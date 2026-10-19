import Foundation

/// Converts instants and wall-clock times from a source zone to a target zone.
///
/// The default converter goes from India Standard Time to US Eastern Time and
/// follows US daylight saving automatically (EDT in summer, EST in winter).
public struct TimeConverter: Hashable, Sendable {
    public let source: WorldZone
    public let target: WorldZone

    public init(from source: WorldZone = .india, to target: WorldZone = .usEastern) {
        self.source = source
        self.target = target
    }

    /// The same pair, converting the other way.
    public var reversed: Self {
        Self(from: target, to: source)
    }

    /// Both wall-clock readings at `date`.
    public func snapshot(at date: Date) -> ConversionSnapshot {
        ConversionSnapshot(
            source: ZoneTime(zone: source, date: date),
            target: ZoneTime(zone: target, date: date)
        )
    }

    /// Target UTC offset minus source UTC offset, in seconds.
    /// Negative when the target is behind (IST → EDT is −9h 30m).
    public func offset(at date: Date) -> Int {
        target.utcOffset(at: date) - source.utcOffset(at: date)
    }

    /// The instant at which the source zone's clock reads `hour:minute` on the
    /// source-zone calendar day that contains `day`.
    ///
    /// Wall times skipped by a daylight saving jump resolve to the next valid time.
    public func date(hour: Int, minute: Int, onSourceDayOf day: Date) -> Date? {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        let calendar = source.calendar
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }

    /// Converts a source-zone wall time to the target zone.
    public func convert(hour: Int, minute: Int, onSourceDayOf day: Date) -> ConversionSnapshot? {
        date(hour: hour, minute: minute, onSourceDayOf: day).map(snapshot(at:))
    }

    /// Hour-by-hour rows starting at the top of the current source-zone hour.
    public func upcomingRows(
        from date: Date,
        count: Int,
        workingHours: WorkingHours = .standard
    ) -> [ConversionRow] {
        guard count > 0 else { return [] }
        let calendar = source.calendar
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        components.minute = 0
        components.second = 0
        let start = calendar.date(from: components) ?? date

        return (0..<count).map { index in
            let rowDate = start.addingTimeInterval(TimeInterval(index * 3600))
            let snapshot = snapshot(at: rowDate)
            return ConversionRow(
                snapshot: snapshot,
                isCurrent: index == 0,
                sourceIsWorking: workingHours.contains(snapshot.source),
                targetIsWorking: workingHours.contains(snapshot.target)
            )
        }
    }

    /// The next moment either zone changes its UTC offset (a daylight saving switch),
    /// or `nil` when neither zone observes daylight saving.
    public func nextOffsetChange(after date: Date) -> OffsetChange? {
        let candidates: [(zone: WorldZone, date: Date)] = [source, target].compactMap { zone in
            zone.timeZone.nextDaylightSavingTimeTransition(after: date).map { (zone, $0) }
        }
        guard let next = candidates.min(by: { $0.date < $1.date }) else { return nil }
        return OffsetChange(
            date: next.date,
            zone: next.zone,
            previousOffset: offset(at: next.date.addingTimeInterval(-60)),
            newOffset: offset(at: next.date.addingTimeInterval(60))
        )
    }
}

/// Source and target readings of the same instant.
public struct ConversionSnapshot: Hashable, Sendable {
    public let source: ZoneTime
    public let target: ZoneTime

    public init(source: ZoneTime, target: ZoneTime) {
        self.source = source
        self.target = target
    }

    public var date: Date { source.date }

    /// Target UTC offset minus source UTC offset, in seconds.
    public var offset: Int { target.utcOffset - source.utcOffset }

    /// Calendar days the target is ahead (+) or behind (−) the source, usually −1, 0 or +1.
    public var dayOffset: Int { source.calendarDays(to: target) }
}

/// One line of an hour-by-hour conversion table.
public struct ConversionRow: Hashable, Sendable, Identifiable {
    public let snapshot: ConversionSnapshot
    public let isCurrent: Bool
    public let sourceIsWorking: Bool
    public let targetIsWorking: Bool

    public init(snapshot: ConversionSnapshot, isCurrent: Bool, sourceIsWorking: Bool, targetIsWorking: Bool) {
        self.snapshot = snapshot
        self.isCurrent = isCurrent
        self.sourceIsWorking = sourceIsWorking
        self.targetIsWorking = targetIsWorking
    }

    public var id: Date { snapshot.date }
}

/// A daylight saving switch that changes the gap between the two zones.
public struct OffsetChange: Hashable, Sendable {
    /// The instant the new offset takes effect.
    public let date: Date
    /// The zone whose clocks change.
    public let zone: WorldZone
    public let previousOffset: Int
    public let newOffset: Int

    public init(date: Date, zone: WorldZone, previousOffset: Int, newOffset: Int) {
        self.date = date
        self.zone = zone
        self.previousOffset = previousOffset
        self.newOffset = newOffset
    }
}

/// Office hours used to flag good meeting slots.
public struct WorkingHours: Hashable, Sendable {
    /// First working hour, inclusive (0–23).
    public let startHour: Int
    /// End hour, exclusive (1–24).
    public let endHour: Int
    public let includesWeekends: Bool

    public init(startHour: Int, endHour: Int, includesWeekends: Bool = false) {
        precondition((0..<24).contains(startHour) && (1...24).contains(endHour) && startHour < endHour,
                     "Working hours must satisfy 0 ≤ start < end ≤ 24")
        self.startHour = startHour
        self.endHour = endHour
        self.includesWeekends = includesWeekends
    }

    /// 09:00–18:00, Monday to Friday.
    public static let standard = Self(startHour: 9, endHour: 18)

    public func contains(_ time: ZoneTime) -> Bool {
        guard includesWeekends || !time.isWeekend else { return false }
        return (startHour..<endHour).contains(time.hour)
    }
}
