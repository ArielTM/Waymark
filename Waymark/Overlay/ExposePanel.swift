import AppKit
import SwiftUI

final class ExposePanel: NSPanel {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        isOpaque = false
        backgroundColor = NSColor.black.withAlphaComponent(0.75)
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class ExposePanelController {
    static let shared = ExposePanelController()

    private var panel: ExposePanel?
    private var hasPromptedScreenRecording = false

    private init() {}

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func show(watchlistManager: WatchlistManager) {
        guard !watchlistManager.targets.isEmpty else { return }

        dismiss()

        guard let screen = NSScreen.main else { return }
        let exposePanel = ExposePanel(screen: screen)

        let exposeView = ExposeView(
            watchlistManager: watchlistManager,
            dismiss: { [weak self] in self?.dismiss() },
            onThumbnailsFailed: { [weak self] in
                self?.promptScreenRecordingIfNeeded()
            }
        )

        let hostingView = NSHostingView(rootView: exposeView)
        hostingView.sizingOptions = .intrinsicContentSize
        hostingView.frame = screen.frame
        exposePanel.contentView = hostingView

        exposePanel.makeKeyAndOrderFront(nil)
        NSApp.activate()

        self.panel = exposePanel

        // Refresh titles in place while the panel is visible — cached titles
        // render instantly, fresh ones arrive ~50–200ms later.
        Task { await watchlistManager.refreshAllTitles() }
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func promptScreenRecordingIfNeeded() {
        guard !hasPromptedScreenRecording else { return }
        hasPromptedScreenRecording = true

        // Dismiss the exposé panel first so the alert is visible
        dismiss()

        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission"
        alert.informativeText = "Waymark needs Screen Recording permission to show window thumbnails in the Exposé panel.\n\nWithout it, app icons will be shown as placeholders."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Continue Without Thumbnails")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
