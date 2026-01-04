//
//  PageSelectionView.swift
//  ReadingNotesApp
//
//  View for selecting existing Notion page or creating new one
//

import SwiftUI
import SwiftData

struct PageSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let screenshot: KindleScreenshot
    let authService: NotionAuthService

    @State private var searchQuery = ""
    @State private var pages: [SearchResult] = []
    @State private var isLoading = false
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showNewPageSheet = false
    @State private var newPageTitle = ""

    var filteredPages: [SearchResult] {
        if searchQuery.isEmpty {
            return pages
        }
        return pages.filter { page in
            page.displayTitle.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading pages...")
                        .padding()
                } else {
                    List {
                        Section {
                            Button {
                                showNewPageSheet = true
                            } label: {
                                Label("Create New Book Page", systemImage: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }

                        if !filteredPages.isEmpty {
                            Section("Recent Pages") {
                                ForEach(filteredPages, id: \.id) { page in
                                    Button {
                                        print("👆 User tapped page: \(page.displayTitle) (ID: \(page.id))")
                                        Task {
                                            await syncToPage(page.id)
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(page.displayTitle)
                                                .foregroundStyle(.primary)
                                            Text(page.id)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .disabled(isSyncing)
                                }
                            }
                        } else if !isLoading {
                            Section {
                                ContentUnavailableView(
                                    "No Pages Found",
                                    systemImage: "doc.text.magnifyingglass",
                                    description: Text("Search for a page or create a new one")
                                )
                            }
                        }
                    }
                    .searchable(text: $searchQuery, prompt: "Search pages")
                }
            }
            .navigationTitle("Select Book Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if isSyncing {
                        ProgressView()
                    }
                }
            }
            .onAppear {
                Task {
                    await loadPages()
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .sheet(isPresented: $showNewPageSheet) {
                NewPageView(
                    screenshot: screenshot,
                    authService: authService,
                    onPageCreated: { pageId in
                        dismiss()
                    }
                )
            }
        }
    }

    @MainActor
    private func loadPages() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let syncService = NotionSyncService(modelContext: modelContext, authService: authService)
            pages = try await syncService.searchPages()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    @MainActor
    private func syncToPage(_ pageId: String) async {
        // Prevent duplicate syncs
        guard !isSyncing else {
            print("⚠️ Sync already in progress, ignoring duplicate call")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let syncService = NotionSyncService(modelContext: modelContext, authService: authService)
            try await syncService.syncScreenshotToPage(screenshot, pageId: pageId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - New Page View

struct NewPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let screenshot: KindleScreenshot
    let authService: NotionAuthService
    let onPageCreated: (String) -> Void

    @State private var pageTitle = ""
    @State private var parentPages: [SearchResult] = []
    @State private var selectedParentId: String?
    @State private var isLoading = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Book Title", text: $pageTitle)
                        .autocapitalization(.words)
                } header: {
                    Text("New Book Page")
                } footer: {
                    Text("Enter the title for your new book page")
                }

                if let bookTitle = screenshot.sourceBook, bookTitle != "Untitled" {
                    Section {
                        Button {
                            pageTitle = bookTitle
                        } label: {
                            Label("Use detected title: \(bookTitle)", systemImage: "wand.and.stars")
                        }
                    }
                }

                Section {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if parentPages.isEmpty {
                        Button {
                            Task {
                                await loadParentPages()
                            }
                        } label: {
                            Label("Load Pages", systemImage: "arrow.clockwise")
                        }
                    } else {
                        ForEach(parentPages, id: \.id) { page in
                            Button {
                                selectedParentId = page.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(page.displayTitle)
                                            .foregroundStyle(.primary)
                                    }
                                    Spacer()
                                    if selectedParentId == page.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Parent Page")
                } footer: {
                    Text("Select where to create the new book page. This will be a sub-page of the selected page.")
                }

                Section {
                    Button {
                        Task {
                            await createPage()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isCreating {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Creating...")
                            } else {
                                Text("Create & Sync")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(pageTitle.isEmpty || selectedParentId == nil || isCreating)
                }
            }
            .navigationTitle("New Book Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await loadParentPages()
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    @MainActor
    private func loadParentPages() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let syncService = NotionSyncService(modelContext: modelContext, authService: authService)
            parentPages = try await syncService.searchPages()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    @MainActor
    private func createPage() async {
        guard let parentId = selectedParentId else { return }

        // Prevent duplicate creates
        guard !isCreating else {
            print("⚠️ Page creation already in progress, ignoring duplicate call")
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            let syncService = NotionSyncService(modelContext: modelContext, authService: authService)
            try await syncService.syncScreenshotToNewPage(screenshot, bookTitle: pageTitle, parentPageId: parentId)
            dismiss()
            if let pageId = screenshot.notionPageId {
                onPageCreated(pageId)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
