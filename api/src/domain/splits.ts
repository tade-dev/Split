import { FieldValue, Timestamp, type DocumentReference, type Firestore, type Transaction } from 'firebase-admin/firestore';
import type { Ambiguity } from '../ai/schemas.js';
import { ApiError } from '../lib/errors.js';
import { allocate } from './allocate.js';
import { DEFAULT_RULES, type Allocation, type Claim, type Receipt, type Rules } from './split.js';

export type SplitStatus = 'draft' | 'claiming' | 'collecting' | 'settled' | 'cancelled';

export type ParticipantStatus =
  | 'invited' | 'claimed' | 'owes' | 'link_opened' | 'processing'
  | 'pending' | 'declined' | 'paid' | 'paid_cash' | 'on_us';

/** organisers/{uid}/splits/{splitId}. Spec §2. */
export type SplitDoc = {
  id: string;
  title: string;
  merchant: string | null;
  receiptDate: string | null;
  status: SplitStatus;
  receipt: Receipt;
  receiptAmbiguities: Ambiguity[];
  claims: Record<string, Claim[]>;
  rules: Rules;
  organiserParticipantId: string;
  computed: Allocation | null;
  lockedAt: Timestamp | null;
  extractionModel: string;
  sourceRef: string | null;
};

/** organisers/{uid}/splits/{splitId}/participants/{participantId}. Spec §2. */
export type ParticipantDoc = {
  id: string;
  name: string;
  colourIndex: number;
  isOrganiser: boolean;
  joinOrder: number;
  status: ParticipantStatus;
  claimText: string | null;
  shareMinor: number | null;
  paypalOrderId: string | null;
  approvalUrl: string | null;
  paypalCaptureId: string | null;
  supersededPaypalOrderIds: string[];
  nudge: { count: number; lastSentAt: Timestamp | null; lastText: string | null; channel: string | null; snoozedUntil: Timestamp | null };
  linkOpenedAt: Timestamp | null;
  claimedAt: Timestamp | null;
  paidAt: Timestamp | null;
  aiParsesUsed: number;
};

/** Eight colours (DESIGN.md), assigned in join order, the organiser first. */
export const PARTICIPANT_COLOURS = 8;

export function newParticipant(
  id: string,
  input: { name: string; joinOrder: number; isOrganiser: boolean },
): ParticipantDoc {
  return {
    id,
    name: input.name,
    colourIndex: input.joinOrder % PARTICIPANT_COLOURS,
    isOrganiser: input.isOrganiser,
    joinOrder: input.joinOrder,
    status: 'invited',
    claimText: null,
    shareMinor: null,
    paypalOrderId: null,
    approvalUrl: null,
    paypalCaptureId: null,
    supersededPaypalOrderIds: [],
    nudge: { count: 0, lastSentAt: null, lastText: null, channel: null, snoozedUntil: null },
    linkOpenedAt: null,
    claimedAt: null,
    paidAt: null,
    aiParsesUsed: 0,
  };
}

/** "Friday's bill" from 2026-10-02, or "Your bill" when the date was unread. */
export function defaultTitle(receiptDate: string | null): string {
  if (!receiptDate) return 'Your bill';
  const day = new Date(`${receiptDate}T12:00:00Z`).toLocaleDateString('en-GB', { weekday: 'long', timeZone: 'Europe/London' });
  return `${day}'s bill`;
}

/** The single place `computed` comes from. The app only ever renders this. */
export function computeFor(split: Pick<SplitDoc, 'receipt' | 'claims' | 'rules'>, participants: ParticipantDoc[]): Allocation {
  return allocate({
    receipt: split.receipt,
    claims: split.claims,
    rules: split.rules,
    participants: participants.map((p) => ({ id: p.id, joinOrder: p.joinOrder, isOrganiser: p.isOrganiser })),
  });
}

export const splitPath = (organiserId: string, splitId: string) => `organisers/${organiserId}/splits/${splitId}`;

export type NewSplitInput = {
  title?: string;
  merchant: string | null;
  receiptDate: string | null;
  receipt: Receipt;
  receiptAmbiguities: Ambiguity[];
  extractionModel: string;
  sourceRef: string | null;
  organiserName: string;
};

/** A WriteBatch or a Transaction: both can set a document. */
type Setter = { set(ref: DocumentReference, data: Record<string, unknown>): unknown };

/**
 * Builds a new draft split and its organiser participant, with `computed`
 * already filled in so the app's listener never sees a split without one.
 * `write` queues both documents on a batch or a transaction.
 */
export function prepareSplit(db: Firestore, organiserId: string, input: NewSplitInput): { split: SplitDoc; write: (w: Setter) => void } {
  const ref = db.collection(`organisers/${organiserId}/splits`).doc();
  const organiserRef = ref.collection('participants').doc();
  const organiser = newParticipant(organiserRef.id, { name: input.organiserName, joinOrder: 0, isOrganiser: true });
  const base = { receipt: input.receipt, claims: {}, rules: DEFAULT_RULES };
  const split: SplitDoc = {
    id: ref.id,
    title: input.title ?? defaultTitle(input.receiptDate),
    merchant: input.merchant,
    receiptDate: input.receiptDate,
    status: 'draft',
    ...base,
    receiptAmbiguities: input.receiptAmbiguities,
    organiserParticipantId: organiser.id,
    computed: computeFor(base, [organiser]),
    lockedAt: null,
    extractionModel: input.extractionModel,
    sourceRef: input.sourceRef,
  };
  return {
    split,
    write: (w) => {
      w.set(ref, { ...split, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
      w.set(organiserRef, organiser);
    },
  };
}

export async function createSplit(db: Firestore, organiserId: string, input: NewSplitInput): Promise<SplitDoc> {
  const { split, write } = prepareSplit(db, organiserId, input);
  const batch = db.batch();
  write(batch);
  await batch.commit();
  return split;
}

/** Reads a split and its participants inside a transaction, or 404s. */
export async function readSplit(
  tx: Transaction,
  db: Firestore,
  organiserId: string,
  splitId: string,
): Promise<{ ref: DocumentReference; split: SplitDoc; participants: ParticipantDoc[] }> {
  const ref = db.doc(splitPath(organiserId, splitId));
  const snap = await tx.get(ref);
  if (!snap.exists) throw new ApiError(404, 'NOT_FOUND', 'That split does not exist.');
  const people = await tx.get(ref.collection('participants'));
  return {
    ref,
    split: { ...(snap.data() as SplitDoc), id: snap.id },
    participants: people.docs.map((d) => ({ ...(d.data() as ParticipantDoc), id: d.id })),
  };
}

export function assertStatus(split: SplitDoc, allowed: SplitStatus[], action: string): void {
  if (!allowed.includes(split.status)) {
    throw new ApiError(409, 'SPLIT_STATE_INVALID', `You can only ${action} while the split is ${allowed.join(' or ')}.`, {
      status: split.status,
    });
  }
}

/** Firestore values to API JSON: Timestamps become ISO strings, recursively. */
export function toApi<T>(value: T): unknown {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(toApi);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, toApi(v)]));
  }
  return value;
}
