import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import { bootstrapOrganiser } from '../src/domain/seed.js';
import { shareSignature } from '../src/domain/links.js';
import { friendPage, friendView } from '../src/pages/friend_page.js';
import { newParticipant, type SplitDoc } from '../src/domain/splits.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-friend-test', INTERNAL_TOKEN: 'internal', LINK_SECRET: 'link-secret',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-friend-test' });
  db = getFirestore();
});

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

const app = () =>
  createApp({
    env, db, paypal: async () => ({}), transport: async () => ({ content: '{}' }),
    verify: async () => { throw new Error('no organiser calls here'); },
  });

/** The demo bill, opened, with Dan in it. */
async function opened(): Promise<{ splitId: string; path: string }> {
  const { seededSplitId } = await bootstrapOrganiser(db, 'kemi', { demo: true });
  const splitId = seededSplitId!;
  const split = db.doc(`organisers/kemi/splits/${splitId}`);
  await split.collection('participants').doc('dan').set(newParticipant('dan', { name: 'Dan', joinOrder: 1, isOrganiser: false }));
  await split.update({ status: 'claiming' });
  return { splitId, path: `/v1/s/kemi/${splitId}/dan/${shareSignature('link-secret', 'kemi', splitId, 'dan')}` };
}

describe('GET /v1/s/...', () => {
  it('asks a friend in claiming what they had, with the bill under it', async () => {
    const { path } = await opened();
    const res = await request(app()).get(path);
    expect(res.status).toBe(200);
    expect(res.text).toContain('What did you have, Dan?');
    expect(res.text).toContain('Opened from Kemi&#39;s link. No app needed.');
    expect(res.text).toContain('Kemi paid £154.69 at Little Bao House.');
    expect(res.text).toContain('Spicy miso ramen');
    expect(res.text).toContain(`action="${path}/claim"`);
    expect(res.text).toContain(`href="${path}?pick=1"`);
  });

  it('marks the first view only', async () => {
    const { splitId, path } = await opened();
    const person = db.doc(`organisers/kemi/splits/${splitId}/participants/dan`);
    await request(app()).get(path);
    const first = (await person.get()).get('linkOpenedAt');
    expect(first).not.toBeNull();
    await request(app()).get(path);
    expect((await person.get()).get('linkOpenedAt')).toEqual(first);
  });

  it('answers a bad signature, an unknown split and a removed person the same way', async () => {
    const { splitId, path } = await opened();
    const badSig = await request(app()).get(path.replace(/[^/]+$/, 'x'.repeat(32)));
    const unknown = await request(app()).get(`/v1/s/kemi/nosuch/dan/${shareSignature('link-secret', 'kemi', 'nosuch', 'dan')}`);
    await db.doc(`organisers/kemi/splits/${splitId}/participants/dan`).delete();
    const removed = await request(app()).get(path);
    for (const r of [badSig, unknown, removed]) {
      expect(r.status).toBe(404);
      expect(r.text).toContain("This link doesn't work");
    }
    expect(unknown.text).toBe(badSig.text);
    expect(removed.text).toBe(badSig.text);
  });

  it('says so when the bill was cancelled', async () => {
    const { splitId, path } = await opened();
    await db.doc(`organisers/kemi/splits/${splitId}`).update({ status: 'cancelled' });
    const res = await request(app()).get(path);
    expect(res.status).toBe(200);
    expect(res.text).toContain('This bill was cancelled');
  });

  it('is never cached and never leaks the link as a referrer', async () => {
    const { path } = await opened();
    const res = await request(app()).get(path);
    expect(res.headers['cache-control']).toBe('no-store');
    expect(res.headers['referrer-policy']).toBe('no-referrer');
    expect(res.headers['content-type']).toMatch(/text\/html/);
  });

  it('moves owes to link_opened when the pay page is seen', async () => {
    const { splitId, path } = await opened();
    const person = db.doc(`organisers/kemi/splits/${splitId}/participants/dan`);
    await person.update({ status: 'owes', shareMinor: 3923 });
    await db.doc(`organisers/kemi/splits/${splitId}`).update({ status: 'collecting' });
    const res = await request(app()).get(path);
    expect(res.text).toContain('Pay £39.23 with PayPal');
    expect((await person.get()).get('status')).toBe('link_opened');
  });
});

describe('friendView', () => {
  const split = (over: Partial<SplitDoc> = {}): SplitDoc => ({
    id: 's1', title: 'Friday dinner', merchant: 'Little Bao House', receiptDate: null, status: 'claiming',
    receipt: {
      lines: [{ id: 'lager-8', name: 'Lager', qty: 3, lineTotalMinor: 1650 }, { id: 'ramen-5', name: 'Spicy miso ramen', qty: 1, lineTotalMinor: 1500 }],
      serviceChargeMinor: 0, serviceChargeLabel: null, tipMinor: 0, discounts: [], printedTotalMinor: 3150, currency: 'GBP',
    },
    receiptAmbiguities: [],
    claims: {
      'lager-8': { claims: [{ participantId: 'dan', weight: 1, source: 'friend' }, { participantId: 'josh', weight: 2, source: 'friend' }], shared: false },
      'ramen-5': { claims: [{ participantId: 'dan', weight: 1, source: 'friend' }], shared: false },
    },
    rules: { serviceMode: 'proportional', onUs: [], onUsPaidBy: null, serviceOptOut: [] },
    organiserParticipantId: 'kemi', computed: null, lockedAt: null, extractionModel: 'seed', sourceRef: null,
    ...over,
  });
  const dan = (over: object = {}) => ({ ...newParticipant('dan', { name: 'Dan', joinOrder: 1, isOrganiser: false }), ...over });

  it('lists what a friend claimed once they have', () => {
    const view = friendView(split(), dan({ status: 'claimed' }), 'Kemi', '/v1/s/x');
    expect(view).toEqual({ kind: 'claimed', name: 'Dan', organiser: 'Kemi', mine: [
      { label: 'Lager, 1 of 3', minor: null },
      { label: 'Spicy miso ramen', minor: null },
    ], changeHref: '/v1/s/x?pick=1' });
    expect(friendPage(view)).toContain('Waiting for everyone else');
  });

  it('thanks someone who paid and tells an on-us friend there is nothing to pay', () => {
    expect(friendPage(friendView(split({ status: 'collecting' }), dan({ status: 'paid' }), 'Kemi', '/x'))).toContain("Kemi's been told.");
    expect(friendPage(friendView(split({ status: 'collecting' }), dan({ status: 'on_us' }), 'Kemi', '/x'))).toContain("This one's on the group");
  });

  it('escapes names it did not write', () => {
    const html = friendPage(friendView(split(), dan({ name: '<script>x</script>' }), 'Kemi', '/x'));
    expect(html).not.toContain('<script>x');
    expect(html).toContain('&lt;script&gt;');
  });
});
