//
//  ShareViewController.swift
//  ReadingNotesApp
//
//  Share Extension for receiving highlighted text or screenshots from Kindle
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private var sharedText: String?
    private var sharedImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get shared content from extension context
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            closeExtension()
            return
        }
        
        // Try to extract image first (for screenshots), then text
        extractContent(from: inputItems) { [weak self] text, image in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let image = image {
                    // Image shared - save and open main app for OCR
                    self.sharedImage = image
                    self.handleSharedImage(image)
                } else if let text = text {
                    // Text shared - show page selection
                    self.sharedText = text
                    self.showPageSelection(text: text)
                } else {
                    self.closeExtension()
                }
            }
        }
    }
    
    private func extractContent(from inputItems: [NSExtensionItem], completion: @escaping (String?, UIImage?) -> Void) {
        var foundText: String?
        var foundImage: UIImage?
        let group = DispatchGroup()
        
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            
            for attachment in attachments {
                // Check for image first
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { (item, error) in
                        defer { group.leave() }
                        
                        if error != nil { return }
                        
                        if let image = item as? UIImage {
                            foundImage = image
                        } else if let imageURL = item as? URL,
                                  let imageData = try? Data(contentsOf: imageURL),
                                  let image = UIImage(data: imageData) {
                            foundImage = image
                        } else if let imageData = item as? Data,
                                  let image = UIImage(data: imageData) {
                            foundImage = image
                        }
                    }
                }
                // Check for text
                else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, error) in
                        defer { group.leave() }
                        
                        if error != nil { return }
                        
                        if let text = item as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            foundText = text
                        } else if let data = item as? Data, let text = String(data: data, encoding: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            foundText = text
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(foundText, foundImage)
        }
    }
    
    private func handleSharedImage(_ image: UIImage) {
        // Save image to shared container
        let manager = SharedTextManager.shared
        if manager.saveSharedImage(image) {
            // Open main app to process the image with OCR
            if let url = URL(string: "readingnotes://sharedimage") {
                var responder: UIResponder? = self
                while responder != nil {
                    if let application = responder as? UIApplication {
                        application.open(url, options: [:], completionHandler: nil)
                        break
                    }
                    responder = responder?.next
                }
            }
            
            // Close extension after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.closeExtension()
            }
        } else {
            // Failed to save image - show error
            showError("Failed to save image. Please try again.")
        }
    }
    
    private func showPageSelection(text: String) {
        let hostingController = UIHostingController(
            rootView: SharePageSelectionView(sharedText: text) {
                self.closeExtension()
            }
        )
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.didMove(toParent: self)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.closeExtension()
        })
        present(alert, animated: true)
    }
    
    private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

