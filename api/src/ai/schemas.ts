import { z } from 'zod';

// Trimmed from Sorted's ai/schemas.ts @902dc25 to the two shapes the copied
// code uses. Split's own schemas (spec §7) are added here as they are built.

export const ambiguitySchema = z.object({
  field: z.string().min(1),
  kind: z.enum([
    'missing',
    'unclear',
    'unknown_product',
    'price_conflict',
    'qty_unclear',
    /** Split: a receipt line, or part of one, that nobody has claimed. */
    'unclaimed',
  ]),
  /** Seller-facing, answerable in one tap. Never model-speak. */
  question: z.string().min(1).max(160),
  options: z.array(z.string()).default([]),
  blocking: z.boolean().default(true),
});
export type Ambiguity = z.infer<typeof ambiguitySchema>;

export const nudgeDraftSchema = z.object({
  text: z.string().max(500),
  recommendChannel: z.enum(['paypal_invoice', 'manual_copy']),
  /** An agent that knows when not to chase is more credible than one that always fires. */
  shouldSkip: z.boolean(),
  skipReason: z.string().max(200).nullable(),
});
export type NudgeDraft = z.infer<typeof nudgeDraftSchema>;

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'must be an ISO date (YYYY-MM-DD)');
/** Integer pence, never negative. Mirrors money.ts's Minor. */
const minor = z.number().int().nonnegative();

/** What the vision model reports from a receipt. It never computes a total. */
export const receiptExtractionSchema = z.object({
  merchant: z.string().max(80).nullable(),
  receiptDate: isoDate.nullable(),
  lines: z
    .array(
      z.object({
        name: z.string().min(1).max(80),
        qty: z.number().int().min(1).max(99),
        lineTotalMinor: minor.nullable(),
      }),
    )
    .max(60),
  serviceChargeMinor: minor.nullable(),
  serviceChargeLabel: z.string().max(60).nullable(),
  tipMinor: minor.nullable(),
  discounts: z.array(z.object({ label: z.string().min(1).max(60), amountMinor: minor })).max(10),
  printedTotalMinor: minor.nullable(),
  ambiguities: z.array(ambiguitySchema).default([]),
});
export type ReceiptExtraction = z.infer<typeof receiptExtractionSchema>;
