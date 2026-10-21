import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import { ApiError } from '../src/lib/errors.js';
import { shareSignature } from '../src/domain/links.js';
import type { PayPalFetch } from '../src/paypal/client.js';
import { SPLIT, order, person, seedCollecting, splitStatus, statusOf } from './shares-fixture.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-return-test', INTERNAL_TOKEN: 'reconcile-secret', LINK_SECRET: 'link-secret',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-return-test' });
  db = getFirestore();
});

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

const app = (fetch: PayPalFetch = async () => ({})) =>
  createApp({
    env, db, paypal: fetch,
    transport: async () => ({ content: '{}' }),
    verify: async () => { throw new Error('friends are not signed in'); },
  });

const danPage = `/v1/s/kemi/s1/dan/${shareSignature('link-secret', 'kemi', 's1', 'dan')}`;

/** PayPal for a payee order: approved on GET, COMPLETED on capture, and no webhook ever. */
function approvedThenCaptured(calls: string[] = []): PayPalFetch {
  return async (path, init) => {
    calls.push(`${init.method} ${path} ${init.requestId ?? ''}`.trim());
    const id = path.includes('PPJOSH') ? 'PPJOSH' : 'PPDAN';
    return path.endsWith('/capture') ? order(id, 'COMPLETED', 'COMPLETED') : order(id, 'APPROVED');
  };
}

describe('GET /v1/paypal/return', () => {
  it('captures on return, marks the share paid and sends the friend back to their page', async () => {
    await seedCollecting(db);
    const calls: string[] = [];
    const res = await request(app(approvedThenCaptured(calls))).get('/v1/paypal/return').query({ token: 'PPDAN', PayerID: 'X' });

    expect(res.status).toBe(303);
    expect(res.headers.location).toBe(danPage);
    expect(calls).toContain('POST /v2/checkout/orders/PPDAN/capture capture-dan-PPDAN');
    const dan = await person(db, 'dan').get();
    expect(dan.get('status')).toBe('paid');
    expect(dan.get('paypalCaptureId')).toBe('CAP-PPDAN');
    expect(dan.get('paidAt')).toBeTruthy();
    expect((await person(db, 'dan').collection('paymentEvents').doc('return-PPDAN-paid').get()).exists).toBe(true);
    // Josh still owes, so the split is not settled yet.
    expect(await splitStatus(db)).toBe('collecting');

    const page = await request(app()).get(danPage);
    expect(page.text).toContain('Paid. Thanks');
    expect(page.text).toContain("Kemi's been told.");
  });

  it('settles the split when the last share lands', async () => {
    await seedCollecting(db, { josh: { status: 'paid' } });
    await request(app(approvedThenCaptured())).get('/v1/paypal/return').query({ token: 'PPDAN' });
    expect(await statusOf(db, 'dan')).toBe('paid');
    expect(await splitStatus(db)).toBe('settled');
    expect((await db.doc(SPLIT).get()).get('settledAt')).toBeTruthy();
  });

  it('finds the share through PayPal when the order-id query cannot run', async () => {
    await seedCollecting(db);
    const broken = Object.create(db) as Firestore;
    broken.collectionGroup = () => { throw new Error('FAILED_PRECONDITION: needs an index'); };
    const res = await request(createApp({
      env, db: broken, paypal: approvedThenCaptured(),
      transport: async () => ({ content: '{}' }),
      verify: async () => { throw new Error('no'); },
    })).get('/v1/paypal/return').query({ token: 'PPDAN' });
    expect(res.status).toBe(303);
    expect(await statusOf(db, 'dan')).toBe('paid');
  });

  it('leaves a pending capture pending', async () => {
    await seedCollecting(db);
    const fetch: PayPalFetch = async (path) => (path.endsWith('/capture') ? order('PPDAN', 'COMPLETED', 'PENDING') : order('PPDAN', 'APPROVED'));
    await request(app(fetch)).get('/v1/paypal/return').query({ token: 'PPDAN' });
    expect(await statusOf(db, 'dan')).toBe('pending');
    const page = await request(app()).get(danPage);
    expect(page.text).toContain('PayPal is confirming it');
  });

  it('still sends the friend back when PayPal is down, and changes nothing', async () => {
    await seedCollecting(db);
    const res = await request(app(async () => { throw new ApiError(502, 'PAYPAL_UNAVAILABLE', 'down'); }))
      .get('/v1/paypal/return').query({ token: 'PPDAN' });
    expect(res.status).toBe(303);
    expect(res.headers.location).toBe(danPage);
    expect(await statusOf(db, 'dan')).toBe('link_opened');
  });

  it('never captures an order the share no longer holds', async () => {
    await seedCollecting(db, { dan: { status: 'owes', paypalOrderId: null, approvalUrl: null, supersededPaypalOrderIds: ['PPDAN'] } });
    let posted = false;
    const fetch: PayPalFetch = async (_path, init) => {
      if (init.method === 'POST') posted = true;
      return order('PPDAN', 'APPROVED');
    };
    const res = await request(app(fetch)).get('/v1/paypal/return').query({ token: 'PPDAN' });
    expect(posted).toBe(false);
    expect(res.headers.location).toBe(danPage);
    expect(await statusOf(db, 'dan')).toBe('owes');
  });

  it('thanks the friend without a page link when the token matches nothing', async () => {
    const res = await request(app(async () => ({ id: 'NOPE', status: 'APPROVED', purchase_units: [{}] })))
      .get('/v1/paypal/return').query({ token: 'NOPE' });
    expect(res.status).toBe(200);
    expect(res.text).toContain('Thanks, payment sent.');
  });

  it('says a cancelled payment charged nothing', async () => {
    const res = await request(app()).get('/v1/paypal/cancel');
    expect(res.status).toBe(200);
    expect(res.text).toContain('Nothing was charged.');
  });
});

describe('POST /v1/internal/workflows/reconcile', () => {
  const run = (fetch: PayPalFetch, token = 'reconcile-secret') =>
    request(app(fetch)).post('/v1/internal/workflows/reconcile').set('X-Internal-Token', token);

  it('refuses a call without the internal token', async () => {
    await seedCollecting(db);
    expect((await request(app()).post('/v1/internal/workflows/reconcile')).status).toBe(401);
    expect((await run(async () => ({}), 'nope')).status).toBe(401);
  });

  it('marks a completed capture paid when nothing else landed, and settles', async () => {
    await seedCollecting(db);
    const calls: string[] = [];
    const fetch: PayPalFetch = async (path) => {
      calls.push(path);
      return order(path.includes('PPJOSH') ? 'PPJOSH' : 'PPDAN', 'COMPLETED', 'COMPLETED');
    };
    const res = await run(fetch);
    expect(res.body).toEqual({ checked: 2, promoted: 2, failed: 0 });
    expect(calls.some((p) => p.endsWith('/capture'))).toBe(false);
    expect(await statusOf(db, 'dan')).toBe('paid');
    expect(await statusOf(db, 'josh')).toBe('paid');
    expect(await splitStatus(db)).toBe('settled');
  });

  it('captures an approved order and marks it paid', async () => {
    await seedCollecting(db, { josh: { status: 'owes', paypalOrderId: null } });
    const calls: string[] = [];
    const res = await run(approvedThenCaptured(calls));
    expect(res.body.promoted).toBe(1);
    expect(calls).toContain('POST /v2/checkout/orders/PPDAN/capture capture-dan-PPDAN');
    expect(await statusOf(db, 'dan')).toBe('paid');
  });

  it('leaves an order made in the last two minutes to the return page', async () => {
    await seedCollecting(db, {
      dan: { paypalOrderCreatedAt: Timestamp.fromMillis(Date.now() - 30_000) },
      josh: { status: 'owes', paypalOrderId: null },
    });
    const res = await run(async () => { throw new Error('should not ask PayPal'); });
    expect(res.body).toEqual({ checked: 0, promoted: 0, failed: 0 });
  });

  it('keeps going when one PayPal order cannot be read', async () => {
    await seedCollecting(db, { josh: { status: 'processing' } });
    const fetch: PayPalFetch = async (path) => {
      if (path.includes('PPJOSH')) throw new ApiError(502, 'PAYPAL_UNAVAILABLE', 'down', { status: 500, detail: 'INTERNAL_SERVER_ERROR' });
      return order('PPDAN', 'COMPLETED', 'COMPLETED');
    };
    const res = await run(fetch);
    expect(res.body).toEqual({ checked: 2, promoted: 1, failed: 1 });
    expect(await statusOf(db, 'dan')).toBe('paid');
    expect(await statusOf(db, 'josh')).toBe('processing');
  });

  it('skips splits that are not collecting', async () => {
    await seedCollecting(db);
    await db.doc(SPLIT).update({ status: 'claiming' });
    const res = await run(async () => { throw new Error('should not ask PayPal'); });
    expect(res.body).toEqual({ checked: 0, promoted: 0, failed: 0 });
  });
});
