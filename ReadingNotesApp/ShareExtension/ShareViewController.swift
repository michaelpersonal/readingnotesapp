//
//  ShareViewController.swift
//  ReadingNotesApp
//
//  Share Extension for receiving highlighted text from Kindle
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private var sharedText: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get shared text from extension context
        guard let extensionContext = extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            closeExtension()
            return
        }
        
        // Extract text from input items
        extractText(from: inputItems) { [weak self] text in
            guard let self = self, let text = text else {
                DispatchQueue.main.async {
                    self?.closeExtension()
                }
                return
            }
            
            DispatchQueue.main.async {
                self.sharedText = text
                self.showPageSelection(text: text)
            }
        }
    }
    
    private func extractText(from inputItems: [NSExtensionItem], completion: @escaping (String?) -> Void) {
        var foundText: String?
        let group = DispatchGroup()
        
        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    group.enter()
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, error) in
                        defer { group.leave() }
                        
                        if error != nil {
                            return
                        }
                        
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
            completion(foundText)
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
    
    private func closeExtension() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

