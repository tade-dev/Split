import express, { Router, type Request, type Response } from 'express';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import type { Env } from '../env.js';
import type { ChatTransport } from '../ai/client.js';
import type { PayPalFetch } from '../paypal/client.js';
import { createPayPalOrder } from '../paypal/orders.js';
import { parseClaim, toClaimPreview, type ClaimContext } from '../ai/parse_claim.js';
import type { Ambiguity } from '../ai/schemas.js';
import { ApiError } from '../lib/errors.js';
import { verifyShareSignature } from '../domain/links.js';
import { applyClaims, normaliseClaims } from '../domain/claims.js';
import { computeFor, readSplit, splitPath, type ParticipantDoc, type SplitDoc } from '../domain/splits.js';
import { friendPage, friendView, pickView, type FriendView } from '../pages/friend_page.js';

export type FriendDeps = { env: Env; db: Firestore; transport: ChatTransport; model: string; paypal: PayPalFetch };

/** Typed claims a friend may send before Split asks them to pick instead. */
export const MAX_AI_PARSES = 8;
const MAX_MESSAGE = 500;

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

/** Thrown inside a transaction when the split or the person is not there. */
class Gone extends Error {}

type Link = { organiserId: string; splitId: string; participantId: string; selfPath: string };

/** The signed link from the URL, or null when the signature is wrong. */
function linkFrom(req: Request, env: Env): Link | null {
  const { organiserId, splitId, participantId, sig } = req.params as Record<string, string>;
  if (!verifyShareSignature(env.LINK_SECRET, organiserId!, splitId!, participantId!, sig!)) return null;
  return {
    organiserId: organiserId!,
    splitId: splitId!,
    participantId: participantId!,
    selfPath: `/v1/s/${organiserId}/${splitId}/${participantId}/${sig}`,
  };
}

const isForm = (req: Request) => req.is('application/x-www-form-urlencoded') === 'application/x-www-form-urlencoded';

const questions = (problems: Ambiguity[]) => problems.map((p) => p.question);

/** Reads the split, its people and this person in a transaction, or throws Gone. */
async function readLink(tx: FirebaseFirestore.Transaction, db: Firestore, link: Link) {
  try {
    const out = await readSplit(tx, db, link.organiserId, link.splitId);
    const person = out.participants.find((p) => p.id === link.participantId);
    if (!person || person.isOrganiser) throw new Gone();
    return { ...out, person };
  } catch (err) {
    if (err instanceof ApiError && err.code === 'NOT_FOUND') throw new Gone();
    throw err;
  }
}

function claimContext(split: SplitDoc, participants: ParticipantDoc[], person: ParticipantDoc): ClaimContext {
  return {
    lines: split.receipt.lines,
    claims: split.claims,
    participants: participants.map((p) => ({ id: p.id, name: p.name })),
    writer: { id: person.id, name: person.name },
  };
}

/** `w_<lineId>` fields from the checklist and preview forms, or JSON `lines`. */
function confirmedLines(req: Request): { lineId: string; weight: number }[] | null {
  const body = (req.body ?? {}) as Record<string, unknown>;
  if (isForm(req)) {
    const out: { lineId: string; weight: number }[] = [];
    for (const [key, value] of Object.entries(body)) {
      if (!key.startsWith('w_')) continue;
      const text = String(value).trim();
      const weight = text === '' ? 0 : Number(text);
      if (!Number.isSafeInteger(weight) || weight < 0) return null;
      if (weight > 0) out.push({ lineId: key.slice(2), weight });
    }
    return out;
  }
  if (!Array.isArray(body.lines)) return null;
  const out: { lineId: string; weight: number }[] = [];
  for (const item of body.lines as unknown[]) {
    const { lineId, weight } = (item ?? {}) as { lineId?: unknown; weight?: unknown };
    if (typeof lineId !== 'string' || typeof weight !== 'number' || !Number.isSafeInteger(weight) || weight < 0) return null;
    if (weight > 0) out.push({ lineId, weight });
  }
  return out;
}

export function friendRouter(deps: FriendDeps): Router {
  const router = Router();
  // The pages post plain forms as well as JSON.
  router.use('/s', express.urlencoded({ extended: false, limit: '16kb' }));

  router.get('/s/:organiserId/:splitId/:participantId/:sig', async (req, res, next) => {
    // Verify before any read: an unsigned request costs no Firestore at all.
    const link = linkFrom(req, deps.env);
    if (!link) {
      gone(res);
      return;
    }
    try {
      const ref = deps.db.doc(splitPath(link.organiserId, link.splitId));
      const personRef = ref.collection('participants').doc(link.participantId);
      const [splitSnap, personSnap, organiserSnap] = await Promise.all([
        ref.get(),
        personRef.get(),
        deps.db.doc(`organisers/${link.organiserId}`).get(),
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

      const view = friendView(split, person, organiser, link.selfPath, { pick: req.query.pick === '1' });
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

  // Spec §7.2: what the friend typed, matched to the bill. Nothing is written
  // but the parse count; the friend confirms the preview next.
  router.post('/s/:organiserId/:splitId/:participantId/:sig/claim', async (req, res, next) => {
    const link = linkFrom(req, deps.env);
    if (!link) {
      gone(res);
      return;
    }
    const form = isForm(req);
    const raw = (req.body ?? {}) as { message?: unknown };
    const message = typeof raw.message === 'string' ? raw.message.trim() : '';
    if (message.length === 0 || message.length > MAX_MESSAGE) {
      if (form) res.redirect(303, link.selfPath);
      else next(new ApiError(400, 'VALIDATION_FAILED', `Say what you had in up to ${MAX_MESSAGE} characters.`));
      return;
    }
    try {
      const read = await deps.db.runTransaction(async (tx) => {
        const out = await readLink(tx, deps.db, link);
        if (out.split.status !== 'claiming') return { ...out, capped: false, open: false };
        if (out.person.aiParsesUsed >= MAX_AI_PARSES) return { ...out, capped: true, open: true };
        tx.update(out.ref.collection('participants').doc(out.person.id), { aiParsesUsed: FieldValue.increment(1) });
        return { ...out, capped: false, open: true };
      });
      const { split, participants, person } = read;
      if (!read.open) {
        if (form) res.redirect(303, link.selfPath);
        else next(new ApiError(409, 'SPLIT_STATE_INVALID', 'Claims are closed for this bill.'));
        return;
      }
      const checklist = (status: number, note: string) => {
        if (form) send(res, status, pickView(split, person, link.selfPath, [note]));
        else res.status(status).json({ error: { code: status === 429 ? 'RATE_LIMITED' : 'AI_PARSE_FAILED', message: note }, fallback: 'checklist' });
      };
      if (read.capped) {
        checklist(429, 'Pick what you had from the bill this time.');
        return;
      }

      const ctx = claimContext(split, participants, person);
      let preview;
      try {
        preview = toClaimPreview(await parseClaim(message, ctx, deps.transport, deps.model), ctx);
      } catch (err) {
        if (err instanceof ApiError && err.code === 'AI_PARSE_FAILED') {
          checklist(502, "Split couldn't read that just now. Pick what you had from the bill.");
          return;
        }
        throw err;
      }
      if (!form) {
        res.json({
          matched: preview.matched.map(({ lineId, name, weight, portionLabel }) => ({ lineId, name, weight, portionLabel })),
          problems: preview.problems,
          ignored: preview.ignored,
        });
        return;
      }
      send(res, 200, {
        kind: 'preview',
        name: person.name,
        matched: preview.matched.map((m) => ({ lineId: m.lineId, label: m.portionLabel ? `${m.name}, ${m.portionLabel}` : m.name, weight: m.weight })),
        notes: [...questions(preview.problems), ...preview.ignored],
        message,
        action: `${link.selfPath}/claim/confirm`,
        pickHref: `${link.selfPath}?pick=1`,
        retryHref: link.selfPath,
      });
    } catch (err) {
      if (err instanceof Gone) gone(res);
      else next(err);
    }
  });

  // The friend's whole claim, from the preview or the checklist. It replaces
  // what they claimed before, and a line can never be claimed past its qty.
  router.post('/s/:organiserId/:splitId/:participantId/:sig/claim/confirm', async (req, res, next) => {
    const link = linkFrom(req, deps.env);
    if (!link) {
      gone(res);
      return;
    }
    const form = isForm(req);
    const lines = confirmedLines(req);
    const rawMessage = (req.body ?? {}).message;
    const message = typeof rawMessage === 'string' && rawMessage.trim() ? rawMessage.trim().slice(0, MAX_MESSAGE) : null;
    try {
      const out = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants, person } = await readLink(tx, deps.db, link);
        if (split.status !== 'claiming') return { kind: 'closed' as const };
        const fail = (problems: Ambiguity[]) => ({ kind: 'problems' as const, split, person, problems });
        if (!lines) return fail([{ field: 'claims', kind: 'qty_unclear', question: 'Put a whole number for each thing you had.', options: [], blocking: true }]);
        if (lines.length === 0) return fail([{ field: 'claims', kind: 'unclear', question: 'Pick at least one thing you had.', options: [], blocking: true }]);
        const applied = applyClaims(split.claims, { participantId: person.id, items: lines }, {
          actor: { kind: 'friend', participantId: person.id },
          lines: split.receipt.lines,
        });
        if (!applied.ok) return fail(applied.problems);
        const computed = computeFor({ ...split, claims: applied.claims }, participants);
        tx.update(ref, { claims: applied.claims, computed, updatedAt: FieldValue.serverTimestamp() });
        tx.update(ref.collection('participants').doc(person.id), {
          claimText: message,
          claimedAt: FieldValue.serverTimestamp(),
          status: 'claimed',
        });
        return { kind: 'ok' as const, claims: applied.claims };
      });
      if (out.kind === 'closed') {
        if (form) res.redirect(303, link.selfPath);
        else next(new ApiError(409, 'SPLIT_STATE_INVALID', 'Claims are closed for this bill.'));
        return;
      }
      if (out.kind === 'problems') {
        if (form) send(res, 409, pickView(out.split, out.person, link.selfPath, questions(out.problems)));
        else res.status(409).json({ error: { code: 'SPLIT_STATE_INVALID', message: out.problems[0]!.question }, problems: out.problems });
        return;
      }
      if (form) res.redirect(303, link.selfPath);
      else res.json({ status: 'claimed', lines });
    } catch (err) {
      if (err instanceof Gone) gone(res);
      else next(err);
    }
  });

  // FriendPay's button. One PayPal order per share: the first tap makes it,
  // later taps reuse it. The amount is the shareMinor frozen at lock, never
  // worked out again here (plan Review Focus 7).
  router.post('/s/:organiserId/:splitId/:participantId/:sig/pay', async (req, res, next) => {
    const link = linkFrom(req, deps.env);
    if (!link) {
      gone(res);
      return;
    }
    const form = isForm(req);
    const refuse = (message: string) => {
      if (form) res.redirect(303, link.selfPath);
      else next(new ApiError(409, 'SPLIT_STATE_INVALID', message));
    };
    const done = (approvalUrl: string) => {
      if (form) res.redirect(303, approvalUrl);
      else res.json({ approvalUrl });
    };
    try {
      const read = await deps.db.runTransaction(async (tx) => {
        const out = await readLink(tx, deps.db, link);
        const organiser = await tx.get(deps.db.doc(`organisers/${link.organiserId}`));
        return { ...out, payeeEmail: (organiser.get('paypalEmail') as string | null | undefined) ?? null };
      });
      const { split, person } = read;
      if (split.status !== 'collecting' || (person.status !== 'owes' && person.status !== 'link_opened')) {
        refuse('There is nothing to pay on this link right now.');
        return;
      }
      if (person.paypalOrderId && person.approvalUrl) {
        done(person.approvalUrl);
        return;
      }
      if (!person.shareMinor || person.shareMinor <= 0) {
        refuse('There is nothing to pay on this link.');
        return;
      }
      const where = split.merchant ? ` (${split.merchant})` : '';
      const created = await createPayPalOrder(
        {
          referenceId: person.id,
          customId: `${link.organiserId}:${link.splitId}:${person.id}`,
          amountMinor: person.shareMinor,
          description: `Your share of ${split.title}${where}`,
          payeeEmail: read.payeeEmail,
          requestId: `pay-${link.splitId}-${person.id}-${person.supersededPaypalOrderIds.length}`,
        },
        deps.paypal,
        deps.env.PUBLIC_BASE_URL,
      );
      // Two taps at once both reach PayPal with the same request id, so they
      // get the same order back; whichever stores it first wins, harmlessly.
      const approvalUrl = await deps.db.runTransaction(async (tx) => {
        const ref = deps.db.doc(splitPath(link.organiserId, link.splitId)).collection('participants').doc(person.id);
        const fresh = await tx.get(ref);
        const stored = fresh.get('approvalUrl') as string | null;
        if (fresh.get('paypalOrderId') && stored) return stored;
        tx.update(ref, { paypalOrderId: created.paypalOrderId, approvalUrl: created.approvalUrl });
        return created.approvalUrl;
      });
      done(approvalUrl);
    } catch (err) {
      if (err instanceof Gone) gone(res);
      else next(err);
    }
  });

  return router;
}
