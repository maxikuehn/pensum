import Foundation

/// Bundesland, dessen gesetzliche Feiertage gelten.
public enum FederalState: String, CaseIterable, Sendable {
    case badenWuerttemberg = "BW"
    case bayern = "BY"
    case berlin = "BE"
    case brandenburg = "BB"
    case bremen = "HB"
    case hamburg = "HH"
    case hessen = "HE"
    case mecklenburgVorpommern = "MV"
    case niedersachsen = "NI"
    case nordrheinWestfalen = "NW"
    case rheinlandPfalz = "RP"
    case saarland = "SL"
    case sachsen = "SN"
    case sachsenAnhalt = "ST"
    case schleswigHolstein = "SH"
    case thueringen = "TH"

    public var name: String {
        switch self {
        case .badenWuerttemberg: "Baden-Württemberg"
        case .bayern: "Bayern"
        case .berlin: "Berlin"
        case .brandenburg: "Brandenburg"
        case .bremen: "Bremen"
        case .hamburg: "Hamburg"
        case .hessen: "Hessen"
        case .mecklenburgVorpommern: "Mecklenburg-Vorpommern"
        case .niedersachsen: "Niedersachsen"
        case .nordrheinWestfalen: "Nordrhein-Westfalen"
        case .rheinlandPfalz: "Rheinland-Pfalz"
        case .saarland: "Saarland"
        case .sachsen: "Sachsen"
        case .sachsenAnhalt: "Sachsen-Anhalt"
        case .schleswigHolstein: "Schleswig-Holstein"
        case .thueringen: "Thüringen"
        }
    }
}

/// Gesetzliche Feiertage, ohne Internet berechnet: feste Termine und alles, was an Ostern hängt.
/// Feiertage, die nur in einzelnen Gemeinden gelten (Augsburger Friedensfest, Fronleichnam in Teilen
/// Sachsens und Thüringens), fehlen; Mariä Himmelfahrt zählt in Bayern, wo es für die meisten Gemeinden gilt.
public enum Holidays {
    /// Alle Feiertage eines Jahres in einem Bundesland.
    public static func all(in year: Int, state: FederalState) -> [Period.Day: String] {
        let easter = easterSunday(year)
        func fixed(_ month: Int, _ day: Int) -> Period.Day { Period.Day(year: year, month: month, day: day) }
        func fromEaster(_ days: Int) -> Period.Day { shifted(easter, by: days) }

        var result: [Period.Day: String] = [
            fixed(1, 1): "Neujahr",
            fromEaster(-2): "Karfreitag",
            fromEaster(1): "Ostermontag",
            fixed(5, 1): "Tag der Arbeit",
            fromEaster(39): "Christi Himmelfahrt",
            fromEaster(50): "Pfingstmontag",
            fixed(10, 3): "Tag der Deutschen Einheit",
            fixed(12, 25): "1. Weihnachtstag",
            fixed(12, 26): "2. Weihnachtstag",
        ]
        if [.badenWuerttemberg, .bayern, .sachsenAnhalt].contains(state) {
            result[fixed(1, 6)] = "Heilige Drei Könige"
        }
        if state == .berlin || (state == .mecklenburgVorpommern && year >= 2023) {
            result[fixed(3, 8)] = "Frauentag"
        }
        if [.badenWuerttemberg, .bayern, .hessen, .nordrheinWestfalen, .rheinlandPfalz, .saarland].contains(state) {
            result[fromEaster(60)] = "Fronleichnam"
        }
        if [.bayern, .saarland].contains(state) {
            result[fixed(8, 15)] = "Mariä Himmelfahrt"
        }
        if state == .thueringen && year >= 2019 {
            result[fixed(9, 20)] = "Weltkindertag"
        }
        let reformation: Set<FederalState> = [.brandenburg, .mecklenburgVorpommern, .sachsen, .sachsenAnhalt, .thueringen]
        let reformationSince2018: Set<FederalState> = [.bremen, .hamburg, .niedersachsen, .schleswigHolstein]
        if reformation.contains(state) || (reformationSince2018.contains(state) && year >= 2018) {
            result[fixed(10, 31)] = "Reformationstag"
        }
        if [.badenWuerttemberg, .bayern, .nordrheinWestfalen, .rheinlandPfalz, .saarland].contains(state) {
            result[fixed(11, 1)] = "Allerheiligen"
        }
        if state == .sachsen {
            result[repentanceDay(year)] = "Buß- und Bettag"
        }
        return result
    }

    /// Name des Feiertags an diesem Tag, sonst `nil`.
    public static func name(on date: Date, state: FederalState, calendar: Calendar = .current) -> String? {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = Period.Day(year: parts.year!, month: parts.month!, day: parts.day!)
        return all(in: day.year, state: state)[day]
    }

    /// Ostersonntag nach Meeus/Jones/Butcher, gültig für den gregorianischen Kalender.
    public static func easterSunday(_ year: Int) -> Period.Day {
        let a = year % 19, b = year / 100, c = year % 100
        let d = b / 4, e = b % 4
        let f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = (h + l - 7 * m + 114) % 31 + 1
        return Period.Day(year: year, month: month, day: day)
    }

    /// Buß- und Bettag: der Mittwoch vor dem 23. November.
    static func repentanceDay(_ year: Int) -> Period.Day {
        let date = grid.date(from: DateComponents(year: year, month: 11, day: 22))!
        // Wochentag 1 = Sonntag … 4 = Mittwoch
        let back = (grid.component(.weekday, from: date) - 4 + 7) % 7
        return shifted(Period.Day(year: year, month: 11, day: 22), by: -back)
    }

    private static func shifted(_ day: Period.Day, by days: Int) -> Period.Day {
        let date = grid.date(from: DateComponents(year: day.year, month: day.month, day: day.day))!
        let parts = grid.dateComponents([.year, .month, .day], from: grid.date(byAdding: .day, value: days, to: date)!)
        return Period.Day(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// Fester Kalender in UTC, damit Zeitumstellungen die Tagesrechnung nicht stören.
    private static let grid: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
