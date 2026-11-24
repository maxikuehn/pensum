// Zeichnet das App-Symbol und legt alle Größen in Pensum/Assets.xcassets/AppIcon.appiconset ab.
// Aufruf aus dem Projektordner: swift scripts/make-icon.swift
import AppKit

let yellow = NSColor(srgbRed: 0.965, green: 0.769, blue: 0.192, alpha: 1)

func draw(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let s = size / 1024
        // Grundform nach Apples Raster: 824 × 824 mit Rand
        let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
        let squircle = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
        NSGradient(starting: NSColor(srgbRed: 0.20, green: 0.20, blue: 0.22, alpha: 1),
                   ending: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1))!.draw(in: squircle, angle: -90)

        // Gleiche Form wie das Menüleisten-Symbol (dort 20 × 16 Punkte, oben nach unten),
        // aber ohne Punkt und mit Stundenstrichen über die ganze Breite
        let k: CGFloat = 31, ox: CGFloat = 233, oy: CGFloat = 264
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
            NSRect(x: (ox + x * k) * s, y: (1024 - oy - (y + h) * k) * s, width: w * k * s, height: h * k * s)
        }
        let inner = rect(4.5, 3, 9, 5)
        yellow.withAlphaComponent(0.24).setFill()
        NSBezierPath(rect: inner).fill()
        let frame = NSBezierPath(roundedRect: rect(1, 1.5, 16, 8), xRadius: 2 * k * s, yRadius: 2 * k * s)
        frame.append(NSBezierPath(rect: inner))
        frame.windingRule = .evenOdd
        yellow.setFill()
        frame.fill()

        NSColor.white.withAlphaComponent(0.55).setFill()
        for i in 0...4 {
            let long = i % 2 == 0
            let tick = rect(1.5 + CGFloat(i) * 3.45, long ? 11 : 12.2, 1.2, long ? 3.5 : 2.3)
            NSBezierPath(roundedRect: tick, xRadius: 0.6 * k * s, yRadius: 0.6 * k * s).fill()
        }
        return true
    }
}

let folder = URL(fileURLWithPath: "Pensum/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(size: CGFloat(pixels)).draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: folder.appendingPathComponent("Contents.json"))
try #"{"info":{"author":"xcode","version":1}}"#.data(using: .utf8)!
    .write(to: URL(fileURLWithPath: "Pensum/Assets.xcassets/Contents.json"))
print("App-Symbol erzeugt")
