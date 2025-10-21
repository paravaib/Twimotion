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
    @StateObject private var gifExporter = GIFExporter()
    @State private var includeWatermark = true // Always true for branding
    @State private var showingShareSheet = false
    @State private var exportedGIFURL: URL?
    @State private var exportCompleted = false
    @State private var exportedFileSize: String = ""
    
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
            ScrollView {
                VStack(spacing: 24) {
                    // Export settings
                    exportSettingsSection
                    
                    // Export button and progress
                    exportSection
                    
                    // Results section
                    if exportCompleted {
                        resultsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Export GIF")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Back") {
                // Handle back navigation
            })
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportedGIFURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    
    // MARK: - Export Settings Section
    
    private var exportSettingsSection: some View {
        VStack(spacing: 20) {
            // Export info
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Export Settings")
                            .font(.headline)
                        
                        Text("\(Int(DeterministicAnimationEngine.calculateGIFDuration(for: phrases, speedMultiplier: speedMultiplier))) seconds • \(phrases.count) words")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                }
                
                // GIF specifications
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("X Platform Optimized")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("1080×1080 • Perfect for X platform uploads")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Watermark toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Include Watermark")
                        .font(.subheadline)
                    
                    Text("Branding watermark (always included)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $includeWatermark)
                    .labelsHidden()
                    .disabled(true) // Always include watermark for branding
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
        }
    }
    
    
    
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        VStack(spacing: 16) {
            // Export button
            Button(action: startExport) {
                HStack(spacing: 12) {
                    if gifExporter.isExporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                    }
                    
                    Text(gifExporter.isExporting ? "Exporting..." : "Export GIF")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: gifExporter.isExporting ? [Color.gray, Color.gray.opacity(0.8)] : [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: gifExporter.isExporting ? Color.clear : Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(gifExporter.isExporting)
            .scaleEffect(gifExporter.isExporting ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: gifExporter.isExporting)
            
            // Progress view
            if gifExporter.isExporting {
                progressView
            }
        }
    }
    
    private var progressView: some View {
        VStack(spacing: 12) {
            // Progress bar
            ProgressView(value: gifExporter.exportProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            // Progress details
            VStack(spacing: 8) {
                HStack {
                    Text("Frame \(gifExporter.currentFrame) of \(gifExporter.totalFrames)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if gifExporter.estimatedTimeRemaining > 0 {
                        Text("ETA: \(timeString(from: gifExporter.estimatedTimeRemaining))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // File size info
                if !exportedFileSize.isEmpty {
                    HStack {
                        Text("GIF Size: \(exportedFileSize)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("1080×1080")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(spacing: 16) {
            // Success message
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    Text("Export Complete!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Spacer()
                }
                
                // File size info
                if !exportedFileSize.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GIF Details")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Size: \(exportedFileSize) • Resolution: 1080×1080")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Button(action: saveToPhotos) {
                    HStack {
                        Image(systemName: "photo")
                        Text("Save to Photos")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.green)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(16)
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
        
        gifExporter.saveToPhotos(gifURL: url) { result in
            DispatchQueue.main.async {
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

