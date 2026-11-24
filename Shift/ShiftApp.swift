import SwiftData
import SwiftUI

@main
struct ShiftApp: App {
    private let container: ModelContainer
    private let monitor: ActivityMonitor
    private let checkIn: CheckInController
    @State private var tracker: Tracker
    @State private var overview: OverviewModel

    init() {
        let container = Self.makeContainer()
        let tracker = Tracker(context: container.mainContext)
        let overview = OverviewModel(tracker: tracker, context: container.mainContext)
        let checkIn = CheckInController(
            tracker: tracker,
            isVacation: { overview.isVacation($0) },
            markDayOff: { overview.setVacation($0, true) }
        )
        self.container = container
        self.checkIn = checkIn
        monitor = ActivityMonitor(tracker: tracker) { checkIn.userBecameActive(at: $0) }
        _tracker = State(initialValue: tracker)
        _overview = State(initialValue: overview)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(tracker: tracker)
        } label: {
            Image(nsImage: MenuBarIcon.image(tracker.isRunning ? .running : tracker.awaySince != nil ? .paused : .idle))
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)

        Window("Übersicht", id: "overview") {
            OverviewView(model: overview)
        }
        .windowResizability(.contentSize)
        // Zum Ausprobieren: mit `-openOverview YES` starten, dann ist die Übersicht sofort offen
        .defaultLaunchBehavior(UserDefaults.standard.bool(forKey: "openOverview") ? .presented : .suppressed)
        .modelContainer(container)

        Settings {
            SettingsView()
        }
    }

    /// Die Daten liegen in ~/Library/Application Support/Shift/Shift.store.
    private static func makeContainer() -> ModelContainer {
        let folder = URL.applicationSupportDirectory.appending(path: "Shift", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var file = "Shift.store"
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
