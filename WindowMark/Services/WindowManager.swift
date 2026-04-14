import AppKit
import ApplicationServices
import ScreenCaptureKit

// Private API to extract CGWindowID from AXUIElement.
// Used by AeroSpace, Ice, Rectangle, and other macOS window managers.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

@MainActor
final class WindowManager {

    // MARK: - Get Focused Window

    func getFocusedWindow() -> WatchedWindow? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }

        let pid = frontApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var focusedWindowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef)
        guard result == .success, let windowElement = focusedWindowRef else { return nil }

        let axWindow = windowElement as! AXUIElement

        // Get CGWindowID via private API
        var windowID: CGWindowID = 0
        let idResult = _AXUIElementGetWindow(axWindow, &windowID)
        guard idResult == .success, windowID != 0 else { return nil }

        // Get window title
        let title = getTitle(of: axWindow) ?? "Untitled"

        return WatchedWindow(
            id: windowID,
            pid: pid,
            title: title,
            appName: frontApp.localizedName ?? "Unknown",
            bundleIdentifier: frontApp.bundleIdentifier,
            axElement: axWindow
        )
    }

    // MARK: - Focus Window

    func focusWindow(_ window: WatchedWindow) {
        guard let axElement = window.axElement else { return }

        // Unminimize if needed
        var minimizedRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axElement, kAXMinimizedAttribute as CFString, &minimizedRef)
        if let minimized = minimizedRef as? Bool, minimized {
            AXUIElementSetAttributeValue(axElement, kAXMinimizedAttribute as CFString, false as CFTypeRef)
        }

        // Activate the owning application
        if let app = NSRunningApplication(processIdentifier: window.pid) {
            app.activate()
        }

        // Raise and focus the window
        AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, true as CFTypeRef)
        AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, true as CFTypeRef)
        AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
    }

    // MARK: - Update Title

    func updateTitle(of window: inout WatchedWindow) {
        guard let axElement = window.axElement else { return }
        if let title = getTitle(of: axElement) {
            window.title = title
        }
    }

    // MARK: - Validation

    func isWindowValid(_ windowID: CGWindowID) -> Bool {
        getLiveWindowIDs().contains(windowID)
    }

    func getLiveWindowIDs() -> Set<CGWindowID> {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]] else {
            return []
        }

        var ids = Set<CGWindowID>()
        for entry in windowList {
            if let id = entry[kCGWindowNumber] as? CGWindowID {
                ids.insert(id)
            }
        }
        return ids
    }

    /// Returns all valid window IDs including off-screen (minimized) windows.
    func getAllWindowIDs() -> Set<CGWindowID> {
        guard let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]] else {
            return []
        }

        var ids = Set<CGWindowID>()
        for entry in windowList {
            if let id = entry[kCGWindowNumber] as? CGWindowID,
               let layer = entry[kCGWindowLayer] as? Int, layer == 0 {
                ids.insert(id)
            }
        }
        return ids
    }

    // MARK: - Thumbnail Capture

    func captureThumbnail(for window: WatchedWindow, size: CGSize) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            guard let scWindow = content.windows.first(where: { $0.windowID == window.id }) else {
                return nil
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            config.width = Int(size.width) * 2  // Retina
            config.height = Int(size.height) * 2
            config.showsCursor = false
            config.captureResolution = .best

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: image, size: size)
        } catch {
            return nil
        }
    }

    // MARK: - Window Frame

    /// Returns the window frame in AppKit coordinates (origin bottom-left), or nil if the window is not found.
    func getWindowFrame(_ windowID: CGWindowID) -> NSRect? {
        guard let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[CFString: Any]],
              let entry = info.first,
              let boundsDict = entry[kCGWindowBounds] as? [String: CGFloat] else {
            return nil
        }

        let cgX = boundsDict["X"] ?? 0
        let cgY = boundsDict["Y"] ?? 0
        let cgW = boundsDict["Width"] ?? 0
        let cgH = boundsDict["Height"] ?? 0

        // Convert CG (top-left origin) to AppKit (bottom-left origin)
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let appKitY = primaryScreenHeight - cgY - cgH

        return NSRect(x: cgX, y: appKitY, width: cgW, height: cgH)
    }

    // MARK: - Private Helpers

    private func getTitle(of element: AXUIElement) -> String? {
        var titleRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        guard result == .success, let title = titleRef as? String, !title.isEmpty else { return nil }
        return title
    }
}
