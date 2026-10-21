import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import { bootstrapOrganiser } from '../src/domain/seed.js';
import { shareSignature } from '../src/domain/links.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-people-test', INTERNAL_TOKEN: 'internal', LINK_SECRET: 'link-secret',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-people-test' });
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
      if (t === 'kemi' || t === 'stranger') return { uid: t };
      throw new Error('bad token');
    },
  });

const as = (t: request.Test, who = 'kemi') => t.set('Authorization', `Bearer ${who}`);

/** The seeded Little Bao House draft: Kemi organising, nobody else yet. */
async function demo(): Promise<string> {
  const { seededSplitId } = await bootstrapOrganiser(db, 'kemi', { demo: true });
  return seededSplitId!;
}

async function add(splitId: string, names: string[]) {
  return as(request(app()).post(`/v1/splits/${splitId}/participants`)).send({ names });
}

type Person = { id: string; name: string; colourIndex: number; joinOrder: number; isOrganiser: boolean };

describe('POST /v1/splits/:id/participants', () => {
  it('adds people after the organiser, trimmed, with their own colours', async () => {
    const id = await demo();
    const res = await add(id, ['  Amaka ', '', 'Josh   B', '   ']);
    expect(res.status).toBe(201);
    const people = res.body.participants as Person[];
    expect(people.map((p) => [p.name, p.joinOrder, p.colourIndex, p.isOrganiser])).toEqual([
      ['Kemi', 0, 0, true],
      ['Amaka', 1, 1, false],
      ['Josh B', 2, 2, false],
    ]);
    const stored = await db.collection(`organisers/kemi/splits/${id}/participants`).get();
    expect(stored.size).toBe(3);
  });

  it('joins after the highest join order and reuses a freed colour', async () => {
    const id = await demo();
    const first = (await add(id, ['Amaka', 'Josh'])).body.participants as Person[];
    const amaka = first.find((p) => p.name === 'Amaka')!;
    await as(request(app()).delete(`/v1/splits/${id}/participants/${amaka.id}`));
    const after = (await add(id, ['Dan'])).body.participants as Person[];
    expect(after.find((p) => p.name === 'Dan')).toMatchObject({ joinOrder: 3, colourIndex: 1 });
  });

  it('refuses an eighth friend, an empty list and a split that has locked', async () => {
    const id = await demo();
    expect((await add(id, ['A', 'B', 'C', 'D', 'E', 'F', 'G'])).status).toBe(201);
    const eighth = await add(id, ['H']);
    expect(eighth.status).toBe(400);
    expect(eighth.body.error.message).toBe('A bill can be split with up to 7 friends.');
    expect((await add(id, ['  '])).status).toBe(400);
    await db.doc(`organisers/kemi/splits/${id}`).update({ status: 'collecting' });
    expect((await add(id, ['Z'])).status).toBe(409);
  });

  it("404s on someone else's split", async () => {
    const id = await demo();
    expect((await as(request(app()).post(`/v1/splits/${id}/participants`), 'stranger').send({ names: ['A'] })).status).toBe(404);
  });
});

describe('DELETE /v1/splits/:id/participants/:pid', () => {
  it('removes them, their claims and every rule that names them', async () => {
    const id = await demo();
    const people = (await add(id, ['Amaka', 'Sam'])).body.participants as Person[];
    const sam = people.find((p) => p.name === 'Sam')!;
    const amaka = people.find((p) => p.name === 'Amaka')!;
    await db.doc(`organisers/kemi/splits/${id}`).update({
      claims: {
        'prawn-crackers-0': { claims: [{ participantId: sam.id, weight: 1, source: 'friend' }, { participantId: amaka.id, weight: 1, source: 'friend' }], shared: false },
      },
      rules: { serviceMode: 'proportional', onUs: [sam.id], onUsPaidBy: [sam.id], serviceOptOut: [sam.id] },
    });
    const res = await as(request(app()).delete(`/v1/splits/${id}/participants/${sam.id}`));
    expect(res.status).toBe(200);
    const stored = (await db.doc(`organisers/kemi/splits/${id}`).get()).data()!;
    expect(stored.claims['prawn-crackers-0'].claims).toEqual([{ participantId: amaka.id, weight: 1, source: 'friend' }]);
    expect(stored.rules).toEqual({ serviceMode: 'proportional', onUs: [], onUsPaidBy: null, serviceOptOut: [] });
    expect((await db.doc(`organisers/kemi/splits/${id}/participants/${sam.id}`).get()).exists).toBe(false);
  });

  it('keeps the organiser and 404s on a stranger', async () => {
    const id = await demo();
    const organiser = (await db.doc(`organisers/kemi/splits/${id}`).get()).get('organiserParticipantId');
    expect((await as(request(app()).delete(`/v1/splits/${id}/participants/${organiser}`))).status).toBe(400);
    expect((await as(request(app()).delete(`/v1/splits/${id}/participants/nobody`))).status).toBe(404);
  });
});

describe('POST /v1/splits/:id/open', () => {
  it('moves to claiming and returns signed links plus the group message', async () => {
    const id = await demo();
    const people = (await add(id, ['Amaka', 'Josh', 'Dan', 'Sam'])).body.participants as Person[];
    const res = await as(request(app()).post(`/v1/splits/${id}/open`));
    expect(res.status).toBe(200);
    const url = (name: string) => {
      const p = people.find((x) => x.name === name)!;
      return `https://split-api-k5ai.onrender.com/v1/s/kemi/${id}/${p.id}/${shareSignature('link-secret', 'kemi', id, p.id)}`;
    };
    expect(res.body.links).toEqual(['Amaka', 'Josh', 'Dan', 'Sam'].map((name) => ({
      participantId: people.find((p) => p.name === name)!.id, name, url: url(name),
    })));
    expect(res.body.groupMessage).toBe([
      'Friday dinner at Little Bao House. Tap your link and say what you had:',
      `Amaka: ${url('Amaka')}`,
      `Josh: ${url('Josh')}`,
      `Dan: ${url('Dan')}`,
      `Sam: ${url('Sam')}`,
    ].join('\n'));
    expect((await db.doc(`organisers/kemi/splits/${id}`).get()).get('status')).toBe('claiming');
  });

  it('gives the same links again once claiming', async () => {
    const id = await demo();
    await add(id, ['Amaka']);
    const first = await as(request(app()).post(`/v1/splits/${id}/open`));
    const second = await as(request(app()).post(`/v1/splits/${id}/open`));
    expect(second.status).toBe(200);
    expect(second.body).toEqual(first.body);
  });

  it('needs a friend and a bill with nothing left to answer', async () => {
    const id = await demo();
    const lonely = await as(request(app()).post(`/v1/splits/${id}/open`));
    expect(lonely.status).toBe(409);
    expect(lonely.body.error.message).toBe('Add at least one friend first.');
    await add(id, ['Amaka']);
    await db.doc(`organisers/kemi/splits/${id}`).update({
      receiptAmbiguities: [{ field: 'printedTotalMinor', kind: 'missing', question: "What's the total on the bill?", options: [], blocking: true }],
    });
    expect((await as(request(app()).post(`/v1/splits/${id}/open`))).status).toBe(409);
    expect((await db.doc(`organisers/kemi/splits/${id}`).get()).get('status')).toBe('draft');
  });
});
