//
//  IAPManager.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import Combine

/// Simple IAP manager for future premium features
class IAPManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isProUser = false
    
    // MARK: - Public Methods
    
    /// Check if user can export without watermark
    var canExportWithoutWatermark: Bool {
        return isProUser
    }
    
    /// Check if user has unlimited exports
    var hasUnlimitedExports: Bool {
        return isProUser
    }
}

// MARK: - Singleton Instance

extension IAPManager {
    static let shared = IAPManager()
}
