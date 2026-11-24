import Foundation
import Testing
@testable import PensumCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
}()

private func date(_ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
}

private let policy = PausePolicy(calendar: calendar)

@Test func shortInterruptionKeepsTheBlockRunning() {
    #expect(policy.resume(awaySince: date(24, 10, 0), now: date(24, 10, 1, 59)) == .reopen)
}

@Test func realPauseStartsANewBlock() {
    #expect(policy.resume(awaySince: date(24, 12, 5), now: date(24, 12, 50)) == .startNew)
    #expect(policy.resume(awaySince: date(24, 10, 0), now: date(24, 10, 2)) == .startNew)
}

@Test func lidClosedOvernightMeansEndOfDay() {
    #expect(policy.resume(awaySince: date(23, 17, 40), now: date(24, 8, 3)) == .none)
}

@Test func blockFromTodayIsNotStale() {
    #expect(policy.staleEnd(blockStart: date(24, 8, 0), lastActivity: date(24, 11, 0), now: date(24, 11, 30)) == nil)
}

@Test func forgottenBlockEndsAtLastActivity() {
    let end = policy.staleEnd(blockStart: date(23, 8, 0), lastActivity: date(23, 18, 12), now: date(24, 8, 5))
    #expect(end == date(23, 18, 12))
}

@Test func forgottenBlockNeverRunsPastMidnight() {
    let end = policy.staleEnd(blockStart: date(23, 8, 0), lastActivity: date(24, 1, 30), now: date(24, 8, 5))
    #expect(end == date(24, 0, 0))
}

@Test func forgottenBlockWithoutKnownActivityEndsWhereItStarted() {
    let end = policy.staleEnd(blockStart: date(23, 8, 0), lastActivity: nil, now: date(24, 8, 5))
    #expect(end == date(23, 8, 0))
}

@Test func workingThroughMidnightContinuesOnTheNewDay() {
    let change = policy.dayChange(blockStart: date(23, 21, 0), lastActivity: date(24, 0, 0, 30), now: date(24, 0, 0, 30), userIsActive: true)
    #expect(change == .split(at: date(24, 0, 0)))
}

@Test func forgottenBlockEndsWhenNobodyIsThere() {
    let change = policy.dayChange(blockStart: date(23, 8, 0), lastActivity: date(23, 18, 12), now: date(24, 8, 5), userIsActive: false)
    #expect(change == .end(at: date(23, 18, 12)))
}

@Test func blockFromOlderDaysIsNeverStretchedOverNights() {
    let change = policy.dayChange(blockStart: date(21, 8, 0), lastActivity: date(21, 17, 0), now: date(24, 8, 5), userIsActive: true)
    #expect(change == .end(at: date(21, 17, 0)))
}

@Test func todaysBlockIsLeftAlone() {
    #expect(policy.dayChange(blockStart: date(24, 8, 0), lastActivity: nil, now: date(24, 9, 0), userIsActive: true) == .none)
}

@Test func restartInTheMorningDoesNotCountTheNight() {
    // Block lief beim Herunterfahren noch; morgens ist man zwar aktiv, war es aber nicht bis eben
    let change = policy.dayChange(blockStart: date(23, 20, 0), lastActivity: date(23, 22, 40), now: date(24, 8, 5), userIsActive: true)
    #expect(change == .end(at: date(23, 22, 40)))
}
