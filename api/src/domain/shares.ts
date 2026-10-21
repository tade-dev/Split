import { FieldValue, type DocumentReference } from 'firebase-admin/firestore';
import { ApiError } from '../lib/errors.js';
import { settleIfDone } from './lock.js';
import type { ParticipantDoc, ParticipantStatus } from './splits.js';

/**
 * Where a share may go once it has a PayPal order (plan Task 10). Paid is
 * final. Declined can still be paid: PayPal lets the friend try another card
 * on the same order. A reversed approval sends a share back to owes.
 */
const ALLOWED: Partial<Record<ParticipantStatus, ParticipantStatus[]>> = {
  owes: ['processing', 'pending', 'declined', 'paid'],
  link_opened: ['processing', 'pending', 'declined', 'paid', 'owes'],
  processing: ['pending', 'paid', 'declined', 'owes'],
  pending: ['paid', 'declined', 'owes'],
  declined: ['owes', 'processing', 'pending', 'paid'],
};

export function assertShareTransition(from: ParticipantStatus, to: ParticipantStatus): void {
  if (!ALLOWED[from]?.includes(to)) {
    throw new ApiError(409, 'SPLIT_STATE_INVALID', `A share that is ${from} cannot become ${to}.`);
  }
}

/** Shares PayPal may still move: a friend with an order out who has not finished paying. */
export const OPEN_SHARE_STATUSES: readonly ParticipantStatus[] = ['owes', 'link_opened', 'processing', 'pending', 'declined'];

export type MoveResult =
  | { moved: true; settled: boolean }
  | { moved: false; reason: 'same' | 'superseded' | 'missing' | 'invalid'; message?: string };

/**
 * Moves one share in a transaction, settling the split when it was the last
 * (plan Review Focus 5). Only the share's current PayPal order may move it:
 * an expired order's capture is somebody's money, but not this share's.
 * `ledger`, when given, is written to the share's paymentEvents in the same
 * transaction.
 */
export async function moveShare(
  ref: DocumentReference,
  move: { to: ParticipantStatus; paypalOrderId: string; captureId?: string | null; ledger?: { id: string } & Record<string, unknown> },
): Promise<MoveResult> {
  const splitRef = ref.parent.parent!;
  return ref.firestore.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return { moved: false, reason: 'missing' } as const;
    const person = snap.data() as ParticipantDoc;
    if (person.paypalOrderId !== move.paypalOrderId) return { moved: false, reason: 'superseded' } as const;
    if (person.status === move.to) return { moved: false, reason: 'same' } as const;
    try {
      assertShareTransition(person.status, move.to);
    } catch (err) {
      if (err instanceof ApiError) return { moved: false, reason: 'invalid', message: err.message } as const;
      throw err;
    }
    const settled = move.to === 'paid' ? await settleIfDone(tx, splitRef, { participantId: ref.id, status: 'paid' }) : false;
    tx.update(ref, {
      status: move.to,
      ...(move.captureId ? { paypalCaptureId: move.captureId } : {}),
      ...(move.to === 'paid' ? { paidAt: FieldValue.serverTimestamp() } : {}),
    });
    if (move.ledger) {
      tx.set(ref.collection('paymentEvents').doc(move.ledger.id), {
        ...move.ledger,
        receivedAt: FieldValue.serverTimestamp(),
        processedAt: FieldValue.serverTimestamp(),
      });
    }
    return { moved: true, settled };
  });
}
