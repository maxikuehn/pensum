import Testing
@testable import PensumCore

@Test func versionsCompareNumerically() {
    #expect(AppVersion("0.10") > AppVersion("0.9"))
    #expect(AppVersion("0.5") > AppVersion("0.4"))
    #expect(AppVersion("1.0") > AppVersion("0.99"))
    #expect(AppVersion("0.4.1") > AppVersion("0.4"))
}

@Test func tagPrefixAndTrailingZerosDoNotMatter() {
    #expect(AppVersion("v0.4") == AppVersion("0.4"))
    #expect(AppVersion("0.4.0") == AppVersion("0.4"))
    #expect(!(AppVersion("v0.4") > AppVersion("0.4")))
}
