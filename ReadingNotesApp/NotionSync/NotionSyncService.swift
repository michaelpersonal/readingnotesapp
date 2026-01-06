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

    func syncScreenshotToPage(_ screenshot: KindleScreenshot, pageId: String, aiNotes: [String] = [], includeHighlights: Bool = true) async throws {
        guard let accessToken = authService.getAccessToken() else {
            throw NotionSyncError.notAuthenticated
        }

        // Append highlights to existing page
        try await appendHighlightsToPage(screenshot, pageId: pageId, accessToken: accessToken, aiNotes: aiNotes, includeHighlights: includeHighlights)

        // Mark as synced
        screenshot.notionPageId = pageId
        screenshot.isSyncedToNotion = true

        try modelContext?.save()
    }

    func syncScreenshotToNewPage(_ screenshot: KindleScreenshot, bookTitle: String, parentPageId: String, aiNotes: [String] = [], includeHighlights: Bool = true) async throws {
        guard let accessToken = authService.getAccessToken() else {
            throw NotionSyncError.notAuthenticated
        }

        // Create new page with highlights as child of parent
        let pageId = try await createPageWithHighlights(screenshot, title: bookTitle, parentPageId: parentPageId, accessToken: accessToken, aiNotes: aiNotes, includeHighlights: includeHighlights)

        // Mark as synced
        screenshot.notionPageId = pageId
        screenshot.isSyncedToNotion = true

        try modelContext?.save()
    }

    private func createPageWithHighlights(_ screenshot: KindleScreenshot, title: String, parentPageId: String, accessToken: String, aiNotes: [String] = [], includeHighlights: Bool = true) async throws -> String {
        // Build blocks for highlights
        var children: [NotionBlock] = []
        
        if includeHighlights {
            children = buildHighlightBlocks(from: screenshot)
        }
        
        // Add AI notes if present
        if !aiNotes.isEmpty {
            children.append(contentsOf: buildAINotesBlocks(aiNotes))
        }

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

    private func appendHighlightsToPage(_ screenshot: KindleScreenshot, pageId: String, accessToken: String, aiNotes: [String] = [], includeHighlights: Bool = true) async throws {
        // Build blocks for highlights
        var blocks: [NotionBlock] = []
        
        if includeHighlights {
            blocks = buildHighlightBlocks(from: screenshot)
        }
        
        // Add AI notes if present
        if !aiNotes.isEmpty {
            blocks.append(contentsOf: buildAINotesBlocks(aiNotes))
        }

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
                // Add highlight as callout with appropriate icon, splitting long text
                let icon = highlightIcon(for: highlight.highlightColor)
                let chunks = splitTextIntoChunks(highlight.extractedText, maxLength: 1900)
                for (index, chunk) in chunks.enumerated() {
                    let chunkIcon = index == 0 ? icon : "↳"
                    blocks.append(.callout(chunk, icon: chunkIcon))
                }

                // Add notes as quotes under each highlight
                // Only include unsynced notes
                let unsyncedNotes = highlight.notes.filter { !$0.isSyncedToNotion }
                for note in unsyncedNotes {
                    let noteChunks = splitTextIntoChunks("💭 \(note.content)", maxLength: 1900)
                    for chunk in noteChunks {
                        blocks.append(.quote(chunk))
                    }
                }

                // Add spacing between highlights
                blocks.append(.divider())
            }
        }

        return blocks
    }

    // MARK: - Sync Text (for Share Extension)

    /// Sync plain text to an existing Notion page
    func syncTextToPage(_ text: String, pageId: String, aiNotes: [String] = []) async throws {
        guard let accessToken = authService.getAccessToken() else {
            throw NotionSyncError.notAuthenticated
        }

        // Build blocks from text
        var blocks = buildTextBlocks(text: text)
        
        // Add AI notes if present
        if !aiNotes.isEmpty {
            blocks.append(contentsOf: buildAINotesBlocks(aiNotes))
        }

        guard !blocks.isEmpty else { return }

        // Append blocks to existing page
        _ = try await apiClient.appendBlockChildren(pageId: pageId, blocks: blocks, accessToken: accessToken)
    }

    /// Sync plain text to a new Notion page
    func syncTextToNewPage(_ text: String, bookTitle: String, parentPageId: String, aiNotes: [String] = []) async throws -> String {
        guard let accessToken = authService.getAccessToken() else {
            throw NotionSyncError.notAuthenticated
        }

        // Build blocks from text
        var blocks = buildTextBlocks(text: text)
        
        // Add AI notes if present
        if !aiNotes.isEmpty {
            blocks.append(contentsOf: buildAINotesBlocks(aiNotes))
        }

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

        // Add text as callout, splitting long text into chunks
        let chunks = splitTextIntoChunks(text, maxLength: 1900)
        for (index, chunk) in chunks.enumerated() {
            let icon = index == 0 ? "⭐" : "↳"
            blocks.append(.callout(chunk, icon: icon))
        }

        return blocks
    }
    
    private func buildAINotesBlocks(_ notes: [String]) -> [NotionBlock] {
        var blocks: [NotionBlock] = []
        
        // Add AI insights section header
        blocks.append(.divider())
        blocks.append(.heading3("💡 AI Insights"))
        
        // Add each note, splitting long text into chunks
        for note in notes {
            let chunks = splitTextIntoChunks(note, maxLength: 1900) // Leave margin for safety
            for (index, chunk) in chunks.enumerated() {
                // Only show icon on first chunk
                let icon = index == 0 ? "🤖" : "↳"
                blocks.append(.callout(chunk, icon: icon))
            }
        }
        
        return blocks
    }
    
    /// Split text into chunks that fit within Notion's 2000 character limit
    private func splitTextIntoChunks(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else {
            return [text]
        }
        
        var chunks: [String] = []
        var remaining = text
        
        while !remaining.isEmpty {
            if remaining.count <= maxLength {
                chunks.append(remaining)
                break
            }
            
            // Find a good break point (end of sentence or paragraph)
            let searchRange = remaining.prefix(maxLength)
            
            // Try to break at paragraph
            if let paragraphBreak = searchRange.lastIndex(of: "\n") {
                let chunk = String(remaining[..<paragraphBreak])
                chunks.append(chunk)
                remaining = String(remaining[remaining.index(after: paragraphBreak)...])
            }
            // Try to break at sentence
            else if let sentenceBreak = searchRange.lastIndex(where: { $0 == "." || $0 == "!" || $0 == "?" }) {
                let endIndex = remaining.index(after: sentenceBreak)
                let chunk = String(remaining[..<endIndex])
                chunks.append(chunk)
                remaining = String(remaining[endIndex...]).trimmingCharacters(in: .whitespaces)
            }
            // Try to break at space
            else if let spaceBreak = searchRange.lastIndex(of: " ") {
                let chunk = String(remaining[..<spaceBreak])
                chunks.append(chunk)
                remaining = String(remaining[remaining.index(after: spaceBreak)...])
            }
            // Hard break
            else {
                let endIndex = remaining.index(remaining.startIndex, offsetBy: maxLength)
                let chunk = String(remaining[..<endIndex])
                chunks.append(chunk)
                remaining = String(remaining[endIndex...])
            }
        }
        
        return chunks
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
