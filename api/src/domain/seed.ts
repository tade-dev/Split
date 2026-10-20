import { FieldValue, type Firestore, type Timestamp } from 'firebase-admin/firestore';
import { loadDemoSplit, type DemoSplit } from './demo.js';
import { receiptProblems } from './receipt.js';
import { prepareSplit } from './splits.js';

/** organisers/{uid}. Spec §2. */
export type OrganiserDoc = {
  id: string;
  /** The name friends see: "Kemi". */
  displayName: string;
  /** Null pays the shared sandbox merchant. */
  paypalEmail: string | null;
  demoSeeded: boolean;
  createdAt?: Timestamp;
};

/**
 * Creates the organiser on first launch and, for the demo, seeds the Little
 * Bao House split in draft. Idempotent and race-safe: a judge reloading the
 * hosted build twice at once still gets exactly one demo split, because the
 * check and the write share a transaction.
 */
export async function bootstrapOrganiser(
  db: Firestore,
  organiserId: string,
  opts: { demo: boolean },
  demo: DemoSplit = loadDemoSplit(),
): Promise<{ organiser: OrganiserDoc; seededSplitId: string | null }> {
  const ref = db.doc(`organisers/${organiserId}`);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const existing = snap.exists ? (snap.data() as OrganiserDoc) : null;
    const organiser: OrganiserDoc = existing
      ? { ...existing, id: organiserId }
      : { id: organiserId, displayName: opts.demo ? demo.organiserName : 'You', paypalEmail: null, demoSeeded: false };

    let seededSplitId: string | null = null;
    if (opts.demo && !organiser.demoSeeded) {
      const { split, write } = prepareSplit(db, organiserId, {
        title: demo.title,
        merchant: demo.merchant,
        receiptDate: demo.receiptDate,
        receipt: demo.receipt,
        receiptAmbiguities: receiptProblems(demo.receipt),
        extractionModel: 'seed',
        sourceRef: null,
        organiserName: organiser.displayName,
      });
      write(tx);
      seededSplitId = split.id;
      organiser.demoSeeded = true;
    }

    if (!existing) {
      tx.set(ref, { ...organiser, createdAt: FieldValue.serverTimestamp() });
    } else if (seededSplitId) {
      tx.update(ref, { demoSeeded: true });
    }
    return { organiser, seededSplitId };
  });
}
