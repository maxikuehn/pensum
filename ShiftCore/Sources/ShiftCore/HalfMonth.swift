import Foundation

/// Ein Abschnitt der Übersicht: der 1.–15. oder der 16. bis Monatsende.
public struct HalfMonth: Hashable, Sendable {
    public var year: Int
    /// 1 bis 12
    public var month: Int
    /// 1 oder 2
    public var half: Int

    public init(year: Int, month: Int, half: Int) {
        self.year = year
        self.month = month
        self.half = half
    }

    public static func containing(_ date: Date, calendar: Calendar = .current) -> HalfMonth {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return HalfMonth(year: parts.year!, month: parts.month!, half: parts.day! <= 15 ? 1 : 2)
    }

    public func dayNumbers(calendar: Calendar = .current) -> ClosedRange<Int> {
        guard half == 2 else { return 1...15 }
        let first = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        return 16...calendar.range(of: .day, in: .month, for: first)!.count
    }

    public func days(calendar: Calendar = .current) -> [Date] {
        dayNumbers(calendar: calendar).map { calendar.date(from: DateComponents(year: year, month: month, day: $0))! }
    }

    public var next: HalfMonth {
        if half == 1 { return HalfMonth(year: year, month: month, half: 2) }
        return month == 12 ? HalfMonth(year: year + 1, month: 1, half: 1) : HalfMonth(year: year, month: month + 1, half: 1)
    }

    public var previous: HalfMonth {
        if half == 2 { return HalfMonth(year: year, month: month, half: 1) }
        return month == 1 ? HalfMonth(year: year - 1, month: 12, half: 2) : HalfMonth(year: year, month: month - 1, half: 2)
    }
}
