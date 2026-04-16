import AppKit
import ApplicationServices
import SwiftUI

// MARK: - Palette Position

enum PalettePosition: String, CaseIterable {
    case none = "none"
    case topLeft = "topLeft"
    case centerLeft = "centerLeft"
    case bottomLeft = "bottomLeft"
    case topRight = "topRight"
    case centerRight = "centerRight"
    case bottomRight = "bottomRight"

    var displayName: String {
        switch self {
        case .none: return "None (Hidden)"
        case .topLeft: return "Top Left"
        case .centerLeft: return "Center Left"
        case .bottomLeft: return "Bottom Left"
        case .topRight: return "Top Right"
        case .centerRight: return "Center Right"
        case .bottomRight: return "Bottom Right"
        }
    }

}

// MARK: - Palette Panel (Minimal HUD)

final class PalettePanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = false
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Palette Controller

@MainActor
final class PalettePanelController {
    private var panel: PalettePanel?
    private var hostingView: NSHostingView<PaletteView>?
    private var currentPosition: PalettePosition = .topRight
    private var lastTargetCount: Int = 0

    func update(watchlistManager: WatchlistManager, settings: Settings) {
        let position = settings.palettePosition
        let targets = watchlistManager.targets

        // Hide if position is "none" or no targets
        if position == .none || targets.isEmpty {
            panel?.orderOut(nil)
            return
        }

        // Hide when a full-screen app is active.  Collection behavior
        // can't do this (.canJoinAllSpaces overrides .fullScreenAuxiliary)
        // and visibleFrame comparison is unreliable on notched Macs.
        // kAXFullscreenAttribute is a public API we already have permission for.
        if settings.hideOnFullScreen && Self.isFrontmostAppFullScreen() {
            panel?.orderOut(nil)
            return
        }

        // Create panel lazily
        if panel == nil {
            panel = PalettePanel()
            applyPosition(position)
            currentPosition = position
        }

        // Reposition if setting changed
        if position != currentPosition {
            applyPosition(position)
            currentPosition = position
        }

        // Create the hosting view once.  PaletteView observes the
        // WatchlistManager directly via @Observable, so SwiftUI handles
        // content updates internally — no rootView replacement needed,
        // which avoids the _NSViewUpdateConstraints crash.
        if hostingView == nil {
            let hv = NSHostingView(rootView: PaletteView(watchlistManager: watchlistManager))
            hv.sizingOptions = .intrinsicContentSize
            panel?.contentView = hv
            // Force constraint resolution now so the display cycle finds
            // consistent state instead of crashing in _NSViewUpdateConstraints.
            hv.layoutSubtreeIfNeeded()
            hostingView = hv
        }

        guard let panel, let hostingView else { return }

        // Only resize when target count changes to avoid poking the
        // constraint system on every timer tick.
        if targets.count != lastTargetCount {
            let contentSize = hostingView.fittingSize
            let maxHeight: CGFloat = 300
            let height = min(contentSize.height, maxHeight)
            panel.setContentSize(NSSize(width: 220, height: height))
            hostingView.layoutSubtreeIfNeeded()
            applyPosition(currentPosition)
            lastTargetCount = targets.count
        }

        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func stop() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
    }

    // MARK: - Private

    private func applyPosition(_ position: PalettePosition) {
        guard let screen = NSScreen.main, let panel else { return }
        let screenFrame = screen.frame
        let topY = screen.visibleFrame.maxY  // respect the menu bar
        let panelSize = panel.frame.size

        var origin: NSPoint
        switch position {
        case .topLeft:
            origin = NSPoint(
                x: screenFrame.minX + 10,
                y: topY - panelSize.height - 10
            )
        case .centerLeft:
            origin = NSPoint(
                x: screenFrame.minX + 10,
                y: screenFrame.midY - panelSize.height / 2
            )
        case .bottomLeft:
            origin = NSPoint(
                x: screenFrame.minX + 10,
                y: screenFrame.minY + 10
            )
        case .topRight:
            origin = NSPoint(
                x: screenFrame.maxX - panelSize.width - 10,
                y: topY - panelSize.height - 10
            )
        case .centerRight:
            origin = NSPoint(
                x: screenFrame.maxX - panelSize.width - 10,
                y: screenFrame.midY - panelSize.height / 2
            )
        case .bottomRight:
            origin = NSPoint(
                x: screenFrame.maxX - panelSize.width - 10,
                y: screenFrame.minY + 10
            )
        case .none:
            return
        }

        panel.setFrameOrigin(origin)
    }

    private static func isFrontmostAppFullScreen() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let window = windowRef else { return false }

        var fullScreenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, "AXFullScreen" as CFString, &fullScreenRef) == .success else {
            return false
        }
        return (fullScreenRef as? Bool) == true
    }
}
