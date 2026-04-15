# Waymark

A macOS menu bar app for **marking windows you need to come back to** and cycling through them with global hotkeys.

## The Problem

Your brain holds 3–5 things in working memory. When you're juggling 15+ windows — Chrome profiles, VS Code instances, terminals, LLM sessions — you forget what you need to check back on. Every existing tool either cycles through *all* windows (Cmd+Tab, AltTab) or arranges them on screen (Rectangle, Stage Manager). None of them answer the question: **"which windows actually matter to me right now?"**

## The Solution

Waymark lets you mark the windows you care about and ignore everything else. One hotkey to mark, one hotkey to cycle through your marks. It's a bookmark for your attention — you mark a window when you think "I need to come back to this", and the mark ensures you won't forget.

- Mark a window in one keystroke — no typing, no clicking, no context switch
- Cycle through only your marked windows, skipping the noise
- Works across all apps: browsers, editors, terminals, anything with a window
- Tracks individual Chrome tabs, not just whole windows
- Expose panel shows thumbnails of all your marks at a glance
- Floating palette keeps your marks visible without taking focus

## Install

### Download

1. Download the latest `.dmg` from [GitHub Releases](https://github.com/AtrRandom/Waymark/releases)
2. Open the DMG and drag **Waymark** to **Applications**
3. Launch Waymark from Applications

> **Note:** Waymark is not notarized yet. On first launch, macOS will block it. Right-click (or Control-click) the app and select **Open**, then click **Open** in the dialog. You only need to do this once.

### Homebrew

```bash
brew install --cask atrandom/tap/waymark
```

## Permissions

### Accessibility (Required)

Waymark needs Accessibility permission to detect global hotkeys and manage windows. On first launch, you'll be prompted to grant access.

**To grant manually:**
1. Open **System Settings > Privacy & Security > Accessibility**
2. Click the **+** button
3. Navigate to and add `Waymark.app`
4. Enable the toggle

### Screen Recording (Optional)

Screen Recording permission is needed to show live window thumbnails in the Expose panel. Without it, app icons are shown as placeholders.

**To grant:**
1. Open **System Settings > Privacy & Security > Screen Recording**
2. Click the **+** button
3. Add `Waymark.app`
4. Enable the toggle

> **Note:** On macOS 15 (Sequoia), you may need to re-authorize these permissions periodically.

## Hotkeys

| Hotkey | Action |
|--------|--------|
| `⌃⌥M` (Control + Option + M) | Toggle mark on the focused window |
| `⌃⌥N` (Control + Option + N) | Cycle forward through marked windows |
| `⌃⌥⇧N` (Control + Option + Shift + N) | Cycle backward through marked windows |
| `⌃⌥L` (Control + Option + L) | Show Expose panel with window thumbnails |
| `⌃⌥C` (Control + Option + C) | Clear all marked windows |

## Menu Bar

- **Empty watchlist:** Outline bookmark icon
- **Non-empty watchlist:** Filled bookmark icon + count
- Click the icon to see the list of marked windows, focus any window, or clear all
- **Launch at Login** toggle to start Waymark automatically
- **About Waymark** to see version info and links

## Expose Panel

Press `⌃⌥L` to show a full-screen overlay with thumbnails of all marked windows.

- **Arrow keys** to navigate the grid
- **Enter** to focus the selected window
- **1-9** to jump directly to a window by number
- **Escape** or click outside to dismiss
- **Click** a thumbnail to focus that window

## Changing Hotkeys

Edit `Waymark/Config/HotkeyConfig.swift` and rebuild. Each hotkey is defined as a key code + modifier combination:

```swift
// Example: Change toggle mark to Control + Option + B
static let toggleMark = (key: CGKeyCode(0x0B), mods: CGEventFlags.maskControl.union(.maskAlternate))
```

Key codes are macOS virtual key codes. Common ones:
- `0x00` = A, `0x0B` = B, `0x08` = C, ..., `0x2E` = M, `0x2D` = N
- Full reference: [Events.h virtual key codes](https://stackoverflow.com/q/3202629)

## Development

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (or just the Command Line Tools)
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Building from Source

```bash
# Generate the Xcode project
xcodegen generate

# Build
xcodebuild -scheme Waymark -configuration Debug build

# Find and launch the built app
open ~/Library/Developer/Xcode/DerivedData/Waymark-*/Build/Products/Debug/Waymark.app
```

Or open `Waymark.xcodeproj` in Xcode and hit Run.

## How It Works

- **Mark/Unmark:** Gets the focused window via the Accessibility API, stores its window ID
- **Cycle:** Focuses the next/previous window in your watchlist using AXUIElement + NSRunningApplication
- **Auto-cleanup:** Watches for app termination and window closure; validates the watchlist every 5 seconds
- **Thumbnails:** Captured via ScreenCaptureKit (SCScreenshotManager)
- **Global hotkeys:** Registered via CGEventTap

## Uninstall

1. Quit Waymark (click the menu bar icon > Quit)
2. Delete `Waymark.app` from Applications
3. Optionally remove preferences: `defaults delete io.atrandom.Waymark`

If installed via Homebrew: `brew uninstall waymark`

## Known Limitations

- **Not notarized** — macOS will warn on first launch. Right-click > Open to bypass.
- **No auto-update** — check GitHub Releases for new versions manually.
- **Hotkeys are not configurable in-app** — edit `HotkeyConfig.swift` and rebuild (see [Changing Hotkeys](#changing-hotkeys)).
- **Permissions reset on macOS 15** — Sequoia may periodically ask you to re-authorize Accessibility and Input Monitoring.
