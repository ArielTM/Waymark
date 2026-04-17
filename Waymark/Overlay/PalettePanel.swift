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

// MARK: - Pill Panel (click-through ambient indicator)

final class PalettePillPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 32, height: PalettePillView.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // Click-through: cursor tracking happens via polling NSEvent.mouseLocation,
        // so we never need to receive mouse events ourselves.
        ignoresMouseEvents = true
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
    private var pillPanel: PalettePillPanel?
    private var hostingView: NSHostingView<PaletteView>?
    private var pillView: PalettePillView?
    private var currentPosition: PalettePosition = .topRight
    private var lastTargetCount: Int = 0

    // Hover state (only meaningful inside hoverReveal + full-screen).
    private var hoverTimer: Timer?
    private var hoverExpanded = false
    private var dwellStart: Date?
    private let revealDwell: TimeInterval = 0.15
    private let collapseDwell: TimeInterval = 0.25

    func update(watchlistManager: WatchlistManager, settings: Settings) {
        let position = settings.palettePosition
        let targets = watchlistManager.targets

        // Nothing to show.
        if position == .none || targets.isEmpty {
            hideAll()
            return
        }

        let isFullScreen = Self.isFrontmostAppFullScreen()

        if isFullScreen {
            switch settings.fullScreenMode {
            case .alwaysHide:
                hideAll()
                return
            case .alwaysShow:
                stopHoverTracking()
                hoverExpanded = false
                pillPanel?.orderOut(nil)
                showPalette(position: position, watchlistManager: watchlistManager, targetCount: targets.count)
                return
            case .hoverReveal:
                showHoverReveal(position: position, watchlistManager: watchlistManager, targetCount: targets.count)
                return
            }
        }

        // Normal desktop: always show palette, tear down hover state.
        stopHoverTracking()
        hoverExpanded = false
        pillPanel?.orderOut(nil)
        showPalette(position: position, watchlistManager: watchlistManager, targetCount: targets.count)
    }

    func stop() {
        stopHoverTracking()
        panel?.orderOut(nil)
        pillPanel?.orderOut(nil)
        panel = nil
        pillPanel = nil
        hostingView = nil
        pillView = nil
    }

    // MARK: - Hover-Reveal flow

    private func showHoverReveal(position: PalettePosition,
                                 watchlistManager: WatchlistManager,
                                 targetCount: Int) {
        ensurePanel(watchlistManager: watchlistManager)
        ensurePill()

        if position != currentPosition {
            applyPosition(position)
            currentPosition = position
        }
        resizePaletteIfNeeded(targetCount: targetCount)
        refreshPill(count: targetCount, position: position)

        startHoverTracking()

        if hoverExpanded {
            pillPanel?.orderOut(nil)
            if !(panel?.isVisible ?? false) {
                panel?.orderFrontRegardless()
            }
        } else {
            panel?.orderOut(nil)
            if !(pillPanel?.isVisible ?? false) {
                pillPanel?.orderFrontRegardless()
            }
        }
    }

    private func showPalette(position: PalettePosition,
                             watchlistManager: WatchlistManager,
                             targetCount: Int) {
        ensurePanel(watchlistManager: watchlistManager)
        if position != currentPosition {
            applyPosition(position)
            currentPosition = position
        }
        resizePaletteIfNeeded(targetCount: targetCount)
        if !(panel?.isVisible ?? false) {
            panel?.orderFrontRegardless()
        }
    }

    private func hideAll() {
        stopHoverTracking()
        hoverExpanded = false
        panel?.orderOut(nil)
        pillPanel?.orderOut(nil)
    }

    // MARK: - Lazy panel creation

    private func ensurePanel(watchlistManager: WatchlistManager) {
        if panel == nil {
            panel = PalettePanel()
            applyPosition(currentPosition)
        }
        if hostingView == nil, let panel {
            let hv = NSHostingView(rootView: PaletteView(watchlistManager: watchlistManager))
            hv.sizingOptions = .intrinsicContentSize
            panel.contentView = hv
            hv.layoutSubtreeIfNeeded()
            hostingView = hv
        }
    }

    private func ensurePill() {
        if pillPanel == nil {
            pillPanel = PalettePillPanel()
        }
        if pillView == nil, let pillPanel {
            let view = PalettePillView(frame: NSRect(x: 0, y: 0,
                                                    width: 32,
                                                    height: PalettePillView.height))
            pillPanel.contentView = view
            pillView = view
        }
    }

    // MARK: - Resize / reposition

    private func resizePaletteIfNeeded(targetCount: Int) {
        guard let panel, let hostingView else { return }
        // Only resize when target count changes — poking the constraint system every
        // tick is what crashed the display cycle historically.
        if targetCount != lastTargetCount {
            let contentSize = hostingView.fittingSize
            let maxHeight: CGFloat = 300
            let height = min(contentSize.height, maxHeight)
            panel.setContentSize(NSSize(width: 220, height: height))
            hostingView.layoutSubtreeIfNeeded()
            applyPosition(currentPosition)
            lastTargetCount = targetCount
        }
    }

    private func refreshPill(count: Int, position: PalettePosition) {
        guard let pillPanel, let pillView else { return }
        pillView.setCount(count)
        let intrinsic = pillView.intrinsicContentSize
        if abs(pillPanel.frame.size.width - intrinsic.width) > 0.5
            || abs(pillPanel.frame.size.height - intrinsic.height) > 0.5 {
            pillPanel.setContentSize(intrinsic)
            pillView.layoutSubtreeIfNeeded()
        }
        applyPillPosition(position)
    }

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

    private func applyPillPosition(_ position: PalettePosition) {
        guard let screen = NSScreen.main, let pillPanel else { return }
        let screenFrame = screen.frame
        let topY = screen.visibleFrame.maxY
        let size = pillPanel.frame.size

        var origin: NSPoint
        switch position {
        case .topLeft:
            origin = NSPoint(x: screenFrame.minX + 10, y: topY - size.height - 10)
        case .centerLeft:
            origin = NSPoint(x: screenFrame.minX + 10, y: screenFrame.midY - size.height / 2)
        case .bottomLeft:
            origin = NSPoint(x: screenFrame.minX + 10, y: screenFrame.minY + 10)
        case .topRight:
            origin = NSPoint(x: screenFrame.maxX - size.width - 10, y: topY - size.height - 10)
        case .centerRight:
            origin = NSPoint(x: screenFrame.maxX - size.width - 10, y: screenFrame.midY - size.height / 2)
        case .bottomRight:
            origin = NSPoint(x: screenFrame.maxX - size.width - 10, y: screenFrame.minY + 10)
        case .none:
            return
        }
        pillPanel.setFrameOrigin(origin)
    }

    // MARK: - Hover tracking

    private func startHoverTracking() {
        guard hoverTimer == nil else { return }
        // 30 Hz polling of NSEvent.mouseLocation is cheap and side-effect-free
        // (no frame writes). Event monitors would also work but polling keeps
        // the state machine synchronous and easier to reason about.
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hoverTick()
            }
        }
        dwellStart = nil
    }

    private func stopHoverTracking() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        dwellStart = nil
    }

    private func hoverTick() {
        let mouse = NSEvent.mouseLocation
        let zone: NSRect
        if hoverExpanded {
            guard let frame = panel?.frame else { return }
            zone = frame.insetBy(dx: -8, dy: -8)
        } else {
            guard let frame = pillPanel?.frame else { return }
            // 10pt Fitts's-law runway around the pill — since the pill sits with a
            // 10pt inset from the screen edge, this brings the hover zone flush
            // with the edge on the anchored side.
            zone = frame.insetBy(dx: -10, dy: -10)
        }

        let inside = zone.contains(mouse)
        let now = Date()

        if hoverExpanded {
            if inside {
                dwellStart = nil
            } else {
                if dwellStart == nil { dwellStart = now }
                if let start = dwellStart, now.timeIntervalSince(start) >= collapseDwell {
                    hoverExpanded = false
                    dwellStart = nil
                    panel?.orderOut(nil)
                    pillPanel?.orderFrontRegardless()
                }
            }
        } else {
            if !inside {
                dwellStart = nil
            } else {
                if dwellStart == nil { dwellStart = now }
                if let start = dwellStart, now.timeIntervalSince(start) >= revealDwell {
                    hoverExpanded = true
                    dwellStart = nil
                    pillPanel?.orderOut(nil)
                    panel?.orderFrontRegardless()
                }
            }
        }
    }

    // MARK: - Full-screen detection

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
