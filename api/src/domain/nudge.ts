import type { ParticipantStatus } from './splits.js';

/**
 * Nudge timings, in one place, from Sorted's lifecycle table: the first
 * reminder is due a day after the links went out, the second at three days,
 * and there is no third. A friend chased three times is being nagged.
 */
export const NUDGE_DUE_HOURS = [24, 72] as const;
export const MAX_NUDGES = NUDGE_DUE_HOURS.length;
/** Never two reminders within a day of each other, whatever the thresholds say. */
export const NUDGE_GAP_HOURS = 24;
/** "Remind me tomorrow". */
export const NUDGE_SNOOZE_HOURS = 24;
/** A friend who opened their link this recently is probably paying (spec §7.4). */
export const RECENTLY_OPENED_HOURS = 1;

const HOUR_MS = 60 * 60 * 1000;

export function millis(value: unknown): number | null {
  if (!value || typeof value !== 'object' || !('toMillis' in value)) return null;
  const ms = (value as { toMillis: () => number }).toMillis();
  return typeof ms === 'number' && !Number.isNaN(ms) ? ms : null;
}

export type NudgeState = {
  count?: number;
  lastSentAt?: unknown;
  snoozedUntil?: unknown;
  draftText?: unknown;
};

/** The parts of a share a nudge looks at. */
export type NudgeShare = {
  name: string;
  status: ParticipantStatus;
  linkOpenedAt?: unknown;
  nudge?: NudgeState | null;
};

/**
 * Why this share cannot be nudged, in the organiser's words, or null if it
 * can. Only a share that is owed with nothing moving at PayPal qualifies.
 */
export function nudgeRefusal(share: NudgeShare, splitStatus: string): string | null {
  if (splitStatus !== 'collecting') return 'Nudges are for a split whose links have gone out.';
  switch (share.status) {
    case 'owes':
    case 'link_opened':
    case 'declined':
      return null;
    case 'paid':
    case 'paid_cash':
      return `${share.name} has already paid.`;
    case 'on_us':
      return `${share.name} has nothing to pay.`;
    case 'processing':
    case 'pending':
      return `PayPal is confirming ${share.name}'s payment right now.`;
    default:
      return `${share.name} has nothing to pay yet.`;
  }
}

/**
 * Whether the model should be told to hold off: the friend opened their link
 * within the last hour, so they are probably paying. The organiser still
 * gets a correct draft if they want one.
 */
export function openedRecently(share: NudgeShare, nowMs: number): boolean {
  const opened = millis(share.linkOpenedAt);
  return opened !== null && nowMs - opened < RECENTLY_OPENED_HOURS * HOUR_MS;
}

/**
 * Whether Split should draft a reminder by itself, in the hourly sweep.
 * Counts from when the split was locked, which is when the links went out.
 */
export function nudgeDue(share: NudgeShare, splitStatus: string, lockedAt: unknown, nowMs: number): boolean {
  if (nudgeRefusal(share, splitStatus) !== null) return false;
  const sent = millis(lockedAt);
  if (sent === null) return false;
  const nudge = share.nudge ?? {};
  const count = typeof nudge.count === 'number' ? nudge.count : 0;
  if (count >= MAX_NUDGES) return false;
  if (nowMs - sent < NUDGE_DUE_HOURS[count]! * HOUR_MS) return false;
  const last = millis(nudge.lastSentAt);
  if (last !== null && nowMs - last < NUDGE_GAP_HOURS * HOUR_MS) return false;
  const snoozed = millis(nudge.snoozedUntil);
  if (snoozed !== null && nowMs < snoozed) return false;
  return !openedRecently(share, nowMs);
}

export function snoozeUntil(nowMs: number): number {
  return nowMs + NUDGE_SNOOZE_HOURS * HOUR_MS;
}
