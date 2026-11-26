import AppKit
import PensumCore
import SwiftUI
import UniformTypeIdentifiers

/// Die Übersicht: eine Monatshälfte, jeder Tag eine Zeile mit Zeitleiste und Summe.
struct OverviewView: View {
    let model: OverviewModel

    @AppStorage(Preferences.periodKey) private var periodKind = Period.Kind.halfMonth
    @State private var period = Period.containing(.now, kind: Preferences.period)
    @State private var offset = Double(TimeWindow.home)
    @State private var undo: UndoEntry?
    @State private var showsProjects = false
    @State private var scrollMonitor: Any?
    @State private var keyMonitor: Any?
    @State private var rowsFrame: CGRect = .zero
    @State private var axisFrame: CGRect = .zero
    @State private var trackWidth: CGFloat = 0
    /// Blöcke des Tages, an dem gerade ein Griff gezogen wird, damit die Summen sofort mitlaufen.
    @State private var liveEdit: (day: Date, spans: [DaySpan])?
    @AppStorage(Preferences.dayStartKey) private var dayStart = 7
    @AppStorage(Preferences.dayEndKey) private var dayEnd = 20
    @AppStorage(Preferences.csvExportKey) private var csvExportEnabled = true
    @AppStorage(Preferences.workdaysKey) private var workdays = "23456"
    /// Aufgeklappte Gruppen freier Tage, erkannt am ersten Tag der Gruppe
    @State private var openDaysOff: Set<Date> = []

    private let calendar = Calendar.current

    static let dateWidth: CGFloat = 92
    static let totalWidth: CGFloat = 82
    static let spacing: CGFloat = 14
    /// Schmaler passt der Kopf nicht mehr in eine Zeile.
    static let minWidth: CGFloat = 720

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
        .frame(minWidth: Self.minWidth, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity, alignment: .top)
        .onAppear {
            // Solange die Übersicht offen ist, gilt Pensum als normale App: mit Dock-Symbol und im App-Umschalter (⌘⇥)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
            installScrollMonitor()
            installKeyMonitor()
            #if DEBUG
            writeSnapshotIfRequested()
            #endif
        }
        .onDisappear {
            if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            scrollMonitor = nil
            keyMonitor = nil
            NSApp.setActivationPolicy(.accessory)
        }
        .sheet(isPresented: $showsProjects) {
            ProjectManager(model: model)
        }
        // Andere Einteilung in den Einstellungen: den heutigen Tag zeigen, sofern er gerade zu sehen ist, sonst den Anfang des Abschnitts
        .onChange(of: periodKind) { _, kind in
            let days = period.days(calendar: calendar)
            let anchor = days.contains { calendar.isDateInToday($0) } ? Date.now : days[0]
            page(Period.containing(anchor, kind: kind, calendar: calendar))
        }
        .onChange(of: dayStart) { offset = Double(TimeWindow.home) }
        .onChange(of: dayEnd) { offset = Double(TimeWindow.home) }
    }

    private func content(now: Date) -> some View {
        let days = period.days(calendar: calendar)
        // Einmal pro Darstellung lesen und an die Zeilen weitergeben
        let stored = Dictionary(uniqueKeysWithValues: days.map { ($0, model.spans(on: $0, now: now)) })
        let totals = Dictionary(uniqueKeysWithValues: days.map { day in
            let spans = liveEdit?.day == day ? liveEdit!.spans : stored[day, default: []]
            return (day, spans.reduce(0) { $0 + $1.minutes })
        })

        return VStack(alignment: .leading, spacing: 0) {
            header(days: days, totals: totals, now: now)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
            Divider()
            VStack(spacing: 0) {
                axis
                    .padding(.horizontal, 24)
                // Nur die Tage scrollen, Kopf und Uhrzeitleiste bleiben stehen
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(sections(of: days), id: \.self) { section in
                            switch section {
                            case .day(let day):
                                dayRow(day, spans: stored[day, default: []], now: now)
                            case .daysOff(let group):
                                // Freie Tage mit Zeit, Urlaub oder heute bleiben immer sichtbar
                                let pinned = group.contains { calendar.isDate($0, inSameDayAs: now) || model.isVacation($0) || !stored[$0, default: []].isEmpty }
                                let isOpen = pinned || openDaysOff.contains(group[0])
                                if !pinned {
                                    DaysOffToggle(days: group, isOpen: isOpen) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if isOpen { openDaysOff.remove(group[0]) } else { openDaysOff.insert(group[0]) }
                                        }
                                    }
                                }
                                if isOpen {
                                    ForEach(group, id: \.self) { dayRow($0, spans: stored[$0, default: []], now: now) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
                }
                .scrollIndicators(.never)
                .scrollBounceBehavior(.basedOnSize)
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rowsFrame = $0 }
        }
        .dragBubbles()
        .overlay(alignment: .bottom) { undoNotice }
    }

    private func dayRow(_ day: Date, spans: [DaySpan], now: Date) -> some View {
        DayRow(
            model: model,
            day: day,
            spans: spans,
            now: now,
            offset: offset,
            liveSpans: liveEdit?.day == day ? liveEdit?.spans : nil,
            onDraft: { draft in liveEdit = draft.map { (day, $0) } },
            onEdit: edit,
            onManageProjects: { showsProjects = true }
        )
    }

    private enum Section: Hashable {
        case day(Date)
        /// Aufeinanderfolgende Tage, die laut Einstellungen keine Arbeitstage sind
        case daysOff([Date])
    }

    private func sections(of days: [Date]) -> [Section] {
        let workdays = Set(workdays.compactMap(\.wholeNumberValue))
        var sections: [Section] = []
        var group: [Date] = []
        for day in days {
            if workdays.contains(calendar.component(.weekday, from: day)) {
                if !group.isEmpty { sections.append(.daysOff(group)) }
                group = []
                sections.append(.day(day))
            } else {
                group.append(day)
            }
        }
        if !group.isEmpty { sections.append(.daysOff(group)) }
        return sections
    }

    // MARK: Kopf

    private func header(days: [Date], totals: [Date: Int], now: Date) -> some View {
        // Der heutige Tag zählt erst mit, wenn die Zeit nicht mehr läuft
        let running = model.tracker.isRunning
        let done = days.filter { totals[$0, default: 0] > 0 && !(running && calendar.isDate($0, inSameDayAs: now)) }
        let average = done.isEmpty ? nil : done.reduce(0) { $0 + totals[$1, default: 0] } / done.count
        let sum = totals.values.reduce(0, +)
        var perProject: [(project: Project, minutes: Int)] = []
        for day in days {
            for entry in model.split(on: day, total: totals[day, default: 0]) {
                if let i = perProject.firstIndex(where: { $0.project.id == entry.project.id }) {
                    perProject[i].minutes += entry.minutes
                } else {
                    perProject.append(entry)
                }
            }
        }
        return HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 12) {
                    // So breit wie der längste mögliche Titel, damit die Punkte immer an derselben Stelle stehen
                    ZStack(alignment: .leading) {
                        title(month: "September 2026", range: "16.–31.").hidden()
                        title(period)
                    }
                    if let half = period.half {
                        PageDots(half: half)
                    }
                }
                Text(average.map { "Ø \(HoursFormat.decimal($0)) h pro Tag" } ?? "Noch keine Zeit erfasst")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            if csvExportEnabled {
                Button { export(days: days, now: now) } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 32, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 7).strokeBorder(Color(nsColor: .separatorColor)))
                .keyboardShortcut("e", modifiers: .command)
                .accessibilityLabel("Als CSV exportieren")
            }
            HStack(spacing: 0) {
                pageButton("chevron.left", label: "Vorheriger Abschnitt") { page(period.previous) }
                Divider().frame(height: 16)
                Button { page(Period.containing(.now, kind: period.kind, calendar: calendar)) } label: {
                    Text("Heute")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("t", modifiers: .command)
                Divider().frame(height: 16)
                pageButton("chevron.right", label: "Nächster Abschnitt") { page(period.next) }
            }
            .background(RoundedRectangle(cornerRadius: 7).strokeBorder(Color(nsColor: .separatorColor)))
            // Feste Breite für bis zu „999,99 h“, damit Export und Pfeile beim Blättern nicht springen
            PeriodTotal(total: sum, perProject: perProject, mainProjectName: model.mainProjectName)
                .frame(width: 128, alignment: .trailing)
        }
    }

    /// Monatshälfte „November 2026 16.–30.“, ganzer Monat „November 2026“, Woche „KW 48 23.–29. November“.
    @ViewBuilder
    private func title(_ period: Period) -> some View {
        let first = period.first(calendar: calendar)
        let last = period.last(calendar: calendar)
        switch period.kind {
        case .month:
            title(month: Formats.month.string(from: first), range: "")
        case .halfMonth:
            let days = period.dayNumbers ?? 1...15
            title(month: Formats.month.string(from: first), range: "\(days.lowerBound).–\(days.upperBound).")
        case .week:
            let range = period.isWithinOneMonth
                ? "\(Formats.day.string(from: first))–\(Formats.dayMonthName.string(from: last))"
                : "\(Formats.dayShortMonth.string(from: first)) – \(Formats.dayShortMonth.string(from: last))"
            title(month: "KW \(period.weekOfYear ?? 0)", range: range)
        }
    }

    private func title(month: String, range: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(month).font(.system(size: 22, weight: .bold))
            Text(range).font(.system(size: 22)).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func pageButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 32, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// ← und → blättern, außer während in einem Textfeld geschrieben wird.
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let window = event.window, window.isOverview, window.attachedSheet == nil,
                  !(window.firstResponder is NSText),
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function, .capsLock]).isEmpty
            else { return event }
            switch event.specialKey {
            case .leftArrow?: page(period.previous)
            case .rightArrow?: page(period.next)
            default: return event
            }
            return nil
        }
    }

    /// Speichert den angezeigten Abschnitt als CSV für Excel.
    private func export(days: [Date], now: Date) {
        var used = Set<String>()
        let exportDays = days.map { day in
            let spans = model.spans(on: day, now: now)
            let split = model.split(on: day, total: spans.reduce(0) { $0 + $1.minutes })
            used.formUnion(split.map(\.project.key))
            return ExportDay(
                date: day,
                spans: spans,
                isVacation: model.isVacation(day),
                projects: Dictionary(uniqueKeysWithValues: split.map { ($0.project.key, $0.minutes) })
            )
        }
        let projects = model.projects.filter { !$0.isHidden || used.contains($0.key) }.map { (id: $0.key, name: $0.name) }
        let csv = CSVExport.make(days: exportDays, mainProject: model.mainProjectName, projects: projects)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "Arbeitszeit \(Formats.isoDay.string(from: period.first(calendar: calendar))) bis \(Formats.isoDay.string(from: period.last(calendar: calendar))).csv"
        NSApplication.shared.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            // Mit BOM, damit Excel Umlaute richtig erkennt
            try Data(("\u{FEFF}" + csv).utf8).write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func page(_ target: Period) {
        period = target
        offset = Double(TimeWindow.home)
        undo = nil
    }

    // MARK: Uhrzeitleiste

    private var axis: some View {
        HStack(alignment: .bottom, spacing: Self.spacing) {
            HStack {
                Spacer()
                panButton("chevron.left", label: "Frühere Uhrzeiten zeigen", delta: -60)
                    .opacity(offset > 0 ? 1 : 0)
            }
            .frame(width: Self.dateWidth)
            .padding(.bottom, 9)

            GeometryReader { geometry in
                let width = geometry.size.width
                // Mittig über den Stundenlinien der Zeitleisten, auch über den beiden Rändern
                ZStack(alignment: .bottomLeading) {
                    ForEach(0...24, id: \.self) { hour in
                        let position = CGFloat((Double(hour * 60) - offset) / Double(TimeWindow.length)) * width
                        if position > -0.5, position < width + 0.5 {
                            Text("\(hour)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .fixedSize()
                                .frame(width: 0)
                                .offset(x: position)
                        }
                    }
                }
                .frame(width: width, height: geometry.size.height, alignment: .bottomLeading)
                .onAppear { trackWidth = width }
                .onChange(of: width) { trackWidth = width }
            }
            .padding(.bottom, 9)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { axisFrame = $0 }

            HStack(alignment: .bottom) {
                panButton("chevron.right", label: "Spätere Uhrzeiten zeigen", delta: 60)
                    .opacity(offset < TimeWindow.maxOffset ? 1 : 0)
                Spacer()
                Text("Summe").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(width: Self.totalWidth)
            .padding(.bottom, 9)
        }
        .frame(height: 30)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func panButton(_ symbol: String, label: String, delta: Double) -> some View {
        Button {
            offset = min(max((offset + delta) / 60, 0), TimeWindow.maxOffset / 60).rounded() * 60
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Seitliches Wischen und Shift + Mausrad verschieben die Zeit überall in der Liste,
    /// das normale Mausrad nur über der Uhrzeitleiste.
    private func installScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard let window = event.window, window.isOverview, let content = window.contentView, trackWidth > 0 else { return event }
            let point = CGPoint(x: event.locationInWindow.x, y: content.bounds.height - event.locationInWindow.y)
            guard rowsFrame.contains(point) else { return event }
            let factor: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
            let dx = event.scrollingDeltaX * factor
            let dy = event.scrollingDeltaY * factor
            let delta: CGFloat
            if abs(dx) > abs(dy) {
                delta = dx
            } else if event.modifierFlags.contains(.shift) || axisFrame.insetBy(dx: 0, dy: -4).contains(point) {
                delta = dy
            } else {
                return event
            }
            offset = min(max(offset - Double(delta) * Double(TimeWindow.length) / Double(trackWidth), 0), TimeWindow.maxOffset)
            return nil
        }
    }

    #if DEBUG
    /// Zum Prüfen ohne Bildschirmfoto: Mit `-snapshotOverview <Pfad>` gestartet,
    /// speichert die App nur dieses Fenster als PNG, in doppelter Auflösung oder so vielfach wie `-snapshotScale <n>`.
    /// `-snapshotDark YES` zeigt es dafür im dunklen Erscheinungsbild.
    private func writeSnapshotIfRequested() {
        guard let path = UserDefaults.standard.string(forKey: "snapshotOverview") else { return }
        if UserDefaults.standard.bool(forKey: "snapshotDark") { NSApp.appearance = NSAppearance(named: .darkAqua) }
        let scale = max(UserDefaults.standard.double(forKey: "snapshotScale"), 2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard let view = NSApp.windows.first(where: { $0.isOverview })?.contentView,
                  let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width * scale),
                                               pixelsHigh: Int(view.bounds.height * scale), bitsPerSample: 8,
                                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
            else { return }
            image.size = view.bounds.size
            // Der Fensterhintergrund gehört nicht zur Ansicht und wird vorher gemalt
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: image)
            view.effectiveAppearance.performAsCurrentDrawingAppearance {
                NSColor.windowBackgroundColor.setFill()
                view.bounds.fill()
            }
            NSGraphicsContext.restoreGraphicsState()
            view.cacheDisplay(in: view.bounds, to: image)
            try? image.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
    }
    #endif

    // MARK: Rückgängig

    private func edit(day: Date, before: [DaySpan], after: [DaySpan], message: String?) {
        if let message {
            undo = UndoEntry(message: "\(message) am \(Formats.dayMonth.string(from: day))", day: day, spans: before)
        }
        model.apply(after, on: day)
    }

    @ViewBuilder
    private var undoNotice: some View {
        if let undo {
            HStack(spacing: 14) {
                Text(undo.message)
                Button("Rückgängig") {
                    model.apply(undo.spans, on: undo.day)
                    self.undo = nil
                }
                .buttonStyle(.plain)
                .fontWeight(.semibold)
                .foregroundStyle(Color.workYellow)
                .keyboardShortcut("z", modifiers: .command)
            }
            .font(.system(size: 13))
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary))
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
            .padding(.bottom, 20)
            .transition(.opacity)
            .task(id: undo.id) {
                try? await Task.sleep(for: .seconds(6))
                if self.undo?.id == undo.id { self.undo = nil }
            }
        }
    }
}

private struct UndoEntry {
    let id = UUID()
    let message: String
    let day: Date
    let spans: [DaySpan]
}

// MARK: Tageszeile

private struct DayRow: View {
    let model: OverviewModel
    let day: Date
    let spans: [DaySpan]
    let now: Date
    let offset: Double
    /// Während des Ziehens: die Blöcke mit dem gezogenen Griff, für die Summe
    let liveSpans: [DaySpan]?
    let onDraft: ([DaySpan]?) -> Void
    let onEdit: (_ day: Date, _ before: [DaySpan], _ after: [DaySpan], _ message: String?) -> Void
    let onManageProjects: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        let isToday = calendar.isDate(day, inSameDayAs: now)
        // Tage, die laut Einstellungen keine Arbeitstage sind, werden wie Wochenenden gezeigt
        let isWeekend = !Preferences.workdays.contains(calendar.component(.weekday, from: day))
        let isVacation = model.isVacation(day)

        HStack(spacing: OverviewView.spacing) {
            HStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Formats.weekdays[calendar.component(.weekday, from: day) - 1])
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .leading)
                    Text("\(calendar.component(.day, from: day)).")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isWeekend ? .secondary : .primary)
                }
                if isToday {
                    Text("Heute")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.85))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.workYellow))
                }
            }
            .monospacedDigit()
            .fixedSize()
            .frame(width: OverviewView.dateWidth, alignment: .leading)

            if isVacation {
                VacationTrack()
            } else {
                DayTrack(spans: spans, offset: offset, onDraft: onDraft) { after, message in
                    onEdit(day, spans, after, message)
                }
                .opacity(isWeekend && spans.isEmpty ? 0.55 : 1)
            }

            ZStack(alignment: .trailing) {
                Color.clear
                if !(liveSpans ?? spans).isEmpty {
                    DayTotal(model: model, day: day, spans: liveSpans ?? spans, onManageProjects: onManageProjects)
                } else if !isWeekend {
                    VacationButton(isOn: isVacation) { model.toggleVacation(day) }
                }
            }
            .frame(width: OverviewView.totalWidth, alignment: .trailing)
        }
        .frame(height: 44)
        .background(isToday ? Color.todayFill.padding(.horizontal, -24) : nil)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct VacationTrack: View {
    var body: some View {
        ZStack {
            Hatch(color: .workYellowFill, spacing: 12, lineWidth: 6)
            Text("URLAUB")
                .font(.system(size: 11))
                .tracking(0.7)
                .foregroundStyle(.secondary)
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor)))
    }
}

private struct VacationButton: View {
    let isOn: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            PalmShape()
                .fill(isOn || hovered ? Color.primary : Color.secondary)
                .frame(width: 16, height: 16)
                .frame(width: 28, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isOn ? Color.workYellowFill : hovered ? Color.hoverFill : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel(isOn ? "Urlaub entfernen" : "Urlaub eintragen")
    }
}

/// Zusammengeklappte freie Tage: nur eine schmale Zeile mit einem Knopf zum Aufklappen.
private struct DaysOffToggle: View {
    let days: [Date]
    let isOpen: Bool
    let toggle: () -> Void
    @State private var hovered = false

    var body: some View {
        let calendar = Calendar.current
        let label = { (day: Date) in "\(Formats.weekdays[calendar.component(.weekday, from: day) - 1]) \(calendar.component(.day, from: day))." }
        let text = days.count == 1 ? label(days[0]) : "\(label(days[0])) – \(label(days[days.count - 1]))"

        Button(action: toggle) {
            HStack(spacing: 5) {
                Text(text)
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 11))
            .foregroundStyle(hovered ? .primary : .secondary)
            .monospacedDigit()
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .background(Capsule().fill(hovered ? Color.hoverFill : .clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .frame(maxWidth: .infinity)
        .frame(height: 24)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityLabel(isOpen ? "\(text) zuklappen" : "\(text) aufklappen")
    }
}

/// Zwei Punkte für die Monatshälfte; der dunkle gleitet beim Blättern hinüber.
private struct PageDots: View {
    let half: Int
    @State private var shown: Int

    init(half: Int) {
        self.half = half
        _shown = State(initialValue: half)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 5) {
                Circle().fill(Color.track).frame(width: 6, height: 6)
                Circle().fill(Color.track).frame(width: 6, height: 6)
            }
            Capsule()
                .fill(Color.primary)
                .frame(width: 6, height: 6)
                .offset(x: shown == 1 ? 0 : 11)
        }
        .accessibilityHidden(true)
        // Erst nach dem Blättern animieren, damit nur die seitliche Bewegung zu sehen ist
        // und nicht die neue Lage, wenn sich die Fensterhöhe ändert.
        .onChange(of: half) { _, new in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { shown = new }
        }
    }
}

enum Formats {
    static let month = formatter("LLLL yyyy")
    static let weekdays = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
    static let dayMonth = formatter("d.M.")
    static let day = formatter("d.")
    static let dayMonthName = formatter("d. MMMM")
    static let dayShortMonth = formatter("d. MMM")
    static let isoDay = formatter("yyyy-MM-dd")
    static func weekdayDayMonth(_ date: Date) -> String {
        "\(weekdays[Calendar.current.component(.weekday, from: date) - 1]) \(dayMonth.string(from: date))"
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = format
        return formatter
    }
}

extension NSWindow {
    /// Das Fenster der Übersicht, erkannt an der ID der Szene statt am Titel
    var isOverview: Bool { identifier?.rawValue.hasPrefix("overview") == true }
}
