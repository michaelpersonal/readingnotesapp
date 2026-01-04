# Robust Highlight Extraction Plan

## Algorithm Overview

### Step 1: Color-Based Highlight Detection
1. Convert image to HSV color space
2. Threshold for pink highlight color (HSV range)
3. Apply morphological operations to clean up noise
4. Find connected components (contours) to get bounding boxes
5. Filter by size (remove tiny regions)

### Step 2: Region Processing
1. Merge adjacent/overlapping regions of same color
2. Sort regions top-to-bottom, left-to-right
3. Pad each region (10-15% of height/width) to avoid truncation
4. Group regions that likely belong to same passage

### Step 3: OCR on Highlighted Regions
1. Crop image to padded region
2. Upscale cropped region (2-3x) for better OCR
3. Run VNRecognizeTextRequest
4. Check for truncation indicators:
   - Starts with lowercase (mid-sentence)
   - Ends with hyphen
   - Ends with lowercase (likely continues)
5. If truncation detected, expand padding and re-run OCR

### Step 4: Text Reconstruction
1. Sort OCR results by position (y then x)
2. Merge lines with proper spacing
3. Fix hyphenation (detect and merge hyphenated words)
4. Return array of strings (one per highlight passage)

## Parameters

### Pink Highlight Detection (HSV)
- Hue: 300-360 or 0-20 (pink/red range)
- Saturation: 0.2-1.0 (must have some color)
- Value: 0.4-1.0 (not too dark)

### Padding Heuristics
- Horizontal padding: 5-10% of region width
- Vertical padding: 10-15% of region height
- Minimum padding: 10 pixels

### Merging Heuristics
- Merge if vertical distance < 1.5 * average line height
- Merge if horizontal overlap > 50%
- Same color required

### Truncation Detection
- Starts with lowercase letter (after trimming)
- Ends with hyphen
- Ends with lowercase (and not punctuation)
- Confidence threshold: < 0.7 at boundaries

