import { Router, type Request } from 'express';
import express from 'express';
import { FieldValue, type DocumentReference, type Firestore } from 'firebase-admin/firestore';
import { ApiError } from '../lib/errors.js';
import { recordWebhookFailure } from './health.js';
import type { Env } from '../env.js';
import type { PayPalFetch } from '../paypal/client.js';
import {
  HANDLED_EVENTS,
  parsePayPalEvent,
  paypalIssue,
  statusForEvent,
  verifyWebhookBody,
  type PayPalEvent,
} from '../paypal/events.js';
import { locateShare, reconcileShare } from '../paypal/reconcile.js';
import { moveShare, OPEN_SHARE_STATUSES } from '../domain/shares.js';

export type WebhookDeps = {
  env: Env;
  db: Firestore;
  paypal: PayPalFetch;
};

const SIGNATURE_HEADERS = [
  ['paypal-transmission-id', 'transmissionId'],
  ['paypal-transmission-time', 'transmissionTime'],
  ['paypal-cert-url', 'certUrl'],
  ['paypal-auth-algo', 'authAlgo'],
  ['paypal-transmission-sig', 'transmissionSig'],
] as const;

function signatureHeaders(req: Request): {
  headers: {
    transmissionId: string;
    transmissionTime: string;
    certUrl: string;
    authAlgo: string;
    transmissionSig: string;
  } | null;
  missing: string[];
} {
  const missing: string[] = [];
  const values: Record<string, string> = {};
  for (const [header, key] of SIGNATURE_HEADERS) {
    const value = req.get(header);
    if (!value) missing.push(header);
    else values[key] = value;
  }
  if (missing.length > 0) return { headers: null, missing };
  return {
    headers: {
      transmissionId: values.transmissionId!,
      transmissionTime: values.transmissionTime!,
      certUrl: values.certUrl!,
      authAlgo: values.authAlgo!,
      transmissionSig: values.transmissionSig!,
    },
    missing,
  };
}

function logVerifyFailure(fields: Record<string, string | number | null>): void {
  console.error(JSON.stringify({ source: 'paypal_webhook_verify', ...fields }));
}

function safeIssue(value: string | undefined): string | null {
  if (!value) return null;
  const oneLine = value.replace(/\s+/g, ' ').slice(0, 80);
  if (/bearer|secret|token/i.test(oneLine)) return 'redacted';
  return oneLine;
}

async function recordPayment(
  ref: DocumentReference,
  event: PayPalEvent,
  processingError: string | null,
  refundDue = false,
) {
  await ref.collection('paymentEvents').doc(event.id).set({
    id: event.id,
    eventType: event.eventType,
    paypalResourceId: event.resourceId,
    amountMinor: event.amountMinor,
    raw: { id: event.id, event_type: event.eventType, resourceId: event.resourceId },
    signatureVerified: true,
    receivedAt: FieldValue.serverTimestamp(),
    processedAt: FieldValue.serverTimestamp(),
    processingError,
    // Money landed on an order the share no longer holds (the expiry sweep
    // replaced it). The organiser refunds it; the share does not move.
    ...(refundDue ? { refundDue: true } : {}),
  });
}

export function webhooksRouter(deps: WebhookDeps): Router {
  const router = Router();

  router.post(
    '/webhooks/paypal',
    express.raw({ type: 'application/json', limit: '1mb' }),
    async (req, res, next) => {
      const raw = Buffer.isBuffer(req.body) ? req.body.toString('utf8') : '';
      const { headers, missing } = signatureHeaders(req);
      if (!raw || !headers) {
        recordWebhookFailure();
        logVerifyFailure({
          reason: !raw ? 'missing_body' : 'missing_headers',
          missingHeaders: missing.join(','),
          contentType: (req.get('content-type') ?? '').slice(0, 120),
          bodyBytes: Buffer.isBuffer(req.body) ? req.body.length : 0,
        });
        next(new ApiError(401, 'UNAUTHENTICATED', 'PayPal could not verify that event.'));
        return;
      }

      let verified: { verification_status?: string };
      try {
        verified = (await deps.paypal('/v1/notifications/verify-webhook-signature', {
          method: 'POST',
          rawBody: verifyWebhookBody(raw, headers, deps.env.PAYPAL_WEBHOOK_ID),
        })) as { verification_status?: string };
      } catch (err) {
        recordWebhookFailure();
        const paypalStatus = err instanceof ApiError && err.details && typeof err.details === 'object'
          ? (err.details as { status?: unknown }).status
          : undefined;
        logVerifyFailure({
          reason: 'paypal_http',
          httpStatus: typeof paypalStatus === 'number' ? paypalStatus : null,
          issue: safeIssue(paypalIssue(err)),
          bodyBytes: Buffer.byteLength(raw),
        });
        next(new ApiError(502, 'PAYPAL_UNAVAILABLE', 'PayPal could not verify that event.'));
        return;
      }

      if (verified.verification_status !== 'SUCCESS') {
        recordWebhookFailure();
        logVerifyFailure({
          reason: 'verification_status',
          verificationStatus: verified.verification_status ?? 'missing',
          bodyBytes: Buffer.byteLength(raw),
        });
        next(new ApiError(401, 'UNAUTHENTICATED', 'PayPal could not verify that event.'));
        return;
      }

      let parsedJson: unknown;
      try {
        parsedJson = JSON.parse(raw);
      } catch {
        next(new ApiError(400, 'VALIDATION_FAILED', 'That webhook body is not JSON.'));
        return;
      }
      const event = parsePayPalEvent(parsedJson);
      if (!event) {
        next(new ApiError(400, 'VALIDATION_FAILED', 'That webhook is missing an id.'));
        return;
      }

      const ledger = deps.db.doc(`webhookEvents/${event.id}`);
      try {
        const gate = await deps.db.runTransaction(async (tx) => {
          const snap = await tx.get(ledger);
          if (snap.exists && snap.get('handled') === true) return 'duplicate' as const;
          tx.set(
            ledger,
            {
              id: event.id,
              eventType: event.eventType,
              receivedAt: snap.exists ? snap.get('receivedAt') : FieldValue.serverTimestamp(),
              handled: false,
              splitId: null,
              participantId: null,
            },
            { merge: true },
          );
          return 'process' as const;
        });
        if (gate === 'duplicate') {
          res.json({ received: true });
          return;
        }

        if (!HANDLED_EVENTS.has(event.eventType)) {
          await ledger.set({ handled: true }, { merge: true });
          res.json({ received: true });
          return;
        }

        const located = await locateShare(
          deps.db,
          { customId: event.customId, paypalOrderId: event.paypalOrderId },
          deps.paypal,
        );
        if (!located) {
          await ledger.set(
            { handled: true, processingError: 'No matching share.' },
            { merge: true },
          );
          res.json({ received: true });
          return;
        }

        const { ref, person } = located;
        const where = { splitId: ref.parent.parent!.id, participantId: ref.id };
        const paypalOrderId = event.paypalOrderId ?? person.paypalOrderId;
        // An order the share no longer holds was replaced by the expiry sweep.
        // Nothing on it may move the share; a capture on it is real money and
        // is flagged for refund.
        if (!paypalOrderId || paypalOrderId !== person.paypalOrderId) {
          const captured = event.eventType === 'PAYMENT.CAPTURE.COMPLETED';
          const reason = captured
            ? 'Captured on a replaced PayPal order. Refund it in PayPal.'
            : 'PayPal order was replaced. Ignored.';
          console.warn(JSON.stringify({
            source: 'paypal_superseded', ...where, paypalOrderId: event.paypalOrderId, eventType: event.eventType,
          }));
          await recordPayment(ref, event, reason, captured);
          await ledger.set({ handled: true, ...where, processingError: reason }, { merge: true });
          res.json({ received: true });
          return;
        }

        let processingError: string | null = null;
        if (event.eventType === 'CHECKOUT.ORDER.APPROVED') {
          // Usually the return page has already captured; this finds it done.
          if (OPEN_SHARE_STATUSES.includes(person.status)) {
            await reconcileShare(deps.paypal, ref, paypalOrderId, 'webhook');
          }
        } else {
          const target = statusForEvent(event.eventType);
          if (target) {
            const out = await moveShare(ref, { to: target, paypalOrderId, captureId: event.captureId });
            if (!out.moved && out.reason === 'invalid') processingError = out.message ?? null;
          }
        }

        await recordPayment(ref, event, processingError);
        await ledger.set({ handled: true, ...where }, { merge: true });
        res.json({ received: true });
      } catch (err) {
        next(err);
      }
    },
  );

  return router;
}
