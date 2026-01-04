//
//  ImageProcessor.swift
//  ReadingNotesApp
//
//  Utility for image processing operations
//

import Foundation
import UIKit
import CoreImage

class ImageProcessor {

    // MARK: - Image Enhancement

    static func enhanceForOCR(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let context = CIContext()
        var ciImage = CIImage(cgImage: cgImage)

        // Increase contrast
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(1.3, forKey: kCIInputContrastKey)
            filter.setValue(1.1, forKey: kCIInputBrightnessKey)
            if let output = filter.outputImage {
                ciImage = output
            }
        }

        // Sharpen
        if let filter = CIFilter(name: "CISharpenLuminance") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(0.8, forKey: kCIInputSharpnessKey)
            if let output = filter.outputImage {
                ciImage = output
            }
        }

        guard let processedCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: processedCGImage)
    }

    // MARK: - Color Analysis

    static func getDominantColor(in image: UIImage, region: CGRect) -> UIColor? {
        guard let croppedImage = cropImage(image, toRect: region),
              let cgImage = croppedImage.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        var count: CGFloat = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let red = CGFloat(pixelData[offset]) / 255.0
                let green = CGFloat(pixelData[offset + 1]) / 255.0
                let blue = CGFloat(pixelData[offset + 2]) / 255.0

                totalRed += red
                totalGreen += green
                totalBlue += blue
                count += 1
            }
        }

        return UIColor(
            red: totalRed / count,
            green: totalGreen / count,
            blue: totalBlue / count,
            alpha: 1.0
        )
    }

    // MARK: - Image Cropping

    static func cropImage(_ image: UIImage, toRect rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        // Convert normalized coordinates (0-1) to pixel coordinates
        // Vision uses bottom-left origin, so we need to flip Y
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

    // MARK: - Thumbnail Generation

    static func generateThumbnail(from image: UIImage, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - Image Scaling

    static func scaleImage(_ image: UIImage, toMaxDimension maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let maxCurrentDimension = max(size.width, size.height)

        if maxCurrentDimension <= maxDimension {
            return image
        }

        let scale = maxDimension / maxCurrentDimension
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
