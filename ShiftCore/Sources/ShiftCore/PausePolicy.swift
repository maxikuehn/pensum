import Foundation

/// Was passiert, wenn du nach einer automatisch erkannten Pause zurück bist.
public enum ResumeAction: Equatable, Sendable {
    /// Die Pause war zu kurz, um zu zählen: Der vorige Block läuft einfach weiter.
    case reopen
    /// Echte Pause: Ein neuer Block beginnt.
    case startNew
    /// Die Pause ging über Nacht: Das letzte Zuklappen war Feierabend, es wird nichts gestartet.
    case none
}

/// Regeln für automatisch erkannte Pausen (Zuklappen, Sperren, Leerlauf).
public struct PausePolicy: Sendable {
    public var calendar: Calendar
    /// Kürzere Unterbrechungen werden ignoriert.
    public var minimumPause: TimeInterval

    public init(calendar: Calendar = .current, minimumPause: TimeInterval = 2 * 60) {
        self.calendar = calendar
        self.minimumPause = minimumPause
    }

    public func resume(awaySince: Date, now: Date) -> ResumeAction {
        guard calendar.isDate(awaySince, inSameDayAs: now) else { return .none }
        return now.timeIntervalSince(awaySince) < minimumPause ? .reopen : .startNew
    }

    /// Was mit einem laufenden Block passiert, der an einem früheren Tag begann.
    public enum DayChange: Equatable, Sendable {
        /// Der Block ist von heute.
        case none
        /// Du arbeitest über Mitternacht: Der Block endet um 0:00 und läuft am neuen Tag weiter.
        case split(at: Date)
        /// Der Block wurde vergessen: Er endet mit deiner letzten Aktivität an jenem Tag.
        case end(at: Date)
    }

    public func dayChange(blockStart: Date, lastActivity: Date?, now: Date, userIsActive: Bool) -> DayChange {
        guard !calendar.isDate(blockStart, inSameDayAs: now) else { return .none }
        let midnight = calendar.startOfDay(for: now)
        let startedYesterday = calendar.isDate(blockStart, inSameDayAs: midnight.addingTimeInterval(-1))
        // Nur wer bis eben aktiv war, arbeitet durch; nach einem Neustart am Morgen zählt die Nacht nicht mit
        let activeUntilNow = lastActivity.map { now.timeIntervalSince($0) < 5 * 60 } ?? false
        if userIsActive && activeUntilNow && startedYesterday { return .split(at: midnight) }
        return .end(at: staleEnd(blockStart: blockStart, lastActivity: lastActivity, now: now)!)
    }

    /// Ein Block, der noch von einem früheren Tag läuft (Stoppen vergessen, Laptop nie zugeklappt),
    /// endet mit der letzten Aktivität an jenem Tag. Gibt `nil` zurück, wenn der Block von heute ist.
    public func staleEnd(blockStart: Date, lastActivity: Date?, now: Date) -> Date? {
        guard !calendar.isDate(blockStart, inSameDayAs: now) else { return nil }
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: blockStart))!
        return max(blockStart, min(lastActivity ?? blockStart, endOfDay))
    }
}
