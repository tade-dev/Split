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
