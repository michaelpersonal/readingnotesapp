//
//  ChatService.swift
//  ReadingNotesApp
//
//  OpenAI GPT integration for chatting about book highlights
//

import Foundation

@MainActor
class ChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let apiKey = Secrets.openAIAPIKey
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o-mini" // Fast, cheap, good quality
    
    private var bookContext: String = ""
    
    // MARK: - Public Methods
    
    /// Set the book context (extracted text) for the conversation
    func setContext(_ text: String) {
        bookContext = text
        messages = []
        
        // Add system message with context
        let systemMessage = ChatMessage(
            role: .system,
            content: """
            You are a helpful reading assistant. The user is reading a book and has highlighted the following passage:
            
            ---
            \(text)
            ---
            
            Help the user understand this passage better. You can:
            - Explain concepts or vocabulary
            - Provide context or background information
            - Suggest connections to other ideas
            - Help develop notes or insights
            - Answer questions about the text
            
            Be concise but thorough. Use markdown formatting when helpful.
            """
        )
        messages.append(systemMessage)
        
        // Add welcome message from assistant
        let welcomeMessage = ChatMessage(
            role: .assistant,
            content: "I've read the highlighted passage. What would you like to know about it? I can help explain concepts, provide context, or help you develop notes."
        )
        messages.append(welcomeMessage)
    }
    
    /// Send a message and get a response
    func sendMessage(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: content)
        messages.append(userMessage)
        
        isLoading = true
        error = nil
        
        do {
            let response = try await callOpenAI()
            let assistantMessage = ChatMessage(role: .assistant, content: response)
            messages.append(assistantMessage)
        } catch {
            self.error = error.localizedDescription
            // Add error message to chat
            let errorMessage = ChatMessage(
                role: .assistant,
                content: "Sorry, I encountered an error: \(error.localizedDescription)"
            )
            messages.append(errorMessage)
        }
        
        isLoading = false
    }
    
    /// Generate a summary of the conversation for saving as notes
    func generateSummary() async -> String? {
        // Need at least one user message and one AI response (beyond the welcome message)
        let userMessages = messages.filter { $0.role == .user }
        let aiResponses = messages.filter { $0.role == .assistant && !$0.content.starts(with: "I've read the highlighted") }
        
        guard !userMessages.isEmpty, !aiResponses.isEmpty else {
            return nil
        }
        
        // Add summary request to messages temporarily
        let summaryPrompt = ChatMessage(
            role: .user,
            content: "Please provide a concise summary of the key insights from our conversation. Format it as reading notes that would be useful for future reference. Keep it brief but comprehensive."
        )
        
        // Build messages for API call (include summary prompt)
        var apiMessages = messages.map { message -> [String: String] in
            return [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }
        apiMessages.append([
            "role": "user",
            "content": summaryPrompt.content
        ])
        
        do {
            let summary = try await callOpenAIWithMessages(apiMessages)
            return summary
        } catch {
            // Fallback: return the last AI response if summary generation fails
            return aiResponses.last?.content
        }
    }
    
    /// Get all assistant messages as notes (fallback method)
    func getInsightsAsNotes() -> [String] {
        return messages
            .filter { $0.role == .assistant && !$0.content.starts(with: "I've read the highlighted") }
            .map { $0.content }
    }
    
    /// Clear the conversation
    func clearConversation() {
        messages = []
        bookContext = ""
    }
    
    // MARK: - Private Methods
    
    private func callOpenAI() async throws -> String {
        let apiMessages = messages.map { message -> [String: String] in
            return [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }
        return try await callOpenAIWithMessages(apiMessages)
    }
    
    private func callOpenAIWithMessages(_ apiMessages: [[String: String]]) async throws -> String {
        guard !apiKey.isEmpty && apiKey != "YOUR_OPENAI_API_KEY_HERE" else {
            throw ChatError.missingAPIKey
        }
        
        let url = URL(string: baseURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": apiMessages,
            "max_tokens": 1000,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            // Try to parse error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorInfo = errorJson["error"] as? [String: Any],
               let message = errorInfo["message"] as? String {
                throw ChatError.apiError(message)
            }
            throw ChatError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ChatError.invalidResponse
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: ChatRole
    let content: String
    let timestamp = Date()
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

enum ChatRole: String {
    case system
    case user
    case assistant
}

// MARK: - Errors

enum ChatError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is not configured"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .apiError(let message):
            return "API Error: \(message)"
        }
    }
}

