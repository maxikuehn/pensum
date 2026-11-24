import AppKit

/// Symbol in der Menüleiste: kleiner Rahmen mit Griffen über Stundenstrichen,
/// dazu unten rechts ein Punkt: grün, solange die Zeit läuft, orange während einer Pause, sonst rot.
enum MenuBarIcon {
    enum State {
        case idle
        case running
        case paused
    }

    static func image(_ state: State) -> NSImage {
        // In oben-nach-unten-Koordinaten gezeichnet (20 × 16 Punkte)
        let image = NSImage(size: NSSize(width: 20, height: 16), flipped: true) { bounds in
            let dot = NSRect(x: 13, y: 9.5, width: 6.5, height: 6.5)

            // Kleiner Rahmen mit Griffen, darunter Stundenstriche wie im App-Symbol
            let frame = NSRect(x: 1, y: 1.5, width: 16, height: 8)
            let shape = NSBezierPath(roundedRect: frame, xRadius: 2, yRadius: 2)
            shape.append(NSBezierPath(rect: NSRect(x: 4.5, y: 3, width: 9, height: 5)))
            shape.windingRule = .evenOdd
            for tick in [NSRect(x: 1.5, y: 11, width: 1.2, height: 3.5),
                         NSRect(x: 5.6, y: 12.2, width: 1.2, height: 2.3),
                         NSRect(x: 9.6, y: 11, width: 1.2, height: 3.5)] {
                shape.append(NSBezierPath(roundedRect: tick, xRadius: 0.6, yRadius: 0.6))
            }

            NSGraphicsContext.saveGraphicsState()
            // Etwas Abstand um den Punkt, damit er sich vom Rest abhebt
            let clip = NSBezierPath(rect: bounds)
            clip.append(NSBezierPath(ovalIn: dot.insetBy(dx: -1.35, dy: -1.35)))
            clip.windingRule = .evenOdd
            clip.addClip()
            NSColor.labelColor.setFill()
            shape.fill()
            NSGraphicsContext.restoreGraphicsState()

            let color: NSColor = switch state {
            case .idle: .systemRed
            case .running: .systemGreen
            case .paused: .systemOrange
            }
            color.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = switch state {
        case .idle: "Pensum, Zeit läuft nicht"
        case .running: "Pensum, Zeit läuft"
        case .paused: "Pensum, Pause"
        }
        return image
    }
}
