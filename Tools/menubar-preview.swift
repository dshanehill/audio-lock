// Renders the menu bar icon (on and off) at 4x so it can be checked: swift Tools/menubar-preview.swift out.png
import AppKit
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "menubar-preview.png"
func menuBarIcon(locked: Bool) -> NSImage {
    let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let body = rect.insetBy(dx: 0.5, dy: 0.5)
            let path = NSBezierPath(roundedRect: body, xRadius: body.width * 0.24, yRadius: body.width * 0.24)
            let top = locked ? NSColor(red: 0.20, green: 0.45, blue: 1.0, alpha: 1) : NSColor(white: 0.55, alpha: 1)
            let bottom = locked ? NSColor(red: 0.10, green: 0.16, blue: 0.55, alpha: 1) : NSColor(white: 0.35, alpha: 1)
            NSGradient(starting: top, ending: bottom)?.draw(in: path, angle: -90)

            func symbol(_ name: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor) -> NSImage? {
                let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
                    .applying(.init(paletteColors: [color]))
                return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
            }
            if let phones = symbol("headphones", side * 0.62, .bold, .white) {
                let s = phones.size
                phones.draw(in: NSRect(x: (rect.width - s.width) / 2, y: (rect.height - s.height) / 2,
                                       width: s.width, height: s.height))
            }
            if locked, let lockImage = symbol("lock.fill", side * 0.30, .heavy,
                                              NSColor(red: 1.0, green: 0.66, blue: 0.0, alpha: 1)) {
                let s = lockImage.size
                lockImage.draw(in: NSRect(x: (rect.width - s.width) / 2, y: (rect.height - s.height) / 2 - side * 0.05,
                                          width: s.width, height: s.height))
            }
            return true
        }
    return image
}
let scale = 4
let w = 18 * 2 + 12, h = 18
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w * scale, pixelsHigh: h * scale + 8 * scale, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: w, height: h + 8)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(white: 0.93, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: w, height: h + 8).fill()
menuBarIcon(locked: true).draw(in: NSRect(x: 3, y: 4, width: 18, height: 18))
menuBarIcon(locked: false).draw(in: NSRect(x: 27, y: 4, width: 18, height: 18))
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
