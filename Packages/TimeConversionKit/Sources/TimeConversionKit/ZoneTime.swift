import Foundation

/// The wall-clock reading of a ``WorldZone`` at one instant.
public struct ZoneTime: Hashable, Sendable {
    public let zone: WorldZone
    public let date: Date
    public let year: Int
    public let month: Int
    public let day: Int
    /// 0–23.
    public let hour: Int
    public let minute: Int
    public let second: Int
    /// 1 = Sunday … 7 = Saturday, matching `Calendar`.
    public let weekday: Int
    /// Seconds east of UTC.
    public let utcOffset: Int
    public let abbreviation: String
    public let isDaylightSavingTime: Bool

    public init(zone: WorldZone, date: Date) {
        let components = zone.calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .weekday],
            from: date
        )
        self.zone = zone
        self.date = date
        self.year = components.year ?? 1970
        self.month = components.month ?? 1
        self.day = components.day ?? 1
        self.hour = components.hour ?? 0
        self.minute = components.minute ?? 0
        self.second = components.second ?? 0
        self.weekday = components.weekday ?? 1
        self.utcOffset = zone.utcOffset(at: date)
        self.abbreviation = zone.abbreviation(at: date)
        self.isDaylightSavingTime = zone.isDaylightSavingTime(at: date)
    }

    /// Rough daylight indicator (06:00–17:59) used to pick a light or dark clock face.
    public var isDaytime: Bool { (6..<18).contains(hour) }

    public var isWeekend: Bool { weekday == 1 || weekday == 7 }

    /// Hour hand angle in degrees, clockwise from 12 o'clock.
    public var hourHandAngle: Double { (Double(hour % 12) + Double(minute) / 60) * 30 }

    /// Minute hand angle in degrees, clockwise from 12 o'clock.
    public var minuteHandAngle: Double { (Double(minute) + Double(second) / 60) * 6 }

    /// The hour as a clock face shows it: 0–23, or 12, 1 … 11 on a 12-hour clock.
    public func displayHour(twelveHour: Bool) -> Int {
        guard twelveHour else { return hour }
        return hour.isMultiple(of: 12) ? 12 : hour % 12
    }

    /// Seconds a count-up timer must already show to read as this wall-clock time
    /// ("9:30:15" → 34 215). Lets a widget tick seconds without one timeline entry per second.
    public func clockFaceSeconds(twelveHour: Bool) -> Int {
        displayHour(twelveHour: twelveHour) * 3600 + minute * 60 + second
    }

    /// Whole calendar days between this reading's date and `other`'s date
    /// (positive when `other` is on a later calendar day).
    public func calendarDays(to other: Self) -> Int {
        Self.dayNumber(year: other.year, month: other.month, day: other.day)
            - Self.dayNumber(year: year, month: month, day: day)
    }

    /// Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's `days_from_civil`).
    static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        let adjustedYear = month <= 2 ? year - 1 : year
        let era = (adjustedYear >= 0 ? adjustedYear : adjustedYear - 399) / 400
        let yearOfEra = adjustedYear - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}
