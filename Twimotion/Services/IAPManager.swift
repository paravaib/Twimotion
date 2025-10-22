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
    
    // Entitlement caching
    @Published var entitlementExpiresAt: Date?
    @Published var entitlementLastChecked: Date?
    
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
        static let entitlementExpiresAt = "entitlementExpiresAt"
        static let entitlementLastChecked = "entitlementLastChecked"
    }
    
    // MARK: - Private Properties
    
    private var updateListenerTask: Task<Void, Error>? = nil
    private var isListening = false
    
    // MARK: - Initialization
    
    init() {
        // Load user data synchronously first
        loadUserData()
        loadEntitlementCache()
        checkForDailyReset()
        
        // Start listening for live transaction updates
        if !isListening {
            updateListenerTask = listenForTransactions()
            isListening = true
        }
        
        // Load products and query local entitlements on app launch
        Task {
            await loadProducts()
            await queryLocalEntitlements()
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
    
    /// Handle app foreground events - check for expired entitlements
    func handleAppForeground() async {
        
        // Check if entitlement has expired
        if let expiresAt = entitlementExpiresAt, expiresAt < Date() {
            await queryLocalEntitlements()
        } else if let lastChecked = entitlementLastChecked {
            let hoursSinceLastCheck = Date().timeIntervalSince(lastChecked) / 3600
            if hoursSinceLastCheck > 24 {
                await queryLocalEntitlements()
            }
        }
    }
    
    /// Check if entitlement is expired and show appropriate UI
    var isEntitlementExpired: Bool {
        guard let expiresAt = entitlementExpiresAt else { return false }
        return expiresAt < Date()
    }
    
    /// Get formatted expiration date for UI display
    var formattedExpirationDate: String? {
        guard let expiresAt = entitlementExpiresAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: expiresAt)
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
    
    /// Restore Pro subscription (only called when user taps "Restore")
    func restorePro() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Only sync when user explicitly requests restore
            try await AppStore.sync()
            // Check for existing transactions
            await checkForExistingPurchases()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Manually refresh subscription status (only when user requests it)
    func refreshSubscriptionStatus() async {
        await checkSubscriptionStatus()
    }
    
    /// Reset Pro status for debugging (remove in production)
    @MainActor
    func resetProStatus() {
        isProUser = false
        userDefaults.set(false, forKey: Keys.isProUser)
        userDefaults.removeObject(forKey: Keys.proPurchaseDate)
    }
    
    /// Manual reset for testing - resets daily GIFs and countdown
    @MainActor
    func manualResetDailyGIFs() {
        dailyGIFsUsed = 0
        lastResetDate = Date()
        saveUserData()
    }
    
    /// Force check subscription status (bypasses local cache)
    func forceCheckSubscriptionStatus() async {
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
    
    /// Query local entitlements - Step 1 of safe client-only flow
    private func queryLocalEntitlements() async {
        await MainActor.run {
            self.isProUser = false
            self.entitlementExpiresAt = nil
        }
        
        // Check if this is a fresh install (no cached entitlement data)
        let isFreshInstall = entitlementLastChecked == nil
        
        if isFreshInstall {
            // Don't call AppStore.sync() to avoid Apple Sign In prompt
            // Local entitlements will be checked below
        }
        
        // Query local entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                // Check if this is a Pro subscription and is active
                if ProductID.allCases.contains(where: { $0.rawValue == transaction.productID }) {
                    let isCurrentlyActive = transaction.revocationDate == nil && 
                                           (transaction.expirationDate == nil || (transaction.expirationDate ?? Date.distantFuture) > Date())
                    
                    if isCurrentlyActive {
                        await MainActor.run {
                            self.isProUser = true
                            self.entitlementExpiresAt = transaction.expirationDate
                            self.entitlementLastChecked = Date()
                        }
                        break // Found active subscription, no need to check more
                    }
                }
            } catch {
                // Handle error silently - this is expected in some cases
                // The app will continue with cached entitlement status
            }
        }
        
        // Save entitlement cache
        saveEntitlementCache()
        
        await MainActor.run {
        }
    }
    
    /// Restore purchases - Only call when user explicitly requests it (will trigger Apple Sign In)
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Only call AppStore.sync() when user explicitly requests restore
            // This will trigger Apple Sign In prompt
            try await AppStore.sync()
            
            // Re-query local entitlements after sync
            await queryLocalEntitlements()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    /// Force restore purchases (for testing/debugging - will trigger Apple Sign In)
    func forceRestorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        // Clear all cached data first
        await MainActor.run {
            self.isProUser = false
            self.entitlementExpiresAt = nil
            self.entitlementLastChecked = nil
            self.userDefaults.removeObject(forKey: Keys.entitlementExpiresAt)
            self.userDefaults.removeObject(forKey: Keys.entitlementLastChecked)
        }
        
        do {
            // Force sync with App Store (will trigger Apple Sign In)
            try await AppStore.sync()
            // Re-query local entitlements after sync
            await queryLocalEntitlements()
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func loadUserData() {
        // Safely load UserDefaults data
        isProUser = userDefaults.bool(forKey: Keys.isProUser)
        dailyGIFsUsed = userDefaults.integer(forKey: Keys.dailyGIFsUsed)
        
        if let savedDate = userDefaults.object(forKey: Keys.lastResetDate) as? Date {
            lastResetDate = savedDate
        } else {
            lastResetDate = Date()
        }
    }
    
    /// Load entitlement cache - Step 4 of safe client-only flow
    private func loadEntitlementCache() {
        // Load cached entitlement data
        entitlementExpiresAt = userDefaults.object(forKey: Keys.entitlementExpiresAt) as? Date
        entitlementLastChecked = userDefaults.object(forKey: Keys.entitlementLastChecked) as? Date
        
        // Check if this is a fresh install (no cached data at all)
        let isFreshInstall = entitlementLastChecked == nil && entitlementExpiresAt == nil
        
        if isFreshInstall {
            return
        }
        
        // Check if cached entitlement is still valid (trusted for 24 hours)
        if let lastChecked = entitlementLastChecked {
            let hoursSinceLastCheck = Date().timeIntervalSince(lastChecked) / 3600
            if hoursSinceLastCheck < 24 && isProUser {
                return
            }
        }
        
    }
    
    /// Save entitlement cache - Step 4 of safe client-only flow
    private func saveEntitlementCache() {
        userDefaults.set(isProUser, forKey: Keys.isProUser)
        userDefaults.set(entitlementExpiresAt, forKey: Keys.entitlementExpiresAt)
        userDefaults.set(entitlementLastChecked, forKey: Keys.entitlementLastChecked)
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
            dailyGIFsUsed = 0
            lastResetDate = now
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
    
    /// Listen for live transaction updates - Step 2 of safe client-only flow
    private func listenForTransactions() -> Task<Void, Error> {
        return Task { [weak self] in
            guard let self = self else { return }
            
            do {
                for await result in Transaction.updates {
                    do {
                        let transaction = try self.checkVerified(result)
                        
                        // Update entitlement state for live updates
                        await self.updateEntitlementFromTransaction(transaction)
                        
                        // Finish transaction if required
                        await transaction.finish()
                    } catch {
                    }
                }
            } catch {
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
    
    /// Update entitlement state from transaction - used for live updates
    private func updateEntitlementFromTransaction(_ transaction: Transaction) async {
        // Check if this is a Pro subscription
        let productID = transaction.productID
        if ProductID.allCases.contains(where: { $0.rawValue == productID }) {
            
            // Check if subscription is currently active
            let isCurrentlyActive = transaction.revocationDate == nil && 
                                   (transaction.expirationDate == nil || (transaction.expirationDate ?? Date.distantFuture) > Date())
            
            await MainActor.run {
                if isCurrentlyActive {
                    // Subscription is active
                    self.isProUser = true
                    self.entitlementExpiresAt = transaction.expirationDate
                    self.entitlementLastChecked = Date()
                } else {
                    // Subscription is not active (expired or revoked)
                    self.isProUser = false
                    self.entitlementExpiresAt = nil
                    self.entitlementLastChecked = Date()
                }
                
                // Save updated entitlement cache
                self.saveEntitlementCache()
            }
        }
    }
    
    /// Legacy method for backward compatibility
    private func updateProStatus(_ transaction: Transaction) async {
        await updateEntitlementFromTransaction(transaction)
    }
    
    private func checkForExistingPurchases() async {
        // First, reset to non-pro status on MainActor
        await MainActor.run {
            self.isProUser = false
            self.userDefaults.set(false, forKey: Keys.isProUser)
        }
        
        // Check current entitlements (active subscriptions)
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                await updateProStatus(transaction)
            } catch {
                // Handle verification errors silently
                print("Transaction verification failed: \(error)")
            }
        }
        
        // Also check for any pending transactions
        for await result in Transaction.unfinished {
            do {
                let transaction = try checkVerified(result)
                await updateProStatus(transaction)
                await transaction.finish()
            } catch {
                // Handle verification errors silently
                print("Pending transaction verification failed: \(error)")
            }
        }
        
        await MainActor.run {
        }
    }
    
    /// Check current subscription status with AppStore.sync (only call when user explicitly requests it)
    private func checkSubscriptionStatus() async {
        isLoading = true
        
        do {
            // Only sync when explicitly requested (e.g., restore purchases button)
            try await AppStore.sync()
            
            // Check for existing entitlements
            await checkForExistingPurchases()
            
        } catch {
            // Check if this is a sandbox/authentication error
            if error.localizedDescription.contains("authentication") || 
               error.localizedDescription.contains("sandbox") ||
               error.localizedDescription.contains("sign in") {
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
