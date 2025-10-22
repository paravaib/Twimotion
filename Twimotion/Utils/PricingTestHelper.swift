//
//  PricingTestHelper.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation

/// Helper class for testing pricing functionality
class PricingTestHelper {
    
    /// Reset daily limits for testing
    static func resetDailyLimits() {
        UserDefaults.standard.set(0, forKey: "dailyGIFsUsed")
        UserDefaults.standard.set(Date(), forKey: "lastResetDate")
    }
    
    /// Set daily GIFs used for testing
    static func setDailyGIFsUsed(_ count: Int) {
        UserDefaults.standard.set(count, forKey: "dailyGIFsUsed")
    }
    
    /// Set Pro status for testing
    static func setProStatus(_ isPro: Bool) {
        UserDefaults.standard.set(isPro, forKey: "isProUser")
    }
    
    /// Get current daily GIFs used
    static func getDailyGIFsUsed() -> Int {
        return UserDefaults.standard.integer(forKey: "dailyGIFsUsed")
    }
    
    /// Get current Pro status
    static func getProStatus() -> Bool {
        return UserDefaults.standard.bool(forKey: "isProUser")
    }
    
    /// Test the complete pricing flow
    static func testPricingFlow() {
        // Reset everything
        resetDailyLimits()
        setProStatus(false)
        
        let iapManager = IAPManager.shared
        
        // Test 1: Free user starts with 2 GIFs
        assert(iapManager.remainingGIFsToday == 2, "Should start with 2 GIFs")
        
        // Test 2: Record first GIF
        iapManager.recordGIFCreation()
        assert(iapManager.remainingGIFsToday == 1, "Should have 1 GIF left")
        
        // Test 3: Record second GIF
        iapManager.recordGIFCreation()
        assert(iapManager.remainingGIFsToday == 0, "Should have 0 GIFs left")
        
        // Test 4: Cannot create more GIFs
        assert(!iapManager.canCreateMoreGIFs, "Should not be able to create more GIFs")
        
        // Test 5: Upgrade to Pro (simulate purchase)
        iapManager.isProUser = true
        UserDefaults.standard.set(true, forKey: "isProUser")
        assert(iapManager.isProUser, "Should be Pro user")
        
        // Test 6: Pro user can create unlimited GIFs
        assert(iapManager.canCreateMoreGIFs, "Pro user should be able to create unlimited GIFs")
    }
}
