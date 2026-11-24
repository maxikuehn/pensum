import AppKit
import CoreGraphics

/// Erkennt Pausen aus Systemereignissen: Zuklappen bzw. Ruhezustand, Bildschirm aus, Sperren
/// und eine einstellbare Zeit ohne Maus oder Tastatur (Standard 15 Minuten). Zurück bist du erst, wenn keiner dieser Zustände mehr gilt.
final class ActivityMonitor {
    private let tracker: Tracker
    private var isAsleep = false
    private var isDisplayAsleep = false
    private var isLocked = false
    private var isIdle = false
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var timer: Timer?
    /// Meldet, wann du wieder am Laptop bist: aufgeklappt, entsperrt oder zurück aus dem Leerlauf.
    private let onActive: (Date) -> Void

    init(tracker: Tracker, onActive: @escaping (Date) -> Void) {
        self.tracker = tracker
        self.onActive = onActive

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { $0.isAsleep = true; $0.away() }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.isAsleep = false; $0.back() }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.isDisplayAsleep = true; $0.away() }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.isDisplayAsleep = false; $0.back() }
        // Herunterfahren, Neustart oder Abmelden: laufenden Block pausieren
        observe(workspace, NSWorkspace.willPowerOffNotification) { $0.away() }

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.isLocked = true; $0.away() }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.isLocked = false; $0.back() }

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Wurde die App ohne Abmeldung beendet (Absturz, Strom weg), gilt die Zeit seit der letzten Aktivität als Pause
        tracker.recoverAfterLaunch(now: .now)
        tick()
        // Erst nach dem Start der App melden, vorher lassen sich keine Fenster zeigen.
        // Wie beim Aufklappen: am selben Tag geht es nach der Pause weiter, sonst fragt das Fenster am Morgen.
        Task { @MainActor [weak self] in
            self?.back()
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ handle: @escaping @MainActor @Sendable (ActivityMonitor) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handle(self)
            }
        }
        observers.append((center, token))
    }

    private func away(at date: Date = .now) {
        tracker.beginAway(at: date)
    }

    private func back(at date: Date = .now) {
        guard !isAsleep, !isDisplayAsleep, !isLocked, !isIdle else { return }
        tracker.endAway(at: date)
        onActive(date)
    }

    private func tick() {
        let now = Date.now
        let awake = !isAsleep && !isDisplayAsleep && !isLocked
        // Sekunden seit der letzten Eingabe über Maus, Trackpad oder Tastatur
        let idle = awake ? CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!) : .infinity
        let threshold = TimeInterval(Preferences.idleMinutes * 60)
        tracker.handleDayChange(now: now, userIsActive: idle < threshold)
        guard awake else { return }

        if idle >= threshold {
            if !isIdle {
                isIdle = true
                away(at: now.addingTimeInterval(-idle))
            }
        } else {
            tracker.noteActivity(at: now)
            if isIdle {
                isIdle = false
                back(at: now.addingTimeInterval(-idle))
            }
        }
    }
}
