//
//  HomeView.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI
import Combine


/// Main home screen with text input and creation flow
struct HomeView: View {
    @EnvironmentObject var iapManager: IAPManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var inputText: String = ""
    @State private var splitPreview: SplitPreview?
    @State private var showingOnboarding = false
    @State private var showingFullScreenPreview = false
    @State private var showingThemeSelection = false
    @State private var toastMessage: String = ""
    @State private var showingToast = false
    @StateObject private var gifExporter = GIFExporter()
    @StateObject private var photoSaver = PhotoSaver()
    @State private var showingShareSheet = false
    @State private var _exportedGIFURL: URL?
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
            return "Enter text to create GIF"
        }
        if isTextTooLong {
            return "Text too long"
        }
        if !iapManager.canCreateMoreGIFs {
            return "Daily Limit Reached"
        }
        if gifExporter.isExporting {
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
            return "Upgrade to Pro for unlimited GIFs"
        }
        if gifExporter.isExporting {
            return "Creating your animated GIF"
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
        return gifExporter.isExporting ? Color.orange : Color.blue
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
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Speed control
                    speedControlSection
                    
                    // Manual settings section
                    manualSettingsSection
                    
                    // Text input section
                    textInputSection
                    
                    // Animation preview
                    if !inputText.isEmpty {
                        animationPreviewSection
                    }
                    
                    // Export section
                    if !inputText.isEmpty {
                        exportSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Twimotion")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button(action: {
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
                let newDuration = DeterministicAnimationEngine.calculateGIFDuration(for: TextSplitter.split(inputText), speedMultiplier: newSpeed)
                print("DEBUG: Animation speed changed from \(oldSpeed) to \(newSpeed), new duration: \(newDuration)")
            }
            .onChange(of: themeManager.selectedTheme) { oldTheme, newTheme in
                // Theme changed - force preview refresh
                previewKey = UUID()
                print("DEBUG: Theme changed from \(oldTheme.name) to \(newTheme.name)")
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
                if let url = _exportedGIFURL {
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
                        preset: currentPreset,
                        duration: DeterministicAnimationEngine.calculateGIFDuration(for: TextSplitter.split(inputText), speedMultiplier: animationSpeed),
                        speedMultiplier: animationSpeed
                    )
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
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Text("Transform your words into captivating animated GIFs")
                .font(.title2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            // Daily limit status
            dailyLimitStatusView
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Daily Limit Status View
    
    private var dailyLimitStatusView: some View {
        HStack(spacing: 12) {
            if iapManager.isProUser {
                // Pro user status
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.subheadline)
                    
                    Text("Pro - Unlimited GIFs")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                // Free user status
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.blue)
                            .font(.subheadline)
                        
                        if iapManager.remainingGIFsToday > 0 {
                            Text("\(iapManager.remainingGIFsToday) GIFs left today")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        } else {
                            Text("Daily limit reached")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Countdown timer
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text("Resets in \(iapManager.formattedTimeUntilReset)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .id(countdownUpdateTrigger) // Force update when timer triggers
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iapManager.remainingGIFsToday > 0 ? Color.blue.opacity(0.1) : Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(iapManager.remainingGIFsToday > 0 ? Color.blue.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Upgrade button
                if iapManager.remainingGIFsToday == 0 {
                    Button(action: {
                        showingProUpgrade = true
                    }) {
                        Text("Upgrade")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Speed Control Section
    
    private var speedControlSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "speedometer")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("Animation Speed")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 16) {
                // Speed slider with enhanced styling
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "tortoise")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Slow")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Fast")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: "hare")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $animationSpeed, in: 0.5...2.0, step: 0.1)
                        .accentColor(.blue)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 6)
                        )
                }
                
                // Enhanced speed indicator
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: speedIcon)
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(speedLabel)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .animation(.easeInOut(duration: 0.3), value: animationSpeed)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
        }
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
    
    // MARK: - Manual Settings Section
    
    private var manualSettingsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "paintpalette")
                    .foregroundColor(.purple)
                    .font(.title3)
                Text("Customize Style")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 24) {
                // Theme selection
                themeSelectionSection
                
                // Advanced customization (only show if custom theme is selected)
                if themeManager.selectedTheme.isCustom {
                    advancedCustomizationSection
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
    
    // MARK: - Theme Selection Section
    
    private var themeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                    .font(.subheadline)
                Text("Theme")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Button(action: {
                showingThemeSelection = true
            }) {
                HStack(spacing: 16) {
                    // Theme preview
                    HStack(spacing: 8) {
                        Circle()
                            .fill(themeManager.effectiveBackgroundColor)
                            .frame(width: 24, height: 24)
                        
                        Circle()
                            .fill(themeManager.effectiveTextColor)
                            .frame(width: 24, height: 24)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(themeManager.selectedTheme.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(themeManager.selectedTheme.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Colors: \(themeManager.effectiveBackgroundColor.toHex()) / \(themeManager.effectiveTextColor.toHex())")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.effectiveTextColor.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    
    // MARK: - Advanced Customization Section
    
    private var advancedCustomizationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.green)
                    .font(.subheadline)
                Text("Advanced Customization")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 16) {
                // Background color control
                colorControlRow(
                    title: "Background",
                    color: $themeManager.customBackgroundColor,
                    icon: "paintpalette",
                    iconColor: .green
                )
                
                // Text color control
                colorControlRow(
                    title: "Text",
                    color: $themeManager.customTextColor,
                    icon: "textformat",
                    iconColor: .orange
                )
            }
        }
    }
    
    private func colorControlRow(title: String, color: Binding<Color>, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.subheadline)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            ColorPicker("", selection: color, supportsOpacity: false)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.wrappedValue)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Text Input Section
    
    private var textInputSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundColor(.cyan)
                    .font(.title3)
                Text("Enter Your Text")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 16) {
                // Action buttons
                HStack(spacing: 16) {
                    Button(action: pasteFromClipboard) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.subheadline)
                            Text("Paste")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                        )
                    }
                    
                    Spacer()
                    
                    Button(action: clearText) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                                .font(.subheadline)
                            Text("Clear")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.gray)
                        )
                    }
                }
                
                // Enhanced text input area
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .frame(minHeight: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                    
                    if inputText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Start typing your message...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                            
                            Text("Tips: Use line breaks for better formatting")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.7))
                                .padding(.horizontal, 24)
                        }
                    }
                    
                    TextEditor(text: $inputText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                        .font(.body)
                        .onChange(of: inputText) {
                            updateSplitPreview()
                        }
                        .overlay(
                            // Character counter overlay
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    characterCounterView
                                        .padding(.trailing, 16)
                                        .padding(.bottom, 16)
                                }
                            }
                        )
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
    
    
    
    // MARK: - Animation Preview Section
    
    private var animationPreviewSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "play.rectangle")
                    .foregroundColor(.indigo)
                    .font(.title3)
                Text("Live Preview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    showingFullScreenPreview = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                        Text("Full Screen")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.indigo)
                    )
                }
            }
            
            PreviewView(
                phrases: TextSplitter.split(inputText),
                preset: currentPreset,
                duration: DeterministicAnimationEngine.calculateGIFDuration(for: TextSplitter.split(inputText), speedMultiplier: animationSpeed),
                speedMultiplier: animationSpeed
            )
            .id(previewKey)
            .frame(height: 420)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.indigo.opacity(0.1),
                                Color.purple.opacity(0.1),
                                Color.pink.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.indigo.opacity(0.3), Color.purple.opacity(0.3)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .indigo.opacity(0.2), radius: 12, x: 0, y: 6)
            )
            .cornerRadius(24)
            .onTapGesture {
                showingFullScreenPreview = true
            }
            .onAppear {
                showToast("Preview ready! Speed: \(speedLabel) • Tap to view full screen")
            }
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Export Your GIF")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 16) {
                // Enhanced export button
                Button(action: {
                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if !iapManager.canCreateMoreGIFs {
                            showingProUpgrade = true
                        } else {
                            startExport()
                        }
                    }
                }) {
                    HStack(spacing: 16) {
                        if gifExporter.isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(gifExporter.isExporting ? "Exporting..." : exportButtonTitle)
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(gifExporter.isExporting ? "Creating your animated GIF" : exportButtonSubtitle)
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
                .disabled(inputText.isEmpty || gifExporter.isExporting || isTextTooLong || !iapManager.canCreateMoreGIFs)
                .scaleEffect((inputText.isEmpty || gifExporter.isExporting || isTextTooLong || !iapManager.canCreateMoreGIFs) ? 0.98 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: gifExporter.isExporting)
            
                // Export progress
                if gifExporter.isExporting {
                    VStack(spacing: 16) {
                        // Enhanced progress bar
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Text("Creating your GIF...")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(Int(gifExporter.exportProgress * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.orange)
                            }
                            
                            ProgressView(value: gifExporter.exportProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                                .frame(height: 8)
                                .background(Color(.systemGray5))
                                .cornerRadius(6)
                        }
                        
                        // Progress details
                        HStack {
                            Text("Frame \(gifExporter.currentFrame) of \(gifExporter.totalFrames)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            // Estimated time remaining
                            if gifExporter.estimatedTimeRemaining > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "timer")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("~\(Int(gifExporter.estimatedTimeRemaining))s left")
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
                if let exportedURL = _exportedGIFURL, !gifExporter.isExporting {
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
        VStack(spacing: 4) {
            if isTextTooLong {
                // Error state - text too long
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("\(characterCount)/\(maxCharacters)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            } else if shouldShowWarning {
                // Warning state - approaching limit
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("\(remainingCharacters) left")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            } else {
                // Normal state
                Text("\(characterCount)/\(maxCharacters)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray6))
                    )
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
            print("DEBUG: Export blocked - no text entered")
            return 
        }
        
        // Check if user can create more GIFs
        guard iapManager.canCreateMoreGIFs else {
            print("DEBUG: Export blocked - daily limit reached")
            showToast("Daily limit reached! Upgrade to Pro for unlimited GIFs.")
            return
        }
        
        print("DEBUG: Starting export - text: '\(inputText)', canCreateMoreGIFs: \(iapManager.canCreateMoreGIFs)")
        showToast("Starting GIF export...")
        
        let phrases = TextSplitter.split(inputText)
        let duration = DeterministicAnimationEngine.calculateGIFDuration(for: phrases, speedMultiplier: animationSpeed)
        
        let exportConfig = GIFExporter.ExportConfiguration(
            phrases: phrases,
            preset: currentPreset,
            duration: duration,
            fps: currentPreset.template.defaultFPS,
            size: CGSize(width: 1080, height: 1080),
            quality: .optimized,
            includeWatermark: true // Always include watermark for branding
        )
        
        gifExporter.exportGIF(config: exportConfig) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    // Record GIF creation for daily limit tracking
                    self.iapManager.recordGIFCreation()
                    
                    self._exportedGIFURL = url
                    self.showToast("GIF exported successfully! Ready to share.")
                    
                    // Auto-save to Photos if enabled
                    print("DEBUG: Auto-save enabled: \(self.settingsManager.isAutoSaveEnabled)")
                    if self.settingsManager.isAutoSaveEnabled {
                        print("DEBUG: Starting auto-save to Photos...")
                        self.autoSaveToPhotos()
                    } else {
                        print("DEBUG: Auto-save is disabled, skipping auto-save")
                    }
                case .failure(let error):
                    self.showToast("Export failed: \(error.localizedDescription)")
                    print("Export error: \(error)")
                }
            }
        }
    }
    
    private func saveToPhotos() {
        guard let gifURL = _exportedGIFURL else { return }
        
        photoSaver.saveToPhotos(gifURL: gifURL) { result in
            switch result {
            case .success:
                self.showToast("GIF saved to Photos!")
            case .failure(let error):
                self.showToast("Failed to save to Photos: \(error.localizedDescription)")
            }
        }
    }
    
    private func autoSaveToPhotos() {
        guard let gifURL = _exportedGIFURL else { return }
        
        photoSaver.autoSaveToPhotos(gifURL: gifURL) { result in
            switch result {
            case .success:
                self.autoSavedToPhotos = true
                self.showToast("Auto-saved to Photos successfully!")
                print("Auto-saved to Photos successfully")
            case .failure(let error):
                self.showToast("Auto-save failed: \(error.localizedDescription)")
                print("Auto-save to Photos failed: \(error.localizedDescription)")
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

