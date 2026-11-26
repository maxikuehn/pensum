import Foundation

/// Ein Abschnitt der Übersicht: ganzer Monat, Monatshälfte oder ISO-Woche (Montag bis Sonntag).
public struct Period: Hashable, Sendable {
    /// Rohwerte dienen als gespeicherte Einstellung.
    public enum Kind: String, CaseIterable, Sendable {
        case month, halfMonth, week
    }

    /// Ein Kalendertag ohne Uhrzeit und Zeitzone.
    public struct Day: Hashable, Sendable {
        public var year: Int
        /// 1 bis 12
        public var month: Int
        public var day: Int

        public init(year: Int, month: Int, day: Int) {
            self.year = year
            self.month = month
            self.day = day
        }
    }

    public let kind: Kind
    /// Erster Tag des Abschnitts
    public let start: Day

    private init(kind: Kind, start: Day) {
        self.kind = kind
        self.start = start
    }

    public static func containing(_ date: Date, kind: Kind, calendar: Calendar = .current) -> Period {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return containing(Day(year: parts.year!, month: parts.month!, day: parts.day!), kind: kind)
    }

    public static func containing(_ day: Day, kind: Kind) -> Period {
        switch kind {
        case .month:
            return Period(kind: kind, start: Day(year: day.year, month: day.month, day: 1))
        case .halfMonth:
            return Period(kind: kind, start: Day(year: day.year, month: day.month, day: day.day <= 15 ? 1 : 16))
        case .week:
            let date = gridDate(day)
            // Wochentag 1 = Sonntag … 7 = Samstag → Abstand zum Montag
            let sinceMonday = (grid.component(.weekday, from: date) + 5) % 7
            return Period(kind: kind, start: gridDay(grid.date(byAdding: .day, value: -sinceMonday, to: date)!))
        }
    }

    /// Anzahl der Tage im Abschnitt
    public var dayCount: Int {
        switch kind {
        case .month: monthLength
        case .halfMonth: start.day == 1 ? 15 : monthLength - 15
        case .week: 7
        }
    }

    /// Letzter Tag des Abschnitts
    public var end: Day { offset(dayCount - 1) }

    /// Tagesanfänge in `calendar`, der Reihe nach.
    public func days(calendar: Calendar = .current) -> [Date] {
        (0..<dayCount).map { Self.date(offset($0), calendar: calendar) }
    }

    public func first(calendar: Calendar = .current) -> Date { Self.date(start, calendar: calendar) }

    public func last(calendar: Calendar = .current) -> Date { Self.date(end, calendar: calendar) }

    public var next: Period { Self.containing(offset(dayCount), kind: kind) }

    public var previous: Period { Self.containing(offset(-1), kind: kind) }

    /// Ob Anfang und Ende im selben Monat liegen (bei Wochen nicht immer).
    public var isWithinOneMonth: Bool { start.year == end.year && start.month == end.month }

    /// Tageszahlen für den Titel, z. B. 16...30
    public var dayNumbers: ClosedRange<Int>? { isWithinOneMonth ? start.day...end.day : nil }

    /// 1 oder 2, nur bei Monatshälften
    public var half: Int? { kind == .halfMonth ? (start.day == 1 ? 1 : 2) : nil }

    /// ISO-Kalenderwoche, nur bei Wochen
    public var weekOfYear: Int? { kind == .week ? Self.grid.component(.weekOfYear, from: Self.gridDate(start)) : nil }

    /// Jahr der ISO-Kalenderwoche (29.12.2025 gehört zur KW 1/2026), nur bei Wochen
    public var yearForWeekOfYear: Int? {
        kind == .week ? Self.grid.component(.yearForWeekOfYear, from: Self.gridDate(start)) : nil
    }

    // MARK: - Tagesrechnung

    /// Gregorianisch in UTC mit ISO-Wochen, unabhängig von den Geräteeinstellungen.
    private static let grid: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()

    private var monthLength: Int {
        Self.grid.range(of: .day, in: .month, for: Self.gridDate(start))!.count
    }

    private func offset(_ days: Int) -> Day {
        Self.gridDay(Self.grid.date(byAdding: .day, value: days, to: Self.gridDate(start))!)
    }

    private static func gridDate(_ day: Day) -> Date {
        grid.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
    }

    private static func gridDay(_ date: Date) -> Day {
        let parts = grid.dateComponents([.year, .month, .day], from: date)
        return Day(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    private static func date(_ day: Day, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
    }
}
