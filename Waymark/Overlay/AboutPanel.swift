import AppKit
import SwiftUI

// MARK: - About Panel (NSPanel subclass)

final class AboutPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        title = "About Waymark"
        level = .floating
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
}

// MARK: - About Panel Controller

@MainActor
final class AboutPanelController {
    static let shared = AboutPanelController()

    private var panel: AboutPanel?

    private init() {}

    func show() {
        if let panel, panel.isVisible {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let panel = AboutPanel()

        let aboutView = AboutView(dismiss: { [weak self] in self?.dismiss() })
        let hostingView = NSHostingView(rootView: aboutView)
        hostingView.sizingOptions = .intrinsicContentSize
        panel.contentView = hostingView

        panel.center()
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}
