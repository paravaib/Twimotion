//
//  ExportView.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI
import Combine

/// Export view with quality settings, progress tracking, and sharing options
struct ExportView: View {
    let phrases: [String]
    let preset: AnimationPreset
    let speedMultiplier: Double
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager
    @StateObject private var gifExporter = GIFExporter()
    @StateObject private var photoSaver = PhotoSaver()
    @State private var includeWatermark = true // Always true for branding
    @State private var showingShareSheet = false
    @State private var exportedGIFURL: URL?
    @State private var exportCompleted = false
    @State private var exportedFileSize: String = ""
    @State private var autoSavedToPhotos = false
    
    private var exportConfig: GIFExporter.ExportConfiguration {
        let dynamicDuration = DeterministicAnimationEngine.calculateGIFDuration(for: phrases, speedMultiplier: speedMultiplier)
        
        return GIFExporter.ExportConfiguration(
            phrases: phrases,
            preset: preset,
            duration: dynamicDuration,
            fps: preset.template.defaultFPS,
            size: CGSize(width: 1080, height: 1080), // Optimized for X platform
            quality: .optimized,
            includeWatermark: includeWatermark
        )
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Header section - no icons
                    VStack(spacing: 16) {
                        Text("Export Your GIF")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Main export button
                    exportButton
                    
                    Spacer()
                    
                    // Progress view (when exporting)
                    if gifExporter.isExporting {
                        progressView
                    }
                    
                    // Results section (when completed)
                    if exportCompleted {
                        resultsSection
                        
                        // Auto-save status
                        if settingsManager.isAutoSaveEnabled {
                            autoSaveStatusSection
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .onTapGesture {
                // Dismiss keyboard when tapping outside
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedGIFURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    
    
    
    
    
    // MARK: - Export Button
    
    private var exportButton: some View {
        Button(action: startExport) {
            VStack(spacing: 4) {
                Text(gifExporter.isExporting ? "Exporting..." : "Export GIF")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Save and share your creation.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Main gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.2, green: 1.0, blue: 0.2), // Lime green
                            Color(red: 0.0, green: 0.5, blue: 1.0)  // Blue
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .cornerRadius(20)
                    
                    // Glow effect
                    if !gifExporter.isExporting {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.2, green: 1.0, blue: 0.2).opacity(0.3),
                                Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.1)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .blur(radius: 20)
                        .offset(x: -10, y: 5)
                    }
                }
            )
            .scaleEffect(gifExporter.isExporting ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: gifExporter.isExporting)
        }
        .disabled(gifExporter.isExporting)
    }
    
    private var progressView: some View {
        VStack(spacing: 16) {
            // Progress bar
            ProgressView(value: gifExporter.exportProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 0.2, green: 1.0, blue: 0.2)))
                .scaleEffect(y: 2)
            
            // Progress text with ETA
            VStack(spacing: 4) {
                Text("Exporting GIF...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                if gifExporter.estimatedTimeRemaining > 0 {
                    Text("ETA: \(timeString(from: gifExporter.estimatedTimeRemaining))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(spacing: 20) {
            // Success message
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(red: 0.2, green: 1.0, blue: 0.2))
                    .font(.system(size: 32))
                
                Text("Export Complete!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                if !exportedFileSize.isEmpty {
                    Text("Size: \(exportedFileSize) • 1080×1080")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(16)
                }
                
                Button(action: saveToPhotos) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo")
                        Text("Save to Photos")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(red: 0.2, green: 1.0, blue: 0.2))
                    .cornerRadius(16)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Auto-save Status Section
    
    private var autoSaveStatusSection: some View {
        HStack(spacing: 12) {
            Image(systemName: autoSavedToPhotos ? "checkmark.circle.fill" : "clock.circle.fill")
                .foregroundColor(autoSavedToPhotos ? Color(red: 0.2, green: 1.0, blue: 0.2) : .orange)
                .font(.system(size: 20))
            
            Text(autoSavedToPhotos ? "Saved to Photos" : "Saving to Photos...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Helper Methods
    
    private func startExport() {
        print("Starting GIF export...")
        print("Export config: \(exportConfig.phrases.count) phrases, \(exportConfig.duration)s duration, \(exportConfig.size)")
        
        // Reset file size
        exportedFileSize = ""
        
        gifExporter.exportGIF(config: exportConfig) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    print("GIF export successful: \(url.path)")
                    self.exportedGIFURL = url
                    self.exportCompleted = true
                    
                    // Calculate and display file size
                    self.calculateFileSize(url: url)
                    
                    // Auto-save to Photos if enabled
                    if self.settingsManager.isAutoSaveEnabled {
                        self.autoSaveToPhotos()
                    }
                case .failure(let error):
                    print("GIF export failed: \(error.localizedDescription)")
                    print("Error details: \(error)")
                    
                    // Show error alert or toast
                    self.showExportError(error.localizedDescription)
                }
            }
        }
    }
    
    private func calculateFileSize(url: URL) {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                exportedFileSize = formatFileSize(fileSize)
            }
        } catch {
            print("Error calculating file size: \(error)")
            exportedFileSize = "Unknown"
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func showExportError(_ message: String) {
        // You can implement an alert or toast here
        print("Export Error: \(message)")
    }
    
    
    private func saveToPhotos() {
        guard let url = exportedGIFURL else { return }
        
        photoSaver.saveToPhotos(gifURL: url) { result in
            switch result {
            case .success:
                // Auto-close the export view after successful save
                dismiss()
            case .failure(let error):
                // Handle error
                print("Save to Photos failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func autoSaveToPhotos() {
        guard let url = exportedGIFURL else { return }
        
        photoSaver.autoSaveToPhotos(gifURL: url) { result in
            switch result {
            case .success:
                self.autoSavedToPhotos = true
                print("Auto-saved to Photos successfully")
            case .failure(let error):
                print("Auto-save to Photos failed: \(error.localizedDescription)")
            }
        }
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
    
    ExportView(
        phrases: ["Sample text", "for export"],
        preset: samplePreset,
        speedMultiplier: 1.0
    )
}

