import Foundation
import Observation
import OSLog
import PensumCore
import SwiftData

/// Datenzugriff für die Übersicht: Blöcke, Urlaub und Projektzeiten je Tag.
@Observable
final class OverviewModel {
    let tracker: Tracker
    private let context: ModelContext
    private let calculator = DayCalculator()
    /// Wird bei jeder Änderung erhöht, damit die Übersicht neu liest.
    private var revision = 0
    /// Gelesene Blöcke je Tag, gültig solange sich nichts geändert hat und dieselbe Minute ist.
    @ObservationIgnored private var cache: (key: CacheKey, spans: [Date: [DaySpan]]) = (CacheKey(), [:])

    private struct CacheKey: Equatable {
        var revision = -1
        var running: PersistentIdentifier?
        var runningStart: Date?
        var minute = 0
    }

    var mainProjectName: String {
        didSet { UserDefaults.standard.set(mainProjectName, forKey: "mainProjectName") }
    }

    init(tracker: Tracker, context: ModelContext) {
        self.tracker = tracker
        self.context = context
        mainProjectName = UserDefaults.standard.string(forKey: "mainProjectName") ?? "Hauptprojekt"
    }

    // MARK: Arbeitszeit

    func spans(on day: Date, now: Date) -> [DaySpan] {
        let key = CacheKey(
            revision: revision,
            running: tracker.running?.persistentModelID,
            runningStart: tracker.running?.start,
            minute: Int(now.timeIntervalSinceReferenceDate / 60)
        )
        if cache.key != key { cache = (key, [:]) }
        if let spans = cache.spans[day] { return spans }
        let spans = calculator.spans(of: tracker.intervals(on: day), on: day, now: now)
        cache.spans[day] = spans
        return spans
    }

    func apply(_ spans: [DaySpan], on day: Date) {
        tracker.replaceBlocks(on: day, with: spans)
        revision += 1
    }

    // MARK: Urlaub

    func isVacation(_ day: Date) -> Bool {
        info(for: day)?.isVacation ?? false
    }

    func setVacation(_ day: Date, _ isVacation: Bool) {
        let info = info(for: day, create: true)!
        info.isVacation = isVacation
        save()
    }

    func toggleVacation(_ day: Date) {
        let info = info(for: day, create: true)!
        info.isVacation.toggle()
        save()
    }

    // MARK: Projekte

    var projects: [Project] {
        _ = revision
        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.sortOrder)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Stunden je Nebenprojekt an diesem Tag, so wie sie in die Tagessumme passen.
    func split(on day: Date, total: Int) -> [(project: Project, minutes: Int)] {
        let stored = info(for: day)?.allocations ?? [:]
        let projects = projects
        let effective = ProjectSplit.effective(projects.map { (id: $0.key, minutes: stored[$0.key] ?? 0) }, total: total)
        return projects.compactMap { project in effective[project.key].map { (project, $0) } }
    }

    func changeAllocation(of project: Project, on day: Date, by delta: Int, total: Int) {
        let current = split(on: day, total: total).first { $0.project.id == project.id }?.minutes ?? 0
        let info = info(for: day, create: true)!
        let minutes = max(0, current + delta)
        info.allocations[project.key] = minutes == 0 ? nil : minutes
        save()
    }

    @discardableResult
    func addProject() -> Project {
        let projects = projects
        let used = Set(projects.filter { !$0.isHidden }.map(\.colorIndex))
        let color = (0..<4).first { !used.contains($0) } ?? projects.count % 4
        let project = Project(name: "Neues Projekt", colorIndex: color, sortOrder: (projects.map(\.sortOrder).max() ?? -1) + 1)
        context.insert(project)
        save()
        return project
    }

    /// An wie vielen Tagen ein Projekt Zeit hat, wie viel insgesamt und wann zuletzt, so wie es in die Tagessummen passt.
    func usage(of project: Project, now: Date = .now) -> (days: Int, minutes: Int, last: Date?) {
        _ = revision
        let infos = (try? context.fetch(FetchDescriptor<DayInfo>())) ?? []
        var result: (days: Int, minutes: Int, last: Date?) = (0, 0, nil)
        for info in infos where (info.allocations[project.key] ?? 0) > 0 {
            let total = spans(on: info.day, now: now).reduce(0) { $0 + $1.minutes }
            guard let minutes = split(on: info.day, total: total).first(where: { $0.project.id == project.id })?.minutes, minutes > 0 else { continue }
            result.days += 1
            result.minutes += minutes
            result.last = max(result.last ?? info.day, info.day)
        }
        return result
    }

    /// Löscht ein Nebenprojekt. Seine Zeit zählt danach wieder zum Hauptprojekt.
    func deleteProject(_ project: Project) {
        let infos = (try? context.fetch(FetchDescriptor<DayInfo>())) ?? []
        for info in infos where info.allocations[project.key] != nil {
            info.allocations[project.key] = nil
        }
        context.delete(project)
        save()
    }

    func moveProjects(from source: IndexSet, to destination: Int) {
        var projects = projects
        projects.move(fromOffsets: source, toOffset: destination)
        for (index, project) in projects.enumerated() { project.sortOrder = index }
        save()
    }

    func save() {
        do {
            try context.save()
        } catch {
            Logger.pensum.error("Speichern fehlgeschlagen: \(error)")
        }
        revision += 1
    }

    private func info(for day: Date, create: Bool = false) -> DayInfo? {
        _ = revision
        let midnight = Calendar.current.startOfDay(for: day)
        var descriptor = FetchDescriptor<DayInfo>(predicate: #Predicate { $0.day == midnight })
        descriptor.fetchLimit = 1
        if let info = (try? context.fetch(descriptor))?.first { return info }
        guard create else { return nil }
        let info = DayInfo(day: midnight)
        context.insert(info)
        return info
    }
}
