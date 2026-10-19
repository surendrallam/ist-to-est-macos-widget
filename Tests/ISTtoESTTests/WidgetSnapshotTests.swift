import ImageIO
import SwiftUI
import TimeConversionKit
import UniformTypeIdentifiers
import XCTest

/// Renders every widget style and size in summer (EDT) and winter (EST), light and dark.
///
/// Set `SNAPSHOT_OUTPUT_DIR` (or `TEST_RUNNER_SNAPSHOT_OUTPUT_DIR` when running
/// through `xcodebuild`) to also write the PNGs, e.g. for README screenshots.
@MainActor
final class WidgetSnapshotTests: XCTestCase {
    private static let moments: [(name: String, date: Date)] = [
        ("summer", iso("2026-07-14T21:30:00+05:30")), // 21:30 IST = 12:00 EDT
        ("winter", iso("2026-01-15T09:00:00+05:30")), // 09:00 IST = 22:30 EST the day before
    ]

    func testAllWidgetsRender() throws {
        for style in WidgetStyle.allCases {
            for moment in Self.moments {
                for scheme in [ColorScheme.light, .dark] {
                    for size in WidgetSize.allCases {
                        let prefix = style == .digital ? "digital" : "widget"
                        let name = "\(prefix)-\(size.rawValue)-\(moment.name)-\(scheme == .dark ? "dark" : "light")"
                        let card = WidgetPreviewCard(size: size) {
                            WidgetContent(style: style, size: size, date: moment.date)
                        }
                        try render(card, name: name, scheme: scheme)
                    }
                }
            }
        }
    }

    func testStaticDigitsMatchTimerShape() {
        let evening = ZoneTime(zone: .india, date: Self.iso("2026-07-14T21:05:09+05:30"))
        XCTAssertEqual(DigitalClockReadout.staticDigits(evening, twelveHour: true), "9:05:09")
        XCTAssertEqual(DigitalClockReadout.staticDigits(evening, twelveHour: false), "21:05:09")
    }

    func testClockStringsSplitDayPeriod() {
        let date = Self.iso("2026-07-14T21:30:00+05:30")
        let us = ClockStrings(date: date, zone: .india, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(us.time, "9:30")
        XCTAssertEqual(us.period, "PM")
        XCTAssertEqual(us.weekday, "Tue")
        XCTAssertFalse(us.periodLeads)

        let uk = ClockStrings(date: date, zone: .india, locale: Locale(identifier: "en_GB"))
        XCTAssertEqual(uk.time, "21:30")
        XCTAssertNil(uk.period)
        XCTAssertFalse(uk.periodLeads)

        // Korean writes the day period first: "오후 9:30".
        let korean = ClockStrings(date: date, zone: .india, locale: Locale(identifier: "ko_KR"))
        XCTAssertEqual(korean.time, "9:30")
        XCTAssertNotNil(korean.period)
        XCTAssertTrue(korean.periodLeads)
    }

    func testLiveTimerKeepsTheMidnightHour() {
        // On a 24-hour clock the timer alone would draw 00:05:09 as "5:09" and 00:45:30 as "45:30".
        let cases: [(date: String, prefix: String, limit: TimeInterval)] = [
            ("2026-07-14T00:05:09+05:30", "0:0", 599),
            ("2026-07-14T00:45:30+05:30", "0:", 3599),
        ]
        for testCase in cases {
            let time = ZoneTime(zone: .india, date: Self.iso(testCase.date))
            let parts = DigitalClockReadout.timerParts(time, twelveHour: false)
            let start = parts.interval.lowerBound
            XCTAssertEqual(parts.prefix, testCase.prefix)
            XCTAssertEqual(parts.interval.upperBound.timeIntervalSince(start), testCase.limit)
            XCTAssertEqual(
                parts.prefix + Self.timerText(time.date.timeIntervalSince(start)),
                DigitalClockReadout.staticDigits(time, twelveHour: false)
            )
            // Where the timer stops, the prefix still fits: "0:09:59" / "0:59:59".
            XCTAssertEqual(parts.prefix + Self.timerText(testCase.limit), testCase.limit < 600 ? "0:09:59" : "0:59:59")
        }

        // From 1:00 on (and always on a 12-hour clock) the timer shows the hour itself.
        let evening = ZoneTime(zone: .india, date: Self.iso("2026-07-14T21:05:09+05:30"))
        let evening24 = DigitalClockReadout.timerParts(evening, twelveHour: false)
        XCTAssertEqual(evening24.prefix, "")
        XCTAssertEqual(Self.timerText(evening.date.timeIntervalSince(evening24.interval.lowerBound)), "21:05:09")
        let midnight = ZoneTime(zone: .india, date: Self.iso("2026-07-14T00:05:09+05:30"))
        let midnight12 = DigitalClockReadout.timerParts(midnight, twelveHour: true)
        XCTAssertEqual(midnight12.prefix, "")
        XCTAssertEqual(Self.timerText(midnight.date.timeIntervalSince(midnight12.interval.lowerBound)), "12:05:09")
    }

    func testLiveReadoutRenders() throws {
        // The widget's ticking path (timer text sized by hidden static digits); not written to disk.
        let time = ZoneTime(zone: .india, date: Self.iso("2026-07-14T00:05:09+05:30"))
        for identifier in ["en_US", "en_GB", "ko_KR"] {
            let view = DigitalClockReadout(time: time, size: 38, ticksLive: true)
                .frame(width: 240)
                .environment(\.locale, Locale(identifier: identifier))
            let renderer = ImageRenderer(content: view)
            let image = try XCTUnwrap(renderer.cgImage, "live readout (\(identifier)) did not render")
            XCTAssertGreaterThan(image.width, 0, identifier)
        }
    }

    private func render(_ view: some View, name: String, scheme: ColorScheme) throws {
        let content = view
            .padding(24)
            .background(scheme == .dark ? Color(white: 0.08) : Color(white: 0.88))
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.colorScheme, scheme)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage, "\(name) did not render")
        XCTAssertGreaterThan(image.width, 200, name)
        XCTAssertGreaterThan(image.height, 200, name)

        let attachment = XCTAttachment(image: NSImage(cgImage: image, size: .zero))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let directory = ProcessInfo.processInfo.environment["SNAPSHOT_OUTPUT_DIR"], !directory.isEmpty else { return }
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(name).png")
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination), "Could not write \(url.path)")
    }

    /// What SwiftUI's count-up timer text draws for `seconds`: "H:MM:SS" from one hour, "M:SS" below.
    private static func timerText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let (hours, minutes, secs) = (total / 3600, total / 60 % 60, total % 60)
        let tail = secs < 10 ? "0\(secs)" : "\(secs)"
        guard hours > 0 else { return "\(minutes):\(tail)" }
        return "\(hours):\(minutes < 10 ? "0" : "")\(minutes):\(tail)"
    }

    private static func iso(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string) ?? Date(timeIntervalSince1970: 0)
    }
}
