import { ApiError } from '../lib/errors.js';
import { DEFAULT_PUBLIC_BASE_URL } from '../env.js';
import { toPayPalValue } from '../domain/money.js';
import type { PayPalFetch } from './client.js';

type CreatedOrder = {
  id: string;
  status: string;
  links?: { rel: string; href: string; method: string }[];
};

export type ShareOrder = {
  /** purchase_units[0].reference_id: the participant. */
  referenceId: string;
  /** `organiserId:splitId:participantId`, so a webhook needs no lookup. */
  customId: string;
  amountMinor: number;
  description: string;
  /**
   * The organiser's PayPal email: PayPal pays it directly, verified by the
   * payee spike (docs/verified-facts.md). Null pays the shared sandbox
   * merchant that owns the app (plan E10).
   */
  payeeEmail: string | null;
  /** PayPal-Request-Id. A new one per superseded order, or PayPal hands back the old one. */
  requestId: string;
};

/**
 * Creates the order a friend approves for their share. The body is the one
 * the payee spike sent, which PayPal accepted: one amount, no item breakdown
 * (spec §5), so it can never disagree with the share Split worked out.
 *
 * With payment_source.paypal.experience_context the response status is
 * PAYER_ACTION_REQUIRED and the approval link is rel="payer-action"; there
 * is no rel="approve".
 */
export async function createPayPalOrder(
  order: ShareOrder,
  call: PayPalFetch,
  publicBaseUrl: string = DEFAULT_PUBLIC_BASE_URL,
): Promise<{ paypalOrderId: string; approvalUrl: string }> {
  if (!Number.isSafeInteger(order.amountMinor) || order.amountMinor <= 0) {
    throw new ApiError(400, 'VALIDATION_FAILED', 'There is nothing to pay on this share.');
  }
  const base = publicBaseUrl.replace(/\/+$/, '') || DEFAULT_PUBLIC_BASE_URL;

  const created = (await call('/v2/checkout/orders', {
    method: 'POST',
    requestId: order.requestId,
    body: {
      intent: 'CAPTURE',
      purchase_units: [
        {
          reference_id: order.referenceId,
          custom_id: order.customId,
          description: order.description.slice(0, 127),
          amount: { currency_code: 'GBP', value: toPayPalValue(order.amountMinor) },
          ...(order.payeeEmail ? { payee: { email_address: order.payeeEmail } } : {}),
        },
      ],
      payment_source: {
        paypal: {
          experience_context: {
            brand_name: 'Split',
            locale: 'en-GB',
            user_action: 'PAY_NOW',
            shipping_preference: 'NO_SHIPPING',
            return_url: `${base}/v1/paypal/return`,
            cancel_url: `${base}/v1/paypal/cancel`,
          },
        },
      },
    },
  })) as CreatedOrder;

  const approval = created.links?.find((l) => l.rel === 'payer-action')?.href;
  if (!created.id || !approval) {
    throw new ApiError(502, 'PAYPAL_UNAVAILABLE', 'PayPal created the order but returned no checkout link. Try again.', {
      status: created.status,
    });
  }
  return { paypalOrderId: created.id, approvalUrl: approval };
}
