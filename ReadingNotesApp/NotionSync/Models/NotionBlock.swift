//
//  NotionBlock.swift
//  ReadingNotesApp
//
//  Models for Notion API block operations
//

import Foundation

// MARK: - Block Response

struct NotionBlockResponse: Codable {
    let id: String
    let type: String
    let createdTime: String?
    let lastEditedTime: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case createdTime = "created_time"
        case lastEditedTime = "last_edited_time"
    }
}

// MARK: - Block

struct NotionBlock: Codable {
    let type: String
    let paragraph: ParagraphBlock?
    let heading1: HeadingBlock?
    let heading2: HeadingBlock?
    let heading3: HeadingBlock?
    let callout: CalloutBlock?
    let quote: QuoteBlock?
    let bulletedListItem: BulletedListItemBlock?
    let numberedListItem: NumberedListItemBlock?
    let image: ImageBlock?
    let divider: DividerBlock?

    enum CodingKeys: String, CodingKey {
        case type
        case paragraph
        case heading1 = "heading_1"
        case heading2 = "heading_2"
        case heading3 = "heading_3"
        case callout
        case quote
        case bulletedListItem = "bulleted_list_item"
        case numberedListItem = "numbered_list_item"
        case image
        case divider
    }

    // Custom encoding to only include the relevant block type
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch type {
        case "paragraph":
            try container.encode(paragraph, forKey: .paragraph)
        case "heading_1":
            try container.encode(heading1, forKey: .heading1)
        case "heading_2":
            try container.encode(heading2, forKey: .heading2)
        case "heading_3":
            try container.encode(heading3, forKey: .heading3)
        case "callout":
            try container.encode(callout, forKey: .callout)
        case "quote":
            try container.encode(quote, forKey: .quote)
        case "bulleted_list_item":
            try container.encode(bulletedListItem, forKey: .bulletedListItem)
        case "numbered_list_item":
            try container.encode(numberedListItem, forKey: .numberedListItem)
        case "image":
            try container.encode(image, forKey: .image)
        case "divider":
            try container.encode(divider, forKey: .divider)
        default:
            break
        }
    }

    // MARK: - Factory Methods

    static func paragraph(_ text: String) -> NotionBlock {
        NotionBlock(
            type: "paragraph",
            paragraph: ParagraphBlock(richText: [NotionRichText(content: text)]),
            heading1: nil,
            heading2: nil,
            heading3: nil,
            callout: nil,
            quote: nil,
            bulletedListItem: nil,
            numberedListItem: nil,
            image: nil,
            divider: nil
        )
    }

    static func heading1(_ text: String) -> NotionBlock {
        NotionBlock(
            type: "heading_1",
            paragraph: nil,
            heading1: HeadingBlock(richText: [NotionRichText(content: text)]),
            heading2: nil,
            heading3: nil,
            callout: nil,
            quote: nil,
            bulletedListItem: nil,
            numberedListItem: nil,
            image: nil,
            divider: nil
        )
    }

    static func heading2(_ text: String) -> NotionBlock {
        NotionBlock(
            type: "heading_2",
            paragraph: nil,
            heading1: nil,
            heading2: HeadingBlock(richText: [NotionRichText(content: text)]),
            heading3: nil,
            callout: nil,
            quote: nil,
            bulletedListItem: nil,
            numberedListItem: nil,
            image: nil,
            divider: nil
        )
    }

    static func callout(_ text: String, icon: String = "💡") -> NotionBlock {
        NotionBlock(
            type: "callout",
            paragraph: nil,
            heading1: nil,
            heading2: nil,
            heading3: nil,
            callout: CalloutBlock(
                richText: [NotionRichText(content: text)],
                icon: NotionIcon(type: "emoji", emoji: icon)
            ),
            quote: nil,
            bulletedListItem: nil,
            numberedListItem: nil,
            image: nil,
            divider: nil
        )
    }

    static func quote(_ text: String) -> NotionBlock {
        NotionBlock(
            type: "quote",
            paragraph: nil,
            heading1: nil,
            heading2: nil,
            heading3: nil,
            callout: nil,
            quote: QuoteBlock(richText: [NotionRichText(content: text)]),
            bulletedListItem: nil,
            numberedListItem: nil,
            image: nil,
            divider: nil
        )
    }

    static func bulletedListItem(_ text: String) -> NotionBlock {
        NotionBlock(
            type: "bulleted_list_item",
            paragraph: nil,
            heading1: nil,
            heading2: nil,
            heading3: nil,
            callout: nil,
            quote: nil,
            bulletedListItem: BulletedListItemBlock(richText: [NotionRichText(content: text)]),
            numberedListItem: nil,
            image: nil,
            divider: nil
        )
    }

    static func image(url: String) -> NotionBlock {
        NotionBlock(
            type: "image",
            paragraph: nil,
            heading1: nil,
            heading2: nil,
            heading3: nil,
            callout: nil,
            quote: nil,
            bulletedListItem: nil,
            numberedListItem: nil,
            image: ImageBlock(type: "external", external: ExternalFile(url: url)),
            divider: nil
        )
    }

    static func divider() -> NotionBlock {
        NotionBlock(
            type: "divider",
            paragraph: nil,
            heading1: nil,
            heading2: nil,
            heading3: nil,
            callout: nil,
            quote: nil,
            bulletedListItem: nil,
            numberedListItem: nil,
            image: nil,
            divider: DividerBlock()
        )
    }
}

// MARK: - Block Types

struct ParagraphBlock: Codable {
    let richText: [NotionRichText]
    let color: String = "default"

    enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
}

struct HeadingBlock: Codable {
    let richText: [NotionRichText]
    let color: String = "default"
    let isToggleable: Bool = false

    enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
        case isToggleable = "is_toggleable"
    }
}

struct CalloutBlock: Codable {
    let richText: [NotionRichText]
    let icon: NotionIcon
    let color: String = "default"

    enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case icon
        case color
    }
}

struct QuoteBlock: Codable {
    let richText: [NotionRichText]
    let color: String = "default"

    enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
}

struct BulletedListItemBlock: Codable {
    let richText: [NotionRichText]
    let color: String = "default"

    enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
}

struct NumberedListItemBlock: Codable {
    let richText: [NotionRichText]
    let color: String = "default"

    enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
}

struct ImageBlock: Codable {
    let type: String
    let external: ExternalFile

    init(type: String, external: ExternalFile) {
        self.type = type
        self.external = external
    }
}

struct ExternalFile: Codable {
    let url: String
}

struct DividerBlock: Codable {
    // Empty object for dividers
}

// MARK: - Append Block Children Request

struct AppendBlockChildrenRequest: Codable {
    let children: [NotionBlock]
}
