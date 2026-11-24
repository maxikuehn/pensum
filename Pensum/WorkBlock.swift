import Foundation
import PensumCore
import SwiftData

/// Eine Arbeitsphase, sekundengenau gespeichert. Gerundet wird erst beim Anzeigen und Zählen.
/// Eine Pause ist die Lücke zwischen zwei Blöcken.
@Model
final class WorkBlock {
    var start: Date
    var end: Date?

    init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    var interval: WorkInterval { WorkInterval(start: start, end: end) }
}
