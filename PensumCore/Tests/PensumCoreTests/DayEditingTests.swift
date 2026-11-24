import Foundation
import Testing
@testable import PensumCore

private func m(_ time: String) -> Int {
    let parts = time.split(separator: ":").map { Int($0)! }
    return parts[0] * 60 + parts[1]
}

private func span(_ start: String, _ end: String, running: Bool = false) -> DaySpan {
    DaySpan(start: m(start), end: m(end), isRunning: running)
}

private let day = [span("8:00", "12:00"), span("12:45", "17:00")]

@Test func edgesStopAtNeighbours() {
    let moved = DayEditing.moving(day, index: 0, edge: .end, to: m("13:30"))
    #expect(moved[0].end == m("12:45"))
    let back = DayEditing.moving(day, index: 1, edge: .start, to: m("6:00"))
    #expect(back[1].start == m("12:00"))
}

@Test func edgesStopAtTheDayBorders() {
    #expect(DayEditing.moving(day, index: 0, edge: .start, to: -30)[0].start == 0)
    #expect(DayEditing.moving(day, index: 1, edge: .end, to: 25 * 60)[1].end == 24 * 60)
}

@Test func normalDragKeepsBothBlocks() {
    let moved = DayEditing.moving(day, index: 0, edge: .end, to: m("12:15"))
    #expect(DayEditing.outcome(of: moved, index: 0, edge: .end) == .keep)
    #expect(DayEditing.committing(moved, index: 0, edge: .end) == [span("8:00", "12:15"), span("12:45", "17:00")])
}

@Test func draggingToTheNeighbourJoinsBlocks() {
    let moved = DayEditing.moving(day, index: 1, edge: .start, to: m("11:00"))
    #expect(DayEditing.outcome(of: moved, index: 1, edge: .start) == .join)
    #expect(DayEditing.committing(moved, index: 1, edge: .start) == [span("8:00", "17:00")])
}

@Test func squeezingABlockDeletesIt() {
    let moved = DayEditing.moving(day, index: 0, edge: .end, to: m("8:05"))
    #expect(DayEditing.outcome(of: moved, index: 0, edge: .end) == .delete)
    #expect(DayEditing.committing(moved, index: 0, edge: .end) == [span("12:45", "17:00")])
}

@Test func removingAPauseKeepsTheRunningState() {
    let running = [span("8:00", "10:40"), span("10:50", "11:25", running: true)]
    #expect(DayEditing.removingPause(running, after: 0) == [span("8:00", "11:25", running: true)])
}

@Test func pauseIsCentredOnTheClick() {
    let result = DayEditing.insertingPause(into: day, at: m("10:00"))
    #expect(result == [span("8:00", "9:55"), span("10:10", "12:00"), span("12:45", "17:00")])
}

@Test func pauseStaysInsideTheBlock() {
    let result = DayEditing.insertingPause(into: day, at: m("8:01"))
    #expect(result?[0] == span("8:00", "8:05"))
    #expect(result?[1] == span("8:20", "12:00"))
}

@Test func pauseInARunningBlockKeepsItRunning() {
    let result = DayEditing.insertingPause(into: [span("8:00", "11:25", running: true)], at: m("10:00"))
    #expect(result == [span("8:00", "9:55"), span("10:10", "11:25", running: true)])
}

@Test func noPauseInShortBlocksOrOutsideBlocks() {
    #expect(DayEditing.insertingPause(into: [span("8:00", "8:20")], at: m("8:10")) == nil)
    #expect(DayEditing.insertingPause(into: day, at: m("12:30")) == nil)
}

@Test func blockIsInsertedIntoFreeSpace() {
    #expect(DayEditing.insertingBlock(into: [], at: m("9:10")) == [span("8:55", "9:25")])
    #expect(DayEditing.insertingBlock(into: day, at: m("18:00")) == day + [span("17:45", "18:15")])
}

@Test func blockStaysInsideAGap() {
    // Lücke 12:05–12:40 (je 5 Minuten Abstand zu den Nachbarn)
    #expect(DayEditing.insertingBlock(into: day, at: m("12:20")) == [span("8:00", "12:00"), span("12:05", "12:35"), span("12:45", "17:00")])
}

@Test func blockShrinksToFitASmallGap() {
    let tight = [span("8:00", "12:00"), span("12:20", "17:00")]
    #expect(DayEditing.insertingBlock(into: tight, at: m("12:10")) == [span("8:00", "12:00"), span("12:05", "12:15"), span("12:20", "17:00")])
}

@Test func noBlockWhenThereIsNoRoom() {
    let tight = [span("8:00", "12:00"), span("12:10", "17:00")]
    #expect(DayEditing.insertingBlock(into: tight, at: m("12:05")) == nil)
}

@Test func draggingOverFreeSpaceCreatesABlock() {
    let result = DayEditing.creatingBlock(in: day, from: m("17:30"), to: m("19:00"))
    #expect(result?.spans == day + [span("17:30", "19:00")])
    #expect(result?.index == 2)
}

@Test func draggingBackwardsWorksToo() {
    let result = DayEditing.creatingBlock(in: [], from: m("10:00"), to: m("8:30"))
    #expect(result?.spans == [span("8:30", "10:00")])
}

@Test func draggedBlockStopsBeforeTheNextBlock() {
    let result = DayEditing.creatingBlock(in: day, from: m("12:10"), to: m("15:00"))
    #expect(result?.spans == [span("8:00", "12:00"), span("12:10", "12:40"), span("12:45", "17:00")])
    #expect(result?.index == 1)
}

@Test func draggingInsideABlockCreatesNothing() {
    #expect(DayEditing.creatingBlock(in: day, from: m("9:00"), to: m("10:00")) == nil)
}

@Test func draggingOverABlockCreatesAPause() {
    let result = DayEditing.creatingPause(in: day, from: m("10:00"), to: m("10:30"))
    #expect(result?.spans == [span("8:00", "10:00"), span("10:30", "12:00"), span("12:45", "17:00")])
    #expect(result?.start == m("10:00"))
    #expect(result?.end == m("10:30"))
}

@Test func pauseDraggedBackwardsAndPastTheEdgeShortensTheBlock() {
    let result = DayEditing.creatingPause(in: day, from: m("16:30"), to: m("16:00"))
    #expect(result?.spans == [span("8:00", "12:00"), span("12:45", "16:00"), span("16:30", "17:00")])
    let trimmed = DayEditing.creatingPause(in: day, from: m("16:30"), to: m("18:00"))
    #expect(trimmed?.spans == [span("8:00", "12:00"), span("12:45", "16:30")])
}

@Test func pauseInRunningBlockKeepsTheRestRunning() {
    let result = DayEditing.creatingPause(in: [span("8:00", "11:25", running: true)], from: m("10:00"), to: m("10:20"))
    #expect(result?.spans == [span("8:00", "10:00"), span("10:20", "11:25", running: true)])
}

@Test func noPauseOutsideBlocksOrWhenTooShort() {
    #expect(DayEditing.creatingPause(in: day, from: m("12:20"), to: m("13:00")) == nil)
    #expect(DayEditing.creatingPause(in: day, from: m("10:00"), to: m("10:00")) == nil)
}
