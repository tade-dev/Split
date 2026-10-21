import type { Ambiguity } from '../ai/schemas.js';
import type { Claim, LineClaims, ReceiptLine } from './split.js';

/** Who is writing claims. A friend writes only their own; the organiser writes anyone's. */
export type ClaimActor = { kind: 'friend'; participantId: string } | { kind: 'organiser' };

/**
 * One person's whole claim, as confirmed. It replaces everything they claimed
 * before, so a friend who confirms twice ends up with the second answer only.
 */
export type ClaimWrite = {
  participantId: string;
  items: { lineId: string; weight: number }[];
  /** Organiser only: lines to mark shared (true) or unmark (false). */
  shared?: Record<string, boolean>;
};

export type ApplyClaimsResult =
  | { ok: true; claims: Record<string, LineClaims> }
  | { ok: false; problems: Ambiguity[] };

/**
 * Week A stored `claims[lineId]` as a bare `Claim[]`. Week B wraps it as
 * `{ claims, shared }`. Docs are normalised on read, so old ones, the seeded
 * demo included, need no backfill.
 */
export function normaliseClaims(raw: Record<string, Claim[] | LineClaims> | null | undefined): Record<string, LineClaims> {
  const out: Record<string, LineClaims> = {};
  for (const [lineId, value] of Object.entries(raw ?? {})) {
    out[lineId] = Array.isArray(value)
      ? { claims: value, shared: false }
      : { claims: value?.claims ?? [], shared: value?.shared === true };
  }
  return out;
}

/** Units of `line` nobody but `except` has claimed yet. Never below 0. */
export function remainingUnits(line: ReceiptLine, lineClaims: LineClaims | undefined, except?: string): number {
  const taken = (lineClaims?.claims ?? [])
    .filter((c) => c.participantId !== except)
    .reduce((t, c) => t + c.weight, 0);
  return Math.max(0, line.qty - taken);
}

/**
 * Replaces one participant's claims. Pure: it returns the new claims map or
 * the problems, and never touches the input.
 *
 * A claim has to fit in what is left on the line: "2 lagers" when 1 is left
 * is a mistake, and two friends racing for the last lager cannot both have
 * it. The one exception is a single dish (qty 1), which anyone may join,
 * because that is how people share the prawn crackers.
 */
export function applyClaims(
  current: Record<string, LineClaims>,
  incoming: ClaimWrite,
  opts: { actor: ClaimActor; lines: ReceiptLine[] },
): ApplyClaimsResult {
  const { actor, lines } = opts;
  const problems: Ambiguity[] = [];
  if (actor.kind === 'friend' && actor.participantId !== incoming.participantId) {
    problems.push(problem('claims', 'unclear', 'You can only claim for yourself.'));
  }
  if (actor.kind === 'friend' && incoming.shared && Object.keys(incoming.shared).length > 0) {
    problems.push(problem('claims', 'unclear', 'Only the organiser can mark a line as shared.'));
  }
  if (problems.length > 0) return { ok: false, problems };

  const byId = new Map(lines.map((l) => [l.id, l]));
  const wanted = new Map<string, number>();
  for (const item of incoming.items) {
    const line = byId.get(item.lineId);
    if (!line) {
      problems.push(problem(`claims.${item.lineId}`, 'unclear', 'That item is no longer on the bill.'));
      continue;
    }
    if (!Number.isSafeInteger(item.weight) || item.weight < 1) {
      problems.push(problem(`claims.${line.id}`, 'qty_unclear', `How many of the ${line.name.toLowerCase()} did you have?`));
      continue;
    }
    wanted.set(line.id, (wanted.get(line.id) ?? 0) + item.weight);
  }
  for (const [lineId, weight] of wanted) {
    const line = byId.get(lineId)!;
    const left = remainingUnits(line, current[lineId], incoming.participantId);
    if (!fitsLine(line, weight, left)) {
      problems.push(problem(`claims.${lineId}`, 'qty_unclear', leftCopy(line, left)));
    }
  }
  for (const lineId of Object.keys(incoming.shared ?? {})) {
    if (!byId.has(lineId)) problems.push(problem(`claims.${lineId}`, 'unclear', 'That item is no longer on the bill.'));
  }
  if (problems.length > 0) return { ok: false, problems };

  const source: Claim['source'] = actor.kind;
  const next: Record<string, LineClaims> = {};
  for (const lineId of new Set([...Object.keys(current), ...wanted.keys()])) {
    const kept = (current[lineId]?.claims ?? []).filter((c) => c.participantId !== incoming.participantId);
    const weight = wanted.get(lineId);
    next[lineId] = {
      claims: weight ? [...kept, { participantId: incoming.participantId, weight, source }] : kept,
      shared: current[lineId]?.shared ?? false,
    };
  }
  for (const [lineId, shared] of Object.entries(incoming.shared ?? {})) {
    next[lineId] = { claims: next[lineId]?.claims ?? [], shared };
  }
  return { ok: true, claims: next };
}

/** Spec §7.2: no unit claimed twice, except a single dish people share. */
export function fitsLine(line: ReceiptLine, weight: number, left: number): boolean {
  return line.qty === 1 ? weight === 1 : weight <= left;
}

/**
 * Sets one person's weight on one line, leaving their other lines alone.
 * The organiser's claim chat ("Josh had the lager") works line by line.
 */
export function setLineClaim(
  current: Record<string, LineClaims>,
  lineId: string,
  participantId: string,
  weight: number,
  source: Claim['source'],
): Record<string, LineClaims> {
  const entry = current[lineId] ?? { claims: [], shared: false };
  const kept = entry.claims.filter((c) => c.participantId !== participantId);
  return { ...current, [lineId]: { ...entry, claims: weight > 0 ? [...kept, { participantId, weight, source }] : kept } };
}

/** "Only 1 lager is left to claim". */
export function leftCopy(line: ReceiptLine, left: number): string {
  const name = line.name.toLowerCase();
  if (left === 0) return `All of the ${name} has been claimed`;
  return left === 1 ? `Only 1 ${name} is left to claim` : `Only ${left} ${name} are left to claim`;
}

function problem(field: string, kind: Ambiguity['kind'], question: string): Ambiguity {
  return { field, kind, question, options: [], blocking: true };
}
