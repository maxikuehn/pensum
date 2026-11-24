#if DEBUG
import Foundation
import SwiftData

/// Beispieldaten zum Ausprobieren, getrennt von deinen echten Daten.
/// Mit `-demoStore YES` gestartet, nutzt die App eine eigene Datei Demo.store und füllt sie einmalig.
enum DemoData {
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: "demoStore") }

    static func seedIfEmpty(_ context: ModelContext, calendar: Calendar = .current) {
        guard (try? context.fetchCount(FetchDescriptor<WorkBlock>())) == 0 else { return }
        let today = calendar.startOfDay(for: .now)
        // Tage relativ zu heute, Zeiten als „h:mm“
        let days: [Int: [(String, String?)]] = [
            -8: [("8:07", "12:11"), ("12:56", "17:38")],
            -7: [("7:52", "10:19"), ("10:33", "12:28"), ("13:12", "16:54")],
            -6: [("8:31", "12:02"), ("12:44", "18:17")],
            -5: [("8:12", "11:43"), ("12:21", "15:04"), ("15:19", "21:12")],
            -4: [("8:01", "13:29")],
            -1: [("8:13", "12:04"), ("12:49", "17:36")],
            0: [("8:03", "10:41"), ("10:52", nil)],
        ]
        func at(_ day: Date, _ time: String) -> Date {
            let parts = time.split(separator: ":").map { Int($0)! }
            return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day)!
        }
        for (offset, blocks) in days {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            guard !calendar.isDateInWeekend(day) else { continue }
            for (start, end) in blocks {
                context.insert(WorkBlock(start: at(day, start), end: end.map { at(day, $0) }))
            }
        }
        let presales = Project(name: "Pre-Sales", colorIndex: 0, sortOrder: 0)
        let intern = Project(name: "Intern", colorIndex: 1, sortOrder: 1)
        context.insert(presales)
        context.insert(intern)
        let info = DayInfo(day: calendar.date(byAdding: .day, value: -1, to: today)!)
        info.allocations = [presales.key: 60, intern.key: 30]
        context.insert(info)
        try? context.save()
    }
}
#endif
