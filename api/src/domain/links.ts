import { createHmac, timingSafeEqual } from 'node:crypto';
// Sorted's domain/invoice.ts @902dc25, HMAC sign/verify only, re-keyed to
// LINK_SECRET over organiserId:splitId:participantId (spec §4).

const ID = /^[A-Za-z0-9_-]{1,128}$/;

/**
 * A friend's page is a public link, so it carries a signature instead of a
 * stored token: nothing new is written to Firestore, and guessed ids alone
 * never open one. The `share:` prefix keeps these from ever matching another
 * HMAC made with the same secret.
 */
export function shareSignature(secret: string, organiserId: string, splitId: string, participantId: string): string {
  return createHmac('sha256', secret)
    .update(`share:${organiserId}:${splitId}:${participantId}`)
    .digest('base64url')
    .slice(0, 32);
}

export function verifyShareSignature(
  secret: string,
  organiserId: string,
  splitId: string,
  participantId: string,
  signature: string,
): boolean {
  if (!ID.test(organiserId) || !ID.test(splitId) || !ID.test(participantId)) return false;
  const expected = Buffer.from(shareSignature(secret, organiserId, splitId, participantId));
  const given = Buffer.from(signature);
  return given.length === expected.length && timingSafeEqual(given, expected);
}

/** `{base}/v1/s/{organiserId}/{splitId}/{participantId}/{sig}`. Base is PUBLIC_BASE_URL (plan E7). */
export function shareUrl(baseUrl: string, secret: string, organiserId: string, splitId: string, participantId: string): string {
  return `${baseUrl}/v1/s/${organiserId}/${splitId}/${participantId}/${shareSignature(secret, organiserId, splitId, participantId)}`;
}
