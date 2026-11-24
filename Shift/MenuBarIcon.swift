import AppKit

/// Symbol in der Menüleiste: der Rahmen mit Griffen aus der Übersicht,
/// dazu unten rechts ein grüner Punkt, solange die Zeit läuft, und ein oranger während einer Pause.
enum MenuBarIcon {
    enum State {
        case idle
        case running
        case paused
    }

    static func image(_ state: State) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 16), flipped: false) { bounds in
            let dot = NSRect(x: 13, y: 0, width: 6.5, height: 6.5)

            // Rahmen: volle Griffe links und rechts, dünne Kanten oben und unten
            let frame = NSRect(x: 1, y: 3.5, width: 16, height: 9)
            let shape = NSBezierPath(roundedRect: frame, xRadius: 2.5, yRadius: 2.5)
            shape.append(NSBezierPath(rect: NSRect(x: frame.minX + 4, y: frame.minY + 1.5, width: frame.width - 8, height: frame.height - 3)))
            shape.windingRule = .evenOdd

            NSGraphicsContext.saveGraphicsState()
            if state != .idle {
                // Etwas Abstand um den Punkt, damit er sich vom Rahmen abhebt
                let clip = NSBezierPath(rect: bounds)
                clip.append(NSBezierPath(ovalIn: dot.insetBy(dx: -1.25, dy: -1.25)))
                clip.windingRule = .evenOdd
                clip.addClip()
            }
            NSColor.labelColor.setFill()
            shape.fill()
            NSGraphicsContext.restoreGraphicsState()

            guard state != .idle else { return true }
            (state == .running ? NSColor.systemGreen : NSColor.systemOrange).setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = switch state {
        case .idle: "Shift"
        case .running: "Shift, Zeit läuft"
        case .paused: "Shift, Pause"
        }
        return image
    }
}
