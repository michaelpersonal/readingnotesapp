//
//  Note.swift
//  ReadingNotesApp
//
//  Represents a user's personal note on a highlight
//

import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var highlight: Highlight?
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isSyncedToNotion: Bool
    var notionBlockId: String?

    init(
        id: UUID = UUID(),
        highlight: Highlight? = nil,
        content: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isSyncedToNotion: Bool = false,
        notionBlockId: String? = nil
    ) {
        self.id = id
        self.highlight = highlight
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isSyncedToNotion = isSyncedToNotion
        self.notionBlockId = notionBlockId
    }

    func updateContent(_ newContent: String) {
        self.content = newContent
        self.updatedAt = Date()
        self.isSyncedToNotion = false
    }
}
