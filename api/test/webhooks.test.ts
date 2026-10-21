import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import { ApiError } from '../src/lib/errors.js';
import type { PayPalFetch } from '../src/paypal/client.js';
import { order, person, seedCollecting, splitStatus, statusOf } from './shares-fixture.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-webhook-test', INTERNAL_TOKEN: 't', LINK_SECRET: 'link-secret',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-webhook-test' });
  db = getFirestore();
});

const HEADERS = {
  'paypal-transmission-id': 'tid',
  'paypal-transmission-time': '2026-10-11T12:00:00Z',
  'paypal-cert-url': 'https://example.test/cert',
  'paypal-auth-algo': 'SHA256withRSA',
  'paypal-transmission-sig': 'sig',
};

type Call = { path: string; requestId?: string; rawBody?: string };

function paypal(opts: { verified?: boolean; captureStatus?: string } = {}): { fetch: PayPalFetch; calls: Call[] } {
  const calls: Call[] = [];
  const fetch: PayPalFetch = async (path, init) => {
    calls.push({ path, requestId: init.requestId, rawBody: init.rawBody });
    if (path.includes('verify-webhook-signature')) {
      return { verification_status: opts.verified === false ? 'FAILURE' : 'SUCCESS' };
    }
    if (path.endsWith('/capture')) return order('PPDAN', 'COMPLETED', opts.captureStatus ?? 'COMPLETED');
    return order('PPDAN', 'APPROVED');
  };
  return { fetch, calls };
}

function appWith(fetch: PayPalFetch) {
  return createApp({
    env, db, paypal: fetch,
    transport: async () => ({ content: '{}' }),
    verify: async () => { throw new Error('webhooks are not authenticated as a seller'); },
  });
}

function event(eventType: string, id: string, resource: unknown): string {
  return JSON.stringify({ id, event_type: eventType, resource });
}

const approved = () => event('CHECKOUT.ORDER.APPROVED', 'WH-APPROVED', {
  id: 'PPDAN',
  purchase_units: [{ custom_id: 'kemi:s1:dan' }],
});

const capture = (eventType: string, id: string, status: string, extra: Record<string, unknown> = {}) => event(eventType, id, {
  id: 'CAP-1',
  status,
  custom_id: 'kemi:s1:dan',
  amount: { currency_code: 'GBP', value: '39.23' },
  supplementary_data: { related_ids: { order_id: 'PPDAN' } },
  ...extra,
});

async function post(app: ReturnType<typeof appWith>, raw: string) {
  const req = request(app).post('/v1/webhooks/paypal').set('Content-Type', 'application/json');
  for (const [name, value] of Object.entries(HEADERS)) req.set(name, value);
  return req.send(raw);
}

const seed = (dan: Record<string, unknown> = {}) => seedCollecting(db, { dan });
const ledgerRow = (id: string) => person(db, 'dan').collection('paymentEvents').doc(id).get();

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
  const events = await db.collection('webhookEvents').listDocuments();
  await Promise.all(events.map((e) => e.delete()));
});

describe('POST /v1/webhooks/paypal', () => {
  it('rejects an event PayPal does not verify', async () => {
    await seed();
    const { fetch, calls } = paypal({ verified: false });
    const before = await request(appWith(fetch)).get('/v1/health');

    const res = await post(appWith(fetch), approved());

    expect(res.status).toBe(401);
    expect(calls.some((c) => c.path.endsWith('/capture'))).toBe(false);
    expect(await statusOf(db, 'dan')).toBe('link_opened');
    const ledger = await db.collection('webhookEvents').get();
    expect(ledger.empty).toBe(true);
    const after = await request(appWith(fetch)).get('/v1/health');
    expect(after.body.webhookFailures).toBe(before.body.webhookFailures + 1);
  });

  it('captures an approved order and marks the share paid', async () => {
    await seed();
    const { fetch, calls } = paypal();
    const raw = approved();
    const res = await post(appWith(fetch), raw);

    expect(res.status).toBe(200);
    const captured = calls.find((c) => c.path.endsWith('/capture'));
    expect(captured?.path).toBe('/v2/checkout/orders/PPDAN/capture');
    expect(captured?.requestId).toBe('capture-dan-PPDAN');
    const verify = calls.find((c) => c.path.includes('verify-webhook-signature'));
    expect(verify?.rawBody).toContain(`"webhook_event":${raw}`);

    const dan = await person(db, 'dan').get();
    expect(dan.get('status')).toBe('paid');
    expect(dan.get('paypalCaptureId')).toBe('CAP-PPDAN');
    const ledger = await db.doc('webhookEvents/WH-APPROVED').get();
    expect(ledger.get('handled')).toBe(true);
    expect(ledger.get('splitId')).toBe('s1');
    expect(ledger.get('participantId')).toBe('dan');
  });

  it('finds an approval the return page already captured, and changes nothing', async () => {
    await seed({ status: 'paid', paypalCaptureId: 'CAP-PPDAN' });
    const { fetch, calls } = paypal();
    expect((await post(appWith(fetch), approved())).status).toBe(200);
    expect(calls.some((c) => c.path.endsWith('/capture'))).toBe(false);
    expect(await statusOf(db, 'dan')).toBe('paid');
  });

  it('ignores a duplicate event', async () => {
    await seed();
    const { fetch, calls } = paypal();
    const app = appWith(fetch);
    const raw = approved();

    expect((await post(app, raw)).status).toBe(200);
    await person(db, 'dan').update({ status: 'link_opened' });
    expect((await post(app, raw)).status).toBe(200);
    expect(calls.filter((c) => c.path.endsWith('/capture'))).toHaveLength(1);
  });

  it('marks the share paid when the capture completes, and settles the split on the last one', async () => {
    await seedCollecting(db, { dan: { status: 'processing' }, josh: { status: 'paid' } });
    const { fetch, calls } = paypal();
    const res = await post(appWith(fetch), capture('PAYMENT.CAPTURE.COMPLETED', 'WH-PAID', 'COMPLETED'));

    expect(res.status).toBe(200);
    expect(calls.some((c) => c.path.endsWith('/capture'))).toBe(false);
    const dan = await person(db, 'dan').get();
    expect(dan.get('status')).toBe('paid');
    expect(dan.get('paypalCaptureId')).toBe('CAP-1');
    expect(dan.get('paidAt')).toBeTruthy();
    expect(await splitStatus(db)).toBe('settled');
    const payment = await ledgerRow('WH-PAID');
    expect(payment.get('amountMinor')).toBe(3923);
    expect(payment.get('signatureVerified')).toBe(true);
  });

  it('finds the share by the stored PayPal id when custom_id is absent', async () => {
    await seed({ status: 'processing' });
    const { fetch } = paypal();
    const res = await post(appWith(fetch), capture('PAYMENT.CAPTURE.COMPLETED', 'WH-LOOKUP', 'COMPLETED', { custom_id: undefined }));
    expect(res.status).toBe(200);
    expect(await statusOf(db, 'dan')).toBe('paid');
  });

  it('records an event for no known share as handled', async () => {
    const { fetch } = paypal();
    const fetchNothing: PayPalFetch = async (path, init) => (path.includes('verify') ? fetch(path, init) : { id: 'X', purchase_units: [{}] });
    const res = await post(appWith(fetchNothing), capture('PAYMENT.CAPTURE.COMPLETED', 'WH-NOBODY', 'COMPLETED', { custom_id: 'kemi:s1:nobody' }));
    expect(res.status).toBe(200);
    const ledger = await db.doc('webhookEvents/WH-NOBODY').get();
    expect(ledger.get('handled')).toBe(true);
    expect(ledger.get('processingError')).toBe('No matching share.');
  });

  it('shows pending without leaving the payment unpaid', async () => {
    await seed();
    const { fetch } = paypal();
    const res = await post(appWith(fetch), capture('PAYMENT.CAPTURE.PENDING', 'WH-PENDING', 'PENDING'));
    expect(res.status).toBe(200);
    expect(await statusOf(db, 'dan')).toBe('pending');
  });

  it('records a denied capture as declined and keeps the link', async () => {
    await seed();
    const { fetch } = paypal();
    const res = await post(appWith(fetch), capture('PAYMENT.CAPTURE.DENIED', 'WH-DENIED', 'DENIED'));
    expect(res.status).toBe(200);
    const dan = await person(db, 'dan').get();
    expect(dan.get('status')).toBe('declined');
    expect(dan.get('approvalUrl')).toContain('checkoutnow');
  });

  it('sends a reversed approval back to owes and keeps the link', async () => {
    await seed({ status: 'processing' });
    const { fetch } = paypal();
    const res = await post(appWith(fetch), event('CHECKOUT.PAYMENT-APPROVAL.REVERSED', 'WH-REV', {
      id: 'PPDAN',
      purchase_units: [{ custom_id: 'kemi:s1:dan' }],
    }));
    expect(res.status).toBe(200);
    const dan = await person(db, 'dan').get();
    expect(dan.get('status')).toBe('owes');
    expect(dan.get('approvalUrl')).toContain('checkoutnow');
  });

  it('never moves a paid share, and notes why', async () => {
    await seed({ status: 'paid' });
    const { fetch } = paypal();
    await post(appWith(fetch), capture('PAYMENT.CAPTURE.DENIED', 'WH-LATE-DENY', 'DENIED'));
    expect(await statusOf(db, 'dan')).toBe('paid');
    expect((await ledgerRow('WH-LATE-DENY')).get('processingError')).toBe('A share that is paid cannot become declined.');
  });

  it('posts a documented capture event back exactly, charset and all', async () => {
    await seed();
    const { fetch, calls } = paypal();
    // Field order matches PayPal's published PAYMENT.CAPTURE.COMPLETED example.
    // Re-stringifying it would move "id" ahead of "amount".
    const raw = '{"id":"WH-3F562076HD293871E-75F399086E414290U","event_version":"1.0","create_time":"2024-05-16T05:19:19.355Z","resource_type":"capture","resource_version":"2.0","event_type":"PAYMENT.CAPTURE.COMPLETED","summary":"Payment completed for GBP 39.23","resource":{"amount":{"value":"39.23","currency_code":"GBP"},"custom_id":"kemi:s1:dan","supplementary_data":{"related_ids":{"order_id":"PPDAN"}},"id":"CAP-1","status":"COMPLETED"}}';
    const req = request(appWith(fetch))
      .post('/v1/webhooks/paypal')
      .set('Content-Type', 'application/json; charset=utf-8');
    for (const [name, value] of Object.entries(HEADERS)) req.set(name, value);
    const res = await req.send(raw);

    expect(res.status).toBe(200);
    const verify = calls.find((c) => c.path.includes('verify-webhook-signature'));
    expect(verify?.rawBody).toContain(`"webhook_event":${raw}`);
    expect(await statusOf(db, 'dan')).toBe('paid');
  });
  it('logs a rejected verification status without the signature', async () => {
    await seed();
    const { fetch } = paypal({ verified: false });
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const req = request(appWith(fetch)).post('/v1/webhooks/paypal').set('Content-Type', 'application/json');
    for (const [name, value] of Object.entries(HEADERS)) {
      req.set(name, name === 'paypal-transmission-sig' ? 'SIGSECRETVALUE' : value);
    }
    const res = await req.send(approved());
    const logged = spy.mock.calls.map((call) => call.map(String).join(' ')).join('\n');
    spy.mockRestore();

    expect(res.status).toBe(401);
    expect(logged).toContain('"verificationStatus":"FAILURE"');
    expect(logged).not.toContain('SIGSECRETVALUE');
  });

  it('logs a delivery that never reached PayPal', async () => {
    const { fetch, calls } = paypal();
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const res = await request(appWith(fetch))
      .post('/v1/webhooks/paypal')
      .set('Content-Type', 'text/plain')
      .send('nope');
    const logged = spy.mock.calls.map((call) => call.map(String).join(' ')).join('\n');
    spy.mockRestore();

    expect(res.status).toBe(401);
    expect(logged).toContain('"reason":"missing_body"');
    expect(logged).toContain('text/plain');
    expect(calls).toHaveLength(0);
  });

  it('logs the PayPal HTTP issue when verification itself fails', async () => {
    await seed();
    const fetch: PayPalFetch = async () => {
      throw new ApiError(502, 'PAYPAL_UNAVAILABLE', 'PayPal rejected that request (VALIDATION_ERROR).', {
        status: 400,
        detail: 'VALIDATION_ERROR',
      });
    };
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const res = await post(appWith(fetch), approved());
    const logged = spy.mock.calls.map((call) => call.map(String).join(' ')).join('\n');
    spy.mockRestore();

    expect(res.status).toBe(502);
    expect(logged).toContain('"reason":"paypal_http"');
    expect(logged).toContain('"httpStatus":400');
    expect(logged).toContain('VALIDATION_ERROR');
    expect(logged).not.toContain('paypal-transmission-sig');
  });

  it('records a refund without moving a paid share', async () => {
    await seed({ status: 'paid' });
    const { fetch } = paypal();
    const res = await post(appWith(fetch), capture('PAYMENT.CAPTURE.REFUNDED', 'WH-REFUND', 'REFUNDED'));
    expect(res.status).toBe(200);
    expect(await statusOf(db, 'dan')).toBe('paid');
    expect((await ledgerRow('WH-REFUND')).exists).toBe(true);
  });

  describe('an order the expiry sweep replaced', () => {
    const replaced = () => seed({ status: 'owes', paypalOrderId: 'PPNEW', approvalUrl: 'https://www.sandbox.paypal.com/checkoutnow?token=PPNEW', supersededPaypalOrderIds: ['PPDAN'] });

    it('does not capture an approval on the old order', async () => {
      await replaced();
      const { fetch, calls } = paypal();
      const res = await post(appWith(fetch), approved());
      expect(res.status).toBe(200);
      expect(calls.some((c) => c.path.endsWith('/capture'))).toBe(false);
      expect(await statusOf(db, 'dan')).toBe('owes');
      const ledger = await db.doc('webhookEvents/WH-APPROVED').get();
      expect(ledger.get('handled')).toBe(true);
      expect(ledger.get('processingError')).toMatch(/replaced/);
      expect((await ledgerRow('WH-APPROVED')).get('refundDue')).toBeUndefined();
    });

    it('never marks the share paid from a capture on the old order, and flags it for refund', async () => {
      await replaced();
      const { fetch } = paypal();
      const res = await post(appWith(fetch), capture('PAYMENT.CAPTURE.COMPLETED', 'WH-OLDCAP', 'COMPLETED'));
      expect(res.status).toBe(200);
      const dan = await person(db, 'dan').get();
      expect(dan.get('status')).toBe('owes');
      expect(dan.get('paypalCaptureId')).toBeNull();
      const payment = await ledgerRow('WH-OLDCAP');
      expect(payment.get('refundDue')).toBe(true);
      expect(payment.get('processingError')).toMatch(/Refund/);
    });
  });
});
