import Foundation
import XCTest

@testable import TimeConversionKit

final class WorldZoneTests: XCTestCase {
    func testIndiaIsAlwaysIST() {
        XCTAssertEqual(WorldZone.india.abbreviation(at: instant("2026-01-15T12:00:00Z")), "IST")
        XCTAssertEqual(WorldZone.india.abbreviation(at: instant("2026-07-15T12:00:00Z")), "IST")
        XCTAssertEqual(WorldZone.india.utcOffset(at: instant("2026-07-15T12:00:00Z")), 19_800)
    }

    func testEasternFollowsDaylightSaving() {
        XCTAssertEqual(WorldZone.usEastern.abbreviation(at: instant("2026-01-15T12:00:00Z")), "EST")
        XCTAssertEqual(WorldZone.usEastern.abbreviation(at: instant("2026-07-15T12:00:00Z")), "EDT")
        XCTAssertEqual(WorldZone.usEastern.genericAbbreviation, "ET")
    }

    func testUnknownIdentifierFails() {
        XCTAssertNil(WorldZone(identifier: "Mars/Olympus_Mons", name: "Mars", city: "Olympus", standardAbbreviation: "MST"))
    }
}

final class TimeConverterTests: XCTestCase {
    private let converter = TimeConverter()

    func testDefaultDirectionIsISTToEastern() {
        XCTAssertEqual(converter.source, .india)
        XCTAssertEqual(converter.target, .usEastern)
        XCTAssertEqual(converter.reversed.source, .usEastern)
    }

    func testOffsetInWinterAndSummer() {
        XCTAssertEqual(converter.offset(at: instant("2026-01-15T12:00:00Z")), -37_800) // −10h 30m
        XCTAssertEqual(converter.offset(at: instant("2026-07-15T12:00:00Z")), -34_200) // −9h 30m
    }

    func testWinterMorningInIndiaIsPreviousEveningInNewYork() {
        let snapshot = converter.snapshot(at: instant("2026-01-15T09:00:00+05:30"))
        XCTAssertEqual(snapshot.source.hour, 9)
        XCTAssertEqual(snapshot.target.hour, 22)
        XCTAssertEqual(snapshot.target.minute, 30)
        XCTAssertEqual(snapshot.target.day, 14)
        XCTAssertEqual(snapshot.target.abbreviation, "EST")
        XCTAssertEqual(snapshot.dayOffset, -1)
        XCTAssertEqual(snapshot.offset, -37_800)
    }

    func testSummerEveningInIndiaIsSameDayMorningInNewYork() {
        let snapshot = converter.snapshot(at: instant("2026-07-15T20:00:00+05:30"))
        XCTAssertEqual(snapshot.target.hour, 10)
        XCTAssertEqual(snapshot.target.minute, 30)
        XCTAssertEqual(snapshot.target.abbreviation, "EDT")
        XCTAssertEqual(snapshot.dayOffset, 0)
    }

    func testConvertWallTimeOnSourceDay() throws {
        // Any instant on 19 Oct 2026 in India; 09:00 IST that day is 23:30 EDT on 18 Oct.
        let result = try XCTUnwrap(converter.convert(hour: 9, minute: 0, onSourceDayOf: instant("2026-10-19T12:00:00Z")))
        XCTAssertEqual(result.source.day, 19)
        XCTAssertEqual(result.source.hour, 9)
        XCTAssertEqual(result.target.day, 18)
        XCTAssertEqual(result.target.hour, 23)
        XCTAssertEqual(result.target.minute, 30)
        XCTAssertEqual(result.dayOffset, -1)
    }

    func testConvertRejectsInvalidWallTime() {
        XCTAssertNil(converter.convert(hour: 24, minute: 0, onSourceDayOf: Date()))
        XCTAssertNil(converter.convert(hour: 10, minute: 60, onSourceDayOf: Date()))
    }

    func testReverseConversion() throws {
        let reverse = converter.reversed
        let winter = try XCTUnwrap(reverse.convert(hour: 9, minute: 0, onSourceDayOf: instant("2026-01-15T17:00:00Z")))
        XCTAssertEqual(winter.target.hour, 19)
        XCTAssertEqual(winter.target.minute, 30)
        XCTAssertEqual(winter.dayOffset, 0)

        let summerEvening = try XCTUnwrap(reverse.convert(hour: 20, minute: 0, onSourceDayOf: instant("2026-07-15T17:00:00Z")))
        XCTAssertEqual(summerEvening.target.hour, 5)
        XCTAssertEqual(summerEvening.target.minute, 30)
        XCTAssertEqual(summerEvening.target.day, 16)
        XCTAssertEqual(summerEvening.dayOffset, 1)
    }

    func testDayOffsetAcrossYearBoundary() {
        // 31 Dec 2026, 20:00 EST = 1 Jan 2027, 06:30 IST.
        let snapshot = converter.reversed.snapshot(at: instant("2026-12-31T20:00:00-05:00"))
        XCTAssertEqual(snapshot.target.year, 2027)
        XCTAssertEqual(snapshot.dayOffset, 1)
    }

    func testUpcomingRowsStartAtTopOfSourceHour() {
        // Monday 19 Oct 2026, 10:47 IST.
        let rows = converter.upcomingRows(from: instant("2026-10-19T10:47:00+05:30"), count: 8)
        XCTAssertEqual(rows.count, 8)
        XCTAssertEqual(rows.map(\.snapshot.source.hour), Array(10...17))
        XCTAssertTrue(rows.allSatisfy { $0.snapshot.source.minute == 0 })
        XCTAssertEqual(rows.filter(\.isCurrent).count, 1)
        XCTAssertTrue(rows[0].isCurrent)

        XCTAssertEqual(rows[0].snapshot.target.hour, 0)
        XCTAssertEqual(rows[0].snapshot.target.minute, 30)
        XCTAssertTrue(rows[0].sourceIsWorking)
        XCTAssertFalse(rows[0].targetIsWorking)
    }

    func testUpcomingRowsFlagUSWorkingHours() {
        // 19:00 IST on Monday 19 Oct 2026 is 09:30 EDT.
        let rows = converter.upcomingRows(from: instant("2026-10-19T19:05:00+05:30"), count: 2)
        XCTAssertEqual(rows[0].snapshot.target.hour, 9)
        XCTAssertFalse(rows[0].sourceIsWorking)
        XCTAssertTrue(rows[0].targetIsWorking)
    }

    func testUpcomingRowsWithNoCount() {
        XCTAssertTrue(converter.upcomingRows(from: Date(), count: 0).isEmpty)
    }

    func testNextOffsetChangeWhenUSFallsBack() throws {
        let change = try XCTUnwrap(converter.nextOffsetChange(after: instant("2026-10-19T00:00:00Z")))
        XCTAssertEqual(change.date, instant("2026-11-01T06:00:00Z")) // 02:00 EDT
        XCTAssertEqual(change.zone, .usEastern)
        XCTAssertEqual(change.previousOffset, -34_200)
        XCTAssertEqual(change.newOffset, -37_800)
    }

    func testNextOffsetChangeWhenUSSpringsForward() throws {
        let change = try XCTUnwrap(converter.nextOffsetChange(after: instant("2026-11-02T00:00:00Z")))
        XCTAssertEqual(change.date, instant("2027-03-14T07:00:00Z")) // 02:00 EST
        XCTAssertEqual(change.previousOffset, -37_800)
        XCTAssertEqual(change.newOffset, -34_200)
    }

    func testNoOffsetChangeWithoutDaylightSaving() {
        let indiaOnly = TimeConverter(from: .india, to: .india)
        XCTAssertNil(indiaOnly.nextOffsetChange(after: instant("2026-10-19T00:00:00Z")))
    }
}

final class ZoneTimeTests: XCTestCase {
    func testHandAngles() {
        let threeOClock = ZoneTime(zone: .india, date: instant("2026-10-19T15:00:00+05:30"))
        XCTAssertEqual(threeOClock.hourHandAngle, 90)
        XCTAssertEqual(threeOClock.minuteHandAngle, 0)

        let halfPastNine = ZoneTime(zone: .india, date: instant("2026-10-19T21:30:00+05:30"))
        XCTAssertEqual(halfPastNine.hourHandAngle, 285)
        XCTAssertEqual(halfPastNine.minuteHandAngle, 180)
    }

    func testDisplayHourAndClockFaceSeconds() {
        let afterMidnight = ZoneTime(zone: .india, date: instant("2026-10-19T00:15:00+05:30"))
        XCTAssertEqual(afterMidnight.displayHour(twelveHour: false), 0)
        XCTAssertEqual(afterMidnight.displayHour(twelveHour: true), 12)
        XCTAssertEqual(afterMidnight.clockFaceSeconds(twelveHour: false), 900)
        XCTAssertEqual(afterMidnight.clockFaceSeconds(twelveHour: true), 43_200 + 900)

        let afternoon = ZoneTime(zone: .india, date: instant("2026-10-19T13:05:07+05:30"))
        XCTAssertEqual(afternoon.displayHour(twelveHour: true), 1)
        XCTAssertEqual(afternoon.clockFaceSeconds(twelveHour: true), 3907)
        XCTAssertEqual(afternoon.clockFaceSeconds(twelveHour: false), 47_107)

        let noon = ZoneTime(zone: .usEastern, date: instant("2026-07-14T12:00:00-04:00"))
        XCTAssertEqual(noon.displayHour(twelveHour: true), 12)
        XCTAssertEqual(noon.displayHour(twelveHour: false), 12)
    }

    func testDaytimeAndWeekend() {
        let saturdayMorning = ZoneTime(zone: .usEastern, date: instant("2026-10-24T08:00:00-04:00"))
        XCTAssertTrue(saturdayMorning.isDaytime)
        XCTAssertTrue(saturdayMorning.isWeekend)
        XCTAssertEqual(saturdayMorning.weekday, 7)

        let mondayNight = ZoneTime(zone: .usEastern, date: instant("2026-10-19T23:00:00-04:00"))
        XCTAssertFalse(mondayNight.isDaytime)
        XCTAssertFalse(mondayNight.isWeekend)
    }

    func testDayNumberMatchesUnixEpoch() {
        XCTAssertEqual(ZoneTime.dayNumber(year: 1970, month: 1, day: 1), 0)
        XCTAssertEqual(ZoneTime.dayNumber(year: 2000, month: 3, day: 1), 11_017)
        XCTAssertEqual(ZoneTime.dayNumber(year: 1969, month: 12, day: 31), -1)
    }
}

final class WorkingHoursTests: XCTestCase {
    func testWeekendsAreExcludedByDefault() {
        let saturday = ZoneTime(zone: .usEastern, date: instant("2026-10-24T10:00:00-04:00"))
        XCTAssertFalse(WorkingHours.standard.contains(saturday))
        XCTAssertTrue(WorkingHours(startHour: 9, endHour: 18, includesWeekends: true).contains(saturday))
    }

    func testEndHourIsExclusive() {
        let sixPM = ZoneTime(zone: .india, date: instant("2026-10-19T18:00:00+05:30"))
        let fiveFiftyNine = ZoneTime(zone: .india, date: instant("2026-10-19T17:59:00+05:30"))
        XCTAssertFalse(WorkingHours.standard.contains(sixPM))
        XCTAssertTrue(WorkingHours.standard.contains(fiveFiftyNine))
    }
}

final class OffsetDescriptionTests: XCTestCase {
    func testRelative() {
        XCTAssertEqual(OffsetDescription.relative(-34_200), "9h 30m behind")
        XCTAssertEqual(OffsetDescription.relative(-37_800), "10h 30m behind")
        XCTAssertEqual(OffsetDescription.relative(19_800), "5h 30m ahead")
        XCTAssertEqual(OffsetDescription.relative(-3600), "1h behind")
        XCTAssertEqual(OffsetDescription.relative(2700), "45m ahead")
        XCTAssertEqual(OffsetDescription.relative(0), "Same time")
    }

    func testSentence() {
        XCTAssertEqual(OffsetDescription.sentence(-34_200, subject: "New York", reference: "New Delhi"),
                       "New York is 9h 30m behind New Delhi")
        XCTAssertEqual(OffsetDescription.sentence(34_200, subject: "New Delhi", reference: "New York"),
                       "New Delhi is 9h 30m ahead of New York")
        XCTAssertEqual(OffsetDescription.sentence(0, subject: "A", reference: "B"), "A and B show the same time")
    }

    func testCompact() {
        XCTAssertEqual(OffsetDescription.compact(-34_200), "\u{2212}9:30")
        XCTAssertEqual(OffsetDescription.compact(19_800), "+5:30")
        XCTAssertEqual(OffsetDescription.compact(-18_000), "\u{2212}5:00")
        XCTAssertEqual(OffsetDescription.compact(20_700), "+5:45")
        XCTAssertEqual(OffsetDescription.compact(0), "\u{00B1}0:00")
    }

    func testDayShift() {
        XCTAssertEqual(OffsetDescription.dayShift(0), "")
        XCTAssertEqual(OffsetDescription.dayShift(-1), "\u{2212}1 day")
        XCTAssertEqual(OffsetDescription.dayShift(1), "+1 day")
        XCTAssertEqual(OffsetDescription.dayShift(2), "+2 days")
    }
}

final class MinuteScheduleTests: XCTestCase {
    func testStartsNowThenFollowsMinuteBoundaries() {
        let start = instant("2026-10-19T10:47:23Z")
        XCTAssertEqual(
            MinuteSchedule.dates(startingAt: start, count: 3),
            [start, instant("2026-10-19T10:48:00Z"), instant("2026-10-19T10:49:00Z")]
        )
    }

    func testStartOnBoundaryDoesNotDuplicate() {
        let start = instant("2026-10-19T10:48:00Z")
        XCTAssertEqual(MinuteSchedule.dates(startingAt: start, count: 2), [start, instant("2026-10-19T10:49:00Z")])
    }

    func testCounts() {
        XCTAssertTrue(MinuteSchedule.dates(startingAt: Date(), count: 0).isEmpty)
        XCTAssertEqual(MinuteSchedule.dates(startingAt: Date(), count: 1).count, 1)
        XCTAssertEqual(MinuteSchedule.dates(startingAt: Date(), count: 60).count, 60)
    }

    func testBoundariesAreWholeMinutesInIndia() {
        let dates = MinuteSchedule.dates(startingAt: instant("2026-10-19T10:47:23Z"), count: 5).dropFirst()
        XCTAssertTrue(dates.allSatisfy { ZoneTime(zone: .india, date: $0).second == 0 })
    }
}

private func instant(_ iso8601: String, file: StaticString = #filePath, line: UInt = #line) -> Date {
    guard let date = ISO8601DateFormatter().date(from: iso8601) else {
        XCTFail("Bad ISO 8601 date: \(iso8601)", file: file, line: line)
        return Date(timeIntervalSince1970: 0)
    }
    return date
}
