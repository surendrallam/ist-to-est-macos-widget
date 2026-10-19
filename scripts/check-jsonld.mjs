#!/usr/bin/env node
// Checks that every <script type="application/ld+json"> block in the given HTML
// files parses as JSON and declares a schema.org @context and @type.
//
// Usage: node scripts/check-jsonld.mjs [file.html ...]   (default: docs/index.html)
import { readFile } from 'node:fs/promises';

const files = process.argv.slice(2);
if (files.length === 0) files.push('docs/index.html');

const blockPattern = /<script\b[^>]*\btype\s*=\s*["']?application\/ld\+json["']?[^>]*>([\s\S]*?)<\/script\s*>/gi;
let failures = 0;

function fail(message) {
  failures += 1;
  console.error(`✗ ${message}`);
}

function typesOf(node) {
  if (Array.isArray(node)) return node.flatMap(typesOf);
  if (node && typeof node === 'object') {
    const own = node['@type'] ? [].concat(node['@type']) : [];
    return own.concat(node['@graph'] ? typesOf(node['@graph']) : []);
  }
  return [];
}

for (const file of files) {
  let html;
  try {
    html = await readFile(file, 'utf8');
  } catch (error) {
    fail(`${file}: ${error.message}`);
    continue;
  }

  const blocks = [...html.matchAll(blockPattern)].map((match) => match[1]);
  if (blocks.length === 0) {
    fail(`${file}: no <script type="application/ld+json"> block found`);
    continue;
  }

  blocks.forEach((source, index) => {
    const label = `${file} JSON-LD block ${index + 1}`;
    let data;
    try {
      data = JSON.parse(source);
    } catch (error) {
      fail(`${label} is not valid JSON: ${error.message}`);
      return;
    }
    const before = failures;
    const roots = Array.isArray(data) ? data : [data];
    for (const root of roots) {
      const context = root?.['@context'];
      if (typeof context !== 'string' || !/^https?:\/\/schema\.org\/?$/.test(context)) {
        fail(`${label}: "@context" should be "https://schema.org" (got ${JSON.stringify(context)})`);
      }
    }
    const types = typesOf(data);
    if (types.length === 0) fail(`${label}: no "@type" found`);
    if (failures === before) console.log(`✓ ${label}: ${types.join(', ')}`);
  });
}

if (failures > 0) {
  console.error(`\n${failures} structured-data problem(s) found.`);
  process.exit(1);
}
