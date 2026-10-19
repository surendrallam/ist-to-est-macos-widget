// Pure time-zone helpers for the IST to EST website.
//
// No DOM access, so the same module runs in the browser and under `node --test`.
// Every offset comes from the runtime's time-zone database through Intl; no
// daylight-saving dates are hard-coded anywhere.

export const IST = 'Asia/Kolkata';
export const ET = 'America/New_York';

export const ZONES = Object.freeze({
  ist: Object.freeze({ key: 'ist', tz: IST, city: 'New Delhi', place: 'India', generic: 'IST' }),
  et: Object.freeze({ key: 'et', tz: ET, city: 'New York', place: 'US Eastern', generic: 'ET' }),
});

const MINUTE = 60_000;
const DAY = 24 * 60 * MINUTE;
const MINUS = '−';

const WEEKDAYS_SHORT = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const WEEKDAYS_LONG = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTHS_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const MONTHS_LONG = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December'];

const pad2 = (n) => String(n).padStart(2, '0');

function toTime(date) {
  const t = date instanceof Date ? date.getTime() : Number(date);
  if (!Number.isFinite(t)) throw new RangeError('Invalid date');
  return t;
}

// ---------------------------------------------------------------------------
// Wall-clock parts

const partFormatters = new Map();

function partsFormatter(tz) {
  let formatter = partFormatters.get(tz);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: tz,
      hourCycle: 'h23',
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      second: 'numeric',
    });
    partFormatters.set(tz, formatter);
  }
  return formatter;
}

/** Day of the week (0 = Sunday) of a proleptic Gregorian calendar date. */
export function weekdayOf(year, month, day) {
  return new Date(utcFromWall({ year, month, day })).getUTCDay();
}

/** Treats a wall-clock reading as if it were UTC and returns its epoch milliseconds. */
function utcFromWall({ year, month, day, hour = 0, minute = 0, second = 0 }) {
  const date = new Date(Date.UTC(2000, month - 1, day, hour, minute, second));
  date.setUTCFullYear(year + (date.getUTCFullYear() - 2000)); // keeps years 0–99 literal
  return date.getTime();
}

/**
 * The wall-clock reading of `date` in `tz`:
 * `{ year, month (1–12), day, hour (0–23), minute, second, weekday (0 = Sunday) }`.
 */
export function wallParts(date, tz) {
  const values = {};
  for (const { type, value } of partsFormatter(tz).formatToParts(toTime(date))) {
    if (type !== 'literal') values[type] = Number(value);
  }
  const { year, month, day, minute, second } = values;
  const hour = values.hour === 24 ? 0 : values.hour; // some engines print midnight as 24
  return { year, month, day, hour, minute, second, weekday: weekdayOf(year, month, day) };
}

// ---------------------------------------------------------------------------
// Offsets

/** Minutes east of UTC that `tz` observes at `date` (IST → 330, EDT → −240, EST → −300). */
export function zoneOffsetMinutes(tz, date) {
  const t = toTime(date);
  const wallAsUtc = utcFromWall(wallParts(t, tz));
  const wholeSeconds = Math.floor(t / 1000) * 1000;
  return Math.round((wallAsUtc - wholeSeconds) / MINUTE);
}

/** "IST" for India, "EDT"/"EST" for US Eastern, otherwise "UTC+h:mm". */
export function abbreviation(tz, date) {
  if (tz === IST) return 'IST';
  const offset = zoneOffsetMinutes(tz, date);
  if (tz === ET) {
    if (offset === -240) return 'EDT';
    if (offset === -300) return 'EST';
  }
  return formatUtcOffset(offset);
}

function sameWall(a, b) {
  return a.year === b.year && a.month === b.month && a.day === b.day
    && a.hour === b.hour && a.minute === b.minute;
}

/** True when `{year, month, day, hour, minute}` names a real calendar date and time. */
export function isValidWall(wall) {
  if (!wall) return false;
  const { year, month, day, hour = 0, minute = 0 } = wall;
  if (![year, month, day, hour, minute].every(Number.isInteger)) return false;
  if (month < 1 || month > 12 || day < 1 || hour < 0 || hour > 23 || minute < 0 || minute > 59) return false;
  const check = new Date(utcFromWall({ year, month, day }));
  return check.getUTCDate() === day && check.getUTCMonth() === month - 1;
}

/**
 * Finds the instant at which `tz` shows the wall time `{year, month, day, hour, minute}`.
 *
 * Iterates over the offsets the zone uses around that wall time and keeps the
 * ones that round-trip, so daylight-saving transitions are handled:
 * - `exact`: one match.
 * - `ambiguous`: the time happens twice (fall back). `date` is the first one and
 *   `alternatives` lists both, like Temporal's "compatible" disambiguation.
 * - `gap`: the time is skipped (spring forward). `date` is moved forward by the
 *   length of the gap, so 2:30 AM becomes 3:30 AM daylight time.
 */
export function resolveWallTime(wall, tz) {
  if (!isValidWall(wall)) throw new RangeError('Invalid wall time');
  const target = { ...wall, hour: wall.hour ?? 0, minute: wall.minute ?? 0, second: 0 };
  const wallMs = utcFromWall(target);

  const offsets = new Set();
  for (const probe of [wallMs - DAY, wallMs, wallMs + DAY]) {
    // Fixed-point iteration: instant = wall − offset(instant). Converges in one or two steps
    // except inside a gap, where it oscillates; every offset it visits is a candidate.
    let instant = probe;
    for (let i = 0; i < 4; i += 1) {
      const offset = zoneOffsetMinutes(tz, instant);
      offsets.add(offset);
      const next = wallMs - offset * MINUTE;
      if (next === instant) break;
      instant = next;
    }
  }

  const candidates = [...offsets].map((offset) => wallMs - offset * MINUTE);
  const matches = [...new Set(candidates.filter((t) => sameWall(wallParts(t, tz), target)))].sort((a, b) => a - b);
  if (matches.length > 0) {
    return {
      date: new Date(matches[0]),
      status: matches.length > 1 ? 'ambiguous' : 'exact',
      alternatives: matches.map((t) => new Date(t)),
    };
  }

  // Skipped wall time: use the offset from before the transition, which lands after it.
  const sortedOffsets = [...offsets].sort((a, b) => a - b);
  const later = Math.max(...candidates);
  return {
    date: new Date(later),
    status: 'gap',
    gapMinutes: sortedOffsets[sortedOffsets.length - 1] - sortedOffsets[0],
    alternatives: [],
  };
}

/** The instant at which `tz` shows the given wall time (see `resolveWallTime`). */
export function zonedWallTimeToDate(wall, tz) {
  return resolveWallTime(wall, tz).date;
}

/** Calendar days from wall date `from` to wall date `to` (−1 = previous day). */
export function calendarDayDifference(from, to) {
  const a = utcFromWall({ year: from.year, month: from.month, day: from.day });
  const b = utcFromWall({ year: to.year, month: to.month, day: to.day });
  return Math.round((b - a) / DAY);
}

/**
 * Converts a wall time in `fromTz` to `toTz`.
 * `offsetMinutes` is how far the target zone is from the source (−630 for IST → EST).
 */
export function convert(wall, fromTz = IST, toTz = ET) {
  const resolved = resolveWallTime(wall, fromTz);
  const { date } = resolved;
  const sourceParts = wallParts(date, fromTz);
  const targetParts = wallParts(date, toTz);
  const sourceOffsetMinutes = zoneOffsetMinutes(fromTz, date);
  const targetOffsetMinutes = zoneOffsetMinutes(toTz, date);
  return {
    date,
    status: resolved.status,
    alternatives: resolved.alternatives,
    gapMinutes: resolved.gapMinutes ?? 0,
    requested: { year: wall.year, month: wall.month, day: wall.day, hour: wall.hour ?? 0, minute: wall.minute ?? 0 },
    sourceParts,
    targetParts,
    dayShift: calendarDayDifference(sourceParts, targetParts),
    offsetMinutes: targetOffsetMinutes - sourceOffsetMinutes,
    sourceOffsetMinutes,
    targetOffsetMinutes,
    sourceAbbr: abbreviation(fromTz, date),
    targetAbbr: abbreviation(toTz, date),
  };
}

/**
 * The next time `tz` changes its UTC offset after `fromDate`, found by scanning
 * day by day and then bisecting to the minute. `gapMinutes` is the new offset of
 * `tz` relative to `referenceTz` (−630 when New York moves to EST). `null` if no
 * change happens within `maxDays`.
 */
export function nextOffsetChange(fromDate = new Date(), tz = ET, { referenceTz = IST, maxDays = 800 } = {}) {
  let low = Math.floor(toTime(fromDate) / MINUTE) * MINUTE;
  const startOffset = zoneOffsetMinutes(tz, low);
  for (let i = 0; i < maxDays; i += 1) {
    const high = low + DAY;
    if (zoneOffsetMinutes(tz, high) !== startOffset) {
      let before = low;
      let after = high;
      while (after - before > MINUTE) {
        const middle = before + Math.floor((after - before) / 2 / MINUTE) * MINUTE;
        if (zoneOffsetMinutes(tz, middle) === startOffset) before = middle;
        else after = middle;
      }
      const date = new Date(after);
      const toOffsetMinutes = zoneOffsetMinutes(tz, date);
      return {
        date,
        tz,
        fromOffsetMinutes: startOffset,
        toOffsetMinutes,
        fromAbbr: abbreviation(tz, new Date(before)),
        toAbbr: abbreviation(tz, date),
        direction: toOffsetMinutes > startOffset ? 'forward' : 'back',
        previousGapMinutes: startOffset - zoneOffsetMinutes(referenceTz, before),
        gapMinutes: toOffsetMinutes - zoneOffsetMinutes(referenceTz, date),
      };
    }
    low = high;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Formatting (English, deterministic, independent of the visitor's locale)

/** `{ time: "10:30", period: "PM", h12: "10:30 PM", h24: "22:30" }` for wall parts. */
export function clockStrings({ hour, minute }) {
  const hour12 = hour % 12 === 0 ? 12 : hour % 12;
  const time = `${hour12}:${pad2(minute)}`;
  const period = hour < 12 ? 'AM' : 'PM';
  return { time, period, h12: `${time} ${period}`, h24: `${pad2(hour)}:${pad2(minute)}` };
}

/** "10:30 PM" (default) or "22:30" with `{ hour12: false }`. */
export function formatTime(date, tz, { hour12 = true } = {}) {
  const strings = clockStrings(wallParts(date, tz));
  return hour12 ? strings.h12 : strings.h24;
}

/**
 * "Wed, Jan 14, 2026". Options: `style: 'long'` → "Wednesday, January 14, 2026";
 * `weekday: 'long'` → "Wednesday, Jan 14, 2026"; `year: false` → "Wed, Jan 14".
 */
export function formatWallDate({ year, month, day, weekday }, { style = 'short', weekday: weekdayStyle = style, year: withYear = true } = {}) {
  const dow = weekday ?? weekdayOf(year, month, day);
  const weekdays = weekdayStyle === 'long' ? WEEKDAYS_LONG : WEEKDAYS_SHORT;
  const months = style === 'long' ? MONTHS_LONG : MONTHS_SHORT;
  const text = `${weekdays[dow]}, ${months[month - 1]} ${day}`;
  return withYear ? `${text}, ${year}` : text;
}

/** Date of `date` as seen in `tz`, e.g. "Sun, Nov 1, 2026". */
export function formatDate(date, tz, options) {
  return formatWallDate(wallParts(date, tz), options);
}

/** "Monday" */
export function weekdayName(parts, style = 'long') {
  const dow = parts.weekday ?? weekdayOf(parts.year, parts.month, parts.day);
  return (style === 'long' ? WEEKDAYS_LONG : WEEKDAYS_SHORT)[dow];
}

/** "9h 30m", "10h", "45m": the magnitude of an offset. */
export function formatDuration(minutes) {
  const total = Math.abs(Math.round(minutes));
  const hours = Math.floor(total / 60);
  const mins = total % 60;
  if (hours === 0) return `${mins}m`;
  return mins === 0 ? `${hours}h` : `${hours}h ${mins}m`;
}

/** "9h 30m behind", "5h 30m ahead" or "Same time". */
export function describeOffset(minutes) {
  if (Math.round(minutes) === 0) return 'Same time';
  return `${formatDuration(minutes)} ${minutes < 0 ? 'behind' : 'ahead'}`;
}

/** "9h 30m behind India", "5h 30m ahead of New York" or "the same time as India". */
export function describeOffsetFrom(minutes, place) {
  if (Math.round(minutes) === 0) return `the same time as ${place}`;
  return `${formatDuration(minutes)} ${minutes < 0 ? 'behind' : 'ahead of'} ${place}`;
}

/** Clock-style signed offset with a true minus sign: "−9:30", "+5:30", "±0:00". */
export function compactOffset(minutes) {
  const total = Math.abs(Math.round(minutes));
  const sign = minutes < 0 ? MINUS : minutes > 0 ? '+' : '±';
  return `${sign}${Math.floor(total / 60)}:${pad2(total % 60)}`;
}

/** "UTC+5:30", "UTC−4". */
export function formatUtcOffset(minutes) {
  if (Math.round(minutes) === 0) return 'UTC';
  const total = Math.abs(Math.round(minutes));
  const sign = minutes < 0 ? MINUS : '+';
  const mins = total % 60;
  return `UTC${sign}${Math.floor(total / 60)}${mins ? `:${pad2(mins)}` : ''}`;
}

/** "same day", "previous day", "next day", "2 days later", "2 days earlier". */
export function dayShiftLabel(days) {
  if (days === 0) return 'same day';
  if (days === -1) return 'previous day';
  if (days === 1) return 'next day';
  return days > 0 ? `${days} days later` : `${-days} days earlier`;
}

// ---------------------------------------------------------------------------
// Input and URL helpers

/** "2026-10-19" and "21:30" → wall parts, or `null` when invalid. */
export function parseDateAndTime(dateText, timeText) {
  const d = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(dateText ?? '').trim());
  const t = /^(\d{1,2}):(\d{2})(?::\d{2}(?:\.\d+)?)?$/.exec(String(timeText ?? '').trim());
  if (!d || !t) return null;
  const wall = { year: +d[1], month: +d[2], day: +d[3], hour: +t[1], minute: +t[2] };
  return isValidWall(wall) ? wall : null;
}

/** "2026-10-19T21:30" → wall parts, or `null` when invalid. */
export function parseDateTimeLocal(text) {
  const [date, time] = String(text ?? '').trim().split('T');
  return parseDateAndTime(date, time);
}

/** `{ date: "2026-10-19", time: "21:30", local: "2026-10-19T21:30" }` */
export function wallToInputValues({ year, month, day, hour = 0, minute = 0 }) {
  const date = `${String(year).padStart(4, '0')}-${pad2(month)}-${pad2(day)}`;
  const time = `${pad2(hour)}:${pad2(minute)}`;
  return { date, time, local: `${date}T${time}` };
}

/** Reads `?from=ist&t=2026-10-19T21:30`. Returns `{ from, wall }` or `null`. */
export function parseQuery(search) {
  const params = new URLSearchParams(search);
  const wall = parseDateTimeLocal(params.get('t'));
  if (!wall) return null;
  const from = (params.get('from') || 'ist').toLowerCase() === 'et' ? 'et' : 'ist';
  return { from, wall };
}

/** The query string for a converter state: "?from=ist&t=2026-10-19T21:30". */
export function buildQuery({ from, wall }) {
  const params = new URLSearchParams({ from: from === 'et' ? 'et' : 'ist', t: wallToInputValues(wall).local });
  return `?${params.toString().replace('%3A', ':')}`;
}

// ---------------------------------------------------------------------------
// Copy for the page

/**
 * Plain-language summary of the current gap and the next daylight-saving change, e.g.
 * "On Sun, Nov 1, 2026 US clocks fall back; New York will be 10h 30m behind India."
 */
export function nowSummary(date = new Date()) {
  const etOffset = zoneOffsetMinutes(ET, date);
  const gapMinutes = etOffset - zoneOffsetMinutes(IST, date);
  const etAbbr = abbreviation(ET, date);
  const change = nextOffsetChange(date, ET);
  const current = `New York is on ${etAbbr} (${formatUtcOffset(etOffset)}), ${describeOffsetFrom(gapMinutes, 'India')}.`;
  let next = '';
  if (change) {
    const when = formatDate(change.date, ET);
    const verb = change.direction === 'back' ? 'fall back' : 'spring forward';
    next = `On ${when} US clocks ${verb}; New York will be ${describeOffsetFrom(change.gapMinutes, 'India')}.`;
  }
  return { gapMinutes, etAbbr, change, current, next, sentence: next ? `${current} ${next}` : current };
}
