import Foundation
import Testing
@testable import ShiftCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
}()

private func date(_ day: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day))!
}

@Test func exportListsWorkedDaysVacationAndTotals() {
    let days = [
        ExportDay(date: date(23), spans: [DaySpan(start: 490, end: 725), DaySpan(start: 765, end: 1060)], projects: ["a": 60]),
        ExportDay(date: date(24), spans: [], isVacation: true),
        ExportDay(date: date(25), spans: []),
    ]
    let csv = CSVExport.make(days: days, mainProject: "Kunde; Nord", projects: [(id: "a", name: "Pre-Sales")], calendar: calendar)
    #expect(csv == """
    Datum;Beginn;Ende;Pause (h);Arbeitszeit (h);"Kunde; Nord (h)";Pre-Sales (h);Bemerkung\r
    23.11.2026;8:10;17:40;0,67;8,83;7,83;1,00;\r
    24.11.2026;;;;;;;Urlaub\r
    Summe;;;0,67;8,83;7,83;1,00;\r

    """)
}
