# Verified facts

Confirmed against live systems, not assumed, with the date. Re-verify if
something fails in a way that contradicts this. Sorted's own record, which
Split builds on, is `tade-dev/sorted` `docs/verified-facts.md` at `902dc25`.

## Deployment

- **Render `split-api` is live at `https://split-api-k5ai.onrender.com`
  (verified 2026-10-20).** Created from the Blueprint on `main`. Render added
  the `-k5ai` suffix because `split-api` was taken, so the plain
  `split-api.onrender.com` is not ours. `GET /v1/health` returned `ok: true`,
  `paypalEnv: sandbox`, `visionModel: gpt-5.5`, `firebaseProject: split-b66c0`.
  It is now the code default for `PUBLIC_BASE_URL` and the app's
  `API_BASE_URL`.
- PayPal credentials in Render come from a dedicated Split sandbox app
  (Merchant), not Sorted's. Its webhook points at `/v1/webhooks/paypal`.
- **Web build is live at `https://split-b66c0.web.app` (deployed
  2026-10-20).** Built with Flutter 3.47.2,
  `--dart-define=API_BASE_URL=https://split-api-k5ai.onrender.com`, deployed
  with `firebase deploy --only hosting`. Plan Task 21's smoke test passed the
  same day at a 375×812 viewport: Home showed "Hi Kemi" and the Little Bao
  House card; *Try a sample bill* went through Reading to a Receipt with
  10 lines, no warning and £154.69; Lager at £15.60 raised "Items add up to
  £153.79 but the bill says £154.69. Check the photo or edit a line." with
  *Add people* disabled, and £16.50 cleared it; *Evenly* stuck after a
  reload. On a cold start (free plan asleep) Home shows a bare "Hi" for
  up to a minute until bootstrap returns.
- **Sweeps run from GitHub Actions** (`.github/workflows/sweeps.yml`, secret
  `INTERNAL_TOKEN`): `reconcile` every 10 minutes, `expire-sweep` and
  `nudge-sweep` hourly at :07. The manual run on 2026-10-20 17:30 UTC
  returned `{"checked":0,"promoted":0,"failed":0}`,
  `{"scanned":0,"expired":0,"kept":0,"failed":0}` and
  `{"scanned":0,"nudged":0,"skipped":0}`. **No scheduled run had fired by
  20:38 UTC**, three hours later; see *Still unverified*.

- **Render is on `starter` (2026-10-21).** It started on `plan: free` on
  2026-10-20, because `starter` needs a payment method before the Blueprint
  will create. Tade moved the service to `starter` before PayPal payments go
  live, and `api/render.yaml` now says so. A sleeping service would drop
  webhooks and could not run the sweeps.

## Firebase

- Project: **`split-b66c0`** (project number 399185024983), account
  `tadedev22@gmail.com`. `.firebaserc` default points at it.
- Apps registered by `flutterfire configure`, all bundle id **`dev.tade.split`**:
  web `1:399185024983:web:c95fafc60cb96ed10f1d92`, Android
  `…:android:6f812edad7c003d50f1d92`, iOS `…:ios:6264088da5844fd60f1d92`.
  macOS, Windows and Linux are deliberately not configured.
- **Verified 2026-10-20 against the live project**, with only the public web
  config (Identity Toolkit and Firestore REST):
  - Anonymous sign-in is enabled: `accounts:signUp` returned an ID token.
  - Split's rules are deployed, not the console defaults. As that anonymous
    user, reading its own `organisers/{uid}` returned **404** (allowed, the doc
    does not exist yet; default production rules would return 403), reading
    `organisers/someone-else` returned **403**, and writing its own doc
    returned **403**.
- Firestore: `(default)` database, `FIRESTORE_NATIVE`, location **`eur3`**
  (multi-region Europe), from `firebase firestore:databases:get` on
  2026-10-20.
- **Bootstrap works end to end (verified 2026-10-20).** A fresh anonymous
  ID token, then `POST /v1/session/bootstrap` with `{}`, returned 200 with
  organiser `displayName: "Kemi"`, `demoSeeded: true` and a `seededSplitId`.
  A second call returned 200 with the same organiser and
  `seededSplitId: null`, so it is idempotent. This also shows the API's
  Admin SDK credentials are set in Render.

## PayPal

- **A personal sandbox account can be the payee (2026-10-21).**
  `api/scripts/payee-spike.ts` created order `9A667520R6342673Y` for £39.23
  GBP with `payee.email_address` = `jeho@gmail.com`. PayPal returned
  `PAYER_ACTION_REQUIRED` with a `payer-action` link. The buyer
  `tadedev22@gmail.com` approved it, and capture `9HN51195SM208083J` came
  back `COMPLETED`: £39.23 gross, £1.53 fee, £37.70 net to the payee. The
  checkout showed the brand "Split", and `custom_id`
  (`org:split:participant`) round-tripped. No shared-merchant fallback is
  needed (plan decision E10).
- **Webhooks arrive for a payee order (2026-10-21).** About nine deliveries
  for the spike reached `POST /v1/webhooks/paypal`. At first every one failed
  verification, because PayPal rejected Render's `PAYPAL_WEBHOOK_ID` with 400
  "must match ^[a-zA-Z0-9]+$" and "size must be between 0 and 50": the wrong
  value had been pasted in. Once the real 17-character ID was set, a resend of
  `PAYMENT.CAPTURE.COMPLETED` (`WH-1C8720305V179940B-2Y2905661P2307307`) at
  18:15:16 UTC left `/v1/health` at `webhookFailures: 0`, so the signature
  passed. PayPal still marked that delivery `FAIL_SOFT`: the spike order is
  not in Firestore, and the `collectionGroup('orders')` fallback in
  `locateOrder` errors (plan Task 10).

## OpenAI

- **`gpt-5.5` read Little Bao House correctly in production (2026-10-20)**,
  through the hosted *Try a sample bill*: 10 lines, Lager x3 as qty 3 /
  £16.50, the 12.5% service charge (£17.19) found, and a total of £154.69
  with no blocking question. One receipt, one model; not the full spike.
- **Receipt model spike (plan Task 7), run 2026-10-21** with
  `api/test/extract-receipt.live.test.ts` against the four sample receipts.
  Times are per receipt, in ms:

  | Model | Little Bao House | Brunch (discount) | Pub (no service) | Long curry (2 photos) | Result |
  |---|---|---|---|---|---|
  | `gpt-5.5` | 5109, 10 lines, £154.69 | 3264, £53.77 | 2684, £88.30 | 4492, 18 lines, £193.84 | **4/4 clean** |
  | `gpt-5.4-mini` | 2523, clean | 2078, clean | 2098, clean | 2278, **20 lines** | 3/4: counted the photo overlap twice, "Items add up to £214.74 but the bill says £193.84" |
  | `gpt-5-mini` | 14286, clean | 25065, clean | 11932, clean | 21162, clean | 4/4 clean, 3–8× slower |

  All three read Lager x3 as qty 3 / 1650. **`OPENAI_VISION_MODEL` stays
  pinned to `gpt-5.5`**: the only model both correct on all four and fast.
  `gpt-5.4-mini`'s miss was caught by the add-up check, as designed, but it
  would block the organiser on every long bill.

## Still unverified

- How often the sweeps really run. Scheduled runs started firing on
  2026-10-20 (20:52, 21:31, 23:41, 00:31 UTC, all green), but roughly hourly,
  not every 10 minutes: GitHub throttles cron on quiet repos. Reconcile may
  need a tighter trigger once payments are live.
