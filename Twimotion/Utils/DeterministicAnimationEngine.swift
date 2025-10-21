//
//  DeterministicAnimationEngine.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import SwiftUI
import Combine

/// Core animation engine that provides deterministic animation states
/// All animations are driven by normalized time (t: 0.0 to 1.0) for consistency between preview and export
class DeterministicAnimationEngine {
    
    // MARK: - Duration Calculation
    
    /// Calculate the optimal GIF duration based on text length
    /// - Parameters:
    ///   - phrases: Array of words/phrases
    ///   - wordDelay: Time between each word appearing (default 0.15 seconds)
    ///   - holdTime: Extra time to hold the final result (default 3.0 seconds)
    ///   - speedMultiplier: Speed multiplier (1.0 = normal, 0.5 = half speed, 2.0 = double speed)
    /// - Returns: Total duration in seconds
    static func calculateGIFDuration(
        for phrases: [String],
        wordDelay: Double = 0.15,
        holdTime: Double = 3.0,
        speedMultiplier: Double = 1.0
    ) -> Double {
        let wordCount = phrases.count
        
        // Optimized for X platform - fast enough to keep attention, readable enough to absorb
        let adjustedWordDelay: Double
        if wordCount <= 20 {
            adjustedWordDelay = 0.4  // Quick for short texts
        } else if wordCount <= 50 {
            adjustedWordDelay = 0.35  // Medium-fast speed
        } else {
            adjustedWordDelay = 0.25  // Fast but readable for long texts
        }
        
        let animationTime = Double(wordCount) * adjustedWordDelay
        let totalDuration = animationTime + (holdTime * 1.5) // Slightly longer hold for X platform
        
        // Apply speed multiplier (higher speed = shorter duration)
        let adjustedDuration = totalDuration / speedMultiplier
        
        print("DEBUG: Duration calculation - wordCount: \(wordCount), totalDuration: \(totalDuration), speedMultiplier: \(speedMultiplier), adjustedDuration: \(adjustedDuration)")
        
        // Cap the duration at reasonable limits
        let minDuration = 5.0   // Minimum 5 seconds
        let maxDuration = 120.0 // Maximum 2 minutes for free X/Twitter
        
        return max(minDuration, min(adjustedDuration, maxDuration))
    }
    
    // MARK: - Animation State
    
    /// Represents the animation state at a specific point in time
    struct AnimationState {
        let phraseStates: [PhraseState]
        let backgroundState: BackgroundState
        let globalState: GlobalState
        
        /// State of an individual phrase
        struct PhraseState {
            let index: Int
            let text: String
            let opacity: Double
            let scale: Double
            let position: CGPoint
            let rotation: Double
            let isVisible: Bool
            let animationProgress: Double // 0.0 to 1.0 for this phrase's animation
        }
        
        /// Background animation state
        struct BackgroundState {
            let scale: Double
            let opacity: Double
            let colorShift: Double
            let patternOffset: CGPoint
        }
        
        /// Global animation effects
        struct GlobalState {
            let overallOpacity: Double
            let cameraShake: CGPoint
            let vignetteIntensity: Double
        }
    }
    
    // MARK: - Animation Timing
    
    /// Calculate animation state at normalized time t (0.0 to 1.0)
    /// - Parameters:
    ///   - t: Normalized time (0.0 = start, 1.0 = end)
    ///   - phrases: Array of text phrases to animate
    ///   - preset: Animation preset with timing configuration
    ///   - speedMultiplier: Speed multiplier for the animation (1.0 = normal speed)
    /// - Returns: Complete animation state for the given time
    static func calculateAnimationState(
        at t: Double,
        phrases: [String],
        preset: AnimationPreset,
        speedMultiplier: Double = 1.0
    ) -> AnimationState {
        
        let clampedT = max(0.0, min(1.0, t))
        let template = preset.template
        let variations = preset.microVariations
        
        // Calculate phrase states
        let phraseStates = calculatePhraseStates(
            at: clampedT,
            phrases: phrases,
            template: template,
            variations: variations,
            speedMultiplier: speedMultiplier
        )
        
        // Calculate background state
        let backgroundState = calculateBackgroundState(
            at: clampedT,
            template: template,
            variations: variations
        )
        
        // Calculate global state
        let globalState = calculateGlobalState(
            at: clampedT,
            template: template,
            variations: variations
        )
        
        return AnimationState(
            phraseStates: phraseStates,
            backgroundState: backgroundState,
            globalState: globalState
        )
    }
    
    // MARK: - Phrase Animation Calculations
    
    private static func calculatePhraseStates(
        at t: Double,
        phrases: [String],
        template: Template,
        variations: AnimationPreset.MicroVariations,
        speedMultiplier: Double = 1.0
    ) -> [AnimationState.PhraseState] {
        
        guard !phrases.isEmpty else { return [] }
        
        let animationFamily = template.animation.family
        let phraseCount = phrases.count
        
        // Calculate timing for each phrase based on animation family
        let phraseTimings = calculatePhraseTimings(
            phraseCount: phraseCount,
            animationFamily: animationFamily,
            variations: variations,
            speedMultiplier: speedMultiplier
        )
        
        return phrases.enumerated().map { index, text in
            let timing = phraseTimings[index]
            let phraseT = calculatePhraseTime(globalT: t, timing: timing)
            
            return AnimationState.PhraseState(
                index: index,
                text: text,
                opacity: calculatePhraseOpacity(phraseT: phraseT, family: animationFamily),
                scale: calculatePhraseScale(phraseT: phraseT, family: animationFamily, variations: variations),
                position: calculatePhrasePosition(phraseT: phraseT, index: index, phraseCount: phraseCount, family: animationFamily),
                rotation: calculatePhraseRotation(phraseT: phraseT, family: animationFamily),
                isVisible: phraseT >= 0.0,
                animationProgress: phraseT
            )
        }
    }
    
    // MARK: - Timing Calculations
    
    private static func calculatePhraseTimings(
        phraseCount: Int,
        animationFamily: String,
        variations: AnimationPreset.MicroVariations,
        speedMultiplier: Double = 1.0
    ) -> [PhraseTiming] {
        
        // Dynamic typewriter timing based on text length
        let wordCount = phraseCount
        
        // Calculate normalized timing (0.0 to 1.0) for each word
        // For faster speeds, compress the animation portion to make words appear faster
        let baseAnimationPortion = 0.8
        let speedAdjustedPortion = baseAnimationPortion / speedMultiplier
        let animationPortion = min(1.0, speedAdjustedPortion) // Cap at 100%
        let wordSpacing = animationPortion / Double(wordCount)
        
        print("DEBUG: Speed timing - speedMultiplier: \(speedMultiplier), baseAnimationPortion: \(baseAnimationPortion), speedAdjustedPortion: \(speedAdjustedPortion), animationPortion: \(animationPortion), wordSpacing: \(wordSpacing)")
        
        return (0..<phraseCount).map { index in
            let startTime = Double(index) * wordSpacing
            // Once a word appears, it stays visible for the rest of the animation
            let duration = 1.0 - startTime // Duration until end of animation
            let endTime = 1.0 // All words stay visible until the end
            
            // Debug logging for the first few and last few words
            if index < 5 || index >= phraseCount - 5 {
                print("DEBUG: Word \(index): startTime=\(String(format: "%.4f", startTime)), duration=\(String(format: "%.4f", duration)), endTime=\(String(format: "%.4f", endTime))")
            }
            
            // Debug logging for words around index 40
            if index >= 35 && index <= 45 {
                print("DEBUG: Word \(index): startTime=\(String(format: "%.4f", startTime)), duration=\(String(format: "%.4f", duration)), endTime=\(String(format: "%.4f", endTime))")
            }
            
            return PhraseTiming(
                startTime: startTime,
                duration: duration,
                endTime: endTime
            )
        }
    }
    
    private static func calculatePhraseTime(globalT: Double, timing: PhraseTiming) -> Double {
        guard globalT >= timing.startTime else { 
            // Debug logging for words that haven't started yet
            if timing.startTime > 0.3 && timing.startTime < 0.4 {
                print("DEBUG: Word with startTime=\(String(format: "%.4f", timing.startTime)) not started yet, globalT=\(String(format: "%.4f", globalT))")
            }
            return -1.0 // Not started
        }
        
        // Once a word appears, it stays visible (return 1.0 for visible state)
        // Since we've already passed the guard, the word should be visible
        
        // Debug logging for words that just became visible
        if timing.startTime > 0.3 && timing.startTime < 0.4 {
            print("DEBUG: Word with startTime=\(String(format: "%.4f", timing.startTime)) became visible, globalT=\(String(format: "%.4f", globalT))")
        }
        
        return 1.0
    }
    
    // MARK: - Animation Family Implementations
    
    private static func calculatePhraseOpacity(phraseT: Double, family: String) -> Double {
        guard phraseT >= 0.0 && phraseT <= 1.0 else {
            return phraseT < 0.0 ? 0.0 : 1.0
        }
        
        switch family {
        case "typewriter":
            // Once a word appears, it stays visible
            return 1.0
            
        case "zoom_hero":
            // Dramatic fade in with hold
            if phraseT <= 0.3 {
                return phraseT / 0.3 // Fade in over 30%
            } else if phraseT <= 0.8 {
                return 1.0 // Hold at full opacity
            } else {
                return max(0.0, (1.0 - phraseT) / 0.2) // Fade out over last 20%
            }
            
        case "stagger_pop":
            // Quick pop in with slight fade
            if phraseT <= 0.1 {
                return phraseT / 0.1 // Quick fade in
            } else if phraseT <= 0.9 {
                return 1.0 // Hold
            } else {
                return max(0.0, (1.0 - phraseT) / 0.1) // Quick fade out
            }
            
        case "fade_slide":
            // Smooth fade in and out
            if phraseT <= 0.4 {
                return phraseT / 0.4 // Smooth fade in
            } else if phraseT <= 0.6 {
                return 1.0 // Hold
            } else {
                return max(0.0, (1.0 - phraseT) / 0.4) // Smooth fade out
            }
            
        case "ticker_news":
            // Always visible once appeared (like news ticker)
            return 1.0
            
        case "pulse_energy":
            // Pulsing opacity effect
            let pulsePhase = phraseT * 4 * .pi // 2 full pulses
            return 0.7 + 0.3 * sin(pulsePhase)
            
        default:
            return 1.0
        }
    }
    
    private static func calculatePhraseScale(phraseT: Double, family: String, variations: AnimationPreset.MicroVariations) -> Double {
        guard phraseT >= 0.0 && phraseT <= 1.0 else {
            return 1.0
        }
        
        let baseScale = 1.0 + variations.scaleVariation
        
        switch family {
        case "typewriter":
            return baseScale
            
        case "zoom_hero":
            // Dramatic zoom in effect
            if phraseT <= 0.3 {
                return baseScale * (0.3 + 0.7 * phraseT / 0.3) // Scale from 0.3 to 1.0
            } else if phraseT <= 0.7 {
                return baseScale * (1.0 + 0.2 * sin((phraseT - 0.3) * 5 * .pi)) // Slight pulse
            } else {
                return baseScale * (1.2 - 0.2 * (phraseT - 0.7) / 0.3) // Scale down slightly
            }
            
        case "stagger_pop":
            // Pop effect with bounce
            if phraseT <= 0.2 {
                let normalizedT = phraseT / 0.2
                return baseScale * (1.0 + 0.3 * normalizedT * normalizedT) // Pop up
            } else if phraseT <= 0.4 {
                let normalizedT = (phraseT - 0.2) / 0.2
                return baseScale * (1.3 - 0.2 * normalizedT) // Settle down
            } else {
                return baseScale
            }
            
        case "fade_slide":
            // Subtle scale with slide
            return baseScale * (1.0 + 0.1 * sin(phraseT * 2 * .pi))
            
        case "ticker_news":
            return baseScale
            
        case "pulse_energy":
            // Strong pulsing effect
            let pulsePhase = phraseT * 6 * .pi // 3 full pulses
            return baseScale * (0.8 + 0.4 * sin(pulsePhase))
            
        default:
            return baseScale
        }
    }
    
    private static func calculatePhrasePosition(phraseT: Double, index: Int, phraseCount: Int, family: String) -> CGPoint {
        guard phraseT >= 0.0 && phraseT <= 1.0 else {
            return CGPoint.zero
        }
        
        switch family {
        case "typewriter", "zoom_hero", "stagger_pop", "pulse_energy":
            return CGPoint.zero
            
        case "fade_slide":
            // Slide in from left
            let slideOffset = (1.0 - phraseT) * 200.0 // Slide from 200px left
            return CGPoint(x: slideOffset, y: 0)
            
        case "ticker_news":
            // Continuous horizontal movement
            let tickerSpeed = 300.0 // pixels per second equivalent
            let timeOffset = Double(index) * 0.5 // Stagger each word
            let xPosition = tickerSpeed * (phraseT + timeOffset)
            return CGPoint(x: xPosition, y: 0)
            
        default:
            return CGPoint.zero
        }
    }
    
    private static func calculatePhraseRotation(phraseT: Double, family: String) -> Double {
        guard phraseT >= 0.0 && phraseT <= 1.0 else {
            return 0.0
        }
        
        switch family {
        case "typewriter", "zoom_hero", "fade_slide", "ticker_news":
            return 0.0
            
        case "stagger_pop":
            // Slight rotation on pop
            if phraseT <= 0.3 {
                let normalizedT = phraseT / 0.3
                return normalizedT * 0.2 // Rotate 0.2 radians (about 11 degrees)
            } else if phraseT <= 0.6 {
                let normalizedT = (phraseT - 0.3) / 0.3
                return 0.2 - normalizedT * 0.2 // Rotate back to 0
            } else {
                return 0.0
            }
            
        case "pulse_energy":
            // Slight wobble effect
            return 0.1 * sin(phraseT * 8 * .pi) // Small oscillation
            
        default:
            return 0.0
        }
    }
    
    // MARK: - Background and Global State
    
    private static func calculateBackgroundState(
        at t: Double,
        template: Template,
        variations: AnimationPreset.MicroVariations
    ) -> AnimationState.BackgroundState {
        
        let animationFamily = template.animation.family
        
        switch animationFamily {
        case "typewriter":
            // Static background
            return AnimationState.BackgroundState(
                scale: 1.0,
                opacity: 1.0,
                colorShift: 0.0,
                patternOffset: CGPoint.zero
            )
            
        case "zoom_hero":
            // Dynamic zoom background
            let scale = 1.0 + 0.1 * sin(t * 2 * .pi)
            let colorShift = t * 0.3 // Subtle color shift over time
            return AnimationState.BackgroundState(
                scale: scale,
                opacity: 0.9 + 0.1 * sin(t * 3 * .pi),
                colorShift: colorShift,
                patternOffset: CGPoint(x: sin(t * .pi) * 10, y: cos(t * .pi) * 5)
            )
            
        case "stagger_pop":
            // Bouncy background
            let scale = 1.0 + 0.05 * sin(t * 8 * .pi)
            return AnimationState.BackgroundState(
                scale: scale,
                opacity: 1.0,
                colorShift: 0.0,
                patternOffset: CGPoint(x: sin(t * 4 * .pi) * 15, y: cos(t * 4 * .pi) * 10)
            )
            
        case "fade_slide":
            // Subtle movement
            return AnimationState.BackgroundState(
                scale: 1.0,
                opacity: 0.95 + 0.05 * sin(t * .pi),
                colorShift: t * 0.2,
                patternOffset: CGPoint(x: -t * 20, y: 0)
            )
            
        case "ticker_news":
            // Fast scrolling background
            return AnimationState.BackgroundState(
                scale: 1.0,
                opacity: 1.0,
                colorShift: 0.0,
                patternOffset: CGPoint(x: -t * 100, y: 0)
            )
            
        case "pulse_energy":
            // High energy pulsing
            let scale = 1.0 + 0.2 * sin(t * 6 * .pi)
            return AnimationState.BackgroundState(
                scale: scale,
                opacity: 0.8 + 0.2 * sin(t * 4 * .pi),
                colorShift: t * 0.5,
                patternOffset: CGPoint(x: sin(t * 8 * .pi) * 20, y: cos(t * 8 * .pi) * 15)
            )
            
        default:
            return AnimationState.BackgroundState(
                scale: 1.0,
                opacity: 1.0,
                colorShift: 0.0,
                patternOffset: CGPoint.zero
            )
        }
    }
    
    private static func calculateGlobalState(
        at t: Double,
        template: Template,
        variations: AnimationPreset.MicroVariations
    ) -> AnimationState.GlobalState {
        
        let animationFamily = template.animation.family
        
        switch animationFamily {
        case "typewriter":
            // No effects
            return AnimationState.GlobalState(
                overallOpacity: 1.0,
                cameraShake: CGPoint.zero,
                vignetteIntensity: 0.0
            )
            
        case "zoom_hero":
            // Subtle camera shake on impact
            let shakeIntensity = t > 0.3 && t < 0.7 ? 0.5 : 0.0
            let shake = CGPoint(
                x: sin(t * 20 * .pi) * shakeIntensity,
                y: cos(t * 20 * .pi) * shakeIntensity * 0.5
            )
            return AnimationState.GlobalState(
                overallOpacity: 1.0,
                cameraShake: shake,
                vignetteIntensity: 0.3
            )
            
        case "stagger_pop":
            // Pop shake effect
            let shakeIntensity = t > 0.1 && t < 0.3 ? 1.0 : 0.0
            let shake = CGPoint(
                x: sin(t * 30 * .pi) * shakeIntensity,
                y: cos(t * 30 * .pi) * shakeIntensity
            )
            return AnimationState.GlobalState(
                overallOpacity: 1.0,
                cameraShake: shake,
                vignetteIntensity: 0.1
            )
            
        case "fade_slide":
            // No shake, smooth
            return AnimationState.GlobalState(
                overallOpacity: 0.95 + 0.05 * sin(t * .pi),
                cameraShake: CGPoint.zero,
                vignetteIntensity: 0.2
            )
            
        case "ticker_news":
            // No effects for news ticker
            return AnimationState.GlobalState(
                overallOpacity: 1.0,
                cameraShake: CGPoint.zero,
                vignetteIntensity: 0.0
            )
            
        case "pulse_energy":
            // High energy shake
            let shake = CGPoint(
                x: sin(t * 40 * .pi) * 0.8,
                y: cos(t * 40 * .pi) * 0.6
            )
            return AnimationState.GlobalState(
                overallOpacity: 0.9 + 0.1 * sin(t * 6 * .pi),
                cameraShake: shake,
                vignetteIntensity: 0.4
            )
            
        default:
            return AnimationState.GlobalState(
                overallOpacity: 1.0,
                cameraShake: CGPoint.zero,
                vignetteIntensity: 0.0
            )
        }
    }
    
}

// MARK: - Supporting Types

/// Timing information for a single phrase
private struct PhraseTiming {
    let startTime: Double
    let duration: Double
    let endTime: Double
}
