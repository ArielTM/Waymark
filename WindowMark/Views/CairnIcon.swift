import AppKit

enum CairnIcon {
    /// Menu bar icon: three stacked ovals, outline or filled.
    static func menuBarImage(filled: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let ctx = NSGraphicsContext.current!.cgContext

            // Three ovals stacked: small on top, large on bottom
            // Positioned within 18x18, vertically centered
            struct Stone {
                let cx: CGFloat
                let cy: CGFloat
                let rx: CGFloat  // horizontal radius
                let ry: CGFloat  // vertical radius
            }

            let stones = [
                Stone(cx: 9, cy: 13.5, rx: 3.5, ry: 2.2),  // top (smallest)
                Stone(cx: 9, cy: 9.0,  rx: 5.0, ry: 2.5),  // middle
                Stone(cx: 9, cy: 4.5,  rx: 6.5, ry: 2.8),  // bottom (largest)
            ]

            ctx.setLineWidth(1.2)

            for stone in stones {
                let oval = CGRect(
                    x: stone.cx - stone.rx,
                    y: stone.cy - stone.ry,
                    width: stone.rx * 2,
                    height: stone.ry * 2
                )
                if filled {
                    ctx.setFillColor(NSColor.black.cgColor)
                    ctx.fillEllipse(in: oval)
                } else {
                    ctx.setStrokeColor(NSColor.black.cgColor)
                    ctx.strokeEllipse(in: oval)
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
