//
//  HighlightDetectionService.swift
//  ReadingNotesApp
//
//  Service for detecting highlighted regions in screenshots
//

import Foundation
import UIKit
import CoreImage
import Vision

struct DetectedHighlight {
    let boundingBox: CGRect
    let color: HighlightColor
    let image: UIImage?
}

@MainActor
class HighlightDetectionService {

    // MARK: - Highlight Detection

    func detectHighlights(in image: UIImage) async -> [DetectedHighlight] {
        // For now, use a simplified approach: detect text regions and check if they have colored background
        guard let cgImage = image.cgImage else { return [] }

        var detectedHighlights: [DetectedHighlight] = []
        let semaphore = DispatchSemaphore(value: 0)

        // Detect all text regions at line level
        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }

            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            // For each text line, check if ANY part has a colored background
            for observation in observations {
                let boundingBox = observation.boundingBox

                // Skip very small regions
                if boundingBox.width < 0.1 || boundingBox.height < 0.02 {
                    continue
                }

                // Expand more aggressively to better capture background color
                let expandedBox = CGRect(
                    x: max(0, boundingBox.origin.x - 0.02),
                    y: max(0, boundingBox.origin.y - 0.01),
                    width: min(1.0, boundingBox.width + 0.04),
                    height: min(1.0, boundingBox.height + 0.02)
                )

                // Check if this region has ANY highlight color
                if let highlightColor = self.detectHighlightColor(in: image, region: expandedBox) {
                    detectedHighlights.append(DetectedHighlight(
                        boundingBox: boundingBox,
                        color: highlightColor,
                        image: nil
                    ))
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            semaphore.wait()
        } catch {
            print("Error detecting text: \(error)")
        }

        // Sort by vertical position (top to bottom) - Vision uses bottom-left origin, so higher Y = lower on screen
        let sortedHighlights = detectedHighlights.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }

        // Merge nearby highlights that are part of the same highlighted region
        return mergeNearbyHighlights(sortedHighlights)
    }

    // MARK: - Merge Nearby Highlights

    private func mergeNearbyHighlights(_ highlights: [DetectedHighlight]) -> [DetectedHighlight] {
        guard !highlights.isEmpty else { return [] }

        var merged: [DetectedHighlight] = []
        var currentGroup: [DetectedHighlight] = [highlights[0]]

        for i in 1..<highlights.count {
            let current = highlights[i]
            let previous = highlights[i-1]

            // Check if highlights are close vertically (part of same highlight block)
            let verticalDistance = abs(current.boundingBox.origin.y - previous.boundingBox.origin.y)

            // Be VERY aggressive with merging - Kindle highlights often span many lines
            // Merge if they're within 0.1 units (roughly 2-3 line heights)
            // This ensures we capture complete highlighted passages
            if verticalDistance < 0.1 && current.color == previous.color {
                currentGroup.append(current)
            } else {
                // Merge the current group and start a new one
                if let mergedHighlight = mergeGroup(currentGroup) {
                    merged.append(mergedHighlight)
                }
                currentGroup = [current]
            }
        }

        // Don't forget the last group
        if let mergedHighlight = mergeGroup(currentGroup) {
            merged.append(mergedHighlight)
        }

        return merged
    }

    private func mergeGroup(_ group: [DetectedHighlight]) -> DetectedHighlight? {
        guard !group.isEmpty else { return nil }

        if group.count == 1 {
            return group[0]
        }

        // Calculate bounding box that encompasses all highlights in the group
        let minX = group.map { $0.boundingBox.minX }.min() ?? 0
        let minY = group.map { $0.boundingBox.minY }.min() ?? 0
        let maxX = group.map { $0.boundingBox.maxX }.max() ?? 1
        let maxY = group.map { $0.boundingBox.maxY }.max() ?? 1

        let mergedBox = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        // Use the color from the first highlight
        return DetectedHighlight(
            boundingBox: mergedBox,
            color: group[0].color,
            image: nil
        )
    }

    // MARK: - Detect Highlight Color

    private func detectHighlightColor(in image: UIImage, region: CGRect) -> HighlightColor? {
        guard let croppedImage = ImageProcessor.cropImage(image, toRect: region),
              let avgColor = ImageProcessor.getDominantColor(in: image, region: region) else {
            return nil
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        avgColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Convert to HSV for better color detection
        let maxC = max(red, green, blue)
        let minC = min(red, green, blue)
        let delta = maxC - minC

        // Calculate saturation and value
        let saturation = maxC == 0 ? 0 : delta / maxC
        let value = maxC

        // Only consider it a highlight if it has reasonable saturation and brightness
        // Made very lenient to catch Kindle's subtle highlights
        if saturation < 0.05 || value < 0.4 {
            return nil // Too gray or too dark
        }

        // Determine color based on RGB values (more lenient thresholds)
        // Yellow highlights
        if red > 0.75 && green > 0.65 && blue < 0.55 {
            return .yellow
        }
        // Orange highlights
        else if red > 0.75 && green > 0.45 && green < 0.75 && blue < 0.45 {
            return .orange
        }
        // Blue highlights
        else if blue > 0.65 && red < 0.55 {
            return .blue
        }
        // Pink/salmon/rose highlights (very common in Kindle) - more lenient
        else if red > 0.65 && saturation > 0.08 {
            // Any text with reddish tint and some saturation
            if green > 0.6 && blue > 0.6 {
                // Light pink/salmon
                return .pink
            } else if green < 0.7 && blue < 0.7 {
                // Darker pink/rose
                return .pink
            }
        }

        // If it has some color saturation, consider it unknown highlight
        if saturation > 0.10 && value > 0.6 {
            return .unknown
        }

        return nil
    }

}
