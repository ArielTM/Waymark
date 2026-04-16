import AppKit

enum CairnIcon {
    /// Menu bar icon: three stacked flat stone slabs with ground line, outline or filled.
    static func menuBarImage(filled: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let ctx = NSGraphicsContext.current!.cgContext

            // Slab geometry — flat rounded rectangles, no taper (top = middle width).
            // Coordinates are CoreGraphics y-up (y=0 at bottom).
            // Converted from spec SVG (y-down): cgY = 18 - svgY - height
            struct Slab {
                let rect: CGRect
                let cornerRadius: CGFloat
                let rotationDegrees: CGFloat  // rotation around slab center
            }

            let slabs = [
                Slab(rect: CGRect(x: 2,   y: 4.0,  width: 14, height: 3.5), cornerRadius: 1.5, rotationDegrees: -2),  // bottom (widest)
                Slab(rect: CGRect(x: 4,   y: 9.3,  width: 10, height: 2.2), cornerRadius: 1.0, rotationDegrees: 3),   // middle (thin spacer)
                Slab(rect: CGRect(x: 4,   y: 13.0, width: 10, height: 3.0), cornerRadius: 1.5, rotationDegrees: -3),  // top (same width as middle)
            ]

            ctx.setLineWidth(1.2)

            for slab in slabs {
                ctx.saveGState()

                // Rotate around the slab's center
                let cx = slab.rect.midX
                let cy = slab.rect.midY
                ctx.translateBy(x: cx, y: cy)
                ctx.rotate(by: slab.rotationDegrees * .pi / 180)
                ctx.translateBy(x: -cx, y: -cy)

                let path = CGPath(
                    roundedRect: slab.rect,
                    cornerWidth: slab.cornerRadius,
                    cornerHeight: slab.cornerRadius,
                    transform: nil
                )

                if filled {
                    ctx.setFillColor(NSColor.black.cgColor)
                    ctx.addPath(path)
                    ctx.fillPath()
                } else {
                    ctx.setStrokeColor(NSColor.black.cgColor)
                    ctx.addPath(path)
                    ctx.strokePath()
                }

                ctx.restoreGState()
            }

            // Ground line — thin horizontal line beneath the stack
            // SVG y=15.5 → CG y = 18 - 15.5 = 2.5
            ctx.setLineWidth(1.0)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.move(to: CGPoint(x: 1, y: 2.5))
            ctx.addLine(to: CGPoint(x: 17, y: 2.5))
            ctx.strokePath()

            return true
        }
        image.isTemplate = true
        return image
    }
}
