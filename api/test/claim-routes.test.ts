import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import { bootstrapOrganiser } from '../src/domain/seed.js';
import { shareSignature } from '../src/domain/links.js';
import { newParticipant } from '../src/domain/splits.js';
import type { ChatTransport } from '../src/ai/client.js';
import type { ClaimParse } from '../src/ai/schemas.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-claims-test', INTERNAL_TOKEN: 'internal', LINK_SECRET: 'link-secret',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-claims-test' });
  db = getFirestore();
});

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

/** A model that always answers `reply`, and counts how often it was asked. */
function model(reply: ClaimParse | 'garbage') {
  const calls = { n: 0 };
  const transport: ChatTransport = async () => {
    calls.n++;
    return { content: reply === 'garbage' ? 'not json' : JSON.stringify(reply) };
  };
  return { calls, transport };
}
const parse = (claims: ClaimParse['claims'], extra: Partial<ClaimParse> = {}): ClaimParse => ({ claims, ambiguities: [], ignored: [], ...extra });

const app = (transport: ChatTransport = async () => ({ content: '{}' })) =>
  createApp({
    env, db, paypal: async () => ({}), transport,
    verify: async (t: string) => {
      if (t === 'kemi') return { uid: t };
      throw new Error('bad token');
    },
  });

/** The demo bill, claiming, with Josh, Amaka and Dan in it. */
async function opened(status: 'draft' | 'claiming' = 'claiming') {
  const { seededSplitId } = await bootstrapOrganiser(db, 'kemi', { demo: true });
  const splitId = seededSplitId!;
  const split = db.doc(`organisers/kemi/splits/${splitId}`);
  for (const [i, name] of ['Josh', 'Amaka', 'Dan'].entries()) {
    const id = name.toLowerCase();
    await split.collection('participants').doc(id).set(newParticipant(id, { name, joinOrder: i + 1, isOrganiser: false }));
  }
  await split.update({ status });
  const path = (p: string) => `/v1/s/kemi/${splitId}/${p}/${shareSignature('link-secret', 'kemi', splitId, p)}`;
  const person = (p: string) => split.collection('participants').doc(p);
  return { splitId, split, path, person };
}

describe('POST /v1/s/.../claim', () => {
  it('previews what Split matched and writes nothing but the count', async () => {
    const { path, split, person } = await opened();
    const { transport } = model(parse([
      { lineId: 'spicy-miso-ramen-5', participantId: 'josh', weight: 1 },
      { lineId: 'lager-8', participantId: 'josh', weight: 1 },
      { lineId: 'pork-bao-1', participantId: 'dan', weight: 1 },
    ]));
    const res = await request(app(transport)).post(`${path('josh')}/claim`).send({ message: 'spicy ramen, a lager, and Dan had a bao' });
    expect(res.status).toBe(200);
    expect(res.body.matched).toEqual([
      { lineId: 'spicy-miso-ramen-5', name: 'Spicy miso ramen', weight: 1, portionLabel: '' },
      { lineId: 'lager-8', name: 'Lager', weight: 1, portionLabel: '1 of 3' },
    ]);
    expect(res.body.ignored).toEqual(["You can only claim for yourself, so Dan's pork bao was left out."]);
    expect((await split.get()).get('claims')).toEqual({});
    expect((await person('josh').get()).get('aiParsesUsed')).toBe(1);
  });

  it('shows the preview page to a form post, with a confirm carrying the weights', async () => {
    const { path } = await opened();
    const { transport } = model(parse([{ lineId: 'lager-8', participantId: 'josh', weight: 2 }]));
    const res = await request(app(transport)).post(`${path('josh')}/claim`).type('form').send({ message: 'two lagers' });
    expect(res.status).toBe(200);
    expect(res.text).toContain('Split matched this to the bill');
    expect(res.text).toContain('Lager, 2 of 3');
    expect(res.text).toContain('name="w_lager-8" value="2"');
    expect(res.text).toContain(`action="${path('josh')}/claim/confirm"`);
  });

  it('hands over the checklist after 8 tries, without asking the model', async () => {
    const { path, person } = await opened();
    await person('josh').update({ aiParsesUsed: 8 });
    const { calls, transport } = model(parse([]));
    const json = await request(app(transport)).post(`${path('josh')}/claim`).send({ message: 'a lager' });
    expect(json.status).toBe(429);
    expect(json.body.fallback).toBe('checklist');
    const form = await request(app(transport)).post(`${path('josh')}/claim`).type('form').send({ message: 'a lager' });
    expect(form.status).toBe(429);
    expect(form.text).toContain('Pick what you had from the bill this time.');
    expect(form.text).toContain('name="w_lager-8"');
    expect(calls.n).toBe(0);
    expect((await person('josh').get()).get('aiParsesUsed')).toBe(8);
  });

  it('falls back to the checklist when the model cannot be read', async () => {
    const { path } = await opened();
    const { transport } = model('garbage');
    const res = await request(app(transport)).post(`${path('josh')}/claim`).send({ message: 'a lager' });
    expect(res.status).toBe(502);
    expect(res.body.fallback).toBe('checklist');
  });

  it('refuses a bad link, an empty message and a split that is not claiming', async () => {
    const { path, split } = await opened();
    const bad = await request(app()).post(`${path('josh').replace(/[^/]+$/, 'x'.repeat(32))}/claim`).send({ message: 'a lager' });
    expect(bad.status).toBe(404);
    expect((await request(app()).post(`${path('josh')}/claim`).send({ message: '   ' })).status).toBe(400);
    await split.update({ status: 'collecting' });
    expect((await request(app()).post(`${path('josh')}/claim`).send({ message: 'a lager' })).status).toBe(409);
  });
});

describe('POST /v1/s/.../claim/confirm', () => {
  it('writes the claim, recomputes and marks them claimed', async () => {
    const { path, split, person } = await opened();
    const res = await request(app()).post(`${path('josh')}/claim/confirm`).send({
      lines: [{ lineId: 'lager-8', weight: 1 }, { lineId: 'spicy-miso-ramen-5', weight: 1 }],
      message: 'spicy ramen and a lager',
    });
    expect(res.status).toBe(200);
    const stored = (await split.get()).data()!;
    expect(stored.claims['lager-8']).toEqual({ claims: [{ participantId: 'josh', weight: 1, source: 'friend' }], shared: false });
    expect(stored.computed.ok).toBe(false); // the rest of the bill is still unclaimed
    const josh = (await person('josh').get()).data()!;
    expect(josh).toMatchObject({ status: 'claimed', claimText: 'spicy ramen and a lager' });
    expect(josh.claimedAt).not.toBeNull();
  });

  it('replaces what they claimed before rather than adding to it', async () => {
    const { path, split } = await opened();
    await request(app()).post(`${path('josh')}/claim/confirm`).send({ lines: [{ lineId: 'lager-8', weight: 2 }] });
    await request(app()).post(`${path('josh')}/claim/confirm`).send({ lines: [{ lineId: 'lemonade-9', weight: 1 }] });
    const claims = (await split.get()).get('claims');
    expect(claims['lager-8'].claims).toEqual([]);
    expect(claims['lemonade-9'].claims).toEqual([{ participantId: 'josh', weight: 1, source: 'friend' }]);
  });

  it('takes the checklist form and goes back to the page', async () => {
    const { path, split } = await opened();
    const res = await request(app()).post(`${path('dan')}/claim/confirm`).type('form').send({ 'w_pork-bao-1': '2', 'w_lager-8': '0', 'w_lemonade-9': '' });
    expect(res.status).toBe(303);
    expect(res.headers.location).toBe(path('dan'));
    expect((await split.get()).get('claims')['pork-bao-1'].claims).toEqual([{ participantId: 'dan', weight: 2, source: 'friend' }]);
    const page = await request(app()).get(path('dan'));
    expect(page.text).toContain('Pork bao, 2 of 3');
    const pick = await request(app()).get(`${path('dan')}?pick=1`);
    expect(pick.text).toContain('name="w_pork-bao-1" type="number" inputmode="numeric" min="0" max="3" value="2"');
  });

  it('refuses more than is left and writes nothing', async () => {
    const { path, split, person } = await opened();
    await request(app()).post(`${path('dan')}/claim/confirm`).send({ lines: [{ lineId: 'lager-8', weight: 2 }] });
    const res = await request(app()).post(`${path('josh')}/claim/confirm`).send({ lines: [{ lineId: 'lager-8', weight: 2 }] });
    expect(res.status).toBe(409);
    expect(res.body.problems).toEqual([expect.objectContaining({ question: 'Only 1 lager is left to claim' })]);
    expect((await split.get()).get('claims')['lager-8'].claims).toHaveLength(1);
    expect((await person('josh').get()).get('status')).toBe('invited');
    const form = await request(app()).post(`${path('josh')}/claim/confirm`).type('form').send({ 'w_lager-8': '2' });
    expect(form.status).toBe(409);
    expect(form.text).toContain('Only 1 lager is left to claim');
  });

  it('gives the last lager to exactly one of two friends racing for it', async () => {
    const { path, split } = await opened();
    await request(app()).post(`${path('dan')}/claim/confirm`).send({ lines: [{ lineId: 'lager-8', weight: 2 }] });
    const [josh, amaka] = await Promise.all([
      request(app()).post(`${path('josh')}/claim/confirm`).send({ lines: [{ lineId: 'lager-8', weight: 1 }] }),
      request(app()).post(`${path('amaka')}/claim/confirm`).send({ lines: [{ lineId: 'lager-8', weight: 1 }] }),
    ]);
    expect([josh.status, amaka.status].sort()).toEqual([200, 409]);
    const lager = (await split.get()).get('claims')['lager-8'].claims as { weight: number }[];
    expect(lager.reduce((t, c) => t + c.weight, 0)).toBe(3);
  });

  it('lets several friends join a single dish', async () => {
    const { path, split } = await opened();
    await request(app()).post(`${path('josh')}/claim/confirm`).send({ lines: [{ lineId: 'prawn-crackers-0', weight: 1 }] });
    const res = await request(app()).post(`${path('amaka')}/claim/confirm`).send({ lines: [{ lineId: 'prawn-crackers-0', weight: 1 }] });
    expect(res.status).toBe(200);
    expect((await split.get()).get('claims')['prawn-crackers-0'].claims).toHaveLength(2);
  });

  it('refuses nothing picked and a weight that is not whole', async () => {
    const { path } = await opened();
    expect((await request(app()).post(`${path('josh')}/claim/confirm`).send({ lines: [] })).status).toBe(409);
    expect((await request(app()).post(`${path('josh')}/claim/confirm`).send({ lines: [{ lineId: 'lager-8', weight: 1.5 }] })).status).toBe(409);
  });
});

const organiserId = async (splitId: string) => (await db.doc(`organisers/kemi/splits/${splitId}`).get()).get('organiserParticipantId') as string;
const as = (t: request.Test) => t.set('Authorization', 'Bearer kemi');

describe('POST /v1/splits/:id/claims/message', () => {
  it('writes what the organiser said for anyone, and marks them claimed', async () => {
    const { splitId, split, person } = await opened('draft');
    const { transport } = model(parse([
      { lineId: 'prawn-crackers-0', participantId: 'josh', weight: 1 },
      { lineId: 'prawn-crackers-0', participantId: 'amaka', weight: 1 },
      { lineId: 'lager-8', participantId: 'dan', weight: 3 },
    ]));
    const res = await as(request(app(transport)).post(`/v1/splits/${splitId}/claims/message`)).send({ participantId: null, message: 'josh and amaka shared the crackers, dan had all the lager' });
    expect(res.status).toBe(200);
    expect(res.body.applied.map((a: { participantId: string }) => a.participantId)).toEqual(['josh', 'amaka', 'dan']);
    expect(res.body.problems).toEqual([]);
    const claims = (await split.get()).get('claims');
    expect(claims['prawn-crackers-0'].claims).toEqual([
      { participantId: 'josh', weight: 1, source: 'organiser' },
      { participantId: 'amaka', weight: 1, source: 'organiser' },
    ]);
    expect((await person('dan').get()).get('status')).toBe('claimed');
  });

  it('applies what fits and reports the rest', async () => {
    const { splitId, split } = await opened();
    await split.update({ claims: { 'lager-8': { claims: [{ participantId: 'dan', weight: 2, source: 'friend' }], shared: false } } });
    const { transport } = model(parse([
      { lineId: 'lager-8', participantId: 'josh', weight: 1 },
      { lineId: 'lager-8', participantId: 'amaka', weight: 1 },
    ]));
    const res = await as(request(app(transport)).post(`/v1/splits/${splitId}/claims/message`)).send({ participantId: null, message: 'josh and amaka had a lager each' });
    expect(res.body.applied.map((a: { participantId: string }) => a.participantId)).toEqual(['josh']);
    expect(res.body.problems).toEqual([expect.objectContaining({ question: 'All of the lager has been claimed' })]);
  });

  it('refuses once the split has locked', async () => {
    const { splitId, split } = await opened();
    await split.update({ status: 'collecting' });
    const res = await as(request(app()).post(`/v1/splits/${splitId}/claims/message`)).send({ participantId: null, message: 'a lager' });
    expect(res.status).toBe(409);
  });
});

describe('PATCH /v1/splits/:id/claims', () => {
  it('replaces one line and can mark it shared', async () => {
    const { splitId, split, person } = await opened();
    await split.update({ claims: { 'lager-8': { claims: [{ participantId: 'dan', weight: 2, source: 'friend' }], shared: false } } });
    const res = await as(request(app()).patch(`/v1/splits/${splitId}/claims`)).send({
      lineId: 'lager-8',
      claims: [{ participantId: 'josh', weight: 1 }, { participantId: 'dan', weight: 1 }],
      shared: true,
    });
    expect(res.status).toBe(200);
    expect((await split.get()).get('claims')['lager-8']).toEqual({
      claims: [{ participantId: 'josh', weight: 1, source: 'organiser' }, { participantId: 'dan', weight: 1, source: 'organiser' }],
      shared: true,
    });
    expect((await person('josh').get()).get('status')).toBe('claimed');
  });

  it('refuses more than the line has, an unknown person and an unknown line', async () => {
    const { splitId } = await opened();
    const patch = (body: object) => as(request(app()).patch(`/v1/splits/${splitId}/claims`)).send(body);
    expect((await patch({ lineId: 'lager-8', claims: [{ participantId: 'josh', weight: 4 }] })).status).toBe(400);
    const everyone = ['josh', 'amaka', 'dan'].map((participantId) => ({ participantId, weight: 1 }));
    expect((await patch({ lineId: 'lager-8', claims: [...everyone, { participantId: (await organiserId(splitId)), weight: 1 }], shared: true })).status).toBe(200);
    expect((await patch({ lineId: 'lager-8', claims: [{ participantId: 'nobody', weight: 1 }] })).status).toBe(404);
    expect((await patch({ lineId: 'ghost-1', claims: [] })).status).toBe(404);
  });
});
