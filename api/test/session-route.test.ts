import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-session-test', INTERNAL_TOKEN: 'internal',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-session-test' });
  db = getFirestore();
});
beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

const app = () => createApp({
  env, db, paypal: async () => ({}), transport: async () => ({ content: '{}' }),
  verify: async (t: string) => ({ uid: t }),
});
const bootstrap = (body: object = { demo: true }, uid = 'judge-1') =>
  request(app()).post('/v1/session/bootstrap').set('Authorization', `Bearer ${uid}`).send(body);

describe('POST /v1/session/bootstrap', () => {
  it('creates Kemi and seeds the Little Bao House bill in draft', async () => {
    const res = await bootstrap();
    expect(res.status).toBe(200);
    expect(res.body.organiser).toMatchObject({ displayName: 'Kemi', paypalEmail: null, demoSeeded: true });
    const split = await db.doc(`organisers/judge-1/splits/${res.body.seededSplitId}`).get();
    expect(split.data()).toMatchObject({ title: 'Friday dinner', merchant: 'Little Bao House', status: 'draft', receiptAmbiguities: [] });
    expect(split.get('receipt.printedTotalMinor')).toBe(15469);
    expect(split.get('receipt.lines')).toHaveLength(10);
  });

  it('is idempotent, even when two calls race', async () => {
    const [a, b] = await Promise.all([bootstrap(), bootstrap()]);
    expect([a.status, b.status]).toEqual([200, 200]);
    await bootstrap();
    const splits = await db.collection('organisers/judge-1/splits').get();
    expect(splits.size).toBe(1);
  });

  it('demo: false creates the organiser with no split', async () => {
    const res = await bootstrap({ demo: false });
    expect(res.body).toMatchObject({ organiser: { displayName: 'You', demoSeeded: false }, seededSplitId: null });
    expect((await db.collection('organisers/judge-1/splits').get()).size).toBe(0);
  });

  it('rejects an unknown field and a missing token', async () => {
    expect((await bootstrap({ demo: true, extra: 1 })).status).toBe(400);
    expect((await request(app()).post('/v1/session/bootstrap').send({})).status).toBe(401);
  });
});
