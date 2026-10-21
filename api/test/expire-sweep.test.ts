import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import { ApiError } from '../src/lib/errors.js';
import type { PayPalFetch } from '../src/paypal/client.js';
import type { ParticipantDoc } from '../src/domain/splits.js';
import { order, person, seedCollecting, statusOf } from './shares-fixture.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const base = {
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'x',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-expiry-test', INTERNAL_TOKEN: 'sweep-secret', LINK_SECRET: 'link-secret',
};

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-expiry-test' });
  db = getFirestore();
});

const HOUR = 60 * 60 * 1000;

function paypal(body: (id: string) => unknown = (id) => ({ id, status: 'PAYER_ACTION_REQUIRED', purchase_units: [] })): { fetch: PayPalFetch; calls: string[] } {
  const calls: string[] = [];
  const fetch: PayPalFetch = async (path, init) => {
    calls.push(`${init.method} ${path}`);
    return body(path.includes('PPJOSH') ? 'PPJOSH' : 'PPDAN');
  };
  return { fetch, calls };
}

function appWith(fetch: PayPalFetch = paypal().fetch, extraEnv: Record<string, string> = {}) {
  return createApp({
    env: loadEnv({ ...base, ...extraEnv }), db, paypal: fetch,
    transport: async () => ({ content: '{}' }),
    verify: async () => { throw new Error('the sweep is not an organiser'); },
  });
}

/** Dan's order is `hoursAgo` old; Josh has none, so only Dan is ever in play. */
const seed = (hoursAgo: number, dan: Partial<ParticipantDoc> = {}) =>
  seedCollecting(db, {
    dan: { paypalOrderCreatedAt: Timestamp.fromMillis(Date.now() - hoursAgo * HOUR), ...dan },
    josh: { status: 'owes', paypalOrderId: null, approvalUrl: null },
  });

function sweep(app: ReturnType<typeof appWith>, token = 'sweep-secret') {
  return request(app).post('/v1/internal/workflows/expire-sweep').set('X-Internal-Token', token);
}

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

describe('POST /v1/internal/workflows/expire-sweep', () => {
  it('refuses a call without the internal token', async () => {
    await seed(200);
    expect((await request(appWith()).post('/v1/internal/workflows/expire-sweep')).status).toBe(401);
    expect((await sweep(appWith(), 'nope')).status).toBe(401);
    expect(await statusOf(db, 'dan')).toBe('link_opened');
  });

  it('replaces an unpaid order older than seven days, once PayPal confirms it is unpaid', async () => {
    await seed(169);
    const { fetch, calls } = paypal();
    const res = await sweep(appWith(fetch));

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ scanned: 1, expired: 1, kept: 0, failed: 0 });
    expect(calls).toEqual(['GET /v2/checkout/orders/PPDAN']);
    const dan = await person(db, 'dan').get();
    expect(dan.get('status')).toBe('owes');
    expect(dan.get('paypalOrderId')).toBeNull();
    expect(dan.get('approvalUrl')).toBeNull();
    expect(dan.get('supersededPaypalOrderIds')).toEqual(['PPDAN']);
    const event = await person(db, 'dan').collection('paymentEvents').doc('expire-PPDAN').get();
    expect(event.get('eventType')).toBe('expired');
    expect(event.get('raw')).toEqual({ source: 'expiry_sweep', from: 'link_opened' });
  });

  it('gives the next Pay tap a fresh PayPal request id', async () => {
    await seed(169);
    await sweep(appWith());
    const dan = (await person(db, 'dan').get()).data() as ParticipantDoc;
    // The Pay route keys its request id on how many orders were replaced.
    expect(dan.supersededPaypalOrderIds).toHaveLength(1);
  });

  it('leaves an order younger than the TTL without asking PayPal', async () => {
    await seed(167);
    const { fetch, calls } = paypal();
    const res = await sweep(appWith(fetch));
    expect(res.body).toEqual({ scanned: 0, expired: 0, kept: 0, failed: 0 });
    expect(calls).toEqual([]);
    expect(await statusOf(db, 'dan')).toBe('link_opened');
  });

  it('follows ORDER_EXPIRY_HOURS', async () => {
    await seed(3);
    const res = await sweep(appWith(paypal().fetch, { ORDER_EXPIRY_HOURS: '2' }));
    expect(res.body.expired).toBe(1);
    expect(await statusOf(db, 'dan')).toBe('owes');
  });

  it('replaces a declined order the friend never retried', async () => {
    await seed(200, { status: 'declined' });
    const res = await sweep(appWith());
    expect(res.body.expired).toBe(1);
    expect(await statusOf(db, 'dan')).toBe('owes');
  });

  it('marks a missed payment paid instead of replacing it', async () => {
    await seed(200);
    const res = await sweep(appWith(paypal((id) => order(id, 'COMPLETED', 'COMPLETED')).fetch));
    expect(res.body).toEqual({ scanned: 1, expired: 0, kept: 1, failed: 0 });
    const dan = await person(db, 'dan').get();
    expect(dan.get('status')).toBe('paid');
    expect(dan.get('paypalOrderId')).toBe('PPDAN');
  });

  it('leaves a share for the next run when PayPal cannot be asked', async () => {
    await seed(200);
    const down: PayPalFetch = async () => {
      throw new ApiError(502, 'PAYPAL_UNAVAILABLE', 'down', { status: 503, detail: 'SERVICE_UNAVAILABLE' });
    };
    const res = await sweep(appWith(down));
    expect(res.body).toEqual({ scanned: 1, expired: 0, kept: 0, failed: 1 });
    expect(await statusOf(db, 'dan')).toBe('link_opened');
  });

  it('never touches a share that is paid or mid-payment', async () => {
    for (const status of ['paid', 'processing', 'pending'] as const) {
      await seed(200, { status });
      const { fetch, calls } = paypal();
      const res = await sweep(appWith(fetch));
      expect(res.body.scanned).toBe(0);
      expect(calls).toEqual([]);
      expect(await statusOf(db, 'dan')).toBe(status);
    }
  });

  it('is a no-op the second time round', async () => {
    await seed(200);
    await sweep(appWith());
    const again = await sweep(appWith());
    expect(again.body).toEqual({ scanned: 0, expired: 0, kept: 0, failed: 0 });
    const events = await person(db, 'dan').collection('paymentEvents').get();
    expect(events.size).toBe(1);
  });
});
