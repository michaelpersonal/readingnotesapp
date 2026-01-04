//
//  NotionConfig.swift
//  ReadingNotesApp
//
//  Configuration for Notion API integration
//

import Foundation
import SwiftData

@Model
final class NotionConfig {
    var id: UUID
    var accessToken: String?
    var workspaceId: String?
    var targetDatabaseId: String?
    var lastSyncDate: Date?
    var autoSyncEnabled: Bool

    init(
        id: UUID = UUID(),
        accessToken: String? = nil,
        workspaceId: String? = nil,
        targetDatabaseId: String? = nil,
        lastSyncDate: Date? = nil,
        autoSyncEnabled: Bool = false
    ) {
        self.id = id
        self.accessToken = accessToken
        self.workspaceId = workspaceId
        self.targetDatabaseId = targetDatabaseId
        self.lastSyncDate = lastSyncDate
        self.autoSyncEnabled = autoSyncEnabled
    }

    var isConfigured: Bool {
        accessToken != nil && targetDatabaseId != nil
    }
}
