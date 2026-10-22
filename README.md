# Split

> Snap the bill. Everyone pays their bit.

**Live demo:** https://split-b66c0.web.app

**API health:** https://split-api-k5ai.onrender.com/v1/health

After a group meal, the person who paid photographs the receipt. Split reads every line and service charge and checks they add up to the printed total. Friends say what they had in plain words from a link, with no app to install. Code, not the AI, works out each share to the penny, and each friend pays their share by PayPal straight to the organiser.

Split is the sister app to [Sorted](https://github.com/tade-dev/sorted) and reuses its design system, motion layer, API shell, AI seam and PayPal pipeline. [docs/reused-from-sorted.md](docs/reused-from-sorted.md) lists every file that came from it.

## Try it as a judge

You can play every part on your own:

1. Open the [live demo](https://split-b66c0.web.app). You are signed in as **Kemi**, an organiser.
2. Tap **Try a sample bill**. Split reads the Little Bao House receipt and checks it adds up to £154.69.
3. Add a few friends, then tap **Ask everyone what they had**.
4. On the claims screen, type what each friend had, for example "Dan had the bao buns and a Tsingtao". Friends do the same from their own links.
5. Tap **Totals**, then **Send links**. Every share is worked out to the penny.
6. On the tracker, open Dan's row menu, pick **Preview as Dan**, and pay with the sandbox buyer below. Dan's row on the tracker flips to **Paid** without a reload.

From the tracker you can also:

- **Nudge** a friend with a drafted reminder.
- **Mark as paid in cash**.
- **Cancel** the split.

Tap your avatar on Home to set the name friends see and your PayPal email.

### PayPal sandbox

No real money moves. Pay as this sandbox buyer:

| | |
|---|---|
| Email | `jeho@gmail.com` |
| Password | `12345678` |

With no PayPal email set in Settings, payments go to Split's sandbox merchant. Set a sandbox **personal** account email there and the money lands in that account instead ([verified](docs/verified-facts.md)).

## How it works

[docs/architecture.md](docs/architecture.md) has the data-flow diagram, the share lifecycle and the data model. In short:

- **The model reads; code counts.** Vision reads the receipt; text models turn "I had the bao" into claims and "Sam's on us" into rules. Every amount comes from `api/src/domain/allocate.ts`: largest remainder, a golden fixture and property tests. A bill that does not add up to its printed total cannot be sent.
- **Friends need no app.** Each friend gets a signed link to a server-rendered page where they say what they had, confirm, and pay.
- **Money goes straight to the organiser.** It uses PayPal Orders v2 with the organiser as payee. The return page captures the order, with the webhook and a reconcile sweep as backups, and the tracker updates live from Firestore.

## Repo layout

| Path | What it is |
|---|---|
| `app/` | Flutter app for the organiser (iOS, Android, web) |
| `api/` | Node + TypeScript backend, for Render |
| `samples/` | The demo bill (`demo-split.json`) and four sample receipts |
| `docs/` | Design spec, screens, implementation plans, verified facts |

## Running locally

```bash
# API: needs api/.env (see api/.env.example) and JDK 21+ for the emulator
cd api && npm ci
npm run emulators      # in one terminal
npm test               # in another
npm run dev

# App
cd app && flutter pub get && flutter test
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

## Licence

MIT. See [LICENSE](LICENSE).
