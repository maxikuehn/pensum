import Foundation

/// Eine erfasste Arbeitsphase mit sekundengenauen Zeitpunkten. `end == nil` heißt: läuft gerade.
public struct WorkInterval: Equatable, Sendable {
    public var start: Date
    public var end: Date?

    public init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }
}

/// Ein gerundeter Arbeitsblock innerhalb eines Tages, in Minuten seit Mitternacht.
public struct DaySpan: Equatable, Sendable {
    public var start: Int
    public var end: Int
    public var isRunning: Bool

    public var minutes: Int { end - start }

    public init(start: Int, end: Int, isRunning: Bool = false) {
        self.start = start
        self.end = end
        self.isRunning = isRunning
    }
}

/// Macht aus den erfassten Arbeitsphasen eines Tages die Blöcke, die angezeigt und gezählt werden.
public struct DayCalculator: Sendable {
    public static let step = 5

    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Rundet zu Gunsten des Nutzers: Beginn abrunden, Ende aufrunden, jeweils auf 5 Minuten.
    /// Blöcke, die sich danach berühren oder überlappen, werden zu einem verbunden.
    /// Ein Block gehört zu dem Tag, an dem er beginnt.
    public func spans(of intervals: [WorkInterval], on day: Date, now: Date) -> [DaySpan] {
        let midnight = calendar.startOfDay(for: day)
        let rounded = intervals
            .filter { calendar.isDate($0.start, inSameDayAs: midnight) }
            .sorted { $0.start < $1.start }
            .map { interval in
                let start = Self.floor(interval.start.timeIntervalSince(midnight) / 60)
                let end = Self.ceil((interval.end ?? max(now, interval.start)).timeIntervalSince(midnight) / 60)
                return DaySpan(start: start, end: max(start, end), isRunning: interval.end == nil)
            }

        var merged: [DaySpan] = []
        for span in rounded where span.minutes > 0 || span.isRunning {
            if var last = merged.last, span.start <= last.end {
                last.end = max(last.end, span.end)
                last.isRunning = last.isRunning || span.isRunning
                merged[merged.count - 1] = last
            } else {
                merged.append(span)
            }
        }
        return merged
    }

    public func totalMinutes(of intervals: [WorkInterval], on day: Date, now: Date) -> Int {
        spans(of: intervals, on: day, now: now).reduce(0) { $0 + $1.minutes }
    }

    static func floor(_ minutes: Double) -> Int {
        Int((minutes / Double(step)).rounded(.down)) * step
    }

    static func ceil(_ minutes: Double) -> Int {
        Int((minutes / Double(step)).rounded(.up)) * step
    }
}
