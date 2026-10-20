import type { Ambiguity } from '../ai/schemas.js';
import { allocateLargestRemainder, type Minor } from './money.js';
import { receiptProblems } from './receipt.js';
import type {
  AllocParticipant,
  Allocation,
  Breakdown,
  BreakdownLine,
  Claim,
  Receipt,
  Rules,
} from './split.js';

export type AllocateInput = {
  receipt: Receipt;
  claims: Record<string, Claim[]>;
  rules: Rules;
  participants: AllocParticipant[];
};

/** A bug in this file, never a user error. Callers let it surface as a 500. */
export class AllocationInvariantError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AllocationInvariantError';
  }
}

/** Organiser first, then join order. The tie-break for every leftover penny. */
export function tieOrder(participants: AllocParticipant[]): string[] {
  return [...participants]
    .sort((a, b) =>
      a.isOrganiser === b.isOrganiser ? a.joinOrder - b.joinOrder : a.isOrganiser ? -1 : 1,
    )
    .map((p) => p.id);
}

const sumOf = (ids: string[], by: Record<string, number>) =>
  ids.reduce((t, id) => t + (by[id] ?? 0), 0);

function weightsFor(ids: string[], by: Record<string, number> | null): Record<string, number> {
  const w: Record<string, number> = {};
  for (const id of ids) w[id] = by ? (by[id] ?? 0) : 1;
  return w;
}

/**
 * Splits `amount` over `ids`, by `by` when it has any weight among them,
 * otherwise evenly. Proportional-by-nothing is how a bill where every eligible
 * payer had £0 of items would otherwise divide by zero.
 */
function spread(amount: Minor, ids: string[], by: Record<string, number> | null, order: string[]) {
  if (amount === 0 || ids.length === 0) return {} as Record<string, Minor>;
  const proportional = by !== null && sumOf(ids, by) > 0;
  return allocateLargestRemainder(amount, weightsFor(ids, proportional ? by : null), order);
}

/**
 * Turns a receipt, who had what and the group's rules into each person's
 * share, to the penny. Pure: no I/O, no clock, no randomness.
 *
 * Stages run in the spec's order (§3): validate, items, on us, service, tip
 * and discounts, invariant. Every problem found is returned at once, so the
 * organiser sees the whole list rather than one at a time.
 */
export function allocate(input: AllocateInput): Allocation {
  const { receipt, claims, rules, participants } = input;
  const order = tieOrder(participants);
  const known = new Set(order);
  const problems: Ambiguity[] = [...receiptProblems(receipt)];

  // ── 1. Validate ─────────────────────────────────────────────────────────
  const lineIds = new Set(receipt.lines.map((l) => l.id));
  for (const lineId of Object.keys(claims)) {
    if (!lineIds.has(lineId) && (claims[lineId]?.length ?? 0) > 0) {
      problems.push(blocking(`claims.${lineId}`, 'unclear', 'A claim points at a line that is no longer on the bill.'));
    }
  }

  // Per line: participantId -> summed weight. A person claiming one line twice
  // ("a lager" then "another lager") is one claimant with weight 2.
  const weightsByLine = new Map<string, Record<string, number>>();
  for (const line of receipt.lines) {
    const merged: Record<string, number> = {};
    for (const claim of claims[line.id] ?? []) {
      if (!known.has(claim.participantId)) {
        problems.push(blocking(`claims.${line.id}`, 'unclear', `The ${line.name} is claimed by someone who is no longer in the group.`));
        continue;
      }
      if (!Number.isSafeInteger(claim.weight) || claim.weight < 1) {
        problems.push(blocking(`claims.${line.id}`, 'qty_unclear', `How many of the ${line.name} did they have?`));
        continue;
      }
      merged[claim.participantId] = (merged[claim.participantId] ?? 0) + claim.weight;
    }
    const claimants = Object.keys(merged).length;
    const units = sumOf(Object.keys(merged), merged);
    if (claimants === 0) {
      problems.push({
        field: `claims.${line.id}`,
        kind: 'unclaimed',
        question: `Nobody claimed the ${line.name.toLowerCase()}`,
        options: [`Share between all ${participants.length}`, 'Ask the group'],
        blocking: true,
      });
    } else if (claimants === 1 && units < line.qty) {
      problems.push({
        field: `claims.${line.id}`,
        kind: 'unclaimed',
        question: `${line.name}: ${line.qty - units} of ${line.qty} unclaimed`,
        options: ['Ask the group'],
        blocking: true,
      });
    }
    weightsByLine.set(line.id, merged);
  }

  for (const [field, ids] of [
    ['rules.onUs', rules.onUs],
    ['rules.onUsPaidBy', rules.onUsPaidBy ?? []],
    ['rules.serviceOptOut', rules.serviceOptOut],
  ] as const) {
    if (ids.some((id) => !known.has(id))) {
      problems.push(blocking(field, 'unclear', 'A rule names someone who is no longer in the group.'));
    }
  }

  const onUs = new Set(rules.onUs.filter((id) => known.has(id)));
  const payers = order.filter((id) => !onUs.has(id));
  if (payers.length === 0) {
    problems.push(blocking('rules.onUs', 'unclear', 'Everyone is on us, so nobody is left to pay.'));
  }
  const coverers = (rules.onUsPaidBy ?? payers).filter((id) => known.has(id) && !onUs.has(id));
  if (onUs.size > 0 && payers.length > 0 && coverers.length === 0) {
    problems.push(blocking('rules.onUsPaidBy', 'unclear', 'Nobody is left to cover the on-us share.'));
  }
  const eligible = payers.filter((id) => !rules.serviceOptOut.includes(id));
  if (receipt.serviceChargeMinor + receipt.tipMinor > 0 && payers.length > 0 && eligible.length === 0) {
    problems.push(blocking('rules.serviceOptOut', 'unclear', 'Everyone has opted out of the service charge. Someone has to cover it.'));
  }

  if (problems.length > 0) return { ok: false, problems };

  // ── 2. Items ────────────────────────────────────────────────────────────
  const items: Record<string, number> = Object.fromEntries(order.map((id) => [id, 0]));
  const lines: Record<string, BreakdownLine[]> = Object.fromEntries(order.map((id) => [id, []]));
  for (const line of receipt.lines) {
    const merged = weightsByLine.get(line.id)!;
    const ids = Object.keys(merged);
    const units = sumOf(ids, merged);
    const parts = allocateLargestRemainder(line.lineTotalMinor!, merged, order);
    for (const id of order) {
      if (!(id in parts)) continue;
      items[id]! += parts[id]!;
      lines[id]!.push({ lineId: line.id, minor: parts[id]!, portionLabel: portionLabel(merged[id]!, ids.length, units, line.qty) });
    }
  }

  // ── 3. On us ────────────────────────────────────────────────────────────
  const shared: Record<string, number> = Object.fromEntries(order.map((id) => [id, 0]));
  for (const id of order) {
    if (!onUs.has(id)) continue;
    const parts = spread(items[id]!, coverers, null, order);
    for (const [to, minor] of Object.entries(parts)) shared[to]! += minor;
    shared[id]! -= items[id]!;
  }
  const subtotal: Record<string, number> = Object.fromEntries(
    order.map((id) => [id, items[id]! + shared[id]!]),
  );

  // ── 4. Service charge, and 5. tip, which follows the service mode ───────
  const by = rules.serviceMode === 'proportional' ? subtotal : null;
  const service = spread(receipt.serviceChargeMinor, eligible, by, order);
  const tip = spread(receipt.tipMinor, eligible, by, order);

  // ── 5. Discounts, by what each payer had, never taking anyone below 0 ───
  const discountTotal = receipt.discounts.reduce((t, d) => t + d.amountMinor, 0);
  const discount: Record<string, number> = { ...spread(discountTotal, payers, subtotal, order) };
  const final: Record<string, number> = {};
  for (const id of order) {
    discount[id] ??= 0;
    final[id] = subtotal[id]! + (service[id] ?? 0) + (tip[id] ?? 0) - discount[id]!;
  }
  for (let pass = 0; order.some((id) => final[id]! < 0); pass++) {
    if (pass > order.length) throw new AllocationInvariantError('discount clamp did not settle');
    let excess = 0;
    for (const id of order) {
      if (final[id]! < 0) {
        excess += -final[id]!;
        discount[id]! += final[id]!;
        final[id] = 0;
      }
    }
    const takers = order.filter((id) => final[id]! > 0);
    if (takers.length === 0) throw new AllocationInvariantError('discount exceeds the whole bill');
    const extra = allocateLargestRemainder(excess, weightsFor(takers, final), order);
    for (const [id, minor] of Object.entries(extra)) {
      discount[id]! += minor;
      final[id]! -= minor;
    }
  }

  // ── 6. Invariant ────────────────────────────────────────────────────────
  const total = sumOf(order, final);
  if (total !== receipt.printedTotalMinor) {
    throw new AllocationInvariantError(`shares sum to ${total}, the bill says ${receipt.printedTotalMinor}`);
  }

  const perParticipant: Record<string, Breakdown> = {};
  for (const id of order) {
    perParticipant[id] = {
      itemsMinor: items[id]!,
      sharedFromOnUsMinor: shared[id]!,
      serviceMinor: service[id] ?? 0,
      tipMinor: tip[id] ?? 0,
      discountMinor: discount[id]!,
      finalMinor: final[id]!,
      lines: lines[id]!,
    };
  }
  return { ok: true, perParticipant, totalMinor: total };
}

/** "" for a whole line, "2 of 3" for some of the units, "share" for a shared item. */
function portionLabel(weight: number, claimants: number, units: number, qty: number): string {
  if (claimants === 1) return '';
  if (units === qty) return `${weight} of ${qty}`;
  return 'share';
}

function blocking(field: string, kind: Ambiguity['kind'], question: string): Ambiguity {
  return { field, kind, question, options: [], blocking: true };
}
