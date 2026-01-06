//
//  SharedTextManager.swift
//  ReadingNotesApp
//
//  Manages shared text between Share Extension and main app via App Groups
//

import Foundation

class SharedTextManager {
    static let shared = SharedTextManager()
    
    private let appGroupID = "group.com.michaelguo.ReadingNotesApp"
    private let sharedTextKey = "SharedTextFromExtension"
    private let sharedTextTimestampKey = "SharedTextTimestamp"
    
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    private init() {}
    
    // MARK: - Save (called from Share Extension)
    
    /// Save shared text from extension
    func saveSharedText(_ text: String) {
        userDefaults?.set(text, forKey: sharedTextKey)
        userDefaults?.set(Date().timeIntervalSince1970, forKey: sharedTextTimestampKey)
        userDefaults?.synchronize()
    }
    
    // MARK: - Retrieve (called from main app)
    
    /// Check if there's pending shared text
    func hasPendingSharedText() -> Bool {
        guard let text = userDefaults?.string(forKey: sharedTextKey),
              !text.isEmpty else {
            return false
        }
        
        // Only consider text shared in the last 5 minutes as valid
        if let timestamp = userDefaults?.double(forKey: sharedTextTimestampKey) {
            let sharedTime = Date(timeIntervalSince1970: timestamp)
            let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
            return sharedTime > fiveMinutesAgo
        }
        
        return false
    }
    
    /// Retrieve and clear the shared text
    func retrieveSharedText() -> String? {
        guard hasPendingSharedText(),
              let text = userDefaults?.string(forKey: sharedTextKey) else {
            return nil
        }
        
        // Clear after retrieval
        clearSharedText()
        
        return text
    }
    
    /// Peek at shared text without clearing
    func peekSharedText() -> String? {
        guard hasPendingSharedText() else { return nil }
        return userDefaults?.string(forKey: sharedTextKey)
    }
    
    /// Clear the shared text
    func clearSharedText() {
        userDefaults?.removeObject(forKey: sharedTextKey)
        userDefaults?.removeObject(forKey: sharedTextTimestampKey)
        userDefaults?.synchronize()
    }
}

