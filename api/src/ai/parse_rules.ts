import { rulesParseSchema, type RulesParse } from './schemas.js';
import { generateStructured, type ChatTransport } from './client.js';
import { allocate } from '../domain/allocate.js';
import { formatGbp, type Minor } from '../domain/money.js';
import type { AllocParticipant, LineClaims, Receipt, Rules } from '../domain/split.js';

/** Spec §7.3. */
export const RULES_SYSTEM = [
  'Turn what the organiser wrote into the bill-splitting rules for this group.',
  'Return the whole rule set: start from the current rules and change only what the message changes.',
  "onUs lists people whose share the group covers, as in 'it's Sam's birthday so his is on us'.",
  "onUsPaidBy lists who covers it when the message says so, as in 'Kemi and Josh will cover Sam'; otherwise null, meaning everyone else.",
  "serviceMode is 'even' when the service charge is split equally, 'proportional' when by what each person had, or null when the message does not say.",
  "serviceOptOut lists people who pay no service charge.",
  'Only use participant ids from the input. confirmationText is one short question asking the organiser to confirm, with no amounts.',
].join(' ');

export const RULES_JSON_SCHEMA: Record<string, unknown> = {
  type: 'object',
  additionalProperties: false,
  required: ['onUs', 'onUsPaidBy', 'serviceMode', 'serviceOptOut', 'confirmationText'],
  properties: {
    onUs: { type: 'array', items: { type: 'string' } },
    onUsPaidBy: { type: ['array', 'null'], items: { type: 'string' } },
    serviceMode: { type: ['string', 'null'], enum: ['proportional', 'even', null] },
    serviceOptOut: { type: 'array', items: { type: 'string' } },
    confirmationText: { type: 'string' },
  },
};

export type RulesContext = {
  receipt: Receipt;
  claims: Record<string, LineClaims>;
  rules: Rules;
  participants: (AllocParticipant & { name: string })[];
};

export async function parseRules(message: string, ctx: RulesContext, transport: ChatTransport, model: string): Promise<RulesParse> {
  const input = {
    participants: ctx.participants.map((p) => ({ id: p.id, name: p.name, isOrganiser: p.isOrganiser })),
    rules: ctx.rules,
    message,
  };
  return generateStructured(
    { schemaName: 'rules_parse', schema: rulesParseSchema, jsonSchema: RULES_JSON_SCHEMA, system: RULES_SYSTEM, text: JSON.stringify(input) },
    transport,
    model,
  );
}

export type RulesPreview = { rules: Rules; confirmationText: string; figureMinor: Minor | null };

/** Plan E6: said when the message changes nothing. Not an error. */
export const NOTHING_CAUGHT = "I didn't catch a rule in that. Try 'Sam's on us'.";

const sameSet = (a: string[], b: string[]) => a.length === b.length && a.every((x) => b.includes(x));
const samePaidBy = (a: string[] | null, b: string[] | null) => (a === null || b === null ? a === b : sameSet(a, b));
const sameRules = (a: Rules, b: Rules) =>
  a.serviceMode === b.serviceMode &&
  sameSet(a.onUs, b.onUs) &&
  samePaidBy(a.onUsPaidBy, b.onUsPaidBy) &&
  sameSet(a.serviceOptOut, b.serviceOptOut);

/** "Sam", "Sam and Dan", "Kemi, Josh and Dan". */
function listNames(names: string[]): string {
  return names.length <= 1 ? names.join('') : `${names.slice(0, -1).join(', ')} and ${names[names.length - 1]}`;
}
const possessive = (name: string) => `${name}${name.endsWith('s') ? "'" : "'s"}`;

/**
 * Code's check on what the model proposed (spec §7.3): ids that are in the
 * group, nobody both on us and covering, and the organiser never on us. The
 * figure on the confirm card comes from allocate(), never the model. Null
 * when nothing changed.
 */
export function toRulesPreview(raw: RulesParse, ctx: RulesContext): RulesPreview | null {
  const known = new Map(ctx.participants.map((p) => [p.id, p]));
  const ids = (list: string[]) => [...new Set(list.filter((id) => known.has(id)))];
  const onUs = ids(raw.onUs).filter((id) => !known.get(id)!.isOrganiser);
  const paidBy = raw.onUsPaidBy === null ? null : ids(raw.onUsPaidBy).filter((id) => !onUs.includes(id));
  const rules: Rules = {
    serviceMode: raw.serviceMode ?? ctx.rules.serviceMode,
    onUs,
    onUsPaidBy: paidBy && paidBy.length > 0 ? paidBy : null,
    serviceOptOut: ids(raw.serviceOptOut),
  };
  if (sameRules(rules, ctx.rules)) return null;

  const name = (id: string) => known.get(id)!.name;
  const sentences: string[] = [];
  let figureMinor: Minor | null = null;

  const onUsChanged = !sameSet(rules.onUs, ctx.rules.onUs) || !samePaidBy(rules.onUsPaidBy, ctx.rules.onUsPaidBy);
  if (onUsChanged && rules.onUs.length > 0) {
    const result = allocate({ receipt: ctx.receipt, claims: ctx.claims, rules, participants: ctx.participants });
    if (result.ok) {
      figureMinor = rules.onUs.reduce((t, id) => t - (result.perParticipant[id]?.sharedFromOnUsMinor ?? 0), 0) as Minor;
    }
    const who = rules.onUs.map(name);
    const subject = who.length === 1 ? `${possessive(who[0]!)} share` : `${listNames(who)}'s shares`;
    const amount = figureMinor === null ? '' : `, ${formatGbp(figureMinor)},`;
    const others = ctx.participants.filter((p) => !rules.onUs.includes(p.id)).length;
    const covered = rules.onUsPaidBy
      ? `paid by ${listNames(rules.onUsPaidBy.map(name))}`
      : `split between the other ${others}`;
    sentences.push(`${subject}${amount} ${covered}?`);
  } else if (onUsChanged) {
    sentences.push('Nobody on us, so everyone pays their own?');
  }
  if (rules.serviceMode !== ctx.rules.serviceMode) {
    sentences.push(rules.serviceMode === 'even' ? 'Split the service evenly?' : 'Split the service by what each person had?');
  }
  if (!sameSet(rules.serviceOptOut, ctx.rules.serviceOptOut)) {
    sentences.push(
      rules.serviceOptOut.length > 0 ? `Leave ${listNames(rules.serviceOptOut.map(name))} out of the service charge?` : 'Everyone pays the service charge?',
    );
  }
  return { rules, confirmationText: sentences.join(' '), figureMinor };
}
