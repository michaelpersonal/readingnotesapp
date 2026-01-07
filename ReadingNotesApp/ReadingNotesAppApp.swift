//
//  ReadingNotesAppApp.swift
//  ReadingNotesApp
//
//  Created by Zhisong guo on 1/4/26.
//

import SwiftUI
import SwiftData

@main
struct ReadingNotesAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSharedTextView = false
    @State private var sharedText: String?
    @State private var showSharedImageView = false
    @State private var sharedImage: UIImage?
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            KindleScreenshot.self,
            Highlight.self,
            Note.self,
            NotionConfig.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleURL(url)
                }
                .onAppear {
                    checkForSharedContent()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Check for shared content when app becomes active
                    if newPhase == .active {
                        checkForSharedContent()
                    }
                }
                .onChange(of: showSharedTextView) { _, show in
                    // Reset when dismissed
                    if !show {
                        sharedText = nil
                    }
                }
                .onChange(of: showSharedImageView) { _, show in
                    // Reset when dismissed
                    if !show {
                        sharedImage = nil
                    }
                }
                .sheet(isPresented: $showSharedTextView) {
                    if let text = sharedText {
                        SharedTextPageSelectionView(
                            sharedText: text,
                            onDismiss: {
                                showSharedTextView = false
                                sharedText = nil
                            }
                        )
                    }
                }
                .sheet(isPresented: $showSharedImageView) {
                    if let image = sharedImage {
                        SharedImageProcessingView(
                            image: image,
                            onDismiss: {
                                showSharedImageView = false
                                sharedImage = nil
                            }
                        )
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleURL(_ url: URL) {
        guard url.scheme == "readingnotes" else { return }
        
        switch url.host {
        case "shared":
            // Shared text from extension
            checkForSharedText()
        case "sharedimage":
            // Shared image from extension
            checkForSharedImage()
        default:
            break
        }
    }
    
    private func checkForSharedContent() {
        // Check for shared image first (higher priority)
        if checkForSharedImage() {
            return
        }
        // Then check for shared text
        checkForSharedText()
    }
    
    @discardableResult
    private func checkForSharedText() -> Bool {
        // Only show if not already showing something
        guard !showSharedTextView && !showSharedImageView else { return false }
        
        if let text = SharedTextManager.shared.retrieveSharedText() {
            sharedText = text
            showSharedTextView = true
            return true
        }
        return false
    }
    
    @discardableResult
    private func checkForSharedImage() -> Bool {
        // Only show if not already showing something
        guard !showSharedTextView && !showSharedImageView else { return false }
        
        if let image = SharedTextManager.shared.retrieveSharedImage() {
            sharedImage = image
            showSharedImageView = true
            return true
        }
        return false
    }
}

