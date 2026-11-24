import AppKit
import CoreGraphics

/// Erkennt Pausen aus Systemereignissen: Zuklappen bzw. Ruhezustand, Bildschirm aus, Sperren
/// und 15 Minuten ohne Maus oder Tastatur. Zurück bist du erst, wenn keiner dieser Zustände mehr gilt.
final class ActivityMonitor {
    private let tracker: Tracker
    private let idleThreshold: TimeInterval = 15 * 60
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

        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.isLocked = true; $0.away() }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.isLocked = false; $0.back() }

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        tick()
        // Erst nach dem Start der App melden, vorher lassen sich keine Fenster zeigen
        Task { @MainActor [weak self] in
            guard let self, !self.isIdle else { return }
            self.onActive(.now)
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
        tracker.closeStaleBlock(now: now)
        guard !isAsleep, !isDisplayAsleep, !isLocked else { return }

        // Sekunden seit der letzten Eingabe über Maus, Trackpad oder Tastatur
        let idle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0)!)
        if idle >= idleThreshold {
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
