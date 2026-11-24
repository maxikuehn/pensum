import Foundation
import Testing
@testable import PensumCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
}()

private func date(_ day: Int, _ hour: Int = 8) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
}

private let policy = CheckInPolicy(calendar: calendar)

// 24.11.2026 ist ein Dienstag, 28.11. ein Samstag.

@Test func asksOnAWorkdayWithoutTime() {
    #expect(policy.shouldAsk(now: date(24), hasWorkToday: false, isRunning: false, dayOff: nil))
}

@Test func doesNotAskOnWeekends() {
    #expect(!policy.shouldAsk(now: date(28), hasWorkToday: false, isRunning: false, dayOff: nil))
}

@Test func doesNotAskOnceTimeIsRecorded() {
    #expect(!policy.shouldAsk(now: date(24), hasWorkToday: true, isRunning: false, dayOff: nil))
    #expect(!policy.shouldAsk(now: date(24), hasWorkToday: false, isRunning: true, dayOff: nil))
}

@Test func dayOffOnlyAppliesToThatDay() {
    #expect(!policy.shouldAsk(now: date(24, 13), hasWorkToday: false, isRunning: false, dayOff: date(24, 8)))
    #expect(policy.shouldAsk(now: date(25), hasWorkToday: false, isRunning: false, dayOff: date(24, 8)))
}
