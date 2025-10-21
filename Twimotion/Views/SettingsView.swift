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
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var iapManager: IAPManager
    @State private var showingOnboarding = false
    @State private var showingAbout = false
    @State private var showingProUpgrade = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var showingSupport = false
    
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
            .sheet(isPresented: $showingProUpgrade) {
                ProUpgradeView()
                    .environmentObject(iapManager)
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                LegalView(title: "Privacy Policy", htmlFileName: "PrivacyPolicy")
            }
            .sheet(isPresented: $showingTermsOfService) {
                LegalView(title: "Terms of Service", htmlFileName: "TermsOfService")
            }
            .sheet(isPresented: $showingSupport) {
                LegalView(title: "Support & Contact", htmlFileName: "Support")
            }
        }
    }
    
    
    // MARK: - App Settings Section
    
    private var appSettingsSection: some View {
        Group {
            Section {
                // Auto-save setting
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("Auto-save to Photos")
                    
                    Spacer()
                    
                    Toggle("", isOn: $settingsManager.autoSaveToPhotos)
                        .labelsHidden()
                }
            } header: {
                Text("App Settings")
            }
            
            // Pro subscription section
            proSubscriptionSection
        }
    }
    
    // MARK: - Pro Subscription Section
    
    private var proSubscriptionSection: some View {
        Section {
            if iapManager.isProUser {
                // Pro user status
                HStack(spacing: 16) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pro Active")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Unlimited GIFs • No daily limits")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        VStack(spacing: 8) {
                            Button(action: {
                                Task {
                                    await iapManager.restorePurchases()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    if iapManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                            .scaleEffect(0.8)
                                    }
                                    Text("Restore")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                            }
                            .disabled(iapManager.isLoading)
                            
                            // Debug buttons (remove in production)
                            #if DEBUG
                            Button(action: {
                                Task {
                                    await iapManager.forceCheckSubscriptionStatus()
                                }
                            }) {
                                Text("Force Check")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            
                            Button(action: {
                                iapManager.resetProStatus()
                            }) {
                                Text("Reset Status")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            
                            Button(action: {
                                iapManager.manualResetDailyGIFs()
                            }) {
                                Text("Reset GIFs")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                            #endif
                        }
                    }
                }
                .padding(.vertical, 8)
            } else {
                // Free user - show upgrade option
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upgrade to Pro")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Unlimited GIFs • Remove daily limits")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Daily limit status
                    HStack {
                        Text("Daily GIFs:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(iapManager.remainingGIFsToday == -1 ? "Unlimited" : "\(iapManager.remainingGIFsToday)/2")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(iapManager.remainingGIFsToday == -1 ? .green : .blue)
                    }
                    
                    // Upgrade button
                    Button(action: {
                        showingProUpgrade = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.subheadline)
                            
                            Text("Upgrade to Pro")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Debug button for free users (remove in production)
                    #if DEBUG
                    HStack {
                        Spacer()
                        Button(action: {
                            iapManager.manualResetDailyGIFs()
                        }) {
                            Text("Reset GIFs (Debug)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                    #endif
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text("Subscription")
        }
    }
    
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Group {
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
            
            // Legal section
            legalSection
        }
    }
    
    // MARK: - Legal Section
    
    private var legalSection: some View {
        Section {
            // Privacy Policy
            Button(action: {
                showingPrivacyPolicy = true
            }) {
                HStack {
                    Image(systemName: "hand.raised")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    Text("Privacy Policy")
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            // Terms of Service
            Button(action: {
                showingTermsOfService = true
            }) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("Terms of Service")
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            // Support & Contact
            Button(action: {
                showingSupport = true
            }) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    
                    Text("Support & Contact")
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
        } header: {
            Text("Legal & Support")
        }
    }
}

// MARK: - Supporting Views

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
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
                dismiss()
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
        .environmentObject(SettingsManager())
        .environmentObject(IAPManager.shared)
}
