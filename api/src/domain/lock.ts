import { FieldValue, type DocumentReference, type Transaction } from 'firebase-admin/firestore';
import type { Ambiguity } from '../ai/schemas.js';
import type { Breakdown } from './split.js';
import { computeFor, type ParticipantDoc, type ParticipantStatus, type SplitDoc } from './splits.js';

export type LockPlan =
  | { ok: true; computed: ReturnType<typeof computeFor>; people: { id: string; shareMinor: number; status: ParticipantStatus }[]; owedMinor: number }
  | { ok: false; problems: Ambiguity[] };

/**
 * What locking writes, worked out without Firestore (plan Task 8). Every
 * share comes from one fresh allocate(), so the amounts friends pay are
 * exactly the ones on Breakdown. The organiser and on-us friends owe
 * nothing and count as settled (plan E1).
 */
export function lockPlan(split: Pick<SplitDoc, 'receipt' | 'claims' | 'rules'>, participants: ParticipantDoc[]): LockPlan {
  const computed = computeFor(split, participants);
  if (!computed.ok) return { ok: false, problems: computed.problems };
  const people = participants.map((p) => {
    const b = computed.perParticipant[p.id] as Breakdown;
    const status: ParticipantStatus = p.isOrganiser || split.rules.onUs.includes(p.id) || b.finalMinor === 0 ? 'on_us' : 'owes';
    return { id: p.id, shareMinor: b.finalMinor, status };
  });
  const owedMinor = people.filter((p) => p.status === 'owes').reduce((t, p) => t + p.shareMinor, 0);
  return { ok: true, computed, people, owedMinor };
}

/** Where a participant goes back to when the organiser unlocks. */
export function unlockedStatus(p: ParticipantDoc): ParticipantStatus {
  return p.claimedAt ? 'claimed' : 'invited';
}

/** Shares that need nothing more. A split whose shares all are is settled. */
export const SETTLED_STATUSES: readonly ParticipantStatus[] = ['paid', 'paid_cash', 'on_us'];

/**
 * Marks the split settled if this change leaves every share done (plan
 * Task 10). Reads every participant inside the caller's transaction, before
 * any of its writes, so two captures landing together cannot both miss the
 * last share or both write `settled`: the later one retries, sees the split
 * already settled, and writes nothing. Returns whether this call settled it.
 */
export async function settleIfDone(
  tx: Transaction,
  splitRef: DocumentReference,
  change: { participantId: string; status: ParticipantStatus },
): Promise<boolean> {
  const [split, people] = await Promise.all([tx.get(splitRef), tx.get(splitRef.collection('participants'))]);
  if (!split.exists || split.get('status') !== 'collecting' || people.empty) return false;
  const done = people.docs.every((doc) => {
    const status = doc.id === change.participantId ? change.status : (doc.get('status') as ParticipantStatus);
    return SETTLED_STATUSES.includes(status);
  });
  if (!done) return false;
  tx.update(splitRef, { status: 'settled', settledAt: FieldValue.serverTimestamp() });
  return true;
}
