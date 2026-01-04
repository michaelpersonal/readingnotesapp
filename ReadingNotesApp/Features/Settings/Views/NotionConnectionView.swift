//
//  NotionConnectionView.swift
//  ReadingNotesApp
//
//  Notion connection and database selection view
//

import SwiftUI
import SwiftData

struct NotionConnectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authService: NotionAuthService

    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            List {
                Section("Connection Status") {
                    if authService.isAuthenticated {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Connected to Notion")
                        }

                        Button(role: .destructive) {
                            do {
                                try authService.signOut()
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        } label: {
                            Label("Disconnect", systemImage: "xmark")
                        }
                    }
                }

                Section("How to Sync") {
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionStep(number: 1, text: "Process a screenshot to extract highlights")
                        InstructionStep(number: 2, text: "Tap 'Sync to Notion' on the screenshot detail")
                        InstructionStep(number: 3, text: "Choose an existing book page or create a new one")
                        InstructionStep(number: 4, text: "Your highlights will be added to that page")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("About") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Each book gets its own page in Notion")
                        Text("• All highlights from that book are added to the same page")
                        Text("• You can sync multiple screenshots to the same book page")
                        Text("• Highlights are timestamped when synced")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Notion Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
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

}

// MARK: - Helper Views

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
}

#Preview {
    NotionConnectionView(authService: NotionAuthService())
}
