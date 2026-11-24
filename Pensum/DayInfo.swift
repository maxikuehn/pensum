import Foundation
import SwiftData

/// Alles zu einem Tag, was keine Arbeitszeit ist: Urlaub und Stunden für Nebenprojekte.
@Model
final class DayInfo {
    /// Mitternacht des Tages
    @Attribute(.unique) var day: Date
    var isVacation = false
    /// Minuten je Nebenprojekt, Schlüssel ist die Projekt-ID.
    var allocations: [String: Int] = [:]

    init(day: Date) {
        self.day = day
    }
}

/// Ein Nebenprojekt. Was keinem Nebenprojekt zugeordnet ist, zählt zum Hauptprojekt.
@Model
final class Project {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorIndex: Int
    var isHidden = false
    var sortOrder: Int

    init(name: String, colorIndex: Int, sortOrder: Int) {
        id = UUID()
        self.name = name
        self.colorIndex = colorIndex
        self.sortOrder = sortOrder
    }

    var key: String { id.uuidString }
}
