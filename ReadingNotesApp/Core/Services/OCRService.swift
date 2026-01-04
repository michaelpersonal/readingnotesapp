//
//  OCRService.swift
//  ReadingNotesApp
//
//  Service for extracting text from images using Vision Framework
//

import Foundation
import Vision
import UIKit

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
        guard let croppedImage = cropImage(image, toRect: region) else {
            throw OCRError.invalidRegion
        }

        return try await recognizeText(in: croppedImage)
    }

    // MARK: - Enhanced Text Recognition with Preprocessing

    func recognizeTextWithPreprocessing(in image: UIImage) async throws -> [OCRResult] {
        // Try both original and preprocessed versions, return better results
        let originalResults = try await recognizeText(in: image)

        if let preprocessedImage = preprocessForOCR(image) {
            let preprocessedResults = try await recognizeText(in: preprocessedImage)

            // Return results with higher average confidence
            let originalAvgConfidence = originalResults.map { $0.confidence }.reduce(0, +) / Float(max(originalResults.count, 1))
            let preprocessedAvgConfidence = preprocessedResults.map { $0.confidence }.reduce(0, +) / Float(max(preprocessedResults.count, 1))

            return preprocessedAvgConfidence > originalAvgConfidence ? preprocessedResults : originalResults
        }

        return originalResults
    }

    func recognizeTextWithPreprocessing(in image: UIImage, region: CGRect) async throws -> [OCRResult] {
        guard let croppedImage = cropImage(image, toRect: region) else {
            throw OCRError.invalidRegion
        }

        return try await recognizeTextWithPreprocessing(in: croppedImage)
    }

    // MARK: - Image Preprocessing

    private func preprocessForOCR(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let context = CIContext()
        var ciImage = CIImage(cgImage: cgImage)

        // Convert to grayscale
        if let grayscaleFilter = CIFilter(name: "CIPhotoEffectMono") {
            grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
            if let output = grayscaleFilter.outputImage {
                ciImage = output
            }
        }

        // Increase contrast
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.5, forKey: kCIInputContrastKey)
            if let output = contrastFilter.outputImage {
                ciImage = output
            }
        }

        // Apply slight blur to reduce noise
        if let blurFilter = CIFilter(name: "CIGaussianBlur") {
            blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
            blurFilter.setValue(0.5, forKey: kCIInputRadiusKey)
            if let output = blurFilter.outputImage {
                ciImage = output
            }
        }

        guard let processedCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: processedCGImage)
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
