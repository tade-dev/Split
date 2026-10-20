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
