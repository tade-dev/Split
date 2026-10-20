import { describe, expect, it } from 'vitest';
import { MoneyError, allocateLargestRemainder } from '../src/domain/money.js';

const order = ['kemi', 'amaka', 'josh', 'dan'];

describe('allocateLargestRemainder', () => {
  it('splits in proportion and always sums to the total', () => {
    expect(allocateLargestRemainder(1650, { josh: 2, dan: 1 }, order)).toEqual({ josh: 1100, dan: 550 });
    const parts = allocateLargestRemainder(1000, { kemi: 1, amaka: 1, josh: 1 }, order);
    expect(Object.values(parts).reduce((a, b) => a + b, 0)).toBe(1000);
  });

  it('gives leftover pennies to the largest remainders first', () => {
    // 1719 by 3238/2988/4037/3487 floors to 1716; the three pennies go to
    // .938 (dan), .808 (kemi), .698 (josh). Amaka's .554 misses out.
    expect(allocateLargestRemainder(1719, { kemi: 3238, amaka: 2988, josh: 4037, dan: 3487 }, order))
      .toEqual({ kemi: 405, amaka: 373, josh: 505, dan: 436 });
  });

  it('breaks ties by the order given, so the organiser absorbs rounding', () => {
    expect(allocateLargestRemainder(2910, { kemi: 1, amaka: 1, josh: 1, dan: 1 }, order))
      .toEqual({ kemi: 728, amaka: 728, josh: 727, dan: 727 });
    expect(allocateLargestRemainder(1, { dan: 1, josh: 1 }, order)).toEqual({ josh: 1, dan: 0 });
  });

  it('never hands a penny to a zero weight', () => {
    expect(allocateLargestRemainder(5, { kemi: 0, amaka: 1, josh: 1 }, order)).toEqual({ kemi: 0, amaka: 3, josh: 2 });
  });

  it('stays exact where floats would not', () => {
    // 10,000,000p over 3 is 3,333,333.33…: a float multiply-then-divide can
    // land a penny out. BigInt cannot.
    expect(allocateLargestRemainder(10_000_000, { kemi: 1, amaka: 1, josh: 1 }, order))
      .toEqual({ kemi: 3_333_334, amaka: 3_333_333, josh: 3_333_333 });
  });

  it('refuses weights it cannot use', () => {
    expect(() => allocateLargestRemainder(100, { kemi: 0 }, order)).toThrow(MoneyError);
    expect(() => allocateLargestRemainder(100, { kemi: 1.5 }, order)).toThrow(MoneyError);
    expect(() => allocateLargestRemainder(100, { kemi: -1, amaka: 2 }, order)).toThrow(MoneyError);
    expect(() => allocateLargestRemainder(100, { stranger: 1 }, order)).toThrow(MoneyError);
    expect(() => allocateLargestRemainder(-1, { kemi: 1 }, order)).toThrow(MoneyError);
  });
});
