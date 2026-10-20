import { Router, type RequestHandler } from 'express';
import { z } from 'zod';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import multer, { MulterError } from 'multer';
import { ApiError } from '../lib/errors.js';
import { requireOrganiser, type TokenVerifier } from '../lib/auth.js';
import { looksLikeUpload, visionMime } from '../lib/image_type.js';
import type { ChatTransport } from '../ai/client.js';
import { extractReceipt, toDraftReceipt } from '../ai/extract_receipt.js';
import { lineIdFor, receiptProblems } from '../domain/receipt.js';
import { assertStatus, computeFor, createSplit, readSplit, toApi } from '../domain/splits.js';
import type { Ambiguity } from '../ai/schemas.js';
import type { Receipt, Rules } from '../domain/split.js';

const MAX_IMAGES = 2;
const MAX_BYTES = 8 * 1024 * 1024;
const MAX_LINES = 60;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_BYTES, files: MAX_IMAGES },
  fileFilter: (_req, file, cb) => {
    if (!looksLikeUpload(file.mimetype)) {
      cb(new ApiError(400, 'VALIDATION_FAILED', `${file.mimetype} is not an image Split can read.`));
      return;
    }
    cb(null, true);
  },
}).array('images', MAX_IMAGES);

const receiveImages: RequestHandler = (req, res, next) => {
  upload(req, res, (err: unknown) => {
    if (err instanceof MulterError) {
      const message =
        err.code === 'LIMIT_FILE_SIZE'
          ? 'Each photo must be 8MB or smaller.'
          : err.code === 'LIMIT_FILE_COUNT' || err.code === 'LIMIT_UNEXPECTED_FILE'
            ? 'Send one photo, or two for a long bill.'
            : 'That upload could not be read.';
      next(new ApiError(400, 'VALIDATION_FAILED', message));
      return;
    }
    next(err as Error | undefined);
  });
};

const minor = z.number().int().nonnegative().max(100_000_00);
const lineName = z.string().trim().min(1).max(80);
const qty = z.number().int().min(1).max(99);

export const receiptPatchSchema = z
  .object({
    lines: z.array(z.object({ id: z.string().min(1), name: lineName.optional(), qty: qty.optional(), lineTotalMinor: minor.nullable().optional() }).strict()).max(MAX_LINES),
    addLines: z.array(z.object({ name: lineName, qty, lineTotalMinor: minor.nullable() }).strict()).max(MAX_LINES),
    removeLineIds: z.array(z.string().min(1)).max(MAX_LINES),
    serviceChargeMinor: minor,
    serviceChargeLabel: z.string().trim().max(60).nullable(),
    tipMinor: minor,
    discounts: z.array(z.object({ label: z.string().trim().min(1).max(60), amountMinor: minor }).strict()).max(10),
    printedTotalMinor: minor,
  })
  .partial()
  .strict()
  .refine((b) => Object.keys(b).length > 0, 'Send at least one change.');

export const rulesPatchSchema = z
  .object({
    serviceMode: z.enum(['proportional', 'even']),
    onUs: z.array(z.string().min(1)).max(20),
    onUsPaidBy: z.array(z.string().min(1)).min(1).max(20).nullable(),
    serviceOptOut: z.array(z.string().min(1)).max(20),
  })
  .partial()
  .strict()
  .refine((b) => Object.keys(b).length > 0, 'Send at least one change.');

/** The index after the highest one in use, so an added line never reuses a removed line's id. */
function nextLineIndex(receipt: Receipt): number {
  return receipt.lines.reduce((max, l) => Math.max(max, Number(/-(\d+)$/.exec(l.id)?.[1] ?? -1)), -1) + 1;
}

/**
 * Applies a receipt edit. Throws a 400 naming any line id that is not on the
 * bill, rather than silently ignoring an edit the organiser thinks they made.
 */
export function applyReceiptPatch(receipt: Receipt, patch: z.infer<typeof receiptPatchSchema>): { receipt: Receipt; touched: Set<string> } {
  const byId = new Map(receipt.lines.map((l) => [l.id, l]));
  const unknown = [...(patch.lines ?? []).map((l) => l.id), ...(patch.removeLineIds ?? [])].filter((id) => !byId.has(id));
  if (unknown.length > 0) {
    throw new ApiError(400, 'VALIDATION_FAILED', 'That line is no longer on the bill.', { lineIds: unknown });
  }
  const touched = new Set<string>([...(patch.removeLineIds ?? []), ...(patch.lines ?? []).map((l) => l.id)]);
  const edits = new Map((patch.lines ?? []).map((l) => [l.id, l]));
  const removed = new Set(patch.removeLineIds ?? []);
  const lines = receipt.lines
    .filter((l) => !removed.has(l.id))
    .map((l) => {
      const e = edits.get(l.id);
      return e
        ? { ...l, ...(e.name === undefined ? {} : { name: e.name }), ...(e.qty === undefined ? {} : { qty: e.qty }), ...(e.lineTotalMinor === undefined ? {} : { lineTotalMinor: e.lineTotalMinor }) }
        : l;
    });
  let next = nextLineIndex(receipt);
  for (const add of patch.addLines ?? []) lines.push({ id: lineIdFor(add.name, next++), ...add });
  if (lines.length > MAX_LINES) throw new ApiError(400, 'VALIDATION_FAILED', `A bill can have at most ${MAX_LINES} lines.`);
  return {
    touched,
    receipt: {
      ...receipt,
      lines,
      ...(patch.serviceChargeMinor === undefined ? {} : { serviceChargeMinor: patch.serviceChargeMinor }),
      ...(patch.serviceChargeLabel === undefined ? {} : { serviceChargeLabel: patch.serviceChargeLabel }),
      ...(patch.tipMinor === undefined ? {} : { tipMinor: patch.tipMinor }),
      ...(patch.discounts === undefined ? {} : { discounts: patch.discounts }),
      ...(patch.printedTotalMinor === undefined ? {} : { printedTotalMinor: patch.printedTotalMinor }),
    },
  };
}

/**
 * Blocking problems are re-derived from the numbers. The model's own notes
 * survive unless the organiser has since edited or removed the line they
 * were about, or a derived problem now covers the same field.
 */
export function nextAmbiguities(receipt: Receipt, previous: Ambiguity[], touched: Set<string>): Ambiguity[] {
  const derived = receiptProblems(receipt);
  const notes = previous.filter((a) => {
    if (a.blocking) return false;
    const line = /^lines\.([^.]+)/.exec(a.field)?.[1];
    if (line && touched.has(line)) return false;
    return !derived.some((d) => d.field === a.field);
  });
  return [...derived, ...notes];
}

export type SplitsDeps = { db: Firestore; verify: TokenVerifier; transport: ChatTransport; model: string };

export function splitsRouter(deps: SplitsDeps): Router {
  const router = Router();
  const auth = requireOrganiser(deps.verify);

  // Spec §4 endpoint 4. Synchronous, 3-10 s: the app shows Reading meanwhile.
  router.post('/splits/scan', auth, receiveImages, async (req, res, next) => {
    try {
      const files = (req.files ?? []) as Express.Multer.File[];
      if (files.length === 0) throw new ApiError(400, 'VALIDATION_FAILED', 'Attach a photo of the bill.');
      const images = files.map((f) => ({ buffer: f.buffer, mime: visionMime(f.buffer) }));
      const extraction = await extractReceipt(images, deps.transport, deps.model);
      const { receipt, ambiguities } = toDraftReceipt(extraction);
      const organiser = await deps.db.doc(`organisers/${req.organiserId}`).get();
      const name = organiser.get('displayName');
      const split = await createSplit(deps.db, req.organiserId!, {
        merchant: extraction.merchant,
        receiptDate: extraction.receiptDate,
        receipt,
        receiptAmbiguities: ambiguities,
        extractionModel: deps.model,
        sourceRef: null,
        organiserName: typeof name === 'string' && name.trim() ? name.trim() : 'You',
      });
      res.status(201).json({ split: toApi(split) });
    } catch (err) {
      next(err);
    }
  });

  // Spec §4 endpoint 5. Draft only: once friends are claiming, lines are what they claim against.
  router.patch('/splits/:splitId/receipt', auth, async (req, res, next) => {
    const parsed = receiptPatchSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      next(new ApiError(400, 'VALIDATION_FAILED', 'That change to the bill is not valid.', parsed.error.format()));
      return;
    }
    try {
      const split = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants } = await readSplit(tx, deps.db, req.organiserId!, String(req.params.splitId));
        assertStatus(split, ['draft'], 'edit the bill');
        const { receipt, touched } = applyReceiptPatch(split.receipt, parsed.data);
        const claims = Object.fromEntries(Object.entries(split.claims).filter(([id]) => receipt.lines.some((l) => l.id === id)));
        const next = { ...split, receipt, claims, receiptAmbiguities: nextAmbiguities(receipt, split.receiptAmbiguities, touched) };
        const computed = computeFor(next, participants);
        tx.update(ref, { receipt, claims, receiptAmbiguities: next.receiptAmbiguities, computed, updatedAt: FieldValue.serverTimestamp() });
        return { ...next, computed };
      });
      res.json({ split: toApi(split) });
    } catch (err) {
      next(err);
    }
  });

  // Spec §4 endpoint 12. Frozen from lock onwards.
  router.patch('/splits/:splitId/rules', auth, async (req, res, next) => {
    const parsed = rulesPatchSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      next(new ApiError(400, 'VALIDATION_FAILED', 'That rule is not valid.', parsed.error.format()));
      return;
    }
    try {
      const split = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants } = await readSplit(tx, deps.db, req.organiserId!, String(req.params.splitId));
        assertStatus(split, ['draft', 'claiming'], 'change the rules');
        const known = new Set(participants.map((p) => p.id));
        const named = [...(parsed.data.onUs ?? []), ...(parsed.data.onUsPaidBy ?? []), ...(parsed.data.serviceOptOut ?? [])];
        const strangers = named.filter((id) => !known.has(id));
        if (strangers.length > 0) {
          throw new ApiError(400, 'VALIDATION_FAILED', 'That rule names someone who is not in the group.', { participantIds: strangers });
        }
        const patch = parsed.data;
        const rules: Rules = {
          serviceMode: patch.serviceMode ?? split.rules.serviceMode,
          onUs: patch.onUs ?? split.rules.onUs,
          onUsPaidBy: patch.onUsPaidBy === undefined ? split.rules.onUsPaidBy : patch.onUsPaidBy,
          serviceOptOut: patch.serviceOptOut ?? split.rules.serviceOptOut,
        };
        const computed = computeFor({ ...split, rules }, participants);
        tx.update(ref, { rules, computed, updatedAt: FieldValue.serverTimestamp() });
        return { ...split, rules, computed };
      });
      res.json({ split: toApi(split) });
    } catch (err) {
      next(err);
    }
  });

  return router;
}
