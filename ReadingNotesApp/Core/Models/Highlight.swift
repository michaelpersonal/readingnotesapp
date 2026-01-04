//
//  Highlight.swift
//  ReadingNotesApp
//
//  Represents a highlighted text region extracted from a screenshot
//

import Foundation
import SwiftData

@Model
final class Highlight {
    var id: UUID
    var screenshot: KindleScreenshot?
    var extractedText: String
    var confidence: Double
    var boundingBox: BoundingBox?
    var highlightColor: HighlightColor
    var notes: [Note]
    var createdAt: Date
    var isSyncedToNotion: Bool
    var notionBlockId: String?

    init(
        id: UUID = UUID(),
        screenshot: KindleScreenshot? = nil,
        extractedText: String = "",
        confidence: Double = 0.0,
        boundingBox: BoundingBox? = nil,
        highlightColor: HighlightColor = .yellow,
        notes: [Note] = [],
        createdAt: Date = Date(),
        isSyncedToNotion: Bool = false,
        notionBlockId: String? = nil
    ) {
        self.id = id
        self.screenshot = screenshot
        self.extractedText = extractedText
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.highlightColor = highlightColor
        self.notes = notes
        self.createdAt = createdAt
        self.isSyncedToNotion = isSyncedToNotion
        self.notionBlockId = notionBlockId
    }
}

// MARK: - Supporting Types

struct BoundingBox: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

enum HighlightColor: String, Codable, CaseIterable {
    case yellow
    case orange
    case blue
    case pink
    case unknown

    var displayName: String {
        rawValue.capitalized
    }
}
