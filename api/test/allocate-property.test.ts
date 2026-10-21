import fc from 'fast-check';
import { describe, expect, it } from 'vitest';
import { allocate, type AllocateInput } from '../src/domain/allocate.js';
import type { LineClaims, Rules } from '../src/domain/split.js';

/**
 * Random but valid splits: every line fully claimed, rules that leave someone
 * to pay, and a printed total that is what the receipt adds up to.
 */
const validSplit: fc.Arbitrary<AllocateInput> = fc
  .integer({ min: 1, max: 8 })
  .chain((n) => {
    const ids = Array.from({ length: n }, (_, i) => `p${i}`);
    const line = fc.record({
      qty: fc.integer({ min: 1, max: 7 }),
      lineTotalMinor: fc.oneof(fc.constant(1), fc.integer({ min: 0, max: 20_000 })),
      claimants: fc.subarray(ids, { minLength: 1 }),
      weightSeed: fc.array(fc.integer({ min: 1, max: 7 }), { minLength: 8, maxLength: 8 }),
      shared: fc.boolean(),
    });
    return fc.record({
      ids: fc.constant(ids),
      organiser: fc.integer({ min: 0, max: n - 1 }),
      lines: fc.array(line, { minLength: 1, maxLength: 12 }),
      service: fc.integer({ min: 0, max: 3000 }),
      tip: fc.integer({ min: 0, max: 1000 }),
      discountShare: fc.double({ min: 0, max: 1, noNaN: true }),
      serviceMode: fc.constantFrom('proportional' as const, 'even' as const),
      onUs: fc.subarray(ids, { maxLength: n - 1 }),
      paidBySeed: fc.option(fc.subarray(ids, { minLength: 1 })),
      optOutSeed: fc.subarray(ids),
    });
  })
  .map((g) => {
    const lines = g.lines.map((l, i) => ({ id: `line-${i}`, name: `Line ${i}`, qty: l.qty, lineTotalMinor: l.lineTotalMinor }));
    const claims: Record<string, LineClaims> = {};
    g.lines.forEach((l, i) => {
      const weights = l.claimants.map((_, k) => l.weightSeed[k]!);
      // Unless the line is shared, its weights must cover every unit, or it
      // is partly unclaimed (spec Q1). The last claimant takes up the slack.
      const short = l.qty - weights.reduce((t, w) => t + w, 0);
      if (!l.shared && short > 0) weights[weights.length - 1]! += short;
      claims[`line-${i}`] = {
        claims: l.claimants.map((id, k) => ({ participantId: id, weight: weights[k]!, source: 'ai' as const })),
        shared: l.shared,
      };
    });
    const payers = g.ids.filter((id) => !g.onUs.includes(id));
    const paidBy = g.paidBySeed?.filter((id) => payers.includes(id)) ?? null;
    const optOut = g.optOutSeed.filter((id) => payers.includes(id)).slice(0, payers.length - 1);
    const itemTotal = lines.reduce((t, l) => t + l.lineTotalMinor, 0);
    const discount = Math.floor(itemTotal * g.discountShare);
    const rules: Rules = {
      serviceMode: g.serviceMode,
      onUs: g.onUs,
      onUsPaidBy: paidBy && paidBy.length > 0 ? paidBy : null,
      serviceOptOut: optOut,
    };
    return {
      receipt: {
        lines,
        serviceChargeMinor: g.service,
        serviceChargeLabel: null,
        tipMinor: g.tip,
        discounts: discount > 0 ? [{ label: 'Voucher', amountMinor: discount }] : [],
        printedTotalMinor: itemTotal + g.service + g.tip - discount,
        currency: 'GBP' as const,
      },
      claims,
      rules,
      participants: g.ids.map((id, joinOrder) => ({ id, joinOrder, isOrganiser: joinOrder === g.organiser })),
    };
  });

const ok = (input: AllocateInput) => {
  const r = allocate(input);
  if (!r.ok) throw new Error(`unexpected problems: ${JSON.stringify(r.problems)}`);
  return r;
};

describe('allocate: properties over random valid splits', () => {
  it('always sums to the printed total', () => {
    fc.assert(fc.property(validSplit, (input) => {
      const r = ok(input);
      const sum = Object.values(r.perParticipant).reduce((t, b) => t + b.finalMinor, 0);
      expect(sum).toBe(input.receipt.printedTotalMinor);
      expect(r.totalMinor).toBe(input.receipt.printedTotalMinor);
    }), { numRuns: 500 });
  });

  it('never gives anyone a negative or fractional share', () => {
    fc.assert(fc.property(validSplit, (input) => {
      for (const b of Object.values(ok(input).perParticipant)) {
        expect(Number.isInteger(b.finalMinor)).toBe(true);
        expect(b.finalMinor).toBeGreaterThanOrEqual(0);
        for (const v of [b.itemsMinor, b.serviceMinor, b.tipMinor, b.discountMinor]) {
          expect(Number.isInteger(v) && v >= 0).toBe(true);
        }
      }
    }), { numRuns: 500 });
  });

  it('keeps every breakdown adding up to its own final', () => {
    fc.assert(fc.property(validSplit, (input) => {
      for (const b of Object.values(ok(input).perParticipant)) {
        expect(b.itemsMinor + b.sharedFromOnUsMinor + b.serviceMinor + b.tipMinor - b.discountMinor).toBe(b.finalMinor);
        expect(b.lines.reduce((t, l) => t + l.minor, 0)).toBe(b.itemsMinor);
      }
    }), { numRuns: 300 });
  });

  it('gives the same answer every time', () => {
    fc.assert(fc.property(validSplit, (input) => {
      expect(ok(structuredClone(input))).toEqual(ok(structuredClone(input)));
    }), { numRuns: 200 });
  });

  it('does not care what order claims on a line arrive in', () => {
    fc.assert(fc.property(validSplit, fc.integer(), (input, seed) => {
      const shuffled = structuredClone(input);
      for (const entry of Object.values(shuffled.claims)) {
        entry.claims = [...entry.claims].sort((a, b) =>
          ((a.participantId.charCodeAt(1) * 31 + seed) % 97) - ((b.participantId.charCodeAt(1) * 31 + seed) % 97));
        entry.claims.reverse();
      }
      expect(ok(shuffled).perParticipant).toEqual(ok(input).perParticipant);
    }), { numRuns: 300 });
  });

  it('charges nobody who is on us', () => {
    fc.assert(fc.property(validSplit, (input) => {
      const r = ok(input);
      for (const id of input.rules.onUs) expect(r.perParticipant[id]!.finalMinor).toBe(0);
    }), { numRuns: 300 });
  });
});
