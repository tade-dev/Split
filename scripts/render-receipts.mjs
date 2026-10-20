// Renders samples/receipts/*.html to PNG with Playwright's Chromium.
//
//   npm i --prefix /tmp/pw playwright@1.56.1
//   NODE_PATH=/tmp/pw/node_modules node scripts/render-receipts.mjs
//
// Set CHROMIUM_PATH to use a preinstalled browser instead of Playwright's own.
// Playwright is deliberately not an api/ or app/ dependency: this runs only
// when a sample receipt changes.
import { readdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const dir = resolve(dirname(fileURLToPath(import.meta.url)), '../samples/receipts');
const browser = await chromium.launch(
  process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {},
);
const page = await browser.newPage({ viewport: { width: 380, height: 600 }, deviceScaleFactor: 2 });
for (const file of readdirSync(dir).filter((f) => f.endsWith('.html')).sort()) {
  await page.goto(pathToFileURL(join(dir, file)).href);
  const out = join(dir, file.replace(/\.html$/, '.png'));
  await page.locator('.paper').screenshot({ path: out });
  console.log('rendered', out);
}
await browser.close();
