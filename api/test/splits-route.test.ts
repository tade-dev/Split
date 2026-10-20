import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import type { ChatTransport } from '../src/ai/client.js';
import type { ReceiptExtraction } from '../src/ai/schemas.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-splits-test', INTERNAL_TOKEN: 'internal',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-splits-test' });
  db = getFirestore();
});

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

const PNG = Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex');

const reading: ReceiptExtraction = {
  merchant: 'Little Bao House',
  receiptDate: '2026-10-02',
  lines: [
    { name: 'Prawn crackers', qty: 1, lineTotalMinor: 550 },
    { name: 'Lager', qty: 3, lineTotalMinor: 1650 },
  ],
  serviceChargeMinor: 275,
  serviceChargeLabel: '12.5% discretionary',
  tipMinor: null,
  discounts: [],
  printedTotalMinor: 2475,
  ambiguities: [],
};

function app(transport: ChatTransport = async () => ({ content: JSON.stringify(reading) })) {
  return createApp({
    env, db, paypal: async () => ({}), transport,
    verify: async (t: string) => {
      if (t === 'kemi' || t === 'stranger') return { uid: t };
      throw new Error('bad token');
    },
  });
}

async function scan(extraction: ReceiptExtraction = reading) {
  const res = await request(app(async () => ({ content: JSON.stringify(extraction) })))
    .post('/v1/splits/scan')
    .set('Authorization', 'Bearer kemi')
    .attach('images', PNG, 'bill.png');
  expect(res.status).toBe(201);
  return res.body.split as { id: string; receipt: { lines: { id: string }[] }; organiserParticipantId: string };
}

describe('POST /v1/splits/scan', () => {
  it('reads the bill into a draft split with the organiser in it', async () => {
    await db.doc('organisers/kemi').set({ displayName: 'Kemi' });
    const split = await scan();
    expect(split).toMatchObject({ status: 'draft', merchant: 'Little Bao House', title: "Friday's bill", receiptAmbiguities: [] });
    const stored = await db.doc(`organisers/kemi/splits/${split.id}`).get();
    expect(stored.get('receipt.printedTotalMinor')).toBe(2475);
    expect(stored.get('extractionModel')).toBe('test-model');
    expect(stored.get('computed.ok')).toBe(false); // nothing is claimed yet
    const people = await stored.ref.collection('participants').get();
    expect(people.docs.map((d) => d.data())).toEqual([expect.objectContaining({ name: 'Kemi', isOrganiser: true, joinOrder: 0, colourIndex: 0 })]);
  });

  it('stores a mismatch as a blocking ambiguity rather than refusing the scan', async () => {
    const split = await scan({ ...reading, printedTotalMinor: 9999 }) as unknown as { receiptAmbiguities: { kind: string }[] };
    expect(split.receiptAmbiguities).toEqual([expect.objectContaining({ kind: 'price_conflict' })]);
  });

  it('refuses a request with no photo, three photos, or a non-image', async () => {
    const auth = (r: request.Test) => r.set('Authorization', 'Bearer kemi');
    expect((await auth(request(app()).post('/v1/splits/scan'))).status).toBe(400);
    const three = auth(request(app()).post('/v1/splits/scan'))
      .attach('images', PNG, 'a.png').attach('images', PNG, 'b.png').attach('images', PNG, 'c.png');
    expect((await three).body.error.code).toBe('VALIDATION_FAILED');
    const text = await auth(request(app()).post('/v1/splits/scan')).attach('images', Buffer.from('hello'), { filename: 'a.png', contentType: 'image/png' });
    expect(text.status).toBe(400);
  });

  it('needs a signed-in organiser', async () => {
    expect((await request(app()).post('/v1/splits/scan').attach('images', PNG, 'a.png')).status).toBe(401);
  });

  it('falls back to manual entry when the model fails twice', async () => {
    const res = await request(app(async () => ({ content: 'not json' })))
      .post('/v1/splits/scan').set('Authorization', 'Bearer kemi').attach('images', PNG, 'a.png');
    expect(res.status).toBe(502);
    expect(res.body.error.code).toBe('AI_PARSE_FAILED');
  });
});

describe('PATCH /v1/splits/:id/receipt', () => {
  it('fixing a misread line clears the mismatch and recomputes', async () => {
    const split = await scan({ ...reading, lines: [reading.lines[0]!, { name: 'Lager', qty: 3, lineTotalMinor: 1560 }] });
    const res = await request(app()).patch(`/v1/splits/${split.id}/receipt`).set('Authorization', 'Bearer kemi')
      .send({ lines: [{ id: 'lager-1', lineTotalMinor: 1650 }] });
    expect(res.status).toBe(200);
    expect(res.body.split.receiptAmbiguities).toEqual([]);
    const stored = await db.doc(`organisers/kemi/splits/${split.id}`).get();
    expect(stored.get('receipt.lines')[1].lineTotalMinor).toBe(1650);
    expect(stored.get('receiptAmbiguities')).toEqual([]);
  });

  it('raises the mismatch again when an edit breaks the sum', async () => {
    const split = await scan();
    const res = await request(app()).patch(`/v1/splits/${split.id}/receipt`).set('Authorization', 'Bearer kemi')
      .send({ serviceChargeMinor: 300 });
    expect(res.body.split.receiptAmbiguities[0]).toMatchObject({ kind: 'price_conflict' });
  });

  it('adds and removes lines without reusing an id', async () => {
    const split = await scan();
    const res = await request(app()).patch(`/v1/splits/${split.id}/receipt`).set('Authorization', 'Bearer kemi')
      .send({ removeLineIds: ['lager-1'], addLines: [{ name: 'Lager', qty: 3, lineTotalMinor: 1650 }] });
    expect(res.body.split.receipt.lines.map((l: { id: string }) => l.id)).toEqual(['prawn-crackers-0', 'lager-2']);
  });

  it('400s on a line that is not on the bill, and on an empty body', async () => {
    const split = await scan();
    const send = (body: object) => request(app()).patch(`/v1/splits/${split.id}/receipt`).set('Authorization', 'Bearer kemi').send(body);
    expect((await send({ lines: [{ id: 'nope', qty: 2 }] })).status).toBe(400);
    expect((await send({})).status).toBe(400);
    expect((await send({ printedTotalMinor: -1 })).status).toBe(400);
  });

  it('409s once the split has left draft', async () => {
    const split = await scan();
    await db.doc(`organisers/kemi/splits/${split.id}`).update({ status: 'claiming' });
    const res = await request(app()).patch(`/v1/splits/${split.id}/receipt`).set('Authorization', 'Bearer kemi').send({ tipMinor: 100 });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('SPLIT_STATE_INVALID');
  });

  it("404s for someone else's split", async () => {
    const split = await scan();
    const res = await request(app()).patch(`/v1/splits/${split.id}/receipt`).set('Authorization', 'Bearer stranger').send({ tipMinor: 100 });
    expect(res.status).toBe(404);
  });
});

describe('PATCH /v1/splits/:id/rules', () => {
  it('changes the service mode and recomputes', async () => {
    const split = await scan();
    const res = await request(app()).patch(`/v1/splits/${split.id}/rules`).set('Authorization', 'Bearer kemi').send({ serviceMode: 'even' });
    expect(res.status).toBe(200);
    expect(res.body.split.rules).toEqual({ serviceMode: 'even', onUs: [], onUsPaidBy: null, serviceOptOut: [] });
  });

  it('refuses a rule naming someone not in the group', async () => {
    const split = await scan();
    const res = await request(app()).patch(`/v1/splits/${split.id}/rules`).set('Authorization', 'Bearer kemi').send({ onUs: ['ghost'] });
    expect(res.status).toBe(400);
  });

  it('is frozen once the split is collecting', async () => {
    const split = await scan();
    await db.doc(`organisers/kemi/splits/${split.id}`).update({ status: 'collecting' });
    const res = await request(app()).patch(`/v1/splits/${split.id}/rules`).set('Authorization', 'Bearer kemi').send({ serviceMode: 'even' });
    expect(res.status).toBe(409);
  });
});
