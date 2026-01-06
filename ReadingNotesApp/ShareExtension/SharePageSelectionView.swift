//
//  SharePageSelectionView.swift
//  ReadingNotesApp
//
//  View for selecting book page when sharing text from Kindle
//

import SwiftUI

struct SharePageSelectionView: View {
    let sharedText: String
    let onComplete: () -> Void
    
    @State private var searchQuery = ""
    @State private var pages: [SearchResult] = []
    @State private var isLoading = false
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showNewPageSheet = false
    
    // Access shared UserDefaults for Notion token
    private var authService: NotionAuthService {
        NotionAuthService()
    }
    
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
                // Preview of shared text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shared Text")
                        .font(.headline)
                        .padding(.horizontal)
                    ScrollView {
                        Text(sharedText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 150)
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                Divider()
                
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
                        onComplete()
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
                ShareNewPageView(
                    sharedText: sharedText,
                    authService: authService,
                    onPageCreated: {
                        onComplete()
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
            // Create a temporary model context for the sync service
            // Note: Share extensions can't use SwiftData, so we'll use UserDefaults for auth
            let syncService = NotionSyncService(modelContext: nil, authService: authService)
            pages = try await syncService.searchPages()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    @MainActor
    private func syncToPage(_ pageId: String) async {
        guard !isSyncing else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let syncService = NotionSyncService(modelContext: nil, authService: authService)
            try await syncService.syncTextToPage(sharedText, pageId: pageId)
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - New Page View

struct ShareNewPageView: View {
    @Environment(\.dismiss) private var dismiss
    let sharedText: String
    let authService: NotionAuthService
    let onPageCreated: () -> Void
    
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
            let syncService = NotionSyncService(modelContext: nil, authService: authService)
            parentPages = try await syncService.searchPages()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    @MainActor
    private func createPage() async {
        guard let parentId = selectedParentId else { return }
        guard !isCreating else { return }
        
        isCreating = true
        defer { isCreating = false }
        
        do {
            let syncService = NotionSyncService(modelContext: nil, authService: authService)
            _ = try await syncService.syncTextToNewPage(sharedText, bookTitle: pageTitle, parentPageId: parentId)
            dismiss()
            onPageCreated()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

