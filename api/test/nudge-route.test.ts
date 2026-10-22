import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { Timestamp, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import { shareSignature } from '../src/domain/links.js';
import type { ChatTransport } from '../src/ai/client.js';
import { SPLIT, person, seedCollecting } from './shares-fixture.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-nudge-test', INTERNAL_TOKEN: 'internal', LINK_SECRET: 'link-secret',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-nudge-test' });
  db = getFirestore();
});

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

const danLink = `https://split-api-k5ai.onrender.com/v1/s/kemi/s1/dan/${shareSignature('link-secret', 'kemi', 's1', 'dan')}`;

const model = (text: string, extra: Record<string, unknown> = {}) =>
  vi.fn<ChatTransport>().mockResolvedValue({
    content: JSON.stringify({ text, recommendChannel: 'manual_copy', shouldSkip: false, skipReason: null, ...extra }),
  });

const app = (transport: ChatTransport = model('')) =>
  createApp({
    env, db, paypal: async () => ({}), transport,
    verify: async (t: string) => {
      if (t === 'kemi') return { uid: t };
      throw new Error('bad token');
    },
  });

const as = (r: request.Test) => r.set('Authorization', 'Bearer kemi');
const locked = (hoursAgo: number) => db.doc(SPLIT).update({ lockedAt: Timestamp.fromMillis(Date.now() - hoursAgo * 3600_000), merchant: 'Little Bao House' });

describe('POST /v1/splits/:id/participants/:pid/nudge', () => {
  it("drafts a reminder with the friend's own link and amount", async () => {
    await seedCollecting(db);
    await locked(50);
    const text = `Hey Dan! Your bit for Little Bao House is £39.23: ${danLink}`;
    const transport = model(text);
    const res = await as(request(app(transport)).post('/v1/splits/s1/participants/dan/nudge')).send({ tone: 'cheeky' });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ text, source: 'ai', shouldSkip: false, skipReason: null, tone: 'cheeky' });
    const prompt = JSON.stringify(transport.mock.calls[0]![0]);
    expect(prompt).toContain(danLink);
    expect(prompt).toContain('From: Kemi');
    expect(prompt).toContain('Unpaid for: 2 days');
  });

  it('falls back to a correct template when the model gets the link wrong', async () => {
    await seedCollecting(db);
    const res = await as(request(app(model('£39.23 https://example.com/x'))).post('/v1/splits/s1/participants/dan/nudge')).send({});
    expect(res.body.source).toBe('template');
    expect(res.body.text).toContain(danLink);
    expect(res.body.tone).toBe('friendly');
  });

  it('refuses a friend who has paid, is on us or is mid-payment', async () => {
    await seedCollecting(db, { josh: { status: 'processing' } });
    await person(db, 'dan').update({ status: 'paid' });
    const paid = await as(request(app()).post('/v1/splits/s1/participants/dan/nudge')).send({});
    expect(paid.status).toBe(409);
    expect(paid.body.error.message).toBe('Dan has already paid.');
    expect((await as(request(app()).post('/v1/splits/s1/participants/josh/nudge')).send({})).status).toBe(409);
    expect((await as(request(app()).post('/v1/splits/s1/participants/sam/nudge')).send({})).status).toBe(409);
    expect((await as(request(app()).post('/v1/splits/s1/participants/kemi/nudge')).send({})).status).toBe(404);
    expect((await as(request(app()).post('/v1/splits/s1/participants/dan/nudge')).send({ tone: 'rude' })).status).toBe(400);
  });

  it('records a copied nudge, and a snooze', async () => {
    await seedCollecting(db);
    const sent = await as(request(app()).post('/v1/splits/s1/participants/dan/nudge/sent')).send({ text: `Hey Dan ${danLink}` });
    expect(sent.body).toEqual({ count: 1 });
    const after = (await person(db, 'dan').get()).get('nudge');
    expect(after.count).toBe(1);
    expect(after.lastText).toBe(`Hey Dan ${danLink}`);
    expect(after.lastSentAt).toBeTruthy();

    const snoozed = await as(request(app()).post('/v1/splits/s1/participants/dan/nudge/snooze')).send({});
    expect(snoozed.status).toBe(200);
    const until = Date.parse(snoozed.body.snoozedUntil);
    expect(until - Date.now()).toBeGreaterThan(23 * 3600_000);
    expect((await person(db, 'dan').get()).get('nudge.snoozedUntil')).toBeTruthy();
  });
});

describe('POST /v1/internal/workflows/nudge-sweep', () => {
  const sweep = (transport?: ChatTransport) =>
    request(createApp({
      env, db, paypal: async () => ({}), transport: transport ?? model(''),
      verify: async () => { throw new Error('no'); },
    })).post('/v1/internal/workflows/nudge-sweep').set('X-Internal-Token', 'internal');

  it('drafts for friends a day past the links, once, and leaves the rest', async () => {
    await seedCollecting(db, { josh: { status: 'paid' } });
    await locked(25);
    const first = await sweep();
    expect(first.body).toEqual({ scanned: 1, nudged: 1, skipped: 0 });
    const draft = (await person(db, 'dan').get()).get('nudge.draftText') as string;
    expect(draft).toContain(danLink);
    expect(draft).toContain('£39.23');

    const again = await sweep();
    expect(again.body).toEqual({ scanned: 1, nudged: 0, skipped: 1 });
    expect((await person(db, 'dan').get()).get('nudge.draftText')).toBe(draft);
  });

  it('waits a day after the links went out', async () => {
    await seedCollecting(db);
    await locked(5);
    expect((await sweep()).body).toEqual({ scanned: 0, nudged: 0, skipped: 0 });
  });
});
