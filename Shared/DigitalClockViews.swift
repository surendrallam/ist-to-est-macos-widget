import SwiftUI
import TimeConversionKit
import WidgetKit

// The "Digital" widget: big numerals with seconds for both zones.

// MARK: - Small

/// Two stacked digital clocks with seconds.
struct DigitalSmallView: View {
    let date: Date
    var converter = TimeConverter()
    var ticksLive = false

    @Environment(\.locale) private var locale

    var body: some View {
        let snapshot = converter.snapshot(at: date)
        VStack(alignment: .leading, spacing: 0) {
            DigitalZoneCaption(time: snapshot.source, locale: locale)
            DigitalClockReadout(time: snapshot.source, size: 30, ticksLive: ticksLive)
            Spacer(minLength: 4)
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
            Spacer(minLength: 4)
            DigitalZoneCaption(time: snapshot.target, locale: locale)
            DigitalClockReadout(time: snapshot.target, size: 30, ticksLive: ticksLive)
            Spacer(minLength: 2)
            Text("\(snapshot.target.zone.genericAbbreviation) \(OffsetDescription.relative(snapshot.offset))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium

/// One full-width row per zone: labels on the left, a large clock on the right.
struct DigitalMediumView: View {
    let date: Date
    var converter = TimeConverter()
    var ticksLive = false

    @Environment(\.locale) private var locale

    var body: some View {
        let snapshot = converter.snapshot(at: date)
        VStack(spacing: 6) {
            DigitalRow(time: snapshot.source, locale: locale, ticksLive: ticksLive)
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
            DigitalRow(time: snapshot.target, locale: locale, ticksLive: ticksLive)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Large

/// Two clock panels, the gap between them, and the next daylight saving change.
struct DigitalLargeView: View {
    let date: Date
    var converter = TimeConverter()
    var ticksLive = false

    @Environment(\.locale) private var locale

    var body: some View {
        let snapshot = converter.snapshot(at: date)
        VStack(alignment: .leading, spacing: 10) {
            DigitalPanel(time: snapshot.source, locale: locale, ticksLive: ticksLive)
            Label {
                Text(OffsetDescription.sentence(
                    snapshot.offset,
                    subject: converter.target.city,
                    reference: converter.source.city
                ))
            } icon: {
                Image(systemName: "arrow.down")
                    .accessibilityHidden(true)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.leading, 4)
            DigitalPanel(time: snapshot.target, locale: locale, ticksLive: ticksLive)
            Spacer(minLength: 0)
            DaylightSavingFootnote(converter: converter, date: date, locale: locale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Building blocks

/// Large digital time with seconds and a smaller day period ("9:30:15 PM").
///
/// With `ticksLive` the seconds advance on their own: a count-up timer is anchored
/// so its elapsed time equals the zone's wall-clock time at `time.date`. Every
/// minute's timeline entry re-anchors it, which also covers the 12 → 1 and
/// midnight roll-overs and daylight saving jumps. Without it (app previews,
/// snapshots) the time is drawn as plain text.
struct DigitalClockReadout: View {
    let time: ZoneTime
    let size: CGFloat
    var ticksLive = false

    @Environment(\.locale) private var locale

    var body: some View {
        let strings = ClockStrings(time, locale: locale)
        HStack(alignment: .firstTextBaseline, spacing: size * 0.1) {
            if strings.periodLeads { periodText(strings) }
            digits(twelveHour: strings.period != nil)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.leading)
            if !strings.periodLeads { periodText(strings) }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(strings.full) \(time.abbreviation)"))
    }

    @ViewBuilder
    private func periodText(_ strings: ClockStrings) -> some View {
        if let period = strings.period {
            Text(period)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func digits(twelveHour: Bool) -> some View {
        let face = Text(Self.staticDigits(time, twelveHour: twelveHour))
        if ticksLive {
            // WidgetKit gives timer text all the width it is offered, which would push
            // the day period to the far edge. Size it with the static digits instead:
            // same shape and monospaced, so the timer drawn on top fits exactly.
            face
                .hidden()
                .overlay(alignment: .leading) { liveDigits(twelveHour: twelveHour) }
        } else {
            face
        }
    }

    private func liveDigits(twelveHour: Bool) -> Text {
        let parts = Self.timerParts(time, twelveHour: twelveHour)
        let timer = Text(timerInterval: parts.interval, countsDown: false)
        return parts.prefix.isEmpty ? timer : Text(verbatim: parts.prefix) + timer
    }

    /// The count-up timer behind a live readout: text drawn in front of it, and the
    /// interval it counts over (its elapsed time is the clock-face time).
    ///
    /// Under one hour the timer leaves out its hour field ("5:09" at 00:05:09 on a
    /// 24-hour clock), so that hour gets a "0:" or "0:0" prefix, and the timer stops
    /// before its minutes would outgrow it; the next minute's entry re-anchors it.
    /// Otherwise there are two days of headroom, so a late timeline reload keeps
    /// counting instead of freezing.
    static func timerParts(_ time: ZoneTime, twelveHour: Bool) -> (prefix: String, interval: ClosedRange<Date>) {
        let faceSeconds = time.clockFaceSeconds(twelveHour: twelveHour)
        let start = time.date.addingTimeInterval(-TimeInterval(faceSeconds))
        guard faceSeconds < 3600 else {
            return ("", start...start.addingTimeInterval(172_800))
        }
        let (prefix, limit) = time.minute < 10 ? ("0:0", 599.0) : ("0:", 3599.0)
        return (prefix, start...start.addingTimeInterval(limit))
    }

    /// "9:30:15" — the same shape the count-up timer draws.
    static func staticDigits(_ time: ZoneTime, twelveHour: Bool) -> String {
        let minute = time.minute < 10 ? "0\(time.minute)" : "\(time.minute)"
        let second = time.second < 10 ? "0\(time.second)" : "\(time.second)"
        return "\(time.displayHour(twelveHour: twelveHour)):\(minute):\(second)"
    }
}

/// Sun or moon depending on the hour in that zone.
private struct DayNightSymbol: View {
    let time: ZoneTime

    var body: some View {
        Image(systemName: time.isDaytime ? "sun.max.fill" : "moon.fill")
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text(time.isDaytime ? "Daytime" : "Night"))
    }
}

/// "☀︎ IST  New Delhi        Tue"
private struct DigitalZoneCaption: View {
    let time: ZoneTime
    let locale: Locale

    var body: some View {
        HStack(spacing: 4) {
            DayNightSymbol(time: time)
            Text(time.abbreviation)
                .fontWeight(.bold)
                .foregroundStyle(ZoneStyle.tint(for: time.zone))
                .widgetAccentable()
            Text(time.zone.city)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(ClockStrings(time, locale: locale).weekday)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}

private struct DigitalRow: View {
    let time: ZoneTime
    let locale: Locale
    let ticksLive: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(time.abbreviation)
                        .font(.headline)
                        .foregroundStyle(ZoneStyle.tint(for: time.zone))
                        .widgetAccentable()
                    DayNightSymbol(time: time)
                        .font(.caption)
                }
                Text(time.zone.city)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(ClockStrings(time, locale: locale).date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .frame(width: 92, alignment: .leading)
            Spacer(minLength: 0)
            DigitalClockReadout(time: time, size: 38, ticksLive: ticksLive)
        }
    }
}

private struct DigitalPanel: View {
    let time: ZoneTime
    let locale: Locale
    let ticksLive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(time.abbreviation)
                    .font(.headline)
                    .foregroundStyle(ZoneStyle.tint(for: time.zone))
                    .widgetAccentable()
                Text(time.zone.city)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                DayNightSymbol(time: time)
            }
            DigitalClockReadout(time: time, size: 54, ticksLive: ticksLive)
            Text(ClockStrings(time, locale: locale).date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
