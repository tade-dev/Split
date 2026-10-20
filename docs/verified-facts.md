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
- **Sweeps are scheduled from GitHub Actions (verified 2026-10-20).**
  `.github/workflows/sweeps.yml` calls `reconcile` every 10 minutes and
  `expire-sweep` and `nudge-sweep` hourly at :07, with the repo secret
  `INTERNAL_TOKEN`. The first manual run
  (https://github.com/tade-dev/Split/actions/runs/39466628528) returned 200
  with zero counts from all three: `{"checked":0,"promoted":0,"failed":0}`,
  `{"scanned":0,"expired":0,"kept":0,"failed":0}`,
  `{"scanned":0,"nudged":0,"skipped":0}`. The first call took ~35s, which is
  the free plan waking from sleep. The idle-wake check (Task 13 step 4) waits
  for `starter`.
- **Web build is live at `https://split-b66c0.web.app` (verified
  2026-10-20).** Built with Flutter 3.47.2 and
  `--dart-define=API_BASE_URL=https://split-api-k5ai.onrender.com`, then
  deployed with `firebase deploy --only hosting --project split-b66c0`
  (Hosting config in `firebase.json`). The smoke test from plan Task 21 passed
  on a phone in a private window: Home with "Hi Kemi" and the Little Bao House
  card, *Try a sample bill* through Reading to a Receipt at £154.69 with no
  warning, the add-up warning appearing and clearing on a Lager edit, and Evenly
  surviving a reload.

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
- Firestore location: not recorded here yet. Check it in the console under
  Firestore → Databases.
- The API's Admin SDK credentials (`FIREBASE_SERVICE_ACCOUNT_JSON`) are not
  set up yet. That happens with Render, plan Task 13.

## PayPal

Not yet verified for Split. See plan Task 14 (payee spike to a personal
sandbox account).

## OpenAI

Not yet verified for receipts. See plan Task 7: run
`api/test/extract-receipt.live.test.ts` once per candidate model and record a
row per model here. `OPENAI_VISION_MODEL` stays `gpt-5.5` (Sorted's pin,
verified 2026-10-04 for DM screenshots) until then.

## Still unverified

- That bootstrap works end to end against `split-b66c0`: it needs the API
  running with a service account (plan Task 13).

- Whether PayPal accepts `payee.email_address` set to a personal sandbox
  account. Fallback: the shared sandbox merchant, stated in the README.
- Which model reads receipts reliably, and whether it reads "Lager x3 16.50"
  as qty 3 / 1650.
- Whether any PayPal webhook arrives for a payee order.
