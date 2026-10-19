// Unit tests for docs/assets/time.js. Run with: node --test docs/tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  IST, ET,
  zoneOffsetMinutes, abbreviation, wallParts, resolveWallTime, zonedWallTimeToDate, convert,
  nextOffsetChange, describeOffset, describeOffsetFrom, compactOffset, formatUtcOffset, formatDuration,
  formatTime, formatDate, formatWallDate, clockStrings, dayShiftLabel, parseDateAndTime, parseDateTimeLocal,
  parseQuery, buildQuery, wallToInputValues, isValidWall, nowSummary,
} from '../assets/time.js';

const at = (iso) => new Date(iso);
const wall = (year, month, day, hour, minute) => ({ year, month, day, hour, minute });

test('India is UTC+5:30 all year; New York is EST in winter and EDT in summer', () => {
  assert.equal(zoneOffsetMinutes(IST, at('2026-01-15T12:00:00Z')), 330);
  assert.equal(zoneOffsetMinutes(IST, at('2026-07-14T12:00:00Z')), 330);
  assert.equal(zoneOffsetMinutes(ET, at('2026-01-15T12:00:00Z')), -300);
  assert.equal(zoneOffsetMinutes(ET, at('2026-07-14T12:00:00Z')), -240);
  assert.equal(zoneOffsetMinutes('UTC', at('2026-07-14T12:00:00Z')), 0);

  assert.equal(abbreviation(IST, at('2026-01-15T12:00:00Z')), 'IST');
  assert.equal(abbreviation(IST, at('2026-07-14T12:00:00Z')), 'IST');
  assert.equal(abbreviation(ET, at('2026-01-15T12:00:00Z')), 'EST');
  assert.equal(abbreviation(ET, at('2026-07-14T12:00:00Z')), 'EDT');
});

test('wallParts reads the clock in a zone', () => {
  assert.deepEqual(wallParts(at('2026-01-15T03:30:00Z'), IST),
    { year: 2026, month: 1, day: 15, hour: 9, minute: 0, second: 0, weekday: 4 });
  assert.deepEqual(wallParts(at('2026-01-15T03:30:00Z'), ET),
    { year: 2026, month: 1, day: 14, hour: 22, minute: 30, second: 0, weekday: 3 });
  // Midnight is hour 0, never 24.
  assert.equal(wallParts(at('2026-01-15T05:00:00Z'), ET).hour, 0);
});

test('09:00 IST on 2026-01-15 is 22:30 EST on 2026-01-14', () => {
  const result = convert(wall(2026, 1, 15, 9, 0), IST, ET);
  assert.equal(result.date.toISOString(), '2026-01-15T03:30:00.000Z');
  assert.equal(result.status, 'exact');
  assert.deepEqual(
    { year: result.targetParts.year, month: result.targetParts.month, day: result.targetParts.day,
      hour: result.targetParts.hour, minute: result.targetParts.minute },
    wall(2026, 1, 14, 22, 30),
  );
  assert.equal(result.dayShift, -1);
  assert.equal(result.offsetMinutes, -630);
  assert.equal(result.sourceAbbr, 'IST');
  assert.equal(result.targetAbbr, 'EST');
  assert.equal(clockStrings(result.targetParts).h12, '10:30 PM');
  assert.equal(clockStrings(result.targetParts).h24, '22:30');
  assert.equal(formatWallDate(result.targetParts), 'Wed, Jan 14, 2026');
});

test('21:30 IST on 2026-07-14 is 12:00 EDT the same day', () => {
  const result = convert(wall(2026, 7, 14, 21, 30), IST, ET);
  assert.equal(result.date.toISOString(), '2026-07-14T16:00:00.000Z');
  assert.equal(result.targetParts.day, 14);
  assert.equal(result.targetParts.hour, 12);
  assert.equal(result.targetParts.minute, 0);
  assert.equal(result.dayShift, 0);
  assert.equal(result.offsetMinutes, -570);
  assert.equal(result.targetAbbr, 'EDT');
  assert.equal(clockStrings(result.targetParts).h12, '12:00 PM');
});

test('ET → IST works in reverse, including the next day', () => {
  const winter = convert(wall(2026, 1, 15, 14, 0), ET, IST);
  assert.equal(winter.sourceAbbr, 'EST');
  assert.equal(winter.targetAbbr, 'IST');
  assert.equal(winter.targetParts.day, 16);
  assert.equal(clockStrings(winter.targetParts).h24, '00:30');
  assert.equal(winter.dayShift, 1);
  assert.equal(winter.offsetMinutes, 630);

  const summer = convert(wall(2026, 7, 14, 12, 0), ET, IST);
  assert.equal(clockStrings(summer.targetParts).h24, '21:30');
  assert.equal(summer.dayShift, 0);
  assert.equal(summer.offsetMinutes, 570);

  const lateSummer = convert(wall(2026, 7, 14, 23, 0), ET, IST);
  assert.equal(clockStrings(lateSummer.targetParts).h12, '8:30 AM');
  assert.equal(lateSummer.targetParts.day, 15);
  assert.equal(lateSummer.dayShift, 1);
});

test('spring forward: 2:30 AM ET on 2027-03-14 does not exist and moves to 3:30 AM EDT', () => {
  const resolved = resolveWallTime(wall(2027, 3, 14, 2, 30), ET);
  assert.equal(resolved.status, 'gap');
  assert.equal(resolved.gapMinutes, 60);
  assert.equal(resolved.date.toISOString(), '2027-03-14T07:30:00.000Z');

  const result = convert(wall(2027, 3, 14, 2, 30), ET, IST);
  assert.equal(result.status, 'gap');
  assert.equal(result.sourceAbbr, 'EDT');
  assert.equal(clockStrings(result.sourceParts).h12, '3:30 AM');
  assert.equal(clockStrings(result.targetParts).h24, '13:00');
  assert.equal(result.targetParts.day, 14);

  // Just before and after the gap are exact.
  assert.equal(convert(wall(2027, 3, 14, 1, 59), ET, IST).status, 'exact');
  assert.equal(convert(wall(2027, 3, 14, 1, 59), ET, IST).sourceAbbr, 'EST');
  assert.equal(convert(wall(2027, 3, 14, 3, 0), ET, IST).sourceAbbr, 'EDT');
  assert.equal(zonedWallTimeToDate(wall(2027, 3, 14, 3, 0), ET).toISOString(), '2027-03-14T07:00:00.000Z');
});

test('fall back: 1:30 AM ET on 2026-11-01 happens twice; the first (EDT) is used', () => {
  const resolved = resolveWallTime(wall(2026, 11, 1, 1, 30), ET);
  assert.equal(resolved.status, 'ambiguous');
  assert.deepEqual(resolved.alternatives.map((d) => d.toISOString()),
    ['2026-11-01T05:30:00.000Z', '2026-11-01T06:30:00.000Z']);
  assert.equal(resolved.date.toISOString(), '2026-11-01T05:30:00.000Z');

  const result = convert(wall(2026, 11, 1, 1, 30), ET, IST);
  assert.equal(result.sourceAbbr, 'EDT');
  assert.equal(clockStrings(result.targetParts).h24, '11:00');

  // IST → ET across the change: one minute apart, an hour apart on the US clock.
  const before = convert(wall(2026, 11, 1, 11, 29), IST, ET);
  const after = convert(wall(2026, 11, 1, 11, 30), IST, ET);
  assert.equal(clockStrings(before.targetParts).h12, '1:59 AM');
  assert.equal(before.targetAbbr, 'EDT');
  assert.equal(clockStrings(after.targetParts).h12, '1:00 AM');
  assert.equal(after.targetAbbr, 'EST');
  assert.equal(after.offsetMinutes, -630);
});

test('zonedWallTimeToDate round-trips every quarter hour of a year in both zones', () => {
  for (const tz of [IST, ET]) {
    for (let day = 0; day < 366; day += 7) {
      for (let minutes = 0; minutes < 24 * 60; minutes += 15) {
        const base = new Date(Date.UTC(2026, 0, 1 + day));
        const w = wall(base.getUTCFullYear(), base.getUTCMonth() + 1, base.getUTCDate(), Math.floor(minutes / 60), minutes % 60);
        const resolved = resolveWallTime(w, tz);
        if (resolved.status === 'gap') continue;
        const back = wallParts(resolved.date, tz);
        assert.deepEqual([back.year, back.month, back.day, back.hour, back.minute],
          [w.year, w.month, w.day, w.hour, w.minute], `${tz} ${JSON.stringify(w)}`);
      }
    }
  }
});

test('nextOffsetChange finds the US daylight-saving changes to the minute', () => {
  const fall = nextOffsetChange(at('2026-10-19T00:00:00Z'));
  assert.equal(fall.date.toISOString(), '2026-11-01T06:00:00.000Z');
  assert.equal(fall.gapMinutes, -630);
  assert.equal(fall.previousGapMinutes, -570);
  assert.equal(fall.fromAbbr, 'EDT');
  assert.equal(fall.toAbbr, 'EST');
  assert.equal(fall.direction, 'back');
  assert.equal(formatDate(fall.date, ET), 'Sun, Nov 1, 2026');

  const spring = nextOffsetChange(at('2026-11-02T00:00:00Z'));
  assert.equal(spring.date.toISOString(), '2027-03-14T07:00:00.000Z');
  assert.equal(spring.gapMinutes, -570);
  assert.equal(spring.toAbbr, 'EDT');
  assert.equal(spring.direction, 'forward');
  assert.equal(formatDate(spring.date, ET), 'Sun, Mar 14, 2027');

  // One minute before a change still finds it; India never changes.
  assert.equal(nextOffsetChange(at('2026-11-01T05:59:00Z')).date.toISOString(), '2026-11-01T06:00:00.000Z');
  assert.equal(nextOffsetChange(at('2026-10-19T00:00:00Z'), IST, { maxDays: 400 }), null);
});

test('nowSummary states the gap and the next change', () => {
  const summary = nowSummary(at('2026-10-19T12:00:00Z'));
  assert.equal(summary.gapMinutes, -570);
  assert.equal(summary.etAbbr, 'EDT');
  assert.equal(summary.current, 'New York is on EDT (UTC−4), 9h 30m behind India.');
  assert.equal(summary.next, 'On Sun, Nov 1, 2026 US clocks fall back; New York will be 10h 30m behind India.');

  const winter = nowSummary(at('2026-12-01T12:00:00Z'));
  assert.equal(winter.next, 'On Sun, Mar 14, 2027 US clocks spring forward; New York will be 9h 30m behind India.');
});

test('describeOffset and friends format offsets', () => {
  assert.equal(describeOffset(-570), '9h 30m behind');
  assert.equal(describeOffset(-630), '10h 30m behind');
  assert.equal(describeOffset(330), '5h 30m ahead');
  assert.equal(describeOffset(-600), '10h behind');
  assert.equal(describeOffset(45), '45m ahead');
  assert.equal(describeOffset(0), 'Same time');
  assert.equal(describeOffsetFrom(-570, 'India'), '9h 30m behind India');
  assert.equal(describeOffsetFrom(570, 'New York'), '9h 30m ahead of New York');
  assert.equal(formatDuration(-630), '10h 30m');
  assert.equal(compactOffset(-570), '−9:30');
  assert.equal(compactOffset(330), '+5:30');
  assert.equal(compactOffset(0), '±0:00');
  assert.equal(formatUtcOffset(330), 'UTC+5:30');
  assert.equal(formatUtcOffset(-240), 'UTC−4');
  assert.equal(formatUtcOffset(0), 'UTC');
});

test('time and date formatting', () => {
  const instant = at('2026-01-15T03:30:00Z');
  assert.equal(formatTime(instant, IST), '9:00 AM');
  assert.equal(formatTime(instant, ET), '10:30 PM');
  assert.equal(formatTime(instant, ET, { hour12: false }), '22:30');
  assert.equal(formatTime(at('2026-01-15T05:00:00Z'), ET), '12:00 AM');
  assert.equal(formatTime(at('2026-01-15T17:00:00Z'), ET), '12:00 PM');
  assert.equal(formatDate(instant, IST), 'Thu, Jan 15, 2026');
  assert.equal(formatDate(instant, ET, { style: 'long' }), 'Wednesday, January 14, 2026');
  assert.equal(formatWallDate({ year: 2026, month: 1, day: 14 }, { weekday: 'long' }), 'Wednesday, Jan 14, 2026');
  assert.equal(formatWallDate({ year: 2026, month: 1, day: 14 }, { year: false }), 'Wed, Jan 14');
});

test('day shift labels', () => {
  assert.equal(dayShiftLabel(0), 'same day');
  assert.equal(dayShiftLabel(-1), 'previous day');
  assert.equal(dayShiftLabel(1), 'next day');
  assert.equal(dayShiftLabel(2), '2 days later');
  assert.equal(dayShiftLabel(-2), '2 days earlier');
});

test('input parsing and URL state', () => {
  assert.deepEqual(parseDateAndTime('2026-10-19', '21:30'), wall(2026, 10, 19, 21, 30));
  assert.deepEqual(parseDateAndTime('2026-10-19', '09:05:00'), wall(2026, 10, 19, 9, 5));
  assert.equal(parseDateAndTime('2026-02-30', '10:00'), null);
  assert.equal(parseDateAndTime('2026-10-19', '24:00'), null);
  assert.equal(parseDateAndTime('', ''), null);
  assert.deepEqual(parseDateTimeLocal('2028-02-29T00:00'), wall(2028, 2, 29, 0, 0));
  assert.equal(isValidWall(wall(2027, 2, 29, 0, 0)), false);
  assert.deepEqual(wallToInputValues(wall(2026, 1, 5, 7, 3)), { date: '2026-01-05', time: '07:03', local: '2026-01-05T07:03' });

  assert.equal(buildQuery({ from: 'ist', wall: wall(2026, 10, 19, 21, 30) }), '?from=ist&t=2026-10-19T21:30');
  assert.equal(buildQuery({ from: 'et', wall: wall(2026, 1, 15, 9, 0) }), '?from=et&t=2026-01-15T09:00');
  assert.deepEqual(parseQuery('?from=ist&t=2026-10-19T21:30'), { from: 'ist', wall: wall(2026, 10, 19, 21, 30) });
  assert.deepEqual(parseQuery('?from=ET&t=2026-10-19T21%3A30'), { from: 'et', wall: wall(2026, 10, 19, 21, 30) });
  assert.deepEqual(parseQuery('?t=2026-10-19T21:30'), { from: 'ist', wall: wall(2026, 10, 19, 21, 30) });
  assert.equal(parseQuery('?from=ist&t=nonsense'), null);
  assert.equal(parseQuery(''), null);
});

test('invalid input is rejected', () => {
  assert.throws(() => resolveWallTime(wall(2026, 13, 1, 0, 0), ET), RangeError);
  assert.throws(() => zoneOffsetMinutes(ET, new Date(Number.NaN)), RangeError);
  assert.throws(() => zoneOffsetMinutes('Not/A_Zone', new Date()), RangeError);
});
