//
//  PermissionManager.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import SwiftUI
import Photos
import Combine

/// Manages app permissions with user-friendly explanations
class PermissionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var photoLibraryPermissionStatus: PHAuthorizationStatus = .notDetermined
    @Published var hasRequestedPhotoLibraryPermission = false
    
    // MARK: - Constants
    
    private let userDefaults = UserDefaults.standard
    private enum Keys {
        static let hasRequestedPhotoLibraryPermission = "hasRequestedPhotoLibraryPermission"
    }
    
    // MARK: - Initialization
    
    init() {
        loadPermissionState()
        checkPhotoLibraryPermission()
        
        // Monitor for permission changes
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkPhotoLibraryPermission()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Photo Library Permission
    
    /// Check current photo library permission status
    func checkPhotoLibraryPermission() {
        let newStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        // Only update if status changed to trigger UI refresh
        if newStatus != photoLibraryPermissionStatus {
            photoLibraryPermissionStatus = newStatus
            print("📸 Photo library permission status updated: \(newStatus)")
        }
    }
    
    /// Request photo library permission with explanation
    func requestPhotoLibraryPermission() async -> Bool {
        hasRequestedPhotoLibraryPermission = true
        userDefaults.set(true, forKey: Keys.hasRequestedPhotoLibraryPermission)
        
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        
        await MainActor.run {
            self.photoLibraryPermissionStatus = status
        }
        
        return status == .authorized || status == .limited
    }
    
    /// Check if photo library permission is granted
    var hasPhotoLibraryPermission: Bool {
        return photoLibraryPermissionStatus == .authorized || photoLibraryPermissionStatus == .limited
    }
    
    /// Get user-friendly permission status message
    var photoLibraryPermissionMessage: String {
        switch photoLibraryPermissionStatus {
        case .notDetermined:
            return "We need access to your photo library to save your animated GIFs so you can share them with others."
        case .denied, .restricted:
            return "Photo library access is required to save your GIFs. You can enable it in Settings > Privacy & Security > Photos > Twimotion."
        case .authorized, .limited:
            return "Photo library access granted! Your GIFs will be saved automatically."
        @unknown default:
            return "Please check your photo library permissions in Settings."
        }
    }
    
    /// Get permission status icon
    var photoLibraryPermissionIcon: String {
        switch photoLibraryPermissionStatus {
        case .notDetermined:
            return "questionmark.circle"
        case .denied, .restricted:
            return "exclamationmark.triangle"
        case .authorized, .limited:
            return "checkmark.circle"
        @unknown default:
            return "questionmark.circle"
        }
    }
    
    /// Get permission status color
    var photoLibraryPermissionColor: Color {
        switch photoLibraryPermissionStatus {
        case .notDetermined:
            return .blue
        case .denied, .restricted:
            return .red
        case .authorized, .limited:
            return .green
        @unknown default:
            return .blue
        }
    }
    
    // MARK: - Private Methods
    
    private func loadPermissionState() {
        hasRequestedPhotoLibraryPermission = userDefaults.bool(forKey: Keys.hasRequestedPhotoLibraryPermission)
    }
    
    /// Open app settings for permission management
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    /// Force refresh permission status (useful for testing)
    func refreshPermissionStatus() {
        checkPhotoLibraryPermission()
    }
}
