import { describe, expect, it } from 'vitest';
import { allocate, type AllocateInput } from '../src/domain/allocate.js';
import { DEFAULT_RULES, type LineClaims, type Rules } from '../src/domain/split.js';

type L = { name: string; qty: number; total: number; claims: Record<string, number>; shared?: boolean };

function split(
  people: string[],
  lines: L[],
  opts: { service?: number; tip?: number; discount?: number; rules?: Partial<Rules> } = {},
): AllocateInput {
  const receiptLines = lines.map((l, i) => ({ id: `l${i}`, name: l.name, qty: l.qty, lineTotalMinor: l.total }));
  const claims: Record<string, LineClaims> = {};
  lines.forEach((l, i) => {
    claims[`l${i}`] = {
      claims: Object.entries(l.claims).map(([participantId, weight]) => ({ participantId, weight, source: 'organiser' })),
      shared: l.shared ?? false,
    };
  });
  const items = lines.reduce((t, l) => t + l.total, 0);
  const service = opts.service ?? 0;
  const tip = opts.tip ?? 0;
  const discount = opts.discount ?? 0;
  return {
    receipt: {
      lines: receiptLines, serviceChargeMinor: service, serviceChargeLabel: null, tipMinor: tip,
      discounts: discount ? [{ label: 'Discount', amountMinor: discount }] : [],
      printedTotalMinor: items + service + tip - discount, currency: 'GBP',
    },
    claims,
    rules: { ...DEFAULT_RULES, ...opts.rules },
    participants: people.map((id, joinOrder) => ({ id, joinOrder, isOrganiser: joinOrder === 0, name: id[0]!.toUpperCase() + id.slice(1) })),
  };
}

const finals = (input: AllocateInput) => {
  const r = allocate(input);
  if (!r.ok) throw new Error(JSON.stringify(r.problems));
  return Object.fromEntries(Object.entries(r.perParticipant).map(([id, b]) => [id, b.finalMinor]));
};

const problems = (input: AllocateInput) => {
  const r = allocate(input);
  if (r.ok) throw new Error('expected problems');
  return r.problems;
};

describe('allocate: edge cases', () => {
  it('one participant pays the whole bill', () => {
    expect(finals(split(['kemi'], [{ name: 'Ramen', qty: 1, total: 1500, claims: { kemi: 1 } }], { service: 188 })))
      .toEqual({ kemi: 1688 });
  });

  it('everyone on us except the organiser leaves the organiser with everything', () => {
    expect(finals(split(['kemi', 'amaka', 'josh'], [
      { name: 'Ramen', qty: 3, total: 4500, claims: { kemi: 1, amaka: 1, josh: 1 } },
    ], { service: 563, rules: { onUs: ['amaka', 'josh'] } }))).toEqual({ kemi: 5063, amaka: 0, josh: 0 });
  });

  it('a qty 7 line split 3:2:2', () => {
    // 2100 × 3/7 = 900, × 2/7 = 600 each. Exact, no leftover.
    expect(finals(split(['kemi', 'amaka', 'josh'], [
      { name: 'Gyoza x7', qty: 7, total: 2100, claims: { kemi: 3, amaka: 2, josh: 2 } },
    ]))).toEqual({ kemi: 900, amaka: 600, josh: 600 });
    // 1000 × 3/7 = 428.57, × 2/7 = 285.71 twice: floors 998, the two pennies
    // go to .71 then .71 (amaka, josh), not kemi's .57.
    expect(finals(split(['kemi', 'amaka', 'josh'], [
      { name: 'Gyoza x7', qty: 7, total: 1000, claims: { kemi: 3, amaka: 2, josh: 2 } },
    ]))).toEqual({ kemi: 428, amaka: 286, josh: 286 });
  });

  it('a 100% discount on a line nets to zero overall without anyone going negative', () => {
    const f = finals(split(['kemi', 'amaka'], [
      { name: 'Dessert', qty: 1, total: 600, claims: { amaka: 1 } },
      { name: 'Ramen', qty: 1, total: 1500, claims: { kemi: 1 } },
    ], { discount: 600 }));
    expect(f.kemi! + f.amaka!).toBe(1500);
    expect(Math.min(f.kemi!, f.amaka!)).toBeGreaterThanOrEqual(0);
  });

  it('a discount bigger than one person\'s items is clamped and the rest absorb it', () => {
    // Amaka opts out of service, so her 100p subtotal takes ~4.5% of a 3000p
    // discount (≈135p) and would go negative. She is clamped to 0.
    const f = finals(split(['kemi', 'amaka'], [
      { name: 'Ramen', qty: 1, total: 2100, claims: { kemi: 1 } },
      { name: 'Tea', qty: 1, total: 100, claims: { amaka: 1 } },
    ], { service: 1000, discount: 3000, rules: { serviceOptOut: ['amaka'] } }));
    expect(f).toEqual({ kemi: 200, amaka: 0 });
  });

  it('service opt-out by all but one puts the whole service charge on them', () => {
    const input = split(['kemi', 'amaka', 'josh'], [
      { name: 'Ramen', qty: 3, total: 4500, claims: { kemi: 1, amaka: 1, josh: 1 } },
    ], { service: 563, rules: { serviceOptOut: ['kemi', 'amaka'] } });
    expect(finals(input)).toEqual({ kemi: 1500, amaka: 1500, josh: 2063 });
  });

  it('a 1p line shared by five gives the penny to the organiser', () => {
    expect(finals(split(['kemi', 'amaka', 'josh', 'dan', 'sam'], [
      { name: 'Mint', qty: 1, total: 1, claims: { kemi: 1, amaka: 1, josh: 1, dan: 1, sam: 1 } },
    ]))).toEqual({ kemi: 1, amaka: 0, josh: 0, dan: 0, sam: 0 });
  });

  it('splits evenly when asked, whatever people had', () => {
    expect(finals(split(['kemi', 'amaka'], [
      { name: 'Steak', qty: 1, total: 3000, claims: { kemi: 1 } },
      { name: 'Soup', qty: 1, total: 600, claims: { amaka: 1 } },
    ], { service: 451, rules: { serviceMode: 'even' } }))).toEqual({ kemi: 3226, amaka: 825 });
  });
});

describe('allocate: problems instead of guesses', () => {
  it('flags an unclaimed line with the two one-tap options', () => {
    const [p] = problems(split(['kemi', 'amaka'], [{ name: 'Prawn crackers', qty: 1, total: 550, claims: {} }]));
    expect(p).toMatchObject({
      field: 'claims.l0', kind: 'unclaimed', blocking: true,
      question: 'Nobody claimed the prawn crackers',
      options: ['Share between all 2', 'Ask the group'],
    });
  });

  it('flags a line one person has only partly claimed', () => {
    const [p] = problems(split(['kemi', 'josh'], [{ name: 'Lager', qty: 3, total: 1650, claims: { josh: 2 } }]));
    expect(p).toMatchObject({ kind: 'unclaimed', question: 'Lager: 1 of 3 unclaimed' });
  });

  it('asks the group when two claimants fall short of the quantity', () => {
    // Spec Q1 (decided 2026-10-21): "Lager ×3: Josh 1, Dan 1" is a missing
    // lager, not a 1:1 share, until the organiser says otherwise.
    const [p] = problems(split(['josh', 'dan'], [{ name: 'Lager', qty: 3, total: 1650, claims: { josh: 1, dan: 1 } }]));
    expect(p).toMatchObject({
      field: 'claims.l0', kind: 'unclaimed', blocking: true,
      question: 'Lager: 1 of 3 unclaimed',
      options: ['Share between Josh and Dan', 'Ask the group'],
    });
  });

  it('splits a short line by weight once the organiser marks it shared', () => {
    expect(finals(split(['josh', 'dan'], [{ name: 'Lager', qty: 3, total: 1650, claims: { josh: 1, dan: 1 }, shared: true }])))
      .toEqual({ josh: 825, dan: 825 });
  });

  it('lets five people share one portion of prawn crackers', () => {
    expect(finals(split(['kemi', 'amaka', 'josh', 'dan', 'sam'], [
      { name: 'Prawn crackers', qty: 1, total: 550, claims: { kemi: 1, amaka: 1, josh: 1, dan: 1, sam: 1 } },
    ]))).toEqual({ kemi: 110, amaka: 110, josh: 110, dan: 110, sam: 110 });
  });

  it('refuses a receipt that does not add up instead of allocating it', () => {
    const input = split(['kemi'], [{ name: 'Ramen', qty: 1, total: 1500, claims: { kemi: 1 } }]);
    input.receipt.printedTotalMinor = 1600;
    expect(problems(input)[0]).toMatchObject({ kind: 'price_conflict', field: 'printedTotalMinor' });
  });

  it('refuses an unread price', () => {
    const input = split(['kemi'], [{ name: 'Ramen', qty: 1, total: 1500, claims: { kemi: 1 } }]);
    input.receipt.lines[0]!.lineTotalMinor = null;
    expect(problems(input)[0]).toMatchObject({ kind: 'missing', field: 'lines.l0.lineTotalMinor' });
  });

  it('refuses to put everyone on us', () => {
    const input = split(['kemi', 'amaka'], [{ name: 'Ramen', qty: 1, total: 1500, claims: { kemi: 1 } }], { rules: { onUs: ['kemi', 'amaka'] } });
    expect(problems(input).map((p) => p.field)).toContain('rules.onUs');
  });

  it('refuses a service charge nobody will cover', () => {
    const input = split(['kemi', 'amaka'], [{ name: 'Ramen', qty: 2, total: 3000, claims: { kemi: 1, amaka: 1 } }],
      { service: 375, rules: { serviceOptOut: ['kemi', 'amaka'] } });
    expect(problems(input).map((p) => p.field)).toContain('rules.serviceOptOut');
  });

  it('refuses claims and rules naming people who have left', () => {
    const input = split(['kemi'], [{ name: 'Ramen', qty: 1, total: 1500, claims: { kemi: 1, ghost: 1 } }], { rules: { onUs: ['ghost'] } });
    expect(problems(input).map((p) => p.field)).toEqual(expect.arrayContaining(['claims.l0', 'rules.onUs']));
  });

  it('returns every problem at once', () => {
    const input = split(['kemi', 'josh'], [
      { name: 'Prawn crackers', qty: 1, total: 550, claims: {} },
      { name: 'Lager', qty: 3, total: 1650, claims: { josh: 1 } },
    ]);
    expect(problems(input)).toHaveLength(2);
  });
});
