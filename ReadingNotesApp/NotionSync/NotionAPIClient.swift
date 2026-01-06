//
//  NotionAPIClient.swift
//  ReadingNotesApp
//
//  HTTP client for Notion API v2022-06-28
//

import Foundation

@MainActor
class NotionAPIClient {
    private let baseURL = "https://api.notion.com/v1"
    private let notionVersion = "2022-06-28"
    private let session = URLSession.shared

    // Rate limiting: 3 requests per second
    private var lastRequestTime: Date?
    private let minimumRequestInterval: TimeInterval = 1.0 / 3.0 // 333ms between requests

    // MARK: - Page Operations

    func createPage(request: NotionPageRequest, accessToken: String) async throws -> NotionPageResponse {
        try await performRateLimitedRequest {
            let url = URL(string: "\(self.baseURL)/pages")!
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue(self.notionVersion, forHTTPHeaderField: "Notion-Version")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(request)

            let (data, response) = try await self.session.data(for: urlRequest)
            try self.validateResponse(response, data: data)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            do {
                return try decoder.decode(NotionPageResponse.self, from: data)
            } catch {
                throw NotionAPIError.badRequest(message: "Failed to decode response")
            }
        }
    }

    func retrievePage(pageId: String, accessToken: String) async throws -> NotionPageResponse {
        try await performRateLimitedRequest {
            let url = URL(string: "\(self.baseURL)/pages/\(pageId)")!
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "GET"
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue(self.notionVersion, forHTTPHeaderField: "Notion-Version")

            let (data, response) = try await self.session.data(for: urlRequest)
            try self.validateResponse(response, data: data)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(NotionPageResponse.self, from: data)
        }
    }

    func updatePage(pageId: String, properties: [String: NotionProperty], accessToken: String) async throws -> NotionPageResponse {
        try await performRateLimitedRequest {
            let url = URL(string: "\(self.baseURL)/pages/\(pageId)")!
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "PATCH"
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue(self.notionVersion, forHTTPHeaderField: "Notion-Version")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = ["properties": properties]
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await self.session.data(for: urlRequest)
            try self.validateResponse(response, data: data)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(NotionPageResponse.self, from: data)
        }
    }

    // MARK: - Block Operations

    func appendBlockChildren(pageId: String, blocks: [NotionBlock], accessToken: String) async throws -> BlockChildrenResponse {
        try await performRateLimitedRequest {
            let url = URL(string: "\(self.baseURL)/blocks/\(pageId)/children")!
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "PATCH"
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue(self.notionVersion, forHTTPHeaderField: "Notion-Version")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let request = AppendBlockChildrenRequest(children: blocks)
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            urlRequest.httpBody = try encoder.encode(request)

            let (data, response) = try await self.session.data(for: urlRequest)
            try self.validateResponse(response, data: data)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            do {
                return try decoder.decode(BlockChildrenResponse.self, from: data)
            } catch {
                throw NotionAPIError.badRequest(message: "Failed to decode response")
            }
        }
    }

    func retrieveBlockChildren(blockId: String, accessToken: String) async throws -> [NotionBlockResponse] {
        try await performRateLimitedRequest {
            let url = URL(string: "\(self.baseURL)/blocks/\(blockId)/children")!
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "GET"
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue(self.notionVersion, forHTTPHeaderField: "Notion-Version")

            let (data, response) = try await self.session.data(for: urlRequest)
            try self.validateResponse(response, data: data)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(BlockChildrenResponse.self, from: data)
            return result.results
        }
    }

    // MARK: - Database Operations

    func queryDatabase(databaseId: String, accessToken: String) async throws -> [NotionPageResponse] {
        try await performRateLimitedRequest {
            let url = URL(string: "\(self.baseURL)/databases/\(databaseId)/query")!
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue(self.notionVersion, forHTTPHeaderField: "Notion-Version")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Empty body for now - can add filters later
            urlRequest.httpBody = "{}".data(using: .utf8)

            let (data, response) = try await self.session.data(for: urlRequest)
            try self.validateResponse(response, data: data)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(DatabaseQueryResponse.self, from: data)
            return result.results
        }
    }

    // MARK: - Search

    func searchPages(query: String, accessToken: String) async throws -> SearchResponse {
        try await performRateLimitedRequest {
            let url = URL(string: "\(self.baseURL)/search")!
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue(self.notionVersion, forHTTPHeaderField: "Notion-Version")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "query": query,
                "filter": ["property": "object", "value": "page"],
                "sort": ["direction": "descending", "timestamp": "last_edited_time"]
            ]
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await self.session.data(for: urlRequest)
            try self.validateResponse(response, data: data)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(SearchResponse.self, from: data)
        }
    }

    func searchDatabases(query: String, accessToken: String) async throws -> SearchResponse {
        try await performRateLimitedRequest {
            let url = URL(string: "\(self.baseURL)/search")!
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue(self.notionVersion, forHTTPHeaderField: "Notion-Version")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = ["query": query, "filter": ["property": "object", "value": "database"]]
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await self.session.data(for: urlRequest)
            try self.validateResponse(response, data: data)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(SearchResponse.self, from: data)
        }
    }

    // MARK: - Rate Limiting

    private func performRateLimitedRequest<T>(_ request: @escaping () async throws -> T) async throws -> T {
        // Wait if necessary to respect rate limit
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minimumRequestInterval {
                let delay = minimumRequestInterval - elapsed
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        lastRequestTime = Date()
        return try await request()
    }

    // MARK: - Response Validation

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NotionAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            throw NotionAPIError.badRequest(message: String(data: data, encoding: .utf8) ?? "Bad request")
        case 401:
            throw NotionAPIError.unauthorized
        case 403:
            throw NotionAPIError.forbidden
        case 404:
            throw NotionAPIError.notFound
        case 429:
            throw NotionAPIError.rateLimited
        case 500...599:
            throw NotionAPIError.serverError
        default:
            throw NotionAPIError.unknown(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Response Models

struct BlockChildrenResponse: Codable {
    let object: String?
    let results: [NotionBlockResponse]
    let hasMore: Bool?
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case object
        case results
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

struct DatabaseQueryResponse: Codable {
    let results: [NotionPageResponse]
    let hasMore: Bool
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case results
        case hasMore = "has_more"
        case nextCursor = "next_cursor"
    }
}

struct SearchResponse: Codable {
    let results: [SearchResult]
}

struct SearchResult: Codable {
    let id: String
    let object: String
    let properties: [String: SearchResultProperty]?

    var displayTitle: String {
        // Try to get title from properties
        guard let properties = properties else { return "Untitled" }

        // Try "title" property first, then "Name"
        if let titleProp = properties["title"],
           let firstText = titleProp.richTexts.first {
            return firstText.plainText ?? firstText.text.content
        }

        if let nameProp = properties["Name"],
           let firstText = nameProp.richTexts.first {
            return firstText.plainText ?? firstText.text.content
        }

        return "Untitled"
    }
}

struct SearchResultProperty: Codable {
    let type: String
    let richTexts: [NotionRichText]

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case richText = "rich_text"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)

        // Try to decode from either "title" or "rich_text" field
        if let texts = try? container.decode([NotionRichText].self, forKey: .title) {
            richTexts = texts
        } else if let texts = try? container.decode([NotionRichText].self, forKey: .richText) {
            richTexts = texts
        } else {
            richTexts = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        // Encode based on type
        if type == "title" {
            try container.encode(richTexts, forKey: .title)
        } else {
            try container.encode(richTexts, forKey: .richText)
        }
    }
}

// MARK: - Errors

enum NotionAPIError: LocalizedError {
    case invalidResponse
    case badRequest(message: String)
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError
    case unknown(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Notion API"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .unauthorized:
            return "Unauthorized - please reconnect your Notion account"
        case .forbidden:
            return "Access forbidden - check integration permissions"
        case .notFound:
            return "Resource not found"
        case .rateLimited:
            return "Rate limit exceeded - please try again"
        case .serverError:
            return "Notion server error - please try again later"
        case .unknown(let statusCode):
            return "Unknown error (status code: \(statusCode))"
        }
    }
}
