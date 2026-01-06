//
//  NotionSyncService.swift
//  ReadingNotesApp
//
//  Service for syncing highlights and notes to Notion
//

import Foundation
import SwiftData

@MainActor
class NotionSyncService {
    private let apiClient: NotionAPIClient
    private let authService: NotionAuthService
    private let modelContext: ModelContext?

    init(modelContext: ModelContext?, authService: NotionAuthService) {
        self.modelContext = modelContext
        self.authService = authService
        self.apiClient = NotionAPIClient()
    }

    // MARK: - Sync Screenshot

    func syncScreenshotToPage(_ screenshot: KindleScreenshot, pageId: String) async throws {
        guard let accessToken = authService.getAccessToken() else {
            throw NotionSyncError.notAuthenticated
        }

        // Append highlights to existing page
        try await appendHighlightsToPage(screenshot, pageId: pageId, accessToken: accessToken)

        // Mark as synced
        screenshot.notionPageId = pageId
        screenshot.isSyncedToNotion = true

        try modelContext?.save()
    }

    func syncScreenshotToNewPage(_ screenshot: KindleScreenshot, bookTitle: String, parentPageId: String) async throws {
        guard let accessToken = authService.getAccessToken() else {
            throw NotionSyncError.notAuthenticated
        }

        // Create new page with highlights as child of parent
        let pageId = try await createPageWithHighlights(screenshot, title: bookTitle, parentPageId: parentPageId, accessToken: accessToken)

        // Mark as synced
        screenshot.notionPageId = pageId
        screenshot.isSyncedToNotion = true

        try modelContext?.save()
    }

    private func createPageWithHighlights(_ screenshot: KindleScreenshot, title: String, parentPageId: String, accessToken: String) async throws -> String {
        // Build blocks for highlights
        var children = buildHighlightBlocks(from: screenshot)

        // Create page request as child of parent page
        let request = NotionPageRequest(
            parentPageId: parentPageId,
            title: title,
            children: children.isEmpty ? nil : children
        )

        // Create page
        let response = try await apiClient.createPage(request: request, accessToken: accessToken)

        // Mark highlights as synced
        for highlight in screenshot.highlights {
            highlight.isSyncedToNotion = true
            for note in highlight.notes {
                note.isSyncedToNotion = true
            }
        }

        return response.id
    }

    private func appendHighlightsToPage(_ screenshot: KindleScreenshot, pageId: String, accessToken: String) async throws {
        // Build blocks for highlights
        let blocks = buildHighlightBlocks(from: screenshot)

        guard !blocks.isEmpty else { return }

        // Append blocks to existing page
        _ = try await apiClient.appendBlockChildren(pageId: pageId, blocks: blocks, accessToken: accessToken)

        // Mark highlights as synced
        for highlight in screenshot.highlights {
            highlight.isSyncedToNotion = true
            for note in highlight.notes {
                note.isSyncedToNotion = true
            }
        }
    }

    private func buildHighlightBlocks(from screenshot: KindleScreenshot) -> [NotionBlock] {
        var blocks: [NotionBlock] = []

        // Only include highlights that haven't been synced yet
        let unsyncedHighlights = screenshot.highlights.filter { !$0.isSyncedToNotion }


        if !unsyncedHighlights.isEmpty {
            // Add timestamp divider
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            blocks.append(.paragraph("📅 Added: \(formatter.string(from: screenshot.createdAt))"))
            blocks.append(.divider())

            for highlight in unsyncedHighlights {
                // Add highlight as callout with appropriate icon
                let icon = highlightIcon(for: highlight.highlightColor)
                blocks.append(.callout(highlight.extractedText, icon: icon))

                // Add notes as quotes under each highlight
                // Only include unsynced notes
                let unsyncedNotes = highlight.notes.filter { !$0.isSyncedToNotion }
                for note in unsyncedNotes {
                    blocks.append(.quote("💭 \(note.content)"))
                }

                // Add spacing between highlights
                blocks.append(.divider())
            }
        }

        return blocks
    }

    // MARK: - Sync Text (for Share Extension)

    /// Sync plain text to an existing Notion page
    func syncTextToPage(_ text: String, pageId: String) async throws {
        guard let accessToken = authService.getAccessToken() else {
            throw NotionSyncError.notAuthenticated
        }

        // Build blocks from text
        let blocks = buildTextBlocks(text: text)

        guard !blocks.isEmpty else { return }

        // Append blocks to existing page
        _ = try await apiClient.appendBlockChildren(pageId: pageId, blocks: blocks, accessToken: accessToken)
    }

    /// Sync plain text to a new Notion page
    func syncTextToNewPage(_ text: String, bookTitle: String, parentPageId: String) async throws -> String {
        guard let accessToken = authService.getAccessToken() else {
            throw NotionSyncError.notAuthenticated
        }

        // Build blocks from text
        let blocks = buildTextBlocks(text: text)

        // Create page request as child of parent page
        let request = NotionPageRequest(
            parentPageId: parentPageId,
            title: bookTitle,
            children: blocks.isEmpty ? nil : blocks
        )

        // Create page
        let response = try await apiClient.createPage(request: request, accessToken: accessToken)

        return response.id
    }

    private func buildTextBlocks(text: String) -> [NotionBlock] {
        var blocks: [NotionBlock] = []

        // Add timestamp divider
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        blocks.append(.paragraph("📅 Added: \(formatter.string(from: Date()))"))
        blocks.append(.divider())

        // Add text as callout (similar to highlights)
        blocks.append(.callout(text, icon: "⭐"))

        return blocks
    }

    // MARK: - Search Pages

    func searchPages(query: String = "") async throws -> [SearchResult] {
        guard let accessToken = authService.getAccessToken() else {
            throw NotionSyncError.notAuthenticated
        }

        let response = try await apiClient.searchPages(query: query, accessToken: accessToken)
        return response.results
    }

    // MARK: - Helper Methods

    private func highlightIcon(for color: HighlightColor) -> String {
        switch color {
        case .yellow:
            return "⭐"
        case .orange:
            return "🔥"
        case .blue:
            return "💙"
        case .pink:
            return "💗"
        case .unknown:
            return "✨"
        }
    }
}

// MARK: - Errors

enum NotionSyncError: LocalizedError {
    case notAuthenticated
    case noDatabaseSelected
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Notion"
        case .noDatabaseSelected:
            return "No Notion database selected"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}
