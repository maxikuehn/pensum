import Foundation
import Testing
@testable import PensumCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
}()

private func day(_ year: Int, _ month: Int, _ day: Int) -> Period.Day {
    Period.Day(year: year, month: month, day: day)
}

@Test func easterSundayMatchesKnownDates() {
    #expect(Holidays.easterSunday(2024) == day(2024, 3, 31))
    #expect(Holidays.easterSunday(2025) == day(2025, 4, 20))
    #expect(Holidays.easterSunday(2026) == day(2026, 4, 5))
    #expect(Holidays.easterSunday(2027) == day(2027, 3, 28))
    #expect(Holidays.easterSunday(2038) == day(2038, 4, 25))
}

@Test func movableHolidaysFollowEaster() {
    let holidays = Holidays.all(in: 2026, state: .nordrheinWestfalen)
    #expect(holidays[day(2026, 4, 3)] == "Karfreitag")
    #expect(holidays[day(2026, 4, 6)] == "Ostermontag")
    #expect(holidays[day(2026, 5, 14)] == "Christi Himmelfahrt")
    #expect(holidays[day(2026, 5, 25)] == "Pfingstmontag")
    #expect(holidays[day(2026, 6, 4)] == "Fronleichnam")
}

@Test func nationwideHolidaysApplyEverywhere() {
    for state in FederalState.allCases {
        let holidays = Holidays.all(in: 2026, state: state)
        #expect(holidays[day(2026, 1, 1)] == "Neujahr")
        #expect(holidays[day(2026, 10, 3)] == "Tag der Deutschen Einheit")
        #expect(holidays[day(2026, 12, 26)] == "2. Weihnachtstag")
    }
}

@Test func stateHolidaysOnlyWhereTheyApply() {
    #expect(Holidays.all(in: 2026, state: .berlin)[day(2026, 3, 8)] == "Frauentag")
    #expect(Holidays.all(in: 2026, state: .hamburg)[day(2026, 3, 8)] == nil)
    #expect(Holidays.all(in: 2026, state: .niedersachsen)[day(2026, 10, 31)] == "Reformationstag")
    #expect(Holidays.all(in: 2026, state: .bayern)[day(2026, 10, 31)] == nil)
    #expect(Holidays.all(in: 2026, state: .bayern)[day(2026, 11, 1)] == "Allerheiligen")
    #expect(Holidays.all(in: 2026, state: .bayern)[day(2026, 8, 15)] == "Mariä Himmelfahrt")
    #expect(Holidays.all(in: 2026, state: .berlin)[day(2026, 6, 4)] == nil)
    #expect(Holidays.all(in: 2026, state: .thueringen)[day(2026, 9, 20)] == "Weltkindertag")
}

@Test func repentanceDayIsWednesdayBeforeNovember23() {
    #expect(Holidays.repentanceDay(2025) == day(2025, 11, 19))
    #expect(Holidays.repentanceDay(2026) == day(2026, 11, 18))
    #expect(Holidays.repentanceDay(2027) == day(2027, 11, 17))
    #expect(Holidays.all(in: 2026, state: .sachsen)[day(2026, 11, 18)] == "Buß- und Bettag")
    #expect(Holidays.all(in: 2026, state: .berlin)[day(2026, 11, 18)] == nil)
}

@Test func lawChangesAreDated() {
    #expect(Holidays.all(in: 2017, state: .niedersachsen)[day(2017, 10, 31)] == nil)
    #expect(Holidays.all(in: 2022, state: .mecklenburgVorpommern)[day(2022, 3, 8)] == nil)
    #expect(Holidays.all(in: 2023, state: .mecklenburgVorpommern)[day(2023, 3, 8)] == "Frauentag")
}

@Test func nameLooksUpALocalDate() {
    let lateEvening = calendar.date(from: DateComponents(year: 2026, month: 12, day: 25, hour: 23, minute: 30))!
    #expect(Holidays.name(on: lateEvening, state: .hessen, calendar: calendar) == "1. Weihnachtstag")
    let normal = calendar.date(from: DateComponents(year: 2026, month: 11, day: 27))!
    #expect(Holidays.name(on: normal, state: .hessen, calendar: calendar) == nil)
}
