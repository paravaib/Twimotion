//
//  Template.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Template Models

/// Represents a complete animation template with styling, timing, and assets
struct Template: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let backgroundAsset: String
    let defaultDuration: Double
    let defaultFPS: Int
    let tokens: ColorTokens
    let placeholder: TextPlaceholder
    let animation: AnimationConfig
    
    // MARK: - Nested Types
    
    /// Color scheme for the template
    struct ColorTokens: Codable, Equatable {
        let bg: String        // Background color (hex)
        let primary: String   // Primary text color (hex)
        
        /// Convert hex string to SwiftUI Color
        var backgroundColor: Color {
            Color.fromHex(bg)
        }
        
        var primaryColor: Color {
            Color.fromHex(primary)
        }
    }
    
    /// Text styling configuration
    struct TextPlaceholder: Codable, Equatable {
        let role: String      // "headline", "body", etc.
        let font: String      // Font family name
        let fontSize: Double  // Base font size
        let maxLines: Int     // Maximum lines allowed
        let safeInset: Double // Safe area inset for text positioning
    }
    
    /// Animation configuration
    struct AnimationConfig: Codable, Equatable {
        let family: String    // Animation family (typewriter, zoom, stagger, etc.)
        let minDuration: Double // Minimum duration in seconds
        let maxDuration: Double // Maximum duration in seconds
    }
}

// MARK: - Animation Preset

/// Represents a specific animation preset with micro-variations
struct AnimationPreset: Identifiable, Equatable {
    let id: String
    let template: Template
    let remixSeed: UInt32
    let microVariations: MicroVariations
    let customSettings: CustomSettings
    
    /// Custom user settings that override template defaults
    struct CustomSettings: Equatable {
        let fontSize: CGFloat?      // Custom font size override
        let backgroundColor: Color? // Custom background color override
        let textColor: Color?       // Custom text color override
        let fontStyle: FontStyle    // Selected font style
        
        static let `default` = CustomSettings(fontSize: nil, backgroundColor: nil, textColor: nil, fontStyle: .system)
        
        static func with(fontSize: CGFloat? = nil, backgroundColor: Color? = nil, textColor: Color? = nil, fontStyle: FontStyle = .system) -> CustomSettings {
            return CustomSettings(fontSize: fontSize, backgroundColor: backgroundColor, textColor: textColor, fontStyle: fontStyle)
        }
    }
    
    /// Micro-variations applied to the base template
    struct MicroVariations: Equatable {
        let timingJitter: Double      // ±10-20% timing variation
        let accentShape: Double       // Random accent shape modifier
        let gradientAngle: Double     // Random gradient angle
        let scaleVariation: Double    // Subtle scale variations
        
        static let `default` = MicroVariations(
            timingJitter: 0.0,
            accentShape: 0.0,
            gradientAngle: 0.0,
            scaleVariation: 0.0
        )
    }
    
    /// Generate a new preset with randomized micro-variations
    static func createRemix(from template: Template) -> AnimationPreset {
        let seed = UInt32.random(in: 0...UInt32.max)
        return createRemix(from: template, seed: seed, customSettings: .default)
    }
    
    /// Generate a preset with specific seed for deterministic variations
    static func createRemix(from template: Template, seed: UInt32, customSettings: CustomSettings = .default) -> AnimationPreset {
        var rng = SeededRandomNumberGenerator(seed: seed)
        
        let variations = MicroVariations(
            timingJitter: Double.random(in: -0.15...0.15, using: &rng),
            accentShape: Double.random(in: -0.3...0.3, using: &rng),
            gradientAngle: Double.random(in: 0...360, using: &rng),
            scaleVariation: Double.random(in: -0.05...0.05, using: &rng)
        )
        
        return AnimationPreset(
            id: "\(template.id)_\(seed)",
            template: template,
            remixSeed: seed,
            microVariations: variations,
            customSettings: customSettings
        )
    }
    
    /// Create a new preset with updated custom settings
    func withCustomSettings(_ newSettings: CustomSettings) -> AnimationPreset {
        return AnimationPreset(
            id: id,
            template: template,
            remixSeed: remixSeed,
            microVariations: microVariations,
            customSettings: newSettings
        )
    }
}

// MARK: - Font Style Enum

enum FontStyle: String, CaseIterable {
    case system = "system"
    case serif = "serif"
    case monospace = "monospace"
    case rounded = "rounded"
    case condensed = "condensed"
    case bold = "bold"
    
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
}

// MARK: - Seeded Random Number Generator

/// Deterministic random number generator for reproducible micro-variations
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt32
    
    init(seed: UInt32) {
        self.state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 1103515245 &+ 12345
        return UInt64(state)
    }
}

