//
//  ScreenshotListViewModel.swift
//  ReadingNotesApp
//
//  ViewModel for the screenshot list view
//

import Foundation
import SwiftData

@MainActor
@Observable
class ScreenshotListViewModel {
    private let repository: ScreenshotRepository
    private let modelContext: ModelContext

    var screenshots: [KindleScreenshot] = []
    var isLoading = false
    var errorMessage: String?
    var showError = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.repository = ScreenshotRepository(modelContext: modelContext)
    }

    // MARK: - Data Loading

    func loadScreenshots() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                screenshots = try repository.fetchAll()
                isLoading = false
            } catch {
                errorMessage = "Failed to load screenshots: \(error.localizedDescription)"
                showError = true
                isLoading = false
            }
        }
    }

    // MARK: - Import

    func importScreenshot(imageData: Data) {
        Task {
            do {
                let screenshot = try repository.createFromImageData(imageData)
                screenshots.insert(screenshot, at: 0)
            } catch {
                errorMessage = "Failed to import screenshot: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    // MARK: - Delete

    func deleteScreenshot(_ screenshot: KindleScreenshot) {
        Task {
            do {
                try repository.delete(screenshot)
                screenshots.removeAll { $0.id == screenshot.id }
            } catch {
                errorMessage = "Failed to delete screenshot: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    func deleteScreenshots(at offsets: IndexSet) {
        Task {
            do {
                for index in offsets {
                    let screenshot = screenshots[index]
                    try repository.delete(screenshot)
                }
                screenshots.remove(atOffsets: offsets)
            } catch {
                errorMessage = "Failed to delete screenshots: \(error.localizedDescription)"
                showError = true
            }
        }
    }

    // MARK: - Statistics

    func getStatistics() -> (total: Int, unsynced: Int) {
        do {
            let total = try repository.count()
            let unsynced = try repository.countUnsynced()
            return (total, unsynced)
        } catch {
            return (0, 0)
        }
    }
}
