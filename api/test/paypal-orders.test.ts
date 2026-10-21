import { describe, expect, it, vi } from 'vitest';
import { createPayPalOrder, type ShareOrder } from '../src/paypal/orders.js';
import type { PayPalFetch } from '../src/paypal/client.js';

const share: ShareOrder = {
  referenceId: 'dan',
  customId: 'kemi:s1:dan',
  amountMinor: 3923,
  description: 'Your share of Friday dinner (Little Bao House)',
  payeeEmail: null,
  requestId: 'pay-s1-dan-0',
};

const created = {
  id: 'PP-ORDER-1',
  status: 'PAYER_ACTION_REQUIRED',
  links: [
    { rel: 'self', method: 'GET', href: 'https://api.sandbox.paypal.com/v2/checkout/orders/PP-ORDER-1' },
    { rel: 'payer-action', method: 'GET', href: 'https://www.sandbox.paypal.com/checkoutnow?token=PP-ORDER-1' },
  ],
};

type Unit = Record<string, unknown> & { amount: Record<string, unknown> };
const unitOf = (call: ReturnType<typeof vi.fn<PayPalFetch>>) =>
  (call.mock.calls[0]![1].body as { purchase_units: Unit[] }).purchase_units[0]!;

describe('createPayPalOrder', () => {
  it('returns the id and the rel=payer-action link, which is what PayPal sends', async () => {
    const out = await createPayPalOrder(share, async () => created);
    expect(out).toEqual({ paypalOrderId: 'PP-ORDER-1', approvalUrl: 'https://www.sandbox.paypal.com/checkoutnow?token=PP-ORDER-1' });
  });

  it('charges exactly the share in GBP, with no item breakdown', async () => {
    const call = vi.fn<PayPalFetch>().mockResolvedValue(created);
    await createPayPalOrder(share, call);
    const unit = unitOf(call);
    expect(unit.amount).toEqual({ currency_code: 'GBP', value: '39.23' });
    expect(unit.items).toBeUndefined();
  });

  it('carries the ids the webhook needs and the request id it is given', async () => {
    const call = vi.fn<PayPalFetch>().mockResolvedValue(created);
    await createPayPalOrder(share, call);
    expect(unitOf(call)).toMatchObject({ reference_id: 'dan', custom_id: 'kemi:s1:dan', description: share.description });
    expect(call.mock.calls[0]![1].requestId).toBe('pay-s1-dan-0');
  });

  it("pays the organiser's own PayPal when an email is given, else the shared merchant", async () => {
    const withEmail = vi.fn<PayPalFetch>().mockResolvedValue(created);
    await createPayPalOrder({ ...share, payeeEmail: 'kemi@example.com' }, withEmail);
    expect(unitOf(withEmail).payee).toEqual({ email_address: 'kemi@example.com' });
    const without = vi.fn<PayPalFetch>().mockResolvedValue(created);
    await createPayPalOrder(share, without);
    expect(unitOf(without)).not.toHaveProperty('payee');
  });

  it('sends the friend back to the configured origin, in a UK experience with no shipping', async () => {
    const call = vi.fn<PayPalFetch>().mockResolvedValue(created);
    await createPayPalOrder(share, call, 'https://pay.example.test/');
    const ctx = (call.mock.calls[0]![1].body as {
      payment_source: { paypal: { experience_context: Record<string, string> } };
    }).payment_source.paypal.experience_context;
    expect(ctx).toMatchObject({
      return_url: 'https://pay.example.test/v1/paypal/return',
      cancel_url: 'https://pay.example.test/v1/paypal/cancel',
      locale: 'en-GB',
      shipping_preference: 'NO_SHIPPING',
      user_action: 'PAY_NOW',
    });
  });

  it('throws when PayPal returns no approval link', async () => {
    await expect(createPayPalOrder(share, async () => ({ id: 'X', status: 'CREATED', links: [] }))).rejects.toMatchObject({
      code: 'PAYPAL_UNAVAILABLE',
    });
  });

  it('refuses to create an order for nothing', async () => {
    const call = vi.fn<PayPalFetch>().mockResolvedValue(created);
    await expect(createPayPalOrder({ ...share, amountMinor: 0 }, call)).rejects.toThrow();
    expect(call).not.toHaveBeenCalled();
  });
});
