import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import { bootstrapOrganiser } from '../src/domain/seed.js';
import { loadDemoSplit } from '../src/domain/demo.js';
import { DEFAULT_RULES } from '../src/domain/split.js';
import { newParticipant } from '../src/domain/splits.js';
import type { ChatTransport } from '../src/ai/client.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-rules-test', INTERNAL_TOKEN: 'internal', LINK_SECRET: 'link-secret',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-rules-test' });
  db = getFirestore();
});

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

const reply = (body: object): ChatTransport => async () => ({ content: JSON.stringify(body) });
const app = (transport: ChatTransport) =>
  createApp({
    env, db, paypal: async () => ({}), transport,
    verify: async (t: string) => {
      if (t === 'kemi') return { uid: t };
      throw new Error('bad token');
    },
  });

/** The Little Bao House bill, everyone in and everything claimed, nobody on us yet. */
async function claimed(): Promise<string> {
  const demo = loadDemoSplit();
  const { seededSplitId } = await bootstrapOrganiser(db, 'kemi', { demo: true });
  const split = db.doc(`organisers/kemi/splits/${seededSplitId}`);
  const seeded = await split.collection('participants').listDocuments();
  await Promise.all(seeded.map((d) => d.delete()));
  for (const p of demo.participants) {
    await split.collection('participants').doc(p.id).set(newParticipant(p.id, { name: p.name, joinOrder: p.joinOrder, isOrganiser: p.isOrganiser }));
  }
  await split.update({ organiserParticipantId: 'kemi', claims: demo.claims, rules: DEFAULT_RULES, status: 'claiming' });
  return seededSplitId!;
}

const post = (transport: ChatTransport, id: string, message: string) =>
  request(app(transport)).post(`/v1/splits/${id}/rules/message`).set('Authorization', 'Bearer kemi').send({ message });

const rule = { onUs: [] as string[], onUsPaidBy: null, serviceMode: null, serviceOptOut: [] as string[], confirmationText: 'ok?' };

describe('POST /v1/splits/:id/rules/message', () => {
  it("previews Sam's birthday at £29.10 and writes nothing", async () => {
    const id = await claimed();
    const res = await post(reply({ ...rule, onUs: ['sam'] }), id, "it's Sam's birthday so his is on us");
    expect(res.status).toBe(200);
    expect(res.body.preview).toEqual({
      rules: { ...DEFAULT_RULES, onUs: ['sam'] },
      confirmationText: "Sam's share, £29.10, split between the other 4?",
      figureMinor: 2910,
    });
    expect((await db.doc(`organisers/kemi/splits/${id}`).get()).get('rules')).toEqual(DEFAULT_RULES);
  });

  it('says so when it caught no rule', async () => {
    const id = await claimed();
    const res = await post(reply(rule), id, 'lovely evening');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ preview: null, message: "I didn't catch a rule in that. Try 'Sam's on us'." });
  });

  it('refuses an empty message and a locked split', async () => {
    const id = await claimed();
    expect((await post(reply(rule), id, '  ')).status).toBe(400);
    await db.doc(`organisers/kemi/splits/${id}`).update({ status: 'collecting' });
    expect((await post(reply(rule), id, 'sam is on us')).status).toBe(409);
  });
});
