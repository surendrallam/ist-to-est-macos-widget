import Foundation

/// Human-readable descriptions of the gap between two zones.
public enum OffsetDescription {
    /// "9h 30m behind", "5h 30m ahead", "1h behind" or "Same time".
    public static func relative(_ seconds: Int) -> String {
        guard seconds != 0 else { return "Same time" }
        return "\(duration(seconds)) \(seconds < 0 ? "behind" : "ahead")"
    }

    /// "New York is 9h 30m behind New Delhi" / "New Delhi is 9h 30m ahead of New York".
    public static func sentence(_ seconds: Int, subject: String, reference: String) -> String {
        guard seconds != 0 else { return "\(subject) and \(reference) show the same time" }
        let relation = seconds < 0 ? "behind" : "ahead of"
        return "\(subject) is \(duration(seconds)) \(relation) \(reference)"
    }

    /// "9h 30m", "10h", "45m" — the magnitude only.
    public static func duration(_ seconds: Int) -> String {
        let totalMinutes = abs(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, _): return "\(minutes)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(minutes)m"
        }
    }

    /// Signed clock-style offset: "−9:30", "+5:30", "±0:00".
    /// Uses a true minus sign (U+2212) so it lines up with "+" in tabular layouts.
    public static func compact(_ seconds: Int) -> String {
        let totalMinutes = abs(seconds) / 60
        let sign = seconds < 0 ? "\u{2212}" : (seconds > 0 ? "+" : "\u{00B1}")
        let minutes = totalMinutes % 60
        return "\(sign)\(totalMinutes / 60):\(minutes < 10 ? "0" : "")\(minutes)"
    }

    /// "−1 day", "+1 day", "+2 days", or an empty string for the same day.
    public static func dayShift(_ days: Int) -> String {
        guard days != 0 else { return "" }
        let sign = days < 0 ? "\u{2212}" : "+"
        return "\(sign)\(abs(days)) \(abs(days) == 1 ? "day" : "days")"
    }
}
