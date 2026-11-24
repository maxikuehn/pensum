import AppKit
import Observation
import ShiftCore
import SwiftUI

/// Das kleine Fenster am Morgen: erscheint beim ersten Aufklappen eines Arbeitstags oben rechts,
/// ohne den Fokus zu stehlen, solange heute noch keine Zeit erfasst ist.
final class CheckInController {
    private let tracker: Tracker
    private let isVacation: (Date) -> Bool
    private let defaults = UserDefaults.standard
    private var panel: NSPanel?

    /// Wann du heute zum ersten Mal am Laptop warst. Damit startet die Arbeitszeit.
    private var firstActive: Date? {
        get { defaults.object(forKey: "firstActive") as? Date }
        set { defaults.set(newValue, forKey: "firstActive") }
    }

    private var dayOff: Date? {
        get { defaults.object(forKey: "dayOff") as? Date }
        set { defaults.set(newValue, forKey: "dayOff") }
    }

    init(tracker: Tracker, isVacation: @escaping (Date) -> Bool) {
        self.tracker = tracker
        self.isVacation = isVacation
        watchTracker()
    }

    /// Aufgeklappt, entsperrt, zurück aus dem Leerlauf oder App gestartet.
    func userBecameActive(at date: Date) {
        if let first = firstActive, Calendar.current.isDate(first, inSameDayAs: date) {} else {
            firstActive = date
        }
        let policy = CheckInPolicy(workdays: Preferences.workdays)
        let shouldAsk = Preferences.checkInEnabled && !isVacation(date) && policy.shouldAsk(
            now: date,
            hasWorkToday: !tracker.intervals(on: date).isEmpty,
            isRunning: tracker.isRunning,
            dayOff: dayOff
        )
        if shouldAsk || defaults.bool(forKey: "alwaysShowCheckIn") { show() }
    }

    private func show() {
        guard let since = firstActive else { return }
        // Ein noch offenes Fenster von einem früheren Tag durch ein aktuelles ersetzen
        if let panel {
            panel.orderOut(nil)
            self.panel = nil
        }
        let view = CheckInView(
            since: since,
            onStart: { [weak self] in
                self?.tracker.start(at: since)
                self?.hide()
            },
            onLater: { [weak self] in self?.hide() },
            onDayOff: { [weak self] in
                self?.dayOff = .now
                self?.hide()
            }
        )
        let hosting = NSHostingView(rootView: view)
        hosting.setFrameSize(hosting.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.maxX - panel.frame.width - 12, y: frame.maxY - panel.frame.height - 8))
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.2; panel.animator().alphaValue = 1 }
        self.panel = panel
    }

    private func hide() {
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 0 } completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
    }

    /// Wird die Zeit auf anderem Weg gestartet (Menüleiste), verschwindet das Fenster.
    private func watchTracker() {
        withObservationTracking {
            _ = tracker.isRunning
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.tracker.isRunning { self.hide() }
                self.watchTracker()
            }
        }
    }
}

private struct CheckInView: View {
    let since: Date
    let onStart: () -> Void
    let onLater: () -> Void
    let onDayOff: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Arbeitszeit starten?")
                    .font(.headline)
                Text("Aufgeklappt um \(since.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                Button("Heute frei", action: onDayOff)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Später", action: onLater)
                    .buttonStyle(PrimaryButtonStyle(isProminent: false))
                    .frame(width: 76)
                Button("Start", action: onStart)
                    .buttonStyle(PrimaryButtonStyle(isProminent: true))
                    .frame(width: 76)
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
