//
//  GIFExporter.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import AVFoundation
import SwiftUI
import Photos
import Combine
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

/// GIF export utility that creates animated GIFs from text posts
class GIFExporter: ObservableObject {
    
    // MARK: - Export Configuration
    
    struct ExportConfiguration {
        let phrases: [String]
        let preset: AnimationPreset
        let duration: Double
        let fps: Int
        let size: CGSize
        let quality: GIFQuality
        let includeWatermark: Bool
        
        enum GIFQuality {
            case optimized // 1080x1080 - Optimized for X platform
            case standard // 1080x1080 - Standard quality
            case hd // 1920x1920 - High definition
            
            var size: CGSize {
                switch self {
                case .optimized:
                    return CGSize(width: 1080, height: 1080) // X platform optimal
                case .standard:
                    return CGSize(width: 1080, height: 1080)
                case .hd:
                    return CGSize(width: 1920, height: 1920)
                }
            }
            
            var title: String {
                switch self {
                case .optimized:
                    return "X Platform Optimized"
                case .standard:
                    return "Standard Quality"
                case .hd:
                    return "High Definition"
                }
            }
            
            var description: String {
                switch self {
                case .optimized:
                    return "1080×1080 • Optimized for X platform uploads"
                case .standard:
                    return "1080×1080 • Perfect for social media"
                case .hd:
                    return "1920×1920 • Higher quality, larger file"
                }
            }
        }
    }
    
    // MARK: - Export Progress
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var currentFrame: Int = 0
    @Published var totalFrames: Int = 0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var exportError: Error?
    
    private var startTime: Date?
    private var frameRenderTimes: [TimeInterval] = []
    
    // MARK: - Public Methods
    
    /// Export animated GIF from text post
    /// - Parameters:
    ///   - config: Export configuration
    ///   - completion: Completion handler with result URL or error
    func exportGIF(config: GIFExporter.ExportConfiguration, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.performGIFExport(config: config, completion: completion)
        }
    }
    
    /// Cancel ongoing export
    func cancelExport() {
        // Implementation would cancel the current export
        DispatchQueue.main.async {
            self.isExporting = false
        }
    }
    
    // MARK: - Private GIF Export Implementation
    
    private func performGIFExport(config: GIFExporter.ExportConfiguration, completion: @escaping (Result<URL, Error>) -> Void) {
        print("GIFExporter: Starting GIF export process")
        
        DispatchQueue.main.async {
            self.isExporting = true
        }
        
        do {
            // Create temporary GIF file
            let tempDir = FileManager.default.temporaryDirectory
            let gifURL = tempDir.appendingPathComponent("animation_\(UUID().uuidString).gif")
            
            // Generate GIF frames
            try generateGIFFrames(config: config, outputURL: gifURL)
            
            DispatchQueue.main.async {
                self.isExporting = false
                completion(.success(gifURL))
            }
            
        } catch {
            DispatchQueue.main.async {
                self.isExporting = false
                completion(.failure(error))
            }
        }
    }
    
    private func generateGIFFrames(config: GIFExporter.ExportConfiguration, outputURL: URL) throws {
        print("GIFExporter: Generating GIF frames")
        
        // Optimize frame rate for long text
        let optimizedFPS = optimizeFPSForTextLength(config.phrases.count, baseFPS: config.fps)
        let frameCount = Int(config.duration * Double(optimizedFPS))
        let frameInterval = 1.0 / Double(optimizedFPS)
        
        print("GIFExporter: Optimized FPS: \(optimizedFPS), Frame count: \(frameCount)")
        
        // Create GIF directly without storing all images in memory
        try createGIFDirectly(config: config, outputURL: outputURL, frameCount: frameCount, frameInterval: frameInterval)
    }
    
    /// Optimize frame rate based on text length to balance quality and performance
    private func optimizeFPSForTextLength(_ wordCount: Int, baseFPS: Int) -> Int {
        if wordCount <= 20 {
            return baseFPS // 30 FPS for short text
        } else if wordCount <= 50 {
            return max(24, baseFPS - 6) // 24 FPS for medium text
        } else if wordCount <= 100 {
            return max(20, baseFPS - 10) // 20 FPS for long text
        } else {
            return max(15, baseFPS - 15) // 15 FPS for very long text (500+ chars)
        }
    }
    
    /// Create GIF directly without storing all frames in memory
    private func createGIFDirectly(config: GIFExporter.ExportConfiguration, outputURL: URL, frameCount: Int, frameInterval: Double) throws {
        print("GIFExporter: Creating GIF directly with \(frameCount) frames")
        
        // Create GIF properties
        let gifProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0, // Infinite loop
                kCGImagePropertyGIFDelayTime: frameInterval
            ]
        ]
        
        // Create destination for GIF
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
            throw GIFExportError.cannotCreateContext
        }
        
        // Set GIF properties
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
        
        // Add frames one by one to avoid memory issues
        for frameIndex in 0..<frameCount {
            let t = Double(frameIndex) / Double(frameCount - 1)
            
            // Create pixel buffer for this frame
            let pixelBuffer = try createPixelBuffer(for: config, at: t, size: config.size)
            
            // Convert pixel buffer to UIImage
            let image = try pixelBufferToUIImage(pixelBuffer)
            
            // Add frame to GIF
            guard let cgImage = image.cgImage else { continue }
            
            let frameProperties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: frameInterval
                ]
            ]
            
            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            
            // Update progress
            let progress = Double(frameIndex + 1) / Double(frameCount)
            DispatchQueue.main.async {
                self.exportProgress = progress
            }
            
            // Log progress for long exports
            if frameCount > 100 && frameIndex % 50 == 0 {
                print("GIFExporter: Progress: \(Int(progress * 100))% (\(frameIndex + 1)/\(frameCount) frames)")
            }
        }
        
        // Finalize the GIF
        guard CGImageDestinationFinalize(destination) else {
            throw GIFExportError.unknownError
        }
        
        print("GIFExporter: GIF created successfully at \(outputURL)")
    }
    
    private func pixelBufferToUIImage(_ pixelBuffer: CVPixelBuffer) throws -> UIImage {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw GIFExportError.cannotCreateContext
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Helper Functions
    
    private func createPixelBuffer(for config: GIFExporter.ExportConfiguration, at t: Double, size: CGSize) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                       Int(size.width),
                                       Int(size.height),
                                       kCVPixelFormatType_32ARGB,
                                       attributes as CFDictionary,
                                       &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw GIFExportError.cannotCreatePixelBuffer
        }
        
        // Render SwiftUI view to pixel buffer
        try renderSwiftUIView(to: buffer, config: config, t: t, size: size)
        
        return buffer
    }
    
    private func renderSwiftUIView(to pixelBuffer: CVPixelBuffer, config: GIFExporter.ExportConfiguration, t: Double, size: CGSize) throws {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            throw GIFExportError.cannotCreateContext
        }
        
        // Fill background with custom color from preset
        let backgroundColor = config.preset.customSettings.backgroundColor ?? config.preset.template.tokens.backgroundColor
        context.setFillColor(UIColor(backgroundColor).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Create SwiftUI view
        let animatedView = AnimatedSlideView(
            phrases: config.phrases,
            preset: config.preset,
            t: t,
            size: size,
            speedMultiplier: 1.0 // Export uses normalized time, so speed multiplier is 1.0
        )
        
        // Add watermark if needed
        let finalView = config.includeWatermark ? 
            AnyView(watermarkedView(animatedView)) : 
            AnyView(animatedView)
        
        // Render SwiftUI view on main thread
        var image: UIImage?
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async {
            image = self.renderSwiftUIViewToImage(view: finalView, size: size, config: config)
            semaphore.signal()
        }
        
        semaphore.wait()
        
        // Draw image to pixel buffer context
        if let cgImage = image?.cgImage {
            context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }
    }
    
    private func renderSwiftUIViewToImage(view: AnyView, size: CGSize, config: GIFExporter.ExportConfiguration) -> UIImage {
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = CGRect(origin: .zero, size: size)
        hostingController.view.backgroundColor = .clear
        
        // Force layout and prepare for rendering
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        // Ensure we're on the main thread for UI operations
        assert(Thread.isMainThread, "UI operations must be on main thread")
        
        // Create image renderer
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            // Fill background with custom color from preset
            let backgroundColor = config.preset.customSettings.backgroundColor ?? config.preset.template.tokens.backgroundColor
            UIColor(backgroundColor).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            
            // Render the SwiftUI view
            hostingController.view.drawHierarchy(in: hostingController.view.bounds, afterScreenUpdates: true)
        }
    }
    
    private func watermarkedView(_ content: some View) -> some View {
        ZStack {
            content
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("Created by Twimotion")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.85))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: 4)
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                }
            }
        }
    }
}

// MARK: - Save to Photos

extension GIFExporter {
    
    /// Save GIF to Photos app
    /// - Parameters:
    ///   - gifURL: Local URL of the GIF file
    ///   - completion: Completion handler with success/failure result
    func saveToPhotos(gifURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(.failure(GIFExportError.photosPermissionDenied))
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: gifURL)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        completion(.success(()))
                    } else {
                        completion(.failure(error ?? GIFExportError.cannotSaveToPhotos))
                    }
                }
            }
        }
    }
}

// MARK: - Export Errors

enum GIFExportError: LocalizedError {
    case cannotCreatePixelBuffer
    case cannotCreateContext
    case unknownError
    case photosPermissionDenied
    case cannotSaveToPhotos
    
    var errorDescription: String? {
        switch self {
        case .cannotCreatePixelBuffer:
            return "Cannot create pixel buffer for GIF frame"
        case .cannotCreateContext:
            return "Cannot create graphics context"
        case .unknownError:
            return "Unknown GIF export error"
        case .photosPermissionDenied:
            return "Photos permission denied"
        case .cannotSaveToPhotos:
            return "Cannot save GIF to Photos"
        }
    }
    
}
