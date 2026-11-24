import ShiftCore
import SwiftData
import SwiftUI

/// Tagessumme in der Übersicht. Ein Klick öffnet die Aufteilung auf Nebenprojekte.
struct DayTotal: View {
    let model: OverviewModel
    let day: Date
    let spans: [DaySpan]
    let onManageProjects: () -> Void

    @State private var isOpen = false
    @State private var hovered = false

    var body: some View {
        let total = spans.reduce(0) { $0 + $1.minutes }
        let split = model.split(on: day, total: total)

        Button {
            isOpen.toggle()
        } label: {
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(HoursFormat.decimal(total)) h")
                    .font(.system(size: 15, weight: .semibold))
                if !split.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(split, id: \.project.id) { entry in
                            ProjectChip(color: .project(entry.project.colorIndex), text: HoursFormat.decimal(entry.minutes))
                        }
                    }
                    .font(.system(size: 11))
                    .fixedSize()
                }
            }
            .monospacedDigit()
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(isOpen || hovered ? Color.hoverFill : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, -6)
        .onHover { hovered = $0 }
        .accessibilityLabel("Projektzeit am \(Formats.dayMonth.string(from: day)) aufteilen")
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            SplitPopover(model: model, day: day, total: total) {
                isOpen = false
                onManageProjects()
            }
        }
    }
}

/// Stunden je Nebenprojekt in Viertelstunden; der Rest zählt zum Hauptprojekt.
private struct SplitPopover: View {
    let model: OverviewModel
    let day: Date
    let total: Int
    let onManage: () -> Void

    var body: some View {
        let split = model.split(on: day, total: total)
        let used = split.reduce(0) { $0 + $1.minutes }
        let available = total / ProjectSplit.quarter * ProjectSplit.quarter - used
        let listed = model.projects.filter { project in !project.isHidden || split.contains { $0.project.id == project.id } }

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(Formats.weekdayDayMonth(day))
                Spacer()
                Text("\(HoursFormat.decimal(total)) h gesamt")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            ForEach(listed) { project in
                let minutes = split.first { $0.project.id == project.id }?.minutes ?? 0
                HStack(spacing: 9) {
                    Circle().fill(Color.project(project.colorIndex)).frame(width: 8, height: 8)
                    Text(project.name).lineLimit(1)
                    Spacer()
                    QuarterStepper(minutes: minutes, canAdd: available >= ProjectSplit.quarter) { delta in
                        model.changeAllocation(of: project, on: day, by: delta, total: total)
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 32)
            }

            Divider().padding(.vertical, 6)
            HStack(spacing: 9) {
                Circle().fill(Color.shiftYellow).frame(width: 8, height: 8)
                Text(model.mainProjectName).lineLimit(1)
                Spacer()
                Text("\(HoursFormat.decimal(total - used)) h").monospacedDigit().padding(.trailing, 4)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .frame(minHeight: 28)

            Divider().padding(.vertical, 6)
            Button("Projekte verwalten…", action: onManage)
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 2)
        }
        .font(.system(size: 13))
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(width: 270)
    }
}

private struct QuarterStepper: View {
    let minutes: Int
    let canAdd: Bool
    let change: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            stepButton("−", delta: -ProjectSplit.quarter, enabled: minutes > 0)
            Text("\(HoursFormat.decimal(minutes)) h")
                .font(.system(size: 12))
                .monospacedDigit()
                .foregroundStyle(minutes > 0 ? .primary : .secondary)
                .frame(width: 52)
            stepButton("+", delta: ProjectSplit.quarter, enabled: canAdd)
        }
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor)))
    }

    private func stepButton(_ title: String, delta: Int, enabled: Bool) -> some View {
        Button { change(delta) } label: {
            Text(title)
                .font(.system(size: 15))
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(delta > 0 ? "Eine Viertelstunde mehr" : "Eine Viertelstunde weniger")
    }
}

/// Liste der Nebenprojekte: umbenennen, Farbe wechseln, ziehen zum Sortieren, ausblenden.
struct ProjectManager: View {
    @Bindable var model: OverviewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Projekte")
                .font(.system(size: 15, weight: .semibold))
                .padding(.bottom, 4)
            Text("Zeit, die du keinem Nebenprojekt zuordnest, zählt zum Hauptprojekt. Ziehe Projekte, um die Reihenfolge zu ändern.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            List {
                HStack(spacing: 10) {
                    Color.clear.frame(width: 12)
                    Circle().fill(Color.shiftYellow).frame(width: 12, height: 12)
                    TextField("Hauptprojekt", text: $model.mainProjectName)
                        .textFieldStyle(.plain)
                    Text("Restzeit").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .moveDisabled(true)

                ForEach(model.projects) { project in
                    ProjectRow(project: project, focused: $focused) { model.save() }
                }
                .onMove { model.moveProjects(from: $0, to: $1) }
            }
            .listStyle(.bordered)
            .frame(minHeight: 180)

            HStack {
                Button("Projekt hinzufügen") {
                    focused = model.addProject().id
                }
                Spacer()
                Button("Fertig") {
                    model.save()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 14)
        }
        .padding(18)
        .frame(width: 400)
    }
}

private struct ProjectRow: View {
    @Bindable var project: Project
    var focused: FocusState<UUID?>.Binding
    let changed: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 12)
            Button {
                project.colorIndex = (project.colorIndex + 1) % Color.project.count
                changed()
            } label: {
                Circle().fill(Color.project(project.colorIndex)).frame(width: 12, height: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Farbe von \(project.name) wechseln")
            TextField("Projektname", text: $project.name)
                .textFieldStyle(.plain)
                .focused(focused, equals: project.id)
                .onSubmit(changed)
            Button {
                project.isHidden.toggle()
                changed()
            } label: {
                Image(systemName: project.isHidden ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(project.isHidden ? "Einblenden" : "Ausblenden")
        }
        .opacity(project.isHidden ? 0.5 : 1)
    }
}
