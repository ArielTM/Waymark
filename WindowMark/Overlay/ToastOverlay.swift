import AppKit
import SwiftUI

// MARK: - Toast SwiftUI View

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.black.opacity(0.85))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

// MARK: - Toast Panel (NSPanel subclass)

final class ToastPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isReleasedWhenClosed = false
    }
}

// MARK: - Toast Overlay Controller

@MainActor
final class ToastOverlay {
    static let shared = ToastOverlay()

    private let panel = ToastPanel()
    private var dismissTimer: Timer?

    private init() {}

    func show(message: String) {
        // Cancel any existing dismiss timer
        dismissTimer?.invalidate()

        // Set content
        let hostingView = NSHostingView(rootView: ToastView(message: message))
        hostingView.frame.size = hostingView.fittingSize
        panel.contentView = hostingView
        panel.setContentSize(hostingView.fittingSize)

        // Position at top-center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - hostingView.fittingSize.width / 2
            let y = screenFrame.maxY - hostingView.fittingSize.height - 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Show with full opacity
        panel.alphaValue = 1.0
        panel.orderFrontRegardless()

        // Schedule auto-dismiss
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dismiss()
            }
        }
    }

    private func dismiss() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }
}
