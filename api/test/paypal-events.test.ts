import { describe, expect, it } from 'vitest';
import {
  captureOutcome,
  orderCustomId,
  parseCustomId,
  parsePayPalEvent,
  reconcileAction,
  statusForEvent,
  verifyWebhookBody,
} from '../src/paypal/events.js';

describe('parsePayPalEvent', () => {
  it('reads the seller and order from an approved order', () => {
    const event = parsePayPalEvent({
      id: 'WH-1',
      event_type: 'CHECKOUT.ORDER.APPROVED',
      resource: {
        id: 'PP-1',
        purchase_units: [{ custom_id: 'kemi:s1:dan' }],
      },
    });
    expect(event).toMatchObject({
      id: 'WH-1',
      paypalOrderId: 'PP-1',
      customId: 'kemi:s1:dan',
    });
    expect(parseCustomId(event!.customId)).toEqual({ organiserId: 'kemi', splitId: 's1', participantId: 'dan' });
  });

  it('reads a capture from the capture resource', () => {
    const event = parsePayPalEvent({
      id: 'WH-2',
      event_type: 'PAYMENT.CAPTURE.COMPLETED',
      resource: {
        id: 'CAP-1',
        status: 'COMPLETED',
        custom_id: 'kemi:s1:dan',
        amount: { currency_code: 'GBP', value: '42.00' },
        supplementary_data: { related_ids: { order_id: 'PP-1' } },
      },
    });
    expect(event).toMatchObject({
      captureId: 'CAP-1',
      paypalOrderId: 'PP-1',
      amountMinor: 4200,
    });
  });
});

describe('parseCustomId', () => {
  it('needs exactly three parts, none empty', () => {
    expect(parseCustomId('kemi:s1:dan')).toEqual({ organiserId: 'kemi', splitId: 's1', participantId: 'dan' });
    for (const bad of [null, '', 'kemi:o1', 'kemi:s1:dan:x', 'kemi::dan', ':s1:dan', 'kemi:s1:']) {
      expect(parseCustomId(bad)).toBeNull();
    }
  });

  it('reads custom_id off a GET order response', () => {
    expect(orderCustomId({ purchase_units: [{ custom_id: 'kemi:s1:dan' }] })).toBe('kemi:s1:dan');
    expect(orderCustomId({ purchase_units: [] })).toBeNull();
  });
});

describe('captureOutcome', () => {
  it('treats a COMPLETED capture response as paid: for a payee order it may be the only signal', () => {
    expect(
      captureOutcome({
        status: 'COMPLETED',
        purchase_units: [{ payments: { captures: [{ id: 'CAP-1', status: 'COMPLETED' }] } }],
      }),
    ).toEqual({ status: 'paid', captureId: 'CAP-1' });
  });

  it('keeps a pending capture pending, and says nothing before a capture', () => {
    expect(
      captureOutcome({
        status: 'COMPLETED',
        purchase_units: [{ payments: { captures: [{ id: 'CAP-1', status: 'PENDING' }] } }],
      }).status,
    ).toBe('pending');
    expect(captureOutcome({ status: 'APPROVED', purchase_units: [{}] }).status).toBeNull();
  });
});

describe('statusForEvent', () => {
  it('marks paid only for the completed capture webhook', () => {
    expect(statusForEvent('PAYMENT.CAPTURE.COMPLETED')).toBe('paid');
    expect(statusForEvent('CHECKOUT.ORDER.APPROVED')).toBeNull();
    expect(statusForEvent('PAYMENT.CAPTURE.REFUNDED')).toBeNull();
    expect(statusForEvent('CHECKOUT.PAYMENT-APPROVAL.REVERSED')).toBe('owes');
  });
});

describe('reconcileAction', () => {
  it('treats a completed capture as paid', () => {
    expect(reconcileAction({
      status: 'COMPLETED',
      purchase_units: [{ payments: { captures: [{ id: 'CAP-1', status: 'COMPLETED' }] } }],
    })).toEqual({ kind: 'move', status: 'paid', captureId: 'CAP-1' });
  });

  it('asks for a capture when the buyer has approved and nothing was captured', () => {
    expect(reconcileAction({
      status: 'APPROVED',
      purchase_units: [{ custom_id: 'kemi:s1:dan' }],
    })).toEqual({ kind: 'capture' });
  });

  it('follows a pending or declined capture', () => {
    expect(reconcileAction({
      status: 'COMPLETED',
      purchase_units: [{ payments: { captures: [{ id: 'CAP-1', status: 'PENDING' }] } }],
    })).toEqual({ kind: 'move', status: 'pending', captureId: 'CAP-1' });
    expect(reconcileAction({
      status: 'COMPLETED',
      purchase_units: [{ payments: { captures: [{ id: 'CAP-1', status: 'DECLINED' }] } }],
    })).toEqual({ kind: 'move', status: 'declined', captureId: 'CAP-1' });
  });

  it('leaves an order the buyer has not approved', () => {
    expect(reconcileAction({ status: 'PAYER_ACTION_REQUIRED', purchase_units: [] })).toEqual({ kind: 'leave' });
  });
});

describe('verifyWebhookBody', () => {
  it('embeds the raw event without reordering it', () => {
    const raw = '{"z":1,"a":2}';
    const body = verifyWebhookBody(
      raw,
      {
        authAlgo: 'SHA256withRSA',
        certUrl: 'https://example.test/cert',
        transmissionId: 'tid',
        transmissionSig: 'sig',
        transmissionTime: '2026-10-11T12:00:00Z',
      },
      'wh-1',
    );
    expect(body).toContain(`"webhook_event":${raw}`);
    expect(JSON.parse(body).webhook_id).toBe('wh-1');
  });
});
