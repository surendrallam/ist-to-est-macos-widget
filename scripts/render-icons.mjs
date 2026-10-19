// Renders design/AppIcon.svg into the Xcode asset catalog and the website.
// Usage: node scripts/render-icons.mjs   (needs Playwright with Chromium)
import { chromium } from 'playwright';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const svg = await readFile(join(root, 'design/AppIcon.svg'), 'utf8');
const appIconSet = join(root, 'App/Assets.xcassets/AppIcon.appiconset');
const docsAssets = join(root, 'docs/assets');
await mkdir(appIconSet, { recursive: true });
await mkdir(docsAssets, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage();

async function render(pixels, outPath) {
  await page.setViewportSize({ width: pixels, height: pixels });
  const sized = svg.replace('width="1024" height="1024"', `width="${pixels}" height="${pixels}"`);
  await page.setContent(`<html><body style="margin:0;background:transparent">${sized}</body></html>`);
  await page.screenshot({ path: outPath, omitBackground: true, clip: { x: 0, y: 0, width: pixels, height: pixels } });
}

const macSizes = [16, 32, 128, 256, 512];
const images = [];
for (const size of macSizes) {
  for (const scale of [1, 2]) {
    const filename = `icon_${size}x${size}${scale === 2 ? '@2x' : ''}.png`;
    await render(size * scale, join(appIconSet, filename));
    images.push({ filename, idiom: 'mac', scale: `${scale}x`, size: `${size}x${size}` });
  }
}
await writeFile(join(appIconSet, 'Contents.json'),
  JSON.stringify({ images, info: { author: 'xcode', version: 1 } }, null, 2) + '\n');

await render(180, join(docsAssets, 'apple-touch-icon.png'));
await render(512, join(docsAssets, 'icon-512.png'));
await render(192, join(docsAssets, 'icon-192.png'));
await browser.close();
console.log('Rendered app icons');
