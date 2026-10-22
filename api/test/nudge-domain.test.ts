import { describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase-admin/firestore';
import { nudgeDue, nudgeRefusal, openedRecently, snoozeUntil, type NudgeShare } from '../src/domain/nudge.js';

const HOUR = 60 * 60 * 1000;
const NOW = Date.UTC(2026, 9, 30, 12);
const ago = (hours: number) => Timestamp.fromMillis(NOW - hours * HOUR);

const share = (extra: Partial<NudgeShare> = {}): NudgeShare => ({
  name: 'Dan',
  status: 'link_opened',
  linkOpenedAt: ago(30),
  nudge: { count: 0, lastSentAt: null, snoozedUntil: null },
  ...extra,
});

describe('nudgeRefusal', () => {
  it('allows a share that is owed with nothing moving at PayPal', () => {
    for (const status of ['owes', 'link_opened', 'declined'] as const) {
      expect(nudgeRefusal(share({ status }), 'collecting')).toBeNull();
    }
  });

  it.each([
    ['paid', 'Dan has already paid.'],
    ['paid_cash', 'Dan has already paid.'],
    ['on_us', 'Dan has nothing to pay.'],
    ['processing', "PayPal is confirming Dan's payment right now."],
    ['pending', "PayPal is confirming Dan's payment right now."],
    ['claimed', 'Dan has nothing to pay yet.'],
  ] as const)('never for a %s share', (status, message) => {
    expect(nudgeRefusal(share({ status }), 'collecting')).toBe(message);
  });

  it('only once the links have gone out', () => {
    expect(nudgeRefusal(share(), 'claiming')).toMatch(/links have gone out/);
    expect(nudgeRefusal(share(), 'settled')).toMatch(/links have gone out/);
  });
});

describe('openedRecently', () => {
  it('is true for a link opened within the hour', () => {
    expect(openedRecently(share({ linkOpenedAt: ago(0.5) }), NOW)).toBe(true);
    expect(openedRecently(share({ linkOpenedAt: ago(2) }), NOW)).toBe(false);
    expect(openedRecently(share({ linkOpenedAt: null }), NOW)).toBe(false);
  });
});

describe('nudgeDue', () => {
  it('brings up the first reminder a day after the links went out', () => {
    expect(nudgeDue(share(), 'collecting', ago(23), NOW)).toBe(false);
    expect(nudgeDue(share(), 'collecting', ago(24), NOW)).toBe(true);
  });

  it('the second waits for three days and a day after the first', () => {
    const once = (lastHours: number) => share({ nudge: { count: 1, lastSentAt: ago(lastHours), snoozedUntil: null } });
    expect(nudgeDue(once(20), 'collecting', ago(48), NOW)).toBe(false);
    expect(nudgeDue(once(20), 'collecting', ago(72), NOW)).toBe(false);
    expect(nudgeDue(once(24), 'collecting', ago(72), NOW)).toBe(true);
  });

  it('stops after two', () => {
    expect(nudgeDue(share({ nudge: { count: 2, lastSentAt: ago(70) } }), 'collecting', ago(150), NOW)).toBe(false);
  });

  it('stays quiet while snoozed, then comes back', () => {
    expect(nudgeDue(share({ nudge: { count: 0, snoozedUntil: Timestamp.fromMillis(NOW + HOUR) } }), 'collecting', ago(30), NOW)).toBe(false);
    expect(nudgeDue(share({ nudge: { count: 0, snoozedUntil: Timestamp.fromMillis(NOW - HOUR) } }), 'collecting', ago(30), NOW)).toBe(true);
  });

  it('holds off while the friend opened their link within the hour', () => {
    expect(nudgeDue(share({ linkOpenedAt: ago(0.5) }), 'collecting', ago(30), NOW)).toBe(false);
  });

  it('copes with a share that has never had a nudge field, and needs a lock time', () => {
    expect(nudgeDue(share({ nudge: undefined }), 'collecting', ago(30), NOW)).toBe(true);
    expect(nudgeDue(share(), 'collecting', null, NOW)).toBe(false);
  });

  it('is never due on a paid share', () => {
    for (const status of ['paid', 'paid_cash', 'on_us'] as const) {
      expect(nudgeDue(share({ status }), 'collecting', ago(100), NOW)).toBe(false);
    }
  });

  it('snoozes until the same time tomorrow', () => {
    expect(snoozeUntil(NOW)).toBe(NOW + 24 * HOUR);
  });
});
