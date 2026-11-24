import Foundation

/// Ein Tag für den Export.
public struct ExportDay: Sendable {
    public var date: Date
    public var spans: [DaySpan]
    public var isVacation: Bool
    /// Minuten je Nebenprojekt (Projekt-ID), bereits auf die Tagessumme begrenzt.
    public var projects: [String: Int]

    public init(date: Date, spans: [DaySpan], isVacation: Bool = false, projects: [String: Int] = [:]) {
        self.date = date
        self.spans = spans
        self.isVacation = isVacation
        self.projects = projects
    }
}

/// CSV für Excel in deutscher Einstellung: Semikolon als Trenner, Komma bei Dezimalzahlen.
public enum CSVExport {
    public static func make(
        days: [ExportDay],
        mainProject: String,
        projects: [(id: String, name: String)],
        calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "dd.MM.yyyy"

        var lines = [(["Datum", "Beginn", "Ende", "Pause (h)", "Arbeitszeit (h)", "\(mainProject) (h)"]
            + projects.map { "\($0.name) (h)" } + ["Bemerkung"]).map(escape).joined(separator: ";")]

        var totals = Array(repeating: 0, count: 3 + projects.count)
        for day in days where !day.spans.isEmpty || day.isVacation {
            let worked = day.spans.reduce(0) { $0 + $1.minutes }
            let pause = day.spans.isEmpty ? 0 : day.spans.last!.end - day.spans.first!.start - worked
            let perProject = projects.map { day.projects[$0.id] ?? 0 }
            let main = worked - perProject.reduce(0, +)
            let values = [pause, worked, main] + perProject
            for (i, value) in values.enumerated() { totals[i] += value }

            var fields = [
                formatter.string(from: day.date),
                day.spans.first.map { clock($0.start) } ?? "",
                day.spans.last.map { clock($0.end) } ?? "",
            ]
            fields += day.spans.isEmpty ? values.map { _ in "" } : values.map(HoursFormat.decimal)
            fields.append(day.isVacation ? "Urlaub" : "")
            lines.append(fields.map(escape).joined(separator: ";"))
        }
        lines.append((["Summe", "", ""] + totals.map(HoursFormat.decimal) + [""]).map(escape).joined(separator: ";"))
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    private static func clock(_ minutes: Int) -> String {
        "\(minutes / 60):" + String(format: "%02d", minutes % 60)
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == ";" || $0 == "\"" || $0 == "\n" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
