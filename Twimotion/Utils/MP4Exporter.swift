//
//  MP4Exporter.swift
//  Twimotion
//
//  Created by Vaibhav Parashar on 10/21/25.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine
import CoreText

/// Fast MP4 export utility using AVAssetWriter with H.264 codec
class MP4Exporter: ObservableObject {
    
    // MARK: - Export Configuration
    
    struct MP4ExportConfiguration {
        let phrases: [String]
        let preset: AnimationPreset
        let duration: Double
        let includeWatermark: Bool
        
        // Simplified quality settings - using balanced quality only
        enum Quality {
            case balanced  // 24 FPS, 1080p
            
            var fps: Int { return 24 }
            var size: CGSize { return CGSize(width: 1080, height: 1080) }
            var bitrate: Int { return 5_000_000 } // 5 Mbps
            var title: String { return "High Quality" }
        }
    }
    
    // MARK: - Export Progress
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var currentFrame: Int = 0
    @Published var totalFrames: Int = 0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var exportError: Error?
    
    private var _startTime: Date?
    private var frameRenderTimes: [TimeInterval] = []
    
    // MARK: - Public Methods
    
    /// Export animated MP4 from text post using AVAssetWriter
    func exportMP4(config: MP4ExportConfiguration, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.performMP4Export(config: config, completion: completion)
        }
    }
    
    /// Cancel ongoing export
    func cancelExport() {
        DispatchQueue.main.async {
            self.isExporting = false
        }
    }
    
    // MARK: - MP4 Export Implementation
    
    private func performMP4Export(config: MP4ExportConfiguration, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.main.async {
            self.isExporting = true
            self.exportProgress = 0.0
            self.currentFrame = 0
            self.totalFrames = 0
            self.estimatedTimeRemaining = 0
            self._startTime = Date()
            self.frameRenderTimes = []
        }
        
        do {
            // Create temporary MP4 file
            let tempDir = FileManager.default.temporaryDirectory
            let mp4URL = tempDir.appendingPathComponent("twimotion_\(UUID().uuidString).mp4")
            
            // Generate MP4 using AVAssetWriter
            try generateMP4WithAVAssetWriter(config: config, outputURL: mp4URL)
            
            DispatchQueue.main.async {
                self.isExporting = false
                completion(.success(mp4URL))
            }
            
        } catch {
            DispatchQueue.main.async {
                self.isExporting = false
                completion(.failure(error))
            }
        }
    }
    
    private func generateMP4WithAVAssetWriter(config: MP4ExportConfiguration, outputURL: URL) throws {
        let quality = MP4ExportConfiguration.Quality.balanced
        let fps = quality.fps
        let frameCount = Int(config.duration * Double(fps))
        _ = 1.0 / Double(fps) // frameInterval not needed for current implementation
        
        // Initialize progress tracking
        DispatchQueue.main.async {
            self.totalFrames = frameCount
            self.currentFrame = 0
        }
        
        // Set up AVAssetWriter
        let (assetWriter, pixelBufferAdapter) = try setupAVAssetWriter(outputURL: outputURL)
        
        // Start writing
        guard assetWriter.startWriting() else {
            throw MP4ExportError.cannotStartWriting
        }
        
        assetWriter.startSession(atSourceTime: .zero)
        
        // Pre-calculate animation states for all frames
        let animationStates = preCalculateAnimationStates(
            phrases: config.phrases,
            preset: config.preset,
            frameCount: frameCount
        )
        
        // Get video input for readiness checking
        guard let videoInput = assetWriter.inputs.first else {
            throw MP4ExportError.cannotCreatePixelBufferAdapter
        }
        
        // Add frames using existing pixel buffer creation logic
        for frameIndex in 0..<frameCount {
            let frameStartTime = Date()
            let t = Double(frameIndex) / Double(frameCount - 1)
            let phraseAnimations = animationStates[frameIndex]
            
            // Create pixel buffer using existing logic
            let pixelBuffer = try createPixelBuffer(
                for: config,
                at: t,
                size: quality.size,
                phraseAnimations: phraseAnimations
            )
            
            // Calculate presentation time
            let presentationTime = CMTimeMake(value: Int64(frameIndex), timescale: Int32(fps))
            
            // Wait for input to be ready for more data
            while !videoInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01) // Wait 10ms
            }
            
            // Append pixel buffer to writer
            guard pixelBufferAdapter.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw MP4ExportError.cannotAppendFrame
            }
            
            // Update progress
            let progress = Double(frameIndex + 1) / Double(frameCount)
            DispatchQueue.main.async {
                self.exportProgress = progress
                self.currentFrame = frameIndex + 1
                
                // Calculate ETA
                let frameRenderTime = Date().timeIntervalSince(frameStartTime)
                self.frameRenderTimes.append(frameRenderTime)
                
                if self.frameRenderTimes.count > 5 {
                    self.frameRenderTimes.removeFirst()
                }
                
                if self._startTime != nil, !self.frameRenderTimes.isEmpty {
                    let averageFrameTime = self.frameRenderTimes.reduce(0, +) / Double(self.frameRenderTimes.count)
                    let remainingFrames = frameCount - (frameIndex + 1)
                    self.estimatedTimeRemaining = Double(remainingFrames) * averageFrameTime
                }
            }
        }
        
        // Finish writing
        videoInput.markAsFinished()
        
        let semaphore = DispatchSemaphore(value: 0)
        var writingError: Error?
        
        assetWriter.finishWriting {
            if let error = assetWriter.error {
                writingError = error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = writingError {
            throw error
        }
    }
    
    // MARK: - AVAssetWriter Setup
    
    private func setupAVAssetWriter(outputURL: URL) throws -> (AVAssetWriter, AVAssetWriterInputPixelBufferAdaptor) {
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        // Create asset writer
        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            throw MP4ExportError.cannotCreateAssetWriter
        }
        
        // Video settings - using balanced quality
        let quality = MP4ExportConfiguration.Quality.balanced
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: quality.size.width,
            AVVideoHeightKey: quality.size.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: quality.bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
            ]
        ]
        
        // Create video input
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        
        // Create pixel buffer adapter
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: quality.size.width,
            kCVPixelBufferHeightKey as String: quality.size.height
        ]
        
        let pixelBufferAdapter = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        // Add input to writer
        guard assetWriter.canAdd(videoInput) else {
            throw MP4ExportError.cannotAddInput
        }
        assetWriter.add(videoInput)
        
        return (assetWriter, pixelBufferAdapter)
    }
    
    // MARK: - Pre-calculation Optimization
    
    private func preCalculateAnimationStates(
        phrases: [String],
        preset: AnimationPreset,
        frameCount: Int
    ) -> [[DeterministicAnimationEngine.PhraseAnimation]] {
        
        var states: [[DeterministicAnimationEngine.PhraseAnimation]] = []
        
        for frameIndex in 0..<frameCount {
            let t = Double(frameIndex) / Double(frameCount - 1)
            
            // Use the same animation type as the preset, defaulting to typewriter
            let animationType: DeterministicAnimationEngine.AnimationType
            switch preset.template.animation.family {
            case "typewriter":
                animationType = .typewriter
            case "fade_in":
                animationType = .fadeIn
            case "pop_in":
                animationType = .popIn
            default:
                animationType = .typewriter
            }
            
            let phraseAnimations = DeterministicAnimationEngine.calculateAnimationState(
                at: t,
                phrases: phrases,
                animationType: animationType
            )
            states.append(phraseAnimations)
        }
        
        return states
    }
    
    // MARK: - Pixel Buffer Creation (using existing logic)
    
    private func createPixelBuffer(
        for config: MP4ExportConfiguration,
        at t: Double,
        size: CGSize,
        phraseAnimations: [DeterministicAnimationEngine.PhraseAnimation]
    ) throws -> CVPixelBuffer {
        
        var pixelBuffer: CVPixelBuffer?
        
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw MP4ExportError.cannotCreatePixelBuffer
        }
        
        // Render content to pixel buffer using direct Core Graphics
        try renderContentToPixelBuffer(
            buffer: buffer,
            config: config,
            phraseAnimations: phraseAnimations,
            size: size,
            t: t
        )
        
        return buffer
    }
    
    // MARK: - Direct Rendering
    
    private func renderContentToPixelBuffer(
        buffer: CVPixelBuffer,
        config: MP4ExportConfiguration,
        phraseAnimations: [DeterministicAnimationEngine.PhraseAnimation],
        size: CGSize,
        t: Double
    ) throws {
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        ) else {
            throw MP4ExportError.cannotCreateContext
        }
        
        // No coordinate transformation needed - Core Graphics handles this correctly
        
        // Fill background
        let backgroundColor = config.preset.customSettings.backgroundColor ?? config.preset.template.tokens.backgroundColor
        context.setFillColor(UIColor(backgroundColor).cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        
        // Render text directly using Core Graphics
        renderTextDirectly(
            context: context,
            phrases: config.phrases,
            phraseAnimations: phraseAnimations,
            preset: config.preset,
            size: size,
            t: t
        )
        
        
        // Add watermark if needed
        if config.includeWatermark {
            renderWatermark(context: context, size: size)
        }
    }
    
    // MARK: - Direct Text Rendering (Simplified to match preview)
    
    private func renderTextDirectly(
        context: CGContext,
        phrases: [String],
        phraseAnimations: [DeterministicAnimationEngine.PhraseAnimation],
        preset: AnimationPreset,
        size: CGSize,
        t: Double
    ) {
        let fontSize = calculateOptimalFontSize(for: size)
        let textColor = preset.customSettings.textColor ?? preset.template.tokens.primaryColor
        
        // Only render visible phrases
        let visiblePhrases = phraseAnimations.enumerated().compactMap { index, phraseAnimation in
            return phraseAnimation.isVisible && phraseAnimation.opacity > 0 ? (index: index, animation: phraseAnimation) : nil
        }
        
        guard !visiblePhrases.isEmpty else { 
            print("MP4Exporter: No visible phrases to render")
            return 
        }
        
        print("MP4Exporter: Rendering \(visiblePhrases.count) visible phrases with fontSize: \(fontSize)")
        
        // Calculate vertical positioning (bottom-aligned for teleprompter effect)
        let totalHeight = CGFloat(visiblePhrases.count) * fontSize * 1.2
        let bottomPadding = size.height * 0.1 // 10% from bottom
        let baseStartY = size.height - totalHeight - bottomPadding
        
        // Add teleprompter scrolling effect (subtle upward movement)
        let maxOffset = size.height * 0.05 // Maximum 5% of screen height
        let teleprompterOffset = -maxOffset * t // Negative offset moves text upward
        let startY = baseStartY + teleprompterOffset
        
        for (phraseIndex, phraseData) in visiblePhrases.enumerated() {
            let phraseAnimation = phraseData.animation
            let phraseText = phraseAnimation.text
            
            print("MP4Exporter: Rendering phrase \(phraseIndex): '\(phraseText)' with opacity: \(phraseAnimation.opacity), scale: \(phraseAnimation.scale)")
            
            // Calculate phrase-specific font size with scaling
            let scaledFontSize = fontSize * phraseAnimation.scale
            let font = UIFont.systemFont(ofSize: scaledFontSize, weight: .bold)
            
            // Set up text attributes
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(textColor).withAlphaComponent(phraseAnimation.opacity)
            ]
            
            let attributedString = NSAttributedString(string: phraseText, attributes: attributes)
            
            // Calculate text size
            let textSize = attributedString.boundingRect(
                with: CGSize(width: size.width * 0.84, height: size.height), // Match preview padding
                options: [NSStringDrawingOptions.usesLineFragmentOrigin, NSStringDrawingOptions.usesFontLeading],
                context: nil
            ).size
            
            // Position text (centered horizontally, stacked vertically like preview)
            // Note: Core Graphics has origin at bottom-left, so we need to adjust Y positioning
            let yPosition = startY + CGFloat(phraseIndex) * fontSize * 1.2
            let phraseRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: yPosition,
                width: textSize.width,
                height: textSize.height
            )
            
            print("MP4Exporter: Text positioned at (\(phraseRect.origin.x), \(phraseRect.origin.y)) with size \(textSize)")
            
            // Render text using Core Graphics
            context.saveGState()
            
            // For video rendering, we need to flip the Y coordinate since Core Graphics has origin at bottom-left
            // but video frames expect origin at top-left
            let line = CTLineCreateWithAttributedString(attributedString)
            let videoY = size.height - phraseRect.origin.y - textSize.height
            context.textPosition = CGPoint(x: phraseRect.origin.x, y: videoY)
            CTLineDraw(line, context)
            
            context.restoreGState()
        }
        
        // Cursor removed from exported videos for cleaner look
        // (Cursor is only shown in preview for typewriter effect)
    }
    
    
    private func renderWatermark(context: CGContext, size: CGSize) {
        context.saveGState()
        
        let watermarkText = "Created by Twimotion"
        let fontSize: CGFloat = 18
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let attributedString = NSAttributedString(string: watermarkText, attributes: attributes)
        let textSize = attributedString.size()
        
        // Position watermark in bottom-right corner
        let margin: CGFloat = 20
        let watermarkRect = CGRect(
            x: size.width - textSize.width - margin,
            y: size.height - textSize.height - margin,
            width: textSize.width,
            height: textSize.height
        )
        
        // Add background
        let backgroundRect = watermarkRect.insetBy(dx: -10, dy: -5)
        context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
        context.fill(backgroundRect)
        
        // Render text
        attributedString.draw(in: watermarkRect)
        
        context.restoreGState()
    }
    
    private func calculateOptimalFontSize(for size: CGSize) -> CGFloat {
        // Use same font size calculation as preview
        let optimizedFontSize: CGFloat = 72.0
        let baseDimension: CGFloat = 1080.0
        let scaleFactor = min(size.width, size.height) / baseDimension
        let scaledSize = optimizedFontSize * scaleFactor
        return max(24.0, min(120.0, scaledSize))
    }
}

// MARK: - Export Errors

enum MP4ExportError: LocalizedError {
    case cannotCreateAssetWriter
    case cannotAddInput
    case cannotStartWriting
    case cannotCreatePixelBufferAdapter
    case cannotAppendFrame
    case cannotCreatePixelBuffer
    case cannotCreateContext
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .cannotCreateAssetWriter:
            return "Cannot create AVAssetWriter"
        case .cannotAddInput:
            return "Cannot add video input to asset writer"
        case .cannotStartWriting:
            return "Cannot start asset writer"
        case .cannotCreatePixelBufferAdapter:
            return "Cannot create pixel buffer adapter"
        case .cannotAppendFrame:
            return "Cannot append frame to video"
        case .cannotCreatePixelBuffer:
            return "Cannot create pixel buffer"
        case .cannotCreateContext:
            return "Cannot create graphics context"
        case .unknownError:
            return "Unknown export error"
        }
    }
}
