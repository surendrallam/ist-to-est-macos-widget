import SwiftUI
import TimeConversionKit
import WidgetKit

// The three widget layouts. They live in Shared so the app can show live
// previews and the snapshot tests can render them without WidgetKit hosting.

// MARK: - Small

/// Two stacked digital clocks with the current gap.
struct SmallClockView: View {
    let date: Date
    var converter = TimeConverter()

    @Environment(\.locale) private var locale

    var body: some View {
        let snapshot = converter.snapshot(at: date)
        VStack(alignment: .leading, spacing: 0) {
            ZoneCaption(time: snapshot.source, locale: locale)
            DigitalTimeText(strings: ClockStrings(snapshot.source, locale: locale), size: 26)
            Spacer(minLength: 4)
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
            Spacer(minLength: 4)
            ZoneCaption(time: snapshot.target, locale: locale)
            DigitalTimeText(strings: ClockStrings(snapshot.target, locale: locale), size: 26)
            Spacer(minLength: 2)
            Text(OffsetDescription.relative(snapshot.offset))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Medium

/// Analog and digital clocks side by side, like World Clock.
struct MediumClockView: View {
    let date: Date
    var converter = TimeConverter()

    @Environment(\.locale) private var locale

    var body: some View {
        let snapshot = converter.snapshot(at: date)
        HStack(alignment: .center, spacing: 8) {
            ZoneColumn(time: snapshot.source, locale: locale)
            OffsetBadge(offset: snapshot.offset)
            ZoneColumn(time: snapshot.target, locale: locale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Large

/// Clocks plus an hour-by-hour IST → ET table for planning calls.
struct LargeConverterView: View {
    let date: Date
    var converter = TimeConverter()
    var rowCount = 8

    @Environment(\.locale) private var locale

    var body: some View {
        let snapshot = converter.snapshot(at: date)
        let rows = converter.upcomingRows(from: date, count: rowCount)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                ZoneColumn(time: snapshot.source, locale: locale, clockSize: 40)
                OffsetBadge(offset: snapshot.offset)
                ZoneColumn(time: snapshot.target, locale: locale, clockSize: 40)
            }

            Rectangle()
                .fill(.separator)
                .frame(height: 1)

            // Same insets and spacing as ConversionRowView, so each heading sits over its column.
            HStack(spacing: 6) {
                Text(snapshot.source.abbreviation)
                Spacer(minLength: 0)
                Label("US work hours", systemImage: "circle.fill")
                    .labelStyle(LegendLabelStyle())
                Spacer(minLength: 0)
                Text(snapshot.target.abbreviation)
                Color.clear
                    .frame(width: 6, height: 1) // working-hours dot column
            }
            .padding(.horizontal, 8)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)

            VStack(spacing: 2) {
                ForEach(rows) { row in
                    ConversionRowView(row: row, locale: locale)
                }
            }

            Spacer(minLength: 0)

            DaylightSavingFootnote(converter: converter, date: date, locale: locale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Building blocks

/// "IST · New Delhi        Mon"
private struct ZoneCaption: View {
    let time: ZoneTime
    let locale: Locale

    var body: some View {
        HStack(spacing: 4) {
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

/// Analog clock, abbreviation, city, digital time and date for one zone.
private struct ZoneColumn: View {
    let time: ZoneTime
    let locale: Locale
    var clockSize: CGFloat = 48

    var body: some View {
        let strings = ClockStrings(time, locale: locale)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                // The digital time below already says this; don't read it twice.
                AnalogClockView(time: time)
                    .frame(width: clockSize, height: clockSize)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(time.abbreviation)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ZoneStyle.tint(for: time.zone))
                        .widgetAccentable()
                    Text(time.zone.city)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            DigitalTimeText(strings: strings, size: 24)
            Text(strings.date)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Big monospaced time with a smaller day period ("9:30 PM", "오후 9:30").
struct DigitalTimeText: View {
    let strings: ClockStrings
    let size: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.12) {
            if strings.periodLeads { periodText }
            Text(strings.time)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if !strings.periodLeads { periodText }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var periodText: some View {
        if let period = strings.period {
            Text(period)
                .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

/// "→ −9:30" between the two columns.
private struct OffsetBadge: View {
    let offset: Int

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(OffsetDescription.compact(offset))
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(OffsetDescription.relative(offset)))
    }
}

private struct ConversionRowView: View {
    let row: ConversionRow
    let locale: Locale

    var body: some View {
        let snapshot = row.snapshot
        let source = ClockStrings(snapshot.source, locale: locale).full
        let target = ClockStrings(snapshot.target, locale: locale).full
        let dayShift = snapshot.dayOffset == 0 ? "" : ", \(OffsetDescription.dayShift(snapshot.dayOffset))"
        HStack(spacing: 6) {
            Text(source)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack(spacing: 4) {
                Text(target)
                if snapshot.dayOffset != 0 {
                    Text(OffsetDescription.dayShift(snapshot.dayOffset))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            Circle()
                .fill(row.targetIsWorking ? Color.green : Color.secondary.opacity(0.25))
                .frame(width: 6, height: 6)
                .widgetAccentable()
                .accessibilityHidden(true)
        }
        .font(.callout.weight(row.isCurrent ? .semibold : .regular))
        .monospacedDigit()
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            if row.isCurrent {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
            }
        }
        // One VoiceOver element per row, and say out loud what the dot's colour shows.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(source) \(snapshot.source.abbreviation) is \(target) \(snapshot.target.abbreviation)\(dayShift)"))
        .accessibilityValue(Text(row.targetIsWorking ? "US working hours" : "Outside US working hours"))
    }
}

/// "ET switches to EST on Sun, Nov 1 · 10h 30m behind"
struct DaylightSavingFootnote: View {
    let converter: TimeConverter
    let date: Date
    let locale: Locale

    var body: some View {
        if let change = converter.nextOffsetChange(after: date) {
            let when = change.date.formatted(
                Date.FormatStyle(locale: locale, timeZone: change.zone.timeZone).weekday(.abbreviated).month(.abbreviated).day()
            )
            let newAbbreviation = change.zone.abbreviation(at: change.date.addingTimeInterval(60))
            Label {
                Text("\(change.zone.genericAbbreviation) switches to \(newAbbreviation) on \(when) · \(OffsetDescription.relative(change.newOffset))")
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
                    .accessibilityHidden(true)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }
}

private struct LegendLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
                .font(.system(size: 5))
                .foregroundStyle(.green)
            configuration.title
        }
    }
}

enum ZoneStyle {
    /// Saffron for India, blue for the US, a neutral accent for anything else.
    static func tint(for zone: WorldZone) -> Color {
        switch zone.identifier {
        case WorldZone.india.identifier: return .orange
        case WorldZone.usEastern.identifier: return .blue
        default: return .accentColor
        }
    }
}
