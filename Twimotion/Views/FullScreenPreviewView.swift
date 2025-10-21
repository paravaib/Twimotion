//
//  FullScreenPreviewView.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI

// MARK: - Full Screen Preview View

struct FullScreenPreviewView: View {
    let phrases: [String]
    let preset: AnimationPreset
    let duration: Double
    let speedMultiplier: Double
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentTime: Double = 0.0
    @State private var isPlaying: Bool = false
    @State private var timer: Timer?
    @State private var animationKey: UUID = UUID() // Force view refresh when speed changes
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    
                    Spacer()
                    
                    Text("Preview")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Full screen animation
                AnimatedSlideView(
                    phrases: phrases,
                    preset: preset,
                    t: currentTime,
                    size: CGSize(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.width - 40),
                    speedMultiplier: speedMultiplier
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                )
                .cornerRadius(20)
                
                Spacer()
                
                // Full screen controls
                fullScreenControls
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            resetAnimation()
            // Auto-play in full screen
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
    
    // MARK: - Full Screen Controls
    
    private var fullScreenControls: some View {
        VStack(spacing: 20) {
            // Progress bar
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
                .accentColor(.white)
                
                // Duration display
                HStack {
                    Text(timeString(from: currentTime * duration))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(timeString(from: duration))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            
            // Control buttons
            HStack(spacing: 40) {
                // Reset button
                Button(action: resetAnimation) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                
                // Play/Pause button
                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                
                // Close button
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
            }
        }
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
    
    private func timeString(from seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    let sampleTemplate = Template(
        id: "sample",
        name: "Sample",
        backgroundAsset: "sample_bg.png",
        defaultDuration: 4.0,
        defaultFPS: 24,
        tokens: Template.ColorTokens(bg: "#000000", primary: "#FFFFFF"),
        placeholder: Template.TextPlaceholder(role: "headline", font: "Inter-Bold", fontSize: 56, maxLines: 3, safeInset: 36),
        animation: Template.AnimationConfig(family: "typewriter", minDuration: 3.0, maxDuration: 6.0)
    )
    
    let samplePreset = AnimationPreset.createRemix(from: sampleTemplate)
    
    FullScreenPreviewView(
        phrases: ["Sample text", "for preview"],
        preset: samplePreset,
        duration: 4.0,
        speedMultiplier: 1.0
    )
}
