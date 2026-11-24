import Foundation
import Observation
import OSLog
import ShiftCore
import SwiftData

/// Startet und stoppt die Arbeitszeit, unterbricht sie bei automatisch erkannten Pausen
/// und liefert die Blöcke eines Tages.
@Observable
final class Tracker {
    private let context: ModelContext
    private let policy = PausePolicy()
    private let defaults = UserDefaults.standard
    private(set) var running: WorkBlock?

    /// Seit wann du weg bist (zugeklappt, gesperrt, Leerlauf), solange dadurch ein Block unterbrochen ist.
    /// Wird gespeichert, damit ein Neustart der App die Pause nicht vergisst.
    private(set) var awaySince: Date? {
        didSet { defaults.set(awaySince, forKey: "awaySince") }
    }

    var isRunning: Bool { running != nil }

    init(context: ModelContext) {
        self.context = context
        var descriptor = FetchDescriptor<WorkBlock>(predicate: #Predicate { $0.end == nil })
        descriptor.fetchLimit = 1
        running = (try? context.fetch(descriptor))?.first
        awaySince = defaults.object(forKey: "awaySince") as? Date
    }

    func start(at date: Date = .now) {
        awaySince = nil
        guard running == nil else { return }
        let block = WorkBlock(start: date)
        context.insert(block)
        running = block
        save()
    }

    func stop(at date: Date = .now) {
        awaySince = nil
        guard let block = running else { return }
        block.end = max(date, block.start)
        running = nil
        save()
    }

    /// Du bist weg: Der laufende Block endet zu dem Zeitpunkt, an dem die Pause begann.
    func beginAway(at date: Date) {
        guard let block = running, awaySince == nil else { return }
        block.end = max(date, block.start)
        running = nil
        awaySince = date
        save()
    }

    /// Du bist zurück: je nach Länge der Pause weiterlaufen, neu starten oder (über Nacht) nichts tun.
    func endAway(at date: Date) {
        guard let since = awaySince else { return }
        awaySince = nil
        switch policy.resume(awaySince: since, now: date) {
        case .reopen:
            if let last = latestBlock(), last.end == since {
                last.end = nil
                running = last
                save()
            } else {
                start(at: date)
            }
        case .startNew:
            start(at: date)
        case .none:
            break
        }
    }

    /// Merkt sich, wann du zuletzt aktiv warst, für einen vergessenen Block über Nacht.
    func noteActivity(at date: Date) {
        defaults.set(date, forKey: "lastActivity")
    }

    /// Läuft noch ein Block von einem früheren Tag, endet er mit der letzten Aktivität an jenem Tag.
    func closeStaleBlock(now: Date) {
        guard let block = running,
              let end = policy.staleEnd(blockStart: block.start, lastActivity: defaults.object(forKey: "lastActivity") as? Date, now: now)
        else { return }
        Logger.shift.info("Block vom \(block.start) war noch offen, endet um \(end)")
        stop(at: end)
    }

    func intervals(on day: Date, calendar: Calendar = .current) -> [WorkInterval] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let descriptor = FetchDescriptor<WorkBlock>(
            predicate: #Predicate { $0.start >= start && $0.start < end },
            sortBy: [SortDescriptor(\.start)]
        )
        do {
            return try context.fetch(descriptor).map(\.interval)
        } catch {
            Logger.shift.error("Blöcke konnten nicht geladen werden: \(error)")
            return []
        }
    }

    /// Ersetzt die Blöcke eines Tages durch die bearbeiteten, gerundeten Blöcke aus der Übersicht.
    func replaceBlocks(on day: Date, with spans: [DaySpan], calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let descriptor = FetchDescriptor<WorkBlock>(predicate: #Predicate { $0.start >= start && $0.start < end })
        let old = (try? context.fetch(descriptor)) ?? []
        if let running, old.contains(where: { $0 === running }) {
            self.running = nil
        }
        old.forEach(context.delete)
        for span in spans {
            let block = WorkBlock(
                start: start.addingTimeInterval(TimeInterval(span.start * 60)),
                end: span.isRunning ? nil : start.addingTimeInterval(TimeInterval(span.end * 60))
            )
            context.insert(block)
            if span.isRunning { running = block }
        }
        save()
    }

    private func latestBlock() -> WorkBlock? {
        var descriptor = FetchDescriptor<WorkBlock>(sortBy: [SortDescriptor(\.start, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func save() {
        do {
            try context.save()
        } catch {
            Logger.shift.error("Speichern fehlgeschlagen: \(error)")
        }
    }
}

extension Logger {
    static let shift = Logger(subsystem: "de.maxikuehn.shift", category: "app")
}
