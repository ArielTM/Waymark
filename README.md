# WindowMark

A macOS menu bar app that lets you **mark** specific windows and cycle through them with global hotkeys. Think of it as a "favorites" list for windows you need to keep checking back on.

Solves the problem of losing track of important windows when context-switching between many Chrome profiles, VS Code instances, and LLM sessions.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ (or just the Command Line Tools)
- [xcodegen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build

```bash
# Generate the Xcode project
xcodegen generate

# Build
xcodebuild -scheme WindowMark -configuration Debug build

# Find and launch the built app
open ~/Library/Developer/Xcode/DerivedData/WindowMark-*/Build/Products/Debug/WindowMark.app
```

Or open `WindowMark.xcodeproj` in Xcode and hit Run.

## Permissions

### Accessibility (Required)

WindowMark needs Accessibility permission to detect global hotkeys and manage windows. On first launch, you'll be prompted to grant access.

**To grant manually:**
1. Open **System Settings > Privacy & Security > Accessibility**
2. Click the **+** button
3. Navigate to and add `WindowMark.app`
4. Enable the toggle

### Screen Recording (Optional)

Screen Recording permission is needed to show live window thumbnails in the Expose panel. Without it, app icons are shown as placeholders.

**To grant:**
1. Open **System Settings > Privacy & Security > Screen Recording**
2. Click the **+** button
3. Add `WindowMark.app`
4. Enable the toggle

> **Note:** On macOS 15 (Sequoia), you may need to re-authorize these permissions periodically.

## Hotkeys

| Hotkey | Action |
|--------|--------|
| `Ctrl + Alt + M` | Toggle mark on the focused window |
| `Ctrl + Alt + N` | Cycle forward through marked windows |
| `Ctrl + Alt + Shift + N` | Cycle backward through marked windows |
| `Ctrl + Alt + L` | Show Expose panel with window thumbnails |
| `Ctrl + Alt + C` | Clear all marked windows |

## Menu Bar

- **Empty watchlist:** Outline bookmark icon
- **Non-empty watchlist:** Filled bookmark icon + count
- Click the icon to see the list of marked windows, focus any window, clear all, or quit

## Expose Panel

Press `Ctrl + Alt + L` to show a full-screen overlay with thumbnails of all marked windows.

- **Arrow keys** to navigate the grid
- **Enter** to focus the selected window
- **1-9** to jump directly to a window by number
- **Escape** or click outside to dismiss
- **Click** a thumbnail to focus that window

## Changing Hotkeys

Edit `WindowMark/Config/HotkeyConfig.swift` and rebuild. Each hotkey is defined as a key code + modifier combination:

```swift
// Example: Change toggle mark to Ctrl + Alt + B
static let toggleMark = (key: CGKeyCode(0x0B), mods: CGEventFlags.maskControl.union(.maskAlternate))
```

Key codes are macOS virtual key codes. Common ones:
- `0x00` = A, `0x0B` = B, `0x08` = C, ..., `0x2E` = M, `0x2D` = N
- Full reference: [Events.h virtual key codes](https://stackoverflow.com/q/3202629)

## How It Works

- **Mark/Unmark:** Gets the focused window via the Accessibility API, stores its window ID
- **Cycle:** Focuses the next/previous window in your watchlist using AXUIElement + NSRunningApplication
- **Auto-cleanup:** Watches for app termination and window closure; validates the watchlist every 5 seconds
- **Thumbnails:** Captured via ScreenCaptureKit (SCScreenshotManager)
- **Global hotkeys:** Registered via CGEventTap
