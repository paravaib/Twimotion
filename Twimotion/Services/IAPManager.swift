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
    private var isListening = false
    
    // MARK: - Initialization
    
    init() {
        // Load user data synchronously first
        loadUserData()
        checkForDailyReset()
        
        // Start listening for transaction updates (only if not already listening)
        if !isListening {
            updateListenerTask = listenForTransactions()
            isListening = true
        }
        
        // Load products and check subscription status
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
        isListening = false
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
    
    /// Get time until next reset in seconds
    var timeUntilReset: TimeInterval {
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastResetDate)
        let hoursInDay: TimeInterval = 24 * 60 * 60 // 24 hours in seconds
        
        return max(0, hoursInDay - timeInterval)
    }
    
    /// Get formatted time until reset (e.g., "2h 30m" or "45m")
    var formattedTimeUntilReset: String {
        let totalSeconds = Int(timeUntilReset)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Record a GIF creation
    @MainActor
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
    
    /// Manually refresh subscription status
    func refreshSubscriptionStatus() async {
        print("🔄 Manually refreshing subscription status...")
        await checkSubscriptionStatus()
    }
    
    /// Reset Pro status for debugging (remove in production)
    @MainActor
    func resetProStatus() {
        print("🔄 Resetting Pro status for debugging...")
        isProUser = false
        userDefaults.set(false, forKey: Keys.isProUser)
        userDefaults.removeObject(forKey: Keys.proPurchaseDate)
        print("✅ Pro status reset to false")
    }
    
    /// Manual reset for testing - resets daily GIFs and countdown
    @MainActor
    func manualResetDailyGIFs() {
        print("🔄 Manual reset: Resetting daily GIFs for testing...")
        dailyGIFsUsed = 0
        lastResetDate = Date()
        saveUserData()
        print("✅ Manual reset complete - GIFs reset to 0, countdown reset")
    }
    
    /// Force check subscription status (bypasses local cache)
    func forceCheckSubscriptionStatus() async {
        print("🔄 Force checking subscription status...")
        // Reset local status first
        isProUser = false
        userDefaults.set(false, forKey: Keys.isProUser)
        
        // Then check with App Store
        await checkSubscriptionStatus()
    }
    
    /// Restart transaction listener if needed
    private func restartTransactionListener() {
        updateListenerTask?.cancel()
        isListening = false
        
        if !isListening {
            updateListenerTask = listenForTransactions()
            isListening = true
        }
    }
    
    
    /// Check if Apple ID authentication is required for subscription check
    func checkAppleIDRequirement() async -> Bool {
        do {
            try await AppStore.sync()
            return false // Apple ID is available
        } catch {
            if error.localizedDescription.contains("authentication") || 
               error.localizedDescription.contains("sandbox") ||
               error.localizedDescription.contains("sign in") {
                return true // Apple ID required
            }
            return false // Other error
        }
    }
    
    // MARK: - Private Methods
    
    private func loadUserData() {
        // Safely load UserDefaults data
        isProUser = userDefaults.bool(forKey: Keys.isProUser)
        dailyGIFsUsed = userDefaults.integer(forKey: Keys.dailyGIFsUsed)
        
        if let savedDate = userDefaults.object(forKey: Keys.lastResetDate) as? Date {
            lastResetDate = savedDate
            print("📅 Loaded saved lastResetDate: \(lastResetDate)")
        } else {
            lastResetDate = Date()
            print("📅 Initialized lastResetDate to current date: \(lastResetDate)")
        }
    }
    
    private func saveUserData() {
        userDefaults.set(isProUser, forKey: Keys.isProUser)
        userDefaults.set(dailyGIFsUsed, forKey: Keys.dailyGIFsUsed)
        userDefaults.set(lastResetDate, forKey: Keys.lastResetDate)
    }
    
    private func checkForDailyReset() {
        let now = Date()
        let timeInterval = now.timeIntervalSince(lastResetDate)
        let hoursInDay: TimeInterval = 24 * 60 * 60 // 24 hours in seconds
        
        // Check if 24 hours have passed since last reset
        if timeInterval >= hoursInDay {
            print("🔄 24 hours have passed, resetting daily GIFs")
            dailyGIFsUsed = 0
            lastResetDate = now
            saveUserData()
            print("✅ Daily GIFs reset to 0, lastResetDate updated to: \(lastResetDate)")
        } else {
            let remainingHours = (hoursInDay - timeInterval) / 3600
            print("⏰ \(String(format: "%.1f", remainingHours)) hours remaining until next reset")
        }
    }
    
    // MARK: - StoreKit Methods
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
            print("✅ Loaded \(products.count) products")
        } catch {
            print("⚠️ Failed to load products (normal in simulator): \(error)")
            // Don't show error to user - this is expected in simulator
            // The app will still work with local Pro status
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
        return Task { [weak self] in
            guard let self = self else { return }
            
            do {
                print("👂 Starting transaction listener...")
                for await result in Transaction.updates {
                    do {
                        let transaction = try self.checkVerified(result)
                        print("🔄 New transaction received: \(transaction.productID)")
                        print("🔄 Purchase date: \(transaction.purchaseDate)")
                        print("🔄 Original purchase date: \(transaction.originalPurchaseDate)")
                        print("🔄 Revocation date: \(transaction.revocationDate?.description ?? "none")")
                        print("🔄 Expiration date: \(transaction.expirationDate?.description ?? "none")")
                        
                        await self.updateProStatus(transaction)
                        await transaction.finish()
                        print("✅ Transaction processed and finished")
                    } catch {
                        print("❌ Transaction verification failed: \(error)")
                        print("❌ Error details: \(error.localizedDescription)")
                    }
                }
            } catch {
                print("❌ Transaction listener failed: \(error)")
                print("❌ Listener error details: \(error.localizedDescription)")
                self.isListening = false
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
        print("🔄 Updating Pro status for transaction: \(transaction.productID)")
        print("🔄 Revocation date: \(transaction.revocationDate?.description ?? "none")")
        print("🔄 Expiration date: \(transaction.expirationDate?.description ?? "none")")
        
        // Check if this is a Pro subscription
        let productID = transaction.productID
        if ProductID.allCases.contains(where: { $0.rawValue == productID }) {
            
            // Check if subscription is currently active
            let isCurrentlyActive = transaction.revocationDate == nil && 
                                   (transaction.expirationDate == nil || transaction.expirationDate! > Date())
            
            if isCurrentlyActive {
                // Subscription is active
                isProUser = true
                userDefaults.set(true, forKey: Keys.isProUser)
                userDefaults.set(Date(), forKey: Keys.proPurchaseDate)
                print("✅ Pro subscription activated")
            } else {
                // Subscription is not active (expired or revoked)
                isProUser = false
                userDefaults.set(false, forKey: Keys.isProUser)
                print("❌ Pro subscription not active (expired or revoked)")
            }
        }
    }
    
    private func checkForExistingPurchases() async {
        print("🔍 Checking for existing purchases...")
        
        // First, reset to non-pro status
        isProUser = false
        userDefaults.set(false, forKey: Keys.isProUser)
        
        // Check current entitlements (active subscriptions)
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                print("✅ Found existing entitlement: \(transaction.productID)")
                print("✅ Revocation date: \(transaction.revocationDate?.description ?? "none")")
                print("✅ Expiration date: \(transaction.expirationDate?.description ?? "none")")
                
                await updateProStatus(transaction)
            } catch {
                print("❌ Failed to verify existing entitlement: \(error)")
            }
        }
        
        // Also check for any pending transactions
        for await result in Transaction.unfinished {
            do {
                let transaction = try checkVerified(result)
                print("✅ Found unfinished transaction: \(transaction.productID)")
                await updateProStatus(transaction)
                await transaction.finish()
            } catch {
                print("❌ Failed to verify unfinished transaction: \(error)")
            }
        }
        
        print("🔍 Final Pro status after checking purchases: \(isProUser)")
    }
    
    /// Check current subscription status on app launch
    private func checkSubscriptionStatus() async {
        print("🔄 Starting subscription status check...")
        isLoading = true
        
        do {
            // Try to sync with App Store to get latest subscription status
            print("🔄 Syncing with App Store...")
            try await AppStore.sync()
            print("✅ App Store sync successful")
            
            // Check for existing entitlements
            await checkForExistingPurchases()
            
            print("✅ Subscription status checked - Pro: \(isProUser)")
        } catch {
            print("⚠️ StoreKit sync failed: \(error)")
            print("⚠️ Error details: \(error.localizedDescription)")
            
            // Check if this is a sandbox/authentication error
            if error.localizedDescription.contains("authentication") || 
               error.localizedDescription.contains("sandbox") ||
               error.localizedDescription.contains("sign in") {
                print("ℹ️ Apple ID authentication required for subscription check")
                // Keep local status - don't change anything
                await checkLocalSubscriptionStatus()
            } else {
                // Other errors - show to user
                await MainActor.run {
                    self.errorMessage = "Failed to check subscription status: \(error.localizedDescription)"
                }
            }
        }
        
        isLoading = false
    }
    
    /// Check local subscription status when StoreKit sync fails
    private func checkLocalSubscriptionStatus() async {
        // Keep existing local status - don't change anything
        if isProUser {
            print("✅ Local Pro status maintained")
        } else {
            print("ℹ️ Free user status maintained")
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
