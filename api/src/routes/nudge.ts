import { Router } from 'express';
import { z } from 'zod';
import { FieldValue, Timestamp, type Firestore } from 'firebase-admin/firestore';
import type { Env } from '../env.js';
import type { ChatTransport } from '../ai/client.js';
import { draftNudge, NUDGE_TONES } from '../ai/draft_nudge.js';
import { ApiError } from '../lib/errors.js';
import { requireOrganiser, type TokenVerifier } from '../lib/auth.js';
import { shareUrl } from '../domain/links.js';
import { millis, nudgeRefusal, openedRecently, snoozeUntil } from '../domain/nudge.js';
import { readSplit } from '../domain/splits.js';

export type NudgeDeps = {
  env: Env;
  db: Firestore;
  verify: TokenVerifier;
  transport: ChatTransport;
  model: string;
  now?: () => number;
};

const draftSchema = z.object({ tone: z.enum(NUDGE_TONES as [string, ...string[]]).optional() }).strict();
const sentSchema = z.object({ text: z.string().trim().min(1).max(500) }).strict();

const DAY_MS = 24 * 60 * 60 * 1000;

/** Spec §4 endpoint 16: draft a friend's nudge, record it sent, or snooze it. */
export function nudgeRouter(deps: NudgeDeps): Router {
  const router = Router();
  const auth = requireOrganiser(deps.verify);
  const now = () => (deps.now ?? Date.now)();

  /** The split and the person, refused unless the share can be nudged. */
  async function nudgeable(organiserId: string, splitId: string, participantId: string) {
    return deps.db.runTransaction(async (tx) => {
      const out = await readSplit(tx, deps.db, organiserId, splitId);
      const person = out.participants.find((p) => p.id === participantId && !p.isOrganiser);
      if (!person) throw new ApiError(404, 'NOT_FOUND', 'That person is not in this split.');
      const refusal = nudgeRefusal(person, out.split.status);
      if (refusal) throw new ApiError(409, 'SPLIT_STATE_INVALID', refusal, { status: person.status });
      return { ...out, person };
    });
  }

  router.post('/splits/:splitId/participants/:participantId/nudge', auth, async (req, res, next) => {
    try {
      const body = draftSchema.safeParse(req.body ?? {});
      if (!body.success) throw new ApiError(400, 'VALIDATION_FAILED', 'Pick a tone: friendly, cheeky or firm.');
      const organiserId = req.organiserId!;
      const { split, person } = await nudgeable(organiserId, String(req.params.splitId), String(req.params.participantId));
      const organiser = await deps.db.doc(`organisers/${organiserId}`).get();
      const tone = (body.data.tone ?? 'friendly') as 'friendly' | 'cheeky' | 'firm';
      const locked = millis(split.lockedAt);
      const drafted = await draftNudge(
        {
          friend: person.name,
          organiser: (organiser.get('displayName') as string | undefined)?.trim() || 'Your friend',
          title: split.title,
          merchant: split.merchant,
          amountMinor: person.shareMinor ?? 0,
          link: shareUrl(deps.env.PUBLIC_BASE_URL, deps.env.LINK_SECRET, organiserId, split.id, person.id),
          tone,
          priorCount: person.nudge?.count ?? 0,
          daysUnpaid: locked === null ? 0 : Math.floor((now() - locked) / DAY_MS),
          openedRecently: openedRecently(person, now()),
        },
        deps.transport,
        deps.model,
      );
      res.json({ ...drafted, tone });
    } catch (err) {
      next(err);
    }
  });

  // The organiser copied it into the chat. Split never sends it.
  router.post('/splits/:splitId/participants/:participantId/nudge/sent', auth, async (req, res, next) => {
    try {
      const body = sentSchema.safeParse(req.body ?? {});
      if (!body.success) throw new ApiError(400, 'VALIDATION_FAILED', 'Send the text that was copied.');
      const { ref, person } = await nudgeable(req.organiserId!, String(req.params.splitId), String(req.params.participantId));
      const count = (person.nudge?.count ?? 0) + 1;
      await ref.collection('participants').doc(person.id).update({
        'nudge.count': count,
        'nudge.lastSentAt': FieldValue.serverTimestamp(),
        'nudge.lastText': body.data.text,
        'nudge.channel': 'manual_copy',
        'nudge.snoozedUntil': null,
        'nudge.draftText': FieldValue.delete(),
      });
      res.json({ count });
    } catch (err) {
      next(err);
    }
  });

  router.post('/splits/:splitId/participants/:participantId/nudge/snooze', auth, async (req, res, next) => {
    try {
      const { ref, person } = await nudgeable(req.organiserId!, String(req.params.splitId), String(req.params.participantId));
      const until = snoozeUntil(now());
      await ref.collection('participants').doc(person.id).update({ 'nudge.snoozedUntil': Timestamp.fromMillis(until) });
      res.json({ snoozedUntil: new Date(until).toISOString() });
    } catch (err) {
      next(err);
    }
  });

  return router;
}
