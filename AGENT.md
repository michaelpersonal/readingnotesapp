# Agent Development Notes

This document tracks the development process, key decisions, and lessons learned during the creation of the Reading Notes App.

## Development Timeline

### Session 1: Foundation & Core Features
**Date**: January 4, 2026

#### Phase 1: Project Setup
- Created iOS app with SwiftUI and SwiftData
- Set up project structure with MVVM architecture
- Enabled required capabilities (App Groups, Keychain)

#### Phase 2: Data Models
- `KindleScreenshot`: Core model for storing screenshots
- `Highlight`: Extracted highlighted text with bounding boxes
- `Note`: User's personal notes on highlights
- `NotionConfig`: Notion authentication settings

#### Phase 3: Image Processing Pipeline
- **OCRService**: Vision Framework integration for text recognition
- **HighlightDetectionService**: Color-based highlight detection using HSV color space
- **ImageProcessingService**: Orchestrator for the entire pipeline

**Key Technical Challenge**: Highlight Detection Algorithm

Initial approaches:
1. ❌ Color masking + contour detection (too many false positives)
2. ❌ Text-based with strict thresholds (missed too many highlights)
3. ✅ **Final approach**: Line-by-line text detection + color sampling + aggressive merging

The winning algorithm:
```
1. Detect all text lines with Vision Framework
2. For each line, expand bounding box and sample background color
3. Convert to HSV and check for highlight colors (yellow, orange, blue, pink)
4. Merge vertically adjacent lines with same color
5. Extract text from merged regions with OCR preprocessing
```

**Iterations on Highlight Merging**:
- Started with 0.03 threshold → too fragmented
- Increased to 0.05 → better but still incomplete
- Final: 0.1 units (2-3 line heights) → captures complete passages

#### Phase 4: Notion Integration

**Initial Plan**: OAuth 2.0 with redirect URIs
**Problem**: Notion automatically adds HTTPS prefix, breaking custom URL schemes for internal integrations

**Pivot**: Token-based authentication
- User enters integration token manually in settings
- Stored securely in iOS Keychain
- Simpler and more reliable for internal integrations

**Architecture Evolution**:

Original design:
```
One Database → Each screenshot = one page in database
```

User feedback: "Why do I need a database? I want one page per book"

Final design:
```
Parent Page (e.g., "My Reading Notes")
├─ Book Page 1
│  ├─ Highlights from Screenshot 1
│  ├─ Highlights from Screenshot 2
│  └─ ...
├─ Book Page 2
└─ ...
```

Benefits:
- More intuitive organization
- All highlights for a book in one place
- Timestamped sync sessions
- Easy to browse and search

#### Phase 5: Bug Fixes & Refinements

**Issue 1: JSON Encoding Errors**
- Problem: `NotionBlock` encoding all optional fields as null
- Solution: Custom `encode(to:)` that only includes relevant block type

**Issue 2: Page Properties Decoding**
- Problem: Notion returns complex property structures, decoding failed
- Solution: Custom decoder with graceful fallback, optional properties

**Issue 3: Duplicate Syncs**
- Problem: Same highlights synced 5 times to multiple pages
- Causes:
  - No filtering of already-synced highlights
  - Button could be tapped multiple times
  - SwiftData relationship iteration issues
- Solutions:
  - Filter `!isSyncedToNotion` in buildHighlightBlocks
  - Guard against duplicate calls with `isSyncing` check
  - Convert relationship to Array before iterating

**Issue 4: Empty Pages After Sync**
- Problem: Created pages had no content
- Root cause: Highlights marked as synced from previous attempt
- Solution: Added "Reset Sync Status" button to clear sync flags

**Issue 5: Reset Only Affecting One Highlight**
- Problem: SwiftData relationship iteration not updating all items
- Solution: Convert to Array first: `let highlightArray = Array(screenshot.highlights)`

**Issue 6: Incomplete Highlight Extraction**
- Multiple iterations on merging threshold
- Made color detection more lenient (saturation < 0.05, value < 0.4)
- Expanded bounding boxes for color sampling (4% wider, 2% taller)

**Issue 7: Garbled Book Titles**
- Problem: OCR extracting nonsense from top of screenshots
- Solution: Removed book title extraction entirely, default to "Untitled"

**Issue 8: Can't Scroll to Buttons**
- Problem: ScrollView not providing enough space
- Solution: Added 100pt bottom padding, made ScrollView explicit

## Key Technical Decisions

### 1. Vision Framework Over Third-Party OCR
**Decision**: Use Apple's Vision Framework
**Rationale**:
- Native performance and optimization
- No external dependencies
- Privacy-preserving (on-device processing)
- Excellent accuracy with preprocessing

### 2. SwiftData Over Core Data
**Decision**: Use SwiftData for persistence
**Rationale**:
- Modern Swift-first API
- Better integration with SwiftUI
- Simpler relationship handling
- Native to iOS 17+

### 3. Token Auth Over OAuth
**Decision**: Manual token entry instead of OAuth flow
**Rationale**:
- Internal integrations can't use public OAuth redirect URIs
- Simpler for users (copy/paste token)
- More reliable (no redirect URL issues)
- Better for personal use case

### 4. Aggressive Highlight Merging
**Decision**: Merge lines within 0.1 units (2-3 line heights)
**Rationale**:
- Kindle highlights often span many lines
- Better to over-merge than under-merge
- Users can edit in Notion if needed
- Captures complete thoughts/passages

### 5. Page-Based Over Database-Based Notion Sync
**Decision**: Create/append to pages instead of database entries
**Rationale**:
- More intuitive for users
- Flexible organization
- One book = one page paradigm
- Easy to browse and edit

## Lessons Learned

### 1. OCR on Highlighted Text is Tricky
- Yellow overlay reduces OCR accuracy
- Pre-processing helps (contrast, grayscale, denoising)
- Running OCR on both original and processed, choosing higher confidence
- Vision Framework's "accurate" mode is worth the extra time

### 2. SwiftData Relationships Need Careful Handling
- Don't iterate directly over relationships in loops
- Convert to Array first for reliable updates
- Save context after each major operation
- Watch for retain cycles with @MainActor

### 3. Notion API Has Quirks
- Properties structure varies by page type
- Empty objects for dividers: `{"type": "divider", "divider": {}}`
- Rate limiting is strict (3 req/sec)
- Always use custom decoders for flexibility

### 4. User Feedback Drives Design
- Original "database" approach made sense technically
- "One page per book" made sense to users
- Listening and pivoting saved the project
- Simpler is usually better

### 5. Async/Await Requires Discipline
- Always use @MainActor for UI updates
- Don't block main thread with sync operations
- Task groups for parallel operations
- Proper error propagation with throws

## Code Quality Principles

### Error Handling
```swift
// Always provide context
throw NotionAPIError.badRequest(message: "Failed to decode: \(error)")

// Use guard for early returns
guard let accessToken = authService.getAccessToken() else {
    throw NotionSyncError.notAuthenticated
}

// Wrap risky operations
do {
    try await operation()
} catch {
    print("❌ Error: \(error)")
    throw error
}
```

### Logging Strategy
- Use emoji prefixes for visual scanning: 🔄 📤 📥 ✅ ❌ ⚠️
- Log at state transitions (starting, completed, error)
- Include context (IDs, counts, status)
- Remove or disable debug logs in production

### State Management
- Single source of truth (SwiftData)
- @Published for observable changes
- @State for view-local state
- Explicit sync status flags

## Performance Optimizations

### 1. Image Processing
- Process on background queue
- Downsample large images
- Cache thumbnails
- Cancel operations on view dismissal

### 2. Notion API
- Rate limit with token bucket (3 req/sec)
- Batch operations where possible
- Skip already-synced items
- Exponential backoff on errors

### 3. UI Responsiveness
- All async operations off main thread
- Progress indicators for long operations
- Optimistic UI updates where safe
- Lazy loading for lists

## Testing Strategy

### Manual Testing Checklist
- [ ] Import screenshot from Photos
- [ ] Process screenshot with 1 highlight
- [ ] Process screenshot with multiple highlights
- [ ] Add personal notes
- [ ] Sync to new page
- [ ] Sync to existing page
- [ ] Reset sync status
- [ ] Reprocess screenshot
- [ ] Test with poor quality images
- [ ] Test with various highlight colors
- [ ] Test network failures
- [ ] Test invalid Notion tokens

### Edge Cases Handled
- Empty screenshots (no highlights)
- Very low confidence OCR results
- Network timeouts
- Invalid Notion credentials
- Missing parent pages
- Already-synced highlights
- Malformed API responses

## Future Improvements

### Short Term
1. Remove debug logging and counters
2. Add proper error messages for users
3. Implement pull-to-refresh
4. Add search/filter functionality
5. Improve OCR accuracy with ML models

### Medium Term
1. Share Extension for quick import
2. Background photo library monitoring
3. Batch processing
4. Export to PDF/Markdown
5. iCloud sync

### Long Term
1. iPad optimization
2. Widget support
3. Advanced search with tags
4. Multi-book selection
5. Statistics and insights

## Development Environment

### Tools Used
- **IDE**: Xcode 15.0+
- **Language**: Swift 5.9
- **Frameworks**: SwiftUI, SwiftData, Vision
- **Version Control**: Git
- **AI Assistant**: Claude Code (Anthropic)

### Build Configuration
```bash
# Debug build
xcodebuild -scheme ReadingNotesApp -destination 'platform=iOS Simulator,name=iPhone 15' build

# Clean build
xcodebuild -scheme ReadingNotesApp -destination 'platform=iOS Simulator,name=iPhone 15' clean build
```

## Acknowledgments

Built with assistance from Claude Code, which helped with:
- Architecture design and planning
- SwiftUI implementation
- Vision Framework integration
- Notion API client development
- Debugging and troubleshooting
- Documentation

## Final Notes

This project demonstrates:
- Modern iOS development practices
- Complex async workflows
- Integration with external APIs
- Image processing and OCR
- Real-world problem solving

Key takeaway: **Iterate based on user feedback, not technical elegance.**

The "one page per book" design wasn't the original plan, but it was the right solution for users. Always validate assumptions with real usage patterns.

---
*Document last updated: January 4, 2026*
