// Zeichnet das App-Symbol und legt alle Größen in Shift/Assets.xcassets/AppIcon.appiconset ab.
// Aufruf aus dem Projektordner: swift scripts/make-icon.swift
import AppKit

let yellow = NSColor(srgbRed: 0.965, green: 0.769, blue: 0.192, alpha: 1)
let ink = NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)

func draw(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let s = size / 1024
        // Grundform nach Apples Raster: 824 × 824 mit Rand
        let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
        let squircle = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
        NSGradient(starting: NSColor(srgbRed: 0.20, green: 0.20, blue: 0.22, alpha: 1),
                   ending: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1))!.draw(in: squircle, angle: -90)

        // Rahmen mit Griffen wie in der Übersicht
        let frame = NSRect(x: 232 * s, y: 392 * s, width: 560 * s, height: 240 * s)
        let radius = 44 * s
        let outer = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
        yellow.withAlphaComponent(0.24).setFill()
        outer.fill()

        let handle = 92 * s
        let border = 30 * s
        yellow.setFill()
        NSGraphicsContext.saveGraphicsState()
        outer.addClip()
        NSRect(x: frame.minX, y: frame.minY, width: handle, height: frame.height).fill()
        NSRect(x: frame.maxX - handle, y: frame.minY, width: handle, height: frame.height).fill()
        NSRect(x: frame.minX, y: frame.minY, width: frame.width, height: border).fill()
        NSRect(x: frame.minX, y: frame.maxY - border, width: frame.width, height: border).fill()
        NSGraphicsContext.restoreGraphicsState()

        // Pfeile in den Griffen
        func chevron(centerX: CGFloat, pointsLeft: Bool) {
            let path = NSBezierPath()
            let w = 20 * s, h = 40 * s, cy = frame.midY
            let tip = pointsLeft ? centerX - w / 2 : centerX + w / 2
            let back = pointsLeft ? centerX + w / 2 : centerX - w / 2
            path.move(to: NSPoint(x: back, y: cy + h))
            path.line(to: NSPoint(x: tip, y: cy))
            path.line(to: NSPoint(x: back, y: cy - h))
            path.lineWidth = 17 * s
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            ink.setStroke()
            path.stroke()
        }
        chevron(centerX: frame.minX + handle / 2, pointsLeft: true)
        chevron(centerX: frame.maxX - handle / 2, pointsLeft: false)

        // Stundenstriche darunter
        NSColor.white.withAlphaComponent(0.22).setFill()
        for i in 0...6 {
            let x = frame.minX + CGFloat(i) * frame.width / 6
            NSRect(x: x - 4 * s, y: 300 * s, width: 8 * s, height: (i % 3 == 0 ? 44 : 26) * s).fill()
        }
        return true
    }
}

let folder = URL(fileURLWithPath: "Shift/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
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
    .write(to: URL(fileURLWithPath: "Shift/Assets.xcassets/Contents.json"))
print("App-Symbol erzeugt")
