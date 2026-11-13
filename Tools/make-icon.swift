// Draws the Audio Lock app icon and writes an .iconset folder.
// Usage: swift Tools/make-icon.swift <output.iconset>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func symbol(_ name: String, size: CGFloat, weight: NSFont.Weight, color: NSColor = .white) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        .applying(.init(paletteColors: [color]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
}

func draw(_ px: Int) -> Data? {
    let s = CGFloat(px)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Rounded-square background, deep blue gradient (Apple icon grid: 824/1024 body).
    let inset = s * 0.0977
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(starting: NSColor(red: 0.20, green: 0.45, blue: 1.0, alpha: 1),
               ending: NSColor(red: 0.10, green: 0.16, blue: 0.55, alpha: 1))?.draw(in: path, angle: -90)

    // Large white headphones filling the icon.
    if let phones = symbol("headphones", size: s * 0.52, weight: .semibold) {
        let sz = phones.size
        phones.draw(in: NSRect(x: (s - sz.width) / 2, y: (s - sz.height) / 2,
                               width: sz.width, height: sz.height))
    }
    // Orange lock in the middle, between the ear cups.
    if let lock = symbol("lock.fill", size: s * 0.20, weight: .bold, color: NSColor(red: 1.0, green: 0.66, blue: 0.0, alpha: 1)) {
        let sz = lock.size
        lock.draw(in: NSRect(x: (s - sz.width) / 2, y: (s - sz.height) / 2 - s * 0.03,
                             width: sz.width, height: sz.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try draw(base * scale)?.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
    }
}
print("Wrote \(out)")
