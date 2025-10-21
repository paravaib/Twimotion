//
//  Theme.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import SwiftUI

// MARK: - Theme Model

/// Represents a complete theme with colors, fonts, and platform-specific styling
struct Theme: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let platform: Platform
    let description: String
    let colorScheme: ColorScheme
    let fontStyle: ThemeFontStyle
    
    var isCustom: Bool {
        id == "custom"
    }
}

// MARK: - Platform Enum

enum Platform: String, CaseIterable, Codable, Identifiable {
    case twitter = "twitter"
    case instagram = "instagram"
    case linkedin = "linkedin"
    case tiktok = "tiktok"
    case youtube = "youtube"
    case general = "general"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .twitter: return "Twitter/X"
        case .instagram: return "Instagram"
        case .linkedin: return "LinkedIn"
        case .tiktok: return "TikTok"
        case .youtube: return "YouTube"
        case .general: return "General"
        }
    }
    
    var iconName: String {
        switch self {
        case .twitter: return "bird"
        case .instagram: return "camera"
        case .linkedin: return "briefcase"
        case .tiktok: return "music.note"
        case .youtube: return "play.rectangle"
        case .general: return "paintpalette"
        }
    }
    
    var primaryColor: String {
        switch self {
        case .twitter: return "#1D9BF0"
        case .instagram: return "#E4405F"
        case .linkedin: return "#0077B5"
        case .tiktok: return "#000000"
        case .youtube: return "#FF0000"
        case .general: return "#007AFF"
        }
    }
}

// MARK: - Color Scheme

struct ColorScheme: Codable, Equatable {
    let background: String // Hex color
    let primary: String    // Primary text color (hex)
    
    var backgroundColor: Color {
        Color.fromHex(background)
    }
    
    var primaryColor: Color {
        Color.fromHex(primary)
    }
}

// MARK: - Theme Font Style

enum ThemeFontStyle: String, CaseIterable, Codable, Identifiable {
    case system = "system"
    case serif = "serif"
    case monospace = "monospace"
    case rounded = "rounded"
    case condensed = "condensed"
    case bold = "bold"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .serif: return "Serif"
        case .monospace: return "Monospace"
        case .rounded: return "Rounded"
        case .condensed: return "Condensed"
        case .bold: return "Bold"
        }
    }
    
    var fontDesign: Font.Design {
        switch self {
        case .system: return .default
        case .serif: return .serif
        case .monospace: return .monospaced
        case .rounded: return .rounded
        case .condensed: return .default
        case .bold: return .default
        }
    }
    
    var fontWeight: Font.Weight {
        switch self {
        case .bold: return .bold
        default: return .medium
        }
    }
    
    // Convert to existing FontStyle
    var toFontStyle: FontStyle {
        switch self {
        case .system: return .system
        case .serif: return .serif
        case .monospace: return .monospace
        case .rounded: return .rounded
        case .condensed: return .condensed
        case .bold: return .system // Map bold to system for now
        }
    }
}

// MARK: - Predefined Themes

extension Theme {
    /// Predefined themes for different platforms
    static let predefinedThemes: [Theme] = [
        // Twitter/X Theme
        Theme(
            id: "twitter",
            name: "Twitter/X",
            platform: .twitter,
            description: "Clean and modern theme perfect for Twitter posts",
            colorScheme: ColorScheme(
                background: "#000000",
                primary: "#FFFFFF"
            ),
            fontStyle: .system
        ),
        
        // Instagram Theme
        Theme(
            id: "instagram",
            name: "Instagram",
            platform: .instagram,
            description: "Vibrant and engaging theme for Instagram stories",
            colorScheme: ColorScheme(
                background: "#E4405F",
                primary: "#FFFFFF"
            ),
            fontStyle: .rounded
        ),
        
        // LinkedIn Theme
        Theme(
            id: "linkedin",
            name: "LinkedIn",
            platform: .linkedin,
            description: "Professional theme ideal for LinkedIn content",
            colorScheme: ColorScheme(
                background: "#0077B5",
                primary: "#FFFFFF"
            ),
            fontStyle: .system
        ),
        
        // TikTok Theme
        Theme(
            id: "tiktok",
            name: "TikTok",
            platform: .tiktok,
            description: "Bold and dynamic theme for TikTok videos",
            colorScheme: ColorScheme(
                background: "#FF0050",
                primary: "#FFFFFF"
            ),
            fontStyle: .bold
        ),
        
        // YouTube Theme
        Theme(
            id: "youtube",
            name: "YouTube",
            platform: .youtube,
            description: "Classic theme optimized for YouTube thumbnails",
            colorScheme: ColorScheme(
                background: "#FF0000",
                primary: "#FFFFFF"
            ),
            fontStyle: .system
        ),
        
        // General Theme
        Theme(
            id: "general",
            name: "General",
            platform: Platform.general,
            description: "Versatile theme suitable for any platform",
            colorScheme: ColorScheme(
                background: "#007AFF",
                primary: "#FFFFFF"
            ),
            fontStyle: ThemeFontStyle.system
        )
    ]
    
    /// Default theme (Twitter)
    static let `default` = predefinedThemes.first { $0.id == "twitter" } ?? predefinedThemes[0]
    
    /// Custom theme placeholder
    static let custom = Theme(
        id: "custom",
        name: "Custom",
        platform: Platform.general,
        description: "Your custom color combination",
        colorScheme: ColorScheme(
            background: "#000000",
            primary: "#FFFFFF"
        ),
        fontStyle: ThemeFontStyle.system
    )
}

// MARK: - Color Extension

extension Color {
    static func fromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#000000" }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
