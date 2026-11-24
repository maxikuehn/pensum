import Foundation
import Testing
@testable import ShiftCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
}()

@Test func halfMonthContainingADate() {
    let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 24))!
    #expect(HalfMonth.containing(date, calendar: calendar) == HalfMonth(year: 2026, month: 11, half: 2))
}

@Test func secondHalfEndsWithTheMonth() {
    #expect(HalfMonth(year: 2026, month: 11, half: 2).dayNumbers(calendar: calendar) == 16...30)
    #expect(HalfMonth(year: 2028, month: 2, half: 2).dayNumbers(calendar: calendar) == 16...29)
    #expect(HalfMonth(year: 2026, month: 12, half: 1).dayNumbers(calendar: calendar) == 1...15)
}

@Test func pagingCrossesMonthsAndYears() {
    let december = HalfMonth(year: 2026, month: 12, half: 2)
    #expect(december.next == HalfMonth(year: 2027, month: 1, half: 1))
    #expect(december.next.previous == december)
    #expect(HalfMonth(year: 2026, month: 11, half: 1).previous == HalfMonth(year: 2026, month: 10, half: 2))
}

@Test func splitFitsIntoTheDayTotal() {
    let split = ProjectSplit.effective([(id: "a", minutes: 60), (id: "b", minutes: 30)], total: 530)
    #expect(split == ["a": 60, "b": 30])
}

@Test func splitIsCutWhenTheDayGetsShorter() {
    // 70 Minuten Arbeitszeit → nur 60 Minuten (volle Viertelstunden) verteilbar
    let split = ProjectSplit.effective([(id: "a", minutes: 45), (id: "b", minutes: 30)], total: 70)
    #expect(split == ["a": 45, "b": 15])
}
