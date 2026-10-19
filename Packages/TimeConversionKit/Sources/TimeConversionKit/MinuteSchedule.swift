import Foundation

/// Timeline dates for clock widgets.
public enum MinuteSchedule {
    /// `date` itself, followed by the next `count − 1` minute boundaries.
    ///
    /// Every time zone in use today has a whole-minute UTC offset (IST is +5:30),
    /// so UTC minute boundaries are minute boundaries in both zones.
    public static func dates(startingAt date: Date, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        let firstBoundary = (date.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60 + 60
        let boundaries = (0..<(count - 1)).map {
            Date(timeIntervalSinceReferenceDate: firstBoundary + Double($0) * 60)
        }
        return [date] + boundaries
    }
}
