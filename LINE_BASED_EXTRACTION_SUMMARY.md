# Line-Based Highlight Extraction - Implementation Summary

## Complete Implementation

I've implemented a line-based approach that extracts **entire lines** if any part is highlighted, avoiding partial words and garbled OCR.

### Files Created/Modified:

1. **LineBasedHighlightService.swift** (NEW) - Line-based extraction pipeline
2. **ImageProcessingService.swift** (UPDATED) - Now uses line-based service

### Algorithm Flow:

```
1. Create binary highlight mask (pink detection)
   ↓
2. Detect text column bounds (union of all text observations)
   ↓
3. Run Vision to detect all text lines
   ↓
4. Group observations by line (similar Y coordinates)
   ↓
5. For each line:
   - Calculate overlap ratio with highlight mask
   - If overlap > threshold (20%), mark line as highlighted
   ↓
6. For each highlighted line:
   - Crop to full line rectangle
   - Add minimal padding (8% vertical, 3% horizontal)
   - Upscale 2x using high-quality interpolation
   - Run OCR on upscaled line crop
   ↓
7. Sort lines top-to-bottom
   ↓
8. Merge consecutive lines into passages
   ↓
9. Fix hyphenation and normalize spacing
   ↓
10. Return array of passages (one per highlight block)
```

### Key Features:

#### A) Line Detection
- Uses Vision Framework to detect all text
- Groups observations by Y position (same line if Y diff < 0.02)
- Merges observations on same line into single bounding box

#### B) Line Filtering
- Calculates overlap ratio between line bounding box and highlight mask
- If overlap > 20%, entire line is marked as highlighted
- Extracts full line (including non-highlighted words on same line)

#### C) Line Extraction
- Crops to full line rectangle (not just highlighted portion)
- Minimal padding: 8% vertical, 3% horizontal (avoids partial glyphs)
- 2x upscaling with high-quality interpolation before OCR
- Runs OCR on each line crop

#### D) Passage Merging
- Sorts lines top-to-bottom
- Merges consecutive lines (within 1.5 line heights)
- Fixes hyphenation ("in-" + "stead" → "instead")
- Normalizes spacing and punctuation

### Tuning Parameters

Located in `LineBasedHighlightService.swift`:

```swift
private let lineOverlapThreshold: Float = 0.20  // Line highlighted if >20% overlap
private let verticalPaddingRatio: CGFloat = 0.08  // 8% of line height
private let horizontalPaddingRatio: CGFloat = 0.03  // 3% of line width
private let upscaleFactor: CGFloat = 2.0  // 2x upscaling
```

**To tune:**
- **lineOverlapThreshold**: Lower (0.15) = more lines included, Higher (0.30) = stricter
- **verticalPaddingRatio**: Increase if truncating words (but may include adjacent lines)
- **horizontalPaddingRatio**: Increase if truncating horizontally
- **upscaleFactor**: Increase (2.5x, 3x) for better OCR on small text

### Advantages of Line-Based Approach:

1. ✅ **No partial words** - Extracts entire lines, avoiding garbled OCR
2. ✅ **Rectangular regions** - Full line rectangles are cleaner for OCR
3. ✅ **Minimal padding** - Only 8% vertical padding reduces chance of including adjacent lines
4. ✅ **Better OCR quality** - Upscaling full lines gives better results than partial regions
5. ✅ **Natural text flow** - Preserves line structure and reading order

### Important: Add File to Xcode

The new `LineBasedHighlightService.swift` file needs to be added to your Xcode project:

1. Open Xcode
2. Right-click on the `Core/Services` folder
3. Select "Add Files to ReadingNotesApp..."
4. Navigate to and select `LineBasedHighlightService.swift`
5. Ensure "Copy items if needed" is checked
6. Click "Add"

After adding the file, the build should succeed.

### Expected Results:

- Extracts complete lines (no partial words)
- Includes non-highlighted words on same line (as requested)
- No garbled OCR tokens from padding
- Better text quality from upscaling full lines
- Proper line merging and hyphenation fixing

