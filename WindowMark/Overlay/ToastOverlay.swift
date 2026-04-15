import AppKit

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
    private let label = NSTextField(labelWithString: "")
    private let backdrop = NSVisualEffectView()
    private var dismissTimer: Timer?

    private init() {
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false

        backdrop.material = .hudWindow
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = 12
        backdrop.layer?.masksToBounds = true

        // Dark scrim on top of the blur
        let scrim = NSView()
        scrim.wantsLayer = true
        scrim.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.65).cgColor
        scrim.translatesAutoresizingMaskIntoConstraints = false
        backdrop.addSubview(scrim)

        backdrop.addSubview(label)
        panel.contentView = backdrop

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor, constant: -20),
            label.topAnchor.constraint(equalTo: backdrop.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor, constant: -10),
            scrim.leadingAnchor.constraint(equalTo: backdrop.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: backdrop.trailingAnchor),
            scrim.topAnchor.constraint(equalTo: backdrop.topAnchor),
            scrim.bottomAnchor.constraint(equalTo: backdrop.bottomAnchor),
        ])
    }

    func show(message: String) {
        dismissTimer?.invalidate()

        label.stringValue = message

        // Size to fit the label
        let labelSize = label.intrinsicContentSize
        let panelSize = NSSize(width: labelSize.width + 40, height: labelSize.height + 20)
        panel.setContentSize(panelSize)

        // Position at top-center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.maxY - panelSize.height - 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 1.0
        panel.orderFrontRegardless()

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
