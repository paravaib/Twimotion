//
//  IAPManager.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import Combine
import StoreKit

/// IAP manager for Pro subscription and daily GIF limits using StoreKit 2
@MainActor
class IAPManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isProUser = false
    @Published var dailyGIFsUsed = 0
    @Published var lastResetDate = Date()
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Constants
    
    private let maxFreeGIFsPerDay = 2
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Product IDs
    
    private enum ProductID: String, CaseIterable {
        case proMonthly = "com.twimotion.pro.monthly"
        case proYearly = "com.twimotion.pro.yearly"
        
        var displayName: String {
            switch self {
            case .proMonthly: return "Pro Monthly"
            case .proYearly: return "Pro Yearly"
            }
        }
    }
    
    // MARK: - Keys for UserDefaults
    
    private enum Keys {
        static let isProUser = "isProUser"
        static let dailyGIFsUsed = "dailyGIFsUsed"
        static let lastResetDate = "lastResetDate"
        static let proPurchaseDate = "proPurchaseDate"
    }
    
    // MARK: - Private Properties
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    // MARK: - Initialization
    
    init() {
        loadUserData()
        checkForDailyReset()
        
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Load products
        Task {
            await loadProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Check if user can export without watermark (always false - watermark stays)
    var canExportWithoutWatermark: Bool {
        return false // Watermark always stays for branding
    }
    
    /// Check if user has unlimited exports
    var hasUnlimitedExports: Bool {
        return isProUser
    }
    
    /// Check if user can create more GIFs today
    var canCreateMoreGIFs: Bool {
        if isProUser {
            return true
        }
        
        checkForDailyReset()
        return dailyGIFsUsed < maxFreeGIFsPerDay
    }
    
    /// Get remaining GIFs for today
    var remainingGIFsToday: Int {
        if isProUser {
            return -1 // Unlimited
        }
        
        checkForDailyReset()
        return max(0, maxFreeGIFsPerDay - dailyGIFsUsed)
    }
    
    /// Record a GIF creation
    func recordGIFCreation() {
        guard !isProUser else { return }
        
        dailyGIFsUsed += 1
        saveUserData()
    }
    
    /// Get monthly product
    var monthlyProduct: Product? {
        return products.first { $0.id == ProductID.proMonthly.rawValue }
    }
    
    /// Get yearly product
    var yearlyProduct: Product? {
        return products.first { $0.id == ProductID.proYearly.rawValue }
    }
    
    /// Purchase Pro subscription (monthly)
    func purchaseMonthly() async {
        guard let product = monthlyProduct else {
            errorMessage = "Monthly subscription not available"
            return
        }
        
        await purchase(product)
    }
    
    /// Purchase Pro subscription (yearly)
    func purchaseYearly() async {
        guard let product = yearlyProduct else {
            errorMessage = "Yearly subscription not available"
            return
        }
        
        await purchase(product)
    }
    
    /// Restore Pro subscription
    func restorePro() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            // Check for existing transactions
            await checkForExistingPurchases()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func loadUserData() {
        isProUser = userDefaults.bool(forKey: Keys.isProUser)
        dailyGIFsUsed = userDefaults.integer(forKey: Keys.dailyGIFsUsed)
        
        if let savedDate = userDefaults.object(forKey: Keys.lastResetDate) as? Date {
            lastResetDate = savedDate
        } else {
            lastResetDate = Date()
        }
    }
    
    private func saveUserData() {
        userDefaults.set(isProUser, forKey: Keys.isProUser)
        userDefaults.set(dailyGIFsUsed, forKey: Keys.dailyGIFsUsed)
        userDefaults.set(lastResetDate, forKey: Keys.lastResetDate)
    }
    
    private func checkForDailyReset() {
        let calendar = Calendar.current
        let today = Date()
        
        // Check if we need to reset (new day)
        if !calendar.isDate(lastResetDate, inSameDayAs: today) {
            dailyGIFsUsed = 0
            lastResetDate = today
            saveUserData()
        }
    }
    
    // MARK: - StoreKit Methods
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateProStatus(transaction)
                await transaction.finish()
                
            case .userCancelled:
                errorMessage = "Purchase cancelled"
                
            case .pending:
                errorMessage = "Purchase pending approval"
                
            @unknown default:
                errorMessage = "Unknown purchase result"
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateProStatus(transaction)
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func updateProStatus(_ transaction: Transaction) async {
        // Check if this is a Pro subscription
        let productID = transaction.productID
        if ProductID.allCases.contains(where: { $0.rawValue == productID }) {
            isProUser = true
            userDefaults.set(true, forKey: Keys.isProUser)
            userDefaults.set(Date(), forKey: Keys.proPurchaseDate)
        }
    }
    
    private func checkForExistingPurchases() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                await updateProStatus(transaction)
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
    }
}

// MARK: - Store Error

enum StoreError: Error, LocalizedError {
    case failedVerification
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        }
    }
}

// MARK: - Singleton Instance

extension IAPManager {
    static let shared = IAPManager()
}
