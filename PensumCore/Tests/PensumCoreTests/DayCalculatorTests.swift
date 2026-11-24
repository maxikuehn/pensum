import Foundation
import Testing
@testable import PensumCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
}()

private let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 24))!

/// Zeitpunkt am Testtag, z. B. `at("8:07")` oder `at("8:07:30")`.
private func at(_ time: String) -> Date {
    let parts = time.split(separator: ":").map { Int($0)! }
    return calendar.date(bySettingHour: parts[0], minute: parts[1], second: parts.count > 2 ? parts[2] : 0, of: day)!
}

private func minutes(_ time: String) -> Int {
    let parts = time.split(separator: ":").map { Int($0)! }
    return parts[0] * 60 + parts[1]
}

private let calculator = DayCalculator(calendar: calendar)

@Test func roundsInFavourOfTheUser() {
    let spans = calculator.spans(of: [WorkInterval(start: at("8:07"), end: at("12:11"))], on: day, now: at("18:00"))
    #expect(spans == [DaySpan(start: minutes("8:05"), end: minutes("12:15"))])
}

@Test func secondsCountTowardsRounding() {
    let spans = calculator.spans(of: [WorkInterval(start: at("8:05:30"), end: at("12:10:01"))], on: day, now: at("18:00"))
    #expect(spans == [DaySpan(start: minutes("8:05"), end: minutes("12:15"))])
}

@Test func exactFiveMinuteMarksStayUnchanged() {
    let spans = calculator.spans(of: [WorkInterval(start: at("8:00"), end: at("12:00"))], on: day, now: at("18:00"))
    #expect(spans == [DaySpan(start: minutes("8:00"), end: minutes("12:00"))])
}

@Test func runningBlockEndsAtNowRoundedUp() {
    let spans = calculator.spans(of: [WorkInterval(start: at("8:03"))], on: day, now: at("11:24"))
    #expect(spans == [DaySpan(start: minutes("8:00"), end: minutes("11:25"), isRunning: true)])
}

@Test func blocksThatTouchAfterRoundingAreJoined() {
    // 10:41 → 10:45 und 10:43 → 10:40: die kurze Pause verschwindet durch das Runden
    let intervals = [
        WorkInterval(start: at("8:03"), end: at("10:41")),
        WorkInterval(start: at("10:43"), end: at("12:00")),
    ]
    let spans = calculator.spans(of: intervals, on: day, now: at("18:00"))
    #expect(spans == [DaySpan(start: minutes("8:00"), end: minutes("12:00"))])
}

@Test func pausesStaySeparateAndAreSortedByStart() {
    let intervals = [
        WorkInterval(start: at("12:56"), end: at("17:38")),
        WorkInterval(start: at("8:07"), end: at("12:11")),
    ]
    let spans = calculator.spans(of: intervals, on: day, now: at("18:00"))
    #expect(spans == [
        DaySpan(start: minutes("8:05"), end: minutes("12:15")),
        DaySpan(start: minutes("12:55"), end: minutes("17:40")),
    ])
    #expect(calculator.totalMinutes(of: intervals, on: day, now: at("18:00")) == 250 + 285)
}

@Test func blocksOfOtherDaysAreIgnored() {
    let yesterday = calendar.date(byAdding: .day, value: -1, to: at("9:00"))!
    let intervals = [
        WorkInterval(start: yesterday, end: yesterday.addingTimeInterval(3600)),
        WorkInterval(start: at("9:00"), end: at("10:00")),
    ]
    #expect(calculator.totalMinutes(of: intervals, on: day, now: at("18:00")) == 60)
}

@Test func emptyBlocksAreDropped() {
    let spans = calculator.spans(of: [WorkInterval(start: at("9:00"), end: at("9:00"))], on: day, now: at("18:00"))
    #expect(spans.isEmpty)
}

@Test(arguments: [
    (0, "0,00"),
    (15, "0,25"),
    (495, "8,25"),
    (530, "8,83"),
    (600, "10,00"),
])
func decimalHours(minutes: Int, expected: String) {
    #expect(HoursFormat.decimal(minutes) == expected)
}
