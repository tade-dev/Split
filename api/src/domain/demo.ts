import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { z } from 'zod';
import { lineIdFor } from './receipt.js';
import type { AllocParticipant, LineClaims, Receipt, Rules } from './split.js';

/**
 * The Little Bao House bill: the golden fixture in spec §3 and the demo split
 * a judge sees. One file feeds both the allocation test and the seed, so the
 * numbers on screen and the numbers under test cannot drift apart.
 */
const DEMO_PATH = fileURLToPath(new URL('../../../samples/demo-split.json', import.meta.url));

const minor = z.number().int().nonnegative();
const fileSchema = z.object({
  organiser: z.object({ displayName: z.string().min(1) }),
  title: z.string().min(1),
  merchant: z.string().min(1),
  receiptDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  people: z.array(z.string().min(1)).min(1),
  lines: z.array(z.object({
    name: z.string().min(1),
    qty: z.number().int().min(1),
    lineTotalMinor: minor,
    claims: z.record(z.string(), z.number().int().min(1)),
    /** Q1: split by weight even though the weights fall short of qty. */
    shared: z.boolean().default(false),
  })).min(1),
  serviceChargeMinor: minor,
  serviceChargeLabel: z.string().nullable(),
  tipMinor: minor,
  discounts: z.array(z.object({ label: z.string(), amountMinor: minor })),
  printedTotalMinor: minor,
  rules: z.object({
    serviceMode: z.enum(['proportional', 'even']),
    onUs: z.array(z.string()),
    onUsPaidBy: z.array(z.string()).nullable(),
    serviceOptOut: z.array(z.string()),
  }),
});

export type DemoParticipant = AllocParticipant & { name: string; colourIndex: number };

export type DemoSplit = {
  organiserName: string;
  title: string;
  merchant: string;
  receiptDate: string;
  receipt: Receipt;
  participants: DemoParticipant[];
  claims: Record<string, LineClaims>;
  rules: Rules;
};

/** Seed ids are the lower-cased first name: `kemi`, `amaka`. */
const personId = (name: string) => name.toLowerCase().replace(/[^a-z0-9]+/g, '-');

export function loadDemoSplit(path: string = DEMO_PATH): DemoSplit {
  const file = fileSchema.parse(JSON.parse(readFileSync(path, 'utf8')));
  const ids = new Map(file.people.map((name) => [name, personId(name)]));
  const id = (name: string) => {
    const found = ids.get(name);
    if (!found) throw new Error(`demo-split.json names ${name}, who is not in people`);
    return found;
  };

  const lines = file.lines.map((l, i) => ({ id: lineIdFor(l.name, i), name: l.name, qty: l.qty, lineTotalMinor: l.lineTotalMinor }));
  const claims: Record<string, LineClaims> = {};
  file.lines.forEach((l, i) => {
    claims[lines[i]!.id] = {
      claims: Object.entries(l.claims).map(([name, weight]) => ({ participantId: id(name), weight, source: 'organiser' as const })),
      shared: l.shared,
    };
  });

  return {
    organiserName: file.organiser.displayName,
    title: file.title,
    merchant: file.merchant,
    receiptDate: file.receiptDate,
    receipt: {
      lines,
      serviceChargeMinor: file.serviceChargeMinor,
      serviceChargeLabel: file.serviceChargeLabel,
      tipMinor: file.tipMinor,
      discounts: file.discounts,
      printedTotalMinor: file.printedTotalMinor,
      currency: 'GBP',
    },
    participants: file.people.map((name, joinOrder) => ({
      id: id(name), name, joinOrder, isOrganiser: name === file.organiser.displayName, colourIndex: joinOrder,
    })),
    claims,
    rules: {
      serviceMode: file.rules.serviceMode,
      onUs: file.rules.onUs.map(id),
      onUsPaidBy: file.rules.onUsPaidBy?.map(id) ?? null,
      serviceOptOut: file.rules.serviceOptOut.map(id),
    },
  };
}
