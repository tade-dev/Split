# Verified facts

Confirmed against live systems, not assumed, with the date. Re-verify if
something fails in a way that contradicts this. Sorted's own record, which
Split builds on, is `tade-dev/sorted` `docs/verified-facts.md` at `902dc25`.

## Deployment

Nothing deployed yet. See plan Tasks 13 (Render `split-api` on `starter`,
sweeps scheduled) and 21 (web build on Firebase Hosting).

## Firebase

No project yet. See plan Task 12. `app/lib/firebase_options.dart` is a
placeholder that throws until `flutterfire configure` runs.

## PayPal

Not yet verified for Split. See plan Task 14 (payee spike to a personal
sandbox account).

## OpenAI

Not yet verified for receipts. See plan Task 7: run
`api/test/extract-receipt.live.test.ts` once per candidate model and record a
row per model here. `OPENAI_VISION_MODEL` stays `gpt-5.5` (Sorted's pin,
verified 2026-10-04 for DM screenshots) until then.

## Still unverified

- That `split-api.onrender.com` is the real Render URL. It is the default in
  `api/src/env.ts`, `app/lib/core/env.dart` and `api/.env.example`.
- Whether PayPal accepts `payee.email_address` set to a personal sandbox
  account. Fallback: the shared sandbox merchant, stated in the README.
- Which model reads receipts reliably, and whether it reads "Lager x3 16.50"
  as qty 3 / 1650.
- Whether any PayPal webhook arrives for a payee order.
