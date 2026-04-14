import AppKit
import ApplicationServices

// MARK: - Border Panel

final class BorderPanel: NSPanel {
    init(frame: NSRect) {
        let borderWidth: CGFloat = 3
        let expandedFrame = frame.insetBy(dx: -borderWidth, dy: -borderWidth)

        super.init(
            contentRect: expandedFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        level = .normal
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
}

// MARK: - Border Overlay Manager

@MainActor
final class BorderOverlayManager {
    private let windowManager: WindowManager
    private var panels: [CGWindowID: BorderPanel] = [:]
    private let cgsConnection = CGSMainConnectionID()

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    /// Single update method: syncs panels with the watchlist, updates positions, and z-orders.
    func update(windows: [WatchedWindow]) {
        let currentIDs = Set(windows.map(\.id))
        let existingIDs = Set(panels.keys)

        // Remove panels for unmarked windows
        for id in existingIDs.subtracting(currentIDs) {
            panels[id]?.orderOut(nil)
            panels.removeValue(forKey: id)
        }

        // Add panels for newly marked windows
        for window in windows where !existingIDs.contains(window.id) {
            guard let frame = windowManager.getWindowFrame(window.id) else { continue }
            let panel = BorderPanel(frame: frame)
            panels[window.id] = panel
        }

        // Update positions and z-order
        let onScreenIDs = windowManager.getLiveWindowIDs()

        for (windowID, panel) in panels {
            guard onScreenIDs.contains(windowID),
                  let frame = windowManager.getWindowFrame(windowID) else {
                if panel.isVisible { panel.orderOut(nil) }
                continue
            }

            // Reposition
            let borderWidth: CGFloat = 3
            let expandedFrame = frame.insetBy(dx: -borderWidth, dy: -borderWidth)
            panel.setFrame(expandedFrame, display: false)

            // Show if hidden
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }

            // Z-order: position directly above the target window
            CGSOrderWindow(cgsConnection, Int32(panel.windowNumber), 1, Int32(windowID))
        }
    }

    func stop() {
        for panel in panels.values {
            panel.orderOut(nil)
        }
        panels.removeAll()
    }
}
