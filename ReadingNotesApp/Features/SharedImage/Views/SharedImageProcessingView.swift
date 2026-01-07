//
//  SharedImageProcessingView.swift
//  ReadingNotesApp
//
//  Processes shared screenshot images with OCR and presents page selection
//

import SwiftUI

struct SharedImageProcessingView: View {
    let image: UIImage
    let onDismiss: () -> Void
    
    @State private var isProcessing = true
    @State private var extractedText: String = ""
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showPageSelection = false
    
    // Services
    @State private var imageProcessingService: ImageProcessingService?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isProcessing {
                    // Processing state
                    VStack(spacing: 24) {
                        // Show thumbnail of shared image
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                        
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Extracting highlighted text...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("This may take a few seconds")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if let error = errorMessage {
                    // Error state
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Processing Failed")
                            .font(.headline)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            Task {
                                await processImage()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Cancel") {
                            onDismiss()
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding()
                } else if extractedText.isEmpty {
                    // No text found
                    VStack(spacing: 16) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Highlighted Text Found")
                            .font(.headline)
                        
                        Text("Make sure the screenshot contains pink highlighted text")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        // Show the image for reference
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 150)
                            .cornerRadius(8)
                        
                        Button("Cancel") {
                            onDismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Process Screenshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await processImage()
                }
            }
            .fullScreenCover(isPresented: $showPageSelection) {
                SharedTextPageSelectionView(
                    sharedText: extractedText,
                    onDismiss: {
                        showPageSelection = false
                        onDismiss()
                    }
                )
            }
        }
    }
    
    @MainActor
    private func processImage() async {
        isProcessing = true
        errorMessage = nil
        extractedText = ""
        
        do {
            // Initialize service if needed
            if imageProcessingService == nil {
                imageProcessingService = ImageProcessingService()
            }
            
            guard let service = imageProcessingService else {
                throw ProcessingError.ocrFailed
            }
            
            // Process the image to extract highlighted text
            let highlightedTexts = try await service.processScreenshotForText(image)
            
            if highlightedTexts.isEmpty {
                isProcessing = false
                extractedText = ""
            } else {
                // Combine all highlighted texts
                extractedText = highlightedTexts.joined(separator: "\n\n")
                isProcessing = false
                
                // Show page selection
                showPageSelection = true
            }
        } catch {
            isProcessing = false
            errorMessage = error.localizedDescription
        }
    }
}

// Note: Uses ProcessingError from ImageProcessingService.swift

