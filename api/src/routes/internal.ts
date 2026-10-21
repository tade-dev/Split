import { timingSafeEqual } from 'node:crypto';
import { Router, type RequestHandler } from 'express';
import type { Firestore } from 'firebase-admin/firestore';
import { ApiError } from '../lib/errors.js';
import type { Env } from '../env.js';
import type { PayPalFetch } from '../paypal/client.js';
import { paypalIssue } from '../paypal/events.js';
import { reconcileShare } from '../paypal/reconcile.js';
import { DEFAULT_ORDER_EXPIRY_HOURS } from '../env.js';
import { millis, nudgeDue, type NudgeOrder } from '../domain/nudge.js';
import { OPEN_SHARE_STATUSES } from '../domain/shares.js';
import type { ParticipantDoc, ParticipantStatus } from '../domain/splits.js';
import { draftNudge } from '../ai/draft_nudge.js';
import type { ChatTransport } from '../ai/client.js';
import { FieldValue, type QueryDocumentSnapshot } from 'firebase-admin/firestore';
const TWO_MINUTES_MS = 2 * 60 * 1000;

function authorised(provided: string, expected: string): boolean {
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

const HOUR_MS = 60 * 60 * 1000;

/** Shares an unpaid PayPal order may be replaced on (plan E8). */
const EXPIRABLE: readonly ParticipantStatus[] = ['owes', 'link_opened', 'declined'];

/**
 * Every share with a PayPal order out, in splits still collecting. Walked
 * organiser by organiser rather than as one collection-group query, which
 * would need an index exemption on `status` as well.
 */
async function sharesWithOrders(db: Firestore, statuses: readonly ParticipantStatus[]): Promise<QueryDocumentSnapshot[]> {
  const out: QueryDocumentSnapshot[] = [];
  const organisers = await db.collection('organisers').listDocuments();
  for (const organiser of organisers) {
    const splits = await organiser.collection('splits').where('status', '==', 'collecting').get();
    for (const split of splits.docs) {
      const people = await split.ref.collection('participants').where('status', 'in', [...statuses]).get();
      for (const doc of people.docs) {
        const id = doc.get('paypalOrderId');
        if (typeof id === 'string' && id) out.push(doc);
      }
    }
  }
  return out;
}

export function internalRouter(deps: {
  env: Env;
  db: Firestore;
  paypal: PayPalFetch;
  /** For the nudge sweep's drafts. Without one, the sweep uses the template. */
  transport?: ChatTransport;
  model?: string;
  now?: () => number;
}): Router {
  const router = Router();

  const internalOnly: RequestHandler = (req, _res, next) => {
    const provided = req.get('x-internal-token') ?? '';
    if (!authorised(provided, deps.env.INTERNAL_TOKEN)) {
      next(new ApiError(401, 'UNAUTHENTICATED', 'That internal call was not authorised.'));
      return;
    }
    next();
  };

  // The safety net under capture on return and the webhooks: asks PayPal
  // about every share still mid-payment and moves it to match. Orders made
  // in the last two minutes are left to the return page.
  router.post('/internal/workflows/reconcile', internalOnly, async (_req, res, next) => {
    const now = (deps.now ?? Date.now)();
    let checked = 0;
    let promoted = 0;
    let failed = 0;

    try {
      for (const doc of await sharesWithOrders(deps.db, OPEN_SHARE_STATUSES)) {
        const created = millis(doc.get('paypalOrderCreatedAt'));
        if (created !== null && now - created < TWO_MINUTES_MS) continue;
        checked += 1;
        try {
          if ((await reconcileShare(deps.paypal, doc.ref, doc.get('paypalOrderId') as string, 'reconcile')).moved) promoted += 1;
        } catch (err) {
          failed += 1;
          console.error(JSON.stringify({
            source: 'paypal_reconcile',
            participantId: doc.id,
            issue: paypalIssue(err) ?? 'unknown',
          }));
        }
      }
      res.json({ checked, promoted, failed });
    } catch (err) {
      next(err);
    }
  });

  // Replaces unpaid PayPal orders older than ORDER_EXPIRY_HOURS (plan E8).
  // The friend's link stays valid: the share drops back to owes, and their
  // next Pay tap makes a fresh order. Each order is checked with PayPal
  // first, so a payment whose signals never landed is marked paid instead;
  // if PayPal cannot be asked, the share is left for the next run.
  router.post('/internal/workflows/expire-sweep', internalOnly, async (_req, res, next) => {
    const now = (deps.now ?? Date.now)();
    const ttlHours = deps.env.ORDER_EXPIRY_HOURS ?? DEFAULT_ORDER_EXPIRY_HOURS;
    let scanned = 0;
    let expired = 0;
    let kept = 0;
    let failed = 0;

    try {
      for (const doc of await sharesWithOrders(deps.db, EXPIRABLE)) {
        const created = millis(doc.get('paypalOrderCreatedAt'));
        if (created === null || now < created + ttlHours * HOUR_MS) continue;
        scanned += 1;
        const paypalOrderId = doc.get('paypalOrderId') as string;
        try {
          if ((await reconcileShare(deps.paypal, doc.ref, paypalOrderId, 'expiry')).moved) {
            kept += 1;
            continue;
          }
        } catch (err) {
          failed += 1;
          console.error(JSON.stringify({
            source: 'order_expiry',
            participantId: doc.id,
            issue: paypalIssue(err) ?? 'unknown',
          }));
          continue;
        }
        // Inside a transaction, so a capture landing between the check and
        // this write is never undone: paid wins.
        const replaced = await deps.db.runTransaction(async (tx) => {
          const fresh = await tx.get(doc.ref);
          const person = fresh.data() as ParticipantDoc | undefined;
          if (!person || person.paypalOrderId !== paypalOrderId || !EXPIRABLE.includes(person.status)) return false;
          tx.update(doc.ref, {
            status: 'owes',
            paypalOrderId: null,
            approvalUrl: null,
            paypalOrderCreatedAt: null,
            supersededPaypalOrderIds: FieldValue.arrayUnion(paypalOrderId),
          });
          tx.set(doc.ref.collection('paymentEvents').doc(`expire-${paypalOrderId}`), {
            id: `expire-${paypalOrderId}`,
            eventType: 'expired',
            paypalResourceId: paypalOrderId,
            amountMinor: null,
            raw: { source: 'expiry_sweep', from: person.status },
            signatureVerified: false,
            receivedAt: FieldValue.serverTimestamp(),
            processedAt: FieldValue.serverTimestamp(),
            processingError: null,
          });
          return true;
        });
        if (replaced) expired += 1;
        else kept += 1;
      }
      res.json({ scanned, expired, kept, failed });
    } catch (err) {
      next(err);
    }
  });

  // Finds unpaid links that are due a reminder and drafts one, so the nudge
  // is already written when the seller opens it. It never sends anything:
  // the seller copies it into the chat. Orders that already have a draft
  // waiting are left alone, so an hourly run does not rewrite it under them.
  router.post('/internal/workflows/nudge-sweep', internalOnly, async (_req, res, next) => {
    const now = (deps.now ?? Date.now)();
    let scanned = 0;
    let nudged = 0;
    let skipped = 0;
    try {
      const organisers = await deps.db.collection('organisers').get();
      for (const seller of organisers.docs) {
        const orders = await seller.ref.collection('orders').where('status', '==', 'link_sent').get();
        for (const doc of orders.docs) {
          const order = doc.data() as NudgeOrder & { linkSentAt?: unknown };
          if (!nudgeDue(order, now)) continue;
          scanned += 1;
          if (order.nudge && (order.nudge as { draftText?: unknown }).draftText) { skipped += 1; continue; }
          const drafted = await draftNudge(
            {
              order,
              approvalUrl: order.approvalUrl!,
              personaTone: (seller.get('personaTone') as string | undefined) ?? '',
              tone: 'friendly',
              priorCount: order.nudge?.count ?? 0,
              daysUnpaid: Math.floor((now - millis(order.linkSentAt)!) / (24 * 60 * 60 * 1000)),
            },
            deps.transport ?? (async () => { throw new Error('no model'); }),
            deps.model ?? '',
          );
          // Here, unlike when the seller asks, the model may decline to chase.
          if (drafted.shouldSkip) {
            skipped += 1;
            await doc.ref.update({ 'nudge.skipReason': drafted.skipReason ?? 'The assistant chose not to chase this one.' });
            continue;
          }
          await doc.ref.update({
            'nudge.draftText': drafted.text,
            'nudge.draftedAt': FieldValue.serverTimestamp(),
          });
          nudged += 1;
        }
      }
      res.json({ scanned, nudged, skipped });
    } catch (err) {
      next(err);
    }
  });

  return router;
}
