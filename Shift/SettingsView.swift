import OSLog
import ServiceManagement
import SwiftUI

/// Gespeicherte Einstellungen mit ihren Standardwerten.
enum Preferences {
    static let idleMinutesKey = "idleMinutes"
    static let checkInEnabledKey = "checkInEnabled"
    static let workdaysKey = "workdays"

    static var idleMinutes: Int {
        let value = UserDefaults.standard.integer(forKey: idleMinutesKey)
        return value > 0 ? value : 15
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
                            .background(RoundedRectangle(cornerRadius: 6).fill(isOn ? Color.shiftYellow : Color.hoverFill))
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
            Logger.shift.error("Autostart konnte nicht geändert werden: \(error)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
