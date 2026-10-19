import SwiftUI

/// The widget's background, shared by the real widget and in-app previews.
struct WidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(white: 0.17), Color(white: 0.12)]
                : [Color.white, Color(white: 0.95)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Point sizes of macOS widgets, used to preview them outside WidgetKit.
enum WidgetSize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .large: CGSize(width: 364, height: 382)
        }
    }

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }
}

/// Draws widget content the way Notification Center does: padded, rounded and on the widget background.
struct WidgetPreviewCard<Content: View>: View {
    let size: WidgetSize
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(width: size.size.width, height: size.size.height)
            .background(WidgetBackground())
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

/// The two widgets the app ships.
enum WidgetStyle: String, CaseIterable, Identifiable {
    /// Analog faces like Apple's World Clock, plus an hour-by-hour table in the large size.
    case worldClock
    /// Big digital numerals with seconds.
    case digital

    var id: String { rawValue }

    var title: String {
        switch self {
        case .worldClock: "World Clock"
        case .digital: "Digital"
        }
    }
}

/// The content of one widget style at one size, without the widget chrome.
struct WidgetContent: View {
    let style: WidgetStyle
    let size: WidgetSize
    let date: Date
    /// Let digital clocks tick seconds on their own (only meaningful inside WidgetKit).
    var ticksLive = false

    var body: some View {
        switch (style, size) {
        case (.worldClock, .small): SmallClockView(date: date)
        case (.worldClock, .medium): MediumClockView(date: date)
        case (.worldClock, .large): LargeConverterView(date: date)
        case (.digital, .small): DigitalSmallView(date: date, ticksLive: ticksLive)
        case (.digital, .medium): DigitalMediumView(date: date, ticksLive: ticksLive)
        case (.digital, .large): DigitalLargeView(date: date, ticksLive: ticksLive)
        }
    }
}
