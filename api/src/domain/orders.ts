// TRANSITIONAL. Trimmed from Sorted's domain/orders.ts @902dc25 so the copied
// PayPal, webhook, reconcile and nudge code compiles unchanged. Only the order
// types and the status transition table are kept. Split replaces this with
// participant shares (spec §2) in the Week B plan, and this file goes away.
import type { Timestamp } from 'firebase-admin/firestore';
import type { Ambiguity } from '../ai/schemas.js';
import { ApiError } from '../lib/errors.js';

/** The fields of Sorted's MatchedLine the copied code reads. */
export type OrderLine = {
  nameRaw: string;
  nameResolved: string | null;
  qty: number;
  unitPriceMinor: number;
  lineTotalMinor: number;
};

export type OrderStatus =
  | 'draft'
  | 'link_sent'
  | 'processing'
  | 'pending'
  | 'declined'
  | 'paid'
  | 'cancelled'
  | 'expired';

export type OrderDoc = {
  id: string;
  status: OrderStatus;
  buyerName: string | null;
  buyerHandle: string | null;
  buyerEmail: string | null;
  channel: string;
  lineItems: OrderLine[];
  subtotalMinor: number;
  depositMinor: number | null;
  amountDueMinor: number;
  currency: 'GBP';
  fulfilment: { mode: string; date: string | null; notes: string | null };
  ambiguities: Ambiguity[];
  paypalOrderId: string | null;
  /** PayPal orders replaced by an edit. Their approvals are never captured. */
  supersededPaypalOrderIds?: string[];
  approvalUrl: string | null;
  paypalCaptureId: string | null;
  /** Seller PayPal email the link pays, or 'shared_sandbox'. */
  paypalPayee?: string;
  paypalInvoiceId: string | null;
  draftedReply: string | null;
  nudge: { count: number; lastSentAt: Timestamp | null; lastText: string | null; channel: string | null; snoozedUntil: Timestamp | null };
  sourceKind: 'screenshot' | 'text';
  extractionModel: string;
  expiresAt: Timestamp | null;
};

const ALLOWED: Record<OrderStatus, OrderStatus[]> = {
  draft: ['link_sent', 'cancelled'],
  // processing / pending / declined are interim. Paid is only the capture webhook.
  link_sent: ['processing', 'pending', 'declined', 'paid', 'cancelled', 'expired'],
  processing: ['pending', 'declined', 'paid', 'link_sent', 'cancelled', 'expired'],
  pending: ['processing', 'declined', 'paid', 'link_sent', 'cancelled', 'expired'],
  declined: ['link_sent', 'processing', 'pending', 'paid', 'cancelled', 'expired'],
  paid: [],
  cancelled: [],
  expired: [],
};

export function assertTransition(from: OrderStatus, to: OrderStatus): void {
  if (!ALLOWED[from]?.includes(to)) {
    throw new ApiError(
      409,
      'ORDER_STATE_INVALID',
      `An order that is ${from} cannot become ${to}.`,
    );
  }
}
