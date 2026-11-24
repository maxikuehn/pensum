import PensumCore
import SwiftUI

/// Sichtbares Zeitfenster der Übersicht, wie in den Einstellungen festgelegt (standardmäßig 7–20 Uhr).
enum TimeWindow {
    static var home: Int { Preferences.dayStartHour * 60 }
    static var length: Int { (Preferences.dayEndHour - Preferences.dayStartHour) * 60 }
    static var maxOffset: Double { Double(DayEditing.dayEnd - length) }
}

/// Die Zeitleiste eines Tages. Zeigt die Blöcke und nimmt alle Bearbeitungen mit der Maus entgegen.
/// `commit` bekommt die neuen Blöcke und, wenn es etwas zum Rückgängigmachen gibt, einen Hinweistext.
struct DayTrack: View {
    let spans: [DaySpan]
    let offset: Double
    /// Meldet die Blöcke während des Ziehens (und `nil` danach), damit die Summen mitlaufen.
    var onDraft: ([DaySpan]?) -> Void = { _ in }
    let commit: (_ spans: [DaySpan], _ undoMessage: String?) -> Void

    @State private var draft: [DaySpan]?
    @State private var dragging: (index: Int, edge: SpanEdge, minute: Int)?
    @State private var hoveredGap: Int?
    /// Gerade wird über eine freie Stelle gezogen, um Arbeitszeit anzulegen.
    @State private var creating = false
    /// Gerade wird über einen Block gezogen, um eine Pause anzulegen.
    @State private var pausing: (start: Int, end: Int, minute: Int)?

    private static let height: CGFloat = 28
    private static let handleWidth: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let shown = draft ?? spans
            let x = { (minute: Int) -> CGFloat in CGFloat((Double(minute) - offset) / Double(TimeWindow.length)) * width }
            let minute = { (x: CGFloat) -> Double in offset + Double(x / width) * Double(TimeWindow.length) }

            ZStack(alignment: .topLeading) {
                background(width: width, x: x)
                    .onTapGesture(count: 2, coordinateSpace: .named("track")) { location in
                        guard let result = DayEditing.insertingBlock(into: spans, at: Int(minute(location.x))) else { return }
                        let added = result.first { !spans.contains($0) }
                        commit(result, added.map { "Arbeitszeit \(clock($0.start)) – \(clock($0.end)) eingefügt" })
                    }
                    .simultaneousGesture(createGesture(minute: minute))

                ForEach(Array(shown.indices.dropLast()), id: \.self) { index in
                    gap(after: index, in: shown, x: x)
                }

                ForEach(Array(shown.enumerated()), id: \.offset) { index, span in
                    block(span, index: index, in: shown, x: x, minute: minute)
                }

                edgeHints(shown)
            }
            .frame(width: width, height: Self.height, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .coordinateSpace(.named("track"))
            .overlay { bubble(in: shown, x: x) }
        }
        .frame(height: Self.height)
    }

    /// Über eine freie Stelle ziehen legt genau diesen Bereich als Arbeitszeit an.
    private func createGesture(minute: @escaping (CGFloat) -> Double) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("track"))
            .onChanged { value in
                let from = DayEditing.snap(minute(value.startLocation.x))
                let to = DayEditing.snap(minute(value.location.x))
                guard let result = DayEditing.creatingBlock(in: spans, from: from, to: to) else { return }
                let span = result.spans[result.index]
                creating = true
                draft = result.spans
                onDraft(result.spans)
                dragging = to >= from ? (result.index, .end, span.end) : (result.index, .start, span.start)
            }
            .onEnded { _ in
                let created = creating ? draft.flatMap { spans in dragging.map { spans[$0.index] } } : nil
                let result = draft
                creating = false
                draft = nil
                dragging = nil
                onDraft(nil)
                guard let created, let result, created.minutes >= DayEditing.deleteBelow else { return }
                commit(result, "Arbeitszeit \(clock(created.start)) – \(clock(created.end)) eingefügt")
            }
    }

    /// Über einen Block ziehen legt genau diesen Bereich als Pause an.
    private func pauseGesture(minute: @escaping (CGFloat) -> Double) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("track"))
            .onChanged { value in
                let from = DayEditing.snap(minute(value.startLocation.x))
                let to = DayEditing.snap(minute(value.location.x))
                if let result = DayEditing.creatingPause(in: spans, from: from, to: to) {
                    draft = result.spans
                    pausing = (result.start, result.end, to >= from ? result.end : result.start)
                    onDraft(result.spans)
                } else {
                    draft = nil
                    pausing = nil
                    onDraft(nil)
                }
            }
            .onEnded { _ in
                let result = draft
                let pause = pausing
                draft = nil
                pausing = nil
                onDraft(nil)
                guard let result, let pause else { return }
                commit(result, "Pause \(clock(pause.start)) – \(clock(pause.end)) eingefügt")
            }
    }

    // MARK: Teile

    private func background(width: CGFloat, x: @escaping (Int) -> CGFloat) -> some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.track))
            for hour in 1..<24 {
                let position = x(hour * 60)
                guard position > 0, position < size.width else { continue }
                context.fill(Path(CGRect(x: position - 0.5, y: 0, width: 1, height: size.height)), with: .color(.gridLine))
            }
        }
        .contentShape(Rectangle())
    }

    private func gap(after index: Int, in shown: [DaySpan], x: (Int) -> CGFloat) -> some View {
        let start = shown[index].end
        let end = shown[index + 1].start
        let hovered = hoveredGap == index && dragging == nil && pausing == nil
        return ZStack {
            Hatch()
                .background(hovered ? Color.dangerFill : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            if hovered {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.dangerRed))
                    .fixedSize()
            }
        }
        .frame(width: max(0, x(end) - x(start)), height: Self.height - 10)
        // etwas breiter klickbar, damit auch kurze Pausen gut zu treffen sind
        .contentShape(Rectangle().inset(by: -6))
        .offset(x: x(start), y: 5)
        .onHover { hoveredGap = $0 ? index : (hoveredGap == index ? nil : hoveredGap) }
        .onTapGesture {
            hoveredGap = nil
            commit(DayEditing.removingPause(spans, after: index), "Pause \(clock(start)) – \(clock(end)) entfernt")
        }
        .accessibilityElement()
        .accessibilityLabel("Pause \(clock(start)) bis \(clock(end)) entfernen")
        .accessibilityAddTraits(.isButton)
    }

    private func block(_ span: DaySpan, index: Int, in shown: [DaySpan], x: @escaping (Int) -> CGFloat, minute: @escaping (CGFloat) -> Double) -> some View {
        let width = max(0, x(span.end) - x(span.start))
        let armed = !creating && dragging?.index == index && span.minutes < DayEditing.deleteBelow
        let color = armed ? Color.dangerRed : .workYellow

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(armed ? Color.dangerFill : .workYellowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(color, lineWidth: 3)
                )
                .simultaneousGesture(pauseGesture(minute: minute))
                .onTapGesture(count: 2, coordinateSpace: .named("track")) { location in
                    guard let result = DayEditing.insertingPause(into: spans, at: Int(minute(location.x))) else { return }
                    let pause = zip(result, result.dropFirst()).map { ($0.end, $1.start) }.first { pair in
                        !zip(spans, spans.dropFirst()).contains { $0.end == pair.0 && $1.start == pair.1 }
                    }
                    commit(result, pause.map { "Pause \(clock($0.0)) – \(clock($0.1)) eingefügt" })
                }

            if width > 92 {
                Text("\(clock(span.start)) – \(span.isRunning ? "läuft" : clock(span.end))")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: width - 2 * Self.handleWidth)
                    .offset(x: Self.handleWidth)
                    .allowsHitTesting(false)
            }

            handle(.start, index: index, color: armed ? .dangerRed : .workYellow, minute: minute)

            if span.isRunning {
                PulsingEdge(color: color)
                    .offset(x: width - 2)
            } else {
                handle(.end, index: index, color: armed ? .dangerRed : .workYellow, minute: minute)
                    .offset(x: width - Self.handleWidth)
            }
        }
        .frame(width: width, height: Self.height, alignment: .leading)
        .offset(x: x(span.start))
    }

    private func handle(_ edge: SpanEdge, index: Int, color: Color, minute: @escaping (CGFloat) -> Double) -> some View {
        let isActive = dragging?.index == index && dragging?.edge == edge
        let armed = color == .dangerRed
        return UnevenRoundedRectangle(
            topLeadingRadius: edge == .start ? 7 : 0,
            bottomLeadingRadius: edge == .start ? 7 : 0,
            bottomTrailingRadius: edge == .end ? 7 : 0,
            topTrailingRadius: edge == .end ? 7 : 0,
            style: .continuous
        )
        .fill(color)
        .overlay {
            Image(systemName: edge == .start ? "chevron.left" : "chevron.right")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(armed ? Color.white : Color.black.opacity(0.85))
        }
        .frame(width: Self.handleWidth, height: Self.height)
        .contentShape(Rectangle())
        .pointerStyle(.columnResize)
        .zIndex(isActive ? 1 : 0)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("track"))
                .onChanged { value in
                    let target = DayEditing.snap(minute(value.location.x))
                    let moved = DayEditing.moving(spans, index: index, edge: edge, to: target)
                    draft = moved
                    onDraft(moved)
                    dragging = (index, edge, edge == .start ? moved[index].start : moved[index].end)
                }
                .onEnded { _ in
                    guard let moved = draft else { return }
                    let outcome = DayEditing.outcome(of: moved, index: index, edge: edge)
                    let result = DayEditing.committing(moved, index: index, edge: edge)
                    draft = nil
                    dragging = nil
                    onDraft(nil)
                    switch outcome {
                    case .keep: commit(result, nil)
                    case .delete: commit(result, "Arbeitszeit gelöscht")
                    case .join: commit(result, "Arbeitszeiten verbunden")
                    }
                }
        )
        .accessibilityLabel(edge == .start ? "Beginn ändern" : "Ende ändern")
    }

    /// Gelber Verlauf am Rand, wenn außerhalb des sichtbaren Fensters gearbeitet wurde.
    @ViewBuilder
    private func edgeHints(_ shown: [DaySpan]) -> some View {
        HStack(spacing: 0) {
            if shown.contains(where: { Double($0.start) < offset }) {
                LinearGradient(colors: [.workYellow, .workYellow.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 10)
            }
            Spacer(minLength: 0)
            if shown.contains(where: { Double($0.end) > offset + Double(TimeWindow.length) }) {
                LinearGradient(colors: [.workYellow.opacity(0), .workYellow], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 10)
            }
        }
        .allowsHitTesting(false)
    }

    /// Uhrzeit bzw. Hinweis über dem gezogenen Griff.
    @ViewBuilder
    private func bubble(in shown: [DaySpan], x: (Int) -> CGFloat) -> some View {
        if let pausing {
            bubbleLabel("Pause \(clock(pausing.start)) – \(clock(pausing.end))", at: x(pausing.minute), danger: false)
        } else if let dragging {
            let outcome = creating ? .keep : DayEditing.outcome(of: shown, index: dragging.index, edge: dragging.edge)
            let position = x(dragging.minute)
            let text = switch outcome {
            case .delete: "Löschen"
            case .join: "Verbinden"
            case .keep: creating
                ? "\(clock(shown[dragging.index].start)) – \(clock(shown[dragging.index].end))"
                : clock(dragging.minute)
            }
            bubbleLabel(text, at: position, danger: outcome == .delete)
        }
    }
}

extension DayTrack {
    fileprivate func bubbleLabel(_ text: String, at position: CGFloat, danger: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(danger ? Color.white : Color(nsColor: .windowBackgroundColor))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(danger ? Color.dangerRed : .primary))
            .fixedSize()
            .position(x: position, y: -12)
            .allowsHitTesting(false)
    }
}

/// Rechter Rand eines laufenden Blocks.
private struct PulsingEdge: View {
    let color: Color
    @State private var dimmed = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 4)
            .opacity(dimmed ? 0.35 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever()) { dimmed = true }
            }
    }
}

func clock(_ minutes: Int) -> String {
    "\(minutes / 60):" + String(format: "%02d", minutes % 60)
}
