import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import { bootstrapOrganiser } from '../src/domain/seed.js';
import { loadDemoSplit } from '../src/domain/demo.js';
import { lockPlan } from '../src/domain/lock.js';
import { newParticipant } from '../src/domain/splits.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-lock-test', INTERNAL_TOKEN: 'internal', LINK_SECRET: 'link-secret',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-lock-test' });
  db = getFirestore();
});

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

const app = () =>
  createApp({
    env, db, paypal: async () => ({}), transport: async () => ({ content: '{}' }),
    verify: async (t: string) => {
      if (t === 'kemi') return { uid: t };
      throw new Error('bad token');
    },
  });

const demo = loadDemoSplit();
const people = () => demo.participants.map((p) => newParticipant(p.id, { name: p.name, joinOrder: p.joinOrder, isOrganiser: p.isOrganiser }));

/** The Little Bao House bill, everyone in and claimed, Sam on us: ready to lock. */
async function ready(): Promise<{ id: string; split: FirebaseFirestore.DocumentReference }> {
  const { seededSplitId } = await bootstrapOrganiser(db, 'kemi', { demo: true });
  const split = db.doc(`organisers/kemi/splits/${seededSplitId}`);
  await Promise.all((await split.collection('participants').listDocuments()).map((d) => d.delete()));
  for (const p of people()) {
    await split.collection('participants').doc(p.id).set({ ...p, status: 'claimed', claimedAt: p.isOrganiser ? null : Timestamp.now() });
  }
  await split.update({ organiserParticipantId: 'kemi', claims: demo.claims, rules: demo.rules, status: 'claiming' });
  return { id: seededSplitId!, split };
}

const lock = (id: string) => request(app()).post(`/v1/splits/${id}/lock`).set('Authorization', 'Bearer kemi');
const unlock = (id: string) => request(app()).post(`/v1/splits/${id}/unlock`).set('Authorization', 'Bearer kemi');
const shares = async (split: FirebaseFirestore.DocumentReference) =>
  Object.fromEntries((await split.collection('participants').get()).docs.map((d) => [d.id, [d.get('shareMinor'), d.get('status')]]));

describe('lockPlan', () => {
  it('matches the golden fixture', () => {
    const plan = lockPlan(demo, people());
    if (!plan.ok) throw new Error('expected ok');
    expect(plan.people.map((p) => [p.id, p.shareMinor, p.status])).toEqual([
      ['kemi', 3643, 'on_us'], ['amaka', 3361, 'owes'], ['josh', 4542, 'owes'], ['dan', 3923, 'owes'], ['sam', 0, 'on_us'],
    ]);
    expect(plan.owedMinor).toBe(11826);
  });
});

describe('POST /v1/splits/:id/lock', () => {
  it('freezes every share and moves to collecting', async () => {
    const { id, split } = await ready();
    const res = await lock(id);
    expect(res.status).toBe(200);
    expect(res.body.owedMinor).toBe(11826);
    expect(await shares(split)).toEqual({
      kemi: [3643, 'on_us'], amaka: [3361, 'owes'], josh: [4542, 'owes'], dan: [3923, 'owes'], sam: [0, 'on_us'],
    });
    const doc = (await split.get()).data()!;
    expect(doc.status).toBe('collecting');
    expect(doc.lockedAt).not.toBeNull();
  });

  it('is safe to repeat', async () => {
    const { id } = await ready();
    const first = await lock(id);
    const again = await lock(id);
    expect(again.status).toBe(200);
    expect(again.body.owedMinor).toBe(11826);
    expect(again.body.split.lockedAt).toBe(first.body.split.lockedAt);
  });

  it('refuses with the problems while something is unclaimed', async () => {
    const { id, split } = await ready();
    const claims = { ...demo.claims, 'prawn-crackers-0': { claims: [], shared: false } };
    await split.update({ claims });
    const res = await lock(id);
    expect(res.status).toBe(409);
    expect(res.body.error.message).toBe('Nobody claimed the prawn crackers');
    expect(res.body.error.details.problems).toHaveLength(1);
    expect((await split.get()).get('status')).toBe('claiming');
  });
});

describe('POST /v1/splits/:id/unlock', () => {
  it('goes back to claiming and clears the shares', async () => {
    const { id, split } = await ready();
    await lock(id);
    const res = await unlock(id);
    expect(res.status).toBe(200);
    expect(await shares(split)).toEqual({
      kemi: [null, 'invited'], amaka: [null, 'claimed'], josh: [null, 'claimed'], dan: [null, 'claimed'], sam: [null, 'claimed'],
    });
    expect((await split.get()).data()).toMatchObject({ status: 'claiming', lockedAt: null });
  });

  it('stays locked once someone has a PayPal order', async () => {
    const { id, split } = await ready();
    await lock(id);
    await split.collection('participants').doc('dan').update({ paypalOrderId: 'ORDER-1' });
    const res = await unlock(id);
    expect(res.status).toBe(409);
    expect((await split.get()).get('status')).toBe('collecting');
  });
});
