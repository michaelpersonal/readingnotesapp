//
//  OCRService.swift
//  ReadingNotesApp
//
//  Service for extracting text from images using Vision Framework
//

import Foundation
import Vision
import UIKit
import CoreImage

struct OCRResult {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

@MainActor
class OCRService {

    // MARK: - Text Recognition

    func recognizeText(in image: UIImage) async throws -> [OCRResult] {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = observations.compactMap { observation -> OCRResult? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }

                    return OCRResult(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: results)
            }

            // Configure for best accuracy
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Text Recognition in Region

    func recognizeText(in image: UIImage, region: CGRect) async throws -> [OCRResult] {
        // Use exact region - no expansion to avoid capturing non-highlighted text
        guard let croppedImage = cropImage(image, toRect: region) else {
            throw OCRError.invalidRegion
        }

        return try await recognizeText(in: croppedImage)
    }

    // MARK: - Enhanced Text Recognition with Preprocessing

    func recognizeTextWithPreprocessing(in image: UIImage) async throws -> [OCRResult] {
        // Try multiple preprocessing strategies and return the best result
        var allResults: [(results: [OCRResult], avgConfidence: Float)] = []
        
        // Strategy 1: Original image (no preprocessing)
        let originalResults = try await recognizeText(in: image)
        if !originalResults.isEmpty {
            let avgConfidence = originalResults.map { $0.confidence }.reduce(0, +) / Float(originalResults.count)
            allResults.append((originalResults, avgConfidence))
        }
        
        // Strategy 2: High contrast binarization
        if let binarizedImage = preprocessBinarized(image) {
            let binarizedResults = try await recognizeText(in: binarizedImage)
            if !binarizedResults.isEmpty {
                let avgConfidence = binarizedResults.map { $0.confidence }.reduce(0, +) / Float(binarizedResults.count)
                allResults.append((binarizedResults, avgConfidence))
            }
        }
        
        // Strategy 3: High contrast (no blur)
        if let highContrastImage = preprocessHighContrast(image) {
            let highContrastResults = try await recognizeText(in: highContrastImage)
            if !highContrastResults.isEmpty {
                let avgConfidence = highContrastResults.map { $0.confidence }.reduce(0, +) / Float(highContrastResults.count)
                allResults.append((highContrastResults, avgConfidence))
            }
        }
        
        // Strategy 4: Upscaled version (for better accuracy on any image)
        // Always try upscaling - it improves OCR accuracy significantly
        if let upscaledImage = upscaleImage(image, scale: 2.0) {
            let upscaledResults = try await recognizeText(in: upscaledImage)
            if !upscaledResults.isEmpty {
                let avgConfidence = upscaledResults.map { $0.confidence }.reduce(0, +) / Float(upscaledResults.count)
                allResults.append((upscaledResults, avgConfidence))
            }
        }
        
        // Return the strategy with highest average confidence
        guard let bestResult = allResults.max(by: { $0.avgConfidence < $1.avgConfidence }) else {
            return originalResults
        }
        
        return bestResult.results
    }

    func recognizeTextWithPreprocessing(in image: UIImage, region: CGRect) async throws -> [OCRResult] {
        // Use exact region - no expansion to avoid capturing non-highlighted text
        guard let croppedImage = cropImage(image, toRect: region) else {
            throw OCRError.invalidRegion
        }

        // Always upscale cropped highlight regions for better OCR accuracy
        // Cropped regions are often small, so upscaling significantly improves text recognition
        let upscaleFactor: CGFloat = 3.0 // 3x upscaling for better accuracy
        guard let upscaledImage = upscaleImage(croppedImage, scale: upscaleFactor) else {
            // Fallback to original if upscaling fails
            return try await recognizeTextWithPreprocessing(in: croppedImage)
        }

        return try await recognizeTextWithPreprocessing(in: upscaledImage)
    }

    // MARK: - Image Preprocessing Strategies
    
    /// High contrast binarization - converts to black/white for better OCR
    private func preprocessBinarized(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let context = CIContext()
        var ciImage = CIImage(cgImage: cgImage)
        
        // Convert to grayscale first
        if let grayscaleFilter = CIFilter(name: "CIColorControls") {
            grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
            grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color
            if let output = grayscaleFilter.outputImage {
                ciImage = output
            }
        }
        
        // High contrast for binarization effect
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(2.0, forKey: kCIInputContrastKey) // Very high contrast
            contrastFilter.setValue(0.1, forKey: kCIInputBrightnessKey) // Slight brightness adjustment
            if let output = contrastFilter.outputImage {
                ciImage = output
            }
        }
        
        guard let processedCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: processedCGImage)
    }
    
    /// High contrast preprocessing without blur (blur hurts OCR accuracy)
    private func preprocessHighContrast(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let context = CIContext()
        var ciImage = CIImage(cgImage: cgImage)
        
        // Increase contrast significantly (removed blur - it hurts OCR)
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.8, forKey: kCIInputContrastKey) // Higher contrast
            contrastFilter.setValue(0.05, forKey: kCIInputBrightnessKey) // Slight brightness boost
            if let output = contrastFilter.outputImage {
                ciImage = output
            }
        }
        
        // Sharpen to improve text clarity
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(ciImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.5, forKey: kCIInputSharpnessKey)
            if let output = sharpenFilter.outputImage {
                ciImage = output
            }
        }
        
        guard let processedCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: processedCGImage)
    }
    
    /// Upscale image for better OCR accuracy
    /// Uses high-quality interpolation for better text clarity
    private func upscaleImage(_ image: UIImage, scale: CGFloat) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        // Use Core Graphics with high-quality interpolation
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            // Fallback to UIGraphicsImageRenderer
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { context in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
        
        // Set high-quality interpolation
        context.interpolationQuality = .high
        
        // Draw the image scaled up
        context.draw(cgImage, in: CGRect(origin: .zero, size: newSize))
        
        guard let scaledCGImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: scaledCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Helper Methods

    private func cropImage(_ image: UIImage, toRect rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        // Convert normalized coordinates to pixel coordinates
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        let pixelRect = CGRect(
            x: rect.origin.x * width,
            y: (1 - rect.origin.y - rect.height) * height,
            width: rect.width * width,
            height: rect.height * height
        )

        guard let croppedCGImage = cgImage.cropping(to: pixelRect) else {
            return nil
        }

        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case invalidImage
    case invalidRegion
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .invalidRegion:
            return "Invalid region specified"
        case .noTextFound:
            return "No text found in image"
        }
    }
}
