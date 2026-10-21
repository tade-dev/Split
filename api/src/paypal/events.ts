import { ApiError } from '../lib/errors.js';
import type { PayPalFetch } from './client.js';

export const HANDLED_EVENTS = new Set([
  'CHECKOUT.ORDER.APPROVED',
  'CHECKOUT.PAYMENT-APPROVAL.REVERSED',
  'PAYMENT.CAPTURE.COMPLETED',
  'PAYMENT.CAPTURE.PENDING',
  'PAYMENT.CAPTURE.DENIED',
  'PAYMENT.CAPTURE.REFUNDED',
]);

export type PayPalEvent = {
  id: string;
  eventType: string;
  /** Capture id when the resource is a capture, otherwise the PayPal order id. */
  resourceId: string | null;
  captureId: string | null;
  paypalOrderId: string | null;
  customId: string | null;
  amountMinor: number | null;
};

function str(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

export function amountToMinor(value: unknown): number | null {
  if (typeof value !== 'string' || !/^\d+\.\d{2}$/.test(value)) return null;
  return Number(value.replace('.', ''));
}

/** `organiserId:splitId:participantId`, the custom_id the Pay route sets. Anything else is null. */
export function parseCustomId(value: string | null): { organiserId: string; splitId: string; participantId: string } | null {
  if (!value) return null;
  const parts = value.split(':');
  if (parts.length !== 3 || parts.some((part) => part.length === 0)) return null;
  const [organiserId, splitId, participantId] = parts as [string, string, string];
  return { organiserId, splitId, participantId };
}

/** custom_id from a GET order response, for when nothing else says whose share it is. */
export function orderCustomId(body: unknown): string | null {
  const order = (body ?? {}) as Record<string, unknown>;
  const units = Array.isArray(order.purchase_units) ? order.purchase_units : [];
  return str(((units[0] ?? {}) as Record<string, unknown>).custom_id);
}

export function parsePayPalEvent(body: unknown): PayPalEvent | null {
  if (!body || typeof body !== 'object') return null;
  const event = body as Record<string, unknown>;
  const id = str(event.id);
  const eventType = str(event.event_type);
  if (!id || !eventType) return null;

  const resource = (event.resource ?? {}) as Record<string, unknown>;
  const resourceId = str(resource.id);
  const isCapture = eventType.startsWith('PAYMENT.CAPTURE.');

  if (isCapture) {
    const related = (resource.supplementary_data ?? {}) as Record<string, unknown>;
    const relatedIds = (related.related_ids ?? {}) as Record<string, unknown>;
    const amount = (resource.amount ?? {}) as Record<string, unknown>;
    return {
      id,
      eventType,
      resourceId,
      captureId: resourceId,
      paypalOrderId: str(relatedIds.order_id),
      customId: str(resource.custom_id),
      amountMinor: amountToMinor(amount.value),
    };
  }

  const units = Array.isArray(resource.purchase_units) ? resource.purchase_units : [];
  const unit = (units[0] ?? {}) as Record<string, unknown>;
  return {
    id,
    eventType,
    resourceId,
    captureId: null,
    paypalOrderId: resourceId,
    customId: str(unit.custom_id),
    amountMinor: null,
  };
}

/** Where a share stands after a capture or GET order response. Null: nothing captured yet. */
export type CaptureOutcome = { status: 'paid' | 'pending' | 'declined' | null; captureId: string | null };

/**
 * Reads a capture or GET order response. A COMPLETED capture is Paid: for an
 * order paid straight to the organiser the capture response may be the only
 * signal there is (spec §0, plan Review Focus 6), so nothing waits for a
 * webhook that may never come.
 */
export function captureOutcome(body: unknown): CaptureOutcome {
  const order = (body ?? {}) as Record<string, unknown>;
  const units = Array.isArray(order.purchase_units) ? order.purchase_units : [];
  const unit = (units[0] ?? {}) as Record<string, unknown>;
  const payments = (unit.payments ?? {}) as Record<string, unknown>;
  const captures = Array.isArray(payments.captures) ? payments.captures : [];
  const capture = (captures[0] ?? {}) as Record<string, unknown>;
  const captureId = str(capture.id);
  switch (str(capture.status)) {
    case 'COMPLETED':
      return { status: 'paid', captureId };
    case 'PENDING':
      return { status: 'pending', captureId };
    case 'DECLINED':
    case 'DENIED':
    case 'FAILED':
      return { status: 'declined', captureId };
    default:
      return { status: null, captureId };
  }
}

/** Where a webhook moves a share. Refunds and approvals do not move it here. */
export function statusForEvent(eventType: string): 'paid' | 'pending' | 'declined' | 'owes' | null {
  switch (eventType) {
    case 'PAYMENT.CAPTURE.COMPLETED':
      return 'paid';
    case 'PAYMENT.CAPTURE.PENDING':
      return 'pending';
    case 'PAYMENT.CAPTURE.DENIED':
      return 'declined';
    case 'CHECKOUT.PAYMENT-APPROVAL.REVERSED':
      return 'owes';
    default:
      return null;
  }
}

export function paypalIssue(err: unknown): string | undefined {
  if (!(err instanceof ApiError) || !err.details || typeof err.details !== 'object') return undefined;
  const detail = (err.details as { detail?: unknown }).detail;
  return typeof detail === 'string' ? detail : undefined;
}

export function verifyWebhookBody(
  rawEvent: string,
  headers: {
    authAlgo: string;
    certUrl: string;
    transmissionId: string;
    transmissionSig: string;
    transmissionTime: string;
  },
  webhookId: string,
): string {
  const head = JSON.stringify({
    auth_algo: headers.authAlgo,
    cert_url: headers.certUrl,
    transmission_id: headers.transmissionId,
    transmission_sig: headers.transmissionSig,
    transmission_time: headers.transmissionTime,
    webhook_id: webhookId,
  });
  return `${head.slice(0, -1)},"webhook_event":${rawEvent}}`;
}

export type ReconcileAction =
  | { kind: 'leave' }
  | { kind: 'capture' }
  | { kind: 'move'; status: 'paid' | 'pending' | 'declined'; captureId: string | null };

/** What to do with a share, read from PayPal's own order. */
export function reconcileAction(body: unknown): ReconcileAction {
  const outcome = captureOutcome(body);
  if (outcome.status) return { kind: 'move', status: outcome.status, captureId: outcome.captureId };
  const order = (body ?? {}) as Record<string, unknown>;
  const orderStatus = typeof order.status === 'string' ? order.status : '';
  if (orderStatus === 'APPROVED' || orderStatus === 'COMPLETED') return { kind: 'capture' };
  return { kind: 'leave' };
}

/**
 * Captures a share's order. The request id names the participant and the
 * order, so a retry is answered from PayPal's cache, and a fresh order after
 * an expiry is never answered with the old one's capture.
 */
export async function capturePayPalOrder(
  call: PayPalFetch,
  paypalOrderId: string,
  participantId: string,
): Promise<unknown> {
  return call(`/v2/checkout/orders/${encodeURIComponent(paypalOrderId)}/capture`, {
    method: 'POST',
    requestId: `capture-${participantId}-${paypalOrderId}`,
    body: {},
  });
}

export async function getPayPalOrder(call: PayPalFetch, paypalOrderId: string): Promise<unknown> {
  return call(`/v2/checkout/orders/${encodeURIComponent(paypalOrderId)}`, { method: 'GET' });
}
