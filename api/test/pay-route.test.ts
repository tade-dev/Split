import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import { bootstrapOrganiser } from '../src/domain/seed.js';
import { loadDemoSplit } from '../src/domain/demo.js';
import { shareSignature } from '../src/domain/links.js';
import { newParticipant } from '../src/domain/splits.js';
import type { PayPalFetch } from '../src/paypal/client.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-pay-test', INTERNAL_TOKEN: 'internal', LINK_SECRET: 'link-secret',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-pay-test' });
  db = getFirestore();
});

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

const created = {
  id: 'PP-ORDER-1',
  status: 'PAYER_ACTION_REQUIRED',
  links: [{ rel: 'payer-action', method: 'GET', href: 'https://www.sandbox.paypal.com/checkoutnow?token=PP-ORDER-1' }],
};

const app = (paypal: PayPalFetch = async () => created) =>
  createApp({
    env, db, paypal, transport: async () => ({ content: '{}' }),
    verify: async (t: string) => {
      if (t === 'kemi') return { uid: t };
      throw new Error('bad token');
    },
  });

const demo = loadDemoSplit();

/** The Little Bao House bill, locked: Dan owes £39.23. */
async function locked() {
  const { seededSplitId } = await bootstrapOrganiser(db, 'kemi', { demo: true });
  const id = seededSplitId!;
  const split = db.doc(`organisers/kemi/splits/${id}`);
  await Promise.all((await split.collection('participants').listDocuments()).map((d) => d.delete()));
  for (const p of demo.participants) {
    const doc = newParticipant(p.id, { name: p.name, joinOrder: p.joinOrder, isOrganiser: p.isOrganiser });
    await split.collection('participants').doc(p.id).set({ ...doc, status: 'claimed', claimedAt: Timestamp.now() });
  }
  await split.update({ organiserParticipantId: 'kemi', claims: demo.claims, rules: demo.rules, status: 'claiming' });
  expect((await request(app()).post(`/v1/splits/${id}/lock`).set('Authorization', 'Bearer kemi')).status).toBe(200);
  const path = (p: string) => `/v1/s/kemi/${id}/${p}/${shareSignature('link-secret', 'kemi', id, p)}`;
  return { id, split, path, person: (p: string) => split.collection('participants').doc(p) };
}

describe('POST /v1/s/.../pay', () => {
  it('creates one order for the frozen share and sends the friend to PayPal', async () => {
    const { id, path, person } = await locked();
    const paypal = vi.fn<PayPalFetch>().mockResolvedValue(created);
    const res = await request(app(paypal)).post(`${path('dan')}/pay`).type('form').send({});
    expect(res.status).toBe(303);
    expect(res.headers.location).toBe(created.links[0]!.href);
    expect(paypal).toHaveBeenCalledTimes(1);
    const [, init] = paypal.mock.calls[0]!;
    expect(init.requestId).toBe(`pay-${id}-dan-0`);
    const unit = (init.body as { purchase_units: Record<string, unknown>[] }).purchase_units[0]!;
    const title = (await db.doc(`organisers/kemi/splits/${id}`).get()).get('title') as string;
    expect(unit).toMatchObject({
      custom_id: `kemi:${id}:dan`,
      amount: { currency_code: 'GBP', value: '39.23' },
      description: `Your share of ${title} (Little Bao House)`,
    });
    expect(unit).not.toHaveProperty('payee');
    expect((await person('dan').get()).data()).toMatchObject({ paypalOrderId: 'PP-ORDER-1', approvalUrl: created.links[0]!.href });
  });

  it('reuses the order on a second tap without calling PayPal again', async () => {
    const { path } = await locked();
    const paypal = vi.fn<PayPalFetch>().mockResolvedValue(created);
    await request(app(paypal)).post(`${path('dan')}/pay`).type('form').send({});
    const again = await request(app(paypal)).post(`${path('dan')}/pay`).send({});
    expect(again.status).toBe(200);
    expect(again.body).toEqual({ approvalUrl: created.links[0]!.href });
    expect(paypal).toHaveBeenCalledTimes(1);
  });

  it("pays the organiser's PayPal email once it is set", async () => {
    const { path } = await locked();
    await db.doc('organisers/kemi').update({ paypalEmail: 'kemi@example.com' });
    const paypal = vi.fn<PayPalFetch>().mockResolvedValue(created);
    await request(app(paypal)).post(`${path('josh')}/pay`).send({});
    const unit = (paypal.mock.calls[0]![1].body as { purchase_units: Record<string, unknown>[] }).purchase_units[0]!;
    expect(unit.payee).toEqual({ email_address: 'kemi@example.com' });
    expect((unit.amount as { value: string }).value).toBe('45.42');
  });

  it('charges the stored share even if the claims change underneath it', async () => {
    const { split, path } = await locked();
    await split.update({ claims: {} });
    const paypal = vi.fn<PayPalFetch>().mockResolvedValue(created);
    await request(app(paypal)).post(`${path('dan')}/pay`).send({});
    const unit = (paypal.mock.calls[0]![1].body as { purchase_units: { amount: { value: string } }[] }).purchase_units[0]!;
    expect(unit.amount.value).toBe('39.23');
  });

  it('refuses an on-us friend, a paid friend and a split that is not collecting', async () => {
    const { split, path, person } = await locked();
    const paypal = vi.fn<PayPalFetch>().mockResolvedValue(created);
    expect((await request(app(paypal)).post(`${path('sam')}/pay`).send({})).status).toBe(409);
    await person('amaka').update({ status: 'paid' });
    expect((await request(app(paypal)).post(`${path('amaka')}/pay`).send({})).status).toBe(409);
    const form = await request(app(paypal)).post(`${path('amaka')}/pay`).type('form').send({});
    expect(form.status).toBe(303);
    expect(form.headers.location).toBe(path('amaka'));
    await split.update({ status: 'claiming' });
    expect((await request(app(paypal)).post(`${path('dan')}/pay`).send({})).status).toBe(409);
    expect(paypal).not.toHaveBeenCalled();
  });

  it('shows FriendPay with the frozen share and a Pay button', async () => {
    const { path, person } = await locked();
    const page = await request(app()).get(path('dan'));
    expect(page.text).toContain('Your share, Dan');
    expect(page.text).toContain('Pay £39.23 with PayPal');
    expect(page.text).toContain(`action="${path('dan')}/pay"`);
    expect((await person('dan').get()).get('status')).toBe('link_opened');
  });
});

describe('PATCH /v1/session/organiser', () => {
  const patch = (body: object) => request(app()).patch('/v1/session/organiser').set('Authorization', 'Bearer kemi').send(body);

  it('sets and clears the PayPal email, and renames', async () => {
    await bootstrapOrganiser(db, 'kemi', { demo: false });
    const set = await patch({ paypalEmail: '  Kemi@Example.com ', displayName: 'Kemi A' });
    expect(set.status).toBe(200);
    expect(set.body.organiser).toMatchObject({ paypalEmail: 'kemi@example.com', displayName: 'Kemi A' });
    expect((await patch({ paypalEmail: null })).body.organiser.paypalEmail).toBeNull();
    expect((await db.doc('organisers/kemi').get()).get('paypalEmail')).toBeNull();
  });

  it('refuses a bad email, an empty body and an unknown field', async () => {
    await bootstrapOrganiser(db, 'kemi', { demo: false });
    const bad = await patch({ paypalEmail: 'not-an-email' });
    expect(bad.status).toBe(400);
    expect(bad.body.error.message).toBe('That is not an email address PayPal can pay.');
    expect((await patch({})).status).toBe(400);
    expect((await patch({ demoSeeded: false })).status).toBe(400);
  });
});
