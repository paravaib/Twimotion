//
//  ThemeSelectionView.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI

// MARK: - Theme Selection View

struct ThemeSelectionView: View {
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingCustomColors = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Quick theme selection
                    quickThemeSection
                    
                    // Custom theme section
                    customThemeSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
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
            .navigationTitle("Choose Theme")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
            .sheet(isPresented: $showingCustomColors) {
                CustomColorView(themeManager: themeManager)
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Text("Choose Your Theme")
                .font(.title2)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            Text("Select a predefined theme or create your own custom colors")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Quick Theme Section
    
    private var quickThemeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                Text("Choose Theme")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(themeManager.properThemes, id: \.id) { theme in
                    QuickThemeCard(
                        theme: theme,
                        isSelected: themeManager.selectedTheme.id == theme.id,
                        onSelect: {
                            themeManager.selectTheme(theme)
                        }
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        )
    }
    
    
    // MARK: - Custom Theme Section
    
    private var customThemeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "paintpalette")
                    .foregroundColor(.purple)
                    .font(.title3)
                Text("Custom Theme")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Button(action: {
                themeManager.enableCustomTheme()
                showingCustomColors = true
            }) {
                HStack(spacing: 16) {
                    // Color preview
                    HStack(spacing: 8) {
                        Circle()
                            .fill(themeManager.customBackgroundColor)
                            .frame(width: 24, height: 24)
                        
                        Circle()
                            .fill(themeManager.customTextColor)
                            .frame(width: 24, height: 24)
                        
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Colors")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Create your own color combination")
                            .font(.caption)
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
                        .fill(themeManager.selectedTheme.isCustom ? Color.blue.opacity(0.1) : Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(themeManager.selectedTheme.isCustom ? Color.blue : Color.clear, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
        )
    }
}

// MARK: - Quick Theme Card

struct QuickThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // Color preview
                HStack(spacing: 6) {
                    Circle()
                        .fill(theme.colorScheme.backgroundColor)
                        .frame(width: 20, height: 20)
                    
                    Circle()
                        .fill(theme.colorScheme.primaryColor)
                        .frame(width: 20, height: 20)
                }
                
                VStack(spacing: 4) {
                    Text(theme.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(theme.platform.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? theme.colorScheme.primaryColor.opacity(0.1) : Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSelected ? theme.colorScheme.primaryColor : Color.clear, lineWidth: 2)
                            )
                    )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// MARK: - Custom Color View

struct CustomColorView: View {
    @ObservedObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Customize Your Theme")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        Text("Choose your own colors for a unique look")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)
                    
                    // Color controls
                    VStack(spacing: 20) {
                        // Background color
                        colorControlSection(
                            title: "Background Color",
                            color: $themeManager.customBackgroundColor,
                            icon: "paintpalette",
                            iconColor: .green
                        )
                        
                        // Text color
                        colorControlSection(
                            title: "Text Color",
                            color: $themeManager.customTextColor,
                            icon: "textformat",
                            iconColor: .orange
                        )
                        
                    }
                    
                    // Preview
                    themePreviewSection
                }
                .padding(.horizontal, 20)
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
            .navigationTitle("Custom Colors")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    themeManager.enableCustomTheme()
                    dismiss()
                }
            )
        }
    }
    
    private func colorControlSection(title: String, color: Binding<Color>, icon: String, iconColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            HStack(spacing: 16) {
                // Color picker
                ColorPicker("", selection: color, supportsOpacity: false)
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(color.wrappedValue)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(color.wrappedValue.toHex())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Tap to change color")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private var themePreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text("Preview")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            VStack(spacing: 16) {
                // Preview card
                VStack(spacing: 12) {
                    Text("Sample Text")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.customTextColor)
                    
                    Text("This is how your animation will look")
                        .font(.subheadline)
                        .foregroundColor(themeManager.customTextColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(themeManager.customBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(themeManager.customTextColor, lineWidth: 2)
                        )
                )
                
                // Color info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Background")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(themeManager.customBackgroundColor.toHex())
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(themeManager.customTextColor.toHex())
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                }
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

#Preview {
    ThemeSelectionView(themeManager: ThemeManager())
}
