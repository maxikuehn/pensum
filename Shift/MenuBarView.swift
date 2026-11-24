import ShiftCore
import SwiftUI

/// Das kleine Fenster unter dem Menübar-Symbol.
struct MenuBarView: View {
    let tracker: Tracker
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    private let calculator = DayCalculator()

    private func menuRow(_ title: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(shortcut).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let spans = calculator.spans(of: tracker.intervals(on: now), on: now, now: now)
            let total = spans.reduce(0) { $0 + $1.minutes }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Heute")
                    Spacer()
                    Text(now, format: .dateTime.weekday(.abbreviated).day().month(.twoDigits))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text("\(HoursFormat.decimal(total)) h")
                    .font(.system(size: 34, weight: .semibold))
                    .monospacedDigit()

                DayStrip(spans: spans)

                Button(tracker.isRunning ? "Stopp" : "Start") {
                    tracker.isRunning ? tracker.stop() : tracker.start()
                }
                .buttonStyle(PrimaryButtonStyle(isProminent: !tracker.isRunning))

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    menuRow("Übersicht", shortcut: "⌘O") {
                        openWindow(id: "overview")
                        NSApplication.shared.activate()
                    }
                    .keyboardShortcut("o")
                    menuRow("Einstellungen", shortcut: "⌘,") {
                        openSettings()
                        NSApplication.shared.activate()
                    }
                    .keyboardShortcut(",")
                    menuRow("Shift beenden", shortcut: "⌘Q") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q")
                }
            }
            .padding(16)
            .frame(width: 280)
        }
    }
}

/// Der heutige Tag als schmale Leiste: standardmäßig 7–20 Uhr, breiter, wenn außerhalb gearbeitet wurde.
private struct DayStrip: View {
    let spans: [DaySpan]

    var body: some View {
        let lower = min(7 * 60, (spans.first?.start ?? 7 * 60) / 60 * 60)
        let upper = max(20 * 60, ((spans.map(\.end).max() ?? 0) + 59) / 60 * 60)

        GeometryReader { geometry in
            let scale = geometry.size.width / CGFloat(upper - lower)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                ForEach(spans, id: \.start) { span in
                    Capsule()
                        .fill(Color.shiftYellow)
                        .frame(width: max(4, CGFloat(span.minutes) * scale))
                        .offset(x: CGFloat(span.start - lower) * scale)
                }
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
