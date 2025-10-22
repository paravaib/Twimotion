//
//  AnimatedSlideView.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI
import CoreText

/// Simplified animated view that renders kinetic typography
struct AnimatedSlideView: View {
    let phrases: [String]
    let animationType: DeterministicAnimationEngine.AnimationType
    let t: Double // Normalized time (0.0 to 1.0)
    let size: CGSize
    let backgroundColor: Color
    let textColor: Color
    let fontStyle: FontStyle
    
    // Cached animation state
    private var phraseAnimations: [DeterministicAnimationEngine.PhraseAnimation] {
        DeterministicAnimationEngine.calculateAnimationState(
            at: t,
            phrases: phrases,
            animationType: animationType
        )
    }
    
    // MARK: - Initialization
    
    init(
        phrases: [String],
        animationType: DeterministicAnimationEngine.AnimationType = .typewriter,
        t: Double,
        size: CGSize = CGSize(width: 1080, height: 1080),
        backgroundColor: Color = .black,
        textColor: Color = .white,
        fontStyle: FontStyle = .system
    ) {
        self.phrases = phrases
        self.animationType = animationType
        self.t = t
        self.size = size
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.fontStyle = fontStyle
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()
            
            // Text content
            textContentView
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
    
    // MARK: - Text Content View
    
    private var textContentView: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                
                // Display text with animation effects - positioned at bottom for teleprompter effect
                paragraphView(geometry: geometry)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, geometry.size.width * 0.08)
                    .padding(.bottom, geometry.size.height * 0.1) // Add bottom padding for teleprompter effect
                    .offset(y: calculateTeleprompterOffset(for: geometry.size)) // Add subtle upward scrolling
            }
        }
    }
    
    private func paragraphView(geometry: GeometryProxy) -> some View {
        // Use per-line animation for consistent preview/export experience
        let config = SharedTextRenderer.TextLayoutConfig.defaultConfig(
            for: geometry.size,
            textColor: textColor,
            backgroundColor: backgroundColor
        )
        
        if let lineData = preparePerLineText(phraseAnimations: phraseAnimations, config: config) {
            return AnyView(
                VStack(spacing: 0) {
                    // Render each line with per-line animation
                    ForEach(Array(lineData.lines.enumerated()), id: \.offset) { lineIndex, line in
                        PerLineAnimatedText(
                            line: line,
                            lineIndex: lineIndex,
                            totalLines: lineData.lines.count,
                            config: config,
                            t: t,
                            animationType: animationType
                        )
                    }
                    
                    // Add blinking cursor for typewriter animation
                    if animationType == .typewriter && t < 1.0 {
                        Text("|")
                            .font(.system(size: config.fontSize, weight: .bold, design: config.fontStyle.fontDesign))
                            .foregroundColor(textColor)
                            .opacity(blinkingCursorOpacity())
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: t)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, config.horizontalPadding)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            )
        } else {
            // No visible text
            return AnyView(
                VStack {
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            )
        }
    }
    
    private func calculateFontSize(for size: CGSize) -> CGFloat {
        let optimizedFontSize: CGFloat = 72.0
        let baseDimension: CGFloat = 1080.0
        let scaleFactor = min(size.width, size.height) / baseDimension
        let scaledSize = optimizedFontSize * scaleFactor
        return max(24.0, min(120.0, scaledSize))
    }
    
    private func blinkingCursorOpacity() -> Double {
        let blinkSpeed = 2.0
        let blinkPhase = sin(t * blinkSpeed * .pi * 2)
        return (blinkPhase + 1) / 2
    }
    
    private func calculateTeleprompterOffset(for size: CGSize) -> CGFloat {
        // Create a subtle upward scrolling effect as the animation progresses
        // This simulates the teleprompter text moving up the screen
        let maxOffset = size.height * 0.05 // Maximum 5% of screen height
        return -maxOffset * t // Negative offset moves text upward
    }
    
    // MARK: - Per-Line Text Preparation
    
    private func preparePerLineText(
        phraseAnimations: [DeterministicAnimationEngine.PhraseAnimation],
        config: SharedTextRenderer.TextLayoutConfig
    ) -> PerLineTextData? {
        // Get visible phrases
        let visiblePhrases = phraseAnimations.enumerated().compactMap { index, phraseAnimation in
            return phraseAnimation.isVisible && phraseAnimation.opacity > 0 ? phraseAnimation.text : nil
        }
        
        guard !visiblePhrases.isEmpty else { return nil }
        
        // Combine all visible phrases into a single text block for line analysis
        let combinedText = visiblePhrases.joined(separator: " ")
        
        // Use CTFramesetter to get precise line information (matching MP4 export)
        let font = UIFont.systemFont(ofSize: config.fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(config.textColor)
        ]
        
        let attributedString = NSAttributedString(string: combinedText, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // Calculate text container size (matching preview padding)
        let textWidth = config.canvasSize.width - 2 * config.horizontalPadding
        let textHeight = config.canvasSize.height * 0.8
        let textRect = CGRect(x: 0, y: 0, width: textWidth, height: textHeight)
        
        // Create path for text layout
        let path = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        
        // Get line information
        let lines = CTFrameGetLines(frame) as! [CTLine]
        let lineCount = lines.count
        
        guard lineCount > 0 else { return nil }
        
        // Get line origins
        var lineOrigins = Array<CGPoint>(repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: lineCount), &lineOrigins)
        
        // Extract line strings
        let lineStrings = lines.map { line in
            let lineRange = CTLineGetStringRange(line)
            return (combinedText as NSString).substring(with: NSRange(location: lineRange.location, length: lineRange.length))
        }
        
        return PerLineTextData(
            lines: lineStrings,
            lineOrigins: lineOrigins,
            textWidth: textWidth,
            fontSize: config.fontSize
        )
    }
}

// MARK: - Per-Line Animation Support

struct PerLineTextData {
    let lines: [String]
    let lineOrigins: [CGPoint]
    let textWidth: CGFloat
    let fontSize: CGFloat
}

struct PerLineAnimatedText: View {
    let line: String
    let lineIndex: Int
    let totalLines: Int
    let config: SharedTextRenderer.TextLayoutConfig
    let t: Double
    let animationType: DeterministicAnimationEngine.AnimationType
    
    var body: some View {
        Text(line)
            .font(.system(size: config.fontSize, weight: .bold, design: config.fontStyle.fontDesign))
            .foregroundColor(config.textColor)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, config.horizontalPadding)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
            .opacity(calculateLineOpacity())
            .scaleEffect(calculateLineScale())
            .offset(y: calculateLineOffset())
            .animation(.easeOut(duration: 0.15), value: t)
    }
    
    // MARK: - Per-Line Animation Calculations
    
    private func calculateLineOpacity() -> Double {
        // Per-line timing (matching MP4 export)
        let lineAnimationDuration = 0.15
        let lineSpacing = 0.05
        let lineStartTime = Double(lineIndex) * lineSpacing
        let lineProgress = max(0.0, min(1.0, (t - lineStartTime) / lineAnimationDuration))
        
        // Smooth fade-in with slight hold
        if lineProgress <= 0.3 {
            return lineProgress / 0.3 // Fade in over first 30%
        } else if lineProgress <= 0.8 {
            return 1.0 // Hold at full opacity
        } else {
            return 1.0
        }
    }
    
    private func calculateLineScale() -> Double {
        // Per-line timing (matching MP4 export)
        let lineAnimationDuration = 0.15
        let lineSpacing = 0.05
        let lineStartTime = Double(lineIndex) * lineSpacing
        let lineProgress = max(0.0, min(1.0, (t - lineStartTime) / lineAnimationDuration))
        
        // Subtle scale effect
        let scaleProgress = min(1.0, lineProgress / 0.3) // Scale completes in first 30%
        return 0.95 + 0.05 * scaleProgress // Scale from 0.95 to 1.0
    }
    
    private func calculateLineOffset() -> CGFloat {
        // Per-line timing (matching MP4 export)
        let lineAnimationDuration = 0.15
        let lineSpacing = 0.05
        let lineStartTime = Double(lineIndex) * lineSpacing
        let lineProgress = max(0.0, min(1.0, (t - lineStartTime) / lineAnimationDuration))
        
        // Slide up effect
        let slideDistance = config.fontSize * 0.3
        let slideProgress = min(1.0, lineProgress / 0.4) // Slide completes in first 40%
        return -slideDistance * (1.0 - slideProgress)
    }
}

// MARK: - Preview View

/// Interactive preview view that plays the animation using a timer
struct PreviewView: View {
    let phrases: [String]
    let animationType: DeterministicAnimationEngine.AnimationType
    let duration: Double
    let backgroundColor: Color
    let textColor: Color
    let fontStyle: FontStyle
    
    @State private var currentTime: Double = 0.0
    @State private var isPlaying: Bool = false
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 20) {
            // Animation preview
            AnimatedSlideView(
                phrases: phrases,
                animationType: animationType,
                t: currentTime,
                size: CGSize(width: 300, height: 300),
                backgroundColor: backgroundColor,
                textColor: textColor,
                fontStyle: fontStyle
            )
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .cornerRadius(20)
            
            // Controls
            HStack(spacing: 20) {
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.blue))
                }
                
                Button(action: resetAnimation) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.gray))
                }
            }
            
            // Progress indicator
            VStack {
                Text("\(Int(currentTime * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
                
                ProgressView(value: currentTime)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(width: 200)
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    private func resetAnimation() {
        stopTimer()
        currentTime = 0.0
    }
    
    private func startTimer() {
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            currentTime += 1.0/30.0/duration
            if currentTime >= 1.0 {
                currentTime = 1.0
                stopTimer()
            }
        }
    }
    
    private func stopTimer() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Legacy Support

/// Legacy preview view for backward compatibility
struct LegacyPreviewView: View {
    let phrases: [String]
    let preset: AnimationPreset
    let duration: Double
    let speedMultiplier: Double
    
    var body: some View {
        PreviewView(
            phrases: phrases,
            animationType: .typewriter, // Default to typewriter
            duration: duration,
            backgroundColor: .black,
            textColor: .white,
            fontStyle: .system
        )
    }
}
