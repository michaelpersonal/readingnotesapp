//
//  NotionPage.swift
//  ReadingNotesApp
//
//  Models for Notion API page operations
//

import Foundation

// MARK: - Page Response

struct NotionPageResponse: Codable {
    let id: String
    let createdTime: String?
    let lastEditedTime: String?
    let url: String?
    let properties: [String: NotionProperty]?

    enum CodingKeys: String, CodingKey {
        case id
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
        case url
        case properties
    }

    // Custom decoder to handle properties decoding failures gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        createdTime = try? container.decode(String.self, forKey: .createdTime)
        lastEditedTime = try? container.decode(String.self, forKey: .lastEditedTime)
        url = try? container.decode(String.self, forKey: .url)

        // Try to decode properties, but if it fails, just set to nil
        properties = try? container.decode([String: NotionProperty].self, forKey: .properties)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(createdTime, forKey: .createdTime)
        try container.encodeIfPresent(lastEditedTime, forKey: .lastEditedTime)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(properties, forKey: .properties)
    }
}

// MARK: - Page Creation Request

struct NotionPageRequest: Codable {
    let parent: NotionParent
    let properties: [String: NotionProperty]
    let children: [NotionBlock]?
    let icon: NotionIcon?

    // Create page in a database
    init(databaseId: String, properties: [String: NotionProperty], children: [NotionBlock]? = nil) {
        self.parent = NotionParent(type: "database_id", databaseId: databaseId, pageId: nil, workspace: nil)
        self.properties = properties
        self.children = children
        self.icon = NotionIcon(type: "emoji", emoji: "📚")
    }

    // Create page as child of another page
    init(parentPageId: String, title: String, children: [NotionBlock]? = nil) {
        self.parent = NotionParent(type: "page_id", databaseId: nil, pageId: parentPageId, workspace: nil)
        self.properties = ["title": .title([NotionRichText(content: title)])]
        self.children = children
        self.icon = NotionIcon(type: "emoji", emoji: "📚")
    }

    // Create page at workspace level
    init(workspaceLevel: Bool, title: String, children: [NotionBlock]? = nil) {
        self.parent = NotionParent(type: "workspace", databaseId: nil, pageId: nil, workspace: true)
        self.properties = ["title": .title([NotionRichText(content: title)])]
        self.children = children
        self.icon = NotionIcon(type: "emoji", emoji: "📚")
    }
}

// MARK: - Parent

struct NotionParent: Codable {
    let type: String
    let databaseId: String?
    let pageId: String?
    let workspace: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case databaseId = "database_id"
        case pageId = "page_id"
        case workspace
    }

    init(type: String, databaseId: String?, pageId: String?, workspace: Bool?) {
        self.type = type
        self.databaseId = databaseId
        self.pageId = pageId
        self.workspace = workspace
    }
}

// MARK: - Icon

struct NotionIcon: Codable {
    let type: String
    let emoji: String
}

// MARK: - Properties

enum NotionProperty: Codable {
    case title([NotionRichText])
    case richText([NotionRichText])
    case date(NotionDate)
    case select(NotionSelect)
    case multiSelect([NotionSelect])
    case number(Double)
    case checkbox(Bool)
    case url(String)

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case richText = "rich_text"
        case date
        case select
        case multiSelect = "multi_select"
        case number
        case checkbox
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "title":
            let texts = try container.decode([NotionRichText].self, forKey: .title)
            self = .title(texts)
        case "rich_text":
            let texts = try container.decode([NotionRichText].self, forKey: .richText)
            self = .richText(texts)
        case "date":
            let date = try container.decode(NotionDate.self, forKey: .date)
            self = .date(date)
        case "select":
            let select = try container.decode(NotionSelect.self, forKey: .select)
            self = .select(select)
        case "multi_select":
            let selects = try container.decode([NotionSelect].self, forKey: .multiSelect)
            self = .multiSelect(selects)
        case "number":
            let number = try container.decode(Double.self, forKey: .number)
            self = .number(number)
        case "checkbox":
            let checkbox = try container.decode(Bool.self, forKey: .checkbox)
            self = .checkbox(checkbox)
        case "url":
            let url = try container.decode(String.self, forKey: .url)
            self = .url(url)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown property type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .title(let texts):
            try container.encode("title", forKey: .type)
            try container.encode(texts, forKey: .title)
        case .richText(let texts):
            try container.encode("rich_text", forKey: .type)
            try container.encode(texts, forKey: .richText)
        case .date(let date):
            try container.encode("date", forKey: .type)
            try container.encode(date, forKey: .date)
        case .select(let select):
            try container.encode("select", forKey: .type)
            try container.encode(select, forKey: .select)
        case .multiSelect(let selects):
            try container.encode("multi_select", forKey: .type)
            try container.encode(selects, forKey: .multiSelect)
        case .number(let number):
            try container.encode("number", forKey: .type)
            try container.encode(number, forKey: .number)
        case .checkbox(let checkbox):
            try container.encode("checkbox", forKey: .type)
            try container.encode(checkbox, forKey: .checkbox)
        case .url(let url):
            try container.encode("url", forKey: .type)
            try container.encode(url, forKey: .url)
        }
    }
}

// MARK: - Rich Text

struct NotionRichText: Codable {
    let type: String = "text"
    let text: NotionText
    let annotations: NotionAnnotations?
    let plainText: String?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case annotations
        case plainText = "plain_text"
    }

    init(content: String, link: String? = nil) {
        self.text = NotionText(content: content, link: link)
        self.annotations = nil
        self.plainText = content
    }
}

struct NotionText: Codable {
    let content: String
    let link: NotionLink?

    init(content: String, link: String? = nil) {
        self.content = content
        self.link = link != nil ? NotionLink(url: link!) : nil
    }
}

struct NotionLink: Codable {
    let url: String
}

struct NotionAnnotations: Codable {
    let bold: Bool?
    let italic: Bool?
    let strikethrough: Bool?
    let underline: Bool?
    let code: Bool?
    let color: String?
}

// MARK: - Date

struct NotionDate: Codable {
    let start: String
    let end: String?
    let timeZone: String?

    enum CodingKeys: String, CodingKey {
        case start
        case end
        case timeZone = "time_zone"
    }

    init(start: Date) {
        let formatter = ISO8601DateFormatter()
        self.start = formatter.string(from: start)
        self.end = nil
        self.timeZone = nil
    }
}

// MARK: - Select

struct NotionSelect: Codable {
    let name: String
    let color: String?

    init(name: String) {
        self.name = name
        self.color = nil
    }
}
