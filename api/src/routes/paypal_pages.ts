import { Router, type Response } from 'express';
import type { Firestore } from 'firebase-admin/firestore';
import { buyerPage } from '../paypal/buyer_page.js';
import type { PayPalFetch } from '../paypal/client.js';
import { locateShare, reconcileShare } from '../paypal/reconcile.js';
import { shareSignature } from '../domain/links.js';
import { OPEN_SHARE_STATUSES } from '../domain/shares.js';

const ORDER_TOKEN = /^[A-Za-z0-9]{1,40}$/;

function sendPage(res: Response, html: string) {
  res.type('html');
  res.set('Cache-Control', 'no-store');
  res.set('X-Content-Type-Options', 'nosniff');
  res.send(html);
}

/**
 * The friend's page for this share, or null when the token matches no
 * share. On the way it captures: the friend just approved, and for an order
 * paid straight to the organiser that capture may be the only signal Split
 * ever gets (plan Review Focus 6). An order the share no longer holds (one
 * the expiry sweep replaced) is never captured.
 */
async function captureOnReturn(db: Firestore, linkSecret: string, token: string, paypal?: PayPalFetch): Promise<string | null> {
  if (!ORDER_TOKEN.test(token)) return null;
  const found = await locateShare(db, { customId: null, paypalOrderId: token }, paypal);
  if (!found) return null;
  const { ref, person } = found;
  if (paypal && person.paypalOrderId === token && OPEN_SHARE_STATUSES.includes(person.status)) {
    try {
      await reconcileShare(paypal, ref, token, 'return');
    } catch (err) {
      // Best effort: the webhook and the reconcile sweep still land it.
      console.error('paypal return capture failed', err instanceof Error ? err.message.slice(0, 160) : 'error');
    }
  }
  const splitRef = ref.parent.parent!;
  const organiserId = splitRef.parent.parent!.id;
  return `/v1/s/${organiserId}/${splitRef.id}/${ref.id}/${shareSignature(linkSecret, organiserId, splitRef.id, ref.id)}`;
}

export function paypalPagesRouter(db: Firestore, linkSecret: string, paypal?: PayPalFetch): Router {
  const router = Router();

  // PayPal sends the friend here after they approve. Capture, then hand them
  // back to their own page, which reads "Paid. Thanks, Kemi's been told."
  router.get('/paypal/return', async (req, res) => {
    const token = typeof req.query.token === 'string' ? req.query.token : '';
    let back: string | null = null;
    try {
      if (token) back = await captureOnReturn(db, linkSecret, token, paypal);
    } catch (err) {
      console.error('paypal return lookup failed', err instanceof Error ? err.message.slice(0, 160) : 'error');
    }
    if (back) {
      res.set('Cache-Control', 'no-store');
      res.redirect(303, back);
      return;
    }
    sendPage(
      res,
      buyerPage({
        title: 'Payment sent',
        headline: 'Thanks, payment sent.',
        detail: 'Open your link from the group again to see where it stands.',
      }),
    );
  });

  router.get('/paypal/cancel', (_req, res) => {
    sendPage(
      res,
      buyerPage({
        title: 'Payment cancelled',
        headline: 'Payment cancelled.',
        detail: 'Nothing was charged. Your link from the group still works when you are ready.',
      }),
    );
  });

  return router;
}
