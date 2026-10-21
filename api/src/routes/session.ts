import { Router } from 'express';
import { z } from 'zod';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import { ApiError } from '../lib/errors.js';
import { requireOrganiser, type TokenVerifier } from '../lib/auth.js';
import { bootstrapOrganiser } from '../domain/seed.js';
import { toApi } from '../domain/splits.js';

const bodySchema = z.object({ demo: z.boolean().default(true) }).strict();

const organiserPatchSchema = z
  .object({
    displayName: z.string().trim().min(1).max(40),
    // Null clears it, so shares pay the shared sandbox merchant (plan E10).
    paypalEmail: z.string().trim().toLowerCase().email().max(254).nullable(),
  })
  .partial()
  .strict()
  .refine((b) => Object.keys(b).length > 0, 'Send at least one change.');

export function sessionRouter(deps: { db: Firestore; verify: TokenVerifier }): Router {
  const router = Router();

  // Spec §4 endpoint 2.
  router.post('/session/bootstrap', requireOrganiser(deps.verify), async (req, res, next) => {
    const parsed = bodySchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      next(new ApiError(400, 'VALIDATION_FAILED', 'Invalid request body.', parsed.error.format()));
      return;
    }
    try {
      const result = await bootstrapOrganiser(deps.db, req.organiserId!, parsed.data);
      res.json({ organiser: toApi(result.organiser), seededSplitId: result.seededSplitId });
    } catch (err) {
      next(err);
    }
  });

  // Spec §4 endpoint 3. Who the friends see, and where their money goes.
  router.patch('/session/organiser', requireOrganiser(deps.verify), async (req, res, next) => {
    const parsed = organiserPatchSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      const email = parsed.error.issues.some((i) => i.path[0] === 'paypalEmail');
      next(new ApiError(400, 'VALIDATION_FAILED', email ? 'That is not an email address PayPal can pay.' : 'Check your name.', parsed.error.format()));
      return;
    }
    try {
      const ref = deps.db.doc(`organisers/${req.organiserId!}`);
      const organiser = await deps.db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) throw new ApiError(404, 'NOT_FOUND', 'Sign in again to set up your account.');
        tx.update(ref, { ...parsed.data, updatedAt: FieldValue.serverTimestamp() });
        return { ...snap.data(), ...parsed.data, id: snap.id };
      });
      res.json({ organiser: toApi(organiser) });
    } catch (err) {
      next(err);
    }
  });

  return router;
}
