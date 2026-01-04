//
//  SettingsView.swift
//  ReadingNotesApp
//
//  Main settings view with Notion integration
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authService = NotionAuthService()
    @State private var showNotionConnection = false
    @State private var showTokenEntry = false

    var body: some View {
        NavigationStack {
            List {
                Section("Notion Integration") {
                    if authService.isAuthenticated {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Connected to Notion")
                        }

                        Button {
                            showNotionConnection = true
                        } label: {
                            Label("Manage Connection", systemImage: "gear")
                        }
                    } else {
                        Button {
                            showTokenEntry = true
                        } label: {
                            Label("Connect to Notion", systemImage: "link")
                        }

                        Text("Enter your Notion Internal Integration Token to sync highlights and notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/yourusername/ReadingNotesApp")!) {
                        Label("View on GitHub", systemImage: "chevron.right")
                    }
                }

                Section("Data") {
                    Button(role: .destructive) {
                        // TODO: Add confirmation dialog
                        clearAllData()
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                authService.checkAuthenticationStatus()
            }
            .sheet(isPresented: $showNotionConnection) {
                NotionConnectionView(authService: authService)
            }
            .sheet(isPresented: $showTokenEntry) {
                TokenEntryView(authService: authService)
            }
        }
    }

    private func clearAllData() {
        // Delete all screenshots (will cascade to highlights and notes)
        let descriptor = FetchDescriptor<KindleScreenshot>()
        if let screenshots = try? modelContext.fetch(descriptor) {
            for screenshot in screenshots {
                modelContext.delete(screenshot)
            }
            try? modelContext.save()
        }
    }
}

// MARK: - Token Entry View

struct TokenEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService: NotionAuthService

    @State private var token = ""
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Integration Token", text: $token)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    Button {
                        saveToken()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Connect")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(token.isEmpty)
                } header: {
                    Text("Notion Token")
                } footer: {
                    Text("Paste your Notion Internal Integration Token (starts with 'secret_' or 'ntn_')")
                }

                Section("Instructions") {
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionStep(number: 1, text: "Go to notion.so/my-integrations")
                        InstructionStep(number: 2, text: "Click on your integration (or create one)")
                        InstructionStep(number: 3, text: "Copy the 'Internal Integration Token'")
                        InstructionStep(number: 4, text: "Paste it above and tap 'Connect'")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Important") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Keep your integration as 'Internal'")
                        Text("• Don't share your token with anyone")
                        Text("• You'll need to share databases with your integration to sync them")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Connect to Notion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    private func saveToken() {
        do {
            try authService.authenticateWithToken(token)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Helper View

struct InstructionStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .fontWeight(.semibold)
            Text(text)
        }
    }
}

#Preview {
    SettingsView()
}
