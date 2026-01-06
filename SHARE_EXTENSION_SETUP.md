# Share Extension Setup Guide

This guide explains how to add the Share Extension to your Xcode project so users can share highlighted text directly from the Kindle app.

## Steps to Add Share Extension

### 1. Create Share Extension Target

1. Open `ReadingNotesApp.xcodeproj` in Xcode
2. File → New → Target
3. Select **Share Extension** (under iOS → Application Extension)
4. Click **Next**
5. Configure:
   - **Product Name**: `ReadingNotesShareExtension`
   - **Bundle Identifier**: `com.michaelguo.ReadingNotesApp.ShareExtension`
   - **Language**: Swift
   - **Embed in Application**: ReadingNotesApp
6. Click **Finish**
7. When prompted, click **Activate** to activate the scheme

### 2. Configure Share Extension

1. Select the **ReadingNotesShareExtension** target
2. Go to **General** tab:
   - **Deployment Target**: iOS 17.5 (match main app)
   - **Display Name**: Reading Notes
3. Go to **Signing & Capabilities**:
   - Enable **Automatically manage signing**
   - Select your team
   - **Note**: The extension will use the same App Group as the main app (if configured)

### 3. Replace Default ShareViewController

1. Delete the default `ShareViewController.swift` that Xcode created
2. Add the new files from `ReadingNotesApp/ShareExtension/`:
   - `ShareViewController.swift`
   - `SharePageSelectionView.swift`

### 4. Configure Info.plist

The Share Extension's `Info.plist` needs to be configured to accept plain text. Update it:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Reading Notes</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsText</key>
                <true/>
            </dict>
        </dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
    </dict>
</dict>
</plist>
```

### 5. Add Required Files to Extension Target

Make sure these files are included in the Share Extension target:

**From main app target** (add to extension):
- `NotionSyncService.swift`
- `NotionAPIClient.swift`
- `NotionAuthService.swift`
- `NotionBlock.swift`
- `NotionPage.swift`
- All Notion models

**New files** (should already be in extension):
- `ShareViewController.swift`
- `SharePageSelectionView.swift`

To add files to the extension target:
1. Select the file in Xcode
2. Open File Inspector (right panel)
3. Under **Target Membership**, check **ReadingNotesShareExtension**

### 6. Configure App Groups (Optional but Recommended)

If you want to share data between the main app and extension:

1. Select **ReadingNotesApp** target → **Signing & Capabilities**
2. Click **+ Capability** → **App Groups**
3. Add group: `group.com.michaelguo.ReadingNotesApp`
4. Repeat for **ReadingNotesShareExtension** target
5. Add the same App Group

**Note**: Currently, the Share Extension uses Keychain (via NotionAuthService) which works without App Groups.

### 7. Test the Extension

1. Build and run the main app on a device
2. Open Kindle app (or any app with text)
3. Highlight text and tap **Share**
4. Look for **Reading Notes** in the share sheet
5. Select it
6. You should see the page selection view

## How It Works

1. **User shares text from Kindle**:
   - User highlights text in Kindle app
   - Taps Share → Selects "Reading Notes"

2. **Share Extension receives text**:
   - `ShareViewController` extracts plain text from share context
   - Shows `SharePageSelectionView` with the shared text preview

3. **User selects book page**:
   - Can search for existing pages
   - Can create new book page
   - Same UI as main app's page selection

4. **Text is synced to Notion**:
   - Uses `NotionSyncService.syncTextToPage()` or `syncTextToNewPage()`
   - Text is formatted as a callout block with timestamp
   - Follows same sync logic as screenshot highlights

## Troubleshooting

### Extension doesn't appear in share sheet
- Make sure the extension target is built
- Check that `NSExtensionActivationSupportsText` is `true` in Info.plist
- Restart the device/simulator

### "Not authenticated" error
- Make sure Notion token is set in main app
- Keychain access should work automatically (same keychain as main app)

### Build errors
- Make sure all Notion files are added to Share Extension target
- Check that deployment targets match (iOS 17.5)

## Files Created

- `ShareExtension/ShareViewController.swift` - Main extension entry point
- `ShareExtension/SharePageSelectionView.swift` - UI for page selection
- `NotionSyncService.swift` - Updated to support text syncing (not just screenshots)

## Next Steps

After setup:
1. Test with real Kindle app
2. Verify Notion sync works
3. Consider adding App Groups for future data sharing
4. Add error handling for network issues

