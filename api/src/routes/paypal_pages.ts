import { Router } from 'express';
import type { Firestore } from 'firebase-admin/firestore';
import { buyerPage, buyerStatusLine } from '../paypal/buyer_page.js';
import type { PayPalFetch } from '../paypal/client.js';
import { OPEN_STATUSES, reconcileOrder } from '../paypal/reconcile.js';
import type { OrderDoc, OrderStatus } from '../domain/orders.js';

const ORDER_TOKEN = /^[A-Za-z0-9]{1,40}$/;

function sendPage(res: { type: (t: string) => void; set: (k: string, v: string) => void; send: (b: string) => void }, html: string) {
  res.type('html');
  res.set('Cache-Control', 'no-store');
  res.set('X-Content-Type-Options', 'nosniff');
  res.send(html);
}

/**
 * Shop name and a coarse status for a PayPal order id.
 * Nothing else from the order is returned: no buyer, no amount, no ids.
 */
async function lookup(
  db: Firestore,
  token: string,
  paypal?: PayPalFetch,
): Promise<{ shop: string | null; status: string | null; organiserId?: string | undefined; orderId?: string | undefined }> {
  if (!ORDER_TOKEN.test(token)) return { shop: null, status: null };
  const found = await db.collectionGroup('orders').where('paypalOrderId', '==', token).limit(1).get();
  const doc = found.docs[0];
  if (!doc) return { shop: null, status: null };
  const organiserId = doc.ref.parent.parent?.id;
  let shop: string | null = null;
  if (organiserId) shop = await shopName(db, organiserId);
  let status = doc.get('status');
  // The buyer just approved. Capture now rather than wait for a webhook that
  // a seller-payee order may never send. Best effort: the page still shows.
  if (paypal && organiserId && OPEN_STATUSES.includes(status as OrderStatus)) {
    try {
      if (await reconcileOrder(paypal, doc.ref, doc.id, status as OrderStatus, token)) {
        status = (await doc.ref.get()).get('status');
      }
    } catch (err) {
      console.error('paypal return capture failed', err instanceof Error ? err.message.slice(0, 160) : 'error');
    }
  }
  return { shop, status: typeof status === 'string' ? status : null, organiserId, orderId: doc.id };
}

async function shopName(db: Firestore, organiserId: string): Promise<string | null> {
  const seller = await db.doc(`organisers/${organiserId}`).get();
  const name = seller.get('displayName');
  return typeof name === 'string' && name.trim() ? name.trim() : null;
}

export function paypalPagesRouter(db: Firestore, paypal?: PayPalFetch): Router {
  const router = Router();

  router.get('/paypal/return', async (req, res) => {
    const token = typeof req.query.token === 'string' ? req.query.token : '';
    let shop: string | null = null;
    let status: string | null = null;
    try {
      if (token) ({ shop, status } = await lookup(db, token, paypal));
    } catch (err) {
      console.error('paypal return lookup failed', err instanceof Error ? err.name : 'error');
    }
    // A buyer can still approve on a link the shop has closed. Split never
    // captures those, so thanking them for a payment would be untrue.
    if (status === 'cancelled' || status === 'expired') {
      const who = shop ?? 'The shop';
      sendPage(
        res,
        buyerPage({
          title: 'Order closed',
          headline: status === 'cancelled'
            ? `${who} cancelled this order.`
            : 'This checkout link has expired.',
          detail: status === 'cancelled'
            ? 'Nothing was charged. You can close this page.'
            : 'Nothing was charged. Ask the shop for a new link.',
        }),
      );
      return;
    }
    const headline = shop
      ? `Thanks, payment sent to ${shop}.`
      : 'Thanks, payment sent.';
    sendPage(
      res,
      buyerPage({
        title: 'Payment sent',
        headline,
        detail: 'You can close this page.',
        statusLine: buyerStatusLine(status),
      }),
    );
  });

  router.get('/paypal/cancel', (_req, res) => {
    sendPage(
      res,
      buyerPage({
        title: 'Payment cancelled',
        headline: 'Payment cancelled.',
        detail: 'Nothing was charged.',
      }),
    );
  });

  return router;
}
