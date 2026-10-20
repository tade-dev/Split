import { readFileSync, existsSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { makeOpenAiTransport } from '../src/ai/client.js';
import { extractReceipt, toDraftReceipt } from '../src/ai/extract_receipt.js';
import { loadDemoSplit } from '../src/domain/demo.js';
import { loadEnv } from '../src/env.js';

// The model spike (spec §7.1, plan Task 7). Run once per candidate model,
// changing OPENAI_VISION_MODEL in api/.env, and record the logged lines in
// docs/verified-facts.md. Skips on a machine with no .env.
const envFile = existsSync('.env') ? readFileSync('.env', 'utf8') : '';
const key = envFile.match(/^OPENAI_API_KEY=(.+)$/m)?.[1]?.trim();
const model = envFile.match(/^OPENAI_VISION_MODEL=(.+)$/m)?.[1]?.trim();
const ready = Boolean(key) && Boolean(model) && model !== 'pending';

const receipt = (name: string) => ({
  buffer: readFileSync(new URL(`../../samples/receipts/${name}.png`, import.meta.url)),
  mime: 'image/png',
});

describe.skipIf(!ready)('extractReceipt against the real model', () => {
  // Vitest still runs this callback when the suite is skipped, and loadEnv
  // throws on an empty key. Leave before that.
  if (!ready) return;

  const env = loadEnv({
    NODE_ENV: 'test',
    PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'x',
    OPENAI_API_KEY: key!, OPENAI_VISION_MODEL: model!,
    FIREBASE_PROJECT_ID: 'x', INTERNAL_TOKEN: 'x',
  });
  const transport = makeOpenAiTransport(env);

  async function read(label: string, names: string[]) {
    const started = Date.now();
    const extraction = await extractReceipt(names.map(receipt), transport, model!);
    const draft = toDraftReceipt(extraction);
    console.log(JSON.stringify({
      spike: label, model, ms: Date.now() - started,
      lines: draft.receipt.lines.length, total: draft.receipt.printedTotalMinor,
      blocking: draft.ambiguities.filter((a) => a.blocking).map((a) => a.question),
    }));
    return draft;
  }

  const clean = (draft: Awaited<ReturnType<typeof read>>) =>
    expect(draft.ambiguities.filter((a) => a.blocking)).toEqual([]);

  it('reads Little Bao House line for line, Lager x3 as qty 3 / 1650', async () => {
    const draft = await read('little-bao-house', ['little-bao-house']);
    clean(draft);
    expect(draft.receipt.printedTotalMinor).toBe(15469);
    const expected = loadDemoSplit().receipt.lines.map(({ name, qty, lineTotalMinor }) => ({ name, qty, lineTotalMinor }));
    expect(draft.receipt.lines.map(({ name, qty, lineTotalMinor }) => ({ name: name.replace(/\s*x\d+$/i, ''), qty, lineTotalMinor })))
      .toEqual(expected);
  }, 60_000);

  it('reads a discount as money off', async () => {
    const draft = await read('brunch-discount', ['brunch-discount']);
    clean(draft);
    expect(draft.receipt.printedTotalMinor).toBe(5377);
    expect(draft.receipt.discounts.reduce((t, d) => t + d.amountMinor, 0)).toBe(598);
  }, 60_000);

  it('reads a bill with no service charge', async () => {
    const draft = await read('pub-no-service', ['pub-no-service']);
    clean(draft);
    expect(draft.receipt.printedTotalMinor).toBe(8830);
    expect(draft.receipt.serviceChargeMinor).toBe(0);
  }, 60_000);

  it('joins a long bill from two photos without double-counting the overlap', async () => {
    const draft = await read('long-curry', ['long-curry-part1', 'long-curry-part2']);
    clean(draft);
    expect(draft.receipt.printedTotalMinor).toBe(19384);
    expect(draft.receipt.lines).toHaveLength(18);
  }, 90_000);
});
