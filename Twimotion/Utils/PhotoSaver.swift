//
//  PhotoSaver.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Photo Saver Utility

class PhotoSaver: ObservableObject {
    @Published var isSaving = false
    @Published var saveError: String?
    
    private let gifExporter = GIFExporter()
    
    /// Save GIF to Photos with completion handler
    /// - Parameters:
    ///   - gifURL: URL of the GIF file to save
    ///   - completion: Completion handler with success/failure result
    func saveToPhotos(gifURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !isSaving else { return }
        
        isSaving = true
        saveError = nil
        
        gifExporter.saveToPhotos(gifURL: gifURL) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    self.saveError = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Auto-save GIF to Photos (used during export process)
    /// - Parameters:
    ///   - gifURL: URL of the GIF file to save
    ///   - completion: Completion handler with success/failure result
    func autoSaveToPhotos(gifURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        saveToPhotos(gifURL: gifURL, completion: completion)
    }
}
