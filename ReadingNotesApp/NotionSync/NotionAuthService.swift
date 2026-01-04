//
//  NotionAuthService.swift
//  ReadingNotesApp
//
//  Token-based authentication service for Notion (Internal Integration)
//

import Foundation
import Security

@MainActor
class NotionAuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var authError: String?

    // Keychain keys
    private let accessTokenKey = "notion_access_token"

    // MARK: - Authentication

    func authenticateWithToken(_ token: String) throws {
        guard !token.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NotionAuthError.emptyToken
        }

        // Validate token format (should start with "secret_" or "ntn_")
        guard token.hasPrefix("secret_") || token.hasPrefix("ntn_") else {
            throw NotionAuthError.invalidTokenFormat
        }

        // Store token securely
        try storeAccessToken(token)
        isAuthenticated = true
    }

    // MARK: - Token Management

    func getAccessToken() -> String? {
        return retrieveFromKeychain(key: accessTokenKey)
    }

    func signOut() throws {
        try deleteFromKeychain(key: accessTokenKey)
        isAuthenticated = false
    }

    func checkAuthenticationStatus() {
        isAuthenticated = getAccessToken() != nil
    }

    // MARK: - Keychain Operations

    private func storeAccessToken(_ token: String) throws {
        try storeInKeychain(key: accessTokenKey, value: token)
    }

    private func storeInKeychain(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw NotionAuthError.keychainError
        }

        // Delete existing item if any
        try? deleteFromKeychain(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NotionAuthError.keychainError
        }
    }

    private func retrieveFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteFromKeychain(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NotionAuthError.keychainError
        }
    }
}

// MARK: - Errors

enum NotionAuthError: LocalizedError {
    case emptyToken
    case invalidTokenFormat
    case keychainError

    var errorDescription: String? {
        switch self {
        case .emptyToken:
            return "Please enter a valid token"
        case .invalidTokenFormat:
            return "Invalid token format. Token should start with 'secret_' or 'ntn_'"
        case .keychainError:
            return "Failed to store credentials securely"
        }
    }
}
