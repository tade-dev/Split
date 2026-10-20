import { createHmac, timingSafeEqual } from 'node:crypto';
// Sorted's domain/invoice.ts @902dc25, HMAC sign/verify only. The invoice page
// itself is not part of Split. Spec §4 re-keys this to LINK_SECRET over
// organiserId:splitId:participantId in the Week B plan.

const ID = /^[A-Za-z0-9_-]{1,128}$/;

/**
 * The buyer's invoice is a public link, so it carries a signature instead of
 * a stored token: nothing new is written to Firestore, and a guessed seller
 * or order id alone never opens one.
 */
export function invoiceSignature(secret: string, organiserId: string, orderId: string): string {
  return createHmac('sha256', secret)
    .update(`invoice:${organiserId}:${orderId}`)
    .digest('base64url')
    .slice(0, 32);
}

export function verifyInvoiceSignature(
  secret: string,
  organiserId: string,
  orderId: string,
  signature: string,
): boolean {
  if (!ID.test(organiserId) || !ID.test(orderId)) return false;
  const expected = Buffer.from(invoiceSignature(secret, organiserId, orderId));
  const given = Buffer.from(signature);
  return given.length === expected.length && timingSafeEqual(given, expected);
}

export function invoiceUrl(baseUrl: string, secret: string, organiserId: string, orderId: string): string {
  return `${baseUrl}/v1/invoice/${organiserId}/${orderId}/${invoiceSignature(secret, organiserId, orderId)}`;
}
