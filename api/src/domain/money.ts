/** An amount in GBP minor units (pence). Always a non-negative integer. */
export type Minor = number;

export class MoneyError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'MoneyError';
  }
}

/** Optional £, optional comma thousands separators, 0 or 2 decimal places. */
const GBP_PATTERN = /^£?(\d{1,3}(?:,\d{3})*|\d+)(?:\.(\d{1,2}))?$/;

export function assertMinor(value: number): Minor {
  if (!Number.isInteger(value) || value < 0) {
    throw new MoneyError(`Expected a non-negative integer of pence, got ${value}`);
  }
  return value;
}

/**
 * Largest amount parseGbp accepts: £100,000. Nothing a small seller takes via
 * DMs comes close, and an unbounded digit run would otherwise overflow
 * Number.MAX_SAFE_INTEGER and silently lose pence.
 */
export const MAX_GBP_MINOR: Minor = 100_000_00;

export function parseGbp(input: string): Minor {
  const trimmed = input.trim();
  if (trimmed.startsWith('-')) {
    throw new MoneyError(`Amount cannot be negative: "${input}"`);
  }
  const match = GBP_PATTERN.exec(trimmed);
  if (!match) {
    throw new MoneyError(`Not a GBP amount: "${input}"`);
  }
  const pounds = Number(match[1]!.replaceAll(',', ''));
  const fraction = (match[2] ?? '').padEnd(2, '0');
  const minor = pounds * 100 + Number(fraction);
  if (!Number.isSafeInteger(minor) || minor > MAX_GBP_MINOR) {
    throw new MoneyError(`Amount is too large (max £100,000.00): "${input}"`);
  }
  return assertMinor(minor);
}

export function toPayPalValue(minor: Minor): string {
  assertMinor(minor);
  return (minor / 100).toFixed(2);
}

export function formatGbp(minor: Minor): string {
  assertMinor(minor);
  const [pounds, pence] = toPayPalValue(minor).split('.') as [string, string];
  const grouped = pounds.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return `£${grouped}.${pence}`;
}

export function sumMinor(values: Minor[]): Minor {
  return values.reduce<Minor>((total, value) => total + assertMinor(value), 0);
}

export function multiplyMinor(minor: Minor, qty: number): Minor {
  assertMinor(minor);
  if (!Number.isInteger(qty) || qty < 0) {
    throw new MoneyError(`Quantity must be a non-negative integer, got ${qty}`);
  }
  return minor * qty;
}

export function applyDelta(base: Minor, delta: number): Minor {
  assertMinor(base);
  if (!Number.isInteger(delta)) {
    throw new MoneyError(`Variant delta must be an integer of pence, got ${delta}`);
  }
  const result = base + delta;
  if (result < 0) {
    throw new MoneyError(
      `Variant delta ${delta} would take a ${base}p price negative`,
    );
  }
  return result;
}

/**
 * Splits `total` pence across parties in proportion to integer weights, so the
 * parts always sum to exactly `total`.
 *
 * Each party gets the floor of total × w / Σw, worked in BigInt so no float
 * ever touches money. The pennies left over go one each to the largest
 * fractional remainders. Ties go to whoever comes first in `order`; Split
 * passes the organiser first, then join order, so the person who paid the
 * bill absorbs the rounding.
 *
 * A party with weight 0 gets 0 and never a leftover penny: the leftover count
 * is always below the number of non-zero remainders.
 */
export function allocateLargestRemainder(
  total: Minor,
  weights: Readonly<Record<string, number>>,
  order: readonly string[],
): Record<string, Minor> {
  assertMinor(total);
  const ids = Object.keys(weights);
  let sum = 0n;
  for (const id of ids) {
    const w = weights[id]!;
    if (!Number.isSafeInteger(w) || w < 0) {
      throw new MoneyError(`Weight for ${id} must be a non-negative integer, got ${w}`);
    }
    if (!order.includes(id)) throw new MoneyError(`${id} has a weight but no place in the tie-break order`);
    sum += BigInt(w);
  }
  if (sum === 0n) throw new MoneyError('Cannot split an amount across weights that sum to zero');

  const t = BigInt(total);
  const out: Record<string, Minor> = {};
  const remainders: { id: string; rem: bigint; rank: number }[] = [];
  let given = 0n;
  for (const id of ids) {
    const scaled = t * BigInt(weights[id]!);
    const share = scaled / sum;
    out[id] = Number(share);
    given += share;
    remainders.push({ id, rem: scaled % sum, rank: order.indexOf(id) });
  }

  remainders.sort((a, b) => (a.rem === b.rem ? a.rank - b.rank : a.rem > b.rem ? -1 : 1));
  for (let i = 0; i < Number(t - given); i++) out[remainders[i]!.id]! += 1;
  return out;
}
