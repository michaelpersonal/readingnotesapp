//
//  ContentView.swift
//  ReadingNotesApp
//
//  Main content view with tab navigation
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            ScreenshotListView()
                .tabItem {
                    Label("Screenshots", systemImage: "photo.stack")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [KindleScreenshot.self, Highlight.self, Note.self, NotionConfig.self])
}
