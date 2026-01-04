//
//  LineBasedHighlightService.swift
//  ReadingNotesApp
//
//  Line-based highlight extraction: if any part of a line is highlighted, extract the entire line
//

import Foundation
import UIKit
import Vision
import CoreImage

struct TextLine {
    let boundingBox: CGRect // In normalized coordinates (0-1)
    let text: String // Initial text from Vision observations
    let observations: [VNRecognizedTextObservation] // Original observations in this line
    let lineHeight: CGFloat // Median height of observations in this line
    let centerY: CGFloat // Center Y coordinate
}

struct HighlightedLine {
    let boundingBox: CGRect // In normalized coordinates (0-1)
    let text: String
    let lineIndex: Int
}

@MainActor
class LineBasedHighlightService {
    
    // Tuning parameters
    private let lineOverlapThreshold: Float = 0.10 // Line is highlighted if >10% overlaps with mask (lowered for better detection)
    private let verticalPaddingRatio: CGFloat = 0.08 // 8% of line height (minimal padding)
    private let horizontalPaddingRatio: CGFloat = 0.03 // 3% of line width
    private let upscaleFactor: CGFloat = 2.0 // 2x upscaling for OCR
    private let minimumTextHeight: CGFloat = 0.01 // Minimum text height for filtering (lowered from 0.02)
    private let lineClusteringThreshold: CGFloat = 0.5 // 0.5 * medianLineHeight for clustering
    private let verticalOverlapThreshold: CGFloat = 0.4 // 40% vertical overlap to merge
    
    // MARK: - Main Pipeline
    
    /// Extract highlighted text using line-based approach
    func extractHighlightedLines(
        from image: UIImage,
        mask: CIImage
    ) async throws -> [String] {
        // Step 1: Get highlight mask (already provided)
        // Step 2: Detect text column bounds
        let textColumnBounds = try await detectTextColumnBounds(in: image)
        
        // Step 3: Run Vision to get all text observations
        let allObservations = try await detectAllTextInColumn(
            in: image,
            columnBounds: textColumnBounds
        )
        
        // Step 4: Cluster observations into robust line boxes
        let textLines = clusterObservationsIntoLines(observations: allObservations)
        
        // Step 5: Filter lines by mask overlap (using grid sampling)
        let highlightedLines = filterLinesByMaskOverlap(
            lines: textLines,
            mask: mask,
            imageSize: image.size
        )
        
        // Step 6: Extract text from highlighted lines (full line OCR with upscaling)
        let extractedLines = try await extractLineTexts(
            from: image,
            lines: highlightedLines,
            columnBounds: textColumnBounds
        )
        
        // Step 7: Sort and merge consecutive lines into passages
        let passages = mergeConsecutiveLines(extractedLines)
        
        return passages
    }
    
    // MARK: - Text Column Detection
    
    /// Detect the text column bounds containing highlights
    private func detectTextColumnBounds(in image: UIImage) async throws -> CGRect {
        guard let cgImage = image.cgImage else {
            throw ProcessingError.invalidImage
        }
        
        // Run Vision to detect all text
        let observations = try await detectAllText(in: image)
        
        guard !observations.isEmpty else {
            // Fallback: use full image width, reasonable margins
            let imageSize = image.size
            return CGRect(
                x: 0.1, // 10% margin from left
                y: 0.0,
                width: 0.8, // 80% of width
                height: 1.0
            )
        }
        
        // Find union of all text bounding boxes
        let minX = observations.map { $0.boundingBox.minX }.min() ?? 0
        let maxX = observations.map { $0.boundingBox.maxX }.max() ?? 1
        let minY = observations.map { $0.boundingBox.minY }.min() ?? 0
        let maxY = observations.map { $0.boundingBox.maxY }.max() ?? 1
        
        // Expand slightly to include margins
        let margin: CGFloat = 0.05
        return CGRect(
            x: max(0, minX - margin),
            y: max(0, minY - margin),
            width: min(1.0, maxX - minX + margin * 2),
            height: min(1.0, maxY - minY + margin * 2)
        )
    }
    
    // MARK: - Text Line Detection
    
    /// Detect all text lines using Vision
    private func detectAllText(in image: UIImage) async throws -> [VNRecognizedTextObservation] {
        guard let cgImage = image.cgImage else {
            throw ProcessingError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: observations)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Detect all text observations within column bounds
    private func detectAllTextInColumn(
        in image: UIImage,
        columnBounds: CGRect
    ) async throws -> [VNRecognizedTextObservation] {
        // Get all text observations
        let allObservations = try await detectAllText(in: image)
        
        // Filter to only observations within column bounds and with minimum height
        let columnObservations = allObservations.filter { observation in
            let box = observation.boundingBox
            
            // Filter by minimum height
            guard box.height >= minimumTextHeight else {
                return false
            }
            
            // Check if observation overlaps with column
            let overlapX = max(0, min(box.maxX, columnBounds.maxX) - max(box.minX, columnBounds.minX))
            let overlapY = max(0, min(box.maxY, columnBounds.maxY) - max(box.minY, columnBounds.minY))
            return overlapX > 0 && overlapY > 0
        }
        
        return columnObservations
    }
    
    // MARK: - Robust Line Clustering
    
    /// Cluster observations into lines using y-overlap and baseline proximity
    private func clusterObservationsIntoLines(observations: [VNRecognizedTextObservation]) -> [TextLine] {
        guard !observations.isEmpty else { return [] }
        
        // Step 1: Convert to pixel coordinates and compute properties
        struct ObservationData {
            let observation: VNRecognizedTextObservation
            let centerY: CGFloat
            let height: CGFloat
            let minX: CGFloat
            let maxX: CGFloat
            let text: String
        }
        
        let observationData = observations.compactMap { obs -> ObservationData? in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let box = obs.boundingBox
            return ObservationData(
                observation: obs,
                centerY: box.midY,
                height: box.height,
                minX: box.minX,
                maxX: box.maxX,
                text: candidate.string
            )
        }
        
        // Step 2: Sort by centerY (top to bottom)
        let sorted = observationData.sorted { $0.centerY > $1.centerY }
        
        // Step 3: Calculate median line height for clustering threshold
        let heights = sorted.map { $0.height }
        let medianHeight = calculateMedian(heights)
        let clusteringThreshold = medianHeight * lineClusteringThreshold
        
        // Step 4: Cluster observations into lines
        var lineGroups: [[ObservationData]] = []
        var currentLine: [ObservationData] = [sorted[0]]
        var currentLineBox = sorted[0].observation.boundingBox
        
        for i in 1..<sorted.count {
            let obs = sorted[i]
            let box = obs.observation.boundingBox
            
            // Check if observation belongs to current line
            let centerYDiff = abs(obs.centerY - currentLineBox.midY)
            let verticalOverlap = calculateVerticalOverlap(box1: box, box2: currentLineBox)
            
            let belongsToLine = centerYDiff < clusteringThreshold || verticalOverlap > verticalOverlapThreshold
            
            if belongsToLine {
                // Add to current line
                currentLine.append(obs)
                // Update line bounding box (union)
                currentLineBox = CGRect(
                    x: min(currentLineBox.minX, box.minX),
                    y: min(currentLineBox.minY, box.minY),
                    width: max(currentLineBox.maxX, box.maxX) - min(currentLineBox.minX, box.minX),
                    height: max(currentLineBox.maxY, box.maxY) - min(currentLineBox.minY, box.minY)
                )
            } else {
                // Start new line
                lineGroups.append(currentLine)
                currentLine = [obs]
                currentLineBox = box
            }
        }
        lineGroups.append(currentLine)
        
        // Step 5: Build TextLine objects
        var textLines: [TextLine] = []
        for group in lineGroups {
            // Sort group members left-to-right by minX
            let sortedGroup = group.sorted { $0.minX < $1.minX }
            
            // Calculate line properties
            let lineHeights = sortedGroup.map { $0.height }
            let medianLineHeight = calculateMedian(lineHeights)
            let centerY = sortedGroup.map { $0.centerY }.reduce(0, +) / CGFloat(sortedGroup.count)
            
            // Merge bounding boxes
            let minX = sortedGroup.map { $0.minX }.min() ?? 0
            let minY = sortedGroup.map { $0.observation.boundingBox.minY }.min() ?? 0
            let maxX = sortedGroup.map { $0.maxX }.max() ?? 1
            let maxY = sortedGroup.map { $0.observation.boundingBox.maxY }.max() ?? 1
            
            // Expand vertically by ~10% of line height
            let verticalExpansion = medianLineHeight * 0.1
            let expandedBox = CGRect(
                x: minX,
                y: max(0, minY - verticalExpansion),
                width: maxX - minX,
                height: min(1.0, maxY - minY + verticalExpansion * 2)
            )
            
            // Join member strings with spaces
            let lineText = sortedGroup.map { $0.text }.joined(separator: " ")
            
            textLines.append(TextLine(
                boundingBox: expandedBox,
                text: lineText,
                observations: sortedGroup.map { $0.observation },
                lineHeight: medianLineHeight,
                centerY: centerY
            ))
        }
        
        return textLines
    }
    
    /// Calculate vertical overlap ratio between two bounding boxes
    private func calculateVerticalOverlap(box1: CGRect, box2: CGRect) -> CGFloat {
        let overlapY = max(0, min(box1.maxY, box2.maxY) - max(box1.minY, box2.minY))
        let minHeight = min(box1.height, box2.height)
        return minHeight > 0 ? overlapY / minHeight : 0
    }
    
    /// Calculate median of an array
    private func calculateMedian(_ values: [CGFloat]) -> CGFloat {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        } else {
            return sorted[count / 2]
        }
    }
    
    // MARK: - Line Filtering by Mask
    
    /// Filter lines by overlap with highlight mask using grid sampling for speed
    private func filterLinesByMaskOverlap(
        lines: [TextLine],
        mask: CIImage,
        imageSize: CGSize
    ) -> [TextLine] {
        var filtered = lines.filter { textLine in
            // Use grid sampling for faster overlap calculation
            let overlapRatio = calculateOverlapRatioWithGridSampling(
                lineBox: textLine.boundingBox,
                mask: mask,
                imageSize: imageSize
            )
            
            // Line is highlighted if overlap exceeds threshold
            return overlapRatio >= lineOverlapThreshold
        }
        
        // Fallback: if filtering removed all lines, try with lower threshold
        if filtered.isEmpty && !lines.isEmpty {
            print("Warning: No lines passed overlap filter. Trying with lower threshold (5%)")
            filtered = lines.filter { textLine in
                let overlapRatio = calculateOverlapRatioWithGridSampling(
                    lineBox: textLine.boundingBox,
                    mask: mask,
                    imageSize: imageSize
                )
                return overlapRatio >= 0.05 // Very low threshold as fallback
            }
        }
        
        // If still empty, use all lines (mask filtering might be too strict)
        if filtered.isEmpty && !lines.isEmpty {
            print("Warning: Still no lines after fallback. Using all detected lines.")
            return lines
        }
        
        return filtered
    }
    
    /// Calculate overlap ratio using grid sampling (faster than pixel-by-pixel)
    private func calculateOverlapRatioWithGridSampling(
        lineBox: CGRect,
        mask: CIImage,
        imageSize: CGSize
    ) -> Float {
        let context = CIContext()
        guard let cgMask = context.createCGImage(mask, from: mask.extent) else {
            return 0.0
        }
        
        let maskWidth = cgMask.width
        let maskHeight = cgMask.height
        
        // Convert normalized lineBox to pixel coordinates
        // Vision uses bottom-left origin, mask uses top-left, so flip Y
        let pixelX = lineBox.origin.x * imageSize.width
        let pixelY = (1.0 - lineBox.origin.y - lineBox.height) * imageSize.height
        let pixelWidth = lineBox.width * imageSize.width
        let pixelHeight = lineBox.height * imageSize.height
        
        // Map to mask coordinates
        let maskX = Int(pixelX * CGFloat(maskWidth) / imageSize.width)
        let maskY = Int(pixelY * CGFloat(maskHeight) / imageSize.height)
        let maskW = Int(pixelWidth * CGFloat(maskWidth) / imageSize.width)
        let maskH = Int(pixelHeight * CGFloat(maskHeight) / imageSize.height)
        
        // Clamp to mask bounds
        let minX = max(0, maskX)
        let maxX = min(maskWidth, maskX + maskW)
        let minY = max(0, maskY)
        let maxY = min(maskHeight, maskY + maskH)
        
        guard maxX > minX && maxY > minY else {
            return 0.0
        }
        
        // Grid sampling: sample 20x5 points (adjust based on line size)
        let sampleWidth = maxX - minX
        let sampleHeight = maxY - minY
        let gridCols = min(20, sampleWidth)
        let gridRows = min(5, sampleHeight)
        
        // Crop the mask to the region of interest
        guard let croppedMask = cgMask.cropping(to: CGRect(x: minX, y: minY, width: sampleWidth, height: sampleHeight)) else {
            return 0.0
        }
        
        // Read mask pixels
        var pixelData = [UInt8](repeating: 0, count: sampleWidth * sampleHeight)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let bitmapContext = CGContext(
            data: &pixelData,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return 0.0
        }
        
        // Draw the cropped mask region
        bitmapContext.draw(
            croppedMask,
            in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight)
        )
        
        // Sample grid points
        var highlightSamples = 0
        let totalSamples = gridCols * gridRows
        
        for row in 0..<gridRows {
            for col in 0..<gridCols {
                // Calculate grid position, handling edge case when gridCols/gridRows is 1
                let x: Int
                let y: Int
                if gridCols > 1 {
                    x = Int(CGFloat(col) / CGFloat(gridCols - 1) * CGFloat(sampleWidth - 1))
                } else {
                    x = sampleWidth / 2
                }
                if gridRows > 1 {
                    y = Int(CGFloat(row) / CGFloat(gridRows - 1) * CGFloat(sampleHeight - 1))
                } else {
                    y = sampleHeight / 2
                }
                
                let offset = y * sampleWidth + x
                
                if offset < pixelData.count && pixelData[offset] > 128 {
                    highlightSamples += 1
                }
            }
        }
        
        return totalSamples > 0 ? Float(highlightSamples) / Float(totalSamples) : 0.0
    }
    
    // MARK: - Line Text Extraction
    
    /// Extract text from highlighted lines using full line OCR
    private func extractLineTexts(
        from image: UIImage,
        lines: [TextLine],
        columnBounds: CGRect
    ) async throws -> [HighlightedLine] {
        var extractedLines: [HighlightedLine] = []
        
        for (index, textLine) in lines.enumerated() {
            // Extend line box to full column width (or keep union bbox)
            let fullLineBox = extendLineToColumnWidth(
                lineBox: textLine.boundingBox,
                columnBounds: columnBounds
            )
            
            // Add minimal padding (5-10% of line height, 2-5% of width)
            let paddedBox = addMinimalPadding(to: fullLineBox, lineHeight: textLine.lineHeight, imageSize: image.size)
            
            // Crop to line region
            guard let croppedImage = cropImage(image, toRect: paddedBox) else {
                continue
            }
            
            // Upscale 2x using high-quality interpolation (CI Lanczos equivalent)
            guard let upscaledImage = upscaleImage(croppedImage, scale: upscaleFactor) else {
                continue
            }
            
            // Run OCR on upscaled line crop for final accurate text
            let ocrResults = try await recognizeText(in: upscaledImage)
            
            // Merge OCR results into single line text
            var lineText = mergeOCRResults(ocrResults)
            
            // Fallback: if OCR on crop failed, use the initial text from Vision observations
            if lineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lineText = textLine.text
            }
            
            if !lineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                extractedLines.append(HighlightedLine(
                    boundingBox: textLine.boundingBox,
                    text: lineText,
                    lineIndex: index
                ))
            }
        }
        
        return extractedLines
    }
    
    /// Extend line box to full column width (or keep union bbox)
    private func extendLineToColumnWidth(lineBox: CGRect, columnBounds: CGRect) -> CGRect {
        // Option 1: Extend to column bounds
        // Option 2: Keep union bbox (current lineBox already includes all observations)
        // We'll extend horizontally to column bounds for consistency
        return CGRect(
            x: columnBounds.minX,
            y: lineBox.origin.y,
            width: columnBounds.width,
            height: lineBox.height
        )
    }
    
    /// Add minimal padding to line bounding box (5-10% of line height, 2-5% of width)
    private func addMinimalPadding(to box: CGRect, lineHeight: CGFloat, imageSize: CGSize) -> CGRect {
        // Use lineHeight for more accurate padding calculation
        let pixelHeight = lineHeight * imageSize.height
        let pixelWidth = box.width * imageSize.width
        
        // Vertical padding: 5-10% of line height
        let verticalPadding = max(pixelHeight * verticalPaddingRatio, 5.0) / imageSize.height
        // Horizontal padding: 2-5% of line width
        let horizontalPadding = max(pixelWidth * horizontalPaddingRatio, 3.0) / imageSize.width
        
        return CGRect(
            x: max(0, box.origin.x - horizontalPadding),
            y: max(0, box.origin.y - verticalPadding),
            width: min(1.0, box.width + horizontalPadding * 2),
            height: min(1.0, box.height + verticalPadding * 2)
        )
    }
    
    /// Crop image to region
    private func cropImage(_ image: UIImage, toRect rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        
        // Convert normalized to pixel coordinates
        // Vision uses bottom-left origin
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
    
    /// Upscale image using high-quality interpolation
    private func upscaleImage(_ image: UIImage, scale: CGFloat) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
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
            return nil
        }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: newSize))
        
        guard let scaledCGImage = context.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: scaledCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    /// Run OCR on image
    private func recognizeText(in image: UIImage) async throws -> [OCRResult] {
        guard let cgImage = image.cgImage else {
            throw ProcessingError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
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
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Merge OCR results into single line text
    private func mergeOCRResults(_ results: [OCRResult]) -> String {
        guard !results.isEmpty else { return "" }
        
        // Sort by X position (left to right)
        let sorted = results.sorted { $0.boundingBox.origin.x < $1.boundingBox.origin.x }
        
        return sorted.map { $0.text }.joined(separator: " ")
    }
    
    // MARK: - Line Merging
    
    /// Merge consecutive highlighted lines into passages
    private func mergeConsecutiveLines(_ lines: [HighlightedLine]) -> [String] {
        guard !lines.isEmpty else { return [] }
        
        // Sort by Y position (top to bottom)
        let sorted = lines.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
        
        var passages: [String] = []
        var currentPassage: [String] = [sorted[0].text]
        var lastY = sorted[0].boundingBox.origin.y
        
        for i in 1..<sorted.count {
            let line = sorted[i]
            let yDiff = abs(line.boundingBox.origin.y - lastY)
            
            // Estimate line height from first line
            let lineHeight = sorted[0].boundingBox.height
            let gapThreshold = lineHeight * 1.5 // Lines within 1.5 line heights are consecutive
            
            if yDiff < gapThreshold {
                // Consecutive line - add to current passage
                currentPassage.append(line.text)
            } else {
                // New passage - finish current and start new
                let passageText = mergePassageLines(currentPassage)
                passages.append(passageText)
                currentPassage = [line.text]
            }
            lastY = line.boundingBox.origin.y
        }
        
        // Don't forget last passage
        if !currentPassage.isEmpty {
            let passageText = mergePassageLines(currentPassage)
            passages.append(passageText)
        }
        
        return passages
    }
    
    /// Merge lines in a passage, fixing hyphenation and spacing
    private func mergePassageLines(_ lines: [String]) -> String {
        guard !lines.isEmpty else { return "" }
        
        // First, fix hyphenation across line breaks
        var merged = fixHyphenationAcrossLines(lines)
        
        // Then fix hyphenation within the merged text
        merged = fixHyphenation(in: merged)
        
        // Normalize whitespace
        while merged.contains("  ") {
            merged = merged.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Remove stray artifacts (multiple spaces, tabs, etc.)
        merged = merged.replacingOccurrences(of: "\t", with: " ")
        merged = merged.replacingOccurrences(of: "\n", with: " ")
        
        // Fix spacing around punctuation
        merged = fixPunctuationSpacing(in: merged)
        
        return merged.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Fix hyphenated words split across lines
    /// If previous line ends with "-" and next begins with lowercase, join them
    private func fixHyphenation(in text: String) -> String {
        let words = text.components(separatedBy: .whitespaces)
        var fixedWords: [String] = []
        var i = 0
        
        while i < words.count {
            let currentWord = words[i]
            
            // Check if word ends with hyphen and next word starts with lowercase
            if currentWord.hasSuffix("-") && i + 1 < words.count {
                let nextWord = words[i + 1]
                // Only merge if next word starts with lowercase (likely continuation)
                if let firstChar = nextWord.first, firstChar.isLowercase {
                    let merged = String(currentWord.dropLast()) + nextWord
                    fixedWords.append(merged)
                    i += 2
                } else {
                    fixedWords.append(currentWord)
                    i += 1
                }
            } else {
                fixedWords.append(currentWord)
                i += 1
            }
        }
        
        return fixedWords.joined(separator: " ")
    }
    
    /// Fix hyphenation across line breaks in passage
    private func fixHyphenationAcrossLines(_ lines: [String]) -> String {
        guard lines.count > 1 else {
            return lines.first ?? ""
        }
        
        var fixed: [String] = []
        var i = 0
        
        while i < lines.count {
            let currentLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            if i + 1 < lines.count {
                let nextLine = lines[i + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check if current line ends with "-" and next starts with lowercase
                if currentLine.hasSuffix("-") || currentLine.hasSuffix(" -") {
                    if let firstChar = nextLine.first, firstChar.isLowercase {
                        // Merge lines: remove hyphen and join
                        let merged = String(currentLine.dropLast().trimmingCharacters(in: .whitespacesAndNewlines)) + nextLine
                        fixed.append(merged)
                        i += 2
                        continue
                    }
                }
            }
            
            fixed.append(currentLine)
            i += 1
        }
        
        return fixed.joined(separator: " ")
    }
    
    /// Fix spacing around punctuation
    private func fixPunctuationSpacing(in text: String) -> String {
        var cleaned = text
        
        // Remove space before punctuation
        cleaned = cleaned.replacingOccurrences(of: " .", with: ".")
        cleaned = cleaned.replacingOccurrences(of: " ,", with: ",")
        cleaned = cleaned.replacingOccurrences(of: " !", with: "!")
        cleaned = cleaned.replacingOccurrences(of: " ?", with: "?")
        cleaned = cleaned.replacingOccurrences(of: " :", with: ":")
        cleaned = cleaned.replacingOccurrences(of: " ;", with: ";")
        
        return cleaned
    }
}

