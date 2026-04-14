import AppKit
import SwiftUI

// MARK: - Palette Panel

final class PalettePanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 100),
            styleMask: [.titled, .nonactivatingPanel, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )

        title = "WindowMark"
        level = .floating
        isOpaque = false
        backgroundColor = NSColor.windowBackgroundColor
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        titlebarAppearsTransparent = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Palette Controller

@MainActor
final class PalettePanelController {
    private var panel: PalettePanel?

    func update(watchlistManager: WatchlistManager) {
        let windows = watchlistManager.windows

        if windows.isEmpty {
            panel?.orderOut(nil)
            return
        }

        // Create panel lazily
        if panel == nil {
            panel = PalettePanel()
            positionOnScreen()
        }

        let paletteView = PaletteView(
            windows: windows,
            currentIndex: watchlistManager.currentIndex,
            onSelect: { [weak watchlistManager] index in
                watchlistManager?.focusWindow(at: index)
            }
        )

        let hostingView = NSHostingView(rootView: paletteView)
        hostingView.frame.size = hostingView.fittingSize
        panel?.contentView = hostingView

        let titleBarHeight: CGFloat = 22
        let contentHeight = hostingView.fittingSize.height + titleBarHeight
        var frame = panel!.frame
        frame.size.height = min(contentHeight, 322)
        frame.size.width = 220
        panel?.setFrame(frame, display: false)

        if panel?.isVisible != true {
            panel?.orderFrontRegardless()
        }
    }

    func stop() {
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Private

    private func positionOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - 230
        let y = screenFrame.midY
        panel?.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
