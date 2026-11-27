import Foundation
import Testing
@testable import PensumCore

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

/// Im Export bleibt der Feiertag auch an gearbeiteten Tagen vermerkt, etwa für Zuschläge
@Test func exportNamesHolidays() {
    let days = [
        ExportDay(date: date(18), spans: [], holiday: "Buß- und Bettag"),
        ExportDay(date: date(19), spans: [DaySpan(start: 480, end: 720)], holiday: "Reformationstag"),
    ]
    let csv = CSVExport.make(days: days, mainProject: "Haupt", projects: [], calendar: calendar)
    #expect(csv.contains("18.11.2026;;;;;;Buß- und Bettag\r\n"))
    #expect(csv.contains("19.11.2026;8:00;12:00;0,00;4,00;4,00;Reformationstag\r\n"))
}
