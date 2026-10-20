# Split Foundations and Money: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** By Sun 26 Oct, an organiser can open the hosted web build, photograph a bill (or tap **Try a sample bill**), watch it being read, and land on a Receipt screen that has proved the lines add up to the printed total. Underneath, `allocate()` turns any receipt, claims and rules into shares to the penny that always sum to the bill.

**Architecture:** `api/src/domain/allocate.ts` is a pure function: no I/O, no clock, no Firestore. The vision model reads the receipt (`ai/extract_receipt.ts`). Code checks the arithmetic (`domain/receipt.ts`) and code computes every share (`allocate.ts` over `money.ts`'s `allocateLargestRemainder`). Every write that touches the receipt, claims, rules or participants recomputes `computed` in the same Firestore transaction (`domain/splits.ts`), and the app only ever renders `computed`. Clients read Firestore through `StreamProvider`s and never write it.

**Tech Stack:** Node 22 + TypeScript 7, Express 5, Zod 4, Vitest 5 + Supertest, **fast-check 4.10.2** (new), Firebase Admin 14; Flutter 3.47 / Dart 3.13, Riverpod 3, GoRouter 18, freezed; OpenAI `gpt-5.5` (pinned in env, re-verified in Task 7); Render `starter`; Firebase Hosting for the web build.

**Spec:** `docs/superpowers/specs/2026-10-20-split-design.md`, especially §2 (data model), §3 (allocation, golden fixture), §4 endpoints 1, 2, 4, 5 and 12, §5 (week-1 PayPal verification), §7.1 (receipt extraction) and §10 Week A.

**Design:** `docs/design/DESIGN.md` and `docs/design/screens/Main`, `Home`, `Scan`, `Receipt`. Reading has no screen of its own; it reuses Sorted's Reading pattern.

**Prior art, already in this repo (read before writing anything):** `api/src/domain/money.ts`, `api/src/ai/client.ts` (`generateStructured`, `toDataUri`, no `temperature`), `api/src/lib/{auth,errors,image_type}.ts`, `api/test/emulator-guard.ts` and the supertest + fake-transport style of `api/test/webhooks.test.ts`; `app/lib/core/theme/*`, `app/lib/core/motion/*`, `app/lib/widgets/*`, `app/lib/core/api_client.dart` (`postImages`, `patchJson`), `app/lib/features/scan/scan_screen.dart` (`scanReaderProvider` seam). `docs/reused-from-sorted.md` says where each came from.

**Proven before writing:** every line of TypeScript in Tasks 1–4 and 6, and 8–11, was run in a scratch copy of `api/` on 2026-10-20. That copy had 290 passing tests: the 228 copied ones plus the 62 new ones below, against the Firestore emulator, with `tsc --noEmit` clean. The golden fixture was also recomputed independently in Python and matched the spec's table to the penny.

## Global Constraints

- **Money is integer pence plus `currency: 'GBP'`.** No floats anywhere money is computed. `allocateLargestRemainder` works in `BigInt`.
- **No share or total ever comes from the LLM.** The model reports what is printed and who had what. `receipt.ts` checks the arithmetic; `allocate.ts` computes every share.
- **`Σ finalMinor == receipt.printedTotalMinor`, always.** A receipt that does not add up is a user problem (`ok: false`); a broken sum after that is a bug (`AllocationInvariantError`).
- **Unknowns become ambiguities, never guesses.** An unread price or total is `null`, never `0`.
- **Never set `temperature`** on an OpenAI call. `gpt-5.5` rejects it.
- **Clients never write Firestore.** All writes go through the API's Admin SDK.
- **Recompute `computed` in the same transaction** as any write to the receipt, claims, rules or participants.
- Every route under `/v1`; every error is exactly `{ error: { code, message, details? } }`. New code: `SPLIT_STATE_INVALID` (409).
- **No hex values in widgets.** No literal durations or `Curves.` outside `app/lib/core/motion`. That includes `Timer` intervals, which `motion_discipline_test` does not catch; put them in `SplitDurations` anyway. `SplitSprings.bouncy` stays at exactly two uses.
- Names and numbers from the screens (Kemi, Little Bao House, £154.69) live in `samples/demo-split.json` and nowhere in widget code.
- UK English. "PayPal" never appears in the product name, logo or app title.
- Anything verified against a live system goes in `docs/verified-facts.md` with the date.
- Run the emulator with `npm run emulators` from `api/` (JDK 21+). Restart it if hooks start timing out.

## Review Focus

The spec implies these failure modes but does not spell them out. Each one has a test in the task that owns it.

1. **Two claimants below `qty`.** "Lager ×3: Josh 1, Dan 1" leaves one lager unaccounted for. Spec §3 stage 1 counts any line with two or more claimants as shared, so it splits 1:1 and nobody is asked. This plan implements the spec as written and pins it in a test (*Task 4*). The fix belongs in Week B's claim validation (§7.2, "no line is over-claimed"), which should raise a `qty_unclear` question before such claims are written. **Decision needed: see the end of this plan.**
2. **A receipt that does not add up must never reach allocation.** `allocate()` re-runs the receipt checks first and returns `price_conflict` instead of throwing. Otherwise a misread receipt would surface as a 500 "invariant broken" when it is the organiser's to fix (*Tasks 3, 4*).
3. **Rounding drift.** BigInt arithmetic, largest remainder at every stage, ties to the organiser and then join order, and property tests over 500 random bills (*Tasks 2, 4*).
4. **Discounts taking someone below zero.** Possible when a discount is larger than one person's items and that person opted out of service. They are clamped to 0 and the excess redistributed; the property tests confirm no final is ever negative (*Task 4*).
5. **Rules that leave nobody to pay.** Everyone on us, an empty `onUsPaidBy`, or everyone opted out of service. Each one is a blocking problem, not a division by zero or a silent organiser charge (*Task 4*).
6. **The model "correcting" the bill.** The prompt forbids it. Code derives every blocking problem from the numbers, and the model's own questions are stored as non-blocking notes. A misread quantity with the right line total changes who claims what but never the money (*Task 6*).
7. **`null` read as `0`.** An unread line price or total of `0` would make a wrong bill look free and might even add up. Both stay `null` and block (*Tasks 3, 6*).
8. **Bootstrap twice at once.** A judge reloading the hosted build fires two bootstraps. The check and the seed share a transaction, so exactly one demo split is ever created (*Task 10*).

## Decisions this plan takes where the spec is silent

Each is small, but they shape data that later plans read. Veto any before execution starts.

| # | Gap | Decision |
|---|---|---|
| D1 | How the on-us person's breakdown adds up | `sharedFromOnUsMinor` is **negative** for them (−2910 for Sam), so `items + shared + service + tip − discount = final` holds for everyone and the column sums to 0 |
| D2 | `portionLabel` values | `''` for a whole line, `'2 of 3'` when the claimants' weights equal the quantity, `'share'` otherwise. These match Breakdown ("Prawn crackers share") and Claim ("Lager, 2 of 3") |
| D3 | Problem kinds | Adds one kind to Sorted's `Ambiguity`: `'unclaimed'`. Copy: "Nobody claimed the prawn crackers" with options "Share between all 5" and "Ask the group" (the screen's wording), and "Lager: 1 of 3 unclaimed" |
| D4 | Does service opt-out also exempt from the tip? | Yes. The tip follows the service mode **and** the same eligible payers |
| D5 | Proportional split when every eligible payer had £0 | Falls back to even rather than dividing by zero |
| D6 | Everyone opted out of service | Blocking problem: "Someone has to cover it". The organiser is not charged silently |
| D7 | The model's own ambiguities | Stored with `blocking: false`. Blocking ones come only from code (unread price, unread total, mismatch) |
| D8 | When the receipt is editable | `draft` only. Rules are editable in `draft` and `claiming`, and frozen from `lock` |
| D9 | Reading route | `/split/reading`, not `/split/:id/reading`, because the split has no id until the synchronous scan returns |
| D10 | Default title | "Friday's bill" from the receipt date, or "Your bill" |
| D11 | **Try a sample bill** vs bootstrap `demo` | *Try a sample bill* sends the bundled `little-bao-house.png` through the real `/splits/scan`, so a judge watches the AI read it. `bootstrap { demo: true }` seeds the same bill from `samples/demo-split.json` in `draft` (receipt and organiser only; people and claims arrive with Week B) |
| D12 | Participant colours 5–7 | `#FF9EC7`/`#4D0A2B`, `#7FD3E6`/`#053A45`, `#B9D46C`/`#2E3A05`. Luminance 0.50, 0.57 and 0.59, inside 0–4's 0.48–0.61 band; text contrast 7.9, 7.3 and 7.4 to 1 |
| D13 | Web hosting | Firebase Hosting. `firebase.json` is already there, and it does not sleep |

---

## File Structure

| File | Responsibility |
|---|---|
| `samples/demo-split.json` | **The** Little Bao House bill: golden fixture inputs and demo seed, one source |
| `samples/receipts/*.html`, `*.png` | Four hand-written receipts and their renders (§8) |
| `scripts/render-receipts.mjs` | Renders the receipt HTML to PNG with the preinstalled Chromium |
| `api/src/domain/money.ts` | + `allocateLargestRemainder()` |
| `api/src/domain/split.ts` | `Receipt`, `ReceiptLine`, `Claim`, `Rules`, `Breakdown`, `Allocation` types |
| `api/src/domain/receipt.ts` | `lineIdFor`, `receiptSumMinor`, `receiptProblems`: the add-up check |
| `api/src/domain/allocate.ts` | `allocate()`: the heart of Split |
| `api/src/domain/demo.ts` | Loads and validates `samples/demo-split.json` |
| `api/src/ai/schemas.ts` | + `'unclaimed'` kind, + `receiptExtractionSchema` |
| `api/src/ai/extract_receipt.ts` | Vision prompt, strict JSON schema, `toDraftReceipt()` |
| `api/src/domain/splits.ts` | `SplitDoc`, `ParticipantDoc`, `prepareSplit`/`createSplit`, `readSplit`, `computeFor`, `toApi` |
| `api/src/domain/seed.ts` | `bootstrapOrganiser()`: organiser doc and demo split, race-safe |
| `api/src/routes/splits.ts` | `POST /splits/scan`, `PATCH /splits/:id/receipt`, `PATCH /splits/:id/rules` |
| `api/src/routes/session.ts` | `POST /session/bootstrap` |
| `api/test/*` | One suite per module above (names in each task) |
| `docs/verified-facts.md` | New for Split: Firebase, Render, PayPal payee and model spike results |
| `app/lib/core/theme/split_colors.dart` | + `participants` (8 fill/text pairs) |
| `app/lib/widgets/avatar.dart` | Participant initial circle, sizes 24–44, stack overlap |
| `app/lib/models/{receipt,split,participant,ambiguity}.dart` | freezed models over the API and Firestore shapes |
| `app/lib/data/splits_repository.dart` | API calls (`scan`, `patchReceipt`, `patchRules`) and Firestore streams |
| `app/lib/providers/splits_providers.dart` | `splitsProvider`, `splitProvider`, `ScanController` |
| `app/lib/features/scan/scan_screen.dart` | Receipt copy, at most two photos |
| `app/lib/features/scan/reading_screen.dart` | The ticking checklist |
| `app/lib/features/split/receipt_screen.dart` | Check the bill |
| `app/lib/features/home/home_screen.dart` | Home skeleton |
| `app/lib/router.dart` | `/`, `/scan`, `/split/reading`, `/split/:id/receipt`, `/split/:id/people` (placeholder) |
| `app/assets/samples/little-bao-house.png` | Bundled for *Try a sample bill* |

---

### Task 1: The golden fixture, as a failing test

The plan starts here because everything else in Split exists to put these numbers on screen. Tasks 1–3 are one red-to-green cycle: this test stays red until Task 3, and its files are committed with Task 3.

**Files:**
- Create: `samples/demo-split.json`, `api/src/domain/split.ts`, `api/src/domain/demo.ts`
- Test: `api/test/allocate-golden.test.ts`

**Interfaces:**
- Consumes: `Ambiguity` from `src/ai/schemas.ts`; `Minor` from `src/domain/money.ts`.
- Produces, from `src/domain/split.ts`: `ReceiptLine`, `Receipt`, `Claim`, `Rules`, `DEFAULT_RULES`, `AllocParticipant`, `BreakdownLine`, `Breakdown`, `Allocation`.
- Produces, from `src/domain/demo.ts`: `type DemoParticipant = AllocParticipant & { name; colourIndex }`, `type DemoSplit = { organiserName, title, merchant, receiptDate, receipt, participants, claims, rules }`, `loadDemoSplit(path?): DemoSplit`. Seed participant ids are lower-cased first names (`kemi`, `amaka`); line ids come from `lineIdFor` (Task 3), so `lager-8`, `pork-bao-1`.

- [ ] **Step 1: Write the fixture file**

Create `samples/demo-split.json`. Claims sit on each line so a human can check it against the spec's table at a glance:

```json
{
  "organiser": { "displayName": "Kemi" },
  "title": "Friday dinner",
  "merchant": "Little Bao House",
  "receiptDate": "2026-10-02",
  "people": ["Kemi", "Amaka", "Josh", "Dan", "Sam"],
  "lines": [
    { "name": "Prawn crackers", "qty": 1, "lineTotalMinor": 550, "claims": { "Kemi": 1, "Amaka": 1, "Josh": 1, "Dan": 1, "Sam": 1 } },
    { "name": "Pork bao", "qty": 3, "lineTotalMinor": 1800, "claims": { "Kemi": 1, "Josh": 1, "Dan": 1 } },
    { "name": "Chicken katsu", "qty": 1, "lineTotalMinor": 1450, "claims": { "Kemi": 1 } },
    { "name": "Tofu rice bowl", "qty": 1, "lineTotalMinor": 1200, "claims": { "Amaka": 1 } },
    { "name": "Beef ramen", "qty": 1, "lineTotalMinor": 1500, "claims": { "Josh": 1 } },
    { "name": "Spicy miso ramen", "qty": 1, "lineTotalMinor": 1500, "claims": { "Dan": 1 } },
    { "name": "Prawn ramen", "qty": 1, "lineTotalMinor": 1500, "claims": { "Sam": 1 } },
    { "name": "Lychee sour", "qty": 2, "lineTotalMinor": 1900, "claims": { "Amaka": 1, "Sam": 1 } },
    { "name": "Lager", "qty": 3, "lineTotalMinor": 1650, "claims": { "Josh": 2, "Dan": 1 } },
    { "name": "Lemonade", "qty": 2, "lineTotalMinor": 700, "claims": { "Kemi": 1, "Sam": 1 } }
  ],
  "serviceChargeMinor": 1719,
  "serviceChargeLabel": "12.5% discretionary",
  "tipMinor": 0,
  "discounts": [],
  "printedTotalMinor": 15469,
  "rules": { "serviceMode": "proportional", "onUs": ["Sam"], "onUsPaidBy": null, "serviceOptOut": [] }
}
```

- [ ] **Step 2: Write the domain types**

Create `api/src/domain/split.ts`. `printedTotalMinor` and `lineTotalMinor` are nullable only so a draft can hold an unread value. See Review Focus 7.

```ts
import type { Ambiguity } from '../ai/schemas.js';
import type { Minor } from './money.js';

/** One printed line. The printed line total is the truth; unit price is display only. */
export type ReceiptLine = {
  /** Stable slug plus index, e.g. `lager-8`. */
  id: string;
  name: string;
  qty: number;
  /** Null only while a draft has an unreadable price. allocate() refuses it. */
  lineTotalMinor: Minor | null;
};

export type Receipt = {
  lines: ReceiptLine[];
  serviceChargeMinor: Minor;
  serviceChargeLabel: string | null;
  tipMinor: Minor;
  /** Each amount is positive and is taken off the bill. */
  discounts: { label: string; amountMinor: Minor }[];
  /** Null only while a draft has an unreadable total. allocate() refuses it. */
  printedTotalMinor: Minor | null;
  currency: 'GBP';
};

export type Claim = {
  participantId: string;
  weight: number;
  source: 'ai' | 'organiser' | 'friend';
};

export type Rules = {
  serviceMode: 'proportional' | 'even';
  onUs: string[];
  /** Null means every participant who is not on us, the organiser included. */
  onUsPaidBy: string[] | null;
  serviceOptOut: string[];
};

export const DEFAULT_RULES: Rules = {
  serviceMode: 'proportional',
  onUs: [],
  onUsPaidBy: null,
  serviceOptOut: [],
};

export type AllocParticipant = { id: string; joinOrder: number; isOrganiser: boolean };

export type BreakdownLine = { lineId: string; minor: Minor; portionLabel: string };

export type Breakdown = {
  /** What their own claims cost, before anyone is on us. */
  itemsMinor: Minor;
  /**
   * Positive for a payer covering someone on us. For the on-us person it is
   * minus their own items, so the formula below still holds and the column
   * sums to zero.
   */
  sharedFromOnUsMinor: number;
  serviceMinor: Minor;
  tipMinor: Minor;
  /** Positive: the amount taken off this person's share. */
  discountMinor: Minor;
  /** itemsMinor + sharedFromOnUsMinor + serviceMinor + tipMinor − discountMinor. */
  finalMinor: Minor;
  lines: BreakdownLine[];
};

export type Allocation =
  | { ok: true; perParticipant: Record<string, Breakdown>; totalMinor: Minor }
  | { ok: false; problems: Ambiguity[] };
```

- [ ] **Step 3: Write the fixture loader**

Create `api/src/domain/demo.ts`. It validates the file with Zod, because a typo in a seed file should fail loudly at load, not as a wrong share on screen.

```ts
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { z } from 'zod';
import { lineIdFor } from './receipt.js';
import type { AllocParticipant, Claim, Receipt, Rules } from './split.js';

/**
 * The Little Bao House bill: the golden fixture in spec §3 and the demo split
 * a judge sees. One file feeds both the allocation test and the seed, so the
 * numbers on screen and the numbers under test cannot drift apart.
 */
const DEMO_PATH = fileURLToPath(new URL('../../../samples/demo-split.json', import.meta.url));

const minor = z.number().int().nonnegative();
const fileSchema = z.object({
  organiser: z.object({ displayName: z.string().min(1) }),
  title: z.string().min(1),
  merchant: z.string().min(1),
  receiptDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  people: z.array(z.string().min(1)).min(1),
  lines: z.array(z.object({
    name: z.string().min(1),
    qty: z.number().int().min(1),
    lineTotalMinor: minor,
    claims: z.record(z.string(), z.number().int().min(1)),
  })).min(1),
  serviceChargeMinor: minor,
  serviceChargeLabel: z.string().nullable(),
  tipMinor: minor,
  discounts: z.array(z.object({ label: z.string(), amountMinor: minor })),
  printedTotalMinor: minor,
  rules: z.object({
    serviceMode: z.enum(['proportional', 'even']),
    onUs: z.array(z.string()),
    onUsPaidBy: z.array(z.string()).nullable(),
    serviceOptOut: z.array(z.string()),
  }),
});

export type DemoParticipant = AllocParticipant & { name: string; colourIndex: number };

export type DemoSplit = {
  organiserName: string;
  title: string;
  merchant: string;
  receiptDate: string;
  receipt: Receipt;
  participants: DemoParticipant[];
  claims: Record<string, Claim[]>;
  rules: Rules;
};

/** Seed ids are the lower-cased first name: `kemi`, `amaka`. */
const personId = (name: string) => name.toLowerCase().replace(/[^a-z0-9]+/g, '-');

export function loadDemoSplit(path: string = DEMO_PATH): DemoSplit {
  const file = fileSchema.parse(JSON.parse(readFileSync(path, 'utf8')));
  const ids = new Map(file.people.map((name) => [name, personId(name)]));
  const id = (name: string) => {
    const found = ids.get(name);
    if (!found) throw new Error(`demo-split.json names ${name}, who is not in people`);
    return found;
  };

  const lines = file.lines.map((l, i) => ({ id: lineIdFor(l.name, i), name: l.name, qty: l.qty, lineTotalMinor: l.lineTotalMinor }));
  const claims: Record<string, Claim[]> = {};
  file.lines.forEach((l, i) => {
    claims[lines[i]!.id] = Object.entries(l.claims).map(([name, weight]) => ({ participantId: id(name), weight, source: 'organiser' as const }));
  });

  return {
    organiserName: file.organiser.displayName,
    title: file.title,
    merchant: file.merchant,
    receiptDate: file.receiptDate,
    receipt: {
      lines,
      serviceChargeMinor: file.serviceChargeMinor,
      serviceChargeLabel: file.serviceChargeLabel,
      tipMinor: file.tipMinor,
      discounts: file.discounts,
      printedTotalMinor: file.printedTotalMinor,
      currency: 'GBP',
    },
    participants: file.people.map((name, joinOrder) => ({
      id: id(name), name, joinOrder, isOrganiser: name === file.organiser.displayName, colourIndex: joinOrder,
    })),
    claims,
    rules: {
      serviceMode: file.rules.serviceMode,
      onUs: file.rules.onUs.map(id),
      onUsPaidBy: file.rules.onUsPaidBy?.map(id) ?? null,
      serviceOptOut: file.rules.serviceOptOut.map(id),
    },
  };
}
```

- [ ] **Step 4: Write the failing test**

Create `api/test/allocate-golden.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { allocate } from '../src/domain/allocate.js';
import { loadDemoSplit } from '../src/domain/demo.js';

// Spec §3, verified by hand on 2026-10-20. These are exactly the figures on
// Home, Breakdown, FriendPay and Tracker. If this test fails, the screens are
// wrong, not the test.
describe('allocate: the Little Bao House bill', () => {
  const demo = loadDemoSplit();
  const result = allocate(demo);

  it('allocates without problems', () => {
    expect(result.ok).toBe(true);
  });

  it('reproduces every figure on the design screens', () => {
    if (!result.ok) throw new Error('expected ok');
    const p = result.perParticipant;
    const row = (id: string) => ({
      items: p[id]!.itemsMinor,
      onUs: p[id]!.sharedFromOnUsMinor,
      service: p[id]!.serviceMinor,
      final: p[id]!.finalMinor,
    });
    expect(row('kemi')).toEqual({ items: 2510, onUs: 728, service: 405, final: 3643 });
    expect(row('amaka')).toEqual({ items: 2260, onUs: 728, service: 373, final: 3361 });
    expect(row('josh')).toEqual({ items: 3310, onUs: 727, service: 505, final: 4542 });
    expect(row('dan')).toEqual({ items: 2760, onUs: 727, service: 436, final: 3923 });
    expect(row('sam')).toEqual({ items: 2910, onUs: -2910, service: 0, final: 0 });
    expect(result.totalMinor).toBe(15469);
  });

  it('owes Kemi £118.26', () => {
    if (!result.ok) throw new Error('expected ok');
    const owed = demo.participants
      .filter((x) => !x.isOrganiser)
      .reduce((t, x) => t + result.perParticipant[x.id]!.finalMinor, 0);
    expect(owed).toBe(11826);
  });

  it("labels Josh's portions the way Breakdown and Claim do", () => {
    if (!result.ok) throw new Error('expected ok');
    const josh = Object.fromEntries(result.perParticipant.josh!.lines.map((l) => [l.lineId, [l.minor, l.portionLabel]]));
    expect(josh['beef-ramen-4']).toEqual([1500, '']);
    expect(josh['lager-8']).toEqual([1100, '2 of 3']);
    expect(josh['pork-bao-1']).toEqual([600, '1 of 3']);
    expect(josh['prawn-crackers-0']).toEqual([110, 'share']);
  });
});
```

- [ ] **Step 5: Run it and watch it fail**

```bash
cd api && npx vitest run test/allocate-golden.test.ts
```

Expected: FAIL. `Cannot find module '../src/domain/allocate.js'` (and `receipt.js` from the loader). Do not commit yet.

---

### Task 2: Largest remainder

**Files:**
- Modify: `api/src/domain/money.ts` (append)
- Test: `api/test/largest-remainder.test.ts`

**Interfaces:**
- Produces, from `src/domain/money.ts`: `allocateLargestRemainder(total: Minor, weights: Readonly<Record<string, number>>, order: readonly string[]): Record<string, Minor>`. It throws `MoneyError` on a negative or non-integer total, a negative or non-integer weight, weights summing to 0, or a weighted id missing from `order`. Every key of `weights` appears in the result.

- [ ] **Step 1: Write the failing test**

Create `api/test/largest-remainder.test.ts`. The second case is the golden fixture's service charge, and the third is Sam's on-us share. Both are worked through in the comments, so a reviewer can check them by hand.

```ts
import { describe, expect, it } from 'vitest';
import { MoneyError, allocateLargestRemainder } from '../src/domain/money.js';

const order = ['kemi', 'amaka', 'josh', 'dan'];

describe('allocateLargestRemainder', () => {
  it('splits in proportion and always sums to the total', () => {
    expect(allocateLargestRemainder(1650, { josh: 2, dan: 1 }, order)).toEqual({ josh: 1100, dan: 550 });
    const parts = allocateLargestRemainder(1000, { kemi: 1, amaka: 1, josh: 1 }, order);
    expect(Object.values(parts).reduce((a, b) => a + b, 0)).toBe(1000);
  });

  it('gives leftover pennies to the largest remainders first', () => {
    // 1719 by 3238/2988/4037/3487 floors to 1716; the three pennies go to
    // .938 (dan), .808 (kemi), .698 (josh). Amaka's .554 misses out.
    expect(allocateLargestRemainder(1719, { kemi: 3238, amaka: 2988, josh: 4037, dan: 3487 }, order))
      .toEqual({ kemi: 405, amaka: 373, josh: 505, dan: 436 });
  });

  it('breaks ties by the order given, so the organiser absorbs rounding', () => {
    expect(allocateLargestRemainder(2910, { kemi: 1, amaka: 1, josh: 1, dan: 1 }, order))
      .toEqual({ kemi: 728, amaka: 728, josh: 727, dan: 727 });
    expect(allocateLargestRemainder(1, { dan: 1, josh: 1 }, order)).toEqual({ josh: 1, dan: 0 });
  });

  it('never hands a penny to a zero weight', () => {
    expect(allocateLargestRemainder(5, { kemi: 0, amaka: 1, josh: 1 }, order)).toEqual({ kemi: 0, amaka: 3, josh: 2 });
  });

  it('stays exact where floats would not', () => {
    // 10,000,000p over 3 is 3,333,333.33…: a float multiply-then-divide can
    // land a penny out. BigInt cannot.
    expect(allocateLargestRemainder(10_000_000, { kemi: 1, amaka: 1, josh: 1 }, order))
      .toEqual({ kemi: 3_333_334, amaka: 3_333_333, josh: 3_333_333 });
  });

  it('refuses weights it cannot use', () => {
    expect(() => allocateLargestRemainder(100, { kemi: 0 }, order)).toThrow(MoneyError);
    expect(() => allocateLargestRemainder(100, { kemi: 1.5 }, order)).toThrow(MoneyError);
    expect(() => allocateLargestRemainder(100, { kemi: -1, amaka: 2 }, order)).toThrow(MoneyError);
    expect(() => allocateLargestRemainder(100, { stranger: 1 }, order)).toThrow(MoneyError);
    expect(() => allocateLargestRemainder(-1, { kemi: 1 }, order)).toThrow(MoneyError);
  });
});
```

- [ ] **Step 2: Run it to see it fail**

```bash
cd api && npx vitest run test/largest-remainder.test.ts
```

Expected: FAIL, `allocateLargestRemainder is not a function` (or a missing export).

- [ ] **Step 3: Implement**

Append to `api/src/domain/money.ts`:

```ts
/**
 * Splits `total` pence across parties in proportion to integer weights, so the
 * parts always sum to exactly `total`.
 *
 * Each party gets the floor of total × w / Σw, worked in BigInt so no float
 * ever touches money. The pennies left over go one each to the largest
 * fractional remainders. Ties go to whoever comes first in `order`; Split
 * passes the organiser first, then join order, so the person who paid the
 * bill absorbs the rounding.
 *
 * A party with weight 0 gets 0 and never a leftover penny: the leftover count
 * is always below the number of non-zero remainders.
 */
export function allocateLargestRemainder(
  total: Minor,
  weights: Readonly<Record<string, number>>,
  order: readonly string[],
): Record<string, Minor> {
  assertMinor(total);
  const ids = Object.keys(weights);
  let sum = 0n;
  for (const id of ids) {
    const w = weights[id]!;
    if (!Number.isSafeInteger(w) || w < 0) {
      throw new MoneyError(`Weight for ${id} must be a non-negative integer, got ${w}`);
    }
    if (!order.includes(id)) throw new MoneyError(`${id} has a weight but no place in the tie-break order`);
    sum += BigInt(w);
  }
  if (sum === 0n) throw new MoneyError('Cannot split an amount across weights that sum to zero');

  const t = BigInt(total);
  const out: Record<string, Minor> = {};
  const remainders: { id: string; rem: bigint; rank: number }[] = [];
  let given = 0n;
  for (const id of ids) {
    const scaled = t * BigInt(weights[id]!);
    const share = scaled / sum;
    out[id] = Number(share);
    given += share;
    remainders.push({ id, rem: scaled % sum, rank: order.indexOf(id) });
  }

  remainders.sort((a, b) => (a.rem === b.rem ? a.rank - b.rank : a.rem > b.rem ? -1 : 1));
  for (let i = 0; i < Number(t - given); i++) out[remainders[i]!.id]! += 1;
  return out;
}
```

- [ ] **Step 4: Run it to see it pass**

```bash
cd api && npx vitest run test/largest-remainder.test.ts test/money.test.ts
```

Expected: PASS (6 new, plus the existing money tests unchanged).

- [ ] **Step 5: Commit only these two files** (the golden test is still red and stays uncommitted)

```bash
git add api/src/domain/money.ts api/test/largest-remainder.test.ts
git commit -m "money: largest-remainder allocation in exact integer arithmetic"
```

---

### Task 3: The add-up check and `allocate()`, so the golden fixture goes green

**Files:**
- Modify: `api/src/ai/schemas.ts` (add the `'unclaimed'` kind)
- Create: `api/src/domain/receipt.ts`, `api/src/domain/allocate.ts`

**Interfaces:**
- Produces, from `src/domain/receipt.ts`: `lineIdFor(name, index): string`, `receiptSumMinor(receipt): number | null`, `receiptProblems(receipt): Ambiguity[]` (blocking: no lines, an unread price, an unread total, `price_conflict` naming both numbers).
- Produces, from `src/domain/allocate.ts`: `type AllocateInput = { receipt, claims, rules, participants }`, `allocate(input): Allocation`, `tieOrder(participants): string[]`, `class AllocationInvariantError`.
- Consumes: `allocateLargestRemainder` (Task 2), the types from Task 1.

- [ ] **Step 1: Add the `unclaimed` kind**

In `api/src/ai/schemas.ts`, extend `ambiguitySchema.kind`:

```ts
  kind: z.enum([
    'missing',
    'unclear',
    'unknown_product',
    'price_conflict',
    'qty_unclear',
    /** Split: a receipt line, or part of one, that nobody has claimed. */
    'unclaimed',
  ]),
```

- [ ] **Step 2: Write the receipt checks**

Create `api/src/domain/receipt.ts`. The problems are derived from the receipt every time, so there is no stored "resolved" flag to fall out of step with the numbers:

```ts
import type { Ambiguity } from '../ai/schemas.js';
import { formatGbp, type Minor } from './money.js';
import type { Receipt } from './split.js';

/** `Lager x3` at index 8 becomes `lager-x3-8`. Stable while the line keeps its place. */
export function lineIdFor(name: string, index: number): string {
  const slug = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 40);
  return `${slug || 'line'}-${index}`;
}

/**
 * Lines + service + tip − discounts, or null while any line price is unread.
 * This is what the printed total has to equal.
 */
export function receiptSumMinor(receipt: Receipt): number | null {
  let sum = receipt.serviceChargeMinor + receipt.tipMinor;
  for (const line of receipt.lines) {
    if (line.lineTotalMinor === null) return null;
    sum += line.lineTotalMinor;
  }
  for (const d of receipt.discounts) sum -= d.amountMinor;
  return sum;
}

/**
 * Everything about the receipt itself that blocks a split. Derived from the
 * receipt every time, so fixing the receipt is what clears them: there is no
 * stored "resolved" flag to fall out of step.
 */
export function receiptProblems(receipt: Receipt): Ambiguity[] {
  const problems: Ambiguity[] = [];
  if (receipt.lines.length === 0) {
    problems.push({
      field: 'lines',
      kind: 'missing',
      question: 'Split could not find any items on this bill. Add them by hand.',
      options: [],
      blocking: true,
    });
    return problems;
  }
  for (const line of receipt.lines) {
    if (line.lineTotalMinor === null) {
      problems.push({
        field: `lines.${line.id}.lineTotalMinor`,
        kind: 'missing',
        question: `What did the ${line.name} cost? Split could not read the price.`,
        options: [],
        blocking: true,
      });
    }
  }
  if (receipt.printedTotalMinor === null) {
    problems.push({
      field: 'printedTotalMinor',
      kind: 'missing',
      question: 'Split could not read the total. What does the bill say?',
      options: [],
      blocking: true,
    });
    return problems;
  }
  const sum = receiptSumMinor(receipt);
  if (sum !== null && sum !== receipt.printedTotalMinor) {
    problems.push({
      field: 'printedTotalMinor',
      kind: 'price_conflict',
      question:
        sum < 0
          ? `The discounts come to more than the bill, which says ${formatGbp(receipt.printedTotalMinor)}. Check the photo or edit a line.`
          : `Items add up to ${formatGbp(sum as Minor)} but the bill says ${formatGbp(receipt.printedTotalMinor)}. Check the photo or edit a line.`,
      options: [],
      blocking: true,
    });
  }
  return problems;
}
```

- [ ] **Step 3: Write `allocate()`**

Create `api/src/domain/allocate.ts`. It runs the spec's stages in order and collects every problem before returning. Each `spread` is one largest-remainder call, so no stage can lose or invent a penny:

```ts
import type { Ambiguity } from '../ai/schemas.js';
import { allocateLargestRemainder, type Minor } from './money.js';
import { receiptProblems } from './receipt.js';
import type {
  AllocParticipant,
  Allocation,
  Breakdown,
  BreakdownLine,
  Claim,
  Receipt,
  Rules,
} from './split.js';

export type AllocateInput = {
  receipt: Receipt;
  claims: Record<string, Claim[]>;
  rules: Rules;
  participants: AllocParticipant[];
};

/** A bug in this file, never a user error. Callers let it surface as a 500. */
export class AllocationInvariantError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AllocationInvariantError';
  }
}

/** Organiser first, then join order. The tie-break for every leftover penny. */
export function tieOrder(participants: AllocParticipant[]): string[] {
  return [...participants]
    .sort((a, b) =>
      a.isOrganiser === b.isOrganiser ? a.joinOrder - b.joinOrder : a.isOrganiser ? -1 : 1,
    )
    .map((p) => p.id);
}

const sumOf = (ids: string[], by: Record<string, number>) =>
  ids.reduce((t, id) => t + (by[id] ?? 0), 0);

function weightsFor(ids: string[], by: Record<string, number> | null): Record<string, number> {
  const w: Record<string, number> = {};
  for (const id of ids) w[id] = by ? (by[id] ?? 0) : 1;
  return w;
}

/**
 * Splits `amount` over `ids`, by `by` when it has any weight among them,
 * otherwise evenly. Proportional-by-nothing is how a bill where every eligible
 * payer had £0 of items would otherwise divide by zero.
 */
function spread(amount: Minor, ids: string[], by: Record<string, number> | null, order: string[]) {
  if (amount === 0 || ids.length === 0) return {} as Record<string, Minor>;
  const proportional = by !== null && sumOf(ids, by) > 0;
  return allocateLargestRemainder(amount, weightsFor(ids, proportional ? by : null), order);
}

/**
 * Turns a receipt, who had what and the group's rules into each person's
 * share, to the penny. Pure: no I/O, no clock, no randomness.
 *
 * Stages run in the spec's order (§3): validate, items, on us, service, tip
 * and discounts, invariant. Every problem found is returned at once, so the
 * organiser sees the whole list rather than one at a time.
 */
export function allocate(input: AllocateInput): Allocation {
  const { receipt, claims, rules, participants } = input;
  const order = tieOrder(participants);
  const known = new Set(order);
  const problems: Ambiguity[] = [...receiptProblems(receipt)];

  // ── 1. Validate ─────────────────────────────────────────────────────────
  const lineIds = new Set(receipt.lines.map((l) => l.id));
  for (const lineId of Object.keys(claims)) {
    if (!lineIds.has(lineId) && (claims[lineId]?.length ?? 0) > 0) {
      problems.push(blocking(`claims.${lineId}`, 'unclear', 'A claim points at a line that is no longer on the bill.'));
    }
  }

  // Per line: participantId -> summed weight. A person claiming one line twice
  // ("a lager" then "another lager") is one claimant with weight 2.
  const weightsByLine = new Map<string, Record<string, number>>();
  for (const line of receipt.lines) {
    const merged: Record<string, number> = {};
    for (const claim of claims[line.id] ?? []) {
      if (!known.has(claim.participantId)) {
        problems.push(blocking(`claims.${line.id}`, 'unclear', `The ${line.name} is claimed by someone who is no longer in the group.`));
        continue;
      }
      if (!Number.isSafeInteger(claim.weight) || claim.weight < 1) {
        problems.push(blocking(`claims.${line.id}`, 'qty_unclear', `How many of the ${line.name} did they have?`));
        continue;
      }
      merged[claim.participantId] = (merged[claim.participantId] ?? 0) + claim.weight;
    }
    const claimants = Object.keys(merged).length;
    const units = sumOf(Object.keys(merged), merged);
    if (claimants === 0) {
      problems.push({
        field: `claims.${line.id}`,
        kind: 'unclaimed',
        question: `Nobody claimed the ${line.name.toLowerCase()}`,
        options: [`Share between all ${participants.length}`, 'Ask the group'],
        blocking: true,
      });
    } else if (claimants === 1 && units < line.qty) {
      problems.push({
        field: `claims.${line.id}`,
        kind: 'unclaimed',
        question: `${line.name}: ${line.qty - units} of ${line.qty} unclaimed`,
        options: ['Ask the group'],
        blocking: true,
      });
    }
    weightsByLine.set(line.id, merged);
  }

  for (const [field, ids] of [
    ['rules.onUs', rules.onUs],
    ['rules.onUsPaidBy', rules.onUsPaidBy ?? []],
    ['rules.serviceOptOut', rules.serviceOptOut],
  ] as const) {
    if (ids.some((id) => !known.has(id))) {
      problems.push(blocking(field, 'unclear', 'A rule names someone who is no longer in the group.'));
    }
  }

  const onUs = new Set(rules.onUs.filter((id) => known.has(id)));
  const payers = order.filter((id) => !onUs.has(id));
  if (payers.length === 0) {
    problems.push(blocking('rules.onUs', 'unclear', 'Everyone is on us, so nobody is left to pay.'));
  }
  const coverers = (rules.onUsPaidBy ?? payers).filter((id) => known.has(id) && !onUs.has(id));
  if (onUs.size > 0 && payers.length > 0 && coverers.length === 0) {
    problems.push(blocking('rules.onUsPaidBy', 'unclear', 'Nobody is left to cover the on-us share.'));
  }
  const eligible = payers.filter((id) => !rules.serviceOptOut.includes(id));
  if (receipt.serviceChargeMinor + receipt.tipMinor > 0 && payers.length > 0 && eligible.length === 0) {
    problems.push(blocking('rules.serviceOptOut', 'unclear', 'Everyone has opted out of the service charge. Someone has to cover it.'));
  }

  if (problems.length > 0) return { ok: false, problems };

  // ── 2. Items ────────────────────────────────────────────────────────────
  const items: Record<string, number> = Object.fromEntries(order.map((id) => [id, 0]));
  const lines: Record<string, BreakdownLine[]> = Object.fromEntries(order.map((id) => [id, []]));
  for (const line of receipt.lines) {
    const merged = weightsByLine.get(line.id)!;
    const ids = Object.keys(merged);
    const units = sumOf(ids, merged);
    const parts = allocateLargestRemainder(line.lineTotalMinor!, merged, order);
    for (const id of order) {
      if (!(id in parts)) continue;
      items[id]! += parts[id]!;
      lines[id]!.push({ lineId: line.id, minor: parts[id]!, portionLabel: portionLabel(merged[id]!, ids.length, units, line.qty) });
    }
  }

  // ── 3. On us ────────────────────────────────────────────────────────────
  const shared: Record<string, number> = Object.fromEntries(order.map((id) => [id, 0]));
  for (const id of order) {
    if (!onUs.has(id)) continue;
    const parts = spread(items[id]!, coverers, null, order);
    for (const [to, minor] of Object.entries(parts)) shared[to]! += minor;
    shared[id]! -= items[id]!;
  }
  const subtotal: Record<string, number> = Object.fromEntries(
    order.map((id) => [id, items[id]! + shared[id]!]),
  );

  // ── 4. Service charge, and 5. tip, which follows the service mode ───────
  const by = rules.serviceMode === 'proportional' ? subtotal : null;
  const service = spread(receipt.serviceChargeMinor, eligible, by, order);
  const tip = spread(receipt.tipMinor, eligible, by, order);

  // ── 5. Discounts, by what each payer had, never taking anyone below 0 ───
  const discountTotal = receipt.discounts.reduce((t, d) => t + d.amountMinor, 0);
  const discount: Record<string, number> = { ...spread(discountTotal, payers, subtotal, order) };
  const final: Record<string, number> = {};
  for (const id of order) {
    discount[id] ??= 0;
    final[id] = subtotal[id]! + (service[id] ?? 0) + (tip[id] ?? 0) - discount[id]!;
  }
  for (let pass = 0; order.some((id) => final[id]! < 0); pass++) {
    if (pass > order.length) throw new AllocationInvariantError('discount clamp did not settle');
    let excess = 0;
    for (const id of order) {
      if (final[id]! < 0) {
        excess += -final[id]!;
        discount[id]! += final[id]!;
        final[id] = 0;
      }
    }
    const takers = order.filter((id) => final[id]! > 0);
    if (takers.length === 0) throw new AllocationInvariantError('discount exceeds the whole bill');
    const extra = allocateLargestRemainder(excess, weightsFor(takers, final), order);
    for (const [id, minor] of Object.entries(extra)) {
      discount[id]! += minor;
      final[id]! -= minor;
    }
  }

  // ── 6. Invariant ────────────────────────────────────────────────────────
  const total = sumOf(order, final);
  if (total !== receipt.printedTotalMinor) {
    throw new AllocationInvariantError(`shares sum to ${total}, the bill says ${receipt.printedTotalMinor}`);
  }

  const perParticipant: Record<string, Breakdown> = {};
  for (const id of order) {
    perParticipant[id] = {
      itemsMinor: items[id]!,
      sharedFromOnUsMinor: shared[id]!,
      serviceMinor: service[id] ?? 0,
      tipMinor: tip[id] ?? 0,
      discountMinor: discount[id]!,
      finalMinor: final[id]!,
      lines: lines[id]!,
    };
  }
  return { ok: true, perParticipant, totalMinor: total };
}

/** "" for a whole line, "2 of 3" for some of the units, "share" for a shared item. */
function portionLabel(weight: number, claimants: number, units: number, qty: number): string {
  if (claimants === 1) return '';
  if (units === qty) return `${weight} of ${qty}`;
  return 'share';
}

function blocking(field: string, kind: Ambiguity['kind'], question: string): Ambiguity {
  return { field, kind, question, options: [], blocking: true };
}
```

- [ ] **Step 4: Run the golden fixture**

```bash
cd api && npx vitest run test/allocate-golden.test.ts test/largest-remainder.test.ts
```

Expected: PASS, 10 tests. Kemi 3643, Amaka 3361, Josh 4542, Dan 3923, Sam 0, total 15469, owed £118.26.

- [ ] **Step 5: Typecheck, full suite, commit**

```bash
cd api && npm run typecheck && npm test
git add samples/demo-split.json api/src/ai/schemas.ts api/src/domain/{split,demo,receipt,allocate}.ts api/test/allocate-golden.test.ts
git commit -m "allocate: shares to the penny, reproducing the Little Bao House bill"
```

---

### Task 4: Property tests and edge cases (**the gate for the week**)

Nothing after this task starts until it is green. A share that is wrong by a penny here is wrong on every screen and in every PayPal order.

**Files:**
- Modify: `api/package.json` (dev dependency)
- Test: `api/test/allocate-property.test.ts`, `api/test/allocate-edges.test.ts`

**Interfaces:**
- Consumes: `allocate`, `AllocateInput`, `DEFAULT_RULES`, `Claim`, `Rules`.
- Produces: nothing new. If a test here fails, fix `allocate.ts`, never the test.

- [ ] **Step 1: Add fast-check, pinned**

```bash
cd api && npm i -D fast-check@4.10.2
```

- [ ] **Step 2: Write the property tests**

Create `api/test/allocate-property.test.ts`. The generator only builds *valid* splits: every line fully claimed, someone left to pay, and a printed total equal to what the receipt adds up to. `ok()` throws on problems, so a generator bug fails loudly instead of quietly skipping cases.

```ts
import fc from 'fast-check';
import { describe, expect, it } from 'vitest';
import { allocate, type AllocateInput } from '../src/domain/allocate.js';
import type { Claim, Rules } from '../src/domain/split.js';

/**
 * Random but valid splits: every line fully claimed, rules that leave someone
 * to pay, and a printed total that is what the receipt adds up to.
 */
const validSplit: fc.Arbitrary<AllocateInput> = fc
  .integer({ min: 1, max: 8 })
  .chain((n) => {
    const ids = Array.from({ length: n }, (_, i) => `p${i}`);
    const line = fc.record({
      qty: fc.integer({ min: 1, max: 7 }),
      lineTotalMinor: fc.oneof(fc.constant(1), fc.integer({ min: 0, max: 20_000 })),
      claimants: fc.subarray(ids, { minLength: 1 }),
      weightSeed: fc.array(fc.integer({ min: 1, max: 7 }), { minLength: 8, maxLength: 8 }),
    });
    return fc.record({
      ids: fc.constant(ids),
      organiser: fc.integer({ min: 0, max: n - 1 }),
      lines: fc.array(line, { minLength: 1, maxLength: 12 }),
      service: fc.integer({ min: 0, max: 3000 }),
      tip: fc.integer({ min: 0, max: 1000 }),
      discountShare: fc.double({ min: 0, max: 1, noNaN: true }),
      serviceMode: fc.constantFrom('proportional' as const, 'even' as const),
      onUs: fc.subarray(ids, { maxLength: n - 1 }),
      paidBySeed: fc.option(fc.subarray(ids, { minLength: 1 })),
      optOutSeed: fc.subarray(ids),
    });
  })
  .map((g) => {
    const lines = g.lines.map((l, i) => ({ id: `line-${i}`, name: `Line ${i}`, qty: l.qty, lineTotalMinor: l.lineTotalMinor }));
    const claims: Record<string, Claim[]> = {};
    g.lines.forEach((l, i) => {
      claims[`line-${i}`] = l.claimants.map((id, k) => ({
        participantId: id,
        // A lone claimant must cover every unit, or the line is partly unclaimed.
        weight: l.claimants.length === 1 ? Math.max(l.qty, l.weightSeed[k]!) : l.weightSeed[k]!,
        source: 'ai' as const,
      }));
    });
    const payers = g.ids.filter((id) => !g.onUs.includes(id));
    const paidBy = g.paidBySeed?.filter((id) => payers.includes(id)) ?? null;
    const optOut = g.optOutSeed.filter((id) => payers.includes(id)).slice(0, payers.length - 1);
    const itemTotal = lines.reduce((t, l) => t + l.lineTotalMinor, 0);
    const discount = Math.floor(itemTotal * g.discountShare);
    const rules: Rules = {
      serviceMode: g.serviceMode,
      onUs: g.onUs,
      onUsPaidBy: paidBy && paidBy.length > 0 ? paidBy : null,
      serviceOptOut: optOut,
    };
    return {
      receipt: {
        lines,
        serviceChargeMinor: g.service,
        serviceChargeLabel: null,
        tipMinor: g.tip,
        discounts: discount > 0 ? [{ label: 'Voucher', amountMinor: discount }] : [],
        printedTotalMinor: itemTotal + g.service + g.tip - discount,
        currency: 'GBP' as const,
      },
      claims,
      rules,
      participants: g.ids.map((id, joinOrder) => ({ id, joinOrder, isOrganiser: joinOrder === g.organiser })),
    };
  });

const ok = (input: AllocateInput) => {
  const r = allocate(input);
  if (!r.ok) throw new Error(`unexpected problems: ${JSON.stringify(r.problems)}`);
  return r;
};

describe('allocate: properties over random valid splits', () => {
  it('always sums to the printed total', () => {
    fc.assert(fc.property(validSplit, (input) => {
      const r = ok(input);
      const sum = Object.values(r.perParticipant).reduce((t, b) => t + b.finalMinor, 0);
      expect(sum).toBe(input.receipt.printedTotalMinor);
      expect(r.totalMinor).toBe(input.receipt.printedTotalMinor);
    }), { numRuns: 500 });
  });

  it('never gives anyone a negative or fractional share', () => {
    fc.assert(fc.property(validSplit, (input) => {
      for (const b of Object.values(ok(input).perParticipant)) {
        expect(Number.isInteger(b.finalMinor)).toBe(true);
        expect(b.finalMinor).toBeGreaterThanOrEqual(0);
        for (const v of [b.itemsMinor, b.serviceMinor, b.tipMinor, b.discountMinor]) {
          expect(Number.isInteger(v) && v >= 0).toBe(true);
        }
      }
    }), { numRuns: 500 });
  });

  it('keeps every breakdown adding up to its own final', () => {
    fc.assert(fc.property(validSplit, (input) => {
      for (const b of Object.values(ok(input).perParticipant)) {
        expect(b.itemsMinor + b.sharedFromOnUsMinor + b.serviceMinor + b.tipMinor - b.discountMinor).toBe(b.finalMinor);
        expect(b.lines.reduce((t, l) => t + l.minor, 0)).toBe(b.itemsMinor);
      }
    }), { numRuns: 300 });
  });

  it('gives the same answer every time', () => {
    fc.assert(fc.property(validSplit, (input) => {
      expect(ok(structuredClone(input))).toEqual(ok(structuredClone(input)));
    }), { numRuns: 200 });
  });

  it('does not care what order claims on a line arrive in', () => {
    fc.assert(fc.property(validSplit, fc.integer(), (input, seed) => {
      const shuffled = structuredClone(input);
      for (const [lineId, list] of Object.entries(shuffled.claims)) {
        shuffled.claims[lineId] = [...list].sort((a, b) =>
          ((a.participantId.charCodeAt(1) * 31 + seed) % 97) - ((b.participantId.charCodeAt(1) * 31 + seed) % 97));
        shuffled.claims[lineId]!.reverse();
      }
      expect(ok(shuffled).perParticipant).toEqual(ok(input).perParticipant);
    }), { numRuns: 300 });
  });

  it('charges nobody who is on us', () => {
    fc.assert(fc.property(validSplit, (input) => {
      const r = ok(input);
      for (const id of input.rules.onUs) expect(r.perParticipant[id]!.finalMinor).toBe(0);
    }), { numRuns: 300 });
  });
});
```

- [ ] **Step 3: Write the edge cases**

Create `api/test/allocate-edges.test.ts`. It covers the six edge cases the spec names, plus each problem `allocate` can return. Every expected figure is worked out in a comment or is trivially checkable:

```ts
import { describe, expect, it } from 'vitest';
import { allocate, type AllocateInput } from '../src/domain/allocate.js';
import { DEFAULT_RULES, type Claim, type Rules } from '../src/domain/split.js';

type L = { name: string; qty: number; total: number; claims: Record<string, number> };

function split(
  people: string[],
  lines: L[],
  opts: { service?: number; tip?: number; discount?: number; rules?: Partial<Rules> } = {},
): AllocateInput {
  const receiptLines = lines.map((l, i) => ({ id: `l${i}`, name: l.name, qty: l.qty, lineTotalMinor: l.total }));
  const claims: Record<string, Claim[]> = {};
  lines.forEach((l, i) => {
    claims[`l${i}`] = Object.entries(l.claims).map(([participantId, weight]) => ({ participantId, weight, source: 'organiser' }));
  });
  const items = lines.reduce((t, l) => t + l.total, 0);
  const service = opts.service ?? 0;
  const tip = opts.tip ?? 0;
  const discount = opts.discount ?? 0;
  return {
    receipt: {
      lines: receiptLines, serviceChargeMinor: service, serviceChargeLabel: null, tipMinor: tip,
      discounts: discount ? [{ label: 'Discount', amountMinor: discount }] : [],
      printedTotalMinor: items + service + tip - discount, currency: 'GBP',
    },
    claims,
    rules: { ...DEFAULT_RULES, ...opts.rules },
    participants: people.map((id, joinOrder) => ({ id, joinOrder, isOrganiser: joinOrder === 0 })),
  };
}

const finals = (input: AllocateInput) => {
  const r = allocate(input);
  if (!r.ok) throw new Error(JSON.stringify(r.problems));
  return Object.fromEntries(Object.entries(r.perParticipant).map(([id, b]) => [id, b.finalMinor]));
};

const problems = (input: AllocateInput) => {
  const r = allocate(input);
  if (r.ok) throw new Error('expected problems');
  return r.problems;
};

describe('allocate: edge cases', () => {
  it('one participant pays the whole bill', () => {
    expect(finals(split(['kemi'], [{ name: 'Ramen', qty: 1, total: 1500, claims: { kemi: 1 } }], { service: 188 })))
      .toEqual({ kemi: 1688 });
  });

  it('everyone on us except the organiser leaves the organiser with everything', () => {
    expect(finals(split(['kemi', 'amaka', 'josh'], [
      { name: 'Ramen', qty: 3, total: 4500, claims: { kemi: 1, amaka: 1, josh: 1 } },
    ], { service: 563, rules: { onUs: ['amaka', 'josh'] } }))).toEqual({ kemi: 5063, amaka: 0, josh: 0 });
  });

  it('a qty 7 line split 3:2:2', () => {
    // 2100 × 3/7 = 900, × 2/7 = 600 each. Exact, no leftover.
    expect(finals(split(['kemi', 'amaka', 'josh'], [
      { name: 'Gyoza x7', qty: 7, total: 2100, claims: { kemi: 3, amaka: 2, josh: 2 } },
    ]))).toEqual({ kemi: 900, amaka: 600, josh: 600 });
    // 1000 × 3/7 = 428.57, × 2/7 = 285.71 twice: floors 998, the two pennies
    // go to .71 then .71 (amaka, josh), not kemi's .57.
    expect(finals(split(['kemi', 'amaka', 'josh'], [
      { name: 'Gyoza x7', qty: 7, total: 1000, claims: { kemi: 3, amaka: 2, josh: 2 } },
    ]))).toEqual({ kemi: 428, amaka: 286, josh: 286 });
  });

  it('a 100% discount on a line nets to zero overall without anyone going negative', () => {
    const f = finals(split(['kemi', 'amaka'], [
      { name: 'Dessert', qty: 1, total: 600, claims: { amaka: 1 } },
      { name: 'Ramen', qty: 1, total: 1500, claims: { kemi: 1 } },
    ], { discount: 600 }));
    expect(f.kemi! + f.amaka!).toBe(1500);
    expect(Math.min(f.kemi!, f.amaka!)).toBeGreaterThanOrEqual(0);
  });

  it('a discount bigger than one person\'s items is clamped and the rest absorb it', () => {
    // Amaka opts out of service, so her 100p subtotal takes ~4.5% of a 3000p
    // discount (≈135p) and would go negative. She is clamped to 0.
    const f = finals(split(['kemi', 'amaka'], [
      { name: 'Ramen', qty: 1, total: 2100, claims: { kemi: 1 } },
      { name: 'Tea', qty: 1, total: 100, claims: { amaka: 1 } },
    ], { service: 1000, discount: 3000, rules: { serviceOptOut: ['amaka'] } }));
    expect(f).toEqual({ kemi: 200, amaka: 0 });
  });

  it('service opt-out by all but one puts the whole service charge on them', () => {
    const input = split(['kemi', 'amaka', 'josh'], [
      { name: 'Ramen', qty: 3, total: 4500, claims: { kemi: 1, amaka: 1, josh: 1 } },
    ], { service: 563, rules: { serviceOptOut: ['kemi', 'amaka'] } });
    expect(finals(input)).toEqual({ kemi: 1500, amaka: 1500, josh: 2063 });
  });

  it('a 1p line shared by five gives the penny to the organiser', () => {
    expect(finals(split(['kemi', 'amaka', 'josh', 'dan', 'sam'], [
      { name: 'Mint', qty: 1, total: 1, claims: { kemi: 1, amaka: 1, josh: 1, dan: 1, sam: 1 } },
    ]))).toEqual({ kemi: 1, amaka: 0, josh: 0, dan: 0, sam: 0 });
  });

  it('splits evenly when asked, whatever people had', () => {
    expect(finals(split(['kemi', 'amaka'], [
      { name: 'Steak', qty: 1, total: 3000, claims: { kemi: 1 } },
      { name: 'Soup', qty: 1, total: 600, claims: { amaka: 1 } },
    ], { service: 451, rules: { serviceMode: 'even' } }))).toEqual({ kemi: 3226, amaka: 825 });
  });
});

describe('allocate: problems instead of guesses', () => {
  it('flags an unclaimed line with the two one-tap options', () => {
    const [p] = problems(split(['kemi', 'amaka'], [{ name: 'Prawn crackers', qty: 1, total: 550, claims: {} }]));
    expect(p).toMatchObject({
      field: 'claims.l0', kind: 'unclaimed', blocking: true,
      question: 'Nobody claimed the prawn crackers',
      options: ['Share between all 2', 'Ask the group'],
    });
  });

  it('flags a line one person has only partly claimed', () => {
    const [p] = problems(split(['kemi', 'josh'], [{ name: 'Lager', qty: 3, total: 1650, claims: { josh: 2 } }]));
    expect(p).toMatchObject({ kind: 'unclaimed', question: 'Lager: 1 of 3 unclaimed' });
  });

  it('treats two or more claimants as sharing, whatever the weights', () => {
    // Spec §3 stage 1: two claimants make a shared item even when the
    // weights are below qty. Split 1:1. See Review Focus 1.
    expect(finals(split(['josh', 'dan'], [{ name: 'Lager', qty: 3, total: 1650, claims: { josh: 1, dan: 1 } }])))
      .toEqual({ josh: 825, dan: 825 });
  });

  it('refuses a receipt that does not add up instead of allocating it', () => {
    const input = split(['kemi'], [{ name: 'Ramen', qty: 1, total: 1500, claims: { kemi: 1 } }]);
    input.receipt.printedTotalMinor = 1600;
    expect(problems(input)[0]).toMatchObject({ kind: 'price_conflict', field: 'printedTotalMinor' });
  });

  it('refuses an unread price', () => {
    const input = split(['kemi'], [{ name: 'Ramen', qty: 1, total: 1500, claims: { kemi: 1 } }]);
    input.receipt.lines[0]!.lineTotalMinor = null;
    expect(problems(input)[0]).toMatchObject({ kind: 'missing', field: 'lines.l0.lineTotalMinor' });
  });

  it('refuses to put everyone on us', () => {
    const input = split(['kemi', 'amaka'], [{ name: 'Ramen', qty: 1, total: 1500, claims: { kemi: 1 } }], { rules: { onUs: ['kemi', 'amaka'] } });
    expect(problems(input).map((p) => p.field)).toContain('rules.onUs');
  });

  it('refuses a service charge nobody will cover', () => {
    const input = split(['kemi', 'amaka'], [{ name: 'Ramen', qty: 2, total: 3000, claims: { kemi: 1, amaka: 1 } }],
      { service: 375, rules: { serviceOptOut: ['kemi', 'amaka'] } });
    expect(problems(input).map((p) => p.field)).toContain('rules.serviceOptOut');
  });

  it('refuses claims and rules naming people who have left', () => {
    const input = split(['kemi'], [{ name: 'Ramen', qty: 1, total: 1500, claims: { kemi: 1, ghost: 1 } }], { rules: { onUs: ['ghost'] } });
    expect(problems(input).map((p) => p.field)).toEqual(expect.arrayContaining(['claims.l0', 'rules.onUs']));
  });

  it('returns every problem at once', () => {
    const input = split(['kemi', 'josh'], [
      { name: 'Prawn crackers', qty: 1, total: 550, claims: {} },
      { name: 'Lager', qty: 3, total: 1650, claims: { josh: 1 } },
    ]);
    expect(problems(input)).toHaveLength(2);
  });
});
```

- [ ] **Step 4: Run them**

```bash
cd api && npx vitest run test/allocate-property.test.ts test/allocate-edges.test.ts
```

Expected: PASS, 23 tests (6 properties at 200–500 runs each, 8 edge cases, 9 problem cases).

- [ ] **Step 5: Mutation check, then commit**

Prove the properties can fail. Temporarily change `tieOrder` to sort `b.joinOrder - a.joinOrder` and run the golden test: expect it to fail on Kemi/Amaka vs Josh/Dan. Temporarily drop the `+= 1` loop in `allocateLargestRemainder` and run the properties: expect "always sums to the printed total" to fail with a counterexample. Revert both.

```bash
git add api/package.json api/package-lock.json api/test/allocate-property.test.ts api/test/allocate-edges.test.ts
git commit -m "allocate: property tests and the spec's edge cases"
```

---

### Task 5: Sample receipts

Four hand-written receipts, as Sorted's DM samples were (§8). They feed the model spike (Task 7), the live extraction test (Task 6) and *Try a sample bill* (Task 20). Every one adds up exactly, so a correct read raises no ambiguity.

**Files:**
- Create: `samples/receipts/little-bao-house.html`, `brunch-discount.html`, `pub-no-service.html`, `long-curry-part1.html`, `long-curry-part2.html`, their `.png` renders, `samples/receipts/README.md`, `scripts/render-receipts.mjs`

**Interfaces:**
- Produces: PNG files at fixed paths. `little-bao-house.png` is also copied to `app/assets/samples/` in Task 20.

- [ ] **Step 1: Write the HTML receipts**

Each is a 380 px-wide thermal-receipt layout in a monospace font: merchant, address, date and time, table number, then one row per line (`Lager x3 ............ 16.50`), a subtotal, the service charge or discount row, and **TOTAL**. Content, fictional throughout:

| File | Merchant, date | Lines (line totals) | Extras | Printed total |
|---|---|---|---|---|
| `little-bao-house` | Little Bao House, Fri 2 Oct 2026, table 6 | exactly the 10 lines of `samples/demo-split.json` | `Service 12.5% (discretionary) 17.19` | **154.69** |
| `brunch-discount` | The Corner Larder, Sun 27 Sep 2026 | Full English x2 24.00, Avocado toast 9.50, Buttermilk pancakes 8.75, Flat white x3 10.50, Fresh orange juice x2 7.00 | `Brunch club 10% -5.98`, no service | **53.77** |
| `pub-no-service` | The Crown & Anchor, Thu 17 Sep 2026 | Pint of Hells x6 36.90, Gin and tonic x3 25.50, House white 175ml x2 14.40, Crisps x4 6.00, Chips to share 5.50 | none | **88.30** |
| `long-curry-part1` + `part2` | Saffron Lane, Sat 10 Oct 2026 | 18 lines: Poppadoms x4 4.00, Chutney tray 3.50, Onion bhaji 5.95, Samosa chaat 6.95, Chicken tikka 7.95, Paneer tikka 7.50, Lamb rogan josh 14.95, Chicken makhani 14.50, Dal makhani 9.95, Saag paneer 10.95, Prawn malabar 15.95, Vegetable biryani 12.50, Pilau rice x3 10.50, Garlic naan x2 7.90, Peshwari naan 4.25, Mango lassi x2 9.50, Kingfisher x4 22.00, Lime soda 3.50. **Part 1 ends after Saag paneer; part 2 starts at Dal makhani**, so Dal makhani and Saag paneer appear in both (the overlap) | `Service 12.5% 21.54` | **193.84** |

Before rendering, check each total with `node -e` over the line values. The receipt is the test input, so an arithmetic slip here would read as a model failure.

- [ ] **Step 2: Write the renderer**

Create `scripts/render-receipts.mjs`. It uses Playwright with the preinstalled Chromium (`executablePath: '/opt/pw-browsers/chromium'` in this environment, or the default locally), sets the viewport to 380 wide with `deviceScaleFactor: 2`, and screenshots `full_page` for each `samples/receipts/*.html` to the same name with `.png`. Run it with `npx -y playwright@1 ...` or a scratch `npm i playwright`. Do not add Playwright to `api/package.json`.

- [ ] **Step 3: Render, eyeball, commit**

```bash
node scripts/render-receipts.mjs && ls -la samples/receipts/*.png
```

Open each PNG and check that every price is legible. Write `samples/receipts/README.md` listing each receipt, what it exercises and its printed total.

```bash
git add samples/receipts scripts/render-receipts.mjs
git commit -m "samples: four fictional receipts for the model spike and the demo"
```

---

### Task 6: Receipt extraction

**Files:**
- Modify: `api/src/ai/schemas.ts` (append `receiptExtractionSchema`)
- Create: `api/src/ai/extract_receipt.ts`
- Test: `api/test/extract-receipt.test.ts`, `api/test/extract-receipt.live.test.ts`

**Interfaces:**
- Consumes: `generateStructured`, `toDataUri`, `ChatTransport` (`src/ai/client.ts`); `lineIdFor`, `receiptProblems` (Task 3).
- Produces, from `src/ai/schemas.ts`: `receiptExtractionSchema`, `type ReceiptExtraction`.
- Produces, from `src/ai/extract_receipt.ts`: `RECEIPT_SYSTEM`, `RECEIPT_JSON_SCHEMA`, `extractReceipt(images: { buffer; mime }[], transport, model): Promise<ReceiptExtraction>` (1–2 images, otherwise it throws), `toDraftReceipt(extraction): { receipt: Receipt; ambiguities: Ambiguity[] }`, `remapLineField(field, lines): string`.

- [ ] **Step 1: Write the failing test**

Create `api/test/extract-receipt.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { RECEIPT_SYSTEM, extractReceipt, remapLineField, toDraftReceipt } from '../src/ai/extract_receipt.js';
import type { ChatTransport } from '../src/ai/client.js';
import type { ReceiptExtraction } from '../src/ai/schemas.js';

const bao: ReceiptExtraction = {
  merchant: 'Little Bao House',
  receiptDate: '2026-10-02',
  lines: [
    { name: 'Prawn crackers', qty: 1, lineTotalMinor: 550 },
    { name: 'Lager', qty: 3, lineTotalMinor: 1650 },
  ],
  serviceChargeMinor: 275,
  serviceChargeLabel: '12.5% discretionary',
  tipMinor: null,
  discounts: [],
  printedTotalMinor: 2475,
  ambiguities: [],
};

const replying = (payload: unknown): ChatTransport & { bodies: unknown[] } => {
  const bodies: unknown[] = [];
  const t = (async (body: unknown) => { bodies.push(body); return { content: JSON.stringify(payload) }; }) as ChatTransport & { bodies: unknown[] };
  t.bodies = bodies;
  return t;
};

const png = { buffer: Buffer.from('x'), mime: 'image/png' };

describe('extractReceipt', () => {
  it('sends the spec prompt, every image, and no temperature', async () => {
    const t = replying(bao);
    await extractReceipt([png, png], t, 'm');
    const body = t.bodies[0] as { messages: { content: unknown }[]; temperature?: number };
    expect(JSON.stringify(body.messages[0])).toContain("not three lines");
    expect((body.messages[1]!.content as { type: string }[]).filter((p) => p.type === 'image_url')).toHaveLength(2);
    expect(body.temperature).toBeUndefined();
    expect(RECEIPT_SYSTEM).toContain('Never compute or correct a total');
  });

  it('refuses no images or more than two', async () => {
    await expect(extractReceipt([], replying(bao), 'm')).rejects.toThrow();
    await expect(extractReceipt([png, png, png], replying(bao), 'm')).rejects.toThrow();
  });
});

describe('toDraftReceipt', () => {
  it('gives lines stable ids and a receipt that adds up raises nothing', () => {
    const { receipt, ambiguities } = toDraftReceipt(bao);
    expect(receipt.lines.map((l) => l.id)).toEqual(['prawn-crackers-0', 'lager-1']);
    expect(receipt.lines[1]).toMatchObject({ qty: 3, lineTotalMinor: 1650 });
    expect(receipt.tipMinor).toBe(0);
    expect(ambiguities).toEqual([]);
  });

  it('blocks a bill that does not add up, naming both numbers', () => {
    const { ambiguities } = toDraftReceipt({ ...bao, printedTotalMinor: 15469 });
    expect(ambiguities).toEqual([expect.objectContaining({
      kind: 'price_conflict', blocking: true,
      question: 'Items add up to £24.75 but the bill says £154.69. Check the photo or edit a line.',
    })]);
  });

  it('blocks an unread price and an unread total', () => {
    const lines = [{ name: 'Lager', qty: 3, lineTotalMinor: null }];
    expect(toDraftReceipt({ ...bao, lines }).ambiguities[0]).toMatchObject({ kind: 'missing', field: 'lines.lager-0.lineTotalMinor', blocking: true });
    expect(toDraftReceipt({ ...bao, printedTotalMinor: null }).ambiguities[0]).toMatchObject({ kind: 'missing', field: 'printedTotalMinor' });
  });

  it("keeps the model's own questions, as notes that do not block", () => {
    const { ambiguities } = toDraftReceipt({
      ...bao,
      ambiguities: [{ field: 'lines[1].qty', kind: 'qty_unclear', question: 'Is that 3 lagers or 2?', options: ['3', '2'], blocking: true }],
    });
    expect(ambiguities).toEqual([expect.objectContaining({ field: 'lines.lager-1.qty', blocking: false })]);
  });

  it('drops a model note a derived problem already covers', () => {
    const { ambiguities } = toDraftReceipt({
      ...bao,
      printedTotalMinor: null,
      ambiguities: [{ field: 'printedTotalMinor', kind: 'missing', question: 'Total unreadable', options: [], blocking: true }],
    });
    expect(ambiguities.filter((a) => a.field === 'printedTotalMinor')).toHaveLength(1);
    expect(ambiguities[0]!.blocking).toBe(true);
  });

  it('remaps the model\'s line positions to ids and leaves other fields alone', () => {
    const lines = [{ id: 'a-0' }, { id: 'b-1' }];
    expect(remapLineField('lines[1].lineTotalMinor', lines)).toBe('lines.b-1.lineTotalMinor');
    expect(remapLineField('lines[9].qty', lines)).toBe('lines[9].qty');
    expect(remapLineField('serviceChargeMinor', lines)).toBe('serviceChargeMinor');
  });
});
```

- [ ] **Step 2: Run it to see it fail** (`Cannot find module '../src/ai/extract_receipt.js'`)

- [ ] **Step 3: Add the schema**

Append to `api/src/ai/schemas.ts`:

```ts
const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'must be an ISO date (YYYY-MM-DD)');
/** Integer pence, never negative. Mirrors money.ts's Minor. */
const minor = z.number().int().nonnegative();

/** What the vision model reports from a receipt. It never computes a total. */
export const receiptExtractionSchema = z.object({
  merchant: z.string().max(80).nullable(),
  receiptDate: isoDate.nullable(),
  lines: z
    .array(
      z.object({
        name: z.string().min(1).max(80),
        qty: z.number().int().min(1).max(99),
        lineTotalMinor: minor.nullable(),
      }),
    )
    .max(60),
  serviceChargeMinor: minor.nullable(),
  serviceChargeLabel: z.string().max(60).nullable(),
  tipMinor: minor.nullable(),
  discounts: z.array(z.object({ label: z.string().min(1).max(60), amountMinor: minor })).max(10),
  printedTotalMinor: minor.nullable(),
  ambiguities: z.array(ambiguitySchema).default([]),
});
export type ReceiptExtraction = z.infer<typeof receiptExtractionSchema>;
```

- [ ] **Step 4: Implement the extraction**

Create `api/src/ai/extract_receipt.ts`. The system prompt is spec §7.1 plus the units the schema needs. The model is told to refer to lines by position, and `remapLineField` turns `lines[3]` into Split's `lines.{id}`:

```ts
import { receiptExtractionSchema, type Ambiguity, type ReceiptExtraction } from './schemas.js';
import { generateStructured, toDataUri, type ChatTransport } from './client.js';
import { lineIdFor, receiptProblems } from '../domain/receipt.js';
import type { Receipt } from '../domain/split.js';

/** Spec §7.1, plus the units the schema needs spelled out. */
export const RECEIPT_SYSTEM = [
  'You read a UK restaurant or bar receipt.',
  'Return every purchased line exactly as printed with its quantity and line total in pence (GBP 16.50 is 1650).',
  'Return the service charge, tip, discounts and the printed total separately. Discount amounts are positive numbers of pence taken off.',
  "A line like 'Lager x3 16.50' is qty 3 with a line total of 1650, not three lines.",
  'If two images are given, they are parts of one long receipt: join them and do not double-count the overlap.',
  'If a value is unreadable, return null and add an ambiguity. Refer to a line by its position from 0, as lines[3].',
  'Never compute or correct a total; report what is printed.',
  'If the image is not a receipt, return no lines and a null total.',
].join(' ');

const nullableInt = { type: ['integer', 'null'] };

export const RECEIPT_JSON_SCHEMA: Record<string, unknown> = {
  type: 'object',
  additionalProperties: false,
  required: [
    'merchant', 'receiptDate', 'lines', 'serviceChargeMinor', 'serviceChargeLabel',
    'tipMinor', 'discounts', 'printedTotalMinor', 'ambiguities',
  ],
  properties: {
    merchant: { type: ['string', 'null'] },
    receiptDate: { type: ['string', 'null'], description: 'ISO date, YYYY-MM-DD' },
    lines: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['name', 'qty', 'lineTotalMinor'],
        properties: { name: { type: 'string' }, qty: { type: 'integer' }, lineTotalMinor: nullableInt },
      },
    },
    serviceChargeMinor: nullableInt,
    serviceChargeLabel: { type: ['string', 'null'] },
    tipMinor: nullableInt,
    discounts: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['label', 'amountMinor'],
        properties: { label: { type: 'string' }, amountMinor: { type: 'integer' } },
      },
    },
    printedTotalMinor: nullableInt,
    ambiguities: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['field', 'kind', 'question', 'options', 'blocking'],
        properties: {
          field: { type: 'string' },
          kind: { type: 'string', enum: ['missing', 'unclear', 'price_conflict', 'qty_unclear'] },
          question: { type: 'string' },
          options: { type: 'array', items: { type: 'string' } },
          blocking: { type: 'boolean' },
        },
      },
    },
  },
};

export async function extractReceipt(
  images: { buffer: Buffer; mime: string }[],
  transport: ChatTransport,
  model: string,
): Promise<ReceiptExtraction> {
  if (images.length < 1 || images.length > 2) throw new Error('extractReceipt takes one or two images');
  return generateStructured(
    {
      schemaName: 'receipt_extraction',
      schema: receiptExtractionSchema,
      jsonSchema: RECEIPT_JSON_SCHEMA,
      system: RECEIPT_SYSTEM,
      ...(images.length === 2 ? { text: 'These are two parts of one long receipt, top part first.' } : {}),
      images: images.map((i) => toDataUri(i.buffer, i.mime)),
    },
    transport,
    model,
  );
}

/**
 * The draft receipt and its ambiguities. Code checks the arithmetic: the
 * model's own questions are kept as non-blocking notes, and every blocking
 * problem (an unread price, an unread total, a bill that does not add up) is
 * derived from the numbers by receiptProblems().
 */
export function toDraftReceipt(extraction: ReceiptExtraction): { receipt: Receipt; ambiguities: Ambiguity[] } {
  const lines = extraction.lines.map((l, i) => ({
    id: lineIdFor(l.name, i),
    name: l.name.trim(),
    qty: l.qty,
    lineTotalMinor: l.lineTotalMinor,
  }));
  const receipt: Receipt = {
    lines,
    serviceChargeMinor: extraction.serviceChargeMinor ?? 0,
    serviceChargeLabel: extraction.serviceChargeLabel,
    tipMinor: extraction.tipMinor ?? 0,
    discounts: extraction.discounts,
    printedTotalMinor: extraction.printedTotalMinor,
    currency: 'GBP',
  };
  const derived = receiptProblems(receipt);
  const notes = extraction.ambiguities
    .map((a) => ({ ...a, field: remapLineField(a.field, lines), blocking: false }))
    .filter((a) => !derived.some((d) => d.field === a.field));
  return { receipt, ambiguities: [...derived, ...notes] };
}

/** The model says `lines[3].qty`; Split's fields name lines by id. */
export function remapLineField(field: string, lines: { id: string }[]): string {
  const m = /^lines\[(\d+)\](.*)$/.exec(field);
  if (!m) return field;
  const line = lines[Number(m[1])];
  return line ? `lines.${line.id}${m[2]}` : field;
}
```

- [ ] **Step 5: Write the live test**

Create `api/test/extract-receipt.live.test.ts`, gated exactly like `ai-client.live.test.ts` (it reads `api/.env` and skips without `OPENAI_API_KEY` and `OPENAI_VISION_MODEL`). For each sample receipt in Task 5 (the curry as one call with both parts), run `extractReceipt` then `toDraftReceipt`, and assert:
- `ambiguities.filter(a => a.blocking)` is empty, which means it read every price and the bill adds up;
- `receipt.printedTotalMinor` is the table's figure;
- for Little Bao House, the lines equal `loadDemoSplit().receipt.lines` by name, qty and line total. **"Lager x3" must be qty 3 / 1650**, the failure gpt-4.1-mini showed on Sorted;
- for the curry, exactly 18 lines, so the overlap was not double-counted.

Log latency and output tokens for Task 7. Allow 60 s per test.

- [ ] **Step 6: Run, typecheck, commit**

```bash
cd api && npx vitest run test/extract-receipt.test.ts && npm run typecheck
git add api/src/ai api/test/extract-receipt*.test.ts
git commit -m "ai: read a receipt into lines, service, discounts and the printed total"
```

---

### Task 7: The model spike (operator, needs a live OpenAI key)

Spec §7.1: before building on extraction, run the same receipts through two or three candidate models and record the results. The failure to look for is a quantity misread that silently changes money.

**Files:**
- Create: `docs/verified-facts.md`

- [ ] **Step 1: Run the live suite once per candidate**

Run `gpt-5.5` (Sorted's pin), `gpt-5.4-mini` and `gpt-5-mini`. Change `OPENAI_VISION_MODEL` in `api/.env` between runs:

```bash
cd api && npx vitest run test/extract-receipt.live.test.ts
```

- [ ] **Step 2: Record the results**

Create `docs/verified-facts.md` with sections *Deployment*, *Firebase*, *PayPal*, *OpenAI* and *Still unverified*, in Sorted's style. Under *OpenAI*, add a table with one row per model: latency, output tokens, whether each of the four receipts read with no blocking ambiguity, and any misread, quoted exactly. Pin the winner as `OPENAI_VISION_MODEL`, with the date. If more than one is correct, prefer correctness, then latency, never price alone (Sorted's gpt-4.1-mini lesson).

- [ ] **Step 3: Commit**

```bash
git add docs/verified-facts.md && git commit -m "docs: receipt model spike results"
```

---

### Task 8: Split documents

**Files:**
- Create: `api/src/domain/splits.ts`

**Interfaces:**
- Consumes: `allocate` (Task 3), the Task 1 types, `ApiError`.
- Produces, from `src/domain/splits.ts`:
  - `type SplitStatus`, `type ParticipantStatus` (spec §2, all ten), `type SplitDoc`, `type ParticipantDoc`
  - `PARTICIPANT_COLOURS = 8`, `newParticipant(id, { name, joinOrder, isOrganiser }): ParticipantDoc` (colour = join order mod 8, status `invited`)
  - `defaultTitle(receiptDate | null): string`
  - `computeFor(split, participants): Allocation`, **the only caller of `allocate` outside tests**
  - `splitPath(organiserId, splitId)`
  - `type NewSplitInput`, `prepareSplit(db, organiserId, input): { split, write(batchOrTx) }`, `createSplit(db, organiserId, input): Promise<SplitDoc>`
  - `readSplit(tx, db, organiserId, splitId)`: split and participants inside a transaction, or a 404
  - `assertStatus(split, allowed, action)`: a 409 `SPLIT_STATE_INVALID` naming the current status
  - `toApi(value)`: Timestamps to ISO strings, recursively

- [ ] **Step 1: Implement**

Create `api/src/domain/splits.ts`. There is no separate unit test: every function is exercised through the routes in Tasks 9 and 10, against the emulator, which is where its Firestore behaviour matters.

```ts
import { FieldValue, Timestamp, type DocumentReference, type Firestore, type Transaction } from 'firebase-admin/firestore';
import type { Ambiguity } from '../ai/schemas.js';
import { ApiError } from '../lib/errors.js';
import { allocate } from './allocate.js';
import { DEFAULT_RULES, type Allocation, type Claim, type Receipt, type Rules } from './split.js';

export type SplitStatus = 'draft' | 'claiming' | 'collecting' | 'settled' | 'cancelled';

export type ParticipantStatus =
  | 'invited' | 'claimed' | 'owes' | 'link_opened' | 'processing'
  | 'pending' | 'declined' | 'paid' | 'paid_cash' | 'on_us';

/** organisers/{uid}/splits/{splitId}. Spec §2. */
export type SplitDoc = {
  id: string;
  title: string;
  merchant: string | null;
  receiptDate: string | null;
  status: SplitStatus;
  receipt: Receipt;
  receiptAmbiguities: Ambiguity[];
  claims: Record<string, Claim[]>;
  rules: Rules;
  organiserParticipantId: string;
  computed: Allocation | null;
  lockedAt: Timestamp | null;
  extractionModel: string;
  sourceRef: string | null;
};

/** organisers/{uid}/splits/{splitId}/participants/{participantId}. Spec §2. */
export type ParticipantDoc = {
  id: string;
  name: string;
  colourIndex: number;
  isOrganiser: boolean;
  joinOrder: number;
  status: ParticipantStatus;
  claimText: string | null;
  shareMinor: number | null;
  paypalOrderId: string | null;
  approvalUrl: string | null;
  paypalCaptureId: string | null;
  supersededPaypalOrderIds: string[];
  nudge: { count: number; lastSentAt: Timestamp | null; lastText: string | null; channel: string | null; snoozedUntil: Timestamp | null };
  linkOpenedAt: Timestamp | null;
  claimedAt: Timestamp | null;
  paidAt: Timestamp | null;
  aiParsesUsed: number;
};

/** Eight colours (DESIGN.md), assigned in join order, the organiser first. */
export const PARTICIPANT_COLOURS = 8;

export function newParticipant(
  id: string,
  input: { name: string; joinOrder: number; isOrganiser: boolean },
): ParticipantDoc {
  return {
    id,
    name: input.name,
    colourIndex: input.joinOrder % PARTICIPANT_COLOURS,
    isOrganiser: input.isOrganiser,
    joinOrder: input.joinOrder,
    status: 'invited',
    claimText: null,
    shareMinor: null,
    paypalOrderId: null,
    approvalUrl: null,
    paypalCaptureId: null,
    supersededPaypalOrderIds: [],
    nudge: { count: 0, lastSentAt: null, lastText: null, channel: null, snoozedUntil: null },
    linkOpenedAt: null,
    claimedAt: null,
    paidAt: null,
    aiParsesUsed: 0,
  };
}

/** "Friday's bill" from 2026-10-02, or "Your bill" when the date was unread. */
export function defaultTitle(receiptDate: string | null): string {
  if (!receiptDate) return 'Your bill';
  const day = new Date(`${receiptDate}T12:00:00Z`).toLocaleDateString('en-GB', { weekday: 'long', timeZone: 'Europe/London' });
  return `${day}'s bill`;
}

/** The single place `computed` comes from. The app only ever renders this. */
export function computeFor(split: Pick<SplitDoc, 'receipt' | 'claims' | 'rules'>, participants: ParticipantDoc[]): Allocation {
  return allocate({
    receipt: split.receipt,
    claims: split.claims,
    rules: split.rules,
    participants: participants.map((p) => ({ id: p.id, joinOrder: p.joinOrder, isOrganiser: p.isOrganiser })),
  });
}

export const splitPath = (organiserId: string, splitId: string) => `organisers/${organiserId}/splits/${splitId}`;

export type NewSplitInput = {
  title?: string;
  merchant: string | null;
  receiptDate: string | null;
  receipt: Receipt;
  receiptAmbiguities: Ambiguity[];
  extractionModel: string;
  sourceRef: string | null;
  organiserName: string;
};

/** A WriteBatch or a Transaction: both can set a document. */
type Setter = { set(ref: DocumentReference, data: Record<string, unknown>): unknown };

/**
 * Builds a new draft split and its organiser participant, with `computed`
 * already filled in so the app's listener never sees a split without one.
 * `write` queues both documents on a batch or a transaction.
 */
export function prepareSplit(db: Firestore, organiserId: string, input: NewSplitInput): { split: SplitDoc; write: (w: Setter) => void } {
  const ref = db.collection(`organisers/${organiserId}/splits`).doc();
  const organiserRef = ref.collection('participants').doc();
  const organiser = newParticipant(organiserRef.id, { name: input.organiserName, joinOrder: 0, isOrganiser: true });
  const base = { receipt: input.receipt, claims: {}, rules: DEFAULT_RULES };
  const split: SplitDoc = {
    id: ref.id,
    title: input.title ?? defaultTitle(input.receiptDate),
    merchant: input.merchant,
    receiptDate: input.receiptDate,
    status: 'draft',
    ...base,
    receiptAmbiguities: input.receiptAmbiguities,
    organiserParticipantId: organiser.id,
    computed: computeFor(base, [organiser]),
    lockedAt: null,
    extractionModel: input.extractionModel,
    sourceRef: input.sourceRef,
  };
  return {
    split,
    write: (w) => {
      w.set(ref, { ...split, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
      w.set(organiserRef, organiser);
    },
  };
}

export async function createSplit(db: Firestore, organiserId: string, input: NewSplitInput): Promise<SplitDoc> {
  const { split, write } = prepareSplit(db, organiserId, input);
  const batch = db.batch();
  write(batch);
  await batch.commit();
  return split;
}

/** Reads a split and its participants inside a transaction, or 404s. */
export async function readSplit(
  tx: Transaction,
  db: Firestore,
  organiserId: string,
  splitId: string,
): Promise<{ ref: DocumentReference; split: SplitDoc; participants: ParticipantDoc[] }> {
  const ref = db.doc(splitPath(organiserId, splitId));
  const snap = await tx.get(ref);
  if (!snap.exists) throw new ApiError(404, 'NOT_FOUND', 'That split does not exist.');
  const people = await tx.get(ref.collection('participants'));
  return {
    ref,
    split: { ...(snap.data() as SplitDoc), id: snap.id },
    participants: people.docs.map((d) => ({ ...(d.data() as ParticipantDoc), id: d.id })),
  };
}

export function assertStatus(split: SplitDoc, allowed: SplitStatus[], action: string): void {
  if (!allowed.includes(split.status)) {
    throw new ApiError(409, 'SPLIT_STATE_INVALID', `You can only ${action} while the split is ${allowed.join(' or ')}.`, {
      status: split.status,
    });
  }
}

/** Firestore values to API JSON: Timestamps become ISO strings, recursively. */
export function toApi<T>(value: T): unknown {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(toApi);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, toApi(v)]));
  }
  return value;
}
```

- [ ] **Step 2: Typecheck and commit**

```bash
cd api && npm run typecheck
git add api/src/domain/splits.ts && git commit -m "splits: documents, participants and the single place computed comes from"
```

---

### Task 9: `POST /splits/scan`, `PATCH /splits/:id/receipt`, `PATCH /splits/:id/rules`

**Files:**
- Create: `api/src/routes/splits.ts`
- Modify: `api/src/app.ts`
- Test: `api/test/splits-route.test.ts`

**Interfaces:**
- Consumes: `extractReceipt`, `toDraftReceipt` (Task 6); everything in Task 8; `requireOrganiser`; `looksLikeUpload`, `visionMime`.
- Produces, from `src/routes/splits.ts`: `splitsRouter({ db, verify, transport, model })`, `receiptPatchSchema`, `rulesPatchSchema`, `applyReceiptPatch(receipt, patch)`, `nextAmbiguities(receipt, previous, touched)`.
- HTTP, all organiser-authenticated:
  - `POST /v1/splits/scan`: multipart `images[]`, 1–2, each ≤ 8 MB. Returns `201 { split }`, with `status: 'draft'`, the organiser participant created and `computed` filled. A mismatch is stored as a blocking ambiguity, not refused. A model that fails twice returns `502 AI_PARSE_FAILED`, so the app falls back to manual entry.
  - `PATCH /v1/splits/:id/receipt`: `{ lines?: [{ id, name?, qty?, lineTotalMinor? }], addLines?, removeLineIds?, serviceChargeMinor?, serviceChargeLabel?, tipMinor?, discounts?, printedTotalMinor? }`, strict, at least one key. Draft only (409 otherwise). Rejects unknown line ids with a 400. Re-derives `receiptAmbiguities`, drops claims on removed lines, recomputes `computed`, all in one transaction. Returns `{ split }`.
  - `PATCH /v1/splits/:id/rules`: partial `Rules`, strict. `draft` or `claiming`. Rejects participant ids not in the split with a 400. Recomputes in the same transaction. Returns `{ split }`.
  - Someone else's split id is a 404, never a 403, so ids cannot be probed.

- [ ] **Step 1: Write the failing test**

Create `api/test/splits-route.test.ts`:

```ts
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';
import type { ChatTransport } from '../src/ai/client.js';
import type { ReceiptExtraction } from '../src/ai/schemas.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-splits-test', INTERNAL_TOKEN: 'internal',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-splits-test' });
  db = getFirestore();
});

beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

const PNG = Buffer.from('89504e470d0a1a0a0000000d49484452', 'hex');

const reading: ReceiptExtraction = {
  merchant: 'Little Bao House',
  receiptDate: '2026-10-02',
  lines: [
    { name: 'Prawn crackers', qty: 1, lineTotalMinor: 550 },
    { name: 'Lager', qty: 3, lineTotalMinor: 1650 },
  ],
  serviceChargeMinor: 275,
  serviceChargeLabel: '12.5% discretionary',
  tipMinor: null,
  discounts: [],
  printedTotalMinor: 2475,
  ambiguities: [],
};

function app(transport: ChatTransport = async () => ({ content: JSON.stringify(reading) })) {
  return createApp({
    env, db, paypal: async () => ({}), transport,
    verify: async (t: string) => {
      if (t === 'kemi' || t === 'stranger') return { uid: t };
      throw new Error('bad token');
    },
  });
}

async function scan(extraction: ReceiptExtraction = reading) {
  const res = await request(app(async () => ({ content: JSON.stringify(extraction) })))
    .post('/v1/splits/scan')
    .set('Authorization', 'Bearer kemi')
    .attach('images', PNG, 'bill.png');
  expect(res.status).toBe(201);
  return res.body.split as { id: string; receipt: { lines: { id: string }[] }; organiserParticipantId: string };
}

describe('POST /v1/splits/scan', () => {
  it('reads the bill into a draft split with the organiser in it', async () => {
    await db.doc('organisers/kemi').set({ displayName: 'Kemi' });
    const split = await scan();
    expect(split).toMatchObject({ status: 'draft', merchant: 'Little Bao House', title: "Friday's bill", receiptAmbiguities: [] });
    const stored = await db.doc(`organisers/kemi/splits/${split.id}`).get();
    expect(stored.get('receipt.printedTotalMinor')).toBe(2475);
    expect(stored.get('extractionModel')).toBe('test-model');
    expect(stored.get('computed.ok')).toBe(false); // nothing is claimed yet
    const people = await stored.ref.collection('participants').get();
    expect(people.docs.map((d) => d.data())).toEqual([expect.objectContaining({ name: 'Kemi', isOrganiser: true, joinOrder: 0, colourIndex: 0 })]);
  });

  it('stores a mismatch as a blocking ambiguity rather than refusing the scan', async () => {
    const split = await scan({ ...reading, printedTotalMinor: 9999 }) as unknown as { receiptAmbiguities: { kind: string }[] };
    expect(split.receiptAmbiguities).toEqual([expect.objectContaining({ kind: 'price_conflict' })]);
  });

  it('refuses a request with no photo, three photos, or a non-image', async () => {
    const auth = (r: request.Test) => r.set('Authorization', 'Bearer kemi');
    expect((await auth(request(app()).post('/v1/splits/scan'))).status).toBe(400);
    const three = auth(request(app()).post('/v1/splits/scan'))
      .attach('images', PNG, 'a.png').attach('images', PNG, 'b.png').attach('images', PNG, 'c.png');
    expect((await three).body.error.code).toBe('VALIDATION_FAILED');
    const text = await auth(request(app()).post('/v1/splits/scan')).attach('images', Buffer.from('hello'), { filename: 'a.png', contentType: 'image/png' });
    expect(text.status).toBe(400);
  });

  it('needs a signed-in organiser', async () => {
    expect((await request(app()).post('/v1/splits/scan').attach('images', PNG, 'a.png')).status).toBe(401);
  });

  it('falls back to manual entry when the model fails twice', async () => {
    const res = await request(app(async () => ({ content: 'not json' })))
      .post('/v1/splits/scan').set('Authorization', 'Bearer kemi').attach('images', PNG, 'a.png');
    expect(res.status).toBe(502);
    expect(res.body.error.code).toBe('AI_PARSE_FAILED');
  });
});

describe('PATCH /v1/splits/:id/receipt', () => {
  it('fixing a misread line clears the mismatch and recomputes', async () => {
    const split = await scan({ ...reading, lines: [reading.lines[0]!, { name: 'Lager', qty: 3, lineTotalMinor: 1560 }] });
    const res = await request(app()).patch(`/v1/splits/${split.id}/receipt`).set('Authorization', 'Bearer kemi')
      .send({ lines: [{ id: 'lager-1', lineTotalMinor: 1650 }] });
    expect(res.status).toBe(200);
    expect(res.body.split.receiptAmbiguities).toEqual([]);
    const stored = await db.doc(`organisers/kemi/splits/${split.id}`).get();
    expect(stored.get('receipt.lines')[1].lineTotalMinor).toBe(1650);
    expect(stored.get('receiptAmbiguities')).toEqual([]);
  });

  it('raises the mismatch again when an edit breaks the sum', async () => {
    const split = await scan();
    const res = await request(app()).patch(`/v1/splits/${split.id}/receipt`).set('Authorization', 'Bearer kemi')
      .send({ serviceChargeMinor: 300 });
    expect(res.body.split.receiptAmbiguities[0]).toMatchObject({ kind: 'price_conflict' });
  });

  it('adds and removes lines without reusing an id', async () => {
    const split = await scan();
    const res = await request(app()).patch(`/v1/splits/${split.id}/receipt`).set('Authorization', 'Bearer kemi')
      .send({ removeLineIds: ['lager-1'], addLines: [{ name: 'Lager', qty: 3, lineTotalMinor: 1650 }] });
    expect(res.body.split.receipt.lines.map((l: { id: string }) => l.id)).toEqual(['prawn-crackers-0', 'lager-2']);
  });

  it('400s on a line that is not on the bill, and on an empty body', async () => {
    const split = await scan();
    const send = (body: object) => request(app()).patch(`/v1/splits/${split.id}/receipt`).set('Authorization', 'Bearer kemi').send(body);
    expect((await send({ lines: [{ id: 'nope', qty: 2 }] })).status).toBe(400);
    expect((await send({})).status).toBe(400);
    expect((await send({ printedTotalMinor: -1 })).status).toBe(400);
  });

  it('409s once the split has left draft', async () => {
    const split = await scan();
    await db.doc(`organisers/kemi/splits/${split.id}`).update({ status: 'claiming' });
    const res = await request(app()).patch(`/v1/splits/${split.id}/receipt`).set('Authorization', 'Bearer kemi').send({ tipMinor: 100 });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('SPLIT_STATE_INVALID');
  });

  it("404s for someone else's split", async () => {
    const split = await scan();
    const res = await request(app()).patch(`/v1/splits/${split.id}/receipt`).set('Authorization', 'Bearer stranger').send({ tipMinor: 100 });
    expect(res.status).toBe(404);
  });
});

describe('PATCH /v1/splits/:id/rules', () => {
  it('changes the service mode and recomputes', async () => {
    const split = await scan();
    const res = await request(app()).patch(`/v1/splits/${split.id}/rules`).set('Authorization', 'Bearer kemi').send({ serviceMode: 'even' });
    expect(res.status).toBe(200);
    expect(res.body.split.rules).toEqual({ serviceMode: 'even', onUs: [], onUsPaidBy: null, serviceOptOut: [] });
  });

  it('refuses a rule naming someone not in the group', async () => {
    const split = await scan();
    const res = await request(app()).patch(`/v1/splits/${split.id}/rules`).set('Authorization', 'Bearer kemi').send({ onUs: ['ghost'] });
    expect(res.status).toBe(400);
  });

  it('is frozen once the split is collecting', async () => {
    const split = await scan();
    await db.doc(`organisers/kemi/splits/${split.id}`).update({ status: 'collecting' });
    const res = await request(app()).patch(`/v1/splits/${split.id}/rules`).set('Authorization', 'Bearer kemi').send({ serviceMode: 'even' });
    expect(res.status).toBe(409);
  });
});
```

- [ ] **Step 2: Run it to see it fail** (start the emulator first: `cd api && npm run emulators`)

- [ ] **Step 3: Implement the router**

Create `api/src/routes/splits.ts`:

```ts
import { Router, type RequestHandler } from 'express';
import { z } from 'zod';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import multer, { MulterError } from 'multer';
import { ApiError } from '../lib/errors.js';
import { requireOrganiser, type TokenVerifier } from '../lib/auth.js';
import { looksLikeUpload, visionMime } from '../lib/image_type.js';
import type { ChatTransport } from '../ai/client.js';
import { extractReceipt, toDraftReceipt } from '../ai/extract_receipt.js';
import { lineIdFor, receiptProblems } from '../domain/receipt.js';
import { assertStatus, computeFor, createSplit, readSplit, toApi } from '../domain/splits.js';
import type { Ambiguity } from '../ai/schemas.js';
import type { Receipt, Rules } from '../domain/split.js';

const MAX_IMAGES = 2;
const MAX_BYTES = 8 * 1024 * 1024;
const MAX_LINES = 60;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_BYTES, files: MAX_IMAGES },
  fileFilter: (_req, file, cb) => {
    if (!looksLikeUpload(file.mimetype)) {
      cb(new ApiError(400, 'VALIDATION_FAILED', `${file.mimetype} is not an image Split can read.`));
      return;
    }
    cb(null, true);
  },
}).array('images', MAX_IMAGES);

const receiveImages: RequestHandler = (req, res, next) => {
  upload(req, res, (err: unknown) => {
    if (err instanceof MulterError) {
      const message =
        err.code === 'LIMIT_FILE_SIZE'
          ? 'Each photo must be 8MB or smaller.'
          : err.code === 'LIMIT_FILE_COUNT' || err.code === 'LIMIT_UNEXPECTED_FILE'
            ? 'Send one photo, or two for a long bill.'
            : 'That upload could not be read.';
      next(new ApiError(400, 'VALIDATION_FAILED', message));
      return;
    }
    next(err as Error | undefined);
  });
};

const minor = z.number().int().nonnegative().max(100_000_00);
const lineName = z.string().trim().min(1).max(80);
const qty = z.number().int().min(1).max(99);

export const receiptPatchSchema = z
  .object({
    lines: z.array(z.object({ id: z.string().min(1), name: lineName.optional(), qty: qty.optional(), lineTotalMinor: minor.nullable().optional() }).strict()).max(MAX_LINES),
    addLines: z.array(z.object({ name: lineName, qty, lineTotalMinor: minor.nullable() }).strict()).max(MAX_LINES),
    removeLineIds: z.array(z.string().min(1)).max(MAX_LINES),
    serviceChargeMinor: minor,
    serviceChargeLabel: z.string().trim().max(60).nullable(),
    tipMinor: minor,
    discounts: z.array(z.object({ label: z.string().trim().min(1).max(60), amountMinor: minor }).strict()).max(10),
    printedTotalMinor: minor,
  })
  .partial()
  .strict()
  .refine((b) => Object.keys(b).length > 0, 'Send at least one change.');

export const rulesPatchSchema = z
  .object({
    serviceMode: z.enum(['proportional', 'even']),
    onUs: z.array(z.string().min(1)).max(20),
    onUsPaidBy: z.array(z.string().min(1)).min(1).max(20).nullable(),
    serviceOptOut: z.array(z.string().min(1)).max(20),
  })
  .partial()
  .strict()
  .refine((b) => Object.keys(b).length > 0, 'Send at least one change.');

/** The index after the highest one in use, so an added line never reuses a removed line's id. */
function nextLineIndex(receipt: Receipt): number {
  return receipt.lines.reduce((max, l) => Math.max(max, Number(/-(\d+)$/.exec(l.id)?.[1] ?? -1)), -1) + 1;
}

/**
 * Applies a receipt edit. Throws a 400 naming any line id that is not on the
 * bill, rather than silently ignoring an edit the organiser thinks they made.
 */
export function applyReceiptPatch(receipt: Receipt, patch: z.infer<typeof receiptPatchSchema>): { receipt: Receipt; touched: Set<string> } {
  const byId = new Map(receipt.lines.map((l) => [l.id, l]));
  const unknown = [...(patch.lines ?? []).map((l) => l.id), ...(patch.removeLineIds ?? [])].filter((id) => !byId.has(id));
  if (unknown.length > 0) {
    throw new ApiError(400, 'VALIDATION_FAILED', 'That line is no longer on the bill.', { lineIds: unknown });
  }
  const touched = new Set<string>([...(patch.removeLineIds ?? []), ...(patch.lines ?? []).map((l) => l.id)]);
  const edits = new Map((patch.lines ?? []).map((l) => [l.id, l]));
  const removed = new Set(patch.removeLineIds ?? []);
  const lines = receipt.lines
    .filter((l) => !removed.has(l.id))
    .map((l) => {
      const e = edits.get(l.id);
      return e
        ? { ...l, ...(e.name === undefined ? {} : { name: e.name }), ...(e.qty === undefined ? {} : { qty: e.qty }), ...(e.lineTotalMinor === undefined ? {} : { lineTotalMinor: e.lineTotalMinor }) }
        : l;
    });
  let next = nextLineIndex(receipt);
  for (const add of patch.addLines ?? []) lines.push({ id: lineIdFor(add.name, next++), ...add });
  if (lines.length > MAX_LINES) throw new ApiError(400, 'VALIDATION_FAILED', `A bill can have at most ${MAX_LINES} lines.`);
  return {
    touched,
    receipt: {
      ...receipt,
      lines,
      ...(patch.serviceChargeMinor === undefined ? {} : { serviceChargeMinor: patch.serviceChargeMinor }),
      ...(patch.serviceChargeLabel === undefined ? {} : { serviceChargeLabel: patch.serviceChargeLabel }),
      ...(patch.tipMinor === undefined ? {} : { tipMinor: patch.tipMinor }),
      ...(patch.discounts === undefined ? {} : { discounts: patch.discounts }),
      ...(patch.printedTotalMinor === undefined ? {} : { printedTotalMinor: patch.printedTotalMinor }),
    },
  };
}

/**
 * Blocking problems are re-derived from the numbers. The model's own notes
 * survive unless the organiser has since edited or removed the line they
 * were about, or a derived problem now covers the same field.
 */
export function nextAmbiguities(receipt: Receipt, previous: Ambiguity[], touched: Set<string>): Ambiguity[] {
  const derived = receiptProblems(receipt);
  const notes = previous.filter((a) => {
    if (a.blocking) return false;
    const line = /^lines\.([^.]+)/.exec(a.field)?.[1];
    if (line && touched.has(line)) return false;
    return !derived.some((d) => d.field === a.field);
  });
  return [...derived, ...notes];
}

export type SplitsDeps = { db: Firestore; verify: TokenVerifier; transport: ChatTransport; model: string };

export function splitsRouter(deps: SplitsDeps): Router {
  const router = Router();
  const auth = requireOrganiser(deps.verify);

  // Spec §4 endpoint 4. Synchronous, 3-10 s: the app shows Reading meanwhile.
  router.post('/splits/scan', auth, receiveImages, async (req, res, next) => {
    try {
      const files = (req.files ?? []) as Express.Multer.File[];
      if (files.length === 0) throw new ApiError(400, 'VALIDATION_FAILED', 'Attach a photo of the bill.');
      const images = files.map((f) => ({ buffer: f.buffer, mime: visionMime(f.buffer) }));
      const extraction = await extractReceipt(images, deps.transport, deps.model);
      const { receipt, ambiguities } = toDraftReceipt(extraction);
      const organiser = await deps.db.doc(`organisers/${req.organiserId}`).get();
      const name = organiser.get('displayName');
      const split = await createSplit(deps.db, req.organiserId!, {
        merchant: extraction.merchant,
        receiptDate: extraction.receiptDate,
        receipt,
        receiptAmbiguities: ambiguities,
        extractionModel: deps.model,
        sourceRef: null,
        organiserName: typeof name === 'string' && name.trim() ? name.trim() : 'You',
      });
      res.status(201).json({ split: toApi(split) });
    } catch (err) {
      next(err);
    }
  });

  // Spec §4 endpoint 5. Draft only: once friends are claiming, lines are what they claim against.
  router.patch('/splits/:splitId/receipt', auth, async (req, res, next) => {
    const parsed = receiptPatchSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      next(new ApiError(400, 'VALIDATION_FAILED', 'That change to the bill is not valid.', parsed.error.format()));
      return;
    }
    try {
      const split = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants } = await readSplit(tx, deps.db, req.organiserId!, String(req.params.splitId));
        assertStatus(split, ['draft'], 'edit the bill');
        const { receipt, touched } = applyReceiptPatch(split.receipt, parsed.data);
        const claims = Object.fromEntries(Object.entries(split.claims).filter(([id]) => receipt.lines.some((l) => l.id === id)));
        const next = { ...split, receipt, claims, receiptAmbiguities: nextAmbiguities(receipt, split.receiptAmbiguities, touched) };
        const computed = computeFor(next, participants);
        tx.update(ref, { receipt, claims, receiptAmbiguities: next.receiptAmbiguities, computed, updatedAt: FieldValue.serverTimestamp() });
        return { ...next, computed };
      });
      res.json({ split: toApi(split) });
    } catch (err) {
      next(err);
    }
  });

  // Spec §4 endpoint 12. Frozen from lock onwards.
  router.patch('/splits/:splitId/rules', auth, async (req, res, next) => {
    const parsed = rulesPatchSchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      next(new ApiError(400, 'VALIDATION_FAILED', 'That rule is not valid.', parsed.error.format()));
      return;
    }
    try {
      const split = await deps.db.runTransaction(async (tx) => {
        const { ref, split, participants } = await readSplit(tx, deps.db, req.organiserId!, String(req.params.splitId));
        assertStatus(split, ['draft', 'claiming'], 'change the rules');
        const known = new Set(participants.map((p) => p.id));
        const named = [...(parsed.data.onUs ?? []), ...(parsed.data.onUsPaidBy ?? []), ...(parsed.data.serviceOptOut ?? [])];
        const strangers = named.filter((id) => !known.has(id));
        if (strangers.length > 0) {
          throw new ApiError(400, 'VALIDATION_FAILED', 'That rule names someone who is not in the group.', { participantIds: strangers });
        }
        const patch = parsed.data;
        const rules: Rules = {
          serviceMode: patch.serviceMode ?? split.rules.serviceMode,
          onUs: patch.onUs ?? split.rules.onUs,
          onUsPaidBy: patch.onUsPaidBy === undefined ? split.rules.onUsPaidBy : patch.onUsPaidBy,
          serviceOptOut: patch.serviceOptOut ?? split.rules.serviceOptOut,
        };
        const computed = computeFor({ ...split, rules }, participants);
        tx.update(ref, { rules, computed, updatedAt: FieldValue.serverTimestamp() });
        return { ...split, rules, computed };
      });
      res.json({ split: toApi(split) });
    } catch (err) {
      next(err);
    }
  });

  return router;
}
```

- [ ] **Step 4: Mount it**

In `api/src/app.ts`, import `splitsRouter` and mount it after `healthRouter`:

```ts
  app.use(
    '/v1',
    splitsRouter({ db: deps.db, verify: deps.verify, transport: deps.transport, model: deps.env.OPENAI_VISION_MODEL }),
  );
```

- [ ] **Step 5: Run, typecheck, full suite, commit**

```bash
cd api && npx vitest run test/splits-route.test.ts && npm run typecheck && npm test
git add api/src/routes/splits.ts api/src/app.ts api/test/splits-route.test.ts
git commit -m "splits: scan a bill, fix the receipt, change the rules"
```

Expected: 14 new tests pass.

---

### Task 10: Bootstrap and the demo seed

**Files:**
- Create: `api/src/domain/seed.ts`, `api/src/routes/session.ts`
- Modify: `api/src/app.ts`
- Test: `api/test/session-route.test.ts`

**Interfaces:**
- Consumes: `loadDemoSplit` (Task 1), `receiptProblems` (Task 3), `prepareSplit`, `toApi` (Task 8).
- Produces, from `src/domain/seed.ts`: `type OrganiserDoc = { id, displayName, paypalEmail: string | null, demoSeeded, createdAt? }`, `bootstrapOrganiser(db, organiserId, { demo }, demo?): Promise<{ organiser, seededSplitId }>`.
- HTTP: `POST /v1/session/bootstrap { demo?: boolean = true }` returns `{ organiser, seededSplitId: string | null }`. With `demo`, a new organiser is named "Kemi" (from the seed file) and gets the Little Bao House split in `draft`; without it, "You" and no split.

- [ ] **Step 1: Write the failing test**

Create `api/test/session-route.test.ts`:

```ts
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { requireEmulator } from './emulator-guard.js';
import request from 'supertest';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { createApp } from '../src/app.js';
import { loadEnv } from '../src/env.js';

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.METADATA_SERVER_DETECTION = 'none';

const env = loadEnv({
  NODE_ENV: 'test',
  PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'wh-1',
  OPENAI_API_KEY: 'x', OPENAI_VISION_MODEL: 'test-model',
  FIREBASE_PROJECT_ID: 'split-session-test', INTERNAL_TOKEN: 'internal',
});

let db: Firestore;
beforeAll(async () => {
  await requireEmulator();
  if (getApps().length === 0) initializeApp({ projectId: 'split-session-test' });
  db = getFirestore();
});
beforeEach(async () => {
  const organisers = await db.collection('organisers').listDocuments();
  await Promise.all(organisers.map((s) => db.recursiveDelete(s)));
});

const app = () => createApp({
  env, db, paypal: async () => ({}), transport: async () => ({ content: '{}' }),
  verify: async (t: string) => ({ uid: t }),
});
const bootstrap = (body: object = { demo: true }, uid = 'judge-1') =>
  request(app()).post('/v1/session/bootstrap').set('Authorization', `Bearer ${uid}`).send(body);

describe('POST /v1/session/bootstrap', () => {
  it('creates Kemi and seeds the Little Bao House bill in draft', async () => {
    const res = await bootstrap();
    expect(res.status).toBe(200);
    expect(res.body.organiser).toMatchObject({ displayName: 'Kemi', paypalEmail: null, demoSeeded: true });
    const split = await db.doc(`organisers/judge-1/splits/${res.body.seededSplitId}`).get();
    expect(split.data()).toMatchObject({ title: 'Friday dinner', merchant: 'Little Bao House', status: 'draft', receiptAmbiguities: [] });
    expect(split.get('receipt.printedTotalMinor')).toBe(15469);
    expect(split.get('receipt.lines')).toHaveLength(10);
  });

  it('is idempotent, even when two calls race', async () => {
    const [a, b] = await Promise.all([bootstrap(), bootstrap()]);
    expect([a.status, b.status]).toEqual([200, 200]);
    await bootstrap();
    const splits = await db.collection('organisers/judge-1/splits').get();
    expect(splits.size).toBe(1);
  });

  it('demo: false creates the organiser with no split', async () => {
    const res = await bootstrap({ demo: false });
    expect(res.body).toMatchObject({ organiser: { displayName: 'You', demoSeeded: false }, seededSplitId: null });
    expect((await db.collection('organisers/judge-1/splits').get()).size).toBe(0);
  });

  it('rejects an unknown field and a missing token', async () => {
    expect((await bootstrap({ demo: true, extra: 1 })).status).toBe(400);
    expect((await request(app()).post('/v1/session/bootstrap').send({})).status).toBe(401);
  });
});
```

- [ ] **Step 2: Run it to see it fail**

- [ ] **Step 3: Implement the seed**

Create `api/src/domain/seed.ts`. The organiser read, the demo split and the `demoSeeded` flag all go through one transaction. That is what keeps the race test at exactly one split; Sorted's week 1 shipped this exact double-seed bug.

```ts
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
```

- [ ] **Step 4: Implement the route and mount it**

Create `api/src/routes/session.ts`:

```ts
import { Router } from 'express';
import { z } from 'zod';
import type { Firestore } from 'firebase-admin/firestore';
import { ApiError } from '../lib/errors.js';
import { requireOrganiser, type TokenVerifier } from '../lib/auth.js';
import { bootstrapOrganiser } from '../domain/seed.js';
import { toApi } from '../domain/splits.js';

const bodySchema = z.object({ demo: z.boolean().default(true) }).strict();

export function sessionRouter(deps: { db: Firestore; verify: TokenVerifier }): Router {
  const router = Router();

  // Spec §4 endpoint 2.
  router.post('/session/bootstrap', requireOrganiser(deps.verify), async (req, res, next) => {
    const parsed = bodySchema.safeParse(req.body ?? {});
    if (!parsed.success) {
      next(new ApiError(400, 'VALIDATION_FAILED', 'Invalid request body.', parsed.error.format()));
      return;
    }
    try {
      const result = await bootstrapOrganiser(deps.db, req.organiserId!, parsed.data);
      res.json({ organiser: toApi(result.organiser), seededSplitId: result.seededSplitId });
    } catch (err) {
      next(err);
    }
  });

  return router;
}
```

In `api/src/app.ts`, mount `sessionRouter({ db: deps.db, verify: deps.verify })` after `healthRouter`.

- [ ] **Step 5: Run, full suite, commit**

```bash
cd api && npx vitest run test/session-route.test.ts && npm test
git add api/src/domain/seed.ts api/src/routes/session.ts api/src/app.ts api/test/session-route.test.ts
git commit -m "session: bootstrap the organiser and seed the demo bill"
```

---

### Task 11: Firestore rules cover splits and participants

`firestore.rules` already allows `organisers/{uid}/**` reads for the owner and denies every client write. This task proves that holds for the new paths, so a later rules edit cannot quietly open them.

**Files:**
- Test: `api/test/firestore-rules.test.ts` (append three cases)

- [ ] **Step 1: Add the cases** inside the existing `describe('firestore rules', ...)`:

```ts
  it('lets an organiser read their own split and its participants', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'organisers/organiser-a/splits/s1'), { status: 'draft' });
      await setDoc(doc(ctx.firestore(), 'organisers/organiser-a/splits/s1/participants/p1'), { name: 'Dan' });
    });
    const db = testEnv.authenticatedContext('organiser-a').firestore();
    await assertSucceeds(getDoc(doc(db, 'organisers/organiser-a/splits/s1')));
    await assertSucceeds(getDoc(doc(db, 'organisers/organiser-a/splits/s1/participants/p1')));
  });

  it("denies reading another organiser's split or participants", async () => {
    const db = testEnv.authenticatedContext('organiser-b').firestore();
    await assertFails(getDoc(doc(db, 'organisers/organiser-a/splits/s1')));
    await assertFails(getDoc(doc(db, 'organisers/organiser-a/splits/s1/participants/p1')));
  });

  it('denies an organiser writing their own split, claims or a participant', async () => {
    const db = testEnv.authenticatedContext('organiser-a').firestore();
    await assertFails(setDoc(doc(db, 'organisers/organiser-a/splits/s2'), { status: 'settled' }));
    await assertFails(setDoc(doc(db, 'organisers/organiser-a/splits/s1/participants/p1'), { status: 'paid' }));
  });
```

- [ ] **Step 2: Run and commit**

```bash
cd api && npx vitest run test/firestore-rules.test.ts
git add api/test/firestore-rules.test.ts && git commit -m "rules: prove splits and participants are read-own, write-never"
```

Expected: 11 tests pass. The API side of Week A is done: `npm test` should show 290 passing.

---

### Task 12: Split's Firebase project (operator)

**Files:**
- Replace: `app/lib/firebase_options.dart` (generated)
- Create: `.firebaserc`
- Modify: `docs/verified-facts.md`

- [ ] **Step 1: Create the project.** In the Firebase console, create a new project (suggested id `split-<suffix>`) on the Spark plan. Enable **Firestore** (region `eur3` or `europe-west2`), **Anonymous** sign-in under Authentication, and **Hosting**.
- [ ] **Step 2: Deploy the rules.** `firebase use --add` (alias `default`), then `firebase deploy --only firestore:rules`.
- [ ] **Step 3: Generate the app config.** In `app/`: `dart pub global activate flutterfire_cli && flutterfire configure --project <id> --platforms=android,ios,web`. This overwrites the placeholder `firebase_options.dart`. `flutter analyze` must stay clean.
- [ ] **Step 4: API credentials.** Create a service account key for the Admin SDK and put it, on one line, in `api/.env` as `FIREBASE_SERVICE_ACCOUNT_JSON`, with `FIREBASE_PROJECT_ID`. Never commit it (`.gitignore` already covers `.env`).
- [ ] **Step 5: Verify live and record.** Run the API locally (`npm run dev`), call `POST /v1/session/bootstrap` with a real anonymous ID token (any quick script with the web config, or from the running app after Task 20), and confirm the `organisers/{uid}` doc and the Little Bao House split appear in the console. Record the project id, region, anonymous auth on, rules deployed, and the date under *Firebase* in `docs/verified-facts.md`.
- [ ] **Step 6: Commit** `app/lib/firebase_options.dart`, `.firebaserc` and `docs/verified-facts.md`.

---

### Task 13: Render `split-api` on `starter`, with the sweeps scheduled (operator)

**Files:**
- Modify: `docs/verified-facts.md`, `README.md`

- [ ] **Step 1: Create the service from the blueprint.** In Render, create a Blueprint from `tade-dev/split` (`api/render.yaml`: service `split-api`, plan `starter`, `rootDir: api`). Set every `sync: false` variable in the dashboard: PayPal sandbox credentials (Sorted's app works, but see Task 14), `PAYPAL_WEBHOOK_ID` (`pending` until Week B registers Split's webhook), OpenAI key and the Task 7 model, Firebase project and service account JSON, a fresh random `INTERNAL_TOKEN`, and `PUBLIC_BASE_URL` once the URL is known.
- [ ] **Step 2: Health check.** `curl https://<service>.onrender.com/v1/health` should return `ok: true`, `paypalEnv: "sandbox"`, and `config.placeholders` listing only what is genuinely still pending. Record the real URL. If it is not `split-api.onrender.com`, update `DEFAULT_PUBLIC_BASE_URL` in `api/src/env.ts`, the `API_BASE_URL` default in `app/lib/core/env.dart`, and `api/.env.example`, in one commit.
- [ ] **Step 3: Schedule the sweeps on day one** (spec §4). Point a scheduler (a Render cron job, or any external cron) at `POST /v1/internal/workflows/reconcile` every 10 minutes and `/expire-sweep` hourly, with header `X-Internal-Token`. Until Week B moves them to participants they scan zero documents, which is fine. The point is that the schedule exists and is proven now. Confirm one run of each returns `200` with zero counts.
- [ ] **Step 4: Prove it does not sleep.** Leave it idle for 20 minutes, then time `/v1/health`. Expect under a second.
- [ ] **Step 5: Record and commit.** Under *Deployment* in `docs/verified-facts.md`: URL, plan `starter`, region (and whether `frankfurt` really applied, which Sorted never confirmed), the scheduler and its two jobs, the idle-wake timing, and the date. Put the API health URL on README line one for now; the web URL joins it in Task 21.

---

### Task 14: PayPal "pay another account" to a personal sandbox account (operator)

Spec §5's week-1 verification, and §9 risk 2. If this is refused, Split falls back to the shared sandbox merchant, and the README and Connect copy must say so.

**Files:**
- Create: `api/scripts/payee-spike.ts` (operator-only, not imported by `src/`)
- Modify: `docs/verified-facts.md`

- [ ] **Step 1: Sandbox accounts.** In the PayPal developer dashboard, create two **personal** sandbox accounts: a payee (stands in for Kemi) and a buyer (stands in for Dan).
- [ ] **Step 2: Write the spike script.** Using `makePayPalClient(loadEnv())`, POST `/v2/checkout/orders` with `intent: CAPTURE`, one purchase unit (`reference_id: 'spike'`, `custom_id: 'org:split:participant'`, `amount: { currency_code: 'GBP', value: '39.23' }`, **no item breakdown**, `payee: { email_address: <payee> }`, `description: 'Your share of Friday dinner (Little Bao House)'`), and `payment_source.paypal.experience_context` as in `src/paypal/orders.ts` with brand `Split`. Print the order id, its status and the `payer-action` link. With `--capture <id>`, POST `/capture` with `PayPal-Request-Id: capture-spike` and print the capture status.
- [ ] **Step 3: Run it.** Create the order, open the link and approve as the sandbox buyer, then run `--capture`. In the payee's sandbox account, confirm £39.23 arrived (net of fees). Note whether any webhook reached the Render service (its logs, or the `webhookEvents` collection).
- [ ] **Step 4: Record.** Under *PayPal* in `docs/verified-facts.md`, record the order id, the create status (expect `PAYER_ACTION_REQUIRED`), the approval link `rel`, the capture status, where the money landed, whether a webhook arrived, and the date. If the payee was refused, record the exact error, and add *Payee fallback: shared sandbox merchant* to *Still unverified* for the README.
- [ ] **Step 5: Commit** the script and `docs/verified-facts.md`.

---

### Task 15: Participant colours and Avatar

"A person's colour follows their items everywhere" is Split's signature (DESIGN.md). This task makes the colours tokens before any screen uses them.

**Files:**
- Modify: `app/lib/core/theme/split_colors.dart`
- Create: `app/lib/widgets/avatar.dart`
- Test: `app/test/theme_test.dart` (extend), `app/test/avatar_test.dart`

**Interfaces:**
- Produces, from `split_colors.dart`:
  - `class ParticipantColour { const ParticipantColour(this.fill, this.text); final Color fill; final Color text; }`
  - `SplitColors.participants: List<ParticipantColour>` (8 entries, in `light`, `copyWith` and `lerp`, where each pair lerps)
  - `ParticipantColour SplitColors.participant(int colourIndex)` (wraps mod 8)
- Produces, from `avatar.dart`: `Avatar({ required String name, required int colourIndex, double size = 36 })`, which asserts the size is one of 24, 30, 36, 40 or 44 and shows the first letter upper-cased. `AvatarStack({ required List<({String name, int colourIndex})> people, double size = 30 })`, which overlaps each avatar −8 px with a 2 px ring in `background`. Each avatar has `Semantics(label: name)`, so colour never carries meaning alone.

- [ ] **Step 1: Write the failing tests**

In `theme_test.dart`, add a case `participant colours match DESIGN.md and D12` that asserts all eight fill/text pairs:

```dart
const expected = [
  (0xFFFFC439, 0xFF3D2B00), (0xFFFF9F80, 0xFF4A1A0A), (0xFF9DBEFF, 0xFF0A2560),
  (0xFF7AD9AE, 0xFF063D26), (0xFFD6B0FF, 0xFF3A1466), (0xFFFF9EC7, 0xFF4D0A2B),
  (0xFF7FD3E6, 0xFF053A45), (0xFFB9D46C, 0xFF2E3A05),
];
```

Add a case `participant text is legible on its fill`: for each pair, the WCAG contrast `(L1 + 0.05) / (L2 + 0.05)` from `Color.computeLuminance()` is at least 4.5. Add another, `participant fills share one lightness band`: every fill's luminance is within 0.45–0.65. Add a case that `participant(9)` equals `participant(1)`, and extend the `lerp` case to cover `participants`.

`avatar_test.dart`: the initial is "D" for "dan"; the fill and text come from `SplitColors.participant(i)`; a non-design size fails its assert; a stack of three is narrower than three avatars side by side; each avatar exposes its name to semantics.

- [ ] **Step 2: Run to see them fail, then implement.** Values go in `SplitColors.light`. Widgets read them through `SplitColors.of(context).participant(i)`, never as literals.
- [ ] **Step 3: Run** `flutter analyze && flutter test`, then **commit** "theme: participant colours and Avatar".

---

### Task 16: Models, repository and providers

**Files:**
- Create: `app/lib/models/ambiguity.dart`, `receipt.dart`, `split.dart`, `participant.dart`, `organiser.dart` (each with its generated `.freezed.dart` and `.g.dart`, committed as Sorted did), `app/lib/data/splits_repository.dart`, `app/lib/providers/splits_providers.dart`
- Modify: `app/lib/providers/organiser_provider.dart` (add `organiserProvider`)
- Test: `app/test/models_test.dart`, `app/test/scan_controller_test.dart`

**Interfaces:**
- Produces (freezed, `fromJson` tolerant of both the API's ISO strings and Firestore `Timestamp`s via `firestore_time.dart`'s `dateTimeFromJson`, as Sorted's `order.dart` did):
  - `Ambiguity { field, kind, question, options = [], blocking = true }`
  - `ReceiptLine { id, name, qty, int? lineTotalMinor }`, `Discount { label, amountMinor }`, `Receipt { lines, serviceChargeMinor = 0, serviceChargeLabel?, tipMinor = 0, discounts = [], int? printedTotalMinor, currency = 'GBP' }`
  - `Rules { serviceMode = 'proportional', onUs = [], onUsPaidBy?, serviceOptOut = [] }`, `Claim { participantId, weight, source }`
  - `BreakdownLine { lineId, minor, portionLabel }`, `Breakdown { itemsMinor, sharedFromOnUsMinor, serviceMinor, tipMinor, discountMinor, finalMinor, lines }`
  - `Computed { bool ok, Map<String, Breakdown> perParticipant = {}, int? totalMinor, List<Ambiguity> problems = [] }`. This is one class for the API's union, which is simpler than a freezed union for a shape the app only reads.
  - `Split { id, title, merchant?, receiptDate?, status, receipt, receiptAmbiguities = [], claims = {}, rules, organiserParticipantId, computed?, createdAt?, updatedAt? }`, with getters `blocking` (the blocking `receiptAmbiguities`) and `isDraft`
  - `Participant { id, name, colourIndex, isOrganiser, joinOrder, status, shareMinor? }` (the rest of §2's fields join in Week B)
  - `Organiser { id, displayName, paypalEmail? }`
- Produces, from `splits_repository.dart`: `abstract class SplitsApi { Future<Split> scan(List<({List<int> bytes, String filename})> photos); Future<Split> patchReceipt(String splitId, Map<String, Object?> body); Future<Split> patchRules(String splitId, Map<String, Object?> body); }`, `HttpSplitsApi(ApiClient)`, and `SplitsRepository { watchSplits(organiserId) (newest first), watchSplit(organiserId, splitId), watchParticipants(organiserId, splitId) (by joinOrder) }`
- Produces, from `splits_providers.dart`: `splitsApiProvider`, `splitsRepositoryProvider`, `splitsProvider: StreamProvider<List<Split>>`, `splitProvider: StreamProvider.family<Split?, String>`, `participantsProvider: StreamProvider.family<List<Participant>, String>`, and `scanControllerProvider: NotifierProvider<ScanController, ScanState>` with `sealed class ScanState`: `ScanIdle`, `ScanReading(int photos)`, `ScanReady(Split split)`, `ScanFailed(String message)`. `ScanController.read(photos)` ignores a second call while already reading, and maps errors through `describeApiError`.
- Produces, from `organiser_provider.dart`: `organiserProvider: StreamProvider<Organiser?>` over `organisers/{uid}`.

- [ ] **Step 1: Write the failing tests.** `models_test.dart` parses the exact JSON `POST /v1/splits/scan` returns in `api/test/splits-route.test.ts` (copy one response into a fixture under `app/test/fixtures/`) and the Firestore map shape with `Timestamp`s. It checks that a `null` `printedTotalMinor` and a `null` line total survive, and that `Computed` parses both `ok: true` with breakdowns and `ok: false` with problems. `scan_controller_test.dart` uses a fake `SplitsApi`: success ends in `ScanReady` with the split; an `AI_PARSE_FAILED` `DioException` ends in `ScanFailed` with the app's wording; a second `read` while `ScanReading` makes no second call.
- [ ] **Step 2: Implement**, then `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 3: Run** `flutter analyze && flutter test`, then **commit** "app: split models, repository and the scan controller".

---

### Task 17: The Scan screen reads receipts

**Files:**
- Modify: `app/lib/features/scan/scan_screen.dart`, `app/test/scan_screen_test.dart`, `app/test/scan_motion_test.dart`

**Interfaces:**
- Consumes: `scanControllerProvider` (Task 16).
- Changes: `_maxPhotos` goes from 5 to **2**. The default `scanReaderProvider` now starts `scanControllerProvider.notifier.read(photos)` without awaiting it and returns `'/split/reading'`; the tests still override it. Copy follows `Scan.dc.html`: title "Scan the bill", "Bill found, hold still" over the frame while the camera is live, the hint "Long bill? Snap it in two parts and Split joins them up.", and a third photo refused with that same line. Close goes to `/`. The rest of Sorted's camera, picker, thumbnail and reduced-motion behaviour is unchanged.

- [ ] **Step 1: Update the tests first.** Replace the Sorted copy expectations ("Snap your stock", "five photos") with the strings above. Add `a third photo is refused with the long-bill hint`, and `Done hands the photos to the reader and pushes where it says`, using a reader that records the photos and returns `/split/reading`, under a `GoRouter` test host.
- [ ] **Step 2: Run to see them fail, implement, run** `flutter analyze && flutter test`.
- [ ] **Step 3: Commit** "scan: one photo, or two for a long bill".

---

### Task 18: The Reading screen

**Files:**
- Create: `app/lib/features/scan/reading_screen.dart`
- Modify: `app/lib/core/motion/motion_access.dart` (two tokens)
- Test: `app/test/reading_screen_test.dart`

**Interfaces:**
- Consumes: `scanControllerProvider`, `formatGbp`.
- Produces: `ReadingScreen`. Add `SplitDurations.readingStep = Duration(milliseconds: 900)` (the ticker) and `SplitDurations.readingHold = Duration(milliseconds: 700)` (how long the real results show before moving on). The `Timer` uses these tokens, never a literal.
- Behaviour, in Sorted's Reading pattern, as a ticking checklist and never a spinner:
  - while `ScanReading`, the steps "Reading the receipt", "Finding every line", "Looking for a service charge" and "Checking it adds up" tick one per `readingStep` and stop on the last;
  - on `ScanReady`, they become the real results: "Found 10 items", "Found a service charge" (or "No service charge"), and "Checking it adds up to £154.69" (or "Couldn't read the total"). All tick, and after `readingHold` the screen `pushReplacement`s to `/split/{id}/receipt`. If it opens already `ScanReady`, it does the same after the first frame (Sorted's fix);
  - on `ScanFailed`, it shows the message and **Try again**, which pops back to Scan with the photos kept. See open question 2 for manual entry.

- [ ] **Step 1: Write the failing tests.** Steps advance with `tester.pump(SplitDurations.readingStep)`. Ready shows "Found 10 items" and "Checking it adds up to £154.69" from a fake split built from the Little Bao House JSON, then navigates to `/split/{id}/receipt`. Failed shows the message and Try again pops. Under reduced motion, nothing animates but the steps still appear.
- [ ] **Step 2: Implement, run** `flutter analyze && flutter test` (including `motion_discipline_test`), **commit** "reading: a checklist while the bill is read".

---

### Task 19: The Receipt screen

**Files:**
- Create: `app/lib/features/split/receipt_screen.dart`, `app/lib/features/split/line_edit_sheet.dart`
- Test: `app/test/receipt_screen_test.dart`

**Interfaces:**
- Consumes: `splitProvider(id)`, `splitsApiProvider` (`patchReceipt`, `patchRules`), `WarningCard`, `SegmentedControl`, `PrimaryButton`, `MoneyRoll`, `SplitAppBar`, `formatGbp`, `parseGbpInput`, `displayDate`.
- Produces: `ReceiptScreen({ required String splitId })` at `/split/:id/receipt`, laid out from `Receipt.dc.html`:
  - title "Check the bill"; the merchant; "Fri 2 Oct. Split read 10 items.";
  - one row per line: a qty badge, the name as printed, and `formatGbp(lineTotalMinor)` (or "Add price", in warning tokens, when it is `null`). Tapping a row opens `LineEditSheet` (name, qty, price), which sends `patchReceipt(id, { lines: [{ id, ... }] })` with only the fields that changed. "Add a line" sends `addLines`; swipe or a menu item sends `removeLineIds`;
  - every **blocking** `receiptAmbiguities` entry as a `WarningCard` at the top, showing the server's `question` verbatim (for example "Items add up to £152.10 but the bill says £154.69. Check the photo or edit a line."). Tapping a `lines.{id}…` one opens that line's editor; tapping the `printedTotalMinor` one opens a total editor (`patchReceipt({ printedTotalMinor })`). Non-blocking notes show as a quieter `primaryTint` card;
  - when `serviceChargeMinor > 0`, the info card "Found a 12.5% service charge (£17.19). Split it by what each person had?" (the label and amount come from the receipt), with a `SegmentedControl` "By what they had" / "Evenly" bound to `rules.serviceMode`, which sends `patchRules({ serviceMode })`;
  - "Total paid by you" with `MoneyRoll(printedTotalMinor)`;
  - `PrimaryButton` "Add people", disabled while `split.blocking` is not empty, which pushes `/split/{id}/people`.
- The screen never decides whether the bill adds up. It shows what the server derived, so there is one source of truth for money.

- [ ] **Step 1: Write the failing tests** over an overridden `splitProvider` stream and a recording fake `SplitsApi`. Cover: the ten Little Bao House lines render with £18.00 against Pork bao; a `price_conflict` shows the server's sentence and disables Add people; editing Lager to £16.50 sends exactly `{ lines: [{ id: 'lager-8', lineTotalMinor: 1650 }] }`; Evenly sends `{ serviceMode: 'even' }`; no service card when the charge is 0; a `null` price shows "Add price" and blocks; after the stream emits a split with no blocking ambiguities, Add people enables.
- [ ] **Step 2: Implement, run** `flutter analyze && flutter test`, **commit** "receipt: check the bill before anyone is asked".

---

### Task 20: Home skeleton, *Try a sample bill*, and the router

**Files:**
- Create: `app/lib/features/home/home_screen.dart`, `app/lib/features/home/summary_card.dart`, `app/lib/features/split/people_placeholder_screen.dart`, `app/assets/samples/little-bao-house.png` (copied from `samples/receipts/`)
- Modify: `app/lib/router.dart`, `app/pubspec.yaml` (asset), `app/web/index.html` and `manifest.json` (name "Split", description "Snap the bill. Everyone pays their bit.")
- Test: `app/test/home_screen_test.dart`, `app/test/router_test.dart`

**Interfaces:**
- Consumes: `organiserProvider`, `splitsProvider`, `participantsProvider`, `scanControllerProvider`, `AvatarStack`, `ShareStatusPill`, `PrimaryButton`.
- Produces: `HomeScreen` at `/`, from `Home.dc.html`:
  - "Hi {displayName}" from `organiserProvider`;
  - the newest split that is not settled or cancelled, as the dark `SummaryCard` (`darkBg` / `darkSurface`, `accentCyan` progress): title and merchant, and an `AvatarStack` of its participants. In Week A, a draft card shows `formatGbp(printedTotalMinor)` with "Still checking the bill" and opens `/split/{id}/receipt`. The "£79.03 of £118.26 back" state needs paid participants, so it lands with the Tracker in Week B. Build the card so that state is a data change, not a rewrite;
  - the Settled list (title, "Sun 27 Sep, 4 people", Settled pill), shown when any exist;
  - `PrimaryButton` "Split a new bill", which pushes `/scan`;
  - a **Try a sample bill** row (D11). It loads `assets/samples/little-bao-house.png` with `rootBundle`, calls `scanControllerProvider.notifier.read([(bytes, 'little-bao-house.png')])`, and pushes `/split/reading`.
- Router: `/` → Home, `/scan` sheet, `/split/reading` push, `/split/:id/receipt` push, `/split/:id/people` push to a placeholder that says the People screen arrives with Week B. The `_HomePlaceholder` from the bootstrap commit is deleted.

- [ ] **Step 1: Write the failing tests.** The greeting comes from a fake organiser stream. A draft split renders the card with £154.69 and tapping it goes to its receipt. "Split a new bill" pushes `/scan`. *Try a sample bill* hands a fake `SplitsApi` exactly the asset's bytes and lands on Reading. With no splits there is no card, and both actions still show. In `router_test`, each route builds its screen.
- [ ] **Step 2: Implement, run** `flutter analyze && flutter test`, **commit** "home: the skeleton, and a sample bill one tap away".

---

### Task 21: Deploy the web build (operator)

Spec §8: deploy the web build in week 1, not week 3.

**Files:**
- Modify: `firebase.json` (hosting), `README.md`, `docs/verified-facts.md`

- [ ] **Step 1: Add hosting** to `firebase.json`: `"hosting": { "public": "app/build/web", "ignore": ["firebase.json", "**/.*"], "rewrites": [{ "source": "**", "destination": "/index.html" }] }`.
- [ ] **Step 2: Build and deploy.** `cd app && flutter build web --release --dart-define=API_BASE_URL=<the Task 13 URL>`, then from the repo root `firebase deploy --only hosting`.
- [ ] **Step 3: Smoke test as a judge**, in a private window on a phone-sized viewport: the URL opens to Home with "Hi Kemi" and the Little Bao House card; **Try a sample bill** goes through Reading and lands on a Receipt that shows no warning and £154.69; changing Lager to £15.60 raises "Items add up to £153.79 but the bill says £154.69…", and changing it back clears it; Evenly sticks after a reload.
- [ ] **Step 4: Record and commit.** README line one is the hosted URL, and line two the API health URL. Under *Deployment* in `docs/verified-facts.md`, record the hosting URL, the build's `API_BASE_URL`, the smoke-test result and the date.

---

## Plan complete

**Week A is done when:**
- `npm test` is green (290+ tests, with `allocate` golden, property and edge suites among them), and so are `npm run typecheck`, `flutter analyze` and `flutter test`;
- the hosted web URL passes Task 21's smoke test;
- `docs/verified-facts.md` has dated entries for the Firebase project, the Render URL on `starter` with both sweeps scheduled, the PayPal payee spike, and the receipt model spike with its pinned model.

**Handed to Week B:** People and `open` (signed links with `LINK_SECRET`), claim parsing, friend pages, Rules and Breakdown screens, `lock`, the generalised `createPayPalOrder`, participant-based webhooks and reconcile (retiring the four transitional files), and the Tracker with the live Paid flip. Review Focus 1's claim check belongs at the start of that plan.

## Open questions for you

1. **Review Focus 1.** Should "Lager ×3: Josh 1, Dan 1" stay a 1:1 share (spec as written, and this plan), or count as a partial claim that asks the group about the third lager? Changing it later means one line in `allocate.ts`'s validate stage and two tests.
2. **Manual entry when the model fails twice.** Spec §7 says nobody is ever blocked by the model, but no endpoint creates an empty draft. This plan gives Week A a *Try again* and defers manual entry to Week C's error states. The alternative is a small `POST /v1/splits` (empty draft) now, so the Receipt screen doubles as manual entry. That would be about half a task.
3. **D11.** Is it right that *Try a sample bill* runs the real AI read rather than seeding fixed data? It is the more honest demo, but a live misread would be visible to a judge. The add-up check would catch it on screen, which is arguably a feature.
