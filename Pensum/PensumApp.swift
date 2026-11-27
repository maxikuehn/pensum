import OSLog
import SwiftData
import SwiftUI

@main
struct PensumApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let container: ModelContainer
    private let monitor: ActivityMonitor
    private let checkIn: CheckInController
    @State private var tracker: Tracker
    @State private var overview: OverviewModel
    @State private var updater: Updater

    init() {
        Self.migrateFromShift()
        let container = Self.makeContainer()
        let tracker = Tracker(context: container.mainContext)
        let overview = OverviewModel(tracker: tracker, context: container.mainContext)
        let checkIn = CheckInController(
            tracker: tracker,
            isVacation: { overview.isVacation($0) || Preferences.holiday(on: $0) != nil },
            markDayOff: { overview.setVacation($0, true) }
        )
        self.container = container
        self.checkIn = checkIn
        let updater = Updater()
        monitor = ActivityMonitor(tracker: tracker) { date in
            checkIn.userBecameActive(at: date)
            updater.check(now: date, onlyIfNewDay: true)
        }
        _updater = State(initialValue: updater)
        _tracker = State(initialValue: tracker)
        _overview = State(initialValue: overview)
        // Nach dem ersten Start aus dem Programme-Ordner: Disk-Image aufräumen
        Task { @MainActor in await InstallerCleanup.offerIfNeeded() }
        Task { @MainActor in updater.check(onlyIfNewDay: false) }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(tracker: tracker, updater: updater)
        } label: {
            MenuBarLabel(state: tracker.isRunning ? .running : tracker.awaySince != nil ? .paused : .idle, appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)

        Window(Self.title, id: "overview") {
            OverviewView(model: overview)
        }
        .defaultSize(width: 900, height: 667)
        .windowResizability(.contentSize)
        // Zum Ausprobieren: mit `-openOverview YES` starten, dann ist die Übersicht sofort offen
        .defaultLaunchBehavior(UserDefaults.standard.bool(forKey: "openOverview") ? .presented : .suppressed)
        .modelContainer(container)

        Settings {
            SettingsView()
        }
    }

    /// Im Entwicklungs-Build ist am Fenstertitel zu erkennen, welche App gerade läuft.
    #if DEBUG
    private static let title = "Pensum-Development"
    #else
    private static let title = "Pensum"
    #endif

    /// Übernimmt Daten und Einstellungen aus der Zeit, als die App noch „Shift“ hieß. Läuft nur einmal.
    private static func migrateFromShift() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "migratedFromShift") else { return }
        if let old = defaults.persistentDomain(forName: "de.maxikuehn.shift") {
            for (key, value) in old { defaults.set(value, forKey: key) }
        }
        let files = FileManager.default
        let support = URL.applicationSupportDirectory
        let oldFolder = support.appending(path: "Shift", directoryHint: .isDirectory)
        let newFolder = support.appending(path: "Pensum", directoryHint: .isDirectory)
        if files.fileExists(atPath: oldFolder.path), !files.fileExists(atPath: newFolder.path) {
            do {
                try files.moveItem(at: oldFolder, to: newFolder)
                for suffix in ["", "-shm", "-wal"] {
                    let from = newFolder.appending(path: "Shift.store" + suffix)
                    if files.fileExists(atPath: from.path) {
                        try files.moveItem(at: from, to: newFolder.appending(path: "Pensum.store" + suffix))
                    }
                }
            } catch {
                Logger.pensum.error("Daten aus Shift konnten nicht übernommen werden: \(error)")
                return
            }
        }
        defaults.set(true, forKey: "migratedFromShift")
    }

    /// Die Daten liegen in ~/Library/Application Support/Pensum/Pensum.store.
    private static func makeContainer() -> ModelContainer {
        let folder = URL.applicationSupportDirectory.appending(path: "Pensum", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var file = "Pensum.store"
            #if DEBUG
            if DemoData.isEnabled { file = "Demo.store" }
            #endif
            let configuration = ModelConfiguration(url: folder.appending(path: file))
            let container = try ModelContainer(for: WorkBlock.self, DayInfo.self, Project.self, configurations: configuration)
            #if DEBUG
            if DemoData.isEnabled { DemoData.seedIfEmpty(container.mainContext) }
            #endif
            return container
        } catch {
            fatalError("Die Datenbank konnte nicht geöffnet werden: \(error)")
        }
    }
}
