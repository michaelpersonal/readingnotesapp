//
//  ImageProcessingService.swift
//  ReadingNotesApp
//
//  Main orchestrator for processing screenshots: highlight detection + OCR
//

import Foundation
import UIKit
import SwiftData
import Vision
import CoreImage

@MainActor
class ImageProcessingService {
    private let ocrService: OCRService
    private let highlightDetectionService: HighlightDetectionService
    private let lineBasedService: LineBasedHighlightService
    private let modelContext: ModelContext
    
    // Tuning parameters (legacy - kept for compatibility)
    private let overlapThreshold: Float = 0.15
    private let verticalPaddingRatio: CGFloat = 0.15
    private let horizontalPaddingRatio: CGFloat = 0.05

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.ocrService = OCRService()
        self.highlightDetectionService = HighlightDetectionService()
        self.lineBasedService = LineBasedHighlightService()
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
            // Step 1: Create highlight mask
            guard let mask = HighlightMaskService.createHighlightMask(from: image) else {
                screenshot.processingStatus = .failed
                try modelContext.save()
                throw ProcessingError.noHighlightsDetected
            }
            
            // Step 2: Use line-based extraction
            // This extracts entire lines if any part is highlighted, avoiding partial words
            let extractedPassages = try await lineBasedService.extractHighlightedLines(
                from: image,
                mask: mask
            )
            
            // Step 3: Create Highlight entities for each passage
            for passage in extractedPassages {
                if passage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continue
                }
                
                // Get bounding box for this passage (we'll use a default for now)
                // In a more sophisticated version, we could track which lines belong to which passage
                let highlight = Highlight(
                    screenshot: screenshot,
                    extractedText: passage,
                    confidence: 0.8, // Default confidence
                    boundingBox: BoundingBox(
                        x: 0.0,
                        y: 0.0,
                        width: 1.0,
                        height: 0.1 // Default height
                    ),
                    highlightColor: .pink
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
