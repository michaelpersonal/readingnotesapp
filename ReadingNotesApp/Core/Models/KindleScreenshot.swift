//
//  KindleScreenshot.swift
//  ReadingNotesApp
//
//  Core data model representing a Kindle screenshot
//

import Foundation
import SwiftData

@Model
final class KindleScreenshot {
    var id: UUID
    var createdAt: Date
    var imageData: Data?
    var thumbnailData: Data?
    var sourceBook: String?
    var pageNumber: String?
    var processingStatus: ProcessingStatus
    var highlights: [Highlight]
    var isSyncedToNotion: Bool
    var notionPageId: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        sourceBook: String? = nil,
        pageNumber: String? = nil,
        processingStatus: ProcessingStatus = .pending,
        highlights: [Highlight] = [],
        isSyncedToNotion: Bool = false,
        notionPageId: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.sourceBook = sourceBook
        self.pageNumber = pageNumber
        self.processingStatus = processingStatus
        self.highlights = highlights
        self.isSyncedToNotion = isSyncedToNotion
        self.notionPageId = notionPageId
    }
}

// MARK: - Processing Status
enum ProcessingStatus: String, Codable {
    case pending
    case processing
    case completed
    case failed

    var displayText: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing..."
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }
}
