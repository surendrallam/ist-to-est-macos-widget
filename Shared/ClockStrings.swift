import Foundation
import TimeConversionKit

/// Locale-aware strings for one zone's clock face.
///
/// The 12/24-hour choice follows the user's locale and macOS "24-hour time" setting,
/// because it is read back from the formatted output rather than guessed.
struct ClockStrings: Equatable {
    /// Time with its day period, e.g. "9:30 PM" or "21:30".
    let full: String
    /// Time without the day period, e.g. "9:30" or "21:30".
    let time: String
    /// "PM", or `nil` when the locale uses a 24-hour clock.
    let period: String?
    /// True when the locale writes the day period first ("오후 9:30", "午後9:30").
    let periodLeads: Bool
    /// "Mon"
    let weekday: String
    /// "Mon, Oct 19"
    let date: String

    init(date: Date, zone: WorldZone, locale: Locale) {
        let base = Date.FormatStyle(locale: locale, timeZone: zone.timeZone)
        let full = date.formatted(base.hour().minute())
        self.full = full
        self.weekday = date.formatted(base.weekday(.abbreviated))
        self.date = date.formatted(base.weekday(.abbreviated).month(.abbreviated).day())

        let periodSymbol = Self.periodSymbol(for: date, zone: zone, locale: locale)
        if !periodSymbol.isEmpty, let range = full.range(of: periodSymbol) {
            var time = full
            time.removeSubrange(range)
            self.time = time.trimmingCharacters(in: .whitespacesAndNewlines)
            self.period = periodSymbol
            self.periodLeads = range.lowerBound == full.startIndex
        } else {
            self.time = full
            self.period = nil
            self.periodLeads = false
        }
    }

    init(_ time: ZoneTime, locale: Locale) {
        self.init(date: time.date, zone: time.zone, locale: locale)
    }

    private static func periodSymbol(for date: Date, zone: WorldZone, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = zone.timeZone
        formatter.dateFormat = "a"
        return formatter.string(from: date)
    }
}
