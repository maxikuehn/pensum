import PensumCore
import SwiftUI

/// Das kleine Fenster unter dem Menübar-Symbol.
struct MenuBarView: View {
    let tracker: Tracker
    let updater: Updater
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    private let calculator = DayCalculator()

    /// Schließt das Menübar-Fenster, bevor ein anderes Fenster aufgeht.
    private func closeAndOpen(_ open: () -> Void) {
        NSApplication.shared.keyWindow?.close()
        open()
        NSApplication.shared.activate()
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
                .buttonStyle(PrimaryButtonStyle(kind: tracker.isRunning ? .stop : .start))

                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    UpdateRows(updater: updater)
                    MenuRow(title: "Übersicht", shortcut: "⌘O") {
                        closeAndOpen { openWindow(id: "overview") }
                    }
                    .keyboardShortcut("o")
                    MenuRow(title: "Einstellungen", shortcut: "⌘,") {
                        closeAndOpen { openSettings() }
                    }
                    .keyboardShortcut(",")
                    MenuRow(title: "Pensum beenden", shortcut: "⌘Q") {
                        NSApplication.shared.terminate(nil)
                    }
                    .keyboardShortcut("q")
                }
                .padding(.horizontal, -8)
            }
            .padding(16)
            .frame(width: 280)
        }
    }
}

/// Hinweis auf eine neue Version; aufgeklappt geht es zu den Neuerungen oder direkt zur Installation.
private struct UpdateRows: View {
    let updater: Updater
    @State private var isOpen = false

    var body: some View {
        switch updater.state {
        case .idle:
            EmptyView()
        case .available(let release), .failed(let release):
            let failed = updater.state == .failed(release)
            MenuRow(title: failed ? "Installation fehlgeschlagen" : "Version \(release.version) verfügbar", shortcut: "", marker: .workYellow) {
                withAnimation(.easeInOut(duration: 0.15)) { isOpen.toggle() }
            }
            if isOpen || failed {
                MenuRow(title: "Neuerungen ansehen", shortcut: "", indent: true) {
                    NSApplication.shared.keyWindow?.close()
                    NSWorkspace.shared.open(release.page)
                }
                MenuRow(title: failed ? "Erneut versuchen" : "Jetzt installieren", shortcut: "", indent: true) {
                    updater.install(release)
                }
            }
            Divider().padding(.vertical, 4).padding(.horizontal, 8)
        case .installing(let release):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Version \(release.version) wird installiert")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            Divider().padding(.vertical, 4).padding(.horizontal, 8)
        }
    }
}

/// Eintrag wie in einem Menü, beim Darüberfahren hervorgehoben.
private struct MenuRow: View {
    let title: String
    let shortcut: String
    var marker: Color?
    var indent = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let marker {
                    Circle().fill(marker).frame(width: 7, height: 7)
                }
                Text(title)
                    .padding(.leading, indent ? 15 : 0)
                Spacer()
                Text(shortcut).foregroundStyle(hovered ? .secondary : .tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(hovered ? Color.hoverFill : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

/// Der heutige Tag als schmale Leiste: im eingestellten Zeitraum, breiter, wenn außerhalb gearbeitet wurde.
private struct DayStrip: View {
    let spans: [DaySpan]

    var body: some View {
        let lower = min(TimeWindow.home, (spans.first?.start ?? TimeWindow.home) / 60 * 60)
        let upper = max(TimeWindow.home + TimeWindow.length, ((spans.map(\.end).max() ?? 0) + 59) / 60 * 60)

        GeometryReader { geometry in
            let scale = geometry.size.width / CGFloat(upper - lower)
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                ForEach(spans, id: \.start) { span in
                    Capsule()
                        .fill(Color.workYellow)
                        .frame(width: max(4, CGFloat(span.minutes) * scale))
                        .offset(x: CGFloat(span.start - lower) * scale)
                }
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
