import Foundation

/// A time zone paired with the abbreviations people actually use for it.
///
/// Foundation reports `Asia/Kolkata` as "GMT+5:30" on Apple platforms, so the
/// familiar abbreviations are stored here instead of being read from `TimeZone`.
public struct WorldZone: Hashable, Sendable, Identifiable {
    /// IANA identifier, for example `America/New_York`.
    public let identifier: String
    /// Region name shown in the UI, for example "US Eastern".
    public let name: String
    /// Representative city, for example "New York".
    public let city: String
    /// Abbreviation used outside daylight saving time, for example "EST".
    public let standardAbbreviation: String
    /// Abbreviation used during daylight saving time, for example "EDT". `nil` when the zone has no DST.
    public let daylightAbbreviation: String?
    /// Season-independent abbreviation, for example "ET".
    public let genericAbbreviation: String
    public let timeZone: TimeZone

    public var id: String { identifier }

    public init?(
        identifier: String,
        name: String,
        city: String,
        standardAbbreviation: String,
        daylightAbbreviation: String? = nil,
        genericAbbreviation: String? = nil
    ) {
        guard let timeZone = TimeZone(identifier: identifier) else { return nil }
        self.identifier = identifier
        self.name = name
        self.city = city
        self.standardAbbreviation = standardAbbreviation
        self.daylightAbbreviation = daylightAbbreviation
        self.genericAbbreviation = genericAbbreviation ?? standardAbbreviation
        self.timeZone = timeZone
    }

    /// The abbreviation in effect at `date`, e.g. "EDT" in July and "EST" in January.
    public func abbreviation(at date: Date) -> String {
        if let daylightAbbreviation, timeZone.isDaylightSavingTime(for: date) {
            return daylightAbbreviation
        }
        return standardAbbreviation
    }

    /// Seconds east of UTC at `date`.
    public func utcOffset(at date: Date) -> Int {
        timeZone.secondsFromGMT(for: date)
    }

    public func isDaylightSavingTime(at date: Date) -> Bool {
        timeZone.isDaylightSavingTime(for: date)
    }

    /// A Gregorian calendar pinned to this zone.
    public var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

public extension WorldZone {
    /// India Standard Time (UTC+5:30, no daylight saving).
    static let india = WorldZone(
        known: "Asia/Kolkata",
        name: "India",
        city: "New Delhi",
        standardAbbreviation: "IST"
    )

    /// US Eastern Time: EST (UTC−5) in winter, EDT (UTC−4) in summer.
    static let usEastern = WorldZone(
        known: "America/New_York",
        name: "US Eastern",
        city: "New York",
        standardAbbreviation: "EST",
        daylightAbbreviation: "EDT",
        genericAbbreviation: "ET"
    )
}

private extension WorldZone {
    init(
        known identifier: String,
        name: String,
        city: String,
        standardAbbreviation: String,
        daylightAbbreviation: String? = nil,
        genericAbbreviation: String? = nil
    ) {
        guard let zone = WorldZone(
            identifier: identifier,
            name: name,
            city: city,
            standardAbbreviation: standardAbbreviation,
            daylightAbbreviation: daylightAbbreviation,
            genericAbbreviation: genericAbbreviation
        ) else {
            fatalError("Time zone database is missing \(identifier)")
        }
        self = zone
    }
}
