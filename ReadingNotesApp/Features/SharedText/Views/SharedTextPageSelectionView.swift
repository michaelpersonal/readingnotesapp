//
//  SharedTextPageSelectionView.swift
//  ReadingNotesApp
//
//  Full-featured page selection for shared text (with chat support)
//

import SwiftUI

struct SharedTextPageSelectionView: View {
    let sharedText: String
    let onDismiss: () -> Void
    
    @State private var searchQuery = ""
    @State private var pages: [SearchResult] = []
    @State private var isLoading = false
    @State private var isSyncing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showNewPageSheet = false
    @State private var showChatSheet = false
    @State private var aiNotes: [String] = []
    @StateObject private var authService = NotionAuthService()
    
    // Sync options
    @State private var includeText = true
    @State private var includeAINotes = true
    
    /// Check if at least one option is selected
    private var canSync: Bool {
        (includeText && !sharedText.isEmpty) || (includeAINotes && !aiNotes.isEmpty)
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
                    HStack {
                        Image(systemName: "text.quote")
                            .foregroundColor(.pink)
                        Text("Shared Text")
                            .font(.headline)
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        Text(sharedText)
                            .font(.footnote)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.pink.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 120)
                    .padding(.horizontal)
                    
                    // Chat button
                    Button {
                        showChatSheet = true
                    } label: {
                        Label("Chat about this text", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    // Sync options
                    VStack(spacing: 8) {
                        Toggle(isOn: $includeText) {
                            HStack {
                                Image(systemName: "text.quote")
                                    .foregroundColor(.pink)
                                    .frame(width: 24)
                                Text("Include shared text")
                                    .font(.subheadline)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .pink))
                        
                        if !aiNotes.isEmpty {
                            Toggle(isOn: $includeAINotes) {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.yellow)
                                        .frame(width: 24)
                                    Text("Include AI insights (\(aiNotes.count))")
                                        .font(.subheadline)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .yellow))
                        }
                        
                        if !canSync {
                            Text("Select at least one option to sync")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
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
                            .disabled(!canSync)
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
                                    .disabled(isSyncing || !canSync)
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
            .navigationTitle("Sync Shared Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if isSyncing {
                        ProgressView()
                    }
                }
            }
            .onAppear {
                authService.checkAuthenticationStatus()
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
                SharedTextNewPageView(
                    sharedText: sharedText,
                    authService: authService,
                    aiNotes: includeAINotes ? aiNotes : [],
                    includeText: includeText,
                    onComplete: {
                        onDismiss()
                    }
                )
            }
            .sheet(isPresented: $showChatSheet) {
                ChatView(
                    highlightedText: sharedText,
                    onSaveNotes: { notes in
                        aiNotes = notes
                        showChatSheet = false
                    },
                    onDismiss: {
                        showChatSheet = false
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
        guard canSync else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let syncService = NotionSyncService(modelContext: nil, authService: authService)
            let textToSync = includeText ? sharedText : ""
            let notesToSync = includeAINotes ? aiNotes : []
            
            if !textToSync.isEmpty || !notesToSync.isEmpty {
                try await syncService.syncTextToPage(textToSync, pageId: pageId, aiNotes: notesToSync)
            }
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - New Page View

struct SharedTextNewPageView: View {
    @Environment(\.dismiss) private var dismiss
    let sharedText: String
    let authService: NotionAuthService
    let aiNotes: [String]
    let includeText: Bool
    let onComplete: () -> Void
    
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
                    Text("Select where to create the new book page.")
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
            let textToSync = includeText ? sharedText : ""
            _ = try await syncService.syncTextToNewPage(textToSync, bookTitle: pageTitle, parentPageId: parentId, aiNotes: aiNotes)
            dismiss()
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

