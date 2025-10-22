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
    let speedMultiplier: Double
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var iapManager: IAPManager
    @EnvironmentObject var permissionManager: PermissionManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var currentTime: Double = 0.0
    @State private var isPlaying: Bool = false
    @State private var timer: Timer?
    @StateObject private var mp4Exporter = MP4Exporter()
    @StateObject private var photoSaver = PhotoSaver()
    @State private var showingShareSheet = false
    @State private var exportedVideoURL: URL?
    @State private var exportCompleted = false
    @State private var autoSavedToPhotos = false
    @State private var showingToast = false
    @State private var toastMessage = ""
    
    // Export configuration
    private var currentPreset: AnimationPreset {
        let template = TemplateLoader.loadTemplates().first ?? createFallbackTemplate()
        let customSettings = AnimationPreset.CustomSettings.with(
            fontSize: nil, 
            backgroundColor: backgroundColor, 
            textColor: textColor, 
            fontStyle: fontStyle
        )
        
        let base = AnimationPreset.createRemix(from: template)
        return base.withCustomSettings(customSettings)
    }
    
    private func createFallbackTemplate() -> Template {
        Template(
            id: "typewriter",
            name: "Classic Typewriter",
            backgroundAsset: "typewriter_bg.png",
            defaultDuration: 10.0,
            defaultFPS: 30,
            tokens: Template.ColorTokens(bg: "#000000", primary: "#FFFFFF"),
            placeholder: Template.TextPlaceholder(role: "headline", font: "Inter-Bold", fontSize: 72, maxLines: 10, safeInset: 40),
            animation: Template.AnimationConfig(family: "typewriter", minDuration: 3.0, maxDuration: 30.0)
        )
    }
    
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
                
                // Animation content - full screen
                GeometryReader { geometry in
                    AnimatedSlideView(
                        phrases: phrases,
                        animationType: animationType,
                        t: currentTime,
                        size: CGSize(
                            width: min(geometry.size.width - 40, geometry.size.height - 200),
                            height: min(geometry.size.width - 40, geometry.size.height - 200)
                        ),
                        backgroundColor: backgroundColor,
                        textColor: textColor,
                        fontStyle: fontStyle
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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
                    
                    // Export section
                    exportSection
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
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportedVideoURL {
                ShareSheet(activityItems: [url])
            }
        }
        .overlay(
            // Toast message overlay
            VStack {
                Spacer()
                if showingToast {
                    toastView
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showingToast)
        )
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
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        VStack(spacing: 16) {
            if !exportCompleted {
                // Export button
                Button(action: startExport) {
                    HStack(spacing: 12) {
                        if mp4Exporter.isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                                .font(.title2)
                        }
                        
                        Text(mp4Exporter.isExporting ? "Exporting..." : "Export Video")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(exportButtonColor)
                            .shadow(color: exportButtonColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .disabled(!canExport)
                .scaleEffect(canExport ? 1.0 : 0.98)
                .animation(.easeInOut(duration: 0.3), value: mp4Exporter.isExporting)
                
                // Export progress
                if mp4Exporter.isExporting {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Creating your video...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(mp4Exporter.exportProgress * 100))%")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        ProgressView(value: mp4Exporter.exportProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .frame(height: 6)
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                // Export completed
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        Text("Video Ready!")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingShareSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.subheadline)
                                Text("Share")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.blue)
                            )
                        }
                        
                        Button(action: saveToPhotos) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.subheadline)
                                Text("Save to Photos")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Export Properties
    
    private var canExport: Bool {
        !phrases.isEmpty && 
        iapManager.canCreateMoreGIFs && 
        permissionManager.hasPhotoLibraryPermission && 
        !mp4Exporter.isExporting
    }
    
    private var exportButtonColor: Color {
        if !iapManager.canCreateMoreGIFs {
            return Color.red
        }
        if !permissionManager.hasPhotoLibraryPermission {
            return Color.orange
        }
        return Color.blue
    }
    
    // MARK: - Export Methods
    
    private func startExport() {
        guard canExport else { return }
        
        showToast("Starting video export...")
        
        let exportConfig = MP4Exporter.MP4ExportConfiguration(
            phrases: phrases,
            preset: currentPreset,
            duration: duration,
            includeWatermark: true
        )
        
        mp4Exporter.exportMP4(config: exportConfig) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    self.iapManager.recordGIFCreation()
                    self.exportedVideoURL = url
                    self.exportCompleted = true
                    self.showToast("Video exported successfully!")
                    
                    if self.settingsManager.isAutoSaveEnabled {
                        self.autoSaveToPhotos()
                    }
                case .failure(let error):
                    self.showToast("Export failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveToPhotos() {
        guard let videoURL = exportedVideoURL else { return }
        
        photoSaver.saveToPhotos(videoURL: videoURL) { result in
            switch result {
            case .success:
                self.showToast("Video saved to Photos!")
            case .failure(let error):
                self.showToast("Failed to save to Photos: \(error.localizedDescription)")
            }
        }
    }
    
    private func autoSaveToPhotos() {
        guard let videoURL = exportedVideoURL else { return }
        
        photoSaver.autoSaveToPhotos(videoURL: videoURL) { result in
            switch result {
            case .success:
                self.autoSavedToPhotos = true
                self.showToast("Auto-saved to Photos successfully!")
            case .failure(let error):
                self.showToast("Auto-save failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        showingToast = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingToast = false
            }
        }
    }
    
    // MARK: - Toast View
    
    private var toastView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.white)
                .font(.title3)
            
            Text(toastMessage)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 100)
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
            fontStyle: FontStyle.system,
            speedMultiplier: speedMultiplier
        )
    }
}
