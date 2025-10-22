//
//  PhotoSaver.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import SwiftUI
import Combine
import Photos

// MARK: - Photo Saver Utility

class PhotoSaver: ObservableObject {
    @Published var isSaving = false
    @Published var saveError: String?
    
    /// Save video to Photos with completion handler
    /// - Parameters:
    ///   - videoURL: URL of the video file to save
    ///   - completion: Completion handler with success/failure result
    func saveToPhotos(videoURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isSaving else { return }
        
        isSaving = true
        saveError = nil
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.saveError = "Photos permission denied"
                    completion(.failure(PhotoSaveError.permissionDenied))
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                DispatchQueue.main.async {
                    self.isSaving = false
                    
                    if success {
                        completion(.success(()))
                    } else {
                        self.saveError = error?.localizedDescription ?? "Unknown error"
                        completion(.failure(error ?? PhotoSaveError.unknownError))
                    }
                }
            }
        }
    }
    
    /// Auto-save video to Photos (used during export process)
    /// - Parameters:
    ///   - videoURL: URL of the video file to save
    ///   - completion: Completion handler with success/failure result
    func autoSaveToPhotos(videoURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        saveToPhotos(videoURL: videoURL, completion: completion)
    }
}

// MARK: - Photo Save Errors

enum PhotoSaveError: LocalizedError {
    case permissionDenied
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photos permission denied"
        case .unknownError:
            return "Unknown error saving to Photos"
        }
    }
}
