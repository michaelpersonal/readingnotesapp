# Notion Integration Setup Guide

## Overview

This app uses **Notion Internal Integration** for authentication (token-based, not OAuth). This is simpler and works perfectly for personal use.

## 1. Create Notion Integration

1. Go to https://www.notion.so/my-integrations
2. Click "+ New integration"
3. Fill in the details:
   - **Name**: ReadingNotesApp (or your preferred name)
   - **Logo**: Optional
   - **Associated workspace**: Select your workspace
4. Under "Type", keep it as **Internal**
5. Under "Capabilities", ensure these are enabled:
   - Read content
   - Update content
   - Insert content
6. Click "Submit"
7. **Copy the "Internal Integration Token"** (starts with `secret_`)
   - Keep this token safe - you'll need it in the app

## 2. Setup in Notion (One-Time)

**Create a "Reading Notes" parent page:**
1. Open Notion
2. Create a new page called "Reading Notes" (or any name you prefer)
3. Share this page with your integration:
   - Click "..." menu → Connections
   - Add your integration
4. This will be the parent page where all your book pages are created

## 3. Using the App

### First Time Setup
1. Open the app
2. Go to the "Settings" tab
3. Tap "Connect to Notion"
4. Paste your Internal Integration Token (from step 1.7)
5. Tap "Connect"

### Syncing Highlights to Notion

**Per-Book Workflow:**
1. Import and process a Kindle screenshot
2. View the extracted highlights
3. Tap "Sync to Notion" button
4. **Choose one:**
   - **Existing page**: Search for and select your existing book page
   - **New page**: Create a new page
     - Enter book title
     - Select parent page (e.g., "Reading Notes")
     - The new book page will be created as a sub-page
5. All highlights from this screenshot are added to that page

**Key Benefits:**
- **One page per book** - all highlights for a book go to the same page
- **Multiple screenshots** - you can sync many screenshots to the same book page
- **Organized** - each book page contains all your highlights from different reading sessions
- **Timestamped** - each sync adds a timestamp so you know when highlights were added

### Data Structure in Notion

```
📚 Book Title (Page)
├─ 📅 Added: Jan 4, 2026, 2:30 PM
├─ ─────────
├─ ⭐ "First highlighted passage from this screenshot"
├─ 💭 "Your personal note on this highlight"
├─ ─────────
├─ 🔥 "Second highlighted passage"
├─ ─────────
│
├─ 📅 Added: Jan 5, 2026, 9:15 AM (from another screenshot)
├─ ─────────
├─ ⭐ "More highlights from the next reading session"
├─ ─────────
...
```

### Highlight Colors
- ⭐ Yellow
- 🔥 Orange
- 💙 Blue
- 💗 Pink
- ✨ Unknown

## Troubleshooting

### "Invalid token format" error
- Make sure your token starts with `secret_`
- Copy the entire token from Notion
- Don't add extra spaces or characters

### "Not authenticated" error
- Make sure you've entered your token in Settings
- Try disconnecting and reconnecting with a fresh token

### "No pages found" when searching
- Make sure you have pages in your Notion workspace
- Pages shared with your integration will appear in search
- You can always create a new page instead

### Rate limit errors
- The app respects Notion's rate limit of 3 requests per second
- If you see rate limit errors, wait a moment and try again

## Security Notes

- Integration tokens are stored securely in the iOS Keychain
- Never share your integration token with anyone
- Keep your integration as "Internal" - don't make it public
- If you suspect your token is compromised, regenerate it in Notion settings
