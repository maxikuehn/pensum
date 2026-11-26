import Foundation
import Testing
@testable import PensumCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
}()

@Test func splitFitsIntoTheDayTotal() {
    let split = ProjectSplit.effective([(id: "a", minutes: 60), (id: "b", minutes: 30)], total: 530)
    #expect(split == ["a": 60, "b": 30])
}

@Test func splitIsCutWhenTheDayGetsShorter() {
    // 70 Minuten Arbeitszeit → nur 60 Minuten (volle Viertelstunden) verteilbar
    let split = ProjectSplit.effective([(id: "a", minutes: 45), (id: "b", minutes: 30)], total: 70)
    #expect(split == ["a": 45, "b": 15])
}
