//
//  DeterministicAnimationTests.swift
//  TwimotionTests
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import XCTest
import SwiftUI
@testable import Twimotion

/// Tests for deterministic animation behavior
/// Ensures that the same input parameters always produce the same output
class DeterministicAnimationTests: XCTestCase {
    
    // MARK: - Test Data
    
    private let testPhrases = ["Hello", "World", "Test"]
    private let testTemplate: Template = {
        return Template(
            id: "test_template",
            name: "Test Template",
            backgroundAsset: "test_bg.png",
            defaultDuration: 4.0,
            defaultFPS: 24,
            tokens: Template.ColorTokens(bg: "#000000", primary: "#FFFFFF", accent: "#1D9BF0"),
            placeholder: Template.TextPlaceholder(role: "headline", font: "Inter-Bold", fontSize: 56, maxLines: 3, safeInset: 36),
            animation: Template.AnimationConfig(family: "typewriter", minDuration: 3.0, maxDuration: 6.0)
        )
    }()
    
    // MARK: - Deterministic Animation Tests
    
    func testAnimationStateDeterminism() {
        // Test that the same parameters always produce the same animation state
        let preset = AnimationPreset.createRemix(from: testTemplate, seed: 12345)
        
        let state1 = DeterministicAnimationEngine.calculateAnimationState(
            at: 0.5,
            phrases: testPhrases,
            preset: preset
        )
        
        let state2 = DeterministicAnimationEngine.calculateAnimationState(
            at: 0.5,
            phrases: testPhrases,
            preset: preset
        )
        
        XCTAssertEqual(state1.phraseStates.count, state2.phraseStates.count)
        
        for i in 0..<state1.phraseStates.count {
            let phrase1 = state1.phraseStates[i]
            let phrase2 = state2.phraseStates[i]
            
            XCTAssertEqual(phrase1.opacity, phrase2.opacity, accuracy: 0.001)
            XCTAssertEqual(phrase1.scale, phrase2.scale, accuracy: 0.001)
            XCTAssertEqual(phrase1.position.x, phrase2.position.x, accuracy: 0.001)
            XCTAssertEqual(phrase1.position.y, phrase2.position.y, accuracy: 0.001)
            XCTAssertEqual(phrase1.rotation, phrase2.rotation, accuracy: 0.001)
        }
    }
    
    func testRemixDeterminism() {
        // Test that the same seed always produces the same remix variations
        let preset1 = AnimationPreset.createRemix(from: testTemplate, seed: 54321)
        let preset2 = AnimationPreset.createRemix(from: testTemplate, seed: 54321)
        
        XCTAssertEqual(preset1.remixSeed, preset2.remixSeed)
        XCTAssertEqual(preset1.microVariations.timingJitter, preset2.microVariations.timingJitter, accuracy: 0.001)
        XCTAssertEqual(preset1.microVariations.accentShape, preset2.microVariations.accentShape, accuracy: 0.001)
        XCTAssertEqual(preset1.microVariations.gradientAngle, preset2.microVariations.gradientAngle, accuracy: 0.001)
        XCTAssertEqual(preset1.microVariations.scaleVariation, preset2.microVariations.scaleVariation, accuracy: 0.001)
    }
    
    func testAnimationStateBoundaries() {
        // Test animation state at boundaries (t=0.0 and t=1.0)
        let preset = AnimationPreset.createRemix(from: testTemplate, seed: 99999)
        
        let startState = DeterministicAnimationEngine.calculateAnimationState(
            at: 0.0,
            phrases: testPhrases,
            preset: preset
        )
        
        let endState = DeterministicAnimationEngine.calculateAnimationState(
            at: 1.0,
            phrases: testPhrases,
            preset: preset
        )
        
        // At start, first phrase should be visible, others not
        XCTAssertGreaterThan(startState.phraseStates[0].opacity, 0.0)
        XCTAssertEqual(startState.phraseStates[0].animationProgress, 0.0, accuracy: 0.001)
        
        // At end, all phrases should be fully visible
        for phraseState in endState.phraseStates {
            XCTAssertEqual(phraseState.opacity, 1.0, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(phraseState.animationProgress, 1.0)
        }
    }
    
    func testAnimationStateClamping() {
        // Test that animation state handles out-of-bounds time values correctly
        let preset = AnimationPreset.createRemix(from: testTemplate, seed: 11111)
        
        let negativeState = DeterministicAnimationEngine.calculateAnimationState(
            at: -0.5,
            phrases: testPhrases,
            preset: preset
        )
        
        let overflowState = DeterministicAnimationEngine.calculateAnimationState(
            at: 1.5,
            phrases: testPhrases,
            preset: preset
        )
        
        let normalState = DeterministicAnimationEngine.calculateAnimationState(
            at: 0.0,
            phrases: testPhrases,
            preset: preset
        )
        
        // Negative time should be clamped to 0.0
        XCTAssertEqual(negativeState.phraseStates[0].opacity, normalState.phraseStates[0].opacity, accuracy: 0.001)
        
        // Overflow time should be clamped to 1.0
        XCTAssertEqual(overflowState.phraseStates[0].opacity, 1.0, accuracy: 0.001)
    }
    
    // MARK: - Text Splitting Tests
    
    func testTextSplittingDeterminism() {
        let testText = "This is a test sentence. It has multiple sentences. Each should be split correctly."
        
        let split1 = TextSplitter.split(testText)
        let split2 = TextSplitter.split(testText)
        
        XCTAssertEqual(split1, split2)
    }
    
    func testTextSplittingStrategies() {
        // Test word splitting
        let longText = "This is a very long text that should be split by words"
        let wordSplit = TextSplitter.split(longText)
        XCTAssertGreaterThan(wordSplit.count, 0)
    }
    
    func testSplitPreview() {
        let testText = "Sample text for preview testing"
        let preview = TextSplitter.splitPreview(testText)
        
        XCTAssertGreaterThan(preview.estimatedPhraseCount, 0)
        XCTAssertGreaterThan(preview.totalCharacterCount, 0)
        XCTAssertFalse(preview.samplePhrases.isEmpty)
    }
    
    // MARK: - Seeded Random Number Generator Tests
    
    func testSeededRandomDeterminism() {
        // Test that the same seed produces the same sequence
        var rng1 = SeededRandomNumberGenerator(seed: 12345)
        var rng2 = SeededRandomNumberGenerator(seed: 12345)
        
        let values1 = (0..<10).map { _ in rng1.next() }
        let values2 = (0..<10).map { _ in rng2.next() }
        
        XCTAssertEqual(values1, values2)
    }
    
    func testSeededRandomUniqueness() {
        // Test that different seeds produce different sequences
        var rng1 = SeededRandomNumberGenerator(seed: 12345)
        var rng2 = SeededRandomNumberGenerator(seed: 54321)
        
        let values1 = (0..<10).map { _ in rng1.next() }
        let values2 = (0..<10).map { _ in rng2.next() }
        
        XCTAssertNotEqual(values1, values2)
    }
    
    // MARK: - Template Loading Tests
    
    func testTemplateLoading() {
        // Test that templates can be loaded
        let templates = TemplateLoader.loadTemplates()
        
        XCTAssertFalse(templates.isEmpty)
        
        // Verify template structure
        for template in templates {
            XCTAssertFalse(template.id.isEmpty)
            XCTAssertFalse(template.name.isEmpty)
            XCTAssertFalse(template.backgroundAsset.isEmpty)
            XCTAssertGreaterThan(template.defaultDuration, 0)
            XCTAssertGreaterThan(template.defaultFPS, 0)
        }
    }
    
    // MARK: - Performance Tests
    
    func testAnimationCalculationPerformance() {
        let preset = AnimationPreset.createRemix(from: testTemplate, seed: 12345)
        
        measure {
            for _ in 0..<1000 {
                _ = DeterministicAnimationEngine.calculateAnimationState(
                    at: Double.random(in: 0...1),
                    phrases: testPhrases,
                    preset: preset
                )
            }
        }
    }
    
    func testTextSplittingPerformance() {
        let longText = String(repeating: "This is a test sentence. ", count: 100)
        
        measure {
            for _ in 0..<100 {
                _ = TextSplitter.split(longText)
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testAnimationToVideoConsistency() {
        // Test that animation states are consistent for video export
        let preset = AnimationPreset.createRemix(from: testTemplate, seed: 77777)
        
        // Calculate states at different time points
        let timePoints: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
        var states: [DeterministicAnimationEngine.AnimationState] = []
        
        for t in timePoints {
            let state = DeterministicAnimationEngine.calculateAnimationState(
                at: t,
                phrases: testPhrases,
                preset: preset
            )
            states.append(state)
        }
        
        // Verify states are valid and consistent
        for state in states {
            XCTAssertEqual(state.phraseStates.count, testPhrases.count)
            
            for phraseState in state.phraseStates {
                XCTAssertGreaterThanOrEqual(phraseState.opacity, 0.0)
                XCTAssertLessThanOrEqual(phraseState.opacity, 1.0)
                XCTAssertGreaterThan(phraseState.scale, 0.0)
            }
        }
    }
    
    func testMicroVariationsBounds() {
        // Test that micro variations stay within safe bounds
        let variations = AnimationPreset.createRemix(from: testTemplate).microVariations
        
        XCTAssertGreaterThanOrEqual(variations.timingJitter, -0.15)
        XCTAssertLessThanOrEqual(variations.timingJitter, 0.15)
        
        XCTAssertGreaterThanOrEqual(variations.accentShape, -0.3)
        XCTAssertLessThanOrEqual(variations.accentShape, 0.3)
        
        XCTAssertGreaterThanOrEqual(variations.gradientAngle, 0)
        XCTAssertLessThanOrEqual(variations.gradientAngle, 360)
        
        XCTAssertGreaterThanOrEqual(variations.scaleVariation, -0.05)
        XCTAssertLessThanOrEqual(variations.scaleVariation, 0.05)
    }
    
    func testTextProgressionCompleteness() {
        // Test that all words become visible by the end of the animation
        // This test specifically addresses the issue where text stops appearing
        let longPhrases = ["This", "is", "a", "long", "text", "that", "should", "appear", "completely", "throughout", "the", "entire", "video", "duration", "without", "stopping", "at", "any", "point", "in", "time"]
        let preset = AnimationPreset.createRemix(from: testTemplate, seed: 12345)
        
        // Test at the end of animation (t=1.0)
        let endState = DeterministicAnimationEngine.calculateAnimationState(
            at: 1.0,
            phrases: longPhrases,
            preset: preset
        )
        
        // All phrases should be visible at the end
        XCTAssertEqual(endState.phraseStates.count, longPhrases.count)
        
        for (index, phraseState) in endState.phraseStates.enumerated() {
            XCTAssertTrue(phraseState.isVisible, "Phrase \(index) '\(phraseState.text)' should be visible at t=1.0")
            XCTAssertEqual(phraseState.opacity, 1.0, accuracy: 0.001, "Phrase \(index) should have full opacity at t=1.0")
        }
        
        // Test progression throughout the animation
        let timePoints: [Double] = [0.2, 0.4, 0.6, 0.8, 1.0]
        var visibleCounts: [Int] = []
        
        for t in timePoints {
            let state = DeterministicAnimationEngine.calculateAnimationState(
                at: t,
                phrases: longPhrases,
                preset: preset
            )
            let visibleCount = state.phraseStates.filter { $0.isVisible }.count
            visibleCounts.append(visibleCount)
        }
        
        // Verify that visible count increases monotonically
        for i in 1..<visibleCounts.count {
            XCTAssertGreaterThanOrEqual(visibleCounts[i], visibleCounts[i-1], 
                "Visible word count should not decrease as time progresses")
        }
        
        // Verify that all words are visible by the end
        XCTAssertEqual(visibleCounts.last, longPhrases.count, 
            "All words should be visible by the end of the animation")
    }
}
