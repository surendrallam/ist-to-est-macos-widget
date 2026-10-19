import SwiftUI
import TimeConversionKit
import WidgetKit

/// A World Clock–style analog face: light during the day, dark at night.
struct AnalogClockView: View {
    let time: ZoneTime

    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.locale) private var locale

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            face(side: side)
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(ClockStrings(time, locale: locale).full) \(time.abbreviation)"))
    }

    private func face(side: CGFloat) -> some View {
        let palette = Palette(isDaytime: time.isDaytime, isFullColor: renderingMode == .fullColor)
        return ZStack {
            Circle().fill(palette.face)
            Circle().strokeBorder(palette.ink.opacity(0.15), lineWidth: max(0.5, side * 0.012))

            ForEach(0..<12, id: \.self) { index in
                let isMajor = index.isMultiple(of: 3)
                Capsule()
                    .fill(palette.ink.opacity(isMajor ? 0.9 : 0.45))
                    .frame(width: side * (isMajor ? 0.03 : 0.02), height: side * (isMajor ? 0.1 : 0.065))
                    .offset(y: -side * 0.39)
                    .rotationEffect(.degrees(Double(index) * 30))
            }

            Hand(length: side * 0.25, width: side * 0.065, color: palette.ink)
                .rotationEffect(.degrees(time.hourHandAngle))
            Hand(length: side * 0.37, width: side * 0.045, color: palette.ink)
                .rotationEffect(.degrees(time.minuteHandAngle))

            Circle()
                .fill(palette.hub)
                .frame(width: side * 0.1, height: side * 0.1)
                .widgetAccentable()
            Circle()
                .fill(palette.face)
                .frame(width: side * 0.035, height: side * 0.035)
        }
    }
}

private struct Hand: View {
    let length: CGFloat
    let width: CGFloat
    let color: Color

    var body: some View {
        // Offset so the hand starts just behind the centre; `rotationEffect`
        // then pivots around the clock centre because offsets don't move the frame.
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2 + width)
    }
}

private struct Palette {
    let face: Color
    let ink: Color
    let hub: Color

    init(isDaytime: Bool, isFullColor: Bool) {
        if isFullColor {
            face = isDaytime ? .white : Color(white: 0.1)
            ink = isDaytime ? .black : .white
            hub = .orange
        } else {
            // Vibrant/accented modes render by luminance, so keep the face faint and the hands bright.
            face = Color.white.opacity(0.12)
            ink = .white
            hub = .white
        }
    }
}
