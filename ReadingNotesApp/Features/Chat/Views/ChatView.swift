//
//  ChatView.swift
//  ReadingNotesApp
//
//  Chat interface for discussing book highlights with AI
//

import SwiftUI

struct ChatView: View {
    let highlightedText: String
    let onSaveNotes: ([String]) -> Void
    let onDismiss: () -> Void
    
    @StateObject private var chatService = ChatService()
    @State private var inputText = ""
    @State private var isGeneratingSummary = false
    @FocusState private var isInputFocused: Bool
    
    private var hasConversation: Bool {
        chatService.messages.contains { $0.role == .user }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Context preview
                contextPreview
                
                Divider()
                
                // Chat messages
                messagesView
                
                Divider()
                
                // Input area
                inputArea
            }
            .navigationTitle("Chat about Highlight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                    .disabled(isGeneratingSummary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isGeneratingSummary {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Summarizing...")
                                .font(.caption)
                        }
                    } else {
                        Button("Save Notes") {
                            Task {
                                await saveNotes()
                            }
                        }
                        .disabled(!hasConversation || chatService.isLoading)
                    }
                }
            }
            .onAppear {
                chatService.setContext(highlightedText)
            }
        }
    }
    
    // MARK: - Save Notes
    
    private func saveNotes() async {
        isGeneratingSummary = true
        
        if let summary = await chatService.generateSummary() {
            onSaveNotes([summary])
        } else {
            // Fallback to all AI responses if summary generation fails
            let notes = chatService.getInsightsAsNotes()
            if !notes.isEmpty {
                onSaveNotes(notes)
            }
        }
        
        isGeneratingSummary = false
    }
    
    // MARK: - Context Preview
    
    private var contextPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "text.quote")
                    .foregroundColor(.pink)
                Text("Highlighted Text")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Text(highlightedText)
                .font(.footnote)
                .foregroundColor(.primary)
                .lineLimit(3)
                .truncationMode(.tail)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pink.opacity(0.1))
    }
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(chatService.messages.filter { $0.role != .system }) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    if chatService.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .id("loading")
                    }
                }
                .padding()
            }
            .onChange(of: chatService.messages.count) { _, _ in
                withAnimation {
                    if let lastMessage = chatService.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: chatService.isLoading) { _, isLoading in
                if isLoading {
                    withAnimation {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("Ask about this passage...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit {
                    sendMessage()
                }
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    .font(.system(size: 20))
            }
            .disabled(inputText.isEmpty || chatService.isLoading)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        let message = inputText
        inputText = ""
        
        Task {
            await chatService.sendMessage(message)
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    
    private var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isUser ? Color.blue : Color(UIColor.systemGray5))
                    )
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isUser {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Quick Actions (Optional Enhancement)

struct QuickActionButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(16)
        }
    }
}

// MARK: - Preview

#Preview {
    ChatView(
        highlightedText: "The quick brown fox jumps over the lazy dog. This is a sample highlighted text from a book that the user wants to discuss.",
        onSaveNotes: { notes in
            print("Saving notes: \(notes)")
        },
        onDismiss: {}
    )
}

