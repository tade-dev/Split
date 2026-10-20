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

- **`api/render.yaml` is on `plan: free` (decided 2026-10-20)**, because
  `starter` asks for a payment method before the Blueprint will create. This
  departs from spec §4 / risk 6. Move to `starter` (or apply the hackathon's
  Render credits) before PayPal payments go live in Week B: a sleeping
  service drops webhooks and cannot run the sweeps.

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

Not yet verified for Split. See plan Task 14 (payee spike to a personal
sandbox account).

## OpenAI

- **`gpt-5.5` read Little Bao House correctly in production (2026-10-20)**,
  through the hosted *Try a sample bill*: 10 lines, Lager x3 as qty 3 /
  £16.50, the 12.5% service charge (£17.19) found, and a total of £154.69
  with no blocking question. One receipt, one model; not the full spike.
- The full spike (plan Task 7) is still to run: `api/test/extract-receipt.live.test.ts`
  once each for `gpt-5.5`, `gpt-5.4-mini` and `gpt-5-mini`, one row per model
  here. It needs `OPENAI_API_KEY` in `api/.env`. `OPENAI_VISION_MODEL` stays
  `gpt-5.5` until then.

## Still unverified

- That the sweeps' cron schedule fires. Only the manual run is proven. Check
  `gh run list --workflow sweeps.yml` for `schedule` events.
- Whether PayPal accepts `payee.email_address` set to a personal sandbox
  account. Fallback: the shared sandbox merchant, stated in the README.
- Which model reads all four sample receipts reliably (only `gpt-5.5` on
  Little Bao House is proven).
- Whether any PayPal webhook arrives for a payee order.
