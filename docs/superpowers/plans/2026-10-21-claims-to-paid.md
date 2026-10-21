# Split Claims to Paid: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** By **Sun 1 Nov**, a judge on the hosted web build can do the following. Tap **Try a sample bill**, add four people and open the split. Paste Dan's link into a private window and type "spicy ramen, a lager and one of the bao". Confirm the match, and claim for the rest from the organiser's claim chat. Make Sam's birthday "on us", lock at £118.26, pay Dan's £39.23 as the sandbox buyer, and watch Dan's tracker row flip to Paid without reloading. That is spec §10's Week B gate. If it is not working by the end of that day, spec §9 risk 1 applies: ship Split as it is and put the week into Sorted.

**Architecture:** Nothing new at the core. `allocate()` stays the only place money comes from, and every write that touches claims, rules or participants recomputes `computed` in the same transaction (Week A's rule). Three new parsers: `ai/parse_claim.ts` (§7.2) and `ai/parse_rules.ts` (§7.3) go through `generateStructured()`, and code validates what they return. Friends get server-rendered pages under `/v1/s/...`, signed with a new `LINK_SECRET`. Payments reuse Sorted's pipeline, moved from order docs onto participant docs. The four transitional files from Week A then go.

**Tech Stack:** unchanged from Week A. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-20-split-design.md`, especially §2 (participants, lifecycle), §3 stage 1, §4 endpoints 3 and 6–14, the friend pages and webhooks, §5 (PayPal sequence), §6 (People, Claim, Rules, Breakdown, Tracker) and §7.2, §7.3 and §7.5.

**Design:** `docs/design/screens/People`, `Claim`, `Rules`, `Breakdown`, `Tracker`, `FriendLink`, `FriendPay`.

**Prior art in this repo (read before writing):**
- `api/src/domain/splits.ts`: `readSplit`, `computeFor`, `assertStatus`, `newParticipant`, `toApi`.
- `api/src/domain/allocate.ts`'s validate stage, `api/src/domain/links.ts` (still keyed as invoices) and `api/src/paypal/*`.
- `api/src/routes/{webhooks,paypal_pages,internal}.ts`, still on Sorted's order docs.
- `api/scripts/payee-spike.ts` and `app/lib/features/split/share_status_pill.dart`, which already maps participant statuses.

## Decisions taken (Tade, 2026-10-21)

These answer the three questions the Week A plan left open.

| # | Question | Decision | Where |
|---|---|---|---|
| Q1 | "Lager ×3: Josh 1, Dan 1" | **Ask the group.** A line whose total weight is below `qty` blocks, however many claimants it has, unless it is marked shared. The copy is "Lager: 1 of 3 unclaimed", with options *Share between Josh and Dan* and *Ask the group*. | Task 1 |
| Q2 | Manual entry when the AI read fails twice | **Now.** `POST /v1/splits` creates an empty draft, and the Receipt screen gains *Add a line* and an editable printed total, so a failed read lands on a blank receipt instead of a dead end. | Task 2 |
| Q3 | *Try a sample bill* | **Keep the live AI read.** The spike read all four sample receipts cleanly on `gpt-5.5` (`docs/verified-facts.md`, 2026-10-21), and the add-up check catches any misread on screen. | No change |

## Global Constraints

Week A's constraints all still hold. Read them in `2026-10-20-foundations-and-money.md`. Added for this week:

- **A friend link can only ever act for its own participant.** The signature covers `organiserId:splitId:participantId`. A friend's claim parse ignores claims for anyone else and says so (`ignored[]`).
- **The model never sees or produces money.** Claim and rule parsing return line ids, participant ids and integer weights. A rule's confirm card shows a figure that `allocate()` computed on the previewed rules.
- **Preview first, then write.** A friend's parse returns a preview, and only `claim/confirm` writes. A rule parse returns a preview, and only `PATCH /rules` applies it.
- **`LINK_SECRET` is not `INTERNAL_TOKEN`** (spec §4). Startup fails if they are equal.
- **One PayPal order per share at a time.** Its request id is `pay-{splitId}-{pid}-{supersededCount}`, and a second tap on Pay reuses the open order.
- **A paid share is never re-opened.** Unlock is refused once any participant has a PayPal order (spec §2). Superseding is Week C.
- **The AI parse cap is 8 per participant link**, counted in a transaction, then a checklist fallback.

## Review Focus

Each item has a test in the task that owns it.

1. **Over-claiming across messages.** Josh says "two lagers", then Dan says "a lager and another lager". The validator caps against remaining units at write time, inside the transaction, rather than at parse time, so two friends confirming at once cannot claim four of three (*Tasks 1, 5*).
2. **Re-claiming replaces, never adds.** A friend who confirms twice must end with their second claim, not both. The friend's own claims are replaced line by line, and other people's are left alone (*Task 5*).
3. **Link probing.** A bad signature, an unknown split and a removed participant all return the same 404 page with the same body (*Task 4*).
4. **The organiser's own share.** The organiser is a participant whose share is what they keep, so they must never be asked to pay or counted as owing. Spec §2 says the organiser "goes straight to on_us / settled". This plan uses `on_us` for both the organiser and on-us friends, never `paid`, and the tracker labels the organiser row "You" (*Task 8*).
5. **Settled check races.** Two friends' captures land at the same moment. The settled check reads every participant inside the same transaction as the flip, so exactly one write sets `settled` (*Task 10*).
6. **Capture on return for a payee order.** The capture call returns `COMPLETED` before any webhook, and may be the only signal (spec §0). The return page must flip the participant itself (*Task 10*).
7. **A friend paying with a stale amount.** The Pay route re-reads `shareMinor` in a transaction and refuses unless the split is `collecting` (*Task 9*).
8. **GitHub cron throttling.** The sweeps run about hourly, not every 10 minutes (verified-facts, 2026-10-21). Reconcile is only a safety net, because capture on return is primary. Task 12 adds a faster trigger anyway.

## Decisions this plan takes where the spec is silent

Veto any of these before execution starts.

| # | Gap | Decision |
|---|---|---|
| E1 | Organiser participant at lock | `status: 'on_us'`, `shareMinor` set to what they keep (3643 for Kemi). Counts as settled |
| E2 | Participant status after confirm | `claimed`. After lock it becomes `owes`, then `link_opened` once the friend views the pay page, then Sorted's `processing`, `pending` and `declined`, then `paid` |
| E3 | Removing a participant with claims | Allowed before lock. Their claims are removed, which can re-raise `unclaimed` problems. The organiser cannot be removed |
| E4 | Organiser claiming on someone's behalf (endpoint 9 with `participantId: null`) | The model attributes names from the message. A name not in the group becomes an `unclear` ambiguity with *Add {name}* as an option, never a silent new person |
| E5 | The "shared" marker for Q1 | A new `shared: true` flag on the line's claims entry: `claims[lineId]` becomes `{ claims: Claim[], shared: boolean }`. Only the organiser sets it, from the *Share between …* option. Week A docs hold `Claim[]` directly, so `readSplit` normalises the old shape on read |
| E6 | Rule parse with nothing recognised | Returns 200 with `{ preview: null, message: "I didn't catch a rule in that. Try 'Sam's on us'." }`. It is not an error |
| E7 | Group message link base | `PUBLIC_BASE_URL`, so links point at Render, not the web build. Friend pages are API pages (spec §0) |
| E8 | The expire sweep on shares | Leaves friend links valid. After `ORDER_EXPIRY_HOURS` it supersedes an unpaid share's PayPal order, so the next Pay tap makes a fresh one, and drops the participant back to `owes`. Nothing else expires |
| E9 | Faster reconcile | Task 12: an external pinger (cron-job.org, free, every 5 minutes) on `reconcile`, keeping GitHub Actions as the hourly backstop. A Render cron job is billed separately, so it is used only if the pinger proves unreliable |
| E10 | Payee | Decided by the payee spike (Task 0). If a personal payee works, Settings takes the organiser's PayPal email, and the demo organiser defaults to the payee sandbox account. If it is refused, every order pays the shared sandbox merchant and the README says so |

---

## File Structure

| File | Responsibility |
|---|---|
| `api/src/domain/split.ts` | `LineClaims = { claims: Claim[]; shared: boolean }`. `Claims` becomes `Record<lineId, LineClaims>` |
| `api/src/domain/allocate.ts` | Validate stage: a line under `qty` blocks unless `shared` (Q1) |
| `api/src/domain/claims.ts` | **New.** `remainingUnits`, `applyClaims` (cap, replace own, merge others) and `normaliseClaims` (the Week A shape) |
| `api/src/domain/links.ts` | Re-keyed: `shareSignature(secret, o, s, p)`, `verifyShareSignature`, `shareUrl` |
| `api/src/domain/group_message.ts` | **New.** The §7.5 template |
| `api/src/domain/lock.ts` | **New.** `lockSplit` and `unlockSplit`, plus the settled check `settleIfDone` |
| `api/src/ai/parse_claim.ts` | **New.** The §7.2 prompt and schema, and `toClaimPreview()` (validation) |
| `api/src/ai/parse_rules.ts` | **New.** The §7.3 prompt and schema, and `toRulesPreview()` |
| `api/src/ai/schemas.ts` | + `claimParseSchema`, `rulesParseSchema` |
| `api/src/routes/splits.ts` | + `POST /splits` (empty draft) and endpoints 6, 7, 8, 9, 10, 11, 13 and 14 |
| `api/src/routes/session.ts` | + `PATCH /session/organiser` (endpoint 3) |
| `api/src/routes/friend.ts` | **New.** `GET /s/...`, `POST /s/.../claim`, `/claim/confirm` and `/pay` |
| `api/src/pages/friend_page.ts` | **New**, from `paypal/buyer_page.ts`. One layout, four states (FriendLink and FriendPay) |
| `api/src/paypal/orders.ts` | Generalised `createPayPalOrder({ referenceId, customId, amountMinor, description, payeeEmail, requestId })` |
| `api/src/paypal/events.ts` | `parseCustomId` returns `{ organiserId, splitId, participantId }` |
| `api/src/paypal/reconcile.ts` | `reconcileShare` over a participant doc |
| `api/src/routes/webhooks.ts` | `locateShare` |
| `api/src/routes/paypal_pages.ts` | Capture on return, flips the participant, links back to `/s/...` |
| `api/src/routes/internal.ts` | Sweeps over `collectionGroup('participants')` |
| `api/src/domain/{orders,closing,dates}.ts` | **Deleted** (the transitional files). `schemas.ts` loses nothing it still uses |
| `api/src/env.ts`, `api/render.yaml`, `api/.env.example` | + `LINK_SECRET` |
| `app/lib/data/splits_repository.dart` | + `createEmpty`, `addPeople`, `removePerson`, `open`, `claimMessage`, `patchClaims`, `rulesMessage`, `lock`, `unlock` |
| `app/lib/features/split/receipt_screen.dart` | + *Add a line* and an editable printed total (Q2) |
| `app/lib/features/people/people_screen.dart` | **New.** Replaces the placeholder |
| `app/lib/features/claims/claims_screen.dart` | **New.** Claim chat |
| `app/lib/features/rules/rules_screen.dart` | **New** |
| `app/lib/features/breakdown/breakdown_screen.dart` | **New** |
| `app/lib/features/tracker/tracker_screen.dart` | **New.** Live rows, PaidPop, SettledStamp |
| `app/lib/router.dart` | `/split/:id/people`, `/claims`, `/rules`, `/breakdown`, `/split/:id` |
| `docs/verified-facts.md` | Payee spike result, the faster reconcile trigger, the gate run |

---

## Task 0: Finish the payee spike (operator)

Spec §5's week-1 check. It decides E10, so it comes first.

- [ ] **Step 1:** As the buyer sandbox account, approve order `9A667520R6342673Y` (created 2026-10-21 by `api/scripts/payee-spike.ts`).
- [ ] **Step 2:** `cd api && npx tsx scripts/payee-spike.ts --capture 9A667520R6342673Y`. Record the capture status, the payee in the response, and whether £39.23 arrived (net of fees) in the payee's sandbox account.
- [ ] **Step 3:** Check whether a webhook reached Render. Look in the service logs, or in `webhookEvents` in Firestore.
- [ ] **Step 4:** Under *PayPal* in `docs/verified-facts.md`, record the order id, `PAYER_ACTION_REQUIRED`, the `payer-action` rel, the capture status, where the money landed, whether a webhook arrived, and the date. If the payee was refused, record the exact error and pick E10's fallback.
- [ ] **Step 5:** Commit on `docs/payee-spike`.

## Task 1: Claims shape and Q1 in `allocate`

**Files:** `domain/split.ts`, `domain/allocate.ts`, `domain/claims.ts` (new), `test/allocate.test.ts`, `test/claims.test.ts` (new), `samples/demo-split.json` (the shape only).

- [ ] **Step 1: Failing tests first.**
  - `allocate`: "Lager ×3: Josh 1, Dan 1" now returns `ok: false` with `Lager: 1 of 3 unclaimed`. This replaces Week A's pinned 1:1 test.
  - The same claims with `shared: true` split 1:1.
  - Prawn crackers (qty 1, five claimants) still pass, because weight 5 ≥ qty 1.
  - The golden fixture is unchanged at 15469.
  - `claims.ts`:
    - `remainingUnits` on a fresh line is `qty`.
    - `applyClaims` refuses a weight above the remaining units with a `qty_unclear` problem ("Only 1 lager is left to claim").
    - A friend's second confirm replaces their first.
    - Another participant's claims survive.
    - `normaliseClaims` turns Week A's `Claim[]` into `{ claims, shared: false }`.
- [ ] **Step 2: Implement.**
  - In the validate stage, `units < line.qty && !lineClaims.shared` blocks for any number of claimants.
  - The options are `Share between {names}` when there are two or more claimants, plus `Ask the group`.
  - `applyClaims(current, incoming, { actor })` is pure. `actor` is `{ kind: 'friend', participantId }` or `{ kind: 'organiser' }`. A friend may only write their own claims; the organiser may write anyone's and may set `shared`.
- [ ] **Step 3: Migrate on read.** `readSplit` passes `split.claims` through `normaliseClaims`, so Week A docs, the seeded demo included, keep working without a backfill.
- [ ] **Step 4:** Run the property tests (500 runs). They now generate `shared` too.
- [ ] **Step 5:** Commit: `allocate: a line under its quantity asks the group`.

## Task 2: Manual entry (Q2)

**Files:** `routes/splits.ts`, `test/splits-route.test.ts`, `app/lib/data/splits_repository.dart`, `app/lib/features/split/receipt_screen.dart`, `line_edit_sheet.dart`, `app/lib/features/scan/reading_screen.dart`, and tests.

- [ ] **Step 1: API test.** `POST /v1/splits` with `{}` returns 201: a `draft` with no lines, `printedTotalMinor: null` and one blocking `missing` ambiguity ("What's the total on the bill?"). `PATCH /receipt` with `addLines: [{ name, qty, lineTotalMinor }]` appends lines with fresh `lineIdFor` ids.
- [ ] **Step 2: Implement.** Reuse `createSplit` with an empty receipt. Add `addLines` and `removeLineIds` to `receiptPatchSchema`. `applyReceiptPatch` already re-derives the add-up check.
- [ ] **Step 3: App.**
  - Reading's second-failure state gets a primary *Type it in instead*, which calls `createEmpty` and goes to Receipt.
  - Receipt gets an *Add a line* row (it opens `LineEditSheet` empty) and makes the printed total tappable.
  - Widget tests: the empty receipt shows the total question; adding two lines and a total clears it.
- [ ] **Step 4:** Commit: `receipt: type the bill in when the read fails`.

## Task 3: People, `open` and the group message

**Files:** `routes/splits.ts`, `domain/group_message.ts`, `domain/links.ts`, `env.ts`, `render.yaml`, `.env.example`, and tests. Then `app/lib/features/people/people_screen.dart`, the repository and the router.

- [ ] **Step 1: `LINK_SECRET`.**
  - `env.ts` adds `LINK_SECRET` as required, and throws if it equals `INTERNAL_TOKEN`.
  - `render.yaml` gains it with `sync: false`.
  - `.env.example` gains it.
  - **Operator:** set it in Render with `openssl rand -hex 32`, before this task's deploy.
- [ ] **Step 2: Links tests.**
  - `shareSignature` is stable and is 32 base64url characters.
  - `verifyShareSignature` rejects a changed participant id and a wrong-length signature, and runs in constant time. It is the Week A `verifyInvoiceSignature` body under a new name, with the message `share:{o}:{s}:{p}`.
- [ ] **Step 3: Endpoints 6 and 7.**
  - `POST /splits/:id/participants { names }` trims names, drops blanks, refuses more than 7 friends (8 colours, with the organiser first), and assigns `joinOrder` after the highest existing one. It recomputes `computed`. Allowed in `draft` and `claiming`.
  - `DELETE /splits/:id/participants/:pid` is allowed before `lock`, refuses the organiser, and removes their claims and their rule mentions (E3).
- [ ] **Step 4: Endpoint 8, `open`.**
  - It needs zero blocking receipt ambiguities and at least one friend.
  - It moves `draft` to `claiming` and returns `{ links: [{ participantId, name, url }], groupMessage }`.
  - It is idempotent once in `claiming`: it returns the same links again and does not change the status.
  - Test the exact group message for the Little Bao House demo with four friends:
    ```
    Friday dinner at Little Bao House. Tap your link and say what you had:
    Amaka: https://split-api-k5ai.onrender.com/v1/s/…
    …
    ```
- [ ] **Step 5: People screen** from `People.dc.html`.
  - A name field, coloured `Avatar` chips, and the organiser chip preset and not removable.
  - *Ask everyone what they had* calls `open`, then shows a sheet with the group message and *Copy* (`Clipboard`), and goes to `/split/:id/claims`.
  - Widget tests: add three names, remove one, then open shows the copy sheet.
- [ ] **Step 6:** Commit: `people: add the group and send their links`.

## Task 4: Friend page shell and link checks

**Files:** `api/src/routes/friend.ts`, `api/src/pages/friend_page.ts`, `app.ts`, `test/friend-page.test.ts`.

- [ ] **Step 1: Tests.**
  - A good link in `claiming` shows "What did you have, Dan?" with the receipt lines.
  - The first view sets `linkOpenedAt`, and a second view does not change it.
  - A bad signature, an unknown split and a removed participant all return 404 with a byte-identical body ("This link doesn't work").
  - `cancelled` shows "This bill was cancelled".
  - The page sets `Cache-Control: no-store` and `Referrer-Policy: no-referrer`.
- [ ] **Step 2: Implement.**
  - `GET /v1/s/:organiserId/:splitId/:participantId/:sig` verifies first, before any Firestore read, then loads the split and the participant.
  - `friend_page.ts` takes over `buyer_page.ts`'s tokens and `escapeHtml`. One function renders the four states (§4) from a state object, so each state is a pure test.
  - Mount it after `express.json`, and add `express.urlencoded` on this router, because the pages post both JSON and plain forms.
- [ ] **Step 3:** Commit: `friend: signed share pages`.

## Task 5: Claim parsing (§7.2), friend claim and organiser claim chat

**Files:** `ai/parse_claim.ts`, `ai/schemas.ts`, `routes/friend.ts`, `routes/splits.ts`, and tests. `test/parse-claim.live.test.ts` is skipped without `.env`.

- [ ] **Step 1: Schema and prompt.** Use §7.2's prompt verbatim. The schema is `{ claims: [{ lineId, participantId, weight }], ambiguities, ignored }`, sent to the model with:
  - lines as `{ id, name, qty, remaining }`,
  - participants as `{ id, name }`,
  - the writer (`{ id, name }`, or `null` for the organiser),
  - the message.
- [ ] **Step 2: `toClaimPreview` tests** (pure, with a fake transport):
  - Unknown line ids are dropped with an `unclear` problem.
  - A non-integer weight becomes `qty_unclear`.
  - A friend's claim for someone else goes to `ignored` and says so.
  - "two lagers" when one remains gives `qty_unclear`, "Only 1 lager is left to claim".
  - "me and Amaka shared the nachos" from Josh gives weight 1 each.
  - An empty result gives "I couldn't match that to the bill. Try naming the dish."
- [ ] **Step 3: Friend claim.** `POST /s/.../claim { message }`:
  - In a transaction, increment `aiParsesUsed`. Past 8, refuse with 429 and `{ fallback: 'checklist' }`.
  - Parse, then return `{ matched: [{ lineId, name, weight, portionLabel }], problems }`. Nothing is written.
- [ ] **Step 4: Friend confirm.** `POST /s/.../claim/confirm { lines: [{ lineId, weight }] }`:
  - In a transaction, `applyClaims` with the friend as actor, then recompute `computed`.
  - Set `claimText`, `claimedAt` and `status: 'claimed'`.
  - On over-claim, return 409 with the problems; nothing is written.
  - Test two confirms racing for the last lager: exactly one wins (Review Focus 1).
- [ ] **Step 5: Checklist fallback.** The friend page's checklist posts straight to `claim/confirm` with weight 1 per ticked unit, so the cap never leaves a friend stuck.
- [ ] **Step 6: Endpoints 9 and 10 (organiser).**
  - `POST /splits/:id/claims/message { participantId|null, message }` parses and writes in one go, because the organiser is trusted. It returns `{ applied, problems }`.
  - `PATCH /splits/:id/claims { lineId, claims, shared? }` replaces one line's claims, which is how *Share between everyone* resolves.
  - Both are allowed in `draft` and `claiming`.
- [ ] **Step 7: Friend page states.** *claimed* shows their matched lines and "Waiting for everyone else". Claiming again goes back to the form with their current lines ticked.
- [ ] **Step 8: Live test.** `parse-claim.live.test.ts` on `gpt-5.5` covers the video line ("spicy ramen, a lager and one of the bao") and two others. Record the result in verified-facts.
- [ ] **Step 9:** Commit: `claims: friends say what they had`.

## Task 6: Claim chat screen

**Files:** `app/lib/features/claims/claims_screen.dart`, the repository, the providers, `test/claims_screen_test.dart`.

- [ ] **Step 1:** Build from `Claim.dc.html`.
  - A message list: friends' `claimText` and the organiser's messages, each followed by an "Added to Amaka" card in their colour.
  - A progress bar ("9 of 10 items claimed", from `computed` problems).
  - A warning card per unclaimed line, with its options wired to `PATCH /claims`.
  - A composer for endpoint 9.
  - A *Totals* button, enabled only when nothing is unclaimed, that goes to Rules.
- [ ] **Step 2:** Widget tests with a fake stream:
  - A friend's confirm arriving makes the card appear without reloading.
  - *Share between Josh and Dan* sends `shared: true`.
- [ ] **Step 3:** Commit: `claims: the group chat view`.

## Task 7: Rules (§7.3)

**Files:** `ai/parse_rules.ts`, `routes/splits.ts` (endpoint 11), `app/lib/features/rules/rules_screen.dart`, and tests.

- [ ] **Step 1: Parser.** Use §7.3's schema. `toRulesPreview` drops unknown ids and returns E6's message when nothing is recognised. It runs `allocate()` on the previewed rules to produce the confirm card: "Sam's share, £29.10, split between the other 4?" (2910 from the golden fixture).
- [ ] **Step 2: Endpoint 11.** `POST /splits/:id/rules/message` returns `{ preview: { rules, confirmationText, figureMinor } | null }` and writes nothing. Test: "it's Sam's birthday so his is on us" with a fake transport gives `onUs: [sam]` and 2910.
- [ ] **Step 3: Rules screen** from `Rules.dc.html`.
  - The shared items list.
  - An on-us toggle per person.
  - *By what they had / Evenly* (`SegmentedControl`).
  - A composer whose preview shows as a confirm card, where *Yes* calls the existing `PATCH /rules`.
  - *See the breakdown* goes to Breakdown.
- [ ] **Step 4:** Commit: `rules: on us and service, in plain words`.

## Task 8: Breakdown, lock and unlock

**Files:** `domain/lock.ts`, `routes/splits.ts` (13, 14), `app/lib/features/breakdown/breakdown_screen.dart`, and tests.

- [ ] **Step 1: `lockSplit` tests.**
  - From `claiming` with no problems, it writes `shareMinor` from `computed` on every participant, sets `lockedAt`, and moves the split to `collecting`.
  - Friends with a share above 0 become `owes`. The organiser and on-us friends become `on_us` (E1).
  - It fails with 409 and the problems if anything is unclaimed.
  - It is idempotent in `collecting`.
  - Golden fixture: Kemi 3643 `on_us`, Amaka 3361, Josh 4542, Dan 3923, Sam 0 `on_us`. The amount owed to Kemi is 11826.
- [ ] **Step 2: `unlockSplit`** moves `collecting` back to `claiming`, clears `shareMinor` and `lockedAt`, and puts everyone back to `claimed`, or to `invited` if they never claimed. It is refused with `SPLIT_STATE_INVALID` if any participant has a `paypalOrderId`.
- [ ] **Step 3: Breakdown screen** from `Breakdown.dc.html`.
  - A row per person that expands to their lines with `portionLabel`.
  - "Adds up to the £154.69 on the bill" from `computed.totalMinor`.
  - `MoneyRoll` on the total when a rule changes.
  - *Send links for £118.26* calls `lock`, then goes to the tracker.
- [ ] **Step 4:** Commit: `breakdown: lock the split`.

## Task 9: Pay (generalised `createPayPalOrder`)

**Files:** `paypal/orders.ts`, `routes/friend.ts` (`/pay`), `routes/session.ts` (endpoint 3), `pages/friend_page.ts` (FriendPay), and tests.

- [ ] **Step 1: Generalise.**
  - The signature becomes `createPayPalOrder({ referenceId, customId, amountMinor, description, payeeEmail, requestId }, call, publicBaseUrl)`.
  - No item breakdown (spec §5).
  - The body shape stays what the payee spike sent, since that is what PayPal accepted.
  - Port Sorted's order tests to it.
- [ ] **Step 2: Pay tests.**
  - It refuses unless the split is `collecting` and the participant is `owes` or `link_opened`.
  - The first tap creates the order, stores `paypalOrderId` and `approvalUrl`, and answers 303 to the approval URL.
  - A second tap reuses the order and makes no second PayPal call.
  - `custom_id` is `o:s:p`, and the request id is `pay-{s}-{p}-0`.
  - The payee is the organiser's `paypalEmail`, or absent when null (E10).
  - The amount is the stored `shareMinor`, never recomputed (Review Focus 7).
- [ ] **Step 3: FriendPay state** from `FriendPay.dc.html`: their lines, their share of Sam, service, the final, and **Pay £39.23 with PayPal** (a form POST to `/pay`). Viewing it moves `owes` to `link_opened`.
- [ ] **Step 4: Endpoint 3.** `PATCH /session/organiser { displayName?, paypalEmail? }` validates the email and lets null clear it.
- [ ] **Step 5:** Commit: `pay: a PayPal checkout per share`.

## Task 10: Paid. Capture on return, webhooks, reconcile and the settled check

**Files:** `paypal/events.ts`, `paypal/reconcile.ts`, `routes/{paypal_pages,webhooks,internal}.ts`, `domain/lock.ts` (`settleIfDone`), and tests. **Delete** `domain/{orders,closing,dates}.ts`.

- [ ] **Step 1: `parseCustomId`** returns `{ organiserId, splitId, participantId }`, and anything not in three parts gives `null`. Test both.
- [ ] **Step 2: Participant transitions.** A small `assertShareTransition(from, to)` replaces `orders.ts`'s `assertTransition`:
  - `owes`/`link_opened` → `processing` | `pending` | `declined` | `paid`
  - `processing` → `pending` | `paid` | `declined`
  - `pending` → `paid` | `declined`
  - `declined` → `owes`
  - `paid` is terminal.
- [ ] **Step 3: Capture on return.**
  - `/paypal/return?token=` finds the participant by `collectionGroup('participants').where('paypalOrderId', '==', token)` (single-field indexes on collection groups need an exemption; add it to `firestore.indexes.json` and deploy it with the rules).
  - It captures with `PayPal-Request-Id: capture-{pid}` and, on `COMPLETED`, flips to `paid` and runs `settleIfDone` in the same transaction.
  - It renders "Paid. Thanks, Kemi's been told." with a link back to `/s/...`.
  - Test the payee-order path where the capture is the only signal (Review Focus 6).
- [ ] **Step 4: `settleIfDone(tx, splitRef)`** reads every participant in the transaction. If all are `paid`, `paid_cash` or `on_us`, it sets `status: 'settled'`. Test two captures racing: one `settled` write (Review Focus 5).
- [ ] **Step 5: Webhooks.**
  - `locateShare` finds the participant by `custom_id`, falling back to the `paypalOrderId` query.
  - The ledger and idempotency are unchanged.
  - `CHECKOUT.ORDER.APPROVED` → capture, `PAYMENT.CAPTURE.COMPLETED` → `paid`, `PENDING` → `pending`, `DENIED` → `declined`.
  - Port the existing webhook tests to participant docs.
- [ ] **Step 6: Sweeps.**
  - `reconcile` runs over `collectionGroup('participants')` with status in (`link_opened`, `processing`, `pending`) and a `paypalOrderId`.
  - `expire-sweep` follows E8.
  - `nudge-sweep` stays as is; its friend version is Week C.
  - Each returns the same count shapes as today, so the GitHub workflow's logs stay comparable.
- [ ] **Step 7: Delete the transitional files** and fix imports. `npm run typecheck` must be clean and `npm test` green, with the emulator running. Update `docs/reused-from-sorted.md`'s transitional rows to "retired in Week B".
- [ ] **Step 8:** Commit: `paid: capture on return, webhooks and reconcile on shares`.

## Task 11: Tracker with the live flip

**Files:** `app/lib/features/tracker/tracker_screen.dart`, the router, `test/tracker_screen_test.dart`.

- [ ] **Step 1:** Build from `Tracker.dc.html`.
  - Participant rows from `participantsProvider`, each with `ShareStatusPill`.
  - "£79.03 of £118.26 back" at the top.
  - A row's menu has *Copy link* and *Preview as Dan* (it opens the share URL in a new tab; endpoint 18 is Week C, so for now the URL comes from `open`'s response, cached on the split as `links`).
  - `PaidPop` and `PaidAnnouncer` on a flip to `paid`, and `SettledStamp` when the split is `settled`. These are the two `bouncy` uses.
- [ ] **Step 2:** Widget tests with a fake stream:
  - Dan goes `link_opened` → `paid` without a rebuild from the route, firing `PaidPop` once and announcing "Dan paid £39.23".
  - When the last share lands, the stamp shows.
  - `motion_discipline_test` still passes.
- [ ] **Step 3: Home** points the active split's card at `/split/:id` once it is `collecting`.
- [ ] **Step 4:** Commit: `tracker: watch everyone pay`.

## Task 12: Faster reconcile and the paid plan (operator)

- [ ] **Step 1: Render plan.** Move `split-api` to `starter`, or apply the hackathon credits. Set `plan: starter` in `render.yaml` in the same commit. Record the change and an idle-wake timing under 1 second in verified-facts. This is Task 13 step 4 from Week A.
- [ ] **Step 2: Pinger.** Create a cron-job.org job: `POST https://split-api-k5ai.onrender.com/v1/internal/workflows/reconcile` every 5 minutes, with header `X-Internal-Token`. Keep `sweeps.yml` as the hourly backstop. Record the job and its first three runs in verified-facts (E9).
- [ ] **Step 3:** Commit: `render: starter, and reconcile every 5 minutes`.

## Task 13: The gate run (Sun 1 Nov)

Run it on the hosted web build, in a private window, on a phone-sized viewport:

- [ ] **Step 1: Deploy.** Rebuild and redeploy the web app (`flutter build web --release --dart-define=API_BASE_URL=https://split-api-k5ai.onrender.com`, then `firebase deploy --only hosting --project split-b66c0`). Render deploys `main` by itself.
- [ ] **Step 2: Organiser.** *Try a sample bill*, then add Amaka, Josh, Dan and Sam, then *Ask everyone what they had*, then copy the group message.
- [ ] **Step 3: Dan.** Open his link in a second private window and type "spicy ramen, a lager and one of the bao". The match should be Spicy miso ramen, Lager 1 of 3 and Pork bao 1 of 3. Tap *That's right*, and the organiser's claim chat should show the card live.
- [ ] **Step 4: The rest.** The organiser claims for the others from the chat, using the golden fixture's claims, resolves the prawn crackers with *Share between all 5*, then says "it's Sam's birthday so his is on us". The card should read £29.10, then confirm.
- [ ] **Step 5: Lock.** Breakdown shows "Adds up to the £154.69 on the bill" and *Send links for £118.26*.
- [ ] **Step 6: Pay.** In Dan's window, refresh, tap *Pay £39.23 with PayPal*, and approve as the sandbox buyer. The return page says Paid.
- [ ] **Step 7: Flip.** The organiser's tracker flips Dan to Paid without reloading, within 5 seconds of the return page.
- [ ] **Step 8: Record.** Under *Deployment* in verified-facts: the date, the build, the order id, the time from approval to the flip, and anything that needed a retry. If any step fails, the gate fails. Write down which step, and make the spec §9 call that day.

---

## Plan complete

**Week B is done when:**
- `npm test`, `npm run typecheck`, `flutter analyze` and `flutter test` are green, with the transitional files gone;
- Task 13's gate run passes on the hosted build and is recorded;
- `docs/verified-facts.md` has dated entries for the payee spike, the claim parse live test, the `starter` plan and the faster reconcile trigger.

**Handed to Week C:**
- Nudges for friends.
- Mark as paid in cash (endpoint 15).
- Unlock with supersede after a PayPal order exists.
- Cancel (endpoint 17).
- Preview as Dan through endpoint 18.
- Empty, error and loading states everywhere.
- Settings (name and PayPal email).
- README, the architecture doc, sandbox credentials, the video and submission.
