//
//  AnimatedSlideView.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI
import Combine

/// Core animated view that renders kinetic typography based on deterministic animation state
/// This view is purely data-driven and does not use implicit SwiftUI animations for export compatibility
struct AnimatedSlideView: View {
    let phrases: [String]
    let preset: AnimationPreset
    let t: Double // Normalized time (0.0 to 1.0)
    let size: CGSize
    let speedMultiplier: Double // Speed multiplier for animation timing
    
    // Cached animation state to ensure consistency
    private var animationState: DeterministicAnimationEngine.AnimationState {
        DeterministicAnimationEngine.calculateAnimationState(
            at: t,
            phrases: phrases,
            preset: preset,
            speedMultiplier: speedMultiplier
        )
    }
    
    // MARK: - Initialization
    
    init(phrases: [String], preset: AnimationPreset, t: Double, size: CGSize = CGSize(width: 1080, height: 1080), speedMultiplier: Double = 1.0) {
        self.phrases = phrases
        self.preset = preset
        self.t = t
        self.size = size
        self.speedMultiplier = speedMultiplier
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            // Text content
            textContentView
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
    
    // MARK: - Background View
    
    private var backgroundView: some View {
        ZStack {
            // Base background color with dynamic effects
            effectiveBackgroundColor
                .ignoresSafeArea()
                .scaleEffect(animationState.backgroundState.scale)
                .opacity(animationState.backgroundState.opacity)
                .offset(x: animationState.backgroundState.patternOffset.x, y: animationState.backgroundState.patternOffset.y)
            
            // Background image if available
            if let backgroundImage = UIImage(named: preset.template.backgroundAsset) {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .opacity(backgroundOpacity)
                    .scaleEffect(animationState.backgroundState.scale)
                    .offset(x: animationState.backgroundState.patternOffset.x, y: animationState.backgroundState.patternOffset.y)
            }
            
            // Dynamic gradient overlay for depth
            gradientOverlay
                .opacity(animationState.backgroundState.opacity)
                .scaleEffect(animationState.backgroundState.scale)
            
            // Vignette effect
            vignetteOverlay
        }
    }
    
    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                effectiveBackgroundColor.opacity(0.1),
                effectiveBackgroundColor.opacity(0.3)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var vignetteOverlay: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color.clear,
                Color.black.opacity(animationState.globalState.vignetteIntensity)
            ]),
            center: .center,
            startRadius: size.width * 0.3,
            endRadius: size.width * 0.8
        )
        .ignoresSafeArea()
    }
    
    private var backgroundOpacity: Double {
        let animationState = DeterministicAnimationEngine.calculateAnimationState(
            at: t,
            phrases: phrases,
            preset: preset
        )
        return animationState.backgroundState.opacity
    }
    
    // MARK: - Text Content View
    
    private var textContentView: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                    .frame(height: geometry.size.height * 0.05) // Minimal top spacing
                
                // Display text with advanced animation effects
                paragraphView(geometry: geometry)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, geometry.size.width * 0.08) // Dynamic padding based on size
                    .opacity(animationState.globalState.overallOpacity)
                    .offset(x: animationState.globalState.cameraShake.x, y: animationState.globalState.cameraShake.y)
                
                Spacer()
                    .frame(height: geometry.size.height * 0.05) // Minimal bottom spacing
            }
        }
    }
    
    private func paragraphView(geometry: GeometryProxy) -> some View {
        let baseFontSize = calculateFontSize(for: geometry.size)
        
        // Use individual word animations for advanced effects
        if preset.template.animation.family == "typewriter" {
            // Simple typewriter effect
            let visibleText = getVisibleText()
            
            return AnyView(VStack(alignment: .leading, spacing: 0) {
                Text(visibleText)
                    .font(.system(size: baseFontSize, weight: .bold, design: preset.customSettings.fontStyle.fontDesign))
                    .foregroundColor(effectiveTextColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Add a cursor that blinks
                if t < 1.0 {
                    Text("|")
                        .font(.system(size: baseFontSize, weight: .bold, design: preset.customSettings.fontStyle.fontDesign))
                        .foregroundColor(effectiveTextColor)
                        .opacity(blinkingCursorOpacity())
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: t)
                }
            })
        } else {
            // Advanced word-by-word animations
            return AnyView(VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(phrases.enumerated()), id: \.offset) { enumeratedItem in
                    let index = enumeratedItem.offset
                    let word = enumeratedItem.element
                    if index < animationState.phraseStates.count {
                        let phraseState = animationState.phraseStates[index]
                        
                        Text(word)
                            .font(.system(size: baseFontSize, weight: .bold, design: preset.customSettings.fontStyle.fontDesign))
                            .foregroundColor(effectiveTextColor)
                            .opacity(phraseState.opacity)
                            .scaleEffect(phraseState.scale)
                            .offset(x: phraseState.position.x, y: phraseState.position.y)
                            .rotationEffect(.radians(phraseState.rotation))
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading))
        }
    }
    
    private func calculateFontSize(for size: CGSize) -> CGFloat {
        // Use a fixed, optimized font size that works perfectly for social media
        // This ensures consistency between preview and export, and eliminates complexity
        let optimizedFontSize: CGFloat = 72.0
        
        // Scale proportionally for different view sizes to maintain readability
        let baseDimension: CGFloat = 1080.0
        let scaleFactor = min(size.width, size.height) / baseDimension
        
        // Apply scaling with reasonable bounds
        let scaledSize = optimizedFontSize * scaleFactor
        let minSize: CGFloat = 24.0
        let maxSize: CGFloat = 120.0
        
        return max(minSize, min(maxSize, scaledSize))
    }
    
    private var effectiveBackgroundColor: Color {
        return preset.customSettings.backgroundColor ?? preset.template.tokens.backgroundColor
    }
    
    private var effectiveTextColor: Color {
        return preset.customSettings.textColor ?? preset.template.tokens.primaryColor
    }
    
    private func getVisibleText() -> String {
        // Calculate which portion of text to show based on cycling logic
        let wordCount = phrases.count
        let wordsPerCycle = 15 // Reduced for larger text size and better readability
        
        // For short text that fits in one cycle, show all words progressively with delay
        if wordCount <= wordsPerCycle {
            let totalTimeForWords = 0.7 // 70% of time for showing words
            
            let wordsToShow: Int
            if t <= totalTimeForWords {
                // Show words progressively - ensure we show at least 1 word and all words by the end
                let progress = (t / totalTimeForWords) * Double(wordCount)
                wordsToShow = max(1, min(wordCount, Int(progress.rounded(.up))))
            } else {
                // Show all words during delay period
                wordsToShow = wordCount
            }
            
            let visibleWords = Array(phrases.prefix(wordsToShow))
            return visibleWords.joined(separator: " ")
        }
        
        // Calculate current cycle and position within cycle for longer text
        let totalCycles = (wordCount + wordsPerCycle - 1) / wordsPerCycle
        let currentCycle = Int(t * Double(totalCycles))
        let cycleProgress = (t * Double(totalCycles)) - Double(currentCycle)
        
        // Calculate words to show in current cycle
        let startIndex = (currentCycle * wordsPerCycle) % wordCount
        let wordsToShowInCycle = min(wordsPerCycle, wordCount - startIndex)
        let wordsVisibleInCurrentCycle = max(1, min(wordsToShowInCycle, Int((cycleProgress * Double(wordsToShowInCycle)).rounded(.up))))
        
        // Get the visible words for this cycle
        let endIndex = startIndex + wordsVisibleInCurrentCycle
        let visibleWords = Array(phrases[startIndex..<endIndex])
        
        let result = visibleWords.joined(separator: " ")
        
        
        return result
    }
    
    
    
    
    private func calculateTextOpacity() -> Double {
        // Calculate opacity based on cycle progress for fade effect
        let wordCount = phrases.count
        let wordsPerCycle = 15 // Match the words per cycle from getVisibleText
        let totalCycles = (wordCount + wordsPerCycle - 1) / wordsPerCycle
        
        // For short text that fits in one cycle, handle delay and fade
        if totalCycles <= 1 {
            let totalTimeForWords = 0.7 // 70% of time for showing words
            let delayTime = 0.3 // 30% of time for delay before fade
            
            if t <= totalTimeForWords {
                // Full opacity while showing words
                return 1.0
            } else if t <= (totalTimeForWords + delayTime) {
                // Full opacity during delay period
                return 1.0
            } else {
                // Fade out in the remaining time
                let fadeStartTime = totalTimeForWords + delayTime
                let fadeProgress = (t - fadeStartTime) / (1.0 - fadeStartTime)
                return max(0.0, 1.0 - fadeProgress)
            }
        }
        
        let cycleProgress = (t * Double(totalCycles)).truncatingRemainder(dividingBy: 1.0)
        
        // Fade out at the end of each cycle, fade in at the beginning
        let fadeZone = 0.1 // 10% of cycle for fade effect
        
        if cycleProgress < fadeZone {
            // Fade in at the beginning of cycle
            return cycleProgress / fadeZone
        } else if cycleProgress > (1.0 - fadeZone) {
            // Fade out at the end of cycle
            return (1.0 - cycleProgress) / fadeZone
        } else {
            // Full opacity during middle of cycle
            return 1.0
        }
    }
    
    private func blinkingCursorOpacity() -> Double {
        // Simple blinking cursor
        let blinkSpeed = 2.0 // Blinks per second
        let blinkPhase = sin(t * blinkSpeed * .pi * 2)
        return (blinkPhase + 1) / 2 // Convert from -1...1 to 0...1
    }
    
    
}

// MARK: - Preview View

/// Interactive preview view that plays the animation using a timer
struct PreviewView: View {
    let phrases: [String]
    let preset: AnimationPreset
    let duration: Double
    let speedMultiplier: Double
    
    @State private var currentTime: Double = 0.0
    @State private var isPlaying: Bool = false
    @State private var timer: Timer?
    @State private var animationKey: UUID = UUID() // Force view refresh when speed changes
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            // Animation preview
            AnimatedSlideView(
                phrases: phrases,
                preset: preset,
                t: currentTime,
                size: CGSize(width: 300, height: 300),
                speedMultiplier: speedMultiplier
            )
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            
            // Controls
            controlsView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear {
            resetAnimation()
            // Auto-play the preview
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                startAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: duration) { oldDuration, newDuration in
            // Restart animation when duration changes
            animationKey = UUID() // Force view refresh
            if isPlaying {
                pauseAnimation()
                resetAnimation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startAnimation()
                }
            }
        }
        .id(animationKey) // Force view refresh when animationKey changes
    }
    
    // MARK: - Controls View
    
    private var controlsView: some View {
        VStack(spacing: 12) {
            // Progress bar
            progressBar
            
            // Control buttons
            HStack(spacing: 24) {
                // Play/Pause button
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                // Reset button
                Button(action: resetAnimation) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title3)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                // Duration display
                HStack(spacing: 4) {
                    Text(timeString(from: currentTime * duration))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("/")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(timeString(from: duration))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            Slider(
                value: $currentTime,
                in: 0...1.0,
                onEditingChanged: { editing in
                    if editing {
                        pauseAnimation()
                    }
                }
            )
            .accentColor(.blue)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 4)
            )
            
            // Progress indicators removed as requested
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Animation Control Methods
    
    private func togglePlayback() {
        if isPlaying {
            pauseAnimation()
        } else {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        guard !isPlaying else { return }
        
        isPlaying = true
        let frameIncrement = 1.0/60.0 / duration
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
            DispatchQueue.main.async {
                guard isPlaying else {
                    timer.invalidate()
                    return
                }
                
                currentTime += frameIncrement
                
                if currentTime >= 1.0 {
                    currentTime = 1.0
                    pauseAnimation()
                }
            }
        }
    }
    
    private func pauseAnimation() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }
    
    private func stopAnimation() {
        pauseAnimation()
    }
    
    private func resetAnimation() {
        pauseAnimation()
        currentTime = 0.0
    }
    
    // MARK: - Helper Methods
    
    private func phraseColor(for index: Int) -> Color {
        // Use the same animation state as the main view for consistency
        let animationState = DeterministicAnimationEngine.calculateAnimationState(
            at: currentTime,
            phrases: phrases,
            preset: preset
        )
        
        guard index < animationState.phraseStates.count else { return .gray.opacity(0.3) }
        
        let phraseState = animationState.phraseStates[index]
        
        // Use isVisible instead of animationProgress for more reliable state
        if !phraseState.isVisible {
            return .gray.opacity(0.3) // Not visible
        } else {
            return .blue.opacity(0.6) // Visible
        }
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

