import OSLog
import PensumCore
import ServiceManagement
import SwiftUI

/// Gespeicherte Einstellungen mit ihren Standardwerten.
enum Preferences {
    static let idleMinutesKey = "idleMinutes"
    static let checkInEnabledKey = "checkInEnabled"
    static let workdaysKey = "workdays"
    static let dayStartKey = "dayStartHour"
    static let dayEndKey = "dayEndHour"
    static let csvExportKey = "csvExportEnabled"
    static let periodKey = "overviewPeriod"

    /// Sichtbarer Zeitraum der Zeitleisten, standardmäßig 7–20 Uhr.
    static var dayStartHour: Int { UserDefaults.standard.object(forKey: dayStartKey) as? Int ?? 7 }
    static var dayEndHour: Int { UserDefaults.standard.object(forKey: dayEndKey) as? Int ?? 20 }

    static var idleMinutes: Int {
        let value = UserDefaults.standard.integer(forKey: idleMinutesKey)
        return value > 0 ? value : 15
    }

    /// Abschnitt der Übersicht, standardmäßig eine Monatshälfte.
    static var period: Period.Kind {
        UserDefaults.standard.string(forKey: periodKey).flatMap(Period.Kind.init(rawValue:)) ?? .halfMonth
    }

    static var checkInEnabled: Bool {
        UserDefaults.standard.object(forKey: checkInEnabledKey) as? Bool ?? true
    }

    /// Wochentage nach `Calendar`-Zählung (1 = Sonntag … 7 = Samstag), gespeichert als z. B. „23456“.
    static var workdays: Set<Int> {
        Set((UserDefaults.standard.string(forKey: workdaysKey) ?? "23456").compactMap { $0.wholeNumberValue })
    }
}

struct SettingsView: View {
    @AppStorage(Preferences.idleMinutesKey) private var idleMinutes = 15
    @AppStorage(Preferences.checkInEnabledKey) private var checkInEnabled = true
    @AppStorage(Preferences.workdaysKey) private var workdays = "23456"
    @AppStorage(Preferences.dayStartKey) private var dayStart = 7
    @AppStorage(Preferences.dayEndKey) private var dayEnd = 20
    @AppStorage(Preferences.csvExportKey) private var csvExportEnabled = true
    @AppStorage(Preferences.periodKey) private var period = Period.Kind.halfMonth
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    /// Montag zuerst, wie im Kalender
    private let weekdays: [(number: Int, name: String)] = [(2, "Mo"), (3, "Di"), (4, "Mi"), (5, "Do"), (6, "Fr"), (7, "Sa"), (1, "So")]

    var body: some View {
        Form {
            Toggle("Bei der Anmeldung starten", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }

            Picker("Pause nach", selection: $idleMinutes) {
                ForEach([5, 10, 15, 20, 30], id: \.self) { Text("\($0) Minuten ohne Eingabe").tag($0) }
            }

            LabeledContent("Sichtbarer Zeitraum") {
                HStack(spacing: 6) {
                    Picker("Von", selection: $dayStart) {
                        ForEach(0..<23, id: \.self) { Text("\($0):00").tag($0) }
                    }
                    Text("bis")
                    Picker("Bis", selection: $dayEnd) {
                        ForEach(2...24, id: \.self) { Text("\($0):00").tag($0) }
                    }
                }
                .labelsHidden()
                .fixedSize()
                .monospacedDigit()
            }
            // Mindestens zwei Stunden, damit die Zeitleiste lesbar bleibt
            .onChange(of: dayStart) { _, start in if dayEnd < start + 2 { dayEnd = min(24, start + 2) } }
            .onChange(of: dayEnd) { _, end in if dayStart > end - 2 { dayStart = max(0, end - 2) } }

            Picker("Übersicht zeigt", selection: $period) {
                Text("Ganzer Monat").tag(Period.Kind.month)
                Text("15 Tage").tag(Period.Kind.halfMonth)
                Text("Woche").tag(Period.Kind.week)
            }

            Toggle("CSV-Export in der Übersicht", isOn: $csvExportEnabled)

            Toggle("Morgens fragen, ob die Arbeitszeit starten soll", isOn: $checkInEnabled)

            LabeledContent("Arbeitstage") {
                HStack(spacing: 4) {
                    ForEach(weekdays, id: \.number) { day in
                        let isOn = workdays.contains(String(day.number))
                        Button(day.name) { toggle(day.number) }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 30, height: 24)
                            .foregroundStyle(isOn ? Color.black.opacity(0.85) : .secondary)
                            .background(RoundedRectangle(cornerRadius: 6).fill(isOn ? Color.workYellow : Color.hoverFill))
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func toggle(_ day: Int) {
        var days = Set(workdays.compactMap(\.wholeNumberValue))
        if days.contains(day) { days.remove(day) } else { days.insert(day) }
        workdays = days.sorted().map(String.init).joined()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.pensum.error("Autostart konnte nicht geändert werden: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
