//
//  ThemeManager.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Theme Manager

/// Manages theme selection, persistence, and customization
@MainActor
class ThemeManager: ObservableObject {
    @Published var selectedTheme: Theme
    @Published var customBackgroundColor: Color = .black
    @Published var customTextColor: Color = .white
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "selectedTheme"
    private let customBackgroundKey = "customBackgroundColor"
    private let customTextKey = "customTextColor"
    
    // MARK: - Initialization
    
    init() {
        // Load saved theme or use default
        if let savedThemeData = userDefaults.data(forKey: themeKey),
           let savedTheme = try? JSONDecoder().decode(Theme.self, from: savedThemeData) {
            self.selectedTheme = savedTheme
        } else {
            self.selectedTheme = Theme.default
        }
        
        // Load custom colors
        loadCustomColors()
        
        // If custom colors are not set, initialize them with the selected theme colors
        if userDefaults.string(forKey: customBackgroundKey) == nil {
            customBackgroundColor = selectedTheme.colorScheme.backgroundColor
            customTextColor = selectedTheme.colorScheme.primaryColor
            saveCustomColors()
        }
        
        print("DEBUG: ThemeManager initialized with theme: \(selectedTheme.name)")
    }
    
    // MARK: - Theme Selection
    
    /// Select a predefined theme
    func selectTheme(_ theme: Theme) {
        selectedTheme = theme
        saveTheme()
        
        // Apply theme colors to custom colors for seamless transition
        customBackgroundColor = theme.colorScheme.backgroundColor
        customTextColor = theme.colorScheme.primaryColor
        saveCustomColors()
        
        print("DEBUG: Theme selected - \(theme.name), Background: \(customBackgroundColor.toHex()), Text: \(customTextColor.toHex())")
    }
    
    /// Create a custom theme from current custom colors
    func createCustomTheme() -> Theme {
        return Theme(
            id: "custom",
            name: "Custom",
            platform: .general,
            description: "Your custom color combination",
            colorScheme: ColorScheme(
                background: customBackgroundColor.toHex(),
                primary: customTextColor.toHex()
            ),
            fontStyle: selectedTheme.fontStyle
        )
    }
    
    /// Switch to custom theme mode
    func enableCustomTheme() {
        selectedTheme = createCustomTheme()
        saveTheme()
    }
    
    // MARK: - Custom Color Management
    
    /// Update custom background color
    func updateCustomBackgroundColor(_ color: Color) {
        customBackgroundColor = color
        if selectedTheme.isCustom {
            selectedTheme = createCustomTheme()
            saveTheme()
        }
        saveCustomColors()
    }
    
    /// Update custom text color
    func updateCustomTextColor(_ color: Color) {
        customTextColor = color
        if selectedTheme.isCustom {
            selectedTheme = createCustomTheme()
            saveTheme()
        }
        saveCustomColors()
    }
    
    
    
    // MARK: - Persistence
    
    private func saveTheme() {
        if let themeData = try? JSONEncoder().encode(selectedTheme) {
            userDefaults.set(themeData, forKey: themeKey)
        }
    }
    
    private func saveCustomColors() {
        userDefaults.set(customBackgroundColor.toHex(), forKey: customBackgroundKey)
        userDefaults.set(customTextColor.toHex(), forKey: customTextKey)
    }
    
    private func loadCustomColors() {
        if let backgroundHex = userDefaults.string(forKey: customBackgroundKey) {
            customBackgroundColor = Color.fromHex(backgroundHex)
        }
        if let textHex = userDefaults.string(forKey: customTextKey) {
            customTextColor = Color.fromHex(textHex)
        }
    }
    
    // MARK: - Theme Application
    
    /// Get the effective background color (theme or custom)
    var effectiveBackgroundColor: Color {
        // Always use custom colors since they're updated to match the selected theme
        return customBackgroundColor
    }
    
    /// Get the effective text color (theme or custom)
    var effectiveTextColor: Color {
        // Always use custom colors since they're updated to match the selected theme
        return customTextColor
    }
    
    
    // MARK: - Theme Utilities
    
    /// Get all available themes including custom
    var availableThemes: [Theme] {
        var themes = Theme.predefinedThemes
        if selectedTheme.isCustom {
            themes.append(selectedTheme)
        }
        return themes
    }
    
    
    /// Get only predefined themes (no custom)
    var properThemes: [Theme] {
        Theme.predefinedThemes
    }
    
    /// Reset to default theme
    func resetToDefault() {
        selectTheme(Theme.default)
        customBackgroundColor = Theme.default.colorScheme.backgroundColor
        customTextColor = Theme.default.colorScheme.primaryColor
    }
}

// MARK: - Color Extension for Opacity

extension String {
    func opacity(_ alpha: Double) -> String {
        // This is a simplified approach - in a real app you might want to
        // properly convert hex to rgba with alpha
        return self
    }
}
