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
    let animationType: DeterministicAnimationEngine.AnimationType
    let duration: Double
    let backgroundColor: Color
    let textColor: Color
    let fontStyle: FontStyle
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentTime: Double = 0.0
    @State private var isPlaying: Bool = false
    @State private var timer: Timer?
    
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
                        .frame(width: 30, height: 30)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Animation content
                AnimatedSlideView(
                    phrases: phrases,
                    animationType: animationType,
                    t: currentTime,
                    size: CGSize(width: 400, height: 400),
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
                
                Spacer()
                
                // Controls
                VStack(spacing: 20) {
                    // Play/Pause and Reset buttons
                    HStack(spacing: 30) {
                        Button(action: togglePlayback) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Circle().fill(Color.blue))
                        }
                        
                        Button(action: resetAnimation) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Circle().fill(Color.gray))
                        }
                    }
                    
                    // Progress indicator
                    VStack(spacing: 8) {
                        Text("\(Int(currentTime * 100))%")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ProgressView(value: currentTime)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(width: 250)
                    }
                }
                .padding(.bottom, 40)
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

/// Legacy full screen preview view for backward compatibility
struct LegacyFullScreenPreviewView: View {
    let phrases: [String]
    let preset: AnimationPreset
    let duration: Double
    let speedMultiplier: Double
    
    var body: some View {
        FullScreenPreviewView(
            phrases: phrases,
            animationType: DeterministicAnimationEngine.AnimationType.typewriter,
            duration: duration,
            backgroundColor: Color.black,
            textColor: Color.white,
            fontStyle: FontStyle.system
        )
    }
}