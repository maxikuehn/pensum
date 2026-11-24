import Foundation

public enum SpanEdge: Sendable {
    case start
    case end
}

/// Was beim Loslassen eines Griffs passiert.
public enum EditOutcome: Equatable, Sendable {
    case keep
    /// Fast ganz zusammengeschoben: Der Block wird gelöscht.
    case delete
    /// Bis an den Nachbarblock gezogen: Beide werden verbunden.
    case join
}

/// Bearbeitungen in der Übersicht. Arbeitet auf den gerundeten Blöcken eines Tages (Minuten seit Mitternacht)
/// und gibt immer eine neue Liste zurück.
public enum DayEditing {
    public static let step = 5
    public static let pauseLength = 15
    public static let blockLength = 30
    /// Kürzer zusammengeschobene Blöcke werden beim Loslassen gelöscht.
    public static let deleteBelow = 10
    public static let dayEnd = 24 * 60

    public static func snap(_ minute: Double) -> Int {
        Int((minute / Double(step)).rounded()) * step
    }

    /// Wie weit ein Griff gezogen werden kann: bis an den Nachbarblock bzw. den Tagesrand.
    public static func bounds(of spans: [DaySpan], index: Int, edge: SpanEdge) -> ClosedRange<Int> {
        let span = spans[index]
        switch edge {
        case .start:
            return (index > 0 ? spans[index - 1].end : 0)...span.end
        case .end:
            return span.start...(index < spans.count - 1 ? spans[index + 1].start : dayEnd)
        }
    }

    public static func moving(_ spans: [DaySpan], index: Int, edge: SpanEdge, to minute: Int) -> [DaySpan] {
        let range = bounds(of: spans, index: index, edge: edge)
        let clamped = min(max(minute, range.lowerBound), range.upperBound)
        var result = spans
        switch edge {
        case .start: result[index].start = clamped
        case .end: result[index].end = clamped
        }
        return result
    }

    public static func outcome(of spans: [DaySpan], index: Int, edge: SpanEdge) -> EditOutcome {
        let span = spans[index]
        if span.minutes < deleteBelow { return .delete }
        switch edge {
        case .start:
            return index > 0 && span.start <= spans[index - 1].end ? .join : .keep
        case .end:
            return index < spans.count - 1 && span.end >= spans[index + 1].start ? .join : .keep
        }
    }

    /// Wendet beim Loslassen Löschen bzw. Verbinden an.
    public static func committing(_ spans: [DaySpan], index: Int, edge: SpanEdge) -> [DaySpan] {
        switch outcome(of: spans, index: index, edge: edge) {
        case .keep:
            return spans
        case .delete:
            var result = spans
            result.remove(at: index)
            return result
        case .join:
            return removingPause(spans, after: edge == .start ? index - 1 : index)
        }
    }

    /// Entfernt die Pause nach dem Block `index`, die beiden Blöcke werden einer.
    public static func removingPause(_ spans: [DaySpan], after index: Int) -> [DaySpan] {
        var result = spans
        result[index].end = result[index + 1].end
        result[index].isRunning = result[index + 1].isRunning
        result.remove(at: index + 1)
        return result
    }

    /// Fügt mitten in einen Block eine 15-Minuten-Pause ein, zentriert auf `minute`.
    /// `nil`, wenn dort kein Block ist oder er zu kurz ist.
    public static func insertingPause(into spans: [DaySpan], at minute: Int) -> [DaySpan]? {
        guard let index = spans.firstIndex(where: { $0.start <= minute && minute <= $0.end }) else { return nil }
        let span = spans[index]
        guard span.minutes >= pauseLength + 2 * step else { return nil }
        let start = min(
            max(snap(Double(minute) - Double(pauseLength) / 2), span.start + step),
            span.end - pauseLength - step
        )
        var result = spans
        result[index] = DaySpan(start: span.start, end: start)
        result.insert(DaySpan(start: start + pauseLength, end: span.end, isRunning: span.isRunning), at: index + 1)
        return result
    }

    /// Legt beim Ziehen über eine freie Stelle einen Block von `from` bis `to` an (in beide Richtungen).
    /// Der Block bleibt in der freien Lücke, in der das Ziehen begann; `nil`, wenn dort schon ein Block ist.
    /// Gibt die neuen Blöcke und die Position des neuen Blocks zurück.
    public static func creatingBlock(in spans: [DaySpan], from: Int, to: Int) -> (spans: [DaySpan], index: Int)? {
        guard !spans.contains(where: { $0.start <= from && from <= $0.end }) else { return nil }
        let index = spans.firstIndex { from < $0.start } ?? spans.count
        let lower = index > 0 ? spans[index - 1].end + step : 0
        let upper = index < spans.count ? spans[index].start - step : dayEnd
        guard lower < upper else { return nil }
        let clamp = { (minute: Int) in min(max(minute, lower), upper) }
        let a = clamp(from)
        let b = clamp(to)
        var result = spans
        result.insert(DaySpan(start: min(a, b), end: max(a, b)), at: index)
        return (result, index)
    }

    /// Fügt in eine freie Stelle einen 30-Minuten-Block ein, zentriert auf `minute`.
    /// Ist weniger Platz, wird er kürzer; `nil`, wenn kein sinnvoller Platz ist.
    public static func insertingBlock(into spans: [DaySpan], at minute: Int) -> [DaySpan]? {
        var lower = 0
        var upper = dayEnd
        var index = spans.count
        for (i, span) in spans.enumerated() {
            if minute < span.start {
                upper = span.start - step
                index = i
                break
            }
            lower = span.end + step
        }
        guard upper - lower >= deleteBelow else { return nil }
        let length = min(blockLength, upper - lower)
        let start = min(upper - length, max(lower, snap(Double(minute) - Double(length) / 2)))
        var result = spans
        result.insert(DaySpan(start: start, end: start + length), at: index)
        return result
    }
}
