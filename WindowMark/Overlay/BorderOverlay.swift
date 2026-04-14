import AppKit
import ApplicationServices

// MARK: - Border Panel

final class BorderPanel: NSPanel {
    init(frame: NSRect) {
        // Expand frame by border width so the border draws around the window, not on top
        let borderWidth: CGFloat = 3
        let expandedFrame = frame.insetBy(dx: -borderWidth, dy: -borderWidth)

        super.init(
            contentRect: expandedFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.fullScreenAuxiliary]
        isReleasedWhenClosed = false

        let borderView = NSView(frame: NSRect(origin: .zero, size: expandedFrame.size))
        borderView.wantsLayer = true
        borderView.layer?.borderWidth = borderWidth
        borderView.layer?.borderColor = NSColor(
            red: 1.0, green: 0.624, blue: 0.039, alpha: 1.0  // #FF9F0A
        ).cgColor
        borderView.layer?.cornerRadius = 10
        contentView = borderView
    }

    /// Reposition the panel to surround the given window frame (in AppKit coordinates).
    func reposition(around windowFrame: NSRect) {
        let borderWidth: CGFloat = 3
        let expandedFrame = windowFrame.insetBy(dx: -borderWidth, dy: -borderWidth)
        setFrame(expandedFrame, display: false)
    }
}

// MARK: - Border Overlay Manager

@MainActor
final class BorderOverlayManager {
    private let windowManager: WindowManager
    private var panels: [CGWindowID: BorderPanel] = [:]
    private var windowPIDs: [CGWindowID: pid_t] = [:]
    private var positionTimer: Timer?

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    /// Sync overlay panels with the current set of marked windows.
    func sync(windows: [WatchedWindow]) {
        let currentIDs = Set(windows.map(\.id))
        let existingIDs = Set(panels.keys)

        // Remove panels for unmarked windows
        for id in existingIDs.subtracting(currentIDs) {
            panels[id]?.orderOut(nil)
            panels.removeValue(forKey: id)
            windowPIDs.removeValue(forKey: id)
        }

        // Add panels for newly marked windows
        for window in windows where !existingIDs.contains(window.id) {
            guard let frame = windowManager.getWindowFrame(window.id) else { continue }
            let panel = BorderPanel(frame: frame)
            panel.orderFrontRegardless()
            panels[window.id] = panel
            windowPIDs[window.id] = window.pid
        }

        // Hide panels for minimized windows, show for non-minimized
        for window in windows {
            guard let panel = panels[window.id] else { continue }
            if isMinimized(window) {
                panel.orderOut(nil)
            } else if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        }
    }

    /// Update positions of all overlay panels to match their target windows.
    func updatePositions() {
        let onScreenIDs = windowManager.getLiveWindowIDs()
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        for (windowID, panel) in panels {
            // Only show border when the window's app is frontmost and window is on screen
            let ownerIsFront = windowPIDs[windowID] == frontPID
            guard ownerIsFront,
                  onScreenIDs.contains(windowID),
                  let frame = windowManager.getWindowFrame(windowID) else {
                if panel.isVisible { panel.orderOut(nil) }
                continue
            }
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
            panel.reposition(around: frame)
        }
    }

    /// Called when a specific window moves or resizes (from AXObserver).
    func windowDidMove(_ windowID: CGWindowID) {
        guard let panel = panels[windowID],
              let frame = windowManager.getWindowFrame(windowID) else { return }
        panel.reposition(around: frame)
    }

    func startPositionTimer() {
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updatePositions()
            }
        }
    }

    func stop() {
        positionTimer?.invalidate()
        positionTimer = nil
        for panel in panels.values {
            panel.orderOut(nil)
        }
        panels.removeAll()
        windowPIDs.removeAll()
    }

    // MARK: - Private

    private func isMinimized(_ window: WatchedWindow) -> Bool {
        guard let axElement = window.axElement else { return false }
        var minimizedRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axElement, kAXMinimizedAttribute as CFString, &minimizedRef)
        return (minimizedRef as? Bool) ?? false
    }
}
