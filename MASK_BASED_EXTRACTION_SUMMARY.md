# Mask-Based Highlight Extraction - Implementation Summary

## Complete Implementation

I've implemented a robust mask-based approach for extracting ONLY text that overlaps with pink highlights. The implementation includes:

### Files Created/Modified:

1. **HighlightMaskService.swift** (NEW) - Binary mask generation and overlap calculation
2. **HighlightDetectionService.swift** (UPDATED) - Uses mask for region detection
3. **ImageProcessingService.swift** (UPDATED) - Filters OCR results by mask overlap

### Key Features:

#### A) Binary Highlight Mask
- ✅ RGB-based pink detection (R > 0.55, G > 0.35, B > 0.35, R-B > 0.1)
- ✅ Morphological operations (closing + opening) to clean mask
- ✅ Returns binary CIImage mask

#### B) Connected Components & Merging
- ✅ Flood fill algorithm for connected components
- ✅ Conservative merging: vertical gap < 0.8×lineHeight, overlap > 50%, similar width/alignment
- ✅ Prevents merging non-highlighted lines

#### C) Mask-Based OCR Filtering
- ✅ Pads regions (15% vertical, 5% horizontal)
- ✅ Runs OCR on padded region
- ✅ Filters each OCR result by overlap ratio with mask
- ✅ Only keeps text with >25% overlap (tunable threshold)

#### D) Text Reconstruction
- ✅ Sorts by Y then X (top-to-bottom, left-to-right)
- ✅ Groups into lines
- ✅ Fixes hyphenation (merges "in-" + "stead" → "instead")
- ✅ Cleans spacing (" -or" → " or")

#### E) Truncation Retry
- ✅ Detects truncation (lowercase start, hyphen end, incomplete sentences)
- ✅ Retries with expanded padding if truncated
- ✅ Still applies mask filtering on retry

## Tuning Parameters

Located in `ImageProcessingService.swift`:

```swift
private let overlapThreshold: Float = 0.25  // Keep text with >25% mask overlap
private let verticalPaddingRatio: CGFloat = 0.15  // 15% of height
private let horizontalPaddingRatio: CGFloat = 0.05  // 5% of width
```

**To tune:**
- **overlapThreshold**: Lower (0.20) = more lenient, Higher (0.35) = stricter
- **verticalPaddingRatio**: Increase if truncating first/last words
- **horizontalPaddingRatio**: Increase if truncating horizontally

## Note

The new `HighlightMaskService.swift` file needs to be added to your Xcode project:
1. Right-click on `Core/Services` folder in Xcode
2. Select "Add Files to ReadingNotesApp..."
3. Select `HighlightMaskService.swift`
4. Ensure "Copy items if needed" is checked
5. Click "Add"

After adding the file, the build should succeed.

## Algorithm Flow

```
1. Create binary mask of pink highlights
   ↓
2. Find connected components (flood fill)
   ↓
3. Merge adjacent regions (conservative)
   ↓
4. For each merged region:
   a. Add padding (15% vertical, 5% horizontal)
   b. Crop and upscale (3x)
   c. Run OCR
   d. For each OCR result:
      - Convert to original image coordinates
      - Calculate overlap ratio with mask
      - Keep only if overlap > threshold (25%)
   e. Check for truncation
   f. If truncated, retry with more padding
   ↓
5. Sort OCR results (Y then X)
   ↓
6. Merge into lines, then paragraphs
   ↓
7. Fix hyphenation and clean spacing
   ↓
8. Return extracted text
```

This approach ensures ONLY text overlapping the pink highlight mask is extracted, solving the problem of including non-highlighted lines.

