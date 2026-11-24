import Foundation

public struct TimeFormatter {
    public static func format(seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else {
            return "00:00.0"
        }
        let totalHundredths = Int((seconds * 10).rounded())
        let totalSeconds = totalHundredths / 10
        let tenths = totalHundredths % 10
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        let hours = mins / 60
        let remainingMins = mins % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%1d", hours, remainingMins, secs, tenths)
        } else {
            return String(format: "%02d:%02d.%1d", mins, secs, tenths)
        }
    }

    public static func formatDetailed(seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else {
            return "00:00.00"
        }
        let totalCenti = Int((seconds * 100).rounded())
        let totalSeconds = totalCenti / 100
        let centis = totalCenti % 100
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d.%02d", mins, secs, centis)
    }

    public static func formatDurationShort(seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let mins = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "\(mins)m \(secs)s"
        }
    }
}
