//
//  HomeView.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI


/// Main home screen with text input and creation flow
struct HomeView: View {
    @EnvironmentObject var iapManager: IAPManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var permissionManager: PermissionManager
    @State private var inputText: String = ""
    @State private var splitPreview: SplitPreview?
    @State private var showingOnboarding = false
    @State private var showingFullScreenPreview = false
    @State private var showingThemeSelection = false
    @State private var toastMessage: String = ""
    @State private var showingToast = false
    @StateObject private var mp4Exporter = MP4Exporter()
    @StateObject private var photoSaver = PhotoSaver()
    @State private var showingShareSheet = false
    @State private var _exportedVideoURL: URL?
    @State private var previewKey: UUID = UUID() // Force preview refresh when theme changes
    @State private var autoSavedToPhotos = false
    @State private var showingProUpgrade = false
    @State private var countdownTimer: Timer?
    @State private var countdownUpdateTrigger = false // Trigger UI updates
    
    
    // Text length limits for optimal performance
    
    @State private var animationSpeed: Double = 1.0 // Speed multiplier (0.5x to 2x)
    
    // Text length limits
    private let maxCharacters = 500 // Maximum characters allowed
    private let warningCharacters = 400 // Show warning at this count
    
    // Computed properties for text validation
    private var characterCount: Int {
        inputText.count
    }
    
    private var isTextTooLong: Bool {
        characterCount > maxCharacters
    }
    
    private var shouldShowWarning: Bool {
        characterCount >= warningCharacters && characterCount <= maxCharacters
    }
    
    private var remainingCharacters: Int {
        maxCharacters - characterCount
    }
    
    // MARK: - Export Button Properties
    
    private var exportButtonTitle: String {
        if inputText.isEmpty {
            return "Enter text to create video"
        }
        if isTextTooLong {
            return "Text too long"
        }
        if !iapManager.canCreateMoreGIFs {
            return "Daily Limit Reached"
        }
        if !permissionManager.hasPhotoLibraryPermission {
            return "Photos Permission Required"
        }
        if mp4Exporter.isExporting {
            return "Exporting..."
        }
        return "Export GIF"
    }
    
    private var exportButtonSubtitle: String {
        if inputText.isEmpty {
            return "Type your message above"
        }
        if isTextTooLong {
            return "Reduce text length to continue"
        }
        if !iapManager.canCreateMoreGIFs {
            return "Upgrade to Pro for unlimited videos"
        }
        if !permissionManager.hasPhotoLibraryPermission {
            return "Enable in Settings to save videos"
        }
        if mp4Exporter.isExporting {
            return "Creating your animated video"
        }
        return "Save and share your creation"
    }
    
    private var exportButtonColor: Color {
        if inputText.isEmpty || isTextTooLong {
            return Color.gray
        }
        if !iapManager.canCreateMoreGIFs {
            return Color.red
        }
        if !permissionManager.hasPhotoLibraryPermission {
            return Color.orange
        }
        return mp4Exporter.isExporting ? Color.orange : Color.blue
    }
    
    // Classic typewriter preset
    private var currentPreset: AnimationPreset {
        let template = TemplateLoader.loadTemplates().first ?? createFallbackTemplate()
        let customSettings = AnimationPreset.CustomSettings.with(
            fontSize: nil, 
            backgroundColor: themeManager.effectiveBackgroundColor, 
            textColor: themeManager.effectiveTextColor, 
            fontStyle: .system
        )
        
        // Use convenience initializer, then apply custom settings
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
        NavigationView {
            VStack(spacing: 0) {
                // Clean header
                cleanHeader
                
                // Main content
                VStack(spacing: 20) {
                    // Text input with enhance button
                    textInputWithEnhance
                    
                    // Style/Theme buttons
                    styleButtons
                    
                    // Preview button
                    if !inputText.isEmpty {
                        previewButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color.blue.opacity(0.05),
                        Color.purple.opacity(0.03)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .onTapGesture {
                // Dismiss keyboard when tapping outside text input
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: HStack(spacing: 12) {
                    // Upgrade to Pro button for free users
                    if !iapManager.isProUser {
                        Button(action: {
                            showingProUpgrade = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                
                                Text("Pro")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.orange,
                                                Color.red
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
                            )
                        }
                    }
                    
                    // Theme button
                    Button(action: {
                        showingThemeSelection = true
                    }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(themeManager.effectiveBackgroundColor)
                                .frame(width: 16, height: 16)
                            
                            Circle()
                                .fill(themeManager.effectiveTextColor)
                                .frame(width: 16, height: 16)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
            )
            .onAppear {
                if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
                    showingOnboarding = true
                }
                startCountdownTimer()
            }
            .onDisappear {
                stopCountdownTimer()
            }
            .onChange(of: animationSpeed) { oldSpeed, newSpeed in
                // Speed changed - preview will automatically update due to duration change
                _ = DeterministicAnimationEngine.calculateVideoDuration(for: TextSplitter.split(inputText), speedMultiplier: newSpeed)
            }
            .onChange(of: themeManager.selectedTheme) { oldTheme, newTheme in
                // Theme changed - force preview refresh
                previewKey = UUID()
            }
            .onChange(of: iapManager.isProUser) { oldValue, newValue in
                // Pro status changed - restart timer
                if newValue {
                    stopCountdownTimer() // Stop timer for Pro users
                } else {
                    startCountdownTimer() // Start timer for free users
                }
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView()
            }
            .sheet(isPresented: $showingThemeSelection) {
                ThemeSelectionView(themeManager: themeManager)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = _exportedVideoURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .sheet(isPresented: $showingProUpgrade) {
                ProUpgradeView()
                    .environmentObject(iapManager)
            }
            .fullScreenCover(isPresented: $showingFullScreenPreview) {
                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    FullScreenPreviewView(
                        phrases: TextSplitter.split(inputText),
                        animationType: DeterministicAnimationEngine.AnimationType.typewriter,
                        duration: DeterministicAnimationEngine.calculateVideoDuration(for: TextSplitter.split(inputText), speedMultiplier: animationSpeed),
                        backgroundColor: themeManager.effectiveBackgroundColor,
                        textColor: themeManager.effectiveTextColor,
                        fontStyle: FontStyle.system,
                        speedMultiplier: animationSpeed
                    )
                    .environmentObject(iapManager)
                    .environmentObject(permissionManager)
                    .environmentObject(settingsManager)
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
    }
    
    // MARK: - Enhanced Header
    
    private var cleanHeader: some View {
        VStack(spacing: 12) {
            // App title with enhanced styling
            Text("Twimotion")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .primary,
                            .blue,
                            .purple,
                            .pink
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Enhanced tagline with better typography
            Text("Transform your words into scroll-stopping videos.")
                .font(.system(size: 16, weight: .medium, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 8)
            
            // Optional status indicator for free users
            if !iapManager.isProUser {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("Free Plan - \(iapManager.remainingGIFsToday) videos left today")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    
    // MARK: - Control Buttons
    
    private var styleButtons: some View {
        HStack(spacing: 12) {
            // Theme button
            VStack(spacing: 8) {
                Text("Theme")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    showingThemeSelection = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "paintpalette")
                            .font(.title3)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Circle()
                                .fill(themeManager.effectiveBackgroundColor)
                                .frame(width: 12, height: 12)
                            Circle()
                                .fill(themeManager.effectiveTextColor)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(.systemGray5),
                                        Color.blue.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Speed button
            VStack(spacing: 8) {
                Text("Speed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                speedDropdownButton
            }
            
            // Clear button
            VStack(spacing: 8) {
                Text("Clear")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: clearText) {
                    Image(systemName: "xmark.circle")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            .red,
                                            .red.opacity(0.8)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    
    private var speedDropdownButton: some View {
        Menu {
            ForEach(speedOptions, id: \.value) { option in
                Button(action: {
                    animationSpeed = option.value
                }) {
                    HStack {
                        Text(option.label)
                        if animationSpeed == option.value {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "speedometer")
                    .font(.title3)
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemGray5),
                                Color.purple.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
    }
    
    // Speed options for dropdown
    private var speedOptions: [(label: String, value: Double)] {
        [
            ("0.5x", 0.5),
            ("0.75x", 0.75),
            ("1x", 1.0),
            ("1.25x", 1.25),
            ("1.5x", 1.5),
            ("2x", 2.0)
        ]
    }
    
    private var speedIcon: String {
        switch animationSpeed {
        case 0.5..<0.8:
            return "tortoise"
        case 0.8..<1.2:
            return "play.circle"
        case 1.2..<1.6:
            return "bolt.circle"
        case 1.6...2.0:
            return "hare"
        default:
            return "play.circle"
        }
    }
    
    private var speedLabel: String {
        switch animationSpeed {
        case 0.5..<0.8:
            return "Slow (\(String(format: "%.1f", animationSpeed))x)"
        case 0.8..<1.2:
            return "Normal (\(String(format: "%.1f", animationSpeed))x)"
        case 1.2..<1.6:
            return "Fast (\(String(format: "%.1f", animationSpeed))x)"
        case 1.6...2.0:
            return "Very Fast (\(String(format: "%.1f", animationSpeed))x)"
        default:
            return "Normal (1.0x)"
        }
    }
    
    
    
    // MARK: - Enhanced Text Input
    
    private var textInputWithEnhance: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Enhanced background with gradient and shadow - dynamic height
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemBackground),
                                Color(.systemGray6).opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(minHeight: 160, maxHeight: 300)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.3),
                                        Color.purple.opacity(0.2),
                                        Color.pink.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 0) {
                    if inputText.isEmpty {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.yellow.opacity(0.8),
                                                Color.orange.opacity(0.6)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 32, height: 32)
                                
                                Text("💡")
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Write your idea...")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Transform your thoughts into engaging videos")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    TextEditor(text: $inputText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80, maxHeight: 200)
                        .onChange(of: inputText) {
                            updateSplitPreview()
                        }
                    
                    // Enhanced bottom section with extended character counter
                    HStack {
                        // Extended character counter with status
                        HStack(spacing: 6) {
                            // Character counter
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(characterCountColor)
                                    .frame(width: 8, height: 8)
                                
                                Text("\(characterCount) / \(maxCharacters)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(characterCountColor)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(characterCountColor.opacity(0.1))
                            )
                            
                            // Text status indicator
                            if !inputText.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: isTextTooLong ? "exclamationmark.triangle.fill" : shouldShowWarning ? "exclamationmark.triangle" : "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(characterCountColor)
                                    
                                    Text(textStatusMessage)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(characterCountColor)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(characterCountColor.opacity(0.1))
                                )
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // Character count color based on usage
    private var characterCountColor: Color {
        if isTextTooLong {
            return .red
        } else if shouldShowWarning {
            return .orange
        } else {
            return .secondary
        }
    }
    
    
    // Text status message
    private var textStatusMessage: String {
        if isTextTooLong {
            return "Too long"
        } else if shouldShowWarning {
            return "Getting long"
        } else {
            return "Good length"
        }
    }
    
    
    
    // MARK: - Preview Button
    
    private var previewButton: some View {
        Button(action: {
            showingFullScreenPreview = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preview Animation")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Tap to turn your words into motion.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .blue,
                                .purple,
                                .pink
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Export Your Video")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 16) {
                // Enhanced export button
                Button(action: {
                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if !iapManager.canCreateMoreGIFs {
                            showingProUpgrade = true
                        } else if !permissionManager.hasPhotoLibraryPermission {
                            // Request permission or show settings alert
                            requestPhotosPermission()
                        } else {
                            startExport()
                        }
                    }
                }) {
                    HStack(spacing: 16) {
                        if mp4Exporter.isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mp4Exporter.isExporting ? "Exporting..." : exportButtonTitle)
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(mp4Exporter.isExporting ? "Creating your animated video" : exportButtonSubtitle)
                                .font(.caption)
                                .opacity(0.9)
                        }
                        .padding(.horizontal, 8)
                        
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(exportButtonColor)
                            .shadow(color: exportButtonColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .disabled(inputText.isEmpty || mp4Exporter.isExporting || isTextTooLong || !iapManager.canCreateMoreGIFs || !permissionManager.hasPhotoLibraryPermission)
                .scaleEffect((inputText.isEmpty || mp4Exporter.isExporting || isTextTooLong || !iapManager.canCreateMoreGIFs || !permissionManager.hasPhotoLibraryPermission) ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: mp4Exporter.isExporting)
            
                // Permission status indicator
                if !permissionManager.hasPhotoLibraryPermission {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 16))
                        
                        Text("Photos permission required to export videos")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Button("Grant Access") {
                            requestPhotosPermission()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Export progress
                if mp4Exporter.isExporting {
                    VStack(spacing: 16) {
                        // Enhanced progress bar
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("Creating your video...")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(mp4Exporter.exportProgress * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                            
                            ProgressView(value: mp4Exporter.exportProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                                .frame(height: 8)
                                .background(Color(.systemGray5))
                                .cornerRadius(6)
                        }
                        
                        // Progress details
                        HStack {
                            Text("Frame \(mp4Exporter.currentFrame) of \(mp4Exporter.totalFrames)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // Estimated time remaining
                            if mp4Exporter.estimatedTimeRemaining > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "timer")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("~\(Int(mp4Exporter.estimatedTimeRemaining))s left")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .orange.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Text too long message
                if isTextTooLong {
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Text Too Long")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                
                                Text("Please keep text under \(maxCharacters) characters for optimal performance")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Button(action: {
                            // Truncate text to max characters
                            inputText = String(inputText.prefix(maxCharacters))
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "scissors")
                                    .font(.subheadline)
                                Text("Trim to \(maxCharacters) characters")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                            )
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .red.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Export completed message
                if _exportedVideoURL != nil, !mp4Exporter.isExporting {
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("GIF Ready!")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                
                                Text("Your animated GIF has been created successfully")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
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
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.blue)
                                )
                            }
                            
                            Button(action: {
                                saveToPhotos()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.subheadline)
                                    Text("Save to Photos")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.green)
                                )
                            }
                            
                            Spacer()
                        }
                        
                        // Auto-save status indicator
                        if settingsManager.isAutoSaveEnabled {
                            HStack {
                                Image(systemName: autoSavedToPhotos ? "checkmark.circle.fill" : "clock.circle.fill")
                                    .foregroundColor(autoSavedToPhotos ? .green : .orange)
                                    .font(.subheadline)
                                
                                Text(autoSavedToPhotos ? "Auto-saved to Photos" : "Auto-saving to Photos...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .green.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
            )
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
    
    // MARK: - Character Counter View
    
    private var characterCounterView: some View {
        Text("\(characterCount) / \(maxCharacters)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    // MARK: - Helper Methods
    
    private func requestPhotosPermission() {
        Task {
            let granted = await permissionManager.requestPhotoLibraryPermission()
            
            await MainActor.run {
                if granted {
                    showToast("Photos permission granted! You can now export GIFs.")
                } else {
                    showToast("Photos permission is required to save GIFs.")
                }
            }
        }
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        showingToast = true
        
        // Auto-hide toast after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingToast = false
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let clipboardText = UIPasteboard.general.string {
            inputText = clipboardText
            updateSplitPreview()
            showToast("Text pasted! Preview your animation below")
        }
    }
    
    private func clearText() {
        inputText = ""
        splitPreview = nil
        showToast("Text cleared")
    }
    
    private func updateSplitPreview() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty {
            splitPreview = TextSplitter.splitPreview(trimmedText)
        } else {
            splitPreview = nil
        }
    }
    
    // MARK: - Export Methods
    
    private func startExport() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            return 
        }
        
        // Check if user can create more videos
        guard iapManager.canCreateMoreGIFs else {
            showToast("Daily limit reached! Upgrade to Pro for unlimited videos.")
            return
        }
        
        showToast("Starting video export...")
        
        let phrases = TextSplitter.split(inputText)
        let duration = DeterministicAnimationEngine.calculateVideoDuration(for: phrases, speedMultiplier: animationSpeed)
        
        let exportConfig = MP4Exporter.MP4ExportConfiguration(
            phrases: phrases,
            preset: currentPreset,
            duration: duration,
            includeWatermark: true // Always include watermark for branding
        )
        
        mp4Exporter.exportMP4(config: exportConfig) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    // Record video creation for daily limit tracking
                    self.iapManager.recordGIFCreation()
                    
                    self._exportedVideoURL = url
                    self.showToast("Video exported successfully! Ready to share.")
                    
                    // Auto-save to Photos if enabled
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
        guard let videoURL = _exportedVideoURL else { return }
        
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
        guard let videoURL = _exportedVideoURL else { return }
        
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
    
    // MARK: - Timer Methods
    
    private func startCountdownTimer() {
        // Only start timer for free users
        guard !iapManager.isProUser else { return }
        
        stopCountdownTimer() // Stop any existing timer
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            countdownUpdateTrigger.toggle() // Trigger UI update
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
}




#Preview {
    HomeView()
}

