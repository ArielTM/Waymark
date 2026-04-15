import AppKit
import ApplicationServices
import SwiftUI

// MARK: - Palette Position

enum PalettePosition: String, CaseIterable {
    case none = "none"
    case topRight = "topRight"
    case bottomRight = "bottomRight"
    case rightCenter = "rightCenter"
    case belowIcon = "belowIcon"

    var displayName: String {
        switch self {
        case .none: return "None (Hidden)"
        case .topRight: return "Top Right"
        case .bottomRight: return "Bottom Right"
        case .rightCenter: return "Right Center"
        case .belowIcon: return "Below Icon"
        }
    }

    static var defaultPosition: PalettePosition { .topRight }

    static var stored: PalettePosition {
        get {
            let raw = UserDefaults.standard.string(forKey: "palettePosition") ?? defaultPosition.rawValue
            return PalettePosition(rawValue: raw) ?? defaultPosition
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "palettePosition")
        }
    }
}

// MARK: - Palette Settings

enum PaletteSettings {
    static var hideOnFullScreen: Bool {
        get {
            // Default to true — UserDefaults.bool returns false for unset keys
            if UserDefaults.standard.object(forKey: "paletteHideOnFullScreen") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "paletteHideOnFullScreen")
        }
        set { UserDefaults.standard.set(newValue, forKey: "paletteHideOnFullScreen") }
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
    private var currentPosition: PalettePosition = PalettePosition.stored
    private var lastTargetCount: Int = 0

    func update(watchlistManager: WatchlistManager) {
        let position = PalettePosition.stored
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
        if PaletteSettings.hideOnFullScreen && Self.isFrontmostAppFullScreen() {
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
        let visibleFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        var origin: NSPoint
        switch position {
        case .topRight:
            origin = NSPoint(
                x: visibleFrame.maxX - panelSize.width - 10,
                y: visibleFrame.maxY - panelSize.height - 10
            )
        case .bottomRight:
            origin = NSPoint(
                x: visibleFrame.maxX - panelSize.width - 10,
                y: visibleFrame.minY + 10
            )
        case .rightCenter:
            origin = NSPoint(
                x: visibleFrame.maxX - panelSize.width - 10,
                y: visibleFrame.midY - panelSize.height / 2
            )
        case .belowIcon:
            // Position near the right side of the menu bar
            origin = NSPoint(
                x: visibleFrame.maxX - panelSize.width - 10,
                y: visibleFrame.maxY - panelSize.height - 5
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
