//
//  ScreenshotRepository.swift
//  ReadingNotesApp
//
//  Repository for managing KindleScreenshot data operations
//

import Foundation
import SwiftData
import UIKit

@MainActor
class ScreenshotRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create

    func create(screenshot: KindleScreenshot) throws {
        modelContext.insert(screenshot)
        try modelContext.save()
    }

    func createFromImageData(_ imageData: Data) throws -> KindleScreenshot {
        let screenshot = KindleScreenshot(
            imageData: imageData,
            thumbnailData: generateThumbnail(from: imageData)
        )
        modelContext.insert(screenshot)
        try modelContext.save()
        return screenshot
    }

    // MARK: - Read

    func fetchAll() throws -> [KindleScreenshot] {
        let descriptor = FetchDescriptor<KindleScreenshot>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) throws -> KindleScreenshot? {
        let allScreenshots = try fetchAll()
        return allScreenshots.first { $0.id == id }
    }

    func fetchPending() throws -> [KindleScreenshot] {
        let allScreenshots = try fetchAll()
        return allScreenshots.filter { $0.processingStatus == .pending }
    }

    func fetchUnsynced() throws -> [KindleScreenshot] {
        let allScreenshots = try fetchAll()
        return allScreenshots.filter { $0.isSyncedToNotion == false }
    }

    // MARK: - Update

    func update(screenshot: KindleScreenshot) throws {
        try modelContext.save()
    }

    func updateProcessingStatus(_ screenshot: KindleScreenshot, status: ProcessingStatus) throws {
        screenshot.processingStatus = status
        try modelContext.save()
    }

    func markAsSynced(_ screenshot: KindleScreenshot, notionPageId: String) throws {
        screenshot.isSyncedToNotion = true
        screenshot.notionPageId = notionPageId
        try modelContext.save()
    }

    // MARK: - Delete

    func delete(_ screenshot: KindleScreenshot) throws {
        modelContext.delete(screenshot)
        try modelContext.save()
    }

    func deleteAll() throws {
        let screenshots = try fetchAll()
        for screenshot in screenshots {
            modelContext.delete(screenshot)
        }
        try modelContext.save()
    }

    // MARK: - Statistics

    func count() throws -> Int {
        let descriptor = FetchDescriptor<KindleScreenshot>()
        return try modelContext.fetchCount(descriptor)
    }

    func countUnsynced() throws -> Int {
        let unsynced = try fetchUnsynced()
        return unsynced.count
    }

    // MARK: - Helper Methods

    private func generateThumbnail(from imageData: Data) -> Data? {
        #if os(iOS)
        guard let image = UIImage(data: imageData) else { return nil }

        let thumbnailSize = CGSize(width: 200, height: 300)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)

        let thumbnail = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }

        return thumbnail.jpegData(compressionQuality: 0.7)
        #else
        return nil
        #endif
    }
}
