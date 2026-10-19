// DOM wiring for the IST to EST website: live clocks, converter, copy buttons.
// All time-zone math lives in time.js.
import {
  IST, ET, ZONES,
  wallParts, zoneOffsetMinutes, abbreviation, convert, nowSummary,
  clockStrings, formatWallDate, describeOffsetFrom, compactOffset, formatUtcOffset,
  dayShiftLabel, parseDateAndTime, wallToInputValues, parseQuery, buildQuery,
} from './time.js';

const $ = (id) => document.getElementById(id);
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

function setText(id, text) {
  const el = $(id);
  if (el && el.textContent !== text) el.textContent = text;
}

// ---------------------------------------------------------------------------
// Live clocks

function setHands(svg, parts) {
  if (!svg) return;
  const { hour, minute, second } = parts;
  const rotate = (selector, degrees) => {
    const hand = svg.querySelector(selector);
    if (hand) hand.setAttribute('transform', `rotate(${degrees.toFixed(2)} 50 50)`);
  };
  rotate('.hand-hour', ((hour % 12) + minute / 60) * 30);
  rotate('.hand-minute', (minute + second / 60) * 6);
  const secondHand = svg.querySelector('.hand-second');
  if (secondHand) {
    secondHand.hidden = reducedMotion.matches;
    secondHand.setAttribute('transform', `rotate(${second * 6} 50 50)`);
  }
  svg.classList.toggle('is-night', hour < 6 || hour >= 18);
}

let lastMinuteKey = '';

function renderZone(prefix, svgId, parts) {
  const strings = clockStrings(parts);
  setText(`${prefix}-time`, strings.time);
  setText(`${prefix}-period`, ` ${strings.period}`);
  setText(`${prefix}-date`, formatWallDate(parts, { year: false }));
  setHands($(svgId), parts);
}

function renderMinute(now) {
  const etAbbr = abbreviation(ET, now);
  const gap = zoneOffsetMinutes(ET, now) - zoneOffsetMinutes(IST, now);
  setText('et-abbr', etAbbr);
  setText('gap-badge', compactOffset(gap));
  setText('gap-text', `New York is ${describeOffsetFrom(gap, 'India')}`);
  setText('gap-utc', `${etAbbr} is ${formatUtcOffset(zoneOffsetMinutes(ET, now))}`);

  const summary = nowSummary(now);
  const sentence = $('now-sentence');
  if (sentence) {
    sentence.replaceChildren(
      'New York is on ',
      strong(`${etAbbr} (${formatUtcOffset(zoneOffsetMinutes(ET, now))})`),
      ', ',
      strong(describeOffsetFrom(gap, 'India')),
      '.',
      summary.next ? ` ${summary.next}` : '',
    );
  }

  // Highlight the current IST hour and the season in effect in the static table.
  const istHour = wallParts(now, IST).hour;
  const rows = $('table-body')?.rows ?? [];
  for (let i = 0; i < rows.length; i += 1) rows[i].classList.toggle('is-now', i === istHour);
  const summer = etAbbr === 'EDT';
  $('col-edt')?.classList.toggle('is-active', summer);
  $('col-est')?.classList.toggle('is-active', !summer);
  for (const [id, active] of [['th-edt', summer], ['th-est', !summer]]) {
    const th = $(id);
    if (!th) continue;
    let chip = th.querySelector('.now-chip');
    if (active && !chip) {
      chip = document.createElement('span');
      chip.className = 'now-chip';
      chip.textContent = 'now';
      th.firstChild.after(chip);
    } else if (!active && chip) {
      chip.remove();
    }
  }
  const tableNote = $('table-now-note');
  if (tableNote) {
    tableNote.textContent = `The highlighted row is the current hour in India; New York is on ${etAbbr} today. Times on the previous day are marked “(previous day)”.`;
  }

  try {
    const localTz = Intl.DateTimeFormat().resolvedOptions().timeZone;
    if (localTz && localTz !== IST && localTz !== ET && localTz !== 'Asia/Calcutta') {
      setText('live-local', `Your time: ${clockStrings(wallParts(now, localTz)).h12}`);
    } else {
      setText('live-local', '');
    }
  } catch {
    setText('live-local', '');
  }
}

function strong(text) {
  const el = document.createElement('strong');
  el.textContent = text;
  return el;
}

function tick() {
  const now = new Date();
  const ist = wallParts(now, IST);
  const et = wallParts(now, ET);
  renderZone('ist', 'clock-ist', ist);
  renderZone('et', 'clock-et', et);
  const minuteKey = `${ist.year}-${ist.month}-${ist.day} ${ist.hour}:${ist.minute}`;
  if (minuteKey !== lastMinuteKey) {
    lastMinuteKey = minuteKey;
    renderMinute(now);
  }
}

let tickTimer = 0;
function scheduleTick() {
  clearTimeout(tickTimer);
  tick();
  tickTimer = setTimeout(scheduleTick, 1000 - (Date.now() % 1000) + 5);
}

// ---------------------------------------------------------------------------
// Converter

const state = { from: 'ist', wall: null };
let lastResult = null;

function zoneFor(key) {
  return key === 'et' ? ZONES.et : ZONES.ist;
}

function updateLabels() {
  const source = zoneFor(state.from);
  const name = state.from === 'et' ? 'New York (ET)' : 'India (IST)';
  setText('conv-date-label', `Date in ${name}`);
  setText('conv-time-label', `Time in ${name}`);
  const radio = $(state.from === 'et' ? 'from-et' : 'from-ist');
  if (radio) radio.checked = true;
  return source;
}

function writeInputs() {
  if (!state.wall) return;
  const values = wallToInputValues(state.wall);
  $('conv-date').value = values.date;
  $('conv-time').value = values.time;
}

function readInputs() {
  return parseDateAndTime($('conv-date').value, $('conv-time').value);
}

function syncUrl() {
  if (!state.wall) return;
  const url = `${location.pathname}${buildQuery(state)}${location.hash}`;
  try {
    history.replaceState(null, '', url);
  } catch {
    // Some sandboxed previews forbid history changes; the converter still works.
  }
}

function renderConversion() {
  updateLabels();
  const dateInput = $('conv-date');
  const timeInput = $('conv-time');
  const valid = Boolean(state.wall);
  dateInput.setAttribute('aria-invalid', String(!dateInput.value));
  timeInput.setAttribute('aria-invalid', String(!timeInput.value));
  if (!valid) {
    lastResult = null;
    setText('r-from', 'Enter a date and a time to convert.');
    setText('r-time', '--:--');
    setText('r-period', '');
    setText('r-abbr', state.from === 'et' ? 'IST' : 'ET');
    setText('r-date', '');
    $('r-shift').hidden = true;
    setText('r-meta', '');
    $('r-note').hidden = true;
    return;
  }

  const fromTz = state.from === 'et' ? ET : IST;
  const toTz = state.from === 'et' ? IST : ET;
  const result = convert(state.wall, fromTz, toTz);
  lastResult = result;
  const source = clockStrings(result.sourceParts);
  const target = clockStrings(result.targetParts);
  const targetZone = zoneFor(state.from === 'et' ? 'ist' : 'et');
  const sourceZone = zoneFor(state.from);

  setText('r-from', `${formatWallDate(result.sourceParts, { weekday: 'long' })} at ${source.h12} ${result.sourceAbbr} is`);
  setText('r-time', target.time);
  setText('r-period', ` ${target.period}`);
  const abbr = $('r-abbr');
  abbr.textContent = result.targetAbbr;
  abbr.className = `r-abbr ${toTz === ET ? 'abbr-et' : 'abbr-ist'}`;
  setText('r-date', formatWallDate(result.targetParts, { weekday: 'long' }));
  const shift = $('r-shift');
  shift.hidden = result.dayShift === 0;
  shift.textContent = dayShiftLabel(result.dayShift);

  const nyGap = toTz === ET ? result.offsetMinutes : -result.offsetMinutes;
  const etOffset = toTz === ET ? result.targetOffsetMinutes : result.sourceOffsetMinutes;
  setText('r-meta', `${target.h24} in 24-hour time · New York is ${describeOffsetFrom(nyGap, 'India')} (${toTz === ET ? result.targetAbbr : result.sourceAbbr}, ${formatUtcOffset(etOffset)})`);

  const note = $('r-note');
  const requested = clockStrings(result.requested);
  if (result.status === 'gap') {
    note.hidden = false;
    note.textContent = `${requested.h12} doesn’t exist in ${sourceZone.city} on that date because clocks spring forward an hour, so this uses ${source.h12} ${result.sourceAbbr}.`;
  } else if (result.status === 'ambiguous') {
    const second = result.alternatives[1];
    const later = clockStrings(wallParts(second, toTz)).h12;
    note.hidden = false;
    note.textContent = `${requested.h12} happens twice in ${sourceZone.city} that night because clocks fall back. This is the first one (${result.sourceAbbr}); the second one (${abbreviation(fromTz, second)}) is ${later} in ${targetZone.city}.`;
  } else {
    note.hidden = true;
    note.textContent = '';
  }
}

function resultText() {
  if (!lastResult) return '';
  const r = lastResult;
  const source = clockStrings(r.sourceParts);
  const target = clockStrings(r.targetParts);
  const shift = r.dayShift ? ` (${dayShiftLabel(r.dayShift)})` : '';
  return `${source.h12} ${r.sourceAbbr}, ${formatWallDate(r.sourceParts)} = ${target.h12} ${r.targetAbbr} (${target.h24}), ${formatWallDate(r.targetParts)}${shift}`;
}

function onInput() {
  state.wall = readInputs();
  renderConversion();
  syncUrl();
}

function setNow() {
  const parts = wallParts(new Date(), zoneFor(state.from).tz);
  state.wall = { year: parts.year, month: parts.month, day: parts.day, hour: parts.hour, minute: parts.minute };
  writeInputs();
}

function initConverter() {
  const form = $('conv-form');
  if (!form) return;

  const restored = parseQuery(location.search);
  if (restored) {
    state.from = restored.from;
    state.wall = restored.wall;
    writeInputs();
  } else {
    setNow();
  }
  renderConversion();

  $('conv-date').addEventListener('input', onInput);
  $('conv-time').addEventListener('input', onInput);
  $('conv-date').addEventListener('change', onInput);
  $('conv-time').addEventListener('change', onInput);
  for (const radio of form.querySelectorAll('input[name="from"]')) {
    radio.addEventListener('change', () => {
      if (!radio.checked) return;
      state.from = radio.value === 'et' ? 'et' : 'ist';
      state.wall = readInputs();
      renderConversion();
      syncUrl();
    });
  }
  $('now-btn').addEventListener('click', () => {
    setNow();
    renderConversion();
    syncUrl();
  });
  $('swap-btn').addEventListener('click', () => {
    if (lastResult) {
      const { year, month, day, hour, minute } = lastResult.targetParts;
      state.wall = { year, month, day, hour, minute };
    }
    state.from = state.from === 'et' ? 'ist' : 'et';
    writeInputs();
    renderConversion();
    syncUrl();
  });
  $('copy-result').addEventListener('click', async () => {
    const text = resultText();
    if (!text) return;
    announceCopy(await copyText(text) ? 'Copied to clipboard' : 'Couldn’t copy. Select the result instead.');
  });
}

// ---------------------------------------------------------------------------
// Clipboard

async function copyText(text) {
  try {
    if (navigator.clipboard && window.isSecureContext) {
      await navigator.clipboard.writeText(text);
      return true;
    }
  } catch {
    // Fall back below.
  }
  const area = document.createElement('textarea');
  area.value = text;
  area.setAttribute('readonly', '');
  area.style.position = 'fixed';
  area.style.opacity = '0';
  document.body.append(area);
  area.select();
  let ok = false;
  try {
    ok = document.execCommand('copy');
  } catch {
    ok = false;
  }
  area.remove();
  return ok;
}

let statusTimer = 0;
function announceCopy(message) {
  const status = $('copy-status');
  if (!status) return;
  status.textContent = message;
  clearTimeout(statusTimer);
  statusTimer = setTimeout(() => { status.textContent = ''; }, 2500);
}

function initCodeCopy() {
  for (const button of document.querySelectorAll('[data-copy-target]')) {
    const status = button.parentElement.querySelector('.code-status');
    let timer = 0;
    button.addEventListener('click', async () => {
      const source = $(button.dataset.copyTarget);
      if (!source) return;
      const ok = await copyText(source.textContent.trim());
      if (!status) return;
      status.textContent = ok ? 'Copied' : 'Select the text to copy';
      clearTimeout(timer);
      timer = setTimeout(() => { status.textContent = ''; }, 2000);
    });
  }
}

// ---------------------------------------------------------------------------
// Screenshots: hide a figure whose PNG is missing; the live clock stays as the visual.

function initScreenshots() {
  const gallery = $('gallery');
  if (!gallery) return;
  const images = [...gallery.querySelectorAll('.shot img')];
  let failed = 0;
  const fail = (img) => {
    const figure = img.closest('figure');
    if (!figure || figure.hidden) return;
    figure.hidden = true;
    img.closest('.size-card')?.classList.add('no-shot');
    failed += 1;
    if (failed === images.length) gallery.classList.add('no-shots');
  };
  for (const img of images) {
    if (img.complete && img.naturalWidth === 0 && (img.currentSrc || img.src)) {
      fail(img);
    } else {
      img.addEventListener('error', () => fail(img), { once: true });
    }
  }
}

// ---------------------------------------------------------------------------

function init() {
  initScreenshots();
  initConverter();
  initCodeCopy();
  scheduleTick();
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) scheduleTick();
  });
  reducedMotion.addEventListener?.('change', tick);
}

init();
