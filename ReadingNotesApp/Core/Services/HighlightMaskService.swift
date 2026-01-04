//
//  HighlightMaskService.swift
//  ReadingNotesApp
//
//  Service for creating binary masks of highlight regions
//

import Foundation
import UIKit
import CoreImage

/// Binary mask service for highlight detection
@MainActor
class HighlightMaskService {
    
    // MARK: - Mask Generation
    
    /// Create a binary mask of pink highlight regions
    /// Returns a CIImage mask where white pixels = highlight, black = background
    static func createHighlightMask(from image: UIImage) -> CIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        
        // Step 1: Convert to HSV-like color space for better pink detection
        // We'll use RGB thresholds but in a more structured way
        
        // Step 2: Create mask using color thresholding
        let mask = createPinkMask(ciImage: ciImage)
        
        // Step 3: Apply morphological operations
        let cleanedMask = applyMorphology(to: mask)
        
        return cleanedMask
    }
    
    // MARK: - Pink Detection
    
    /// Create a mask for pink highlights using RGB color thresholds
    private static func createPinkMask(ciImage: CIImage) -> CIImage {
        // Pink highlights in RGB:
        // - High red (R > 0.55 in normalized 0-1, or > 140 in 0-255)
        // - Medium-high green (G > 0.35, or > 90)
        // - Medium-high blue (B > 0.35, or > 90)
        // - Red is dominant (R > B + 0.1, or R > B + 25)
        // - Not too dark (average > 0.4, or > 100)
        
        // Use Core Image filters to create mask
        // We'll use a combination of color controls and color matrix
        
        // Create a custom kernel for pink detection
        let kernel = CIColorKernel(source: """
            kernel vec4 pinkMask(__sample s) {
                float r = s.r;
                float g = s.g;
                float b = s.b;
                
                // Pink detection thresholds (normalized 0-1) - more lenient
                bool isPink = r > 0.50 && g > 0.30 && b > 0.30 &&
                              (r - b) > 0.05 &&
                              ((r + g + b) / 3.0) > 0.35;
                
                // Return white (1,1,1,1) for pink, black (0,0,0,1) otherwise
                float mask = isPink ? 1.0 : 0.0;
                return vec4(mask, mask, mask, 1.0);
            }
        """)
        
        if let kernel = kernel {
            return kernel.apply(extent: ciImage.extent, arguments: [ciImage]) ?? ciImage
        }
        
        // Fallback: use pixel-by-pixel processing
        return createPinkMaskPixelBased(ciImage: ciImage)
    }
    
    /// Fallback: Create mask using pixel-based processing
    private static func createPinkMaskPixelBased(ciImage: CIImage) -> CIImage {
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return ciImage
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var inputData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        var outputData = [UInt8](repeating: 0, count: width * height)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let inputContext = CGContext(
            data: &inputData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return ciImage
        }
        
        inputContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Process pixels
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = Float(inputData[offset]) / 255.0
                let g = Float(inputData[offset + 1]) / 255.0
                let b = Float(inputData[offset + 2]) / 255.0
                
                // More lenient pink detection - adjust thresholds to catch more highlights
                let isPink = r > 0.50 && g > 0.30 && b > 0.30 &&
                            (r - b) > 0.05 &&  // Reduced from 0.1
                            ((r + g + b) / 3.0) > 0.35  // Reduced from 0.4
                
                outputData[y * width + x] = isPink ? 255 : 0
            }
        }
        
        // Create output image
        guard let outputContext = CGContext(
            data: &outputData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ),
        let outputCGImage = outputContext.makeImage() else {
            return ciImage
        }
        
        return CIImage(cgImage: outputCGImage)
    }
    
    // MARK: - Morphological Operations
    
    /// Apply morphological operations to clean up the mask
    private static func applyMorphology(to mask: CIImage) -> CIImage {
        var result = mask
        
        // 1. Closing: dilate then erode to fill small gaps
        if let closingFilter = CIFilter(name: "CIMorphologyGradient") {
            // Use a small radius for closing
            // Note: Core Image doesn't have direct closing, so we'll use dilation + erosion
            if let dilateFilter = CIFilter(name: "CIMorphologyMaximum") {
                dilateFilter.setValue(result, forKey: kCIInputImageKey)
                dilateFilter.setValue(2.0, forKey: kCIInputRadiusKey)
                if let dilated = dilateFilter.outputImage {
                    if let erodeFilter = CIFilter(name: "CIMorphologyMinimum") {
                        erodeFilter.setValue(dilated, forKey: kCIInputImageKey)
                        erodeFilter.setValue(2.0, forKey: kCIInputRadiusKey)
                        if let closed = erodeFilter.outputImage {
                            result = closed
                        }
                    }
                }
            }
        }
        
        // 2. Opening: erode then dilate to remove small noise
        if let erodeFilter = CIFilter(name: "CIMorphologyMinimum") {
            erodeFilter.setValue(result, forKey: kCIInputImageKey)
            erodeFilter.setValue(1.0, forKey: kCIInputRadiusKey)
            if let eroded = erodeFilter.outputImage {
                if let dilateFilter = CIFilter(name: "CIMorphologyMaximum") {
                    dilateFilter.setValue(eroded, forKey: kCIInputImageKey)
                    dilateFilter.setValue(1.0, forKey: kCIInputRadiusKey)
                    if let opened = dilateFilter.outputImage {
                        result = opened
                    }
                }
            }
        }
        
        return result
    }
    
    // MARK: - Mask Utilities
    
    /// Check if a pixel in the mask is a highlight (white)
    static func isHighlightPixel(in mask: CIImage, at point: CGPoint, imageSize: CGSize) -> Bool {
        let context = CIContext()
        guard let cgMask = context.createCGImage(mask, from: mask.extent) else {
            return false
        }
        
        let width = cgMask.width
        let height = cgMask.height
        
        // Convert point to pixel coordinates
        let x = Int(point.x * CGFloat(width) / imageSize.width)
        let y = Int(point.y * CGFloat(height) / imageSize.height)
        
        guard x >= 0 && x < width && y >= 0 && y < height else {
            return false
        }
        
        // Read pixel value
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixelData: [UInt8] = [0]
        
        guard let context = CGContext(
            data: &pixelData,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 1,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return false
        }
        
        context.draw(cgMask, in: CGRect(x: -x, y: -y, width: width, height: height))
        
        return pixelData[0] > 128 // White pixel = highlight
    }
    
    /// Calculate overlap ratio between a text bounding box and the highlight mask
    /// textBox is in normalized coordinates (0-1) with Vision's bottom-left origin
    static func calculateOverlapRatio(
        textBox: CGRect,
        mask: CIImage,
        imageSize: CGSize
    ) -> Float {
        let context = CIContext()
        guard let cgMask = context.createCGImage(mask, from: mask.extent) else {
            return 0.0
        }
        
        let maskWidth = cgMask.width
        let maskHeight = cgMask.height
        
        // Convert normalized textBox to pixel coordinates
        // Vision uses bottom-left origin, mask uses top-left, so flip Y
        let pixelX = textBox.origin.x * imageSize.width
        let pixelY = (1.0 - textBox.origin.y - textBox.height) * imageSize.height
        let pixelWidth = textBox.width * imageSize.width
        let pixelHeight = textBox.height * imageSize.height
        
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
        
        // Read mask pixels in the text box region
        let sampleWidth = maxX - minX
        let sampleHeight = maxY - minY
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
        
        // Draw the relevant portion of the mask
        let sourceRect = CGRect(x: minX, y: minY, width: sampleWidth, height: sampleHeight)
        bitmapContext.draw(
            cgMask,
            in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight),
            byTiling: false
        )
        
        // Count highlight pixels (white = > 128)
        var highlightPixels = 0
        for pixel in pixelData {
            if pixel > 128 {
                highlightPixels += 1
            }
        }
        
        let totalPixels = sampleWidth * sampleHeight
        return totalPixels > 0 ? Float(highlightPixels) / Float(totalPixels) : 0.0
    }
}

