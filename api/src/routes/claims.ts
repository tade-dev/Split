import { Router } from 'express';
import { z } from 'zod';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import { ApiError } from '../lib/errors.js';
import { requireOrganiser, type TokenVerifier } from '../lib/auth.js';
import type { ChatTransport } from '../ai/client.js';
import { parseClaim, toClaimPreview, type ClaimContext, type MatchedLine } from '../ai/parse_claim.js';
import type { Ambiguity } from '../ai/schemas.js';
import { fitsLine, leftCopy, remainingUnits, setLineClaim } from '../domain/claims.js';
import type { LineClaims } from '../domain/split.js';
import { assertStatus, computeFor, readSplit, toApi, type ParticipantDoc, type SplitDoc } from '../domain/splits.js';

const messageSchema = z
  .object({ participantId: z.string().min(1).nullable(), message: z.string().trim().min(1).max(500) })
  .strict();

const lineSchema = z
  .object({
    lineId: z.string().min(1),
    claims: z.array(z.object({ participantId: z.string().min(1), weight: z.number().int().min(1) }).strict()).max(8),
    shared: z.boolean().optional(),
  })
  .strict();

export type ClaimsDeps = { db: Firestore; verify: TokenVerifier; transport: ChatTransport; model: string };

const unclear = (field: string, question: string): Ambiguity => ({ field, kind: 'unclear', question, options: [], blocking: true });

/** Anyone still `invited` who now has a claim becomes `claimed` (plan E2). */
function newlyClaimed(participants: ParticipantDoc[], claims: Record<string, LineClaims>, ids: Iterable<string>): ParticipantDoc[] {
  const wanted = new Set(ids);
  return participants.filter(
    (p) => wanted.has(p.id) && p.status === 'invited' && Object.values(claims).some((e) => e.claims.some((c) => c.participantId === p.id)),
  );
}

function context(split: SplitDoc, participants: ParticipantDoc[], writerId: string | null): ClaimContext {
  const writer = writerId ? participants.find((p) => p.id === writerId) : null;
  if (writerId && !writer) throw new ApiError(404, 'NOT_FOUND', 'That person is not in this split.');
  return {
    lines: split.receipt.lines,
    claims: split.claims,
    participants: participants.map((p) => ({ id: p.id, name: p.name })),
    writer: writer ? { id: writer.id, name: writer.name } : null,
  };
}

export function claimsRouter(deps: ClaimsDeps): Router {
  const router = Router();
  const auth = requireOrganiser(deps.verify);

  // Spec §4 endpoint 9. The organiser is trusted, so this parses and writes
  // in one go. The parse runs outside the transaction; the matches are
  // checked again against the claims as they stand when it commits.
  router.post('/splits/:splitId/claims/message', auth, async (req, res, next) => {
    const parsed = messageSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      next(new ApiError(400, 'VALIDATION_FAILED', 'Say who had what.', parsed.error.format()));
      return;
    }
    const { participantId, message } = parsed.data;
    const organiserId = req.organiserId!;
    const splitId = String(req.params.splitId);
    try {
      const before = await deps.db.runTransaction(async (tx) => {
        const out = await readSplit(tx, deps.db, organiserId, splitId);
        assertStatus(out.split, ['draft', 'claiming'], 'change claims');
        return out;
      });
      const raw = await parseClaim(message, context(before.split, before.participants, participantId), deps.transport, deps.model);

      const out = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants } = await readSplit(tx, deps.db, organiserId, splitId);
        assertStatus(split, ['draft', 'claiming'], 'change claims');
        const preview = toClaimPreview(raw, context(split, participants, participantId));
        const problems = [...preview.problems];
        const applied: MatchedLine[] = [];
        let claims = split.claims;
        // One message can name two people on one line; each has to fit in
        // what the ones before it left.
        for (const m of preview.matched) {
          const line = split.receipt.lines.find((l) => l.id === m.lineId)!;
          const left = remainingUnits(line, claims[line.id], m.participantId);
          if (!fitsLine(line, m.weight, left)) {
            problems.push({ ...unclear(`claims.${line.id}`, leftCopy(line, left)), kind: 'qty_unclear' });
            continue;
          }
          claims = setLineClaim(claims, m.lineId, m.participantId, m.weight, 'organiser');
          applied.push(m);
        }
        if (applied.length > 0) {
          const computed = computeFor({ ...split, claims }, participants);
          tx.update(ref, { claims, computed, updatedAt: FieldValue.serverTimestamp() });
          for (const p of newlyClaimed(participants, claims, applied.map((a) => a.participantId))) {
            tx.update(ref.collection('participants').doc(p.id), { status: 'claimed', claimedAt: FieldValue.serverTimestamp() });
          }
        }
        return { applied, problems, ignored: preview.ignored };
      });
      res.json(out);
    } catch (err) {
      next(err);
    }
  });

  // Spec §4 endpoint 10. Replaces one line's claims outright: how a warning's
  // "Share between Josh and Dan" resolves, and how the organiser fixes a line.
  router.patch('/splits/:splitId/claims', auth, async (req, res, next) => {
    const parsed = lineSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      next(new ApiError(400, 'VALIDATION_FAILED', 'Send the line and who had it.', parsed.error.format()));
      return;
    }
    const body = parsed.data;
    try {
      const out = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants } = await readSplit(tx, deps.db, req.organiserId!, String(req.params.splitId));
        assertStatus(split, ['draft', 'claiming'], 'change claims');
        const line = split.receipt.lines.find((l) => l.id === body.lineId);
        if (!line) throw new ApiError(404, 'NOT_FOUND', 'That item is no longer on the bill.');
        const ids = body.claims.map((c) => c.participantId);
        if (new Set(ids).size !== ids.length) throw new ApiError(400, 'VALIDATION_FAILED', 'Each person goes on a line once.');
        if (ids.some((id) => !participants.some((p) => p.id === id))) throw new ApiError(404, 'NOT_FOUND', 'That person is not in this split.');
        const total = body.claims.reduce((t, c) => t + c.weight, 0);
        // A single dish can go to everyone who shared it; more than one can
        // never be claimed past its qty.
        if (line.qty > 1 ? total > line.qty : body.claims.some((c) => c.weight !== 1)) {
          throw new ApiError(400, 'VALIDATION_FAILED', `There ${line.qty === 1 ? 'is 1' : `are ${line.qty}`} of the ${line.name.toLowerCase()} on the bill.`);
        }
        const claims: Record<string, LineClaims> = {
          ...split.claims,
          [line.id]: {
            claims: body.claims.map((c) => ({ participantId: c.participantId, weight: c.weight, source: 'organiser' as const })),
            shared: body.shared ?? split.claims[line.id]?.shared ?? false,
          },
        };
        const computed = computeFor({ ...split, claims }, participants);
        tx.update(ref, { claims, computed, updatedAt: FieldValue.serverTimestamp() });
        for (const p of newlyClaimed(participants, claims, ids)) {
          tx.update(ref.collection('participants').doc(p.id), { status: 'claimed', claimedAt: FieldValue.serverTimestamp() });
        }
        return { split: { ...split, claims, computed } };
      });
      res.json(toApi(out));
    } catch (err) {
      next(err);
    }
  });

  return router;
}
