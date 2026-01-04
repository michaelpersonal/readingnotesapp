# Reading Notes App

A native iOS app that extracts highlighted text from Kindle screenshots using OCR and syncs them to Notion.

## Features

- 📸 **Screenshot Import** - Import Kindle screenshots from Photos app
- 🎨 **Highlight Detection** - Automatically detects highlighted passages (yellow, orange, blue, pink)
- 📝 **OCR Text Extraction** - Uses Apple Vision Framework for accurate text recognition
- 📓 **Personal Notes** - Add your own notes to each highlight
- ☁️ **Notion Sync** - Sync highlights to Notion with one-page-per-book organization
- 🔄 **Background Processing** - Efficient async processing with progress tracking

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Notion Integration Token (for syncing)

## Installation

1. Clone the repository:
```bash
git clone git@github.com:michaelpersonal/readingnotesapp.git
cd readingnotesapp/ReadingNotesApp
```

2. Open the project in Xcode:
```bash
open ReadingNotesApp.xcodeproj
```

3. Build and run on simulator or device

## Setup

### Notion Integration

To sync highlights to Notion, you need to set up a Notion integration:

1. Go to [Notion Integrations](https://www.notion.so/my-integrations)
2. Create a new **Internal Integration**
3. Copy your integration token (starts with `ntn_` or `secret_`)
4. In the app, go to **Settings → Connect to Notion**
5. Paste your token

See [NOTION_SETUP.md](NOTION_SETUP.md) for detailed setup instructions.

## Usage

### Basic Workflow

1. **Import Screenshot**
   - Tap "+" button
   - Select a Kindle screenshot from Photos
   - Screenshot is saved to the app

2. **Process Screenshot**
   - Tap on the screenshot
   - Tap "Process Screenshot"
   - Wait for highlight detection and OCR (usually 5-10 seconds)

3. **Review Highlights**
   - View extracted highlighted passages
   - Add personal notes if desired

4. **Sync to Notion**
   - Tap "Sync to Notion"
   - Choose an existing book page OR create a new one
   - Select parent page (e.g., "My Reading Notes")
   - All highlights are synced with timestamp and color indicators

### Notion Organization

Each book gets its own page with all highlights organized by sync date:

```
📚 Book Title (Page)
├─ 📅 Added: Jan 4, 2026, 2:30 PM
├─ ─────────
├─ ⭐ "Highlighted passage with yellow"
├─ 💭 "Your personal note"
├─ ─────────
├─ 🔥 "Highlighted passage with orange"
├─ ─────────
```

### Highlight Colors
- ⭐ Yellow
- 🔥 Orange
- 💙 Blue
- 💗 Pink
- ✨ Unknown

## Architecture

### Technology Stack
- **Platform**: iOS 17.0+ (Swift + SwiftUI)
- **Storage**: SwiftData for local persistence
- **OCR**: Apple Vision Framework (VNRecognizeTextRequest)
- **Sync**: Notion API v2022-06-28 with token-based authentication
- **Image Processing**: Core Image for highlight detection

### Project Structure

```
ReadingNotesApp/
├── App/
│   ├── ReadingNotesAppApp.swift       # App entry point
│   └── ContentView.swift               # Main tab view
├── Core/
│   ├── Models/                        # SwiftData models
│   │   ├── KindleScreenshot.swift
│   │   ├── Highlight.swift
│   │   ├── Note.swift
│   │   └── NotionConfig.swift
│   ├── Services/                      # Core services
│   │   ├── ImageProcessingService.swift
│   │   ├── OCRService.swift
│   │   └── HighlightDetectionService.swift
│   └── Utilities/
│       └── ImageProcessor.swift
├── Features/
│   ├── Screenshots/                   # Screenshot management
│   ├── Settings/                      # App settings
│   └── Highlights/                    # Highlight views
└── NotionSync/                        # Notion integration
    ├── NotionAPIClient.swift
    ├── NotionAuthService.swift
    ├── NotionSyncService.swift
    └── Models/
        ├── NotionPage.swift
        └── NotionBlock.swift
```

## Key Technical Details

### Highlight Detection Algorithm

1. Use Vision Framework to detect all text lines in the image
2. For each text line, check if background has colored highlighting
3. Detect highlight color using HSV color space analysis
4. Merge nearby highlighted lines into complete passages
5. Extract text from merged regions using OCR

### OCR Enhancement

- Uses Vision Framework's accurate recognition level
- Pre-processes images to increase contrast
- Tries both original and pre-processed versions
- Returns results with higher confidence scores

### Notion Sync

- Token-based authentication (no OAuth required)
- Rate limiting: 3 requests/second with token bucket algorithm
- Creates pages as sub-pages of parent pages
- Tracks sync status to avoid duplicates
- Supports appending to existing pages or creating new ones

## Troubleshooting

### Highlights Not Detected
- Ensure screenshot has clear, visible highlights
- Try reprocessing (tap menu → "Reprocess")
- Kindle highlights work best (yellow, orange, blue, pink)

### Incomplete Text Extraction
- OCR works best with high-resolution screenshots
- Avoid screenshots with glare or poor lighting
- Text must be clearly visible

### Notion Sync Issues
- Verify integration token is valid
- Ensure parent page is shared with your integration
- Check internet connection
- See [NOTION_SETUP.md](NOTION_SETUP.md) for detailed troubleshooting

### Can't Scroll to Buttons
- This is fixed in the latest version
- If issue persists, restart the app

## Development

### Building from Source

```bash
# Clone repository
git clone git@github.com:michaelpersonal/readingnotesapp.git
cd readingnotesapp/ReadingNotesApp

# Open in Xcode
open ReadingNotesApp.xcodeproj

# Build for simulator
xcodebuild -scheme ReadingNotesApp -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests (when available)
xcodebuild -scheme ReadingNotesApp -destination 'platform=iOS Simulator,name=iPhone 15' test
```

### Code Style
- Swift conventions
- SwiftUI for all UI
- Async/await for concurrency
- @MainActor for UI updates
- Comprehensive error handling

## Roadmap

### Completed ✅
- Screenshot import and storage
- Highlight detection with color recognition
- OCR text extraction
- Personal note-taking
- Notion sync with page organization
- Sync status tracking
- Reset sync functionality

### Future Enhancements
- Share Extension for quick import
- Automatic screenshot detection from photo library
- iCloud backup
- Export to PDF/Markdown
- Advanced search and filtering
- Widget support
- iPad optimization
- Batch operations

## License

Copyright © 2026. All rights reserved.

## Contributing

This is a personal project. If you find bugs or have suggestions, please open an issue on GitHub.

## Acknowledgments

- Built with Claude Code (Anthropic)
- Uses Apple Vision Framework for OCR
- Integrates with Notion API

## Contact

For questions or issues, please open a GitHub issue.
