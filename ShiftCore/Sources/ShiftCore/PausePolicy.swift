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

    /// Ein Block, der noch von einem früheren Tag läuft (Stoppen vergessen, Laptop nie zugeklappt),
    /// endet mit der letzten Aktivität an jenem Tag. Gibt `nil` zurück, wenn der Block von heute ist.
    public func staleEnd(blockStart: Date, lastActivity: Date?, now: Date) -> Date? {
        guard !calendar.isDate(blockStart, inSameDayAs: now) else { return nil }
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: blockStart))!
        return max(blockStart, min(lastActivity ?? blockStart, endOfDay))
    }
}
