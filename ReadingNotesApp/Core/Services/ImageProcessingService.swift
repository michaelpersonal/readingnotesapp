//
//  ImageProcessingService.swift
//  ReadingNotesApp
//
//  Main orchestrator for processing screenshots: highlight detection + OCR
//

import Foundation
import UIKit
import SwiftData

@MainActor
class ImageProcessingService {
    private let ocrService: OCRService
    private let highlightDetectionService: HighlightDetectionService
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.ocrService = OCRService()
        self.highlightDetectionService = HighlightDetectionService()
    }

    // MARK: - Main Processing Pipeline

    func processScreenshot(_ screenshot: KindleScreenshot) async throws {
        // Update status to processing
        screenshot.processingStatus = .processing
        try modelContext.save()

        guard let imageData = screenshot.imageData,
              let image = UIImage(data: imageData) else {
            screenshot.processingStatus = .failed
            try modelContext.save()
            throw ProcessingError.invalidImage
        }

        do {
            // Step 1: Detect highlighted regions
            let detectedHighlights = await highlightDetectionService.detectHighlights(in: image)

            // Step 2: For each highlight, extract text
            for detectedHighlight in detectedHighlights {
                // Extract text from the highlighted region using enhanced OCR
                let ocrResults = try await ocrService.recognizeTextWithPreprocessing(in: image, region: detectedHighlight.boundingBox)

                // Combine OCR results into single text
                let extractedText = ocrResults.map { $0.text }.joined(separator: " ")

                // Skip if no text was extracted
                if extractedText.trimmingCharacters(in: .whitespaces).isEmpty {
                    continue
                }

                // Calculate average confidence
                let avgConfidence = ocrResults.isEmpty ? 0.0 : ocrResults.map { Double($0.confidence) }.reduce(0, +) / Double(ocrResults.count)

                // Create Highlight entity
                let highlight = Highlight(
                    screenshot: screenshot,
                    extractedText: extractedText,
                    confidence: avgConfidence,
                    boundingBox: BoundingBox(
                        x: Double(detectedHighlight.boundingBox.origin.x),
                        y: Double(detectedHighlight.boundingBox.origin.y),
                        width: Double(detectedHighlight.boundingBox.width),
                        height: Double(detectedHighlight.boundingBox.height)
                    ),
                    highlightColor: detectedHighlight.color
                )

                modelContext.insert(highlight)
                screenshot.highlights.append(highlight)
            }

            // Step 3: Set default title
            if screenshot.sourceBook == nil {
                screenshot.sourceBook = "Untitled"
            }

            // Mark as completed
            screenshot.processingStatus = .completed
            try modelContext.save()

        } catch {
            screenshot.processingStatus = .failed
            try modelContext.save()
            throw error
        }
    }

    // MARK: - Batch Processing

    func processPendingScreenshots() async {
        let descriptor = FetchDescriptor<KindleScreenshot>()
        guard let allScreenshots = try? modelContext.fetch(descriptor) else {
            return
        }

        let pendingScreenshots = allScreenshots.filter { $0.processingStatus == .pending }

        for screenshot in pendingScreenshots {
            do {
                try await processScreenshot(screenshot)
            } catch {
                print("Error processing screenshot \(screenshot.id): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Reprocessing

    func reprocessScreenshot(_ screenshot: KindleScreenshot) async throws {
        // Clear existing highlights
        for highlight in screenshot.highlights {
            modelContext.delete(highlight)
        }
        screenshot.highlights.removeAll()

        // Reset status
        screenshot.processingStatus = .pending

        // Process again
        try await processScreenshot(screenshot)
    }
}

// MARK: - Errors

enum ProcessingError: LocalizedError {
    case invalidImage
    case noHighlightsDetected
    case ocrFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image data"
        case .noHighlightsDetected:
            return "No highlights detected in screenshot"
        case .ocrFailed:
            return "Text recognition failed"
        }
    }
}
