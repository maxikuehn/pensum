import Foundation
import Testing
@testable import PensumCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
}()

private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
}

private func period(_ kind: Period.Kind, _ year: Int, _ month: Int, _ day: Int) -> Period {
    Period.containing(date(year, month, day), kind: kind, calendar: calendar)
}

private func day(_ year: Int, _ month: Int, _ day: Int) -> Period.Day {
    Period.Day(year: year, month: month, day: day)
}

// MARK: - Monat

@Test func monthStartsOnTheFirst() {
    let november = period(.month, 2026, 11, 24)
    #expect(november.start == day(2026, 11, 1))
    #expect(november.end == day(2026, 11, 30))
    #expect(november.dayNumbers == 1...30)
    #expect(november.isWithinOneMonth)
    #expect(november.half == nil)
    #expect(november.weekOfYear == nil)
}

@Test(arguments: [(2026, 1, 31), (2026, 2, 28), (2028, 2, 29), (2026, 4, 30), (2026, 12, 31)])
func monthEndsWithItsLastDay(year: Int, month: Int, length: Int) {
    let month = period(.month, year, month, 10)
    #expect(month.dayCount == length)
    #expect(month.days(calendar: calendar).count == length)
    #expect(month.end.day == length)
}

@Test func monthPagingCrossesYears() {
    let december = period(.month, 2026, 12, 5)
    #expect(december.next == period(.month, 2027, 1, 1))
    #expect(december.next.previous == december)
    #expect(period(.month, 2026, 1, 31).previous == period(.month, 2025, 12, 1))
    #expect(period(.month, 2028, 2, 29).next == period(.month, 2028, 3, 1))
}

// MARK: - Monatshälfte

@Test func halfMonthSplitsAfterTheFifteenth() {
    #expect(period(.halfMonth, 2026, 11, 1).start == day(2026, 11, 1))
    #expect(period(.halfMonth, 2026, 11, 15).start == day(2026, 11, 1))
    #expect(period(.halfMonth, 2026, 11, 16).start == day(2026, 11, 16))
    #expect(period(.halfMonth, 2026, 11, 15).half == 1)
    #expect(period(.halfMonth, 2026, 11, 16).half == 2)
}

@Test func halfMonthBoundaryFollowsTheCalendarsTimeZone() {
    // 15. kurz vor Mitternacht und 16. direkt danach
    #expect(Period.containing(date(2026, 11, 15, hour: 23), kind: .halfMonth, calendar: calendar).half == 1)
    #expect(Period.containing(date(2026, 11, 16, hour: 0), kind: .halfMonth, calendar: calendar).half == 2)
}

@Test(arguments: [(2026, 1, 16), (2026, 2, 13), (2028, 2, 14), (2026, 4, 15), (2026, 12, 16)])
func secondHalfRunsToTheMonthEnd(year: Int, month: Int, count: Int) {
    let first = period(.halfMonth, year, month, 3)
    let second = period(.halfMonth, year, month, 20)
    #expect(first.dayCount == 15)
    #expect(first.dayNumbers == 1...15)
    #expect(second.dayCount == count)
    #expect(second.dayNumbers == 16...(15 + count))
    #expect(second.days(calendar: calendar).count == count)
}

@Test func halfMonthPagingCrossesMonthsAndYears() {
    let lateDecember = period(.halfMonth, 2026, 12, 20)
    #expect(lateDecember.next == period(.halfMonth, 2027, 1, 1))
    #expect(lateDecember.next.previous == lateDecember)
    #expect(period(.halfMonth, 2026, 11, 3).previous == period(.halfMonth, 2026, 10, 20))
    #expect(period(.halfMonth, 2026, 11, 3).next == period(.halfMonth, 2026, 11, 16))
    #expect(period(.halfMonth, 2028, 2, 16).next == period(.halfMonth, 2028, 3, 1))
}

// MARK: - Woche

@Test func weekStartsOnMonday() {
    // Donnerstag, 26.11.2026
    let week = period(.week, 2026, 11, 26)
    #expect(week.start == day(2026, 11, 23))
    #expect(week.end == day(2026, 11, 29))
    #expect(week.weekOfYear == 48)
    #expect(week.yearForWeekOfYear == 2026)
    #expect(week.dayNumbers == 23...29)
    #expect(week.half == nil)
    // Sonntag gehört noch zur selben Woche, Montag beginnt die nächste
    #expect(period(.week, 2026, 11, 29) == week)
    #expect(period(.week, 2026, 11, 30) == week.next)
}

@Test func weekIgnoresTheCalendarsFirstWeekday() {
    var american = calendar
    american.firstWeekday = 1
    american.minimumDaysInFirstWeek = 1
    let week = Period.containing(date(2026, 11, 29), kind: .week, calendar: american)
    #expect(week.start == day(2026, 11, 23))
    #expect(week.weekOfYear == 48)
}

@Test func weekCrossesTheYearBoundary() {
    let week = period(.week, 2026, 1, 1)
    #expect(week.start == day(2025, 12, 29))
    #expect(week.end == day(2026, 1, 4))
    #expect(week.weekOfYear == 1)
    #expect(week.yearForWeekOfYear == 2026)
    #expect(!week.isWithinOneMonth)
    #expect(week.dayNumbers == nil)
    #expect(week.previous.weekOfYear == 52)
    #expect(week.previous.start == day(2025, 12, 22))
}

@Test func weekFiftyThreeExists() {
    // 2026 beginnt an einem Donnerstag und hat 53 Wochen
    let week = period(.week, 2026, 12, 31)
    #expect(week.start == day(2026, 12, 28))
    #expect(week.weekOfYear == 53)
    #expect(week.next.start == day(2027, 1, 4))
    #expect(week.next.weekOfYear == 1)
}

@Test func weekPagingCrossesMonths() {
    let week = period(.week, 2026, 11, 26)
    #expect(week.next.start == day(2026, 11, 30))
    #expect(week.next.end == day(2026, 12, 6))
    #expect(!week.next.isWithinOneMonth)
    #expect(week.next.previous == week)
    #expect(period(.week, 2028, 2, 29).start == day(2028, 2, 28))
    #expect(period(.week, 2028, 2, 29).end == day(2028, 3, 5))
}

// MARK: - Tage

@Test(arguments: Period.Kind.allCases)
func daysAreConsecutiveStartsOfDay(kind: Period.Kind) {
    // Enthält die Umstellung auf Winterzeit am 25.10.2026
    let period = period(kind, 2026, 10, 25)
    let days = period.days(calendar: calendar)
    #expect(days.count == period.dayCount)
    #expect(days.first == period.first(calendar: calendar))
    #expect(days.last == period.last(calendar: calendar))
    for (index, day) in days.enumerated() {
        #expect(day == calendar.startOfDay(for: day))
        if index > 0 { #expect(calendar.dateComponents([.day], from: days[index - 1], to: day).day == 1) }
    }
}

@Test func dayCountPerKind() {
    #expect(period(.month, 2026, 11, 26).dayCount == 30)
    #expect(period(.halfMonth, 2026, 11, 26).dayCount == 15)
    #expect(period(.week, 2026, 11, 26).dayCount == 7)
}

@Test func kindRawValuesStayStable() {
    #expect(Period.Kind.allCases.map(\.rawValue) == ["month", "halfMonth", "week"])
}
