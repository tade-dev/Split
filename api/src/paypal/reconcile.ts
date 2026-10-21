import type { DocumentReference, Firestore } from 'firebase-admin/firestore';
import type { PayPalFetch } from './client.js';
import { capturePayPalOrder, getPayPalOrder, orderCustomId, parseCustomId, paypalIssue, reconcileAction } from './events.js';
import { moveShare, type MoveResult } from '../domain/shares.js';
import { splitPath, type ParticipantDoc } from '../domain/splits.js';

/**
 * Reads one share's order from PayPal, captures it if the friend approved,
 * and moves the share to match, settling the split if it was the last. The
 * return page runs this the moment the friend is back (capture on return is
 * the primary signal); the webhook and the reconcile sweep run it too, so
 * whichever lands first wins and the rest find nothing to do. Throws on
 * PayPal errors other than already-captured and declined.
 */
export async function reconcileShare(
  paypal: PayPalFetch,
  ref: DocumentReference,
  paypalOrderId: string,
  source: 'return' | 'webhook' | 'reconcile' | 'expiry',
): Promise<MoveResult> {
  let body = await getPayPalOrder(paypal, paypalOrderId);
  let action = reconcileAction(body);
  if (action.kind === 'capture') {
    try {
      body = await capturePayPalOrder(paypal, paypalOrderId, ref.id);
    } catch (err) {
      const issue = paypalIssue(err);
      if (issue === 'ORDER_ALREADY_CAPTURED') {
        body = await getPayPalOrder(paypal, paypalOrderId);
      } else if (issue === 'INSTRUMENT_DECLINED') {
        action = { kind: 'move', status: 'declined', captureId: null };
      } else {
        throw err;
      }
    }
    if (action.kind === 'capture') action = reconcileAction(body);
  }
  if (action.kind !== 'move') return { moved: false, reason: 'same' };
  return moveShare(ref, {
    to: action.status,
    paypalOrderId,
    captureId: action.captureId,
    ledger: {
      id: `${source}-${paypalOrderId}-${action.status}`,
      eventType: source,
      paypalResourceId: action.captureId,
      amountMinor: null,
      raw: { source, status: action.status },
      signatureVerified: false,
      processingError: null,
    },
  });
}

/**
 * Finds the share a PayPal order belongs to. custom_id names it outright;
 * failing that, the stored order id, through a collection-group query that
 * needs the `participants.paypalOrderId` exemption in firestore.indexes.json.
 * If that query fails (the exemption not deployed yet: the payee spike's
 * return page did exactly this), PayPal's own order still carries custom_id.
 */
export async function locateShare(
  db: Firestore,
  ids: { customId: string | null; paypalOrderId: string | null },
  paypal?: PayPalFetch,
): Promise<{ ref: DocumentReference; person: ParticipantDoc } | null> {
  const byPath = async (customId: string | null) => {
    const custom = parseCustomId(customId);
    if (!custom) return null;
    const ref = db.doc(`${splitPath(custom.organiserId, custom.splitId)}/participants/${custom.participantId}`);
    const snap = await ref.get();
    return snap.exists ? { ref, person: { ...(snap.data() as ParticipantDoc), id: snap.id } } : null;
  };

  const direct = await byPath(ids.customId);
  if (direct || !ids.paypalOrderId) return direct;
  try {
    const found = await db.collectionGroup('participants').where('paypalOrderId', '==', ids.paypalOrderId).limit(1).get();
    const doc = found.docs[0];
    if (doc) return { ref: doc.ref, person: { ...(doc.data() as ParticipantDoc), id: doc.id } };
  } catch (err) {
    console.error(JSON.stringify({ source: 'paypal_locate', issue: err instanceof Error ? err.message.slice(0, 120) : 'error' }));
  }
  if (!paypal) return null;
  return byPath(orderCustomId(await getPayPalOrder(paypal, ids.paypalOrderId)));
}
