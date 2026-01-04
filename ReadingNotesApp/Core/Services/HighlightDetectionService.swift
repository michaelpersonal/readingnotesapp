//
//  HighlightDetectionService.swift
//  ReadingNotesApp
//
//  Service for detecting highlighted regions using color segmentation
//

import Foundation
import UIKit
import CoreImage
import Vision

struct DetectedHighlight {
    let boundingBox: CGRect
    let color: HighlightColor
    let image: UIImage?
    let mask: CIImage? // Store mask for filtering
}

@MainActor
class HighlightDetectionService {
    
    // MARK: - Color-Based Highlight Detection
    
    /// Detect highlights by color segmentation first, then return bounding boxes
    func detectHighlights(in image: UIImage) async -> [DetectedHighlight] {
        guard let cgImage = image.cgImage else { return [] }
        
        // Step 1: Create binary highlight mask
        guard let mask = HighlightMaskService.createHighlightMask(from: image) else {
            return []
        }
        
        // Step 2: Find connected components (contours) from the mask
        let boundingBoxes = findConnectedComponents(in: mask, imageSize: CGSize(width: cgImage.width, height: cgImage.height))
        
        // Step 3: Merge adjacent regions that likely belong to same passage
        // Use more conservative merging to avoid including non-highlighted lines
        let mergedBoxes = mergeAdjacentRegions(boundingBoxes, imageSize: CGSize(width: cgImage.width, height: cgImage.height))
        
        // Step 4: Convert to normalized coordinates and create DetectedHighlight objects
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        return mergedBoxes.map { box in
            // Convert pixel coordinates to normalized (0-1) coordinates
            // Vision uses bottom-left origin, so we need to flip Y
            let normalizedBox = CGRect(
                x: box.origin.x / imageWidth,
                y: 1.0 - (box.origin.y + box.height) / imageHeight,
                width: box.width / imageWidth,
                height: box.height / imageHeight
            )
            
            return DetectedHighlight(
                boundingBox: normalizedBox,
                color: .pink, // Detected as pink highlight
                image: nil,
                mask: mask // Store mask for later filtering
            )
        }
    }
    
    // MARK: - Connected Component Analysis
    
    /// Find connected components from the binary mask
    private func findConnectedComponents(in mask: CIImage, imageSize: CGSize) -> [CGRect] {
        let context = CIContext()
        guard let cgMask = context.createCGImage(mask, from: mask.extent) else {
            return []
        }
        
        let width = cgMask.width
        let height = cgMask.height
        
        // Read mask pixels
        var pixelData = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let bitmapContext = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return []
        }
        
        bitmapContext.draw(cgMask, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Find connected components using flood fill
        var visited = Array(repeating: Array(repeating: false, count: width), count: height)
        var boundingBoxes: [CGRect] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * width + x
                let isHighlight = pixelData[offset] > 128 // White = highlight
                
                if isHighlight && !visited[y][x] {
                    // Flood fill to find connected component
                    var minX = x
                    var maxX = x
                    var minY = y
                    var maxY = y
                    
                    var stack = [(x: Int, y: Int)]()
                    stack.append((x, y))
                    visited[y][x] = true
                    
                    while !stack.isEmpty {
                        let (cx, cy) = stack.removeLast()
                        minX = min(minX, cx)
                        maxX = max(maxX, cx)
                        minY = min(minY, cy)
                        maxY = max(maxY, cy)
                        
                        // Check 8-connected neighbors
                        for dy in -1...1 {
                            for dx in -1...1 {
                                if dx == 0 && dy == 0 { continue }
                                let nx = cx + dx
                                let ny = cy + dy
                                
                                if nx >= 0 && nx < width && ny >= 0 && ny < height && !visited[ny][nx] {
                                    let nOffset = ny * width + nx
                                    if pixelData[nOffset] > 128 {
                                        visited[ny][nx] = true
                                        stack.append((nx, ny))
                                    }
                                }
                            }
                        }
                    }
                    
                    // Create bounding box for this component
                    let bbox = CGRect(
                        x: CGFloat(minX),
                        y: CGFloat(minY),
                        width: CGFloat(maxX - minX + 1),
                        height: CGFloat(maxY - minY + 1)
                    )
                    
                    // Filter out very small regions (noise)
                    if bbox.width >= 20 && bbox.height >= 10 {
                        boundingBoxes.append(bbox)
                    }
                }
            }
        }
        
        return boundingBoxes
    }
    
    // MARK: - Region Merging
    
    /// Merge adjacent regions that likely belong to the same highlighted passage
    /// Uses conservative merging to avoid including non-highlighted lines
    private func mergeAdjacentRegions(_ boxes: [CGRect], imageSize: CGSize) -> [CGRect] {
        guard !boxes.isEmpty else { return [] }
        
        // Sort by vertical position (top to bottom)
        let sorted = boxes.sorted { $0.origin.y < $1.origin.y }
        
        // Estimate average line height from boxes
        let avgHeight = sorted.prefix(min(5, sorted.count)).map { $0.height }.reduce(0, +) / CGFloat(min(5, sorted.count))
        let lineHeight = max(avgHeight, 20.0) // Minimum line height
        
        var merged: [CGRect] = []
        var currentGroup: [CGRect] = [sorted[0]]
        
        for i in 1..<sorted.count {
            let current = sorted[i]
            let previous = sorted[i-1]
            
            // Calculate vertical gap
            let verticalGap = current.origin.y - (previous.origin.y + previous.height)
            
            // Calculate horizontal overlap
            let horizontalOverlap = max(0, min(current.maxX, previous.maxX) - max(current.minX, previous.minX))
            let minWidth = min(current.width, previous.width)
            let overlapRatio = minWidth > 0 ? horizontalOverlap / minWidth : 0
            
            // Check width consistency (similar width suggests same line/paragraph)
            let widthRatio = min(current.width, previous.width) / max(current.width, previous.width)
            let similarWidth = widthRatio > 0.7
            
            // Check left alignment (similar left edge suggests same paragraph)
            let leftAlignmentDiff = abs(current.origin.x - previous.origin.x)
            let similarAlignment = leftAlignmentDiff < lineHeight * 0.3
            
            // Conservative merging criteria:
            // 1. Vertical gap < 0.8 * lineHeight (very close vertically)
            // 2. Horizontal overlap > 50% (significant overlap)
            // 3. Similar width OR similar left alignment (belongs to same passage)
            let shouldMerge = verticalGap < (lineHeight * 0.8) &&
                             overlapRatio > 0.5 &&
                             (similarWidth || similarAlignment)
            
            if shouldMerge {
                currentGroup.append(current)
            } else {
                // Merge current group
                if let mergedBox = mergeGroup(currentGroup) {
                    merged.append(mergedBox)
                }
                currentGroup = [current]
            }
        }
        
        // Don't forget last group
        if let mergedBox = mergeGroup(currentGroup) {
            merged.append(mergedBox)
        }
        
        return merged
    }
    
    private func mergeGroup(_ group: [CGRect]) -> CGRect? {
        guard !group.isEmpty else { return nil }
        if group.count == 1 { return group[0] }
        
        let minX = group.map { $0.minX }.min() ?? 0
        let minY = group.map { $0.minY }.min() ?? 0
        let maxX = group.map { $0.maxX }.max() ?? 0
        let maxY = group.map { $0.maxY }.max() ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
