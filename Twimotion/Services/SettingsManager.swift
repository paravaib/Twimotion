//
//  SettingsManager.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import Combine

/// Manages app settings and preferences
@MainActor
class SettingsManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var autoSaveToPhotos: Bool {
        didSet {
            userDefaults.set(autoSaveToPhotos, forKey: autoSaveKey)
        }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let autoSaveKey = "autoSaveToPhotos"
    
    // MARK: - Initialization
    
    init() {
        // Load auto-save preference, default to true
        self.autoSaveToPhotos = userDefaults.object(forKey: autoSaveKey) as? Bool ?? true
    }
    
    // MARK: - Public Methods
    
    /// Reset all settings to default values
    func resetToDefaults() {
        autoSaveToPhotos = true
    }
    
    /// Check if auto-save is enabled
    var isAutoSaveEnabled: Bool {
        return autoSaveToPhotos
    }
}
