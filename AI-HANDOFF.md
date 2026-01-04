# AI Development Handoff Document

**Project**: Reading Notes App (iOS Kindle Screenshot OCR + Notion Sync)
**Last Updated**: January 4, 2026
**Session**: Initial development session
**Status**: Core features complete, functional MVP

---

## 🎯 Project Overview

Native iOS app that extracts highlighted text from Kindle screenshots using OCR and syncs them to Notion for personal reading notes management.

**What Works**: ✅
- Screenshot import from Photos
- Highlight detection (yellow, orange, blue, pink)
- OCR text extraction using Vision Framework
- Personal note-taking
- Notion sync with token authentication
- One-page-per-book organization
- Sync status tracking and reset

**Known Issues**: ⚠️
- Highlight extraction sometimes incomplete (merging threshold may need tuning)
- Book title extraction removed (was producing garbled text)
- Debug logging still active (needs cleanup for production)
- Scroll view works but padding could be optimized

---

## 📁 Project Structure

```
ReadingNotesApp/
├── ReadingNotesApp.xcodeproj/          # Xcode project
├── ReadingNotesApp/
│   ├── ReadingNotesAppApp.swift        # @main entry point
│   ├── ContentView.swift                # Tab view (Screenshots, Settings)
│   │
│   ├── Core/
│   │   ├── Models/                      # SwiftData models
│   │   │   ├── KindleScreenshot.swift   # Main screenshot entity
│   │   │   ├── Highlight.swift          # Extracted highlight with text
│   │   │   ├── Note.swift               # User's personal notes
│   │   │   └── NotionConfig.swift       # Notion auth settings
│   │   │
│   │   ├── Services/                    # Core business logic
│   │   │   ├── ImageProcessingService.swift    # Main orchestrator
│   │   │   ├── OCRService.swift                # Vision Framework wrapper
│   │   │   └── HighlightDetectionService.swift # Color-based detection
│   │   │
│   │   ├── Repositories/
│   │   │   └── ScreenshotRepository.swift      # Data access layer
│   │   │
│   │   └── Utilities/
│   │       └── ImageProcessor.swift            # Image helper functions
│   │
│   ├── Features/
│   │   ├── Screenshots/
│   │   │   ├── Views/
│   │   │   │   ├── ScreenshotListView.swift    # Main list
│   │   │   │   └── ScreenshotDetailView.swift  # Detail + process
│   │   │   └── ViewModels/
│   │   │       └── ScreenshotListViewModel.swift
│   │   │
│   │   └── Settings/
│   │       └── Views/
│   │           ├── SettingsView.swift          # Main settings
│   │           ├── NotionConnectionView.swift   # Auth UI
│   │           └── PageSelectionView.swift      # Sync page picker
│   │
│   ├── NotionSync/                      # Notion integration
│   │   ├── NotionAPIClient.swift        # HTTP client (rate limited)
│   │   ├── NotionAuthService.swift      # Token management
│   │   ├── NotionSyncService.swift      # Sync orchestrator
│   │   └── Models/
│   │       ├── NotionPage.swift         # Page request/response
│   │       └── NotionBlock.swift        # Block structures
│   │
│   └── Info.plist                       # App permissions
│
├── README.md                            # User documentation
├── AGENT.md                             # Development notes
├── NOTION_SETUP.md                      # Notion setup guide
└── AI-HANDOFF.md                        # This file
```

---

## 🔑 Key Technical Details

### SwiftData Models

**KindleScreenshot** (Core entity)
```swift
- id: UUID
- imageData: Data?
- thumbnailData: Data?
- sourceBook: String?  // Defaults to "Untitled"
- createdAt: Date
- processingStatus: ProcessingStatus (pending, processing, completed, failed)
- highlights: [Highlight]
- isSyncedToNotion: Bool
- notionPageId: String?
```

**Highlight** (Extracted text)
```swift
- id: UUID
- extractedText: String
- confidence: Double
- boundingBox: BoundingBox
- highlightColor: HighlightColor (yellow, orange, blue, pink, unknown)
- notes: [Note]
- isSyncedToNotion: Bool
- notionBlockId: String?
```

**Note** (User notes)
```swift
- id: UUID
- content: String
- createdAt: Date
- updatedAt: Date
- isSyncedToNotion: Bool
- notionBlockId: String?
```

### Processing Pipeline

```
1. User imports screenshot → Saved to SwiftData
2. User taps "Process Screenshot"
   ↓
3. HighlightDetectionService.detectHighlights()
   - Uses Vision to detect all text lines
   - For each line, samples background color (HSV)
   - Groups lines by color (yellow, orange, blue, pink)
   - Merges nearby lines (< 0.1 units = 2-3 line heights)
   ↓
4. OCRService.recognizeTextWithPreprocessing()
   - Crops to merged highlight region
   - Runs OCR on original + preprocessed image
   - Returns higher confidence result
   ↓
5. Save Highlight entities to SwiftData
6. Mark screenshot as "completed"
```

### Notion Sync Flow

```
User taps "Sync to Notion"
   ↓
PageSelectionView appears
   ↓
User chooses:
   A) Existing page → syncScreenshotToPage()
      - Appends blocks to existing page
   B) Create new → syncScreenshotToNewPage()
      - Creates page as sub-page of selected parent
      - Adds highlights as initial content
   ↓
Only unsynced highlights are included (isSyncedToNotion = false)
   ↓
After success, mark highlights as synced
```

**Notion Block Structure**:
```
📅 Added: [timestamp]
─────────
⭐ "Highlighted text" (callout block with emoji)
💭 "User note" (quote block)
─────────
🔥 "Next highlight"
─────────
```

---

## 🛠️ How to Continue Development

### Setup

```bash
# Clone repo
git clone git@github.com:michaelpersonal/readingnotesapp.git
cd readingnotesapp/ReadingNotesApp

# Open in Xcode
open ReadingNotesApp.xcodeproj

# Build for simulator
xcodebuild -scheme ReadingNotesApp -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Running the App

1. Select iPhone 15 simulator (or any iOS 17+ device)
2. Cmd+R to build and run
3. In simulator, import a Kindle screenshot from Photos
4. Tap screenshot → "Process Screenshot"
5. Review extracted highlights
6. Connect Notion in Settings (need integration token)
7. Sync to Notion

### Common Tasks

#### Fix Incomplete Highlight Extraction

**File**: `ReadingNotesApp/Core/Services/HighlightDetectionService.swift`

**Current merging threshold**: 0.1 units (line 104)
```swift
if verticalDistance < 0.1 && current.color == previous.color {
```

**To make more aggressive** (merge more lines):
- Increase threshold to 0.15 or 0.2
- Will capture longer passages but risk merging separate highlights

**To make more conservative** (split more):
- Decrease threshold to 0.05 or 0.03
- Will capture distinct highlights but may fragment passages

**Color detection tuning** (lines 177-179):
```swift
// Current thresholds - very lenient
if saturation < 0.05 || value < 0.4 {
    return nil
}
```
- Decrease saturation/value for even more lenient
- Increase for stricter color matching

#### Add New Highlight Color

**File**: `ReadingNotesApp/Core/Models/Highlight.swift`

1. Add to enum:
```swift
enum HighlightColor: String, Codable {
    case yellow, orange, blue, pink, green, unknown  // Add green
}
```

2. Add detection in `HighlightDetectionService.swift` (around line 183):
```swift
// Green highlights
else if green > 0.65 && red < 0.55 && blue < 0.55 {
    return .green
}
```

3. Add icon in `NotionSyncService.swift` (line 140):
```swift
case .green:
    return "💚"
```

#### Remove Debug Logging

**Files to clean**:
- `NotionAPIClient.swift`: Lines 35-47, 115-127 (📤 📥 ❌ prints)
- `NotionSyncService.swift`: Lines 30, 40, 107 (🔄 📝 ✅ prints)
- `PageSelectionView.swift`: Line 56 (👆 print)
- `ScreenshotDetailView.swift`: Lines 238-265 (reset function prints)

**Also remove UI debug elements**:
- `ScreenshotDetailView.swift`: Lines 56-59 (Unsynced counter)

#### Add New Notion Block Type

**File**: `ReadingNotesApp/NotionSync/Models/NotionBlock.swift`

1. Add property to struct (line 28):
```swift
let toggle: ToggleBlock?
```

2. Add to CodingKeys (line 41):
```swift
case toggle
```

3. Add to custom encoder (line 60):
```swift
case "toggle":
    try container.encode(toggle, forKey: .toggle)
```

4. Add factory method (line 187):
```swift
static func toggle(_ text: String) -> NotionBlock {
    NotionBlock(
        type: "toggle",
        paragraph: nil,
        // ... all nil except toggle
        toggle: ToggleBlock(richText: [NotionRichText(content: text)])
    )
}
```

5. Define block struct (line 272):
```swift
struct ToggleBlock: Codable {
    let richText: [NotionRichText]
    let color: String = "default"

    enum CodingKeys: String, CodingKey {
        case richText = "rich_text"
        case color
    }
}
```

#### Add Share Extension (Not Yet Implemented)

**Next major feature to implement**:

1. File → New → Target → Share Extension
2. Name: `ReadingNotesShareExtension`
3. Enable App Groups: `group.com.yourcompany.readingnotes`
4. Share SwiftData container:
```swift
let container = ModelContainer(
    for: [KindleScreenshot.self, Highlight.self, Note.self],
    configurations: ModelConfiguration(
        url: FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.yourcompany.readingnotes")!
            .appendingPathComponent("ReadingNotes.sqlite")
    )
)
```
5. In ShareViewController, receive image from extensionContext
6. Save to shared container
7. Notify main app using CFNotificationCenter

---

## 🐛 Known Issues & Solutions

### Issue: Highlights Still Incomplete

**Symptoms**: Only partial sentences extracted, missing lines

**Diagnosis**:
- Check console for "Building blocks: X unsynced highlights"
- Look at bounding boxes in HighlightDetectionService
- May need even more aggressive merging

**Solutions**:
1. Increase merge threshold to 0.15-0.2
2. Make color detection even more lenient (saturation < 0.03)
3. Increase bounding box expansion (lines 51-54)
4. Check if Vision is detecting all text lines (add logging)

### Issue: ScrollView Not Scrolling

**Symptoms**: Can't access buttons at bottom

**Current fix**: 100pt bottom padding (ScreenshotDetailView.swift:170)

**If still occurring**:
1. Check if ScrollView is embedded in another ScrollView
2. Ensure VStack doesn't have fixed height
3. Try `.frame(maxHeight: .infinity)` on VStack
4. Add `.scrollIndicators(.visible)` to make scrollbar always visible

### Issue: SwiftData Not Updating

**Symptoms**: Changes don't persist, or only some highlights update

**Solution**: Always convert relationships to Arrays before iterating
```swift
// ❌ Wrong
for highlight in screenshot.highlights {
    highlight.isSyncedToNotion = false
}

// ✅ Correct
let highlightArray = Array(screenshot.highlights)
for highlight in highlightArray {
    highlight.isSyncedToNotion = false
}
```

### Issue: Notion API Errors

**"The data couldn't be read because it is missing"**
- Check JSON encoding - ensure only relevant fields are sent
- Make response properties optional
- Add custom decoders with graceful fallback
- Check console for 📥 response to see actual JSON

**"body.parent.workspace should be not present or true"**
- When creating page_id parent, set workspace: nil (not false)
- See NotionPage.swift line 46

**"Incorrect redirect uri"**
- This is why we use token auth, not OAuth
- For internal integrations, OAuth redirect URIs don't work

---

## 🎨 Code Patterns & Conventions

### Async/Await with @MainActor

```swift
// All UI-related operations must be on main actor
@MainActor
class ImageProcessingService {
    func processScreenshot(_ screenshot: KindleScreenshot) async throws {
        // Background work
        let results = await detectHighlights(in: image)

        // SwiftData operations (also main actor)
        screenshot.highlights.append(highlight)
        try modelContext.save()
    }
}
```

### Error Handling Pattern

```swift
do {
    try await operation()
} catch {
    // Log for debugging
    print("❌ Error: \(error)")

    // Set user-facing error
    errorMessage = error.localizedDescription
    showError = true

    // Update state
    screenshot.processingStatus = .failed
}
```

### SwiftData Model Relationships

```swift
// Parent
@Model
class KindleScreenshot {
    @Relationship(deleteRule: .cascade, inverse: \Highlight.screenshot)
    var highlights: [Highlight] = []
}

// Child
@Model
class Highlight {
    var screenshot: KindleScreenshot?
}
```

### Notion API Calls

```swift
// All go through NotionAPIClient
let client = NotionAPIClient()

// Rate limited automatically (3 req/sec)
let response = try await client.createPage(
    request: pageRequest,
    accessToken: token
)

// Always check console for 📤 request and 📥 response
```

---

## 📊 Performance Notes

### Image Processing
- Takes 5-10 seconds for typical screenshot
- Runs on background queue (not main thread)
- Vision Framework does heavy lifting

### Notion API
- Rate limited to 3 requests/second (enforced in code)
- Each sync makes 1 request (create or append)
- Search makes 1 request per search

### SwiftData
- Saves are async but fast (< 100ms typically)
- Use `modelContext.save()` after mutations
- Relationships are lazy-loaded

---

## 🧪 Testing Checklist

Manual tests to run after changes:

**Core Functionality**:
- [ ] Import screenshot from Photos
- [ ] Process screenshot with 1 highlight
- [ ] Process screenshot with 5+ highlights
- [ ] Add personal note
- [ ] Delete highlight
- [ ] Reprocess screenshot

**Notion Sync**:
- [ ] Connect with valid token
- [ ] Sync to new page
- [ ] Sync to existing page
- [ ] Sync multiple times (should skip synced items)
- [ ] Reset sync status
- [ ] Sync after reset

**Edge Cases**:
- [ ] Screenshot with no highlights
- [ ] Very long highlight (multiple paragraphs)
- [ ] Multiple highlights same color
- [ ] Mixed highlight colors
- [ ] Low quality/blurry screenshot
- [ ] Invalid Notion token
- [ ] Network offline

---

## 🚀 Next Features to Implement

### Priority 1: Core Improvements
1. **Improve highlight extraction accuracy**
   - Fine-tune merging thresholds based on testing
   - Add confidence threshold filtering
   - Handle edge cases (page headers, footers)

2. **Clean up for production**
   - Remove debug logging
   - Remove UI debug counters
   - Add user-friendly error messages
   - Improve loading states

3. **Search and filtering**
   - Search highlights by text
   - Filter by book
   - Filter by sync status
   - Sort options (date, book, confidence)

### Priority 2: UX Enhancements
4. **Share Extension**
   - Quick import from Photos share sheet
   - Background processing
   - Notification when complete

5. **Batch operations**
   - Select multiple screenshots
   - Batch process
   - Batch sync
   - Batch delete

6. **Better error handling**
   - Retry failed operations
   - Queue for offline sync
   - Show specific error messages

### Priority 3: Advanced Features
7. **Automatic detection**
   - Monitor photo library for new screenshots
   - Auto-detect Kindle screenshots
   - Background processing
   - Notifications

8. **Export options**
   - Export to PDF
   - Export to Markdown
   - Share as text

9. **iCloud sync**
   - Sync across devices
   - CloudKit integration
   - Conflict resolution

---

## 📝 Important Notes for AI Assistants

### When Modifying Highlight Detection
- Always test with real Kindle screenshots
- Merging threshold affects passage completeness vs. separation
- Color thresholds affect false positives vs. missed highlights
- Changes require reprocessing existing screenshots

### When Working with Notion API
- Notion's JSON structure is complex and varies by object type
- Always make properties optional where possible
- Use custom decoders for flexibility
- Test against real Notion workspace
- Rate limiting is critical (3 req/sec max)

### When Working with SwiftData
- Convert relationships to Arrays before iterating in loops
- Always save context after mutations
- Use @MainActor for all model operations
- Cascade deletes are configured on relationships

### When Adding UI Features
- All UI code uses SwiftUI (no UIKit view controllers)
- Use @State for view-local state
- Use @Published in ObservableObject for shared state
- All async operations should show loading indicators

---

## 🔗 Useful References

**Apple Documentation**:
- [Vision Framework](https://developer.apple.com/documentation/vision)
- [SwiftData](https://developer.apple.com/documentation/swiftdata)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)

**Notion API**:
- [API Reference](https://developers.notion.com/reference)
- [Working with Blocks](https://developers.notion.com/docs/working-with-blocks)
- [Rate Limits](https://developers.notion.com/reference/request-limits)

**Project Files**:
- `README.md` - User-facing documentation
- `AGENT.md` - Detailed development history and decisions
- `NOTION_SETUP.md` - Step-by-step Notion setup

---

## 🤝 Handoff Checklist

When picking up this project:

- [ ] Read this document completely
- [ ] Read AGENT.md for development context
- [ ] Clone repo and build successfully
- [ ] Run app in simulator
- [ ] Import a test screenshot
- [ ] Process it and check highlights
- [ ] Set up Notion integration (optional)
- [ ] Review key files: HighlightDetectionService, OCRService, NotionSyncService
- [ ] Check current issues in GitHub (if any)
- [ ] Ask user for priorities/immediate needs

---

## 💬 Quick Start Commands

```bash
# Build
xcodebuild -scheme ReadingNotesApp -destination 'platform=iOS Simulator,name=iPhone 15' build

# Clean build
xcodebuild clean && xcodebuild -scheme ReadingNotesApp -destination 'platform=iOS Simulator,name=iPhone 15' build

# Check git status
git status

# Commit changes
git add -A
git commit -m "Your message"
git push origin main
```

---

**Last updated**: January 4, 2026
**Built with**: Claude Code (Anthropic)
**Status**: Functional MVP, ready for iteration
