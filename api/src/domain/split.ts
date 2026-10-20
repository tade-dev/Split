import type { Ambiguity } from '../ai/schemas.js';
import type { Minor } from './money.js';

/** One printed line. The printed line total is the truth; unit price is display only. */
export type ReceiptLine = {
  /** Stable slug plus index, e.g. `lager-8`. */
  id: string;
  name: string;
  qty: number;
  /** Null only while a draft has an unreadable price. allocate() refuses it. */
  lineTotalMinor: Minor | null;
};

export type Receipt = {
  lines: ReceiptLine[];
  serviceChargeMinor: Minor;
  serviceChargeLabel: string | null;
  tipMinor: Minor;
  /** Each amount is positive and is taken off the bill. */
  discounts: { label: string; amountMinor: Minor }[];
  /** Null only while a draft has an unreadable total. allocate() refuses it. */
  printedTotalMinor: Minor | null;
  currency: 'GBP';
};

export type Claim = {
  participantId: string;
  weight: number;
  source: 'ai' | 'organiser' | 'friend';
};

export type Rules = {
  serviceMode: 'proportional' | 'even';
  onUs: string[];
  /** Null means every participant who is not on us, the organiser included. */
  onUsPaidBy: string[] | null;
  serviceOptOut: string[];
};

export const DEFAULT_RULES: Rules = {
  serviceMode: 'proportional',
  onUs: [],
  onUsPaidBy: null,
  serviceOptOut: [],
};

export type AllocParticipant = { id: string; joinOrder: number; isOrganiser: boolean };

export type BreakdownLine = { lineId: string; minor: Minor; portionLabel: string };

export type Breakdown = {
  /** What their own claims cost, before anyone is on us. */
  itemsMinor: Minor;
  /**
   * Positive for a payer covering someone on us. For the on-us person it is
   * minus their own items, so the formula below still holds and the column
   * sums to zero.
   */
  sharedFromOnUsMinor: number;
  serviceMinor: Minor;
  tipMinor: Minor;
  /** Positive: the amount taken off this person's share. */
  discountMinor: Minor;
  /** itemsMinor + sharedFromOnUsMinor + serviceMinor + tipMinor − discountMinor. */
  finalMinor: Minor;
  lines: BreakdownLine[];
};

export type Allocation =
  | { ok: true; perParticipant: Record<string, Breakdown>; totalMinor: Minor }
  | { ok: false; problems: Ambiguity[] };
