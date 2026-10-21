import { readFileSync, existsSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { generateStructured, makeOpenAiTransport, toDataUri } from '../src/ai/client.js';
import { loadEnv } from '../src/env.js';

const envFile = existsSync('.env') ? readFileSync('.env', 'utf8') : '';
const key = envFile.match(/^OPENAI_API_KEY=(.+)$/m)?.[1]?.trim();
const model = envFile.match(/^OPENAI_VISION_MODEL=(.+)$/m)?.[1]?.trim();
const ready = Boolean(key) && Boolean(model) && model !== 'pending';

describe.skipIf(!ready)('generateStructured against the real model', () => {
  // Vitest still runs this callback when the suite is skipped, and loadEnv
  // throws on an empty key. Leave before that so `vitest run` stays quiet
  // on a machine with no .env.
  if (!ready) return;

  const env = loadEnv({
    NODE_ENV: 'test',
    PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'x',
    OPENAI_API_KEY: key!, OPENAI_VISION_MODEL: model!,
    FIREBASE_PROJECT_ID: 'x', INTERNAL_TOKEN: 'x', LINK_SECRET: 'link-secret',
  });

  const schema = z.object({
    merchant: z.string().nullable(),
    lines: z.array(z.object({ name: z.string(), qty: z.number().int() })),
  });

  it('reads the Little Bao House receipt into schema-valid JSON', async () => {
    const img = toDataUri(readFileSync('../samples/receipts/little-bao-house.png'), 'image/png');

    const result = await generateStructured(
      {
        schemaName: 'probe',
        schema,
        jsonSchema: {
          type: 'object', additionalProperties: false,
          required: ['merchant', 'lines'],
          properties: {
            merchant: { type: ['string', 'null'] },
            lines: {
              type: 'array',
              items: {
                type: 'object', additionalProperties: false,
                required: ['name', 'qty'],
                properties: { name: { type: 'string' }, qty: { type: 'integer' } },
              },
            },
          },
        },
        system: 'List the item lines on this receipt with their quantities. "Lager x3" is one line with qty 3.',
        images: [img],
      },
      makeOpenAiTransport(env),
      env.OPENAI_VISION_MODEL,
    );

    expect(result.merchant).toMatch(/Little Bao/i);
    expect(result.lines).toHaveLength(10);
    expect(result.lines.find((l) => /lager/i.test(l.name))?.qty).toBe(3);
  }, 60_000);
});
