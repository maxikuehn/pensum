#if DEBUG
import Foundation
import PensumCore
import SwiftData

/// Beispieldaten zum Ausprobieren, getrennt von deinen echten Daten.
/// Mit `-demoStore YES` gestartet, nutzt die App eine eigene Datei Demo.store und füllt sie einmalig.
enum DemoData {
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: "demoStore") }

    /// Mit `-demoNow "2026-12-29 12:40"` tut die Übersicht so, als wäre es dieser Zeitpunkt, etwa für Schnappschüsse.
    static func now(replacing date: Date) -> Date {
        guard let text = UserDefaults.standard.string(forKey: "demoNow") else { return date }
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy-MM-dd H:mm"
        return format.date(from: text) ?? date
    }

    static func seedIfEmpty(_ context: ModelContext, calendar: Calendar = .current) {
        guard (try? context.fetchCount(FetchDescriptor<WorkBlock>())) == 0 else { return }
        let today = calendar.startOfDay(for: now(replacing: .now))
        // Die letzten Arbeitstage bis heute, neuester zuerst, Zeiten als „h:mm“; ohne Blöcke ist Urlaub.
        // Gedacht für `-demoNow "2026-12-29 12:40"`: zwischen den Jahren ruhiger, am 23. kurz, am 24. Urlaub
        let days: [[(String, String?)]] = [
            [("8:12", nil)],
            [("8:41", "12:03"), ("12:45", "16:10")],
            [],
            [("7:56", "11:58"), ("12:31", "14:47")],
            [("8:05", "12:14"), ("12:58", "17:33")],
            [("7:49", "12:02"), ("12:40", "15:12"), ("15:24", "17:51")],
            [("8:02", "13:41")],
            [("8:16", "12:22"), ("13:05", "18:09")],
            [("8:24", "12:30"), ("13:10", "16:45")],
            [("7:52", "10:19"), ("10:33", "12:28"), ("13:12", "16:54")],
            [("8:07", "12:11"), ("12:56", "17:38")],
        ]
        // Bundesweite Feiertage bleiben auch ohne eingestelltes Bundesland frei
        func isHoliday(_ day: Date) -> Bool {
            Preferences.holiday(on: day) != nil || FederalState.allCases.allSatisfy { Holidays.name(on: day, state: $0) != nil }
        }
        func at(_ day: Date, _ time: String) -> Date {
            let parts = time.split(separator: ":").map { Int($0)! }
            return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)!
        }
        let presales = Project(name: "Pre-Sales", colorIndex: 0, sortOrder: 0)
        let intern = Project(name: "Intern", colorIndex: 1, sortOrder: 1)
        let training = Project(name: "Weiterbildung", colorIndex: 2, sortOrder: 2)
        let recruiting = Project(name: "Recruiting", colorIndex: 3, sortOrder: 3)
        [presales, intern, training, recruiting].forEach(context.insert)
        // Minuten je Projekt, in derselben Reihenfolge wie die Tage
        let allocations: [[Project: Int]] = [
            [:],
            [intern: 60],
            [:],
            [presales: 30],
            [presales: 90, recruiting: 45],
            [training: 120],
            [:],
            [recruiting: 60, training: 30, presales: 30],
            [presales: 120],
            [intern: 30],
            [presales: 60, intern: 30],
        ]
        var day = today
        for (blocks, projects) in zip(days, allocations) {
            // Wochenenden und Feiertage bleiben frei
            while calendar.isDateInWeekend(day) || isHoliday(day) {
                day = calendar.date(byAdding: .day, value: -1, to: day)!
            }
            for (start, end) in blocks {
                context.insert(WorkBlock(start: at(day, start), end: end.map { at(day, $0) }))
            }
            if blocks.isEmpty || !projects.isEmpty {
                let info = DayInfo(day: day)
                info.isVacation = blocks.isEmpty
                info.allocations = Dictionary(uniqueKeysWithValues: projects.map { ($0.key.key, $0.value) })
                context.insert(info)
            }
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        try? context.save()
    }
}
#endif
