//
//  ScreenshotDetailView.swift
//  ReadingNotesApp
//
//  Detail view for a single screenshot with processing
//

import SwiftUI
import SwiftData
import UIKit

struct ScreenshotDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let screenshot: KindleScreenshot

    @State private var isProcessing = false
    @State private var processingError: String?
    @State private var showError = false
    @State private var showPageSelection = false
    @StateObject private var authService = NotionAuthService()

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                if let imageData = screenshot.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(screenshot.sourceBook ?? "Untitled")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Created: \(screenshot.createdAt.formatted(date: .long, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    StatusBadge(status: screenshot.processingStatus)
                }
                .padding(.horizontal)

                if !screenshot.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Highlights (\(screenshot.highlights.count))")
                                .font(.headline)
                            Spacer()
                            // Debug info
                            let unsyncedCount = screenshot.highlights.filter { !$0.isSyncedToNotion }.count
                            Text("Unsynced: \(unsyncedCount)")
                                .font(.caption)
                                .foregroundStyle(unsyncedCount > 0 ? .orange : .green)
                        }
                        .padding(.horizontal)

                        ForEach(screenshot.highlights, id: \.id) { highlight in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(highlight.extractedText)
                                    .padding()
                                    .background(Color.yellow.opacity(0.2))
                                    .cornerRadius(8)

                                if !highlight.notes.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(highlight.notes, id: \.id) { note in
                                            Text(note.content)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .padding(.leading)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Sync to Notion button
                        if authService.isAuthenticated {
                            VStack(spacing: 8) {
                                Button {
                                    showPageSelection = true
                                } label: {
                                    HStack {
                                        Spacer()
                                        Image(systemName: screenshot.isSyncedToNotion ? "checkmark.circle.fill" : "square.and.arrow.up")
                                        Text(screenshot.isSyncedToNotion ? "Synced to Notion" : "Sync to Notion")
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(screenshot.isSyncedToNotion ? Color.green.opacity(0.2) : Color.blue)
                                    .foregroundStyle(screenshot.isSyncedToNotion ? .green : .white)
                                    .cornerRadius(12)
                                }

                                // Reset sync status button (only show if synced)
                                if screenshot.isSyncedToNotion {
                                    Button {
                                        resetSyncStatus()
                                    } label: {
                                        HStack {
                                            Image(systemName: "arrow.counterclockwise")
                                            Text("Reset Sync Status")
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.orange)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else if screenshot.processingStatus == .pending || screenshot.processingStatus == .failed {
                    VStack(spacing: 12) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)

                        Text("No highlights detected yet")
                            .font(.headline)

                        Text("Tap the button below to analyze this screenshot and extract highlighted text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            Task {
                                await processScreenshot()
                            }
                        } label: {
                            Label("Process Screenshot", systemImage: "wand.and.stars")
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .disabled(isProcessing)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else if screenshot.processingStatus == .processing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()

                        Text("Processing screenshot...")
                            .font(.headline)

                        Text("Detecting highlights and extracting text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .padding(.vertical)
            .padding(.bottom, 100) // Extra bottom padding to ensure buttons are accessible
        }
        .navigationTitle("Screenshot Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !screenshot.highlights.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            Task {
                                await reprocessScreenshot()
                            }
                        } label: {
                            Label("Reprocess", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Processing Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(processingError ?? "An error occurred while processing")
        }
        .sheet(isPresented: $showPageSelection) {
            PageSelectionView(screenshot: screenshot, authService: authService)
        }
        .onAppear {
            authService.checkAuthenticationStatus()
        }
    }

    // MARK: - Processing Methods

    @MainActor
    private func processScreenshot() async {
        isProcessing = true

        let processingService = ImageProcessingService(modelContext: modelContext)

        do {
            try await processingService.processScreenshot(screenshot)
            isProcessing = false
        } catch {
            processingError = error.localizedDescription
            showError = true
            isProcessing = false
        }
    }

    @MainActor
    private func reprocessScreenshot() async {
        isProcessing = true

        let processingService = ImageProcessingService(modelContext: modelContext)

        do {
            try await processingService.reprocessScreenshot(screenshot)
            isProcessing = false
        } catch {
            processingError = error.localizedDescription
            showError = true
            isProcessing = false
        }
    }

    private func resetSyncStatus() {
        print("🔄 Resetting sync status for screenshot")
        print("   Total highlights: \(screenshot.highlights.count)")

        // Reset screenshot sync status
        screenshot.isSyncedToNotion = false
        screenshot.notionPageId = nil

        // Reset all highlights and notes sync status
        let highlightArray = Array(screenshot.highlights)
        print("   Processing \(highlightArray.count) highlights...")

        for (index, highlight) in highlightArray.enumerated() {
            print("   Resetting highlight \(index + 1)")
            highlight.isSyncedToNotion = false
            highlight.notionBlockId = nil

            let noteArray = Array(highlight.notes)
            for note in noteArray {
                note.isSyncedToNotion = false
                note.notionBlockId = nil
            }
        }

        // Save changes
        do {
            try modelContext.save()
            let unsyncedCount = screenshot.highlights.filter { !$0.isSyncedToNotion }.count
            print("✅ Sync status reset: \(unsyncedCount) unsynced highlights out of \(screenshot.highlights.count)")
        } catch {
            print("❌ Failed to reset sync status: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        ScreenshotDetailView(screenshot: KindleScreenshot())
    }
}
