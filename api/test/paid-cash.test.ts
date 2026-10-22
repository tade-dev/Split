import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import { person, seedCollecting, splitStatus, statusOf } from './shares-fixture.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-cash-test', INTERNAL_TOKEN: 'internal', LINK_SECRET: 'link-secret',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-cash-test' });
  db = getFirestore();
});

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

const app = () =>
  createApp({
    env, db, paypal: async () => { throw new Error('marking cash never calls PayPal'); },
    transport: async () => ({ content: '{}' }),
    verify: async (t: string) => {
      if (t === 'kemi' || t === 'someone-else') return { uid: t };
      throw new Error('bad token');
    },
  });

const markCash = (pid: string, token = 'kemi') =>
  request(app()).post(`/v1/splits/s1/participants/${pid}/paid-cash`).set('Authorization', `Bearer ${token}`);

describe('POST /v1/splits/:id/participants/:pid/paid-cash', () => {
  it('marks the share paid in cash and replaces the PayPal order it held', async () => {
    await seedCollecting(db);
    const res = await markCash('dan');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'paid_cash', settled: false });
    const dan = await person(db, 'dan').get();
    expect(dan.get('status')).toBe('paid_cash');
    expect(dan.get('paidAt')).toBeTruthy();
    expect(dan.get('paypalOrderId')).toBeNull();
    expect(dan.get('supersededPaypalOrderIds')).toEqual(['PPDAN']);
    expect((await person(db, 'dan').collection('paymentEvents').doc('paid-cash-dan').get()).get('amountMinor')).toBe(3923);
  });

  it('settles the split when it was the last share', async () => {
    await seedCollecting(db, { josh: { status: 'paid' } });
    const res = await markCash('dan');
    expect(res.body).toEqual({ status: 'paid_cash', settled: true });
    expect(await splitStatus(db)).toBe('settled');
  });

  it('refuses while PayPal is confirming, and for a share already done', async () => {
    await seedCollecting(db, { dan: { status: 'processing' }, josh: { status: 'paid' } });
    const moving = await markCash('dan');
    expect(moving.status).toBe(409);
    expect(moving.body.error.message).toBe("PayPal is still confirming Dan's payment.");
    expect((await markCash('josh')).status).toBe(409);
    expect((await markCash('sam')).status).toBe(409);
    expect(await statusOf(db, 'dan')).toBe('processing');
  });

  it('is only for a split that is collecting, and only for its own organiser', async () => {
    await seedCollecting(db);
    expect((await markCash('dan', 'someone-else')).status).toBe(404);
    expect((await markCash('nobody')).status).toBe(404);
    await db.doc('organisers/kemi/splits/s1').update({ status: 'claiming' });
    expect((await markCash('dan')).status).toBe(409);
    expect(await statusOf(db, 'dan')).toBe('link_opened');
  });
});
