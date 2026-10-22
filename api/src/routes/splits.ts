import { Router, type RequestHandler } from 'express';
import { z } from 'zod';
import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
import multer, { MulterError } from 'multer';
import { ApiError } from '../lib/errors.js';
import { requireOrganiser, type TokenVerifier } from '../lib/auth.js';
import { looksLikeUpload, visionMime } from '../lib/image_type.js';
import type { ChatTransport } from '../ai/client.js';
import { extractReceipt, toDraftReceipt } from '../ai/extract_receipt.js';
import { NOTHING_CAUGHT, parseRules, toRulesPreview } from '../ai/parse_rules.js';
import { lockPlan, paymentBlocker, supersedeOrder, unlockedStatus } from '../domain/lock.js';
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

/** Spec Q2: a blank draft to type the bill into when the photo read fails. */
export const newSplitSchema = z
  .object({
    title: z.string().trim().min(1).max(60),
    merchant: z.string().trim().min(1).max(80).nullable(),
    receiptDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable(),
  })
  .partial()
  .strict();

const EMPTY_RECEIPT: Receipt = {
  lines: [],
  serviceChargeMinor: 0,
  serviceChargeLabel: null,
  tipMinor: 0,
  discounts: [],
  printedTotalMinor: null,
  currency: 'GBP',
};

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

const rulesMessageSchema = z.object({ message: z.string().trim().min(1).max(500) }).strict();

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

  // Manual entry (plan Task 2). The same draft a scan makes, with nothing read.
  router.post('/splits', auth, async (req, res, next) => {
    const parsed = newSplitSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      next(new ApiError(400, 'VALIDATION_FAILED', 'That new split is not valid.', parsed.error.format()));
      return;
    }
    try {
      const organiser = await deps.db.doc(`organisers/${req.organiserId}`).get();
      const name = organiser.get('displayName');
      const split = await createSplit(deps.db, req.organiserId!, {
        ...(parsed.data.title ? { title: parsed.data.title } : {}),
        merchant: parsed.data.merchant ?? null,
        receiptDate: parsed.data.receiptDate ?? null,
        receipt: EMPTY_RECEIPT,
        receiptAmbiguities: receiptProblems(EMPTY_RECEIPT),
        extractionModel: 'manual',
        sourceRef: null,
        organiserName: typeof name === 'string' && name.trim() ? name.trim() : 'You',
      });
      res.status(201).json({ split: toApi(split) });
    } catch (err) {
      next(err);
    }
  });

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

  // Spec §4 endpoint 11. A preview only: the organiser confirms it with
  // endpoint 12, so nothing here is ever applied on the model's say-so.
  router.post('/splits/:splitId/rules/message', auth, async (req, res, next) => {
    const parsed = rulesMessageSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      next(new ApiError(400, 'VALIDATION_FAILED', 'Say the rule in a few words.', parsed.error.format()));
      return;
    }
    try {
      const { split, participants } = await deps.db.runTransaction(async (tx) => {
        const out = await readSplit(tx, deps.db, req.organiserId!, String(req.params.splitId));
        assertStatus(out.split, ['draft', 'claiming'], 'change the rules');
        return out;
      });
      const ctx = {
        receipt: split.receipt,
        claims: split.claims,
        rules: split.rules,
        participants: participants.map((p) => ({ id: p.id, name: p.name, joinOrder: p.joinOrder, isOrganiser: p.isOrganiser })),
      };
      const preview = toRulesPreview(await parseRules(parsed.data.message, ctx, deps.transport, deps.model), ctx);
      res.json(preview ? { preview } : { preview: null, message: NOTHING_CAUGHT });
    } catch (err) {
      next(err);
    }
  });

  // Spec §4 endpoint 13. Freezes every share; friends can pay from here.
  // Safe to repeat: a split already collecting comes back as it is.
  router.post('/splits/:splitId/lock', auth, async (req, res, next) => {
    try {
      const out = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants } = await readSplit(tx, deps.db, req.organiserId!, String(req.params.splitId));
        if (split.status === 'collecting') {
          const owedMinor = participants.filter((p) => !p.isOrganiser && p.status !== 'on_us').reduce((t, p) => t + (p.shareMinor ?? 0), 0);
          return { split, participants, owedMinor };
        }
        assertStatus(split, ['claiming'], 'lock the split');
        const plan = lockPlan(split, participants);
        if (!plan.ok) {
          throw new ApiError(409, 'SPLIT_STATE_INVALID', plan.problems[0]?.question ?? 'Something on the bill still needs an answer.', { problems: plan.problems });
        }
        const lockedAt = Timestamp.now();
        tx.update(ref, { status: 'collecting', computed: plan.computed, lockedAt, updatedAt: FieldValue.serverTimestamp() });
        const byId = new Map(plan.people.map((p) => [p.id, p]));
        const next = participants.map((p) => ({ ...p, ...byId.get(p.id)! }));
        for (const p of plan.people) {
          tx.update(ref.collection('participants').doc(p.id), { shareMinor: p.shareMinor, status: p.status });
        }
        return { split: { ...split, status: 'collecting' as const, computed: plan.computed, lockedAt }, participants: next, owedMinor: plan.owedMinor };
      });
      res.json(toApi(out));
    } catch (err) {
      next(err);
    }
  });

  // Spec §4 endpoint 14. Back to claiming so the organiser can fix
  // something. Refused once anyone has paid; a friend who only opened PayPal
  // has that order superseded, and pays a fresh one after the next lock.
  router.post('/splits/:splitId/unlock', auth, async (req, res, next) => {
    try {
      const out = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants } = await readSplit(tx, deps.db, req.organiserId!, String(req.params.splitId));
        if (split.status === 'claiming') return { split, participants };
        assertStatus(split, ['collecting'], 'unlock the split');
        const blocker = paymentBlocker(participants, 'unlock');
        if (blocker) throw new ApiError(409, 'SPLIT_STATE_INVALID', blocker);
        tx.update(ref, { status: 'claiming', lockedAt: null, updatedAt: FieldValue.serverTimestamp() });
        const next = participants.map((p) => ({
          ...p,
          shareMinor: null,
          status: unlockedStatus(p),
          ...(p.paypalOrderId
            ? { paypalOrderId: null, approvalUrl: null, supersededPaypalOrderIds: [...p.supersededPaypalOrderIds, p.paypalOrderId] }
            : {}),
        }));
        for (const p of participants) {
          tx.update(ref.collection('participants').doc(p.id), { shareMinor: null, status: unlockedStatus(p), nudge: { count: 0, lastSentAt: null, lastText: null, channel: null, snoozedUntil: null }, ...supersedeOrder(p) });
        }
        return { split: { ...split, status: 'claiming' as const, lockedAt: null }, participants: next };
      });
      res.json(toApi(out));
    } catch (err) {
      next(err);
    }
  });

  // Spec §4 endpoint 17. The bill is off. Friends' links show "This bill was
  // cancelled" and every open PayPal order is superseded. A share already
  // paid stays paid: the organiser settles that with the friend.
  router.post('/splits/:splitId/cancel', auth, async (req, res, next) => {
    try {
      const out = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants } = await readSplit(tx, deps.db, req.organiserId!, String(req.params.splitId));
        if (split.status === 'cancelled') return { split, participants };
        assertStatus(split, ['draft', 'claiming', 'collecting'], 'cancel the split');
        const blocker = paymentBlocker(participants, 'cancel');
        if (blocker) throw new ApiError(409, 'SPLIT_STATE_INVALID', blocker);
        tx.update(ref, { status: 'cancelled', cancelledAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
        for (const p of participants) {
          if (p.paypalOrderId) tx.update(ref.collection('participants').doc(p.id), supersedeOrder(p));
        }
        const next = participants.map((p) => (p.paypalOrderId
          ? { ...p, paypalOrderId: null, approvalUrl: null, supersededPaypalOrderIds: [...p.supersededPaypalOrderIds, p.paypalOrderId] }
          : p));
        return { split: { ...split, status: 'cancelled' as const }, participants: next };
      });
      res.json(toApi(out));
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
