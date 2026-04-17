import AppKit

// Pure AppKit pill view: orange dot + mark count on a blurred rounded pill.
// Kept AppKit-only to avoid the NSHostingView constraint-crash pattern seen in
// other HUD panels (see rejected-approaches §AppKit + SwiftUI Integration).
final class PalettePillView: NSView {
    static let height: CGFloat = 20

    private let effect: NSVisualEffectView
    private let dot: NSView
    private let label: NSTextField

    private(set) var count: Int = 0

    override init(frame frameRect: NSRect) {
        effect = NSVisualEffectView(frame: .zero)
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = Self.height / 2
        effect.layer?.masksToBounds = true

        dot = NSView(frame: .zero)
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.systemOrange.cgColor
        dot.layer?.cornerRadius = 3

        label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .left
        label.backgroundColor = .clear
        label.isBordered = false
        label.drawsBackground = false

        super.init(frame: frameRect)
        wantsLayer = true
        addSubview(effect)
        effect.addSubview(dot)
        effect.addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func setCount(_ n: Int) {
        guard n != count else { return }
        count = n
        label.stringValue = "\(n)"
        needsLayout = true
    }

    override var intrinsicContentSize: NSSize {
        label.sizeToFit()
        let textWidth = label.frame.width
        // 6 leading pad + 6 dot + 5 gap + text + 8 trailing pad
        let width = max(32, 6 + 6 + 5 + textWidth + 8)
        return NSSize(width: width, height: Self.height)
    }

    override func layout() {
        super.layout()
        effect.frame = bounds
        let dotSize: CGFloat = 6
        let dotY = (bounds.height - dotSize) / 2
        dot.frame = NSRect(x: 6, y: dotY, width: dotSize, height: dotSize)
        label.sizeToFit()
        let labelY = (bounds.height - label.frame.height) / 2
        label.frame = NSRect(x: 6 + dotSize + 5, y: labelY,
                             width: label.frame.width, height: label.frame.height)
    }
}
