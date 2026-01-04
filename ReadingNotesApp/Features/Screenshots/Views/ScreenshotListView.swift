//
//  ScreenshotListView.swift
//  ReadingNotesApp
//
//  Main view displaying list of imported Kindle screenshots
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

@MainActor
struct ScreenshotListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: ScreenshotListViewModel?
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                if let viewModel = viewModel {
                    if viewModel.isLoading {
                        ProgressView("Loading screenshots...")
                    } else if viewModel.screenshots.isEmpty {
                        emptyStateView
                    } else {
                        screenshotList(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("Kindle Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Import", systemImage: "photo.badge.plus")
                    }
                }
            }
            .photosPicker(
                isPresented: $showingPhotoPicker,
                selection: $selectedPhotoItem,
                matching: .images
            )
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await handlePhotoSelection(newItem)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel?.showError ?? false },
                set: { if !$0 { viewModel?.showError = false } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel?.errorMessage ?? "An error occurred")
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = ScreenshotListViewModel(modelContext: modelContext)
                }
                viewModel?.loadScreenshots()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.pages")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Screenshots Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Import Kindle screenshots to extract highlights and add notes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showingPhotoPicker = true
            } label: {
                Label("Import Screenshot", systemImage: "photo.badge.plus")
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Screenshot List

    private func screenshotList(viewModel: ScreenshotListViewModel) -> some View {
        List {
            ForEach(viewModel.screenshots, id: \.id) { screenshot in
                NavigationLink(destination: ScreenshotDetailView(screenshot: screenshot)) {
                    ScreenshotRowView(screenshot: screenshot)
                }
            }
            .onDelete { offsets in
                viewModel.deleteScreenshots(at: offsets)
            }
        }
        .refreshable {
            viewModel.loadScreenshots()
        }
    }

    // MARK: - Photo Handling

    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    viewModel?.importScreenshot(imageData: data)
                    selectedPhotoItem = nil
                }
            }
        } catch {
            await MainActor.run {
                viewModel?.errorMessage = "Failed to load image: \(error.localizedDescription)"
                viewModel?.showError = true
            }
        }
    }
}

// MARK: - Screenshot Row View

struct ScreenshotRowView: View {
    let screenshot: KindleScreenshot

    var body: some View {
        HStack(spacing: 12) {
            if let thumbnailData = screenshot.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 90)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(screenshot.sourceBook ?? "Untitled")
                    .font(.headline)
                    .lineLimit(1)

                Text(screenshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    StatusBadge(status: screenshot.processingStatus)

                    if !screenshot.highlights.isEmpty {
                        Label("\(screenshot.highlights.count)", systemImage: "highlighter")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if screenshot.isSyncedToNotion {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ProcessingStatus

    var body: some View {
        Text(status.displayText)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundStyle(.white)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .pending: return .orange
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    ScreenshotListView()
        .modelContainer(for: [KindleScreenshot.self, Highlight.self, Note.self, NotionConfig.self])
}
