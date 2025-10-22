//
//  SharedTextRenderer.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI
import CoreText

/// Shared text rendering component used by both preview and export
/// Ensures consistent text layout and appearance across the app
class SharedTextRenderer {
    
    // MARK: - Text Layout Configuration
    
    struct TextLayoutConfig {
        let fontSize: CGFloat
        let textColor: Color
        let backgroundColor: Color
        let canvasSize: CGSize
        let horizontalPadding: CGFloat
        let fontStyle: FontStyle
        
        static func defaultConfig(for size: CGSize, textColor: Color = .white, backgroundColor: Color = .black) -> TextLayoutConfig {
            return TextLayoutConfig(
                fontSize: calculateOptimalFontSize(for: size),
                textColor: textColor,
                backgroundColor: backgroundColor,
                canvasSize: size,
                horizontalPadding: size.width * 0.05, // 5% margin
                fontStyle: .system
            )
        }
        
        private static func calculateOptimalFontSize(for size: CGSize) -> CGFloat {
            let optimizedFontSize: CGFloat = 72.0
            let baseDimension: CGFloat = 1080.0
            let scaleFactor = min(size.width, size.height) / baseDimension
            let scaledSize = optimizedFontSize * scaleFactor
            return max(24.0, min(120.0, scaledSize))
        }
    }
    
    // MARK: - Text Rendering Result
    
    struct TextRenderingResult {
        let combinedText: String
        let textSize: CGSize
        let textRect: CGRect
        let attributedString: NSAttributedString
    }
    
    // MARK: - Public Methods
    
    /// Prepare text for rendering (combines phrases and calculates layout)
    static func prepareText(
        phraseAnimations: [DeterministicAnimationEngine.PhraseAnimation],
        config: TextLayoutConfig
    ) -> TextRenderingResult? {
        
        // Get visible phrases (only those that should be visible at current time)
        let visiblePhrases = phraseAnimations.enumerated().compactMap { index, phraseAnimation in
            return phraseAnimation.isVisible && phraseAnimation.opacity > 0 ? phraseAnimation.text : nil
        }
        
        guard !visiblePhrases.isEmpty else { return nil }
        
        // For typewriter effect, we need to show words progressively
        // Only show words that are currently visible, not all words that have ever been visible
        let combinedText = visiblePhrases.joined(separator: " ")
        
        // Debug logging
        print("SharedTextRenderer: Visible phrases count: \(visiblePhrases.count), combined text: '\(combinedText)'")
        
        // Create attributed string
        let font = UIFont.systemFont(ofSize: config.fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(config.textColor)
        ]
        
        let attributedString = NSAttributedString(string: combinedText, attributes: attributes)
        
        // Calculate text size with full width
        let availableWidth = config.canvasSize.width - 2 * config.horizontalPadding
        let textSize = attributedString.boundingRect(
            with: CGSize(width: availableWidth, height: config.canvasSize.height),
            options: [NSStringDrawingOptions.usesLineFragmentOrigin, NSStringDrawingOptions.usesFontLeading],
            context: nil
        ).size
        
        // Calculate text rectangle (centered vertically)
        let textRect = CGRect(
            x: config.horizontalPadding,
            y: (config.canvasSize.height - textSize.height) / 2,
            width: availableWidth,
            height: textSize.height
        )
        
        return TextRenderingResult(
            combinedText: combinedText,
            textSize: textSize,
            textRect: textRect,
            attributedString: attributedString
        )
    }
    
    /// Render text to SwiftUI View (for preview)
    static func renderToSwiftUIView(
        result: TextRenderingResult,
        config: TextLayoutConfig
    ) -> some View {
        return VStack {
            Text(result.combinedText)
                .font(.system(size: config.fontSize, weight: .bold, design: config.fontStyle.fontDesign))
                .foregroundColor(config.textColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, config.horizontalPadding)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// Render text to Core Graphics context (for export)
    static func renderToCoreGraphics(
        result: TextRenderingResult,
        config: TextLayoutConfig,
        context: CGContext
    ) {
        context.saveGState()
        
        // Create a framesetter for proper text wrapping (like a teleprompter)
        let framesetter = CTFramesetterCreateWithAttributedString(result.attributedString)
        
        // Create a path for the text frame that allows wrapping
        let path = CGPath(rect: result.textRect, transform: nil)
        
        // Create the frame
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        
        // Draw the frame with proper text wrapping
        CTFrameDraw(frame, context)
        
        context.restoreGState()
    }
}

// FontStyle extension already exists in Template.swift
