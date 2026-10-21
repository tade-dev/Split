# Reused from Sorted

Split is the sister app to [Sorted](https://github.com/tade-dev/sorted). Its
foundation (design tokens, motion layer, API shell, AI seam and PayPal
pipeline) was copied from Sorted at commit **`902dc25`** (merge of
`tade-dev/sorted#18`, 2026-10-19) and then renamed. Nothing is shared as a
package: each repo stands alone, as Devpost requires. This page lists every
copied file so the reuse is stated openly.

**Renames applied everywhere:** `Sorted*` → `Split*`, `sorted*` helpers →
`split*`, `sellerId` → `organiserId`, `requireSeller` → `requireOrganiser`,
the `sellers` collection → `organisers`, `SortedStamp` → `SettledStamp`,
`StatusPill` → `ShareStatusPill`, `SnapScreen` → `ScanScreen`,
`sorted-api` → `split-api`, `demo-sorted` → `demo-split`.

**Actions.** *Copy* is verbatim plus those renames. *Adapt* is copied, then
changed only as far as it needed to compile without the Sorted features that
were not brought across. The behavioural adaptations the Split spec (§1)
describes are listed under [Still to adapt](#still-to-adapt) and land in the
implementation plans. *Transitional* files are not in §1. They are trimmed
copies kept only so Adapt files compile unchanged, and they are deleted when
the participant model replaces them.

Baseline: at `902dc25`, Sorted's suites were green here (API 497 tests,
Flutter 378 tests, analyze clean). After the copy, Split's are green too:
API 228 tests, Flutter 156 tests, `tsc --noEmit` and `flutter analyze` clean.

## API (`api/`)

| Split path | Sorted path | Action | What changed |
|---|---|---|---|
| `src/env.ts` | `src/env.ts` | Adapt | `DEFAULT_PUBLIC_BASE_URL` → `https://split-api-k5ai.onrender.com` (the URL Render assigned on first deploy) |
| `src/firebase.ts` | `src/firebase.ts` | Adapt | None beyond renames |
| `src/index.ts` | `src/index.ts` | Adapt | Log line |
| `src/app.ts` | `src/app.ts` | Adapt | Catalogue, orders, session and summary routers removed; the invoice option to the PayPal pages removed |
| `src/lib/auth.ts` | `src/lib/auth.ts` | Copy | `req.sellerId` → `req.organiserId` |
| `src/lib/errors.ts` | `src/lib/errors.ts` | Copy | Adds `SPLIT_STATE_INVALID` |
| `src/lib/image_type.ts` | `src/lib/image_type.ts` | Copy | |
| `src/ai/client.ts` | `src/ai/client.ts` | Copy | `generateStructured()`, transport and corrective retry untouched |
| `src/ai/draft_nudge.ts` | `src/ai/draft_nudge.ts` | Adapt | None yet. Still drafts for a buyer's order |
| `src/domain/money.ts` | `src/domain/money.ts` | Copy | `allocateLargestRemainder()` is added in plan 1 |
| `src/domain/nudge.ts` | `src/domain/nudge.ts` | Adapt | None yet |
| `src/domain/links.ts` | `src/domain/invoice.ts` | Adapt | HMAC sign, verify and URL only. The invoice page and invoice numbers are dropped |
| `src/paypal/client.ts` | `src/paypal/client.ts` | Copy | |
| `src/paypal/orders.ts` | `src/paypal/orders.ts` | Adapt | Brand name `Split`. Generalised to `createPayPalOrder(ShareOrder)` (Week B Task 9) |
| `src/paypal/events.ts` | `src/paypal/events.ts` | Adapt | Three-part `custom_id`; a COMPLETED capture is Paid (`captureOutcome`) (Week B Task 10) |
| `src/paypal/reconcile.ts` | `src/paypal/reconcile.ts` | Adapt | `reconcileShare` and `locateShare` over participant docs (Week B Task 10) |
| `src/paypal/buyer_page.ts` | `src/paypal/buyer_page.ts` | Adapt | Wordmark `Split` |
| `src/routes/webhooks.ts` | `src/routes/webhooks.ts` | Adapt | `locateShare`; ledger and idempotency unchanged (Week B Task 10) |
| `src/routes/paypal_pages.ts` | `src/routes/paypal_pages.ts` | Adapt | `/invoice/...` route removed. The return page captures and redirects to the friend's page (Week B Task 10) |
| `src/routes/internal.ts` | `src/routes/internal.ts` | Adapt | `reconcile` and `expire-sweep` walk shares in collecting splits (Week B Task 10). `nudge-sweep` still walks `organisers/*/orders` until Week C |
| `src/routes/health.ts` | `src/routes/health.ts` | Adapt | None |
| `src/domain/orders.ts` | (deleted) | Transitional | Retired in Week B. `assertShareTransition` in `domain/shares.ts` replaces `assertTransition`; the nudge's order shape is `NudgeOrder` in `domain/nudge.ts` |
| `src/domain/closing.ts` | (deleted) | Transitional | Retired in Week B. The expiry sweep replaces a share's order instead of closing anything (plan E8) |
| `src/domain/dates.ts` | (deleted) | Transitional | Retired in Week B. Its two helpers moved into `draft_nudge.ts`, their only user |
| `src/ai/schemas.ts` | `src/ai/schemas.ts` | Transitional | Trimmed to `ambiguitySchema` (Split reuses the shape) and `nudgeDraftSchema` |
| `package.json`, `package-lock.json` | same | Adapt | Name `split-api`, description. Dependency versions identical |
| `tsconfig.json`, `vitest.config.ts` | same | Copy | |
| `render.yaml` | `api/render.yaml` | Adapt | Service `split-api`, **plan `starter`** |
| `.env.example` | `api/.env.example` | Adapt | `PUBLIC_BASE_URL` |

### API tests

All copied with renames. Each keeps the supertest + fake-transport +
fake-PayPal style.

| Split test | Sorted test | Notes |
|---|---|---|
| `test/emulator-guard.ts`, `emulator-guard.test.ts` | same | |
| `test/ai-client.test.ts`, `ai-client.live.test.ts` | same | The live suite skips without keys |
| `test/auth.test.ts`, `cors.test.ts`, `env.test.ts`, `firebase.test.ts`, `health.test.ts`, `image-type.test.ts`, `money.test.ts` | same | |
| `test/draft-nudge.test.ts`, `nudge-domain.test.ts` | same | |
| `test/paypal-client.test.ts`, `paypal-events.test.ts`, `paypal-orders.test.ts`, `paypal-orders.live.test.ts` | same | |
| `test/paypal-buyer.test.ts` (now `paid-return.test.ts`), `webhooks.test.ts`, `expire-sweep.test.ts` | ported to shares | Emulator |
| `test/firestore-rules.test.ts` | same | Emulator. Paths `sellers/` → `organisers/` |
| `test/links.test.ts` | `test/invoice.test.ts` | Signature cases only. The invoice-page and invoice-route cases went with the page |

## Repo root

| Split path | Sorted path | Action |
|---|---|---|
| `LICENSE` | `LICENSE` | Copy (MIT, holder `Split`) |
| `.gitignore` | `.gitignore` | Copy |
| `firebase.json` | `firebase.json` | Copy |
| `firestore.rules` | `firestore.rules` | Adapt: `sellers` → `organisers` |
| `scripts/emulators.sh` | `scripts/emulators.sh` | Adapt: `--project demo-split` |

## Flutter (`app/`)

Platform folders (`android/`, `ios/`, `web/`) were generated fresh with
`flutter create --org dev.tade --project-name split`, so no Sorted bundle
id, Firebase config or iOS share extension came across.

| Split path | Sorted path | Action | What changed |
|---|---|---|---|
| `lib/core/theme/split_colors.dart`, `split_shape.dart`, `split_theme.dart` | `lib/core/theme/sorted_*.dart` | Adapt | Renames only so far. Participant colours are added in plan 1 |
| `lib/core/motion/*.dart` (10 files, `split_motion.dart` was `sorted_motion.dart`) | `lib/core/motion/*` | Copy | `SplitSprings` / `SplitDurations` / `SplitCurves`; doc comments name the Settled stamp |
| `lib/widgets/primary_button.dart`, `selectable_chip.dart`, `segmented_control.dart`, `warning_card.dart`, `skeleton.dart`, `money_roll.dart`, `reply_bubble.dart` | same | Copy | |
| `lib/widgets/split_toast.dart`, `split_app_bar.dart`, `split_icon.dart` | `lib/widgets/sorted_*.dart` | Copy | |
| `lib/widgets/settled_stamp.dart` | `lib/widgets/sorted_stamp.dart` | Adapt | `SettledStamp`, says "Settled" |
| `lib/features/split/share_status_pill.dart` | `lib/features/orders/status_pill.dart` | Adapt | `ShareStatusPill`. Morph and lightness rule unchanged |
| `lib/features/split/share_presentation.dart` | `lib/features/orders/order_presentation.dart` | Adapt | Trimmed to `StatusTone` and `statusPresentation`. Labels are still Sorted's order statuses |
| `lib/core/money.dart`, `firestore_time.dart`, `uk_date.dart`, `api_client.dart` | same | Copy | |
| `lib/core/env.dart` | same | Copy | `API_BASE_URL` default → `https://split-api-k5ai.onrender.com` |
| `lib/features/scan/camera_port.dart` | `lib/features/catalogue/camera_port.dart` | Adapt | None beyond renames |
| `lib/features/scan/scan_screen.dart` | `lib/features/catalogue/snap_screen.dart` | Adapt | Catalogue extraction replaced by a `scanReaderProvider` seam that returns the next route. Copy is still Sorted's ("Snap your stock", five photos) |
| `lib/providers/organiser_provider.dart` | `lib/providers/seller_provider.dart` | Adapt | `organiserIdProvider` only (anonymous sign-in + bootstrap). The seller doc stream and updater were dropped with the `Seller` model |
| `lib/providers/api_provider.dart` | same | Copy | |
| `lib/router.dart` | `lib/router.dart` | Adapt | No tab shell. `/` placeholder and `/scan` sheet |
| `lib/main.dart` | `lib/main.dart` | Adapt | Share intake and the orders paid listener removed |
| `lib/firebase_options.dart` | none | New placeholder | Throws until `flutterfire configure` runs against Split's own project |
| `assets/fonts/*`, the `fonts:` block of `pubspec.yaml` | same | Copy | |
| `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `build.yaml` | same | Adapt | Name `split`. `receive_sharing_intent` dropped (no share intent in v1) |

### Flutter tests

| Split test | Sorted test | Notes |
|---|---|---|
| `motion_discipline_test`, `press_coverage_test`, `motion_test`, `motion_access_test`, `spring_curve_test`, `page_transitions_test`, `reveal_test`, `enter_stagger_test`, `after_arrival_test`, `paid_pop_test`, `press_scale_test` | same | `press_coverage_test` loses its two `ProductTile` cases |
| `theme_test`, `money_test`, `money_roll_test`, `uk_date_test` | same | |
| `firestore_time_test` | same | Keeps the converter case. The `Order` and `PaymentEvent` cases went with those models |
| `widgets_test` | same | Keeps the PrimaryButton and WarningCard cases. Three `ProductTile` cases dropped |
| `split_app_bar_test`, `split_toast_test` | `sorted_app_bar_test`, `sorted_toast_test` | |
| `settled_stamp_test` | `sorted_stamp_test` | Expects "Settled" |
| `share_status_pill_test` | `status_pill_test` | |
| `scan_screen_test`, `scan_motion_test` | `snap_screen_test`, `snap_motion_test` | Override `scanReaderProvider` in place of the catalogue repository |

## Still to adapt

The §1 notes that this copy deliberately has not done yet, and where each
one is picked up:

| Spec §1 note | Plan |
|---|---|
| `money.ts`: add `allocateLargestRemainder()` | 1, Foundations and money |
| Participant colours on `SplitColors` | 1, Foundations and money |
| `scan_screen.dart` for receipts: one or two photos, "long bill? snap it in two parts" | 1, Foundations and money |
| `env.ts`: add `LINK_SECRET` | Week B |
| `links.ts`: sign `organiserId:splitId:participantId` with `LINK_SECRET` | Week B |
| `orders.ts`: generalised `createPayPalOrder({ referenceId, customId, amountMinor, ... })` | Week B. Done (Task 9) |
| `events.ts`: three-part `custom_id` | Week B. Done (Task 10) |
| `reconcile.ts`, `webhooks.ts` (`locateShare`), `internal.ts`: participant docs | Week B. Done (Task 10), and the transitional files are gone |
| `paypal_pages.ts`: return page links back to the friend's page | Week B. Done (Task 10): it redirects there |
| `buyer_page.ts`: shared layout for every friend page | Week B |
| `draft_nudge.ts`, `nudge.ts`: nudge a friend | Week C |
| `ShareStatusPill` participant statuses | Week B (Tracker) |
| `firebase_options.dart`: Split's own Firebase project | 1, Foundations and money |
