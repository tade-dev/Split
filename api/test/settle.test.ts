import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { settleIfDone } from '../src/domain/lock.js';
import { assertShareTransition, moveShare } from '../src/domain/shares.js';
import { SPLIT, person, seedCollecting, splitStatus, statusOf } from './shares-fixture.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-settle-test' });
  db = getFirestore();
});

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

describe('assertShareTransition', () => {
  it('lets an open share move on, and never reopens a paid one', () => {
    expect(() => assertShareTransition('link_opened', 'paid')).not.toThrow();
    expect(() => assertShareTransition('processing', 'pending')).not.toThrow();
    expect(() => assertShareTransition('pending', 'declined')).not.toThrow();
    expect(() => assertShareTransition('declined', 'owes')).not.toThrow();
    expect(() => assertShareTransition('declined', 'paid')).not.toThrow();
    for (const to of ['owes', 'pending', 'declined', 'processing'] as const) {
      expect(() => assertShareTransition('paid', to)).toThrow(/paid cannot become/);
    }
    expect(() => assertShareTransition('claimed', 'paid')).toThrow();
    expect(() => assertShareTransition('on_us', 'paid')).toThrow();
  });
});

describe('settleIfDone', () => {
  it('settles only when every share is paid, paid in cash or on us', async () => {
    await seedCollecting(db, { josh: { status: 'paid_cash' } });
    const run = (status: 'paid' | 'pending') =>
      db.runTransaction((tx) => settleIfDone(tx, db.doc(SPLIT), { participantId: 'dan', status }));
    expect(await run('pending')).toBe(false);
    expect(await splitStatus(db)).toBe('collecting');
    expect(await run('paid')).toBe(true);
    expect(await splitStatus(db)).toBe('settled');
    // Already settled: nothing more is written.
    expect(await run('paid')).toBe(false);
  });

  it('settles once when the last two captures land at the same moment', async () => {
    await seedCollecting(db);
    const [dan, josh] = await Promise.all([
      moveShare(person(db, 'dan'), { to: 'paid', paypalOrderId: 'PPDAN' }),
      moveShare(person(db, 'josh'), { to: 'paid', paypalOrderId: 'PPJOSH' }),
    ]);
    expect(dan.moved && josh.moved).toBe(true);
    const settledBy = [dan, josh].filter((r) => r.moved && r.settled);
    expect(settledBy).toHaveLength(1);
    expect(await statusOf(db, 'dan')).toBe('paid');
    expect(await statusOf(db, 'josh')).toBe('paid');
    expect(await splitStatus(db)).toBe('settled');
  });

  it('settles from whichever lands last, however many rounds it takes', async () => {
    await seedCollecting(db);
    const first = await moveShare(person(db, 'dan'), { to: 'paid', paypalOrderId: 'PPDAN' });
    expect(first).toEqual({ moved: true, settled: false });
    expect(await splitStatus(db)).toBe('collecting');
    const last = await moveShare(person(db, 'josh'), { to: 'paid', paypalOrderId: 'PPJOSH' });
    expect(last).toEqual({ moved: true, settled: true });
  });
});

describe('moveShare', () => {
  it('ignores an order the share no longer holds', async () => {
    await seedCollecting(db);
    expect(await moveShare(person(db, 'dan'), { to: 'paid', paypalOrderId: 'PPOLD' })).toEqual({ moved: false, reason: 'superseded' });
    expect(await statusOf(db, 'dan')).toBe('link_opened');
  });

  it('reports a move the table refuses without writing it', async () => {
    await seedCollecting(db, { dan: { status: 'paid' } });
    const out = await moveShare(person(db, 'dan'), { to: 'declined', paypalOrderId: 'PPDAN' });
    expect(out).toMatchObject({ moved: false, reason: 'invalid' });
    expect(await statusOf(db, 'dan')).toBe('paid');
  });
});
