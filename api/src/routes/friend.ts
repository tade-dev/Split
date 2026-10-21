import express, { Router, type Response } from 'express';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import type { Env } from '../env.js';
import { verifyShareSignature } from '../domain/links.js';
import { normaliseClaims } from '../domain/claims.js';
import { splitPath, type ParticipantDoc, type SplitDoc } from '../domain/splits.js';
import { friendPage, friendView, type FriendView } from '../pages/friend_page.js';

export type FriendDeps = { env: Env; db: Firestore };

function send(res: Response, status: number, view: FriendView) {
  res.status(status);
  res.type('html');
  res.set('Cache-Control', 'no-store');
  res.set('Referrer-Policy', 'no-referrer');
  res.set('X-Content-Type-Options', 'nosniff');
  res.send(friendPage(view));
}

/**
 * A bad signature, a missing split and a removed person all get the same
 * 404 page, byte for byte, so ids cannot be probed (spec §4).
 */
const gone = (res: Response) => send(res, 404, { kind: 'gone' });

export function friendRouter(deps: FriendDeps): Router {
  const router = Router();
  // The pages post plain forms as well as JSON.
  router.use('/s', express.urlencoded({ extended: false, limit: '16kb' }));

  router.get('/s/:organiserId/:splitId/:participantId/:sig', async (req, res, next) => {
    const { organiserId, splitId, participantId, sig } = req.params;
    // Verify before any read: an unsigned request costs no Firestore at all.
    if (!verifyShareSignature(deps.env.LINK_SECRET, organiserId, splitId, participantId, sig)) {
      gone(res);
      return;
    }
    try {
      const ref = deps.db.doc(splitPath(organiserId, splitId));
      const personRef = ref.collection('participants').doc(participantId);
      const [splitSnap, personSnap, organiserSnap] = await Promise.all([
        ref.get(),
        personRef.get(),
        deps.db.doc(`organisers/${organiserId}`).get(),
      ]);
      if (!splitSnap.exists || !personSnap.exists) {
        gone(res);
        return;
      }
      const data = splitSnap.data() as SplitDoc;
      const split: SplitDoc = { ...data, id: splitSnap.id, claims: normaliseClaims(data.claims) };
      const person = { ...(personSnap.data() as ParticipantDoc), id: personSnap.id };
      const organiserName = organiserSnap.get('displayName');
      const organiser = typeof organiserName === 'string' && organiserName.trim() ? organiserName.trim() : 'Your friend';

      const view = friendView(split, person, organiser, req.originalUrl.split('?')[0]!.replace(/\/+$/, ''));
      if (view.kind === 'gone') {
        gone(res);
        return;
      }
      // First view only, and the pay page moves owes to link_opened (plan E2).
      const update: Record<string, unknown> = {};
      if (!person.linkOpenedAt) update.linkOpenedAt = FieldValue.serverTimestamp();
      if (split.status === 'collecting' && person.status === 'owes') update.status = 'link_opened';
      if (Object.keys(update).length > 0) await personRef.update(update);
      send(res, 200, view);
    } catch (err) {
      next(err);
    }
  });

  return router;
}
