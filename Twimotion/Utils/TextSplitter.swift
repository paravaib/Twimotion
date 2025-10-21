//
//  TextSplitter.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation

/// Utility class for splitting text into words for typewriter animation
class TextSplitter {
    
    // MARK: - Public Methods
    
    /// Split text into individual words for typewriter effect
    /// - Parameter text: Input text to split
    /// - Returns: Array of individual words
    static func split(_ text: String) -> [String] {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Simple word splitting - each word becomes a separate element
        let words = trimmedText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        return words
    }
    
    /// Preview how text will be split without actually splitting
    /// - Parameter text: Input text to analyze
    /// - Returns: SplitPreview with word count and sample words
    static func splitPreview(_ text: String) -> SplitPreview {
        let words = split(text)
        
        return SplitPreview(
            estimatedPhraseCount: words.count,
            samplePhrases: Array(words.prefix(3)),
            totalCharacterCount: text.count,
            averagePhraseLength: words.isEmpty ? 0 : words.map(\.count).reduce(0, +) / words.count
        )
    }
}

// MARK: - SplitPreview Model

/// Preview information about how text will be split
struct SplitPreview {
    let estimatedPhraseCount: Int
    let samplePhrases: [String]
    let totalCharacterCount: Int
    let averagePhraseLength: Int
    
    /// Human-readable description of the split
    var description: String {
        if estimatedPhraseCount == 1 {
            return "Single word (\(totalCharacterCount) characters)"
        } else {
            return "\(estimatedPhraseCount) words"
        }
    }
    
    /// Whether the split looks good for animation
    var isOptimal: Bool {
        estimatedPhraseCount >= 3 && estimatedPhraseCount <= 50
    }
}
