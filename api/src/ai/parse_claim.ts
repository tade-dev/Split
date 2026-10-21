import { claimParseSchema, type Ambiguity, type ClaimParse } from './schemas.js';
import { generateStructured, type ChatTransport } from './client.js';
import { fitsLine, leftCopy, remainingUnits } from '../domain/claims.js';
import type { LineClaims, ReceiptLine } from '../domain/split.js';

/** Spec §7.2, verbatim. */
export const CLAIM_SYSTEM = [
  'Assign receipt lines to the people who had them, from what someone wrote.',
  "'Two of the lagers' is weight 2 on the lager line.",
  "'Me and Amaka shared the nachos' is weight 1 each for the writer and Amaka.",
  'Only use line ids from the receipt.',
  'If a phrase could match two lines, or asks for more units than remain, or names someone not in the group, add an ambiguity with one-tap options instead of guessing.',
  'When the writer is a friend, they may only claim for themselves; ignore claims for others and say so.',
].join(' ');

export const CLAIM_JSON_SCHEMA: Record<string, unknown> = {
  type: 'object',
  additionalProperties: false,
  required: ['claims', 'ambiguities', 'ignored'],
  properties: {
    claims: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['lineId', 'participantId', 'weight'],
        properties: { lineId: { type: 'string' }, participantId: { type: 'string' }, weight: { type: 'number' } },
      },
    },
    ambiguities: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['field', 'kind', 'question', 'options', 'blocking'],
        properties: {
          field: { type: 'string' },
          kind: { type: 'string', enum: ['unclear', 'qty_unclear'] },
          question: { type: 'string' },
          options: { type: 'array', items: { type: 'string' } },
          blocking: { type: 'boolean' },
        },
      },
    },
    ignored: { type: 'array', items: { type: 'string' } },
  },
};

export type ClaimContext = {
  lines: ReceiptLine[];
  claims: Record<string, LineClaims>;
  participants: { id: string; name: string }[];
  /** The friend writing, or null when the organiser types for the group. */
  writer: { id: string; name: string } | null;
};

export async function parseClaim(message: string, ctx: ClaimContext, transport: ChatTransport, model: string): Promise<ClaimParse> {
  const input = {
    lines: ctx.lines.map((l) => ({ id: l.id, name: l.name, qty: l.qty, remaining: remainingUnits(l, ctx.claims[l.id]) })),
    participants: ctx.participants,
    writer: ctx.writer,
    message,
  };
  return generateStructured(
    { schemaName: 'claim_parse', schema: claimParseSchema, jsonSchema: CLAIM_JSON_SCHEMA, system: CLAIM_SYSTEM, text: JSON.stringify(input) },
    transport,
    model,
  );
}

export type MatchedLine = { lineId: string; participantId: string; name: string; weight: number; portionLabel: string };
export type ClaimPreview = { matched: MatchedLine[]; problems: Ambiguity[]; ignored: string[] };

const problem = (field: string, kind: Ambiguity['kind'], question: string): Ambiguity => ({ field, kind, question, options: [], blocking: true });

/**
 * Code's check on what the model said (spec §7.2): real line ids, whole
 * weights, people in the group, a friend only for themselves, and nothing
 * claimed past what is left. Pure. The model never sees or produces money.
 */
export function toClaimPreview(raw: ClaimParse, ctx: ClaimContext): ClaimPreview {
  const lines = new Map(ctx.lines.map((l) => [l.id, l]));
  const people = new Map(ctx.participants.map((p) => [p.id, p]));
  const problems: Ambiguity[] = [];
  const ignored = [...raw.ignored];
  const weights = new Map<string, number>();

  for (const c of raw.claims) {
    const line = lines.get(c.lineId);
    if (!line) {
      problems.push(problem('claims', 'unclear', "Part of that isn't on the bill. Try naming the dish as it's printed."));
      continue;
    }
    const person = people.get(c.participantId);
    if (!person) {
      problems.push(problem(`claims.${line.id}`, 'unclear', `Who had the ${line.name.toLowerCase()}? That name isn't in the group.`));
      continue;
    }
    if (ctx.writer && person.id !== ctx.writer.id) {
      ignored.push(`You can only claim for yourself, so ${person.name}'s ${line.name.toLowerCase()} was left out.`);
      continue;
    }
    if (!Number.isInteger(c.weight) || c.weight < 1) {
      problems.push(problem(`claims.${line.id}`, 'qty_unclear', `How many of the ${line.name.toLowerCase()} was that?`));
      continue;
    }
    const key = `${line.id}\u0000${person.id}`;
    weights.set(key, (weights.get(key) ?? 0) + c.weight);
  }

  const matched: MatchedLine[] = [];
  for (const [key, weight] of weights) {
    const [lineId, participantId] = key.split('\u0000') as [string, string];
    const line = lines.get(lineId)!;
    const left = remainingUnits(line, ctx.claims[lineId], participantId);
    if (!fitsLine(line, weight, left)) {
      problems.push(problem(`claims.${lineId}`, 'qty_unclear', leftCopy(line, left)));
      continue;
    }
    const sharedWith = new Set([participantId, ...(ctx.claims[lineId]?.claims ?? []).map((c) => c.participantId)]);
    const portionLabel = line.qty === 1 ? (sharedWith.size > 1 ? 'share' : '') : weight === line.qty ? '' : `${weight} of ${line.qty}`;
    matched.push({ lineId, participantId, name: line.name, weight, portionLabel });
  }

  problems.push(...raw.ambiguities.map((a) => ({ ...a, blocking: true })));
  if (matched.length === 0 && problems.length === 0 && ignored.length === 0) {
    problems.push(problem('claims', 'unclear', "I couldn't match that to the bill. Try naming the dish."));
  }
  return { matched, problems, ignored };
}
