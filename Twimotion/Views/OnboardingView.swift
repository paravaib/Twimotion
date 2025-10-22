//
//  OnboardingView.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import SwiftUI
import Photos

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var permissionManager = PermissionManager()
    @State private var currentStep = 0
    @State private var showingPermissionRequest = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // Onboarding content based on current step
                if currentStep == 0 {
                    welcomeStep
                } else if currentStep == 1 {
                    permissionStep
                }
                
                Spacer()
                
                // Navigation buttons
                navigationButtons
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Skip") { 
                UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                dismiss() 
            })
        }
    }
    
    // MARK: - Step Views
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome to Twimotion")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                onboardingStep(
                    icon: "doc.text",
                    title: "Type Your Text",
                    description: "Enter or paste your text to animate"
                )
                
                onboardingStep(
                    icon: "play.rectangle",
                    title: "Preview",
                    description: "Watch your text come alive with typewriter animation"
                )
                
                onboardingStep(
                    icon: "square.and.arrow.up",
                    title: "Export",
                    description: "Save and share your typewriter animation"
                )
            }
        }
    }
    
    private var permissionStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Photo Library Access")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Image(systemName: permissionManager.photoLibraryPermissionIcon)
                        .font(.title2)
                        .foregroundColor(permissionManager.photoLibraryPermissionColor)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Save Your GIFs")
                            .font(.headline)
                        Text(permissionManager.photoLibraryPermissionMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if !permissionManager.hasPhotoLibraryPermission {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Your GIFs will be saved automatically")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var navigationButtons: some View {
        VStack(spacing: 16) {
            if currentStep == 0 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        currentStep = 1
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            } else {
                VStack(spacing: 12) {
                    if permissionManager.hasPhotoLibraryPermission {
                        Button(action: {
                            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                            dismiss()
                        }) {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    } else {
                        Button(action: {
                            Task {
                                await permissionManager.requestPhotoLibraryPermission()
                            }
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Allow Photo Access")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                            dismiss()
                        }) {
                            Text("Skip for Now")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func onboardingStep(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
