//
//  DeterministicAnimationEngine.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import SwiftUI

/// Simplified animation engine that provides clean, deterministic animation states
/// All animations are driven by normalized time (t: 0.0 to 1.0) for consistency between preview and export
class DeterministicAnimationEngine {
    
    // MARK: - Duration Calculation
    
    /// Calculate the optimal video duration based on text length
    static func calculateVideoDuration(
        for phrases: [String],
        speedMultiplier: Double = 1.0
    ) -> Double {
        let wordCount = phrases.count
        
        // Simple, effective timing
        let baseDelay: Double = 0.4 // Time per word
        let holdTime: Double = 3.0  // Hold final result
        
        let animationTime = Double(wordCount) * baseDelay
        let totalDuration = animationTime + holdTime
        
        // Apply speed multiplier
        let adjustedDuration = totalDuration / speedMultiplier
        
        // Reasonable limits
        return max(5.0, min(adjustedDuration, 120.0))
    }
    
    // MARK: - Animation State
    
    /// Simple animation state for a phrase
    struct PhraseAnimation {
        let text: String
        let opacity: Double
        let scale: Double
        let isVisible: Bool
    }
    
    /// Calculate animation state at normalized time t (0.0 to 1.0)
    static func calculateAnimationState(
        at t: Double,
        phrases: [String],
        animationType: AnimationType = .typewriter
    ) -> [PhraseAnimation] {
        
        let clampedT = max(0.0, min(1.0, t))
        let phraseCount = phrases.count
        
        guard phraseCount > 0 else { return [] }
        
        // Calculate when each phrase should appear
        let animationPortion = 0.8 // 80% of time for animation, 20% for hold
        let phraseSpacing = animationPortion / Double(phraseCount)
        
        return phrases.enumerated().map { index, text in
            let phraseStartTime = Double(index) * phraseSpacing
            let phraseT = calculatePhraseTime(globalT: clampedT, phraseStartTime: phraseStartTime)
            
            return PhraseAnimation(
                text: text,
                opacity: calculateOpacity(phraseT: phraseT, animationType: animationType),
                scale: calculateScale(phraseT: phraseT, animationType: animationType),
                isVisible: phraseT >= 0.0
            )
        }
    }
    
    // MARK: - Animation Types
    
    enum AnimationType: String, CaseIterable {
        case typewriter = "typewriter"
        case fadeIn = "fade_in"
        case popIn = "pop_in"
        
        var displayName: String {
            switch self {
            case .typewriter: return "Typewriter"
            case .fadeIn: return "Fade In"
            case .popIn: return "Pop In"
            }
        }
    }
    
    // MARK: - Private Calculations
    
    private static func calculatePhraseTime(globalT: Double, phraseStartTime: Double) -> Double {
        guard globalT >= phraseStartTime else { return -1.0 }
        return 1.0 // Once visible, stay visible
    }
    
    private static func calculateOpacity(phraseT: Double, animationType: AnimationType) -> Double {
        guard phraseT >= 0.0 else { return 0.0 }
        
        switch animationType {
        case .typewriter:
            return 1.0 // Always visible once appeared
            
        case .fadeIn:
            if phraseT <= 0.3 {
                return phraseT / 0.3 // Fade in over 30%
            } else {
                return 1.0 // Hold
            }
            
        case .popIn:
            if phraseT <= 0.2 {
                return phraseT / 0.2 // Quick fade in
            } else {
                return 1.0 // Hold
            }
        }
    }
    
    private static func calculateScale(phraseT: Double, animationType: AnimationType) -> Double {
        guard phraseT >= 0.0 else { return 1.0 }
        
        switch animationType {
        case .typewriter:
            return 1.0 // No scaling
            
        case .fadeIn:
            return 1.0 // No scaling
            
        case .popIn:
            if phraseT <= 0.2 {
                let normalizedT = phraseT / 0.2
                return 0.8 + 0.2 * normalizedT // Scale from 0.8 to 1.0
            } else {
                return 1.0
            }
        }
    }
}
