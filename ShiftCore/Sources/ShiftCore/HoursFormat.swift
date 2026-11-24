import Foundation

public enum HoursFormat {
    /// Dauer als Dezimalstunden mit Komma, z. B. 495 Minuten → „8,25“.
    public static func decimal(_ minutes: Int) -> String {
        let hundredths = Int((Double(minutes) / 60 * 100).rounded())
        return "\(hundredths / 100)," + String(format: "%02d", hundredths % 100)
    }
}
