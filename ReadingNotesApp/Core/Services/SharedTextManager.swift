//
//  SharedTextManager.swift
//  ReadingNotesApp
//
//  Manages shared text and images between Share Extension and main app via App Groups
//

import Foundation
import UIKit

class SharedTextManager {
    static let shared = SharedTextManager()
    
    private let appGroupID = "group.com.michaelguo.ReadingNotesApp"
    private let sharedTextKey = "SharedTextFromExtension"
    private let sharedTextTimestampKey = "SharedTextTimestamp"
    private let sharedImageKey = "SharedImageFromExtension"
    private let sharedImageTimestampKey = "SharedImageTimestamp"
    
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    /// Get the shared container URL for storing files
    private var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }
    
    private init() {}
    
    // MARK: - Text Methods
    
    /// Save shared text from extension
    func saveSharedText(_ text: String) {
        userDefaults?.set(text, forKey: sharedTextKey)
        userDefaults?.set(Date().timeIntervalSince1970, forKey: sharedTextTimestampKey)
        userDefaults?.synchronize()
    }
    
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
    
    // MARK: - Image Methods
    
    /// Save shared image from extension (saves to file in shared container)
    func saveSharedImage(_ image: UIImage) -> Bool {
        guard let containerURL = sharedContainerURL else { return false }
        
        let imageURL = containerURL.appendingPathComponent("shared_image.jpg")
        
        // Convert to JPEG data (more efficient than PNG for photos)
        guard let imageData = image.jpegData(compressionQuality: 0.9) else { return false }
        
        do {
            try imageData.write(to: imageURL)
            userDefaults?.set(imageURL.path, forKey: sharedImageKey)
            userDefaults?.set(Date().timeIntervalSince1970, forKey: sharedImageTimestampKey)
            userDefaults?.synchronize()
            return true
        } catch {
            return false
        }
    }
    
    /// Check if there's pending shared image
    func hasPendingSharedImage() -> Bool {
        guard let imagePath = userDefaults?.string(forKey: sharedImageKey),
              FileManager.default.fileExists(atPath: imagePath) else {
            return false
        }
        
        // Only consider image shared in the last 5 minutes as valid
        if let timestamp = userDefaults?.double(forKey: sharedImageTimestampKey) {
            let sharedTime = Date(timeIntervalSince1970: timestamp)
            let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
            return sharedTime > fiveMinutesAgo
        }
        
        return false
    }
    
    /// Retrieve and clear the shared image
    func retrieveSharedImage() -> UIImage? {
        guard hasPendingSharedImage(),
              let imagePath = userDefaults?.string(forKey: sharedImageKey) else {
            return nil
        }
        
        let image = UIImage(contentsOfFile: imagePath)
        
        // Clear after retrieval
        clearSharedImage()
        
        return image
    }
    
    /// Peek at shared image without clearing
    func peekSharedImage() -> UIImage? {
        guard hasPendingSharedImage(),
              let imagePath = userDefaults?.string(forKey: sharedImageKey) else {
            return nil
        }
        return UIImage(contentsOfFile: imagePath)
    }
    
    /// Clear the shared image
    func clearSharedImage() {
        if let imagePath = userDefaults?.string(forKey: sharedImageKey) {
            try? FileManager.default.removeItem(atPath: imagePath)
        }
        userDefaults?.removeObject(forKey: sharedImageKey)
        userDefaults?.removeObject(forKey: sharedImageTimestampKey)
        userDefaults?.synchronize()
    }
    
    // MARK: - Combined Methods
    
    /// Check if there's any pending shared content (text or image)
    func hasPendingSharedContent() -> Bool {
        return hasPendingSharedText() || hasPendingSharedImage()
    }
    
    /// Clear all shared content
    func clearAllSharedContent() {
        clearSharedText()
        clearSharedImage()
    }
}

