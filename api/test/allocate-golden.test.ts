import { describe, expect, it } from 'vitest';
import { allocate } from '../src/domain/allocate.js';
import { loadDemoSplit } from '../src/domain/demo.js';

// Spec §3, verified by hand on 2026-10-20. These are exactly the figures on
// Home, Breakdown, FriendPay and Tracker. If this test fails, the screens are
// wrong, not the test.
describe('allocate: the Little Bao House bill', () => {
  const demo = loadDemoSplit();
  const result = allocate(demo);

  it('allocates without problems', () => {
    expect(result.ok).toBe(true);
  });

  it('reproduces every figure on the design screens', () => {
    if (!result.ok) throw new Error('expected ok');
    const p = result.perParticipant;
    const row = (id: string) => ({
      items: p[id]!.itemsMinor,
      onUs: p[id]!.sharedFromOnUsMinor,
      service: p[id]!.serviceMinor,
      final: p[id]!.finalMinor,
    });
    expect(row('kemi')).toEqual({ items: 2510, onUs: 728, service: 405, final: 3643 });
    expect(row('amaka')).toEqual({ items: 2260, onUs: 728, service: 373, final: 3361 });
    expect(row('josh')).toEqual({ items: 3310, onUs: 727, service: 505, final: 4542 });
    expect(row('dan')).toEqual({ items: 2760, onUs: 727, service: 436, final: 3923 });
    expect(row('sam')).toEqual({ items: 2910, onUs: -2910, service: 0, final: 0 });
    expect(result.totalMinor).toBe(15469);
  });

  it('owes Kemi £118.26', () => {
    if (!result.ok) throw new Error('expected ok');
    const owed = demo.participants
      .filter((x) => !x.isOrganiser)
      .reduce((t, x) => t + result.perParticipant[x.id]!.finalMinor, 0);
    expect(owed).toBe(11826);
  });

  it("labels Josh's portions the way Breakdown and Claim do", () => {
    if (!result.ok) throw new Error('expected ok');
    const josh = Object.fromEntries(result.perParticipant.josh!.lines.map((l) => [l.lineId, [l.minor, l.portionLabel]]));
    expect(josh['beef-ramen-4']).toEqual([1500, '']);
    expect(josh['lager-8']).toEqual([1100, '2 of 3']);
    expect(josh['pork-bao-1']).toEqual([600, '1 of 3']);
    expect(josh['prawn-crackers-0']).toEqual([110, 'share']);
  });
});
