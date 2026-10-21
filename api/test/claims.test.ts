import { describe, expect, it } from 'vitest';
import { applyClaims, normaliseClaims, remainingUnits } from '../src/domain/claims.js';
import type { LineClaims, ReceiptLine } from '../src/domain/split.js';

const lager: ReceiptLine = { id: 'lager-8', name: 'Lager', qty: 3, lineTotalMinor: 1650 };
const crackers: ReceiptLine = { id: 'prawn-crackers-0', name: 'Prawn crackers', qty: 1, lineTotalMinor: 550 };
const lines = [crackers, lager];
const josh = { kind: 'friend' as const, participantId: 'josh' };

describe('remainingUnits', () => {
  it('is the whole quantity on a fresh line', () => {
    expect(remainingUnits(lager, undefined)).toBe(3);
  });

  it('leaves out the person asking, so they can change their own claim', () => {
    const entry: LineClaims = { claims: [{ participantId: 'josh', weight: 2, source: 'friend' }], shared: false };
    expect(remainingUnits(lager, entry)).toBe(1);
    expect(remainingUnits(lager, entry, 'josh')).toBe(3);
  });
});

describe('applyClaims', () => {
  it('refuses a weight above what is left on the line', () => {
    const current = { [lager.id]: { claims: [{ participantId: 'dan', weight: 2, source: 'friend' as const }], shared: false } };
    const r = applyClaims(current, { participantId: 'josh', items: [{ lineId: lager.id, weight: 2 }] }, { actor: josh, lines });
    expect(r).toEqual({
      ok: false,
      problems: [{ field: `claims.${lager.id}`, kind: 'qty_unclear', question: 'Only 1 lager is left to claim', options: [], blocking: true }],
    });
  });

  it('always lets someone share a single dish', () => {
    const current = { [crackers.id]: { claims: [{ participantId: 'kemi', weight: 1, source: 'friend' as const }], shared: false } };
    const r = applyClaims(current, { participantId: 'josh', items: [{ lineId: crackers.id, weight: 1 }] }, { actor: josh, lines });
    expect(r.ok && r.claims[crackers.id]!.claims.map((c) => c.participantId)).toEqual(['kemi', 'josh']);
  });

  it("replaces a friend's first confirm with their second", () => {
    const first = applyClaims({}, { participantId: 'josh', items: [{ lineId: lager.id, weight: 2 }] }, { actor: josh, lines });
    if (!first.ok) throw new Error('expected ok');
    const second = applyClaims(first.claims, { participantId: 'josh', items: [{ lineId: crackers.id, weight: 1 }] }, { actor: josh, lines });
    expect(second).toEqual({
      ok: true,
      claims: {
        [lager.id]: { claims: [], shared: false },
        [crackers.id]: { claims: [{ participantId: 'josh', weight: 1, source: 'friend' }], shared: false },
      },
    });
  });

  it("keeps everyone else's claims", () => {
    const current = { [lager.id]: { claims: [{ participantId: 'dan', weight: 1, source: 'organiser' as const }], shared: true } };
    const r = applyClaims(current, { participantId: 'josh', items: [{ lineId: lager.id, weight: 2 }] }, { actor: josh, lines });
    expect(r).toEqual({
      ok: true,
      claims: {
        [lager.id]: {
          claims: [
            { participantId: 'dan', weight: 1, source: 'organiser' },
            { participantId: 'josh', weight: 2, source: 'friend' },
          ],
          shared: true,
        },
      },
    });
  });

  it('does not change the map it was given', () => {
    const current = { [lager.id]: { claims: [{ participantId: 'dan', weight: 1, source: 'friend' as const }], shared: false } };
    const before = structuredClone(current);
    applyClaims(current, { participantId: 'josh', items: [{ lineId: lager.id, weight: 1 }] }, { actor: josh, lines });
    expect(current).toEqual(before);
  });

  it('stops a friend claiming for someone else or marking a line shared', () => {
    const forDan = applyClaims({}, { participantId: 'dan', items: [{ lineId: lager.id, weight: 1 }] }, { actor: josh, lines });
    expect(forDan.ok).toBe(false);
    const shared = applyClaims({}, { participantId: 'josh', items: [], shared: { [lager.id]: true } }, { actor: josh, lines });
    expect(shared.ok).toBe(false);
  });

  it('lets the organiser claim for anyone and mark a line shared', () => {
    const r = applyClaims(
      {},
      { participantId: 'dan', items: [{ lineId: lager.id, weight: 1 }], shared: { [lager.id]: true } },
      { actor: { kind: 'organiser' }, lines },
    );
    expect(r).toEqual({
      ok: true,
      claims: { [lager.id]: { claims: [{ participantId: 'dan', weight: 1, source: 'organiser' }], shared: true } },
    });
  });

  it('refuses a line that is not on the bill and a weight below 1', () => {
    const r = applyClaims({}, { participantId: 'josh', items: [{ lineId: 'gone', weight: 1 }, { lineId: lager.id, weight: 0 }] }, { actor: josh, lines });
    expect(r.ok ? [] : r.problems.map((p) => p.field)).toEqual(['claims.gone', `claims.${lager.id}`]);
  });
});

describe('normaliseClaims', () => {
  it("wraps Week A's bare Claim[] as an unshared line", () => {
    const week = { [lager.id]: [{ participantId: 'josh', weight: 2, source: 'ai' as const }] };
    expect(normaliseClaims(week)).toEqual({ [lager.id]: { claims: week[lager.id], shared: false } });
  });

  it('passes the new shape through and treats a missing map as empty', () => {
    const entry: LineClaims = { claims: [], shared: true };
    expect(normaliseClaims({ [lager.id]: entry })).toEqual({ [lager.id]: entry });
    expect(normaliseClaims(undefined)).toEqual({});
  });
});
