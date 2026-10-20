import { Router } from 'express';
import { z } from 'zod';
import type { Firestore } from 'firebase-admin/firestore';
import { ApiError } from '../lib/errors.js';
import { requireOrganiser, type TokenVerifier } from '../lib/auth.js';
import { bootstrapOrganiser } from '../domain/seed.js';
import { toApi } from '../domain/splits.js';

const bodySchema = z.object({ demo: z.boolean().default(true) }).strict();

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

  return router;
}
