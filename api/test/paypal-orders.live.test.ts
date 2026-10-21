import { existsSync, readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { makePayPalClient } from '../src/paypal/client.js';
import { createPayPalOrder } from '../src/paypal/orders.js';
import { loadEnv } from '../src/env.js';

const envFile = existsSync('.env') ? readFileSync('.env', 'utf8') : '';
const id = envFile.match(/^PAYPAL_CLIENT_ID=(.+)$/m)?.[1]?.trim();
const secret = envFile.match(/^PAYPAL_CLIENT_SECRET=(.+)$/m)?.[1]?.trim();
const ready = Boolean(id) && Boolean(secret);


describe.skipIf(!ready)('createPayPalOrder against the real sandbox', () => {
  // Vitest still runs this callback when the suite is skipped, and loadEnv
  // throws on an empty key. Leave before that so `vitest run` stays quiet
  // on a machine with no .env.
  if (!ready) return;

  const env = loadEnv({
    NODE_ENV: 'test',
    PAYPAL_CLIENT_ID: id!, PAYPAL_CLIENT_SECRET: secret!, PAYPAL_WEBHOOK_ID: 'x',
    OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'm',
    FIREBASE_PROJECT_ID: 'x', INTERNAL_TOKEN: 'x', LINK_SECRET: 'link-secret',
  });

  it('builds a body PayPal accepts, and returns a usable checkout link', async () => {
    const out = await createPayPalOrder(
      {
        referenceId: 'dan',
        customId: 'live:probe:dan',
        amountMinor: 3923,
        description: 'Your share of Friday dinner (Little Bao House)',
        payeeEmail: null,
        requestId: `live-probe-${Date.now()}`,
      },
      makePayPalClient(env),
    );
    expect(out.paypalOrderId).toMatch(/^[A-Z0-9]+$/);
    expect(out.approvalUrl).toContain('checkoutnow?token=');
    expect(out.approvalUrl).toContain(out.paypalOrderId);
  }, 60_000);
});
