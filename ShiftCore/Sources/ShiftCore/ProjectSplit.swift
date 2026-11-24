import Foundation

/// Aufteilung der Tagessumme auf Nebenprojekte, in Viertelstunden. Der Rest zählt zum Hauptprojekt.
public enum ProjectSplit {
    public static let quarter = 15

    /// Was angezeigt und gezählt wird, passt immer in die Tagessumme, auch wenn die Arbeitszeit
    /// nachträglich kürzer wird. Die Projekte werden in der gegebenen Reihenfolge bedient.
    /// Die gespeicherte Eingabe bleibt dabei unverändert.
    public static func effective(_ requested: [(id: String, minutes: Int)], total: Int) -> [String: Int] {
        var left = total / quarter * quarter
        var result: [String: Int] = [:]
        for entry in requested {
            let minutes = min(entry.minutes, left)
            if minutes > 0 {
                result[entry.id] = minutes
                left -= minutes
            }
        }
        return result
    }
}
