//
//  SettingsView.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI
import Combine

/// Settings view with app configuration and premium features
struct SettingsView: View {
    @State private var showingOnboarding = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            List {
                // App settings
                appSettingsSection
                
                // About section
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
    
    
    // MARK: - App Settings Section
    
    private var appSettingsSection: some View {
        Section {
            // Auto-save setting
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text("Auto-save to Photos")
                
                Spacer()
                
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
            }
        } header: {
            Text("App Settings")
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            // Show onboarding
            Button(action: {
                showingOnboarding = true
            }) {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("How to Use")
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            // About app
            Button(action: {
                showingAbout = true
            }) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("About Twimotion")
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
        } header: {
            Text("About")
        }
    }
}

// MARK: - Supporting Views

struct AboutView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App icon and name
                    VStack(spacing: 16) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Twimotion")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About Twimotion")
                            .font(.headline)
                        
                        Text("Twimotion transforms your text into stunning animated GIFs using kinetic typography. Create engaging content for social media with just a few taps.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            featureRow(icon: "paintpalette", title: "Beautiful Animation Styles")
                            featureRow(icon: "photo", title: "HD GIF Export")
                            featureRow(icon: "square.and.arrow.up", title: "Easy Sharing")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                // Dismiss
            })
        }
    }
    
    private func featureRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
        }
    }
}

#Preview {
    SettingsView()
}
