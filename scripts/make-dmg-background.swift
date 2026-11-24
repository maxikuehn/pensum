// Zeichnet den Hintergrund für das Fenster der DMG (540 × 340 Punkte) in einfacher und doppelter Auflösung
// und fasst beides zu scripts/dmg/background.tiff zusammen.
// Aufruf aus dem Projektordner: swift scripts/make-dmg-background.swift
import AppKit

let size = NSSize(width: 540, height: 340)
// Mitte der beiden Symbole im Fenster, von oben gemessen
let appCenter = NSPoint(x: 140, y: 140)
let dropCenter = NSPoint(x: 400, y: 140)
let yellow = NSColor(srgbRed: 0.965, green: 0.769, blue: 0.192, alpha: 1)

func draw() {
    let bounds = NSRect(origin: .zero, size: size)

    // Mittleres Graphit: Der Finder beschriftet die Symbole im hellen Modus schwarz, im dunklen weiß,
    // auf diesem Ton bleibt beides lesbar
    NSGradient(colors: [NSColor(srgbRed: 0.53, green: 0.53, blue: 0.57, alpha: 1),
                        NSColor(srgbRed: 0.40, green: 0.40, blue: 0.44, alpha: 1)])!
        .draw(in: bounds, angle: -70)

    // Warmes Licht hinter der App, kühles hinter dem Programme-Ordner
    NSGradient(colors: [yellow.withAlphaComponent(0.55), yellow.withAlphaComponent(0)])!
        .draw(fromCenter: appCenter, radius: 0, toCenter: appCenter, radius: 150, options: [])
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
        .draw(fromCenter: dropCenter, radius: 0, toCenter: dropCenter, radius: 130, options: [])

    // Weiches Licht von oben
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.12), NSColor.white.withAlphaComponent(0)])!
        .draw(fromCenter: NSPoint(x: size.width / 2, y: -60), radius: 0,
              toCenter: NSPoint(x: size.width / 2, y: -60), radius: 300, options: [])

    // Pfeil aus drei Winkeln, nach rechts kräftiger, zwischen den Symbolen
    for i in 0..<3 {
        let x = 246 + CGFloat(i) * 18
        let path = NSBezierPath()
        path.move(to: NSPoint(x: x, y: appCenter.y - 13))
        path.line(to: NSPoint(x: x + 12, y: appCenter.y))
        path.line(to: NSPoint(x: x, y: appCenter.y + 13))
        path.lineWidth = 4.5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        yellow.withAlphaComponent([0.35, 0.65, 1][i]).setStroke()
        path.stroke()
    }

    // Stundenstriche unter den Symbolen wie im App-Symbol, hoch genug, dass keine Statusleiste sie verdeckt
    NSColor.white.withAlphaComponent(0.28).setFill()
    let count = 24
    for i in 0...count {
        let x = 40 + CGFloat(i) * (size.width - 80) / CGFloat(count)
        let long = i % 3 == 0
        let h: CGFloat = long ? 14 : 8
        NSBezierPath(roundedRect: NSRect(x: x - 1, y: 284 - h, width: 2, height: h), xRadius: 1, yRadius: 1).fill()
    }

    // Leichte Vignette, damit der Rand ruhig wirkt
    NSGradient(colors: [NSColor.black.withAlphaComponent(0), NSColor.black.withAlphaComponent(0.22)])!
        .draw(fromCenter: NSPoint(x: size.width / 2, y: size.height / 2), radius: 150,
              toCenter: NSPoint(x: size.width / 2, y: size.height / 2), radius: 380, options: [])
}

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    // Oben-nach-unten-Koordinaten wie im Finder-Fenster
    context.cgContext.translateBy(x: 0, y: size.height)
    context.cgContext.scaleBy(x: 1, y: -1)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let folder = URL(fileURLWithPath: "scripts/dmg", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
let temp = FileManager.default.temporaryDirectory
for (scale, name) in [(1.0, "background.png"), (2.0, "background@2x.png")] {
    try render(scale: scale).representation(using: .png, properties: [:])!.write(to: temp.appendingPathComponent(name))
}
let tiff = Process()
tiff.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
tiff.arguments = ["-cathidpicheck", temp.appendingPathComponent("background.png").path,
                  temp.appendingPathComponent("background@2x.png").path, "-out", folder.appendingPathComponent("background.tiff").path]
try tiff.run()
tiff.waitUntilExit()
print("DMG-Hintergrund erzeugt")
