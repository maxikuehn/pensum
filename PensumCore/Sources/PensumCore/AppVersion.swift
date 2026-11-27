import Foundation

/// Eine Versionsnummer wie „0.4“ oder „v1.2.3“, Teil für Teil als Zahl verglichen.
public struct AppVersion: Comparable, Sendable {
    public let parts: [Int]

    public init(_ text: String) {
        let trimmed = text.hasPrefix("v") ? String(text.dropFirst()) : text
        parts = trimmed.split(separator: ".").map { Int($0) ?? 0 }
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        for index in 0..<max(lhs.parts.count, rhs.parts.count) {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}
