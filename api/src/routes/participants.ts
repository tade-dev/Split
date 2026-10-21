import { Router } from 'express';
import { z } from 'zod';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import type { Env } from '../env.js';
import { ApiError } from '../lib/errors.js';
import { requireOrganiser, type TokenVerifier } from '../lib/auth.js';
import { groupMessage } from '../domain/group_message.js';
import { shareUrl } from '../domain/links.js';
import type { LineClaims, Rules } from '../domain/split.js';
import {
  PARTICIPANT_COLOURS,
  assertStatus,
  computeFor,
  newParticipant,
  readSplit,
  toApi,
  type ParticipantDoc,
  type SplitDoc,
} from '../domain/splits.js';

/** Eight colours, the organiser's first, so seven friends at most. */
export const MAX_FRIENDS = PARTICIPANT_COLOURS - 1;

const addSchema = z
  .object({ names: z.array(z.string().max(40)).min(1).max(MAX_FRIENDS) })
  .strict();

export type ParticipantsDeps = { env: Env; db: Firestore; verify: TokenVerifier };

/** The lowest colours nobody in the group has, in order. */
function freeColours(people: ParticipantDoc[], count: number): number[] {
  const used = new Set(people.map((p) => p.colourIndex));
  const free: number[] = [];
  for (let i = 0; i < PARTICIPANT_COLOURS && free.length < count; i++) if (!used.has(i)) free.push(i);
  return free;
}

/** Spec plan E3: their claims go, and so does every rule that names them. */
export function withoutParticipant(split: Pick<SplitDoc, 'claims' | 'rules'>, id: string): { claims: Record<string, LineClaims>; rules: Rules } {
  const claims = Object.fromEntries(
    Object.entries(split.claims).map(([lineId, entry]) => [
      lineId,
      { ...entry, claims: entry.claims.filter((c) => c.participantId !== id) },
    ]),
  );
  const paidBy = split.rules.onUsPaidBy?.filter((p) => p !== id) ?? null;
  return {
    claims,
    rules: {
      ...split.rules,
      onUs: split.rules.onUs.filter((p) => p !== id),
      onUsPaidBy: paidBy && paidBy.length > 0 ? paidBy : null,
      serviceOptOut: split.rules.serviceOptOut.filter((p) => p !== id),
    },
  };
}

export function participantsRouter(deps: ParticipantsDeps): Router {
  const router = Router();
  const auth = requireOrganiser(deps.verify);

  // Spec §4 endpoint 6.
  router.post('/splits/:splitId/participants', auth, async (req, res, next) => {
    const parsed = addSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      next(new ApiError(400, 'VALIDATION_FAILED', 'Send the names to add.', parsed.error.format()));
      return;
    }
    const names = parsed.data.names.map((n) => n.trim().replace(/\s+/g, ' ')).filter((n) => n.length > 0);
    if (names.length === 0) {
      next(new ApiError(400, 'VALIDATION_FAILED', 'Type a name to add someone.'));
      return;
    }
    try {
      const out = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants } = await readSplit(tx, deps.db, req.organiserId!, String(req.params.splitId));
        assertStatus(split, ['draft', 'claiming'], 'add people');
        const friends = participants.filter((p) => !p.isOrganiser).length;
        if (friends + names.length > MAX_FRIENDS) {
          throw new ApiError(400, 'VALIDATION_FAILED', `A bill can be split with up to ${MAX_FRIENDS} friends.`, { friends });
        }
        const colours = freeColours(participants, names.length);
        let joinOrder = participants.reduce((max, p) => Math.max(max, p.joinOrder), -1);
        const added = names.map((name, i) => {
          const docRef = ref.collection('participants').doc();
          return { docRef, doc: newParticipant(docRef.id, { name, joinOrder: ++joinOrder, isOrganiser: false, colourIndex: colours[i]! }) };
        });
        const everyone = [...participants, ...added.map((a) => a.doc)];
        const computed = computeFor(split, everyone);
        for (const a of added) tx.set(a.docRef, a.doc);
        tx.update(ref, { computed, updatedAt: FieldValue.serverTimestamp() });
        return { split: { ...split, computed }, participants: everyone };
      });
      res.status(201).json(toApi(out));
    } catch (err) {
      next(err);
    }
  });

  // Spec §4 endpoint 7. Before lock only; the organiser stays.
  router.delete('/splits/:splitId/participants/:participantId', auth, async (req, res, next) => {
    try {
      const out = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants } = await readSplit(tx, deps.db, req.organiserId!, String(req.params.splitId));
        assertStatus(split, ['draft', 'claiming'], 'remove someone');
        const id = String(req.params.participantId);
        const person = participants.find((p) => p.id === id);
        if (!person) throw new ApiError(404, 'NOT_FOUND', 'That person is not in this split.');
        if (person.isOrganiser) throw new ApiError(400, 'VALIDATION_FAILED', 'You are the organiser, so you stay in the split.');
        const { claims, rules } = withoutParticipant(split, id);
        const rest = participants.filter((p) => p.id !== id);
        const computed = computeFor({ ...split, claims, rules }, rest);
        tx.delete(ref.collection('participants').doc(id));
        tx.update(ref, { claims, rules, computed, updatedAt: FieldValue.serverTimestamp() });
        return { split: { ...split, claims, rules, computed }, participants: rest };
      });
      res.json(toApi(out));
    } catch (err) {
      next(err);
    }
  });

  // Spec §4 endpoint 8. Idempotent once claiming: the same links come back.
  router.post('/splits/:splitId/open', auth, async (req, res, next) => {
    try {
      const organiserId = req.organiserId!;
      const out = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants } = await readSplit(tx, deps.db, organiserId, String(req.params.splitId));
        assertStatus(split, ['draft', 'claiming'], 'send the links');
        const friends = participants.filter((p) => !p.isOrganiser).sort((a, b) => a.joinOrder - b.joinOrder);
        if (split.status === 'draft') {
          if (split.receiptAmbiguities.some((a) => a.blocking)) {
            throw new ApiError(409, 'SPLIT_STATE_INVALID', 'Check the bill first: something on it still needs an answer.');
          }
          if (friends.length === 0) {
            throw new ApiError(409, 'SPLIT_STATE_INVALID', 'Add at least one friend first.');
          }
        }
        const links = friends.map((p) => ({
          participantId: p.id,
          name: p.name,
          url: shareUrl(deps.env.PUBLIC_BASE_URL, deps.env.LINK_SECRET, organiserId, split.id, p.id),
        }));
        // Cached for the Tracker's Copy link and Preview (plan Task 11).
        tx.update(ref, {
          ...(split.status === 'draft' ? { status: 'claiming' } : {}),
          links: Object.fromEntries(links.map((l) => [l.participantId, l.url])),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return { links, groupMessage: groupMessage(split, links) };
      });
      res.json(out);
    } catch (err) {
      next(err);
    }
  });

  return router;
}
