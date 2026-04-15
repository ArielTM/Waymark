import AppKit
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

        // Vibrancy blur background
        let effectView = NSVisualEffectView()
        effectView.material = .menu
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true
        contentView = effectView
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

    func update(watchlistManager: WatchlistManager) {
        let position = PalettePosition.stored
        let targets = watchlistManager.targets

        // Hide if position is "none" or no targets
        if position == .none || targets.isEmpty {
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

        let paletteView = PaletteView(
            targets: targets,
            currentIndex: watchlistManager.currentIndex,
            onSelect: { [weak watchlistManager] index in
                watchlistManager?.focusTarget(at: index)
            }
        )

        // Reuse the hosting view — recreating it each tick races with AppKit's
        // display cycle and crashes in _postWindowNeedsUpdateConstraints.
        if let hostingView {
            hostingView.rootView = paletteView
        } else {
            let hv = NSHostingView(rootView: paletteView)
            // Prevent NSHostingView from negotiating min/max content size with
            // the borderless panel — that path crashes during constraint updates.
            hv.sizingOptions = .intrinsicContentSize
            if let effectView = panel?.contentView as? NSVisualEffectView {
                hv.frame = NSRect(origin: .zero, size: hv.fittingSize)
                effectView.addSubview(hv)
            }
            hostingView = hv
        }

        guard let panel, let hostingView else { return }

        let contentSize = hostingView.fittingSize
        let maxHeight: CGFloat = 300
        let height = min(contentSize.height, maxHeight)
        var frame = panel.frame
        frame.size = NSSize(width: 220, height: height)
        panel.setFrame(frame, display: false)
        hostingView.frame = NSRect(origin: .zero, size: NSSize(width: 220, height: height))

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
}
