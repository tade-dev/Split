# Split — Design Spec

> Snap the bill. Everyone pays their bit.

**Date:** 2026-10-20
**Entrant:** solo, UK-based
**Event:** PayPal AI Hackathon (Devpost), second entry alongside Sorted. Wire: **Thu 12 Nov 2026, 22:00 UK**.
**Internal deadline:** submit **Tue 10 Nov** together with Sorted. Wed 11 Nov is contingency.
**Sister project:** `tade-dev/sorted`. Split reuses its design system, motion layer, API shell, AI seam and the whole PayPal pipeline. Read Sorted's `docs/superpowers/specs/2026-10-02-sorted-design.md` and `docs/verified-facts.md` before writing anything here.

---

## 0. Intent and locked decisions

### What we are building

An app for whoever paid the bill. After a group meal, the organiser photographs the receipt. A vision model reads every line, service charge and discount, and the app checks they add up to the printed total. Friends say what they had in plain words, from a web link with no app to install. The AI turns those messages into exact item claims. Deterministic code then works out each person's share to the penny, including shared starters, "it's Sam's birthday so his is on us" and the UK 12.5% service charge. Each friend pays their share through a PayPal checkout that goes straight to the organiser, and the organiser's app ticks them off live.

### Success criterion

A judge opens the hosted web URL, taps **Try a sample bill**, adds people, opens a friend's link with **Preview as Dan**, types what Dan had, pays as the sandbox buyer, and watches Dan flip to Paid on the organiser's tracker without reloading. Everything else supports that moment.

### Locked decisions

| Decision | Choice | Why |
|---|---|---|
| Repo | **New public repo `tade-dev/split`**, MIT. Reused code is copied in, not shared as a package | Devpost requires each submission to have its own public repo, and multiple entries must be "unique and substantially different". A shared package across two repos costs days of plumbing for no judge-visible gain. Provenance goes in `docs/reused-from-sorted.md`, so the reuse is stated openly. |
| Who installs the app | **Only the organiser.** Friends use signed web links | Asking friends to install an app kills group payments. The organiser is the one person who cares. |
| Friend pages | **Server-rendered HTML from the API**, small vanilla JS, same visual tokens | Opens instantly from a WhatsApp link on any phone. A Flutter web build is 2+ MB of first load for a page a friend sees once. Sorted's `buyer_page.ts` already proves the pattern. |
| Friend identity | **One HMAC-signed capability link per participant**, no friend login | Same pattern as Sorted's signed invoice links. The link is the credential and shows only that friend's share. |
| Organiser auth | **Anonymous Firebase Auth**, exactly as Sorted | Zero-friction demo, data scoped per uid. |
| Who receives money | **The organiser, via PayPal "pay another account"** (`purchase_units[].payee.email_address`). Falls back to the shared sandbox merchant when no email is set | Sorted already ships this path (`createPayPalOrder(..., payeeEmail)` and `per_seller_paypal_test`). It removes the "organiser needs a business account" problem from the concept stage. |
| Paid detection | **Capture on return, reconcile sweep as safety net, webhooks when they arrive** | Sorted's `/paypal/return` already captures on the buyer's return because payee orders may never notify the app. Reuse exactly. |
| AI | **OpenAI `gpt-5.5`**, pinned in env, strict JSON schema, no `temperature` | Verified in Sorted. Same `generateStructured()` seam with its corrective retry. |
| Money | **Integer pence; every share computed in code by largest remainder** | The model reads the receipt and says who had what. It never computes a share. The sum of shares always equals the printed total, which is a tested invariant. |
| Sponsor tools | **Render only** | Same as Sorted. No second frontend. |
| Scope cut | **No share extension, no contacts picker, no Android share intent in v1** | The camera and photo picker cover the receipt. Names are typed. Native share is where Sorted lost days. |

### The honesty rules (Split's version of Sorted's)

1. **Unknowns become ambiguities, never guesses.** An unreadable price, an item nobody claimed, a portion nobody can account for: each one becomes a question the organiser answers in one tap.
2. **Prices come from the printed receipt, and the app proves they add up.** The lines, service charge, tip and discounts must sum to the printed total. If they don't, the receipt is blocked until the organiser fixes it. This replaces Sorted's "prices come from the catalogue".
3. **No share ever comes from the LLM.** The model outputs claims (who had which line, in what portion) and rules (who is on us, how service splits). `allocate.ts` turns those into pence.
4. **Split never messages anyone itself.** The organiser shares links and nudges by copying them into their own group chat, as Sorted's sellers do.

---

## 1. What is reused from Sorted

Copy these from `tade-dev/sorted` at commit `902dc25`. **Copy** means verbatim plus renames. **Adapt** means copied and then changed as described. Every copied file keeps its tests, which come across too and must pass before any new code is written.

### Flutter (`app/`)

| Sorted file(s) | Action | Notes |
|---|---|---|
| `lib/core/theme/sorted_colors.dart`, `sorted_shape.dart`, `sorted_theme.dart` | **Adapt** | Rename to `split_*`, `SortedColors` → `SplitColors`, etc. Add the five participant colours (§6) to the extension. Tokens are otherwise identical. |
| `lib/core/motion/*` (all of it) | **Copy** | Rename `SortedSprings`/`SortedDurations`/`SortedCurves` → `Split*`. Keep the rules: no literal durations or `Curves.` outside this directory, `bouncy` used exactly twice. In Split, those two are the **Paid pop on a tracker row** and the **"Settled" stamp** when the last friend pays. |
| `test/motion_discipline_test.dart`, `press_coverage_test.dart`, `motion_*_test.dart`, `spring_curve_test.dart`, `page_transitions_test.dart`, `reveal_test.dart`, `enter_stagger_test.dart`, `after_arrival_test.dart` | **Copy** | The guard rails come with the motion layer. |
| `lib/widgets/primary_button.dart`, `selectable_chip.dart`, `segmented_control.dart`, `warning_card.dart`, `skeleton.dart`, `sorted_toast.dart`, `sorted_app_bar.dart`, `sorted_icon.dart`, `money_roll.dart`, `reply_bubble.dart` | **Copy** | Rename `Sorted*` → `Split*`. `ReplyBubble` becomes the nudge and share-message bubble. `MoneyRoll` is the total on Breakdown when a rule changes. |
| `lib/widgets/sorted_stamp.dart` | **Adapt** | Becomes `SettledStamp`: same motion, says "Settled". |
| `lib/features/orders/status_pill.dart` + `order_presentation.dart` | **Adapt** | Becomes `ShareStatusPill` with participant statuses (§2). Keep the morph animation and the lightness rule. |
| `lib/core/motion/paid_pop.dart`, `paid_announcer.dart` | **Copy** | The haptic and screen-reader "Dan paid £39.23". |
| `lib/core/money.dart`, `firestore_time.dart`, `uk_date.dart`, `env.dart`, `api_client.dart` | **Copy** | Change the `API_BASE_URL` default to Split's Render URL. |
| `lib/features/catalogue/camera_port.dart`, `snap_screen.dart` | **Adapt** | Becomes `scan_screen.dart` for receipts: one or two photos, "long bill? snap it in two parts". |
| `lib/providers/seller_provider.dart`, `api_provider.dart` | **Adapt** | `organiserIdProvider`: anonymous sign-in plus bootstrap. |
| `lib/router.dart` | **Adapt** | Keep `sortedPushPage`/`sortedSheetPage`/`sortedTabPage` (renamed). No five-slot tab bar: Split's design has a single Home with a primary "Split a bill". |
| `assets/fonts/*`, the `fonts:` block of `pubspec.yaml` | **Copy** | Bundled Bricolage Grotesque and Plus Jakarta Sans. |
| Firebase options, iOS share extension, `share_intake.dart`, catalogue, order and onboarding features | **Do not copy** | New Firebase project. No share extension in v1. |

### API (`api/`)

| Sorted file(s) | Action | Notes |
|---|---|---|
| `src/env.ts`, `src/firebase.ts`, `src/index.ts`, `src/app.ts` | **Adapt** | Same shape. Add `LINK_SECRET` (separate from `INTERNAL_TOKEN`, see §4). Swap the routers. |
| `src/lib/auth.ts`, `src/lib/errors.ts`, `src/lib/image_type.ts` | **Copy** | `req.sellerId` → `req.organiserId`. Add error code `SPLIT_STATE_INVALID`. |
| `src/ai/client.ts` | **Copy** | `generateStructured()`, the transport and the corrective retry, untouched. |
| `src/domain/money.ts` | **Copy, then extend** | Add `allocateLargestRemainder()` (§3). Existing functions unchanged. |
| `src/paypal/client.ts` | **Copy** | OAuth caching and the error surfacing. |
| `src/paypal/orders.ts` | **Adapt** | Generalise `createPayPalOrder(order: OrderDoc, ...)` to take `{ referenceId, customId, amountMinor, description, items?, payeeEmail, requestId }`. Brand name "Split". |
| `src/paypal/events.ts` | **Adapt** | `parseCustomId` returns `{ organiserId, splitId, participantId }` from a three-part `custom_id`. Everything else unchanged. |
| `src/paypal/reconcile.ts` | **Adapt** | Operates on a participant doc instead of an order doc. Same capture-or-move logic. |
| `src/routes/webhooks.ts` | **Adapt** | Same verification, ledger and idempotency. `locateOrder` becomes `locateShare`: by `custom_id`, else `collectionGroup('participants').where('paypalOrderId', ...)`. |
| `src/routes/paypal_pages.ts` | **Adapt** | Same capture-on-return. The return page links back to the friend's own Split page. |
| `src/paypal/buyer_page.ts` | **Adapt** | Becomes the shared layout for all friend pages (§5). |
| `src/domain/invoice.ts` (HMAC sign/verify only) | **Adapt** | Becomes `domain/links.ts`. |
| `src/routes/internal.ts`, `src/routes/health.ts` | **Adapt** | Reconcile and expire sweeps over open participant shares. |
| `src/ai/draft_nudge.ts`, `src/domain/nudge.ts` | **Adapt** | Nudge a friend instead of a buyer. Keep `shouldSkip`. |
| `test/emulator-guard.ts`, the vitest config, the supertest + fake-transport + fake-PayPal pattern | **Copy** | Every new route gets the same style of test. |
| `render.yaml`, `scripts/emulators.sh`, `firebase.json` | **Adapt** | New service name `split-api`. **Start on the `starter` plan.** Sorted is still on `free`. |

---

## 2. Data model

Money is integer pence plus `currency: 'GBP'`. Timestamps are Firestore `Timestamp` at rest and ISO strings over the API. Clients **read** Firestore and **never write** it. Every write goes through the API's Admin SDK, as in Sorted.

### `organisers/{uid}`

`displayName` (the name friends see: "Kemi"), `paypalEmail` (string or null; null pays the shared sandbox merchant), `createdAt`, `demoSeeded`.

### `organisers/{uid}/splits/{splitId}`

| Field | Type | Notes |
|---|---|---|
| `title` | string | "Friday dinner". Organiser-editable, defaulted from the receipt. |
| `merchant` | string \| null | "Little Bao House" |
| `receiptDate` | ISO date \| null | |
| `status` | `'draft' \| 'claiming' \| 'collecting' \| 'settled' \| 'cancelled'` | See the lifecycle below |
| `receipt` | `Receipt` | Embedded, below |
| `receiptAmbiguities` | `Ambiguity[]` | Reuses Sorted's shape. Blocks `open` while any blocking one is unresolved |
| `claims` | `Record<lineId, Claim[]>` | Embedded. Small and always read together. Written in transactions |
| `rules` | `Rules` | Below |
| `organiserParticipantId` | string | The organiser is a participant too. Their share is what they keep, not charged |
| `computed` | `Allocation \| null` | Last result of `allocate()`, so the app renders without recomputing |
| `lockedAt` | Timestamp \| null | Set by `lock`. Claims and rules are frozen from here |
| `extractionModel` | string | For the write-up |
| `sourceRef` | string \| null | Storage path of the receipt photo |
| `createdAt` / `updatedAt` | Timestamp | |

**`Receipt`**: `lines: ReceiptLine[]`, `serviceChargeMinor: int` (0 if none), `serviceChargeLabel: string|null` ("12.5% discretionary"), `tipMinor: int`, `discounts: { label, amountMinor }[]`, `printedTotalMinor: int`, `currency: 'GBP'`.

**`ReceiptLine`**: `id` (stable slug + index), `name` (as printed), `qty` int ≥1, `lineTotalMinor` int. The unit price is derived only for display. The printed line total is the truth.

**`Claim`**: `{ participantId, weight: int ≥1, source: 'ai' | 'organiser' | 'friend' }`. A line's weights decide its split: `Lager x3` claimed `Josh 2, Dan 1` splits 2:1, and `Prawn crackers` shared by five is weight 1 each.

**`Rules`**: `serviceMode: 'proportional' | 'even'` (default proportional, "by what they had"), `onUs: participantId[]`, `onUsPaidBy: participantId[] | null` (null means every other participant), `serviceOptOut: participantId[]`.

### `organisers/{uid}/splits/{splitId}/participants/{participantId}`

| Field | Type | Notes |
|---|---|---|
| `name` | string | First name, as friends see it |
| `colourIndex` | int 0–7 | Stable, assigned in join order |
| `isOrganiser` | bool | |
| `joinOrder` | int | The tie-break order for remainder pennies |
| `status` | `'invited' \| 'claimed' \| 'owes' \| 'link_opened' \| 'processing' \| 'pending' \| 'declined' \| 'paid' \| 'paid_cash' \| 'on_us'` | |
| `claimText` | string \| null | What they typed, kept for the claim chat view |
| `shareMinor` | int \| null | Set at `lock` from `computed` |
| `paypalOrderId` / `approvalUrl` / `paypalCaptureId` | string \| null | Created lazily on **Pay** |
| `supersededPaypalOrderIds` | string[] | Same meaning as Sorted's: approvals never captured, captures flagged for refund |
| `nudge` | Sorted's nudge shape | |
| `linkOpenedAt` / `claimedAt` / `paidAt` | Timestamp \| null | "Dan opened his link but hasn't paid" comes from these |
| `aiParsesUsed` | int | Rate limit on public AI calls (§5) |

Payment events go in `.../participants/{pid}/paymentEvents/{eventId}`, exactly as Sorted's order events. The root `webhookEvents` ledger is unchanged.

### Lifecycle

```
draft ──open──▶ claiming ──lock──▶ collecting ──(all paid / paid_cash / on_us)──▶ settled
  │                │                    │
  └──cancel────────┴──cancel────────────┘──▶ cancelled (open PayPal orders superseded)
```

- `draft`: the receipt is being checked. Needs zero blocking receipt ambiguities to `open`.
- `claiming`: friend links are live for claiming. The organiser can also claim on anyone's behalf.
- `lock`: needs every line fully claimed (§3). Runs `allocate()`, writes `shareMinor` to each participant and freezes claims and rules. **Unlock** is allowed only while no participant has a PayPal order. After that, an edit supersedes open PayPal orders, using Sorted's mechanism.
- `collecting`: the same friend links now show the share and a **Pay** button.

### Firestore rules

Organisers read `organisers/{uid}/**` where `uid == request.auth.uid`. All client writes are denied. `webhookEvents` is denied in both directions. Friends never touch Firestore. Port Sorted's emulator tests with the paths renamed.

---

## 3. The allocation algorithm (`api/src/domain/allocate.ts`)

The heart of Split. It is a pure function with no I/O and no Firestore, so it is tested to exhaustion.

```ts
allocate(input: {
  receipt: Receipt;
  claims: Record<string, Claim[]>;
  rules: Rules;
  participants: { id: string; joinOrder: number; isOrganiser: boolean }[];
}): Allocation
// Allocation = { perParticipant: Record<id, Breakdown>, totalMinor, ok: true }
//            | { ok: false, problems: Ambiguity[] }
// Breakdown = { itemsMinor, sharedFromOnUsMinor, serviceMinor, tipMinor,
//               discountMinor, finalMinor, lines: { lineId, minor, portionLabel }[] }
```

### Stages, in this order

1. **Validate.** Every line must be fully claimed: the sum of weights is ≥ `qty`, or the line has two or more claimants (a shared item). A line with some weight but less than `qty` units and a single claimant is **partially claimed**. It becomes a blocking problem ("1 of 3 lagers is unclaimed"). An unclaimed line also blocks ("Nobody claimed the prawn crackers") with options *Share between everyone* and *Ask the group*.
2. **Items.** Each line's `lineTotalMinor` splits across its claimants in proportion to weight, using **largest remainder**.
3. **On us.** Each on-us participant's item total is redistributed **evenly** across `onUsPaidBy`, which defaults to all non-on-us participants including the organiser, using largest remainder. The on-us person's items drop to 0.
4. **Service charge.** `proportional` splits it by each payer's post-stage-3 subtotal. `even` splits it equally. Participants in `serviceOptOut` are excluded and the rest absorb it. Largest remainder.
5. **Tip** follows the service mode. **Discounts** are negative and split proportionally to the post-stage-3 subtotal. A participant's final can never go below 0; clamp and redistribute.
6. **Invariant:** `Σ finalMinor == receipt.printedTotalMinor`. If this ever fails, throw. It is a bug, never a user error.

### Largest remainder (`allocateLargestRemainder(total, weights, order)`)

Give each party the floor of `total × w / Σw` (in exact integer arithmetic, no floats). Then hand the leftover pennies one at a time to the largest fractional remainders. **Ties go to the organiser first, then by `joinOrder`**, so the person who paid the bill absorbs the rounding.

### Golden fixture (it must reproduce the design screens exactly)

The Little Bao House bill: £137.50 of items + £17.19 service = **£154.69**. Kemi (organiser) is joinOrder 0, then Amaka, Josh, Dan, Sam. Sam is on us.

| Line | Total | Claims |
|---|---|---|
| Prawn crackers | 550 | all five, weight 1 |
| Pork bao ×3 | 1800 | Kemi 1, Josh 1, Dan 1 |
| Chicken katsu | 1450 | Kemi |
| Tofu rice bowl | 1200 | Amaka |
| Beef ramen | 1500 | Josh |
| Spicy miso ramen | 1500 | Dan |
| Prawn ramen | 1500 | Sam |
| Lychee sour ×2 | 1900 | Amaka 1, Sam 1 |
| Lager ×3 | 1650 | Josh 2, Dan 1 |
| Lemonade ×2 | 700 | Kemi 1, Sam 1 |

Expected (verified by hand computation on 2026-10-20):

| | Items | Sam's share | Service | **Final** |
|---|---|---|---|---|
| Kemi | 2510 | 728 | 405 | **3643** |
| Amaka | 2260 | 728 | 373 | **3361** |
| Josh | 3310 | 727 | 505 | **4542** |
| Dan | 2760 | 727 | 436 | **3923** |
| Sam | 2910 → 0 | | | **0** |
| **Total** | 13750 | | 1719 | **15469** |

Owed to Kemi: **£118.26**. These are exactly the figures on `Home`, `Breakdown`, `FriendPay` and `Tracker`. Seed this bill as the demo, and keep the numbers out of widgets.

### Required tests

- The golden fixture, exact.
- **Property tests** (add `fast-check` as a dev dependency) over random receipts, claims and rules: the sum always equals the printed total, no final is negative, every final is an integer, the result is identical across runs, and permuting the claims within a line does not change the result.
- Edge cases: one participant, everyone on us except the organiser, a line of `qty` 7 split between 3 people, a 100% discount line, service opt-out by all but one person, a £0.01 line shared by five.

---

## 4. Backend API

Base `https://split-api.onrender.com/v1` (confirm the real URL in `docs/verified-facts.md` on first deploy). The auth and error shapes are Sorted's. New code: `SPLIT_STATE_INVALID`.

### Organiser (Bearer Firebase ID token)

| # | Endpoint | Request | Response / effect |
|---|---|---|---|
| 1 | `GET /health` | | Sorted's shape |
| 2 | `POST /session/bootstrap` | `{ demo: boolean }` | Creates the organiser. `demo` seeds the Little Bao House split in `draft` |
| 3 | `PATCH /session/organiser` | `{ displayName?, paypalEmail? }` | |
| 4 | `POST /splits/scan` | multipart `images[]` (1–2, ≤8 MB) | AI receipt read (§7.1) → creates the split in `draft` with `receipt` + `receiptAmbiguities` → `{ split }`. Synchronous, 3–10 s |
| 5 | `PATCH /splits/:id/receipt` | partial `Receipt` (edit a line, the service charge, the printed total) | Recomputes the add-up check, resolves or raises the mismatch ambiguity |
| 6 | `POST /splits/:id/participants` | `{ names: string[] }` | Adds people with colours and join order. The organiser is created at scan time |
| 7 | `DELETE /splits/:id/participants/:pid` | | Only before `lock`. Removes their claims |
| 8 | `POST /splits/:id/open` | | `draft → claiming`. Returns `{ links: { participantId, url }[], groupMessage }`. The group message is a ready-to-paste text listing each friend's link |
| 9 | `POST /splits/:id/claims/message` | `{ participantId \| null, message }` | AI claim parse (§7.2) against the receipt and current claims. `participantId` null means the organiser is typing in the group chat view and the AI must attribute names. Returns `{ applied: Claim[], problems: Ambiguity[] }` and writes the claims |
| 10 | `PATCH /splits/:id/claims` | `{ lineId, claims: Claim[] }` | Manual claim edit, and resolves "share between everyone" |
| 11 | `POST /splits/:id/rules/message` | `{ message }` | AI rule parse (§7.3): "it's Sam's birthday so his is on us" → `Rules` patch preview. Not applied until confirmed |
| 12 | `PATCH /splits/:id/rules` | partial `Rules` | Applies rules and recomputes `computed` |
| 13 | `POST /splits/:id/lock` | | `claiming → collecting`. Fails with problems if anything is unclaimed. Writes `shareMinor`. On-us participants and the organiser go straight to `on_us` / settled |
| 14 | `POST /splits/:id/unlock` | | Only if no participant has a PayPal order |
| 15 | `POST /splits/:id/participants/:pid/paid-cash` | | Marks a cash or bank payment. Settled logic counts it |
| 16 | `POST /splits/:id/participants/:pid/nudge` (+ `/sent`, `/snooze`) | Sorted's shapes | Drafts a friend nudge with the link |
| 17 | `POST /splits/:id/cancel` | | Supersedes open PayPal orders |
| 18 | `POST /splits/:id/preview-link/:pid` | | Returns that participant's link, for the judge's **Preview as Dan** |

After every write that touches the receipt, claims, rules or participants, recompute `computed` in the same transaction. The app only ever renders `computed`.

### Friend pages (public, signed, no auth)

The URL is `/s/{organiserId}/{splitId}/{participantId}/{sig}`, where `sig = HMAC-SHA256(LINK_SECRET, "organiserId:splitId:participantId")` in base64url, verified with `timingSafeEqual`. A bad signature gets the same plain "This link doesn't work" page as a missing split, so ids cannot be probed. Port Sorted's `verifyInvoiceSignature`.

| Endpoint | Behaviour |
|---|---|
| `GET /s/...` | One page whose content follows state. **claiming + not yet claimed**: "What did you have, Dan?" textarea. **Claimed**: their matched lines plus "Waiting for everyone else". **collecting + owes**: the FriendPay breakdown with **Pay £39.23 with PayPal**. **paid**: "Paid. Thanks, Kemi's been told." **on_us**: "This one's on the group." Sets `linkOpenedAt` on first view |
| `POST /s/.../claim` | `{ message }` → AI parse scoped to this participant (it may only claim for themselves) → `{ matched lines, problems }` preview. No write yet |
| `POST /s/.../claim/confirm` | `{ lineIds+weights }` from the preview → writes the claims (`source: 'friend'`) in a transaction → `claimed` |
| `POST /s/.../pay` | Requires `collecting` and `owes`. Lazily creates the PayPal order (`custom_id = organiserId:splitId:participantId`, `PayPal-Request-Id = pay-{splitId}-{pid}-{supersededCount}`, `payee` = the organiser's `paypalEmail`) → `303` to the approval URL. A second tap reuses the open order |
| `GET /paypal/return`, `GET /paypal/cancel` | Sorted's pages: capture on return, then link back to `/s/...` |

**Why `LINK_SECRET` is new.** Sorted signs invoice links with `INTERNAL_TOKEN`, the same secret that guards the internal sweep routes. If one leaks, both are compromised. Keep them separate here, and fix it in Sorted when there is time.

**Rate limit.** Public claim parses cost money. Allow at most **8 AI parses per participant link** (`aiParsesUsed`). After that, show "Pick from the bill instead", a checklist of receipt lines.

### Webhooks and sweeps

Sorted's route, ledger, verification and idempotency, with `locateShare` in place of `locateOrder`. Statuses map one to one: `CHECKOUT.ORDER.APPROVED` → capture, `PAYMENT.CAPTURE.COMPLETED` → `paid`, and so on. After a participant flips to `paid`, check whether the split is settled. If every participant is `paid`, `paid_cash` or `on_us`, set `status: settled`.

`POST /internal/workflows/reconcile` (every 10 min) and `/expire-sweep` (hourly) run over open participant shares. **Point a real scheduler at them on day one.** Render cron or any external cron works, but the service must be on `starter`, not `free`.

---

## 5. PayPal sequence

**Create (lazily, on the friend's Pay tap):** Orders v2, `intent: CAPTURE`, one purchase unit: `reference_id: participantId`, `custom_id: organiserId:splitId:participantId`, `amount: { GBP, value: toPayPalValue(shareMinor) }`, `description: "Your share of Friday dinner (Little Bao House)"`, `payee: { email_address }` when set. Use **no item breakdown**, because a share is not a list of goods (Sorted's deposit path already does this). Use `payment_source.paypal.experience_context`, as verified in Sorted: status `PAYER_ACTION_REQUIRED`, approval link `rel="payer-action"`, brand `Split`, locale `en-GB`, `NO_SHIPPING`, `PAY_NOW`.

**Capture:** on return (primary), on `CHECKOUT.ORDER.APPROVED`, or by the reconcile sweep, whichever lands first. `PayPal-Request-Id: capture-{participantId}` makes this idempotent.

**Paid:** `PAYMENT.CAPTURE.COMPLETED` or a reconcile `COMPLETED` → `paid`, `paidAt`, a payment event, and the settled check.

**Failure states:** Sorted's table applies unchanged. In addition, a **share changed after an order exists** (unlock and edit) adds the old order id to `supersededPaypalOrderIds`, and a capture on it is flagged `refundDue`, exactly as Sorted's edit path does.

**Week-1 verification (record in `docs/verified-facts.md`):** create a sandbox order with `payee.email_address` set to a **sandbox personal account**, approve it as another sandbox personal buyer, and capture it. Confirm the money lands in the personal account and note whether any webhook arrives. If a personal payee is refused, the fallback is the shared sandbox merchant, with an honest line in the README and Connect copy.

---

## 6. Flutter screens

The visual source of truth is `docs/design/screens/*.dc.html` plus `docs/design/DESIGN.md`. Where this spec and a screen disagree on layout or copy, the screen wins. Where they disagree on behaviour, this spec wins.

| Route | Screen file | Purpose |
|---|---|---|
| `/welcome` | `Main.dc.html` | First run only. "Split a bill" and "See my splits" |
| `/` | `Home.dc.html` | The active split as a dark card ("£79.03 of £118.26 back"), a needs-you card ("Dan opened his link but hasn't paid"), the settled list, a primary "Split a new bill", and a **Try a sample bill** row for judges |
| `/scan` (sheet) | `Scan.dc.html` | Camera on mobile, file picker on web. Up to two photos |
| `/split/:id/reading` | none (reuse Sorted's Reading pattern) | A ticking checklist while the receipt is read: "Found 10 items", "Found a service charge", "Checking it adds up to £154.69" |
| `/split/:id/receipt` | `Receipt.dc.html` | Lines with inline edit, the service charge card ("By what they had / Evenly"), the add-up check, total |
| `/split/:id/people` | `People.dc.html` | Type a name, coloured avatar chips, the organiser preset. "Ask everyone what they had" calls `open` and shows the share sheet with the group message |
| `/split/:id/claims` | `Claim.dc.html` | Group-chat view of claim messages (friends' and the organiser's), each followed by its "Added to Amaka" card. Progress bar ("9 of 10 items claimed"), unclaimed-item warning card, message composer (endpoint 9), Totals button |
| `/split/:id/rules` | `Rules.dc.html` | Shared items, the on-us toggle, the service charge mode. A rule message from the composer shows as a confirm card first |
| `/split/:id/breakdown` | `Breakdown.dc.html` | Who owes what, expandable per person, the "Adds up to the £154.69 on the bill" check, "Send links for £118.26" → `lock` |
| `/split/:id` | `Tracker.dc.html` | Live participant rows with `ShareStatusPill`, `PaidPop` on flip, Nudge, Mark as paid in cash, **Preview as Dan** in each row's menu, the Settled stamp when done |
| `/split/:id/nudge/:pid` (sheet) | `Nudge.dc.html` | Sorted's nudge screen with the friend's link |
| `/settings` | none | Name friends see, PayPal email (with the sandbox note), repo and licence links |
| (server page) | `FriendLink.dc.html`, `FriendPay.dc.html` | Not Flutter. Rebuild as the API's friend pages using the same tokens |

**Participant colours** (add to `SplitColors`; each pair is a fill and its text): `#FFC439`/`#3D2B00`, `#FF9F80`/`#4A1A0A`, `#9DBEFF`/`#0A2560`, `#7AD9AE`/`#063D26`, `#D6B0FF`/`#3A1466`, then three more of the same lightness for groups of six to eight. A person's colour follows their items everywhere: receipt dots, claim cards, breakdown rows. That is the signature idea.

**Realtime.** `StreamProvider`s over the split doc and its participants subcollection, as Sorted's orders. The tracker flip is the money shot, so test it with a fake stream the way Sorted's `orders_screen_test` does.

---

## 7. AI pipeline

All calls go through the copied `generateStructured()`: strict JSON schema, Zod validation, one corrective retry, no temperature. On a second failure, return `AI_PARSE_FAILED` and fall back to manual entry. Nobody is ever blocked by the model.

### 7.1 Receipt extraction (vision, 1–2 images)

System prompt: *"You read a UK restaurant or bar receipt. Return every purchased line exactly as printed with its quantity and line total in pence. Return the service charge, tip, discounts and the printed total separately. A line like 'Lager x3 16.50' is qty 3 with a line total of 1650, not three lines. If two images are given, they are parts of one long receipt: join them and do not double-count the overlap. If a value is unreadable, return null and add an ambiguity. Never compute or correct a total; report what is printed."*

Schema: `{ merchant, receiptDate, lines: [{ name, qty, lineTotalMinor|null }], serviceChargeMinor|null, serviceChargeLabel|null, tipMinor|null, discounts: [{ label, amountMinor }], printedTotalMinor|null, ambiguities: [Ambiguity] }`

**Then code checks the arithmetic.** `Σ lines + service + tip − discounts` vs `printedTotalMinor`. A mismatch becomes a blocking `price_conflict` ambiguity naming both numbers: "Items add up to £152.10 but the bill says £154.69. Check the photo or edit a line." A null price is a blocking `missing` ambiguity on that line.

Before building on this, run the same model-selection spike Sorted did: three sample receipts through two or three candidate models, results recorded in `verified-facts.md`. The failure to watch for is the one gpt-4.1-mini showed on Sorted, misreading quantities in a way that silently changes money.

### 7.2 Claim parsing (text)

Input: the receipt lines with ids, qty and **remaining unclaimed units**, the participant names, the current claims, and the message. For a friend-page call, also the friend's own participant id.

System prompt: *"Assign receipt lines to the people who had them, from what someone wrote. 'Two of the lagers' is weight 2 on the lager line. 'Me and Amaka shared the nachos' is weight 1 each for the writer and Amaka. Only use line ids from the receipt. If a phrase could match two lines, or asks for more units than remain, or names someone not in the group, add an ambiguity with one-tap options instead of guessing. When the writer is a friend, they may only claim for themselves; ignore claims for others and say so."*

Schema: `{ claims: [{ lineId, participantId, weight }], ambiguities: [Ambiguity], ignored: string[] }`

Code then validates: the line ids exist, the weights are integers, and no line is over-claimed beyond `qty` unless shared. Validation failures become ambiguities. The model never sees or produces money.

### 7.3 Rule parsing (text)

Input: the participant names and the current rules. Output: `{ onUs: participantId[], onUsPaidBy: participantId[]|null, serviceMode: 'proportional'|'even'|null, serviceOptOut: participantId[], confirmationText }`. It is always shown as a confirm card ("Sam's share, £29.10, split between the other 4?"), with the figure computed by code, and is never auto-applied.

### 7.4 Nudge drafting

Sorted's `draft_nudge.ts`, re-prompted for friends: *"A friendly reminder to a friend about their share of a group bill. Never guilt. Under 40 words. Include the link exactly once."* Keep `shouldSkip`. Skip when the friend opened the link less than an hour ago.

### 7.5 Group message

A template, no AI: "Friday dinner at Little Bao House. Tap your link and say what you had:\nAmaka: [link]\nJosh: [link]\n…". Templates are free, instant and never wrong.

---

## 8. Judge experience

- Hosted web URL on line one of the README. Sorted's spec makes the same promise. Deploy the web build in week 1, not week 3.
- **Try a sample bill** on Home seeds the Little Bao House split from `samples/receipts/little-bao-house.png`. Produce it from hand-written HTML, as Sorted's DM samples were.
- **Preview as Dan** on each tracker row opens that friend's page in a new tab. A judge alone can play every part.
- Sandbox buyer credentials in the README.
- `samples/receipts/` with 4 receipts: the canonical one, one with a discount, one with no service charge, and a two-photo long receipt.
- `docs/architecture.md` with the data-flow diagram, and `docs/reused-from-sorted.md` stating plainly what came from the sister project.

---

## 9. Risks, ranked by how badly they could block the build

| # | Risk | Mitigation |
|---|---|---|
| 1 | **Time, shared with Sorted.** Sorted still has its own submission week, video and README to finish | Split must not touch Sorted's critical path. Gate: if Split's core loop (scan → claim → lock → pay → paid) isn't working by **Sun 1 Nov**, ship Split as-is, polish Sorted, and decide that day whether to submit Split at all |
| 2 | **PayPal payee to a personal sandbox account refused** | Verify on day 1 (§5). Fallback: the shared sandbox merchant, stated honestly |
| 3 | **Receipt OCR misreads quantities or totals** | The add-up check blocks anything wrong. Model spike before building. Ambiguities first, as Sorted did |
| 4 | **Claim parsing attributes items to the wrong person** | The friend scope (self only), a preview-then-confirm flow on friend pages, and the organiser can edit any line |
| 5 | **Rounding drift** | Largest remainder, the invariant check, the golden fixture, property tests |
| 6 | **Free Render plan sleeps and the sweeps stop** | `starter` from day 1. Sorted is still on `free` too, so fix that first |
| 7 | **Friend page abuse (AI cost)** | Per-link parse cap. Signed links only |
| 8 | **Devpost "substantially different" scrutiny** | A different user, problem, AI task (receipt + claims vs DM orders), payment shape (many payers to one person vs one buyer to a shop) and allocation engine. State the shared foundation openly in the README |

---

## 10. Timeline (Oct 20 → Nov 10), shift-sized tasks

### Week A: Oct 20–26, foundations and money

- Create `tade-dev/split` (public, MIT). Copy the files in §1, rename, and get **every copied test green** before adding anything
- New Firebase project, anonymous auth, Firestore rules plus ported emulator tests
- Render `split-api` on `starter`. Health check. Scheduler pointed at reconcile and expire
- PayPal payee spike (§5). Model spike for receipts (§7.1). Record both in `verified-facts.md`
- `domain/allocate.ts` with the golden fixture and property tests. **This is the gate for the week.**
- `ai/extract_receipt.ts`, `POST /splits/scan`, `PATCH /receipt`, the add-up check
- Flutter: theme, Home skeleton, Scan, Reading, Receipt. **Deploy the web build.**

### Week B: Oct 27 – Nov 2, claims to Paid

- Participants, `open`, links (`domain/links.ts`), the group message
- `ai/parse_claim.ts`, endpoints 9 and 10, Claim screen
- Friend pages: claim → confirm → waiting → pay
- `ai/parse_rules.ts`, Rules screen, Breakdown, `lock`
- Generalised `createPayPalOrder`, the Pay endpoint, return capture, webhooks and reconcile on participants
- Tracker with a live flip, PaidPop, Settled stamp
- **Gate (Sun 1 Nov): a sample bill paid end to end on the hosted web build.**

### Week C: Nov 3–9, polish and ship

- Nudges, mark as paid in cash, unlock/supersede, cancel
- Empty, error and loading states. Preview as Dan
- README, samples, architecture doc, reused-from-sorted doc, sandbox credentials
- Record the video (§11). **Submit Tue 10 Nov** with Sorted.

---

## 11. Demo video (under 3 minutes)

| Time | Beat |
|---|---|
| 0:00–0:20 | **Problem:** Kemi paid £154.69 for five people. Three days later she's still chasing. |
| 0:20–0:45 | **Snap:** the receipt is read, the service charge is found, and "Adds up to £154.69" is checked on screen. |
| 0:45–1:30 | **Plain-words claims:** Dan's phone opens a link with no app and types "spicy ramen, a lager and one of the bao". The match appears and he taps That's right. Cut to the organiser's claim chat filling in colour. The unclaimed-crackers warning. "It's Sam's birthday so his is on us", confirmed with the figure. |
| 1:30–1:50 | **Breakdown:** every share to the penny, adding up to the bill. Send links for £118.26. |
| 1:50–2:30 | **Paid, live:** Dan pays with PayPal sandbox on the left, and his row flips to Paid on the right with the haptic pop. The last friend pays and the Settled stamp lands. |
| 2:30–2:50 | **Nudge:** one tap drafts a friendly reminder with the link. |
| 2:50–3:00 | **Close:** "Snap the bill. Everyone pays their bit." Next: per-organiser PayPal onboarding, recurring house bills. |

---

## 12. Non-goals

No friend app or friend accounts. No contacts import (typed names). No share extension or share intent. No SMS or WhatsApp sending; the organiser copies messages. No currencies other than GBP. No PayPal friends-and-family transfers (no public API exists for them; payments use checkout to the organiser). No receipts for itemised VAT. No ongoing balances between friends (Splitwise territory); each split settles on its own.
