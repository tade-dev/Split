import { Timestamp, type Firestore } from 'firebase-admin/firestore';
import { newParticipant, type ParticipantDoc } from '../src/domain/splits.js';

export const SPLIT = 'organisers/kemi/splits/s1';

/**
 * A locked split, collecting: Kemi and Sam owe nothing, Dan and Josh each
 * have a PayPal order out. Overrides change one person at a time.
 */
export async function seedCollecting(db: Firestore, people: Record<string, Partial<ParticipantDoc>> = {}) {
  await db.doc('organisers/kemi').set({ displayName: 'Kemi' });
  await db.doc(SPLIT).set({ id: 's1', title: 'Friday dinner', status: 'collecting', organiserParticipantId: 'kemi' });
  const base: Record<string, Partial<ParticipantDoc>> = {
    kemi: { isOrganiser: true, status: 'on_us', shareMinor: 3643 },
    dan: { status: 'link_opened', shareMinor: 3923, paypalOrderId: 'PPDAN', approvalUrl: 'https://www.sandbox.paypal.com/checkoutnow?token=PPDAN' },
    josh: { status: 'link_opened', shareMinor: 4542, paypalOrderId: 'PPJOSH', approvalUrl: 'https://www.sandbox.paypal.com/checkoutnow?token=PPJOSH' },
    sam: { status: 'on_us', shareMinor: 0 },
  };
  let order = 0;
  for (const [id, fields] of Object.entries(base)) {
    const doc = newParticipant(id, { name: id[0]!.toUpperCase() + id.slice(1), joinOrder: order++, isOrganiser: id === 'kemi' });
    await db.doc(`${SPLIT}/participants/${id}`).set({
      ...doc,
      claimedAt: Timestamp.now(),
      paypalOrderCreatedAt: fields.paypalOrderId ? Timestamp.fromMillis(Date.now() - 10 * 60 * 1000) : null,
      ...fields,
      ...people[id],
    });
  }
}

export const person = (db: Firestore, id: string) => db.doc(`${SPLIT}/participants/${id}`);
export const statusOf = async (db: Firestore, id: string) => (await person(db, id).get()).get('status') as string;
export const splitStatus = async (db: Firestore) => (await db.doc(SPLIT).get()).get('status') as string;

/** A PayPal order as GET and capture return it. */
export function order(id: string, status: string, capture?: string, customId = `kemi:s1:${id === 'PPDAN' ? 'dan' : 'josh'}`) {
  return {
    id,
    status,
    purchase_units: [{
      custom_id: customId,
      ...(capture ? { payments: { captures: [{ id: `CAP-${id}`, status: capture }] } } : {}),
    }],
  };
}
