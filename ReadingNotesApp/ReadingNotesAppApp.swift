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
                    checkForSharedText()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Check for shared text when app becomes active
                    if newPhase == .active {
                        checkForSharedText()
                    }
                }
                .onChange(of: showSharedTextView) { _, show in
                    // Reset when dismissed
                    if !show {
                        sharedText = nil
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
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleURL(_ url: URL) {
        // Handle readingnotes://shared URL
        if url.scheme == "readingnotes" && url.host == "shared" {
            checkForSharedText()
        }
    }
    
    private func checkForSharedText() {
        // Only show if not already showing
        guard !showSharedTextView else { return }
        
        if let text = SharedTextManager.shared.retrieveSharedText() {
            sharedText = text
            showSharedTextView = true
        }
    }
}
