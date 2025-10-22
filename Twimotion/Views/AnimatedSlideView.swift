//
//  AnimatedSlideView.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI

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
                
                // Display text with animation effects
                paragraphView(geometry: geometry)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, geometry.size.width * 0.08)
                
                Spacer()
            }
        }
    }
    
    private func paragraphView(geometry: GeometryProxy) -> some View {
        // Use shared text renderer for consistent layout
        let config = SharedTextRenderer.TextLayoutConfig.defaultConfig(
            for: geometry.size,
            textColor: textColor,
            backgroundColor: backgroundColor
        )
        
        if let result = SharedTextRenderer.prepareText(phraseAnimations: phraseAnimations, config: config) {
            return AnyView(
                VStack {
                    // Display text using shared renderer
                    SharedTextRenderer.renderToSwiftUIView(result: result, config: config)
                    
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
