import AppKit
import SwiftUI

extension Color {
    /// Das Gelb der Arbeitszeit, wie im Entwurf der Übersicht.
    static let workYellow = Color(red: 0.965, green: 0.769, blue: 0.192)
    static let workYellowFill = workYellow.opacity(0.26)

    static let track = dynamic(light: rgb(0xD6D6DC), dark: rgb(0x3B3B42))
    static let gridLine = dynamic(light: rgb(0xFFFFFF), dark: rgb(0x232327))
    static let hatch = dynamic(light: rgb(0x3C3C43, 0.28), dark: rgb(0xEBEBF5, 0.26))
    static let dangerRed = dynamic(light: rgb(0xE0342A), dark: rgb(0xFF6B61))
    static let dangerFill = dynamic(light: rgb(0xFF453A, 0.14), dark: rgb(0xFF453A, 0.22))
    static let hoverFill = dynamic(light: rgb(0x3C3C43, 0.08), dark: rgb(0xEBEBF5, 0.10))
    static let todayFill = workYellow.opacity(0.10)
    /// Schrift für den heutigen Tag: Gelb ist auf Hell zu blass, dort ein dunkleres Bernstein
    static let todayText = dynamic(light: rgb(0xB27600), dark: rgb(0xF6C431))

    /// Farben der Nebenprojekte
    static let project: [Color] = [
        dynamic(light: rgb(0x3A7FF6), dark: rgb(0x5A9BFF)),
        dynamic(light: rgb(0xA259E6), dark: rgb(0xBF80FF)),
        dynamic(light: rgb(0x1FA79A), dark: rgb(0x3CC9B8)),
        dynamic(light: rgb(0xE0528A), dark: rgb(0xFF6FA5)),
    ]

    static func project(_ index: Int) -> Color { project[index % project.count] }

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    private static func rgb(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// Großer Knopf: gelb zum Starten, rot zum Stoppen, neutral für alles andere.
struct PrimaryButtonStyle: ButtonStyle {
    enum Kind {
        case start
        case stop
        case neutral
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        let fill: AnyShapeStyle = switch kind {
        case .start: AnyShapeStyle(Color.workYellow)
        case .stop: AnyShapeStyle(Color.dangerRed)
        case .neutral: AnyShapeStyle(.quaternary)
        }
        let text: Color = switch kind {
        case .start: .black.opacity(0.85)
        case .stop: .white
        case .neutral: .primary
        }
        return configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .foregroundStyle(text)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(fill))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Rectangle())
    }
}

/// Schraffur für Pausen, wie im Entwurf.
struct Hatch: View {
    var color: Color = .hatch
    var spacing: CGFloat = 6
    var lineWidth: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += spacing
            }
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
    }
}

/// Kleine Insel mit Palme für Urlaub (16 × 16, aus dem Entwurf übernommen).
nonisolated struct PalmShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 16
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }

        var path = Path()
        // Insel
        path.move(to: p(1.5, 14.5))
        path.addCurve(to: p(7.8, 12), control1: p(3.1, 12.8), control2: p(5.3, 12))
        path.addCurve(to: p(14.1, 14.5), control1: p(10.3, 12), control2: p(12.5, 12.8))
        path.closeSubpath()
        // Blätter
        let leaves: [(CGPoint, CGPoint, CGPoint, CGPoint, CGPoint, CGPoint)] = [
            (p(4.8, 3.6), p(2.8, 3.4), p(1.3, 4.5), p(3.1, 4.6), p(4.5, 5.0), p(6.4, 5.2)),
            (p(6.8, 3.2), p(8.4, 1.9), p(10.4, 2.0), p(8.9, 2.7), p(7.7, 3.7), p(6.4, 5.2)),
            (p(8.4, 4.3), p(10.7, 4.7), p(12.2, 6.3), p(10.3, 5.9), p(8.5, 5.6), p(6.4, 5.2)),
            (p(4.4, 5.0), p(2.8, 6.0), p(2.1, 7.8), p(3.3, 6.7), p(4.8, 5.9), p(6.4, 5.2)),
        ]
        for leaf in leaves {
            path.move(to: p(6.4, 5.2))
            path.addCurve(to: leaf.2, control1: leaf.0, control2: leaf.1)
            path.addCurve(to: leaf.5, control1: leaf.3, control2: leaf.4)
            path.closeSubpath()
        }
        // Stamm
        var trunk = Path()
        trunk.move(to: p(8.8, 12.3))
        trunk.addCurve(to: p(6.4, 5.2), control1: p(8.7, 9.4), control2: p(7.9, 7.1))
        path.addPath(trunk.strokedPath(StrokeStyle(lineWidth: 1.4 * s, lineCap: .round)))
        return path
    }
}
