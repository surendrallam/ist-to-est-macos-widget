// Static checks for docs/index.html: SEO tags, JSON-LD, FAQ and the hourly table.
// Run with: node --test docs/tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile, access } from 'node:fs/promises';
import { IST, ET, convert, clockStrings } from '../assets/time.js';

const docs = new URL('../', import.meta.url);
const html = await readFile(new URL('index.html', docs), 'utf8');
const SITE = 'https://surendrallam.github.io/ist-to-est-macos-widget/';
const DMG = 'https://github.com/surendrallam/ist-to-est-macos-widget/releases/latest/download/IST-to-EST.dmg';

const decode = (text) => text
  .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
  .replace(/&quot;/g, '"').replace(/&#39;/g, "'");
const textOf = (fragment) => decode(fragment.replace(/<[^>]+>/g, '')).replace(/\s+/g, ' ').trim();
const meta = (attr, name) => {
  const match = new RegExp(`<meta ${attr}="${name}" content="([^"]*)"`).exec(html);
  return match ? decode(match[1]) : null;
};
const jsonLd = [...html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)]
  .map((m) => JSON.parse(m[1]));
const byType = (type) => jsonLd.find((block) => block['@type'] === type);

test('head has the SEO essentials', () => {
  assert.match(html, /^<!doctype html>\s*<html lang="en">/i);
  const title = textOf(/<title>([\s\S]*?)<\/title>/.exec(html)[1]);
  assert.ok(title.length < 60, `title is ${title.length} chars`);
  assert.match(title, /IST to EST Converter/);
  assert.match(title, /Mac Widget/);
  const description = meta('name', 'description');
  assert.ok(description.length >= 130 && description.length <= 160, `description is ${description.length} chars`);
  assert.match(html, new RegExp(`<link rel="canonical" href="${SITE}">`));
  assert.equal(meta('property', 'og:url'), SITE);
  assert.equal(meta('property', 'og:image'), `${SITE}assets/og-image.png`);
  assert.equal(meta('property', 'og:image:width'), '1200');
  assert.equal(meta('property', 'og:image:height'), '630');
  assert.equal(meta('name', 'twitter:card'), 'summary_large_image');
  assert.equal(meta('name', 'twitter:image'), `${SITE}assets/og-image.png`);
  assert.match(html, /<meta name="theme-color" content="[^"]+" media="\(prefers-color-scheme: light\)">/);
  assert.match(html, /<meta name="theme-color" content="[^"]+" media="\(prefers-color-scheme: dark\)">/);
  assert.match(html, /<link rel="manifest" href="site.webmanifest">/);
});

test('exactly one h1 and no third-party requests', () => {
  assert.equal((html.match(/<h1[\s>]/g) || []).length, 1);
  const external = [...html.matchAll(/\s(?:src|srcset)="(https?:[^"]+)"/g)].map((m) => m[1]);
  assert.deepEqual(external, []);
  assert.doesNotMatch(html, /<link rel="stylesheet"/);
  assert.doesNotMatch(html, /fonts\.googleapis|googletagmanager|google-analytics/);
});

test('JSON-LD describes the app, the site and the FAQ', () => {
  assert.equal(jsonLd.length, 3);
  const app = byType('SoftwareApplication');
  assert.equal(app.name, 'IST to EST');
  assert.equal(app.operatingSystem, 'macOS 14 or later');
  assert.equal(app.applicationCategory, 'UtilitiesApplication');
  assert.deepEqual(app.offers, { '@type': 'Offer', price: '0', priceCurrency: 'USD' });
  assert.equal(app.downloadUrl, DMG);
  assert.equal(app.softwareVersion, '1.0.0');
  assert.equal(app.license, 'https://opensource.org/licenses/MIT');
  assert.deepEqual(app.author, { '@type': 'Person', name: 'surendrallam', url: 'https://github.com/surendrallam' });
  assert.equal(app.screenshot, `${SITE}screenshots/widget-medium-summer-light.png`);
  assert.equal(byType('WebSite').url, SITE);
});

test('FAQ JSON-LD matches the visible FAQ word for word', () => {
  const visible = [...html.matchAll(/<details(?: open)?>\s*<summary>([\s\S]*?)<\/summary>\s*<div class="faq-answer">([\s\S]*?)<\/div>\s*<\/details>/g)]
    .map((m) => ({ q: textOf(m[1]), a: textOf(m[2]) }));
  const structured = byType('FAQPage').mainEntity.map((item) => ({ q: item.name, a: item.acceptedAnswer.text }));
  assert.ok(visible.length >= 8);
  assert.deepEqual(visible, structured);
});

test('the static conversion table matches time.js for every IST hour', () => {
  const body = /<tbody id="table-body">([\s\S]*?)<\/tbody>/.exec(html)[1];
  const rows = [...body.matchAll(/<tr>([\s\S]*?)<\/tr>/g)].map((m) => [...m[1].matchAll(/<t[hd][^>]*>([\s\S]*?)<\/t[hd]>/g)].map((c) => textOf(c[1])));
  assert.equal(rows.length, 24);
  const cell = (result) => {
    const strings = clockStrings(result.targetParts);
    const shift = result.dayShift === -1 ? ' (previous day)' : '';
    return `${strings.h12} ${strings.h24}${shift}`;
  };
  rows.forEach((cells, hour) => {
    const ist = clockStrings({ hour, minute: 0 });
    const summer = convert({ year: 2026, month: 7, day: 14, hour, minute: 0 }, IST, ET);
    const winter = convert({ year: 2026, month: 1, day: 15, hour, minute: 0 }, IST, ET);
    assert.equal(summer.targetAbbr, 'EDT');
    assert.equal(winter.targetAbbr, 'EST');
    assert.deepEqual(cells, [`${ist.h12} ${ist.h24}`, cell(summer), cell(winter)], `IST hour ${hour}`);
  });
});

test('every local link and asset exists (screenshots come from CI)', async () => {
  const refs = new Set();
  for (const file of ['index.html', '404.html']) {
    const page = await readFile(new URL(file, docs), 'utf8');
    for (const m of page.matchAll(/\s(?:href|src|srcset)="([^"]+)"/g)) refs.add(m[1]);
  }
  const manifest = JSON.parse(await readFile(new URL('site.webmanifest', docs), 'utf8'));
  for (const icon of manifest.icons) refs.add(icon.src);
  // 404.html uses root-relative links because GitHub Pages serves it at any missing path.
  const local = [...refs]
    .map((ref) => ref.replace(/^\/ist-to-est-macos-widget\//, './'))
    .filter((ref) => !/^(?:https?:|mailto:|#)/.test(ref) && !ref.startsWith('screenshots/'));
  assert.ok(local.length > 5);
  for (const ref of local) {
    const path = ref.split(/[?#]/)[0];
    await access(new URL(path === './' ? 'index.html' : path, docs)).catch(() => assert.fail(`missing ${ref}`));
  }
  for (const id of [...html.matchAll(/href="#([^"]+)"/g)].map((m) => m[1])) {
    assert.match(html, new RegExp(`id="${id}"`), `missing anchor #${id}`);
  }
});
