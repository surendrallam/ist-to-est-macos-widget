import SwiftUI
import TimeConversionKit
import WidgetKit

struct ClockEntry: TimelineEntry {
    let date: Date
}

/// Supplies one entry per minute for the next hour, then asks for a fresh timeline.
///
/// Offsets are computed per entry, so a daylight saving switch inside the
/// hour is reflected at the right minute without a reload.
struct ClockProvider: TimelineProvider {
    static let entriesPerTimeline = 60

    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(ClockEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let entries = MinuteSchedule
            .dates(startingAt: Date(), count: Self.entriesPerTimeline)
            .map(ClockEntry.init(date:))
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct ClockWidgetEntryView: View {
    let entry: ClockEntry
    let style: WidgetStyle

    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetContent(style: style, size: WidgetSize(family), date: entry.date, ticksLive: true)
            .containerBackground(for: .widget) {
                WidgetBackground()
            }
    }
}

/// Analog faces like Apple's World Clock; the large size adds an hour-by-hour table.
struct ClockWidget: Widget {
    static let kind = "io.github.surendrallam.ISTtoEST.clock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ClockProvider()) { entry in
            ClockWidgetEntryView(entry: entry, style: .worldClock)
        }
        .configurationDisplayName("IST to EST")
        .description("India Standard Time and US Eastern Time side by side. Daylight saving (EST/EDT) is handled automatically.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Big digital clocks with live seconds.
struct DigitalClockWidget: Widget {
    static let kind = "io.github.surendrallam.ISTtoEST.digital"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ClockProvider()) { entry in
            ClockWidgetEntryView(entry: entry, style: .digital)
        }
        .configurationDisplayName("IST to EST Digital")
        .description("Large digital clocks with seconds for India Standard Time and US Eastern Time (EST/EDT).")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct ISTtoESTWidgetBundle: WidgetBundle {
    var body: some Widget {
        ClockWidget()
        DigitalClockWidget()
    }
}

extension WidgetSize {
    init(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        default: self = .large
        }
    }
}

#Preview("World Clock", as: .systemMedium) {
    ClockWidget()
} timeline: {
    ClockEntry(date: Date())
}

#Preview("Digital", as: .systemMedium) {
    DigitalClockWidget()
} timeline: {
    ClockEntry(date: Date())
}

#Preview("Digital large", as: .systemLarge) {
    DigitalClockWidget()
} timeline: {
    ClockEntry(date: Date())
}
