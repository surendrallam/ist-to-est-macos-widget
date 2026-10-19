// Renders scripts/og-image.html to docs/assets/og-image.png (1200×630) for
// Open Graph and Twitter cards, and fails if any text is clipped.
// Usage: node scripts/render-og-image.mjs   (needs Playwright with Chromium)
import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const WIDTH = 1200;
const HEIGHT = 630;
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const template = join(root, 'scripts/og-image.html');
const output = join(root, 'docs/assets/og-image.png');

const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: WIDTH, height: HEIGHT }, deviceScaleFactor: 1 });
  await page.goto(pathToFileURL(template).href, { waitUntil: 'load' });
  await page.evaluate(() => document.fonts.ready);

  const problems = await page.evaluate(({ width, height }) => {
    const issues = [];
    const icon = document.querySelector('.icon');
    if (!icon || !icon.complete || icon.naturalWidth === 0) issues.push('app icon did not load');
    for (const el of document.querySelectorAll('body *')) {
      if (!el.textContent.trim() || el.children.length > 0 && el.tagName !== 'H1') continue;
      const rect = el.getBoundingClientRect();
      if (rect.left < 0 || rect.top < 0 || rect.right > width || rect.bottom > height) {
        issues.push(`"${el.textContent.trim()}" overflows the image (${Math.round(rect.right)}×${Math.round(rect.bottom)})`);
      }
      if (el.scrollWidth > el.clientWidth + 1 && getComputedStyle(el).overflow !== 'visible') {
        issues.push(`"${el.textContent.trim()}" is clipped`);
      }
    }
    const copy = document.querySelector('.copy').getBoundingClientRect();
    for (const el of document.querySelectorAll('.copy *')) {
      const rect = el.getBoundingClientRect();
      if (rect.width && rect.right > copy.right + 1) issues.push(`"${el.textContent.trim()}" runs past its column`);
    }
    return issues;
  }, { width: WIDTH, height: HEIGHT });
  if (problems.length) throw new Error(`OG image layout problems:\n- ${problems.join('\n- ')}`);

  await mkdir(dirname(output), { recursive: true });
  await page.screenshot({ path: output, clip: { x: 0, y: 0, width: WIDTH, height: HEIGHT } });
  console.log(`Rendered ${output}`);
} finally {
  await browser.close();
}
