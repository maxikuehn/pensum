import Foundation

/// Entscheidet, ob morgens gefragt wird, ob die Arbeitszeit starten soll.
public struct CheckInPolicy: Sendable {
    public var calendar: Calendar
    /// Wochentage nach `Calendar`-Zählung (1 = Sonntag … 7 = Samstag), an denen gefragt wird.
    public var workdays: Set<Int>

    public init(calendar: Calendar = .current, workdays: Set<Int> = [2, 3, 4, 5, 6]) {
        self.calendar = calendar
        self.workdays = workdays
    }

    /// Gefragt wird an Arbeitstagen, solange heute weder Zeit erfasst noch „Heute frei“ gewählt wurde.
    public func shouldAsk(now: Date, hasWorkToday: Bool, isRunning: Bool, dayOff: Date?) -> Bool {
        guard workdays.contains(calendar.component(.weekday, from: now)) else { return false }
        if hasWorkToday || isRunning { return false }
        if let dayOff, calendar.isDate(dayOff, inSameDayAs: now) { return false }
        return true
    }
}
