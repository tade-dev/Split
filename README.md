# Split

> Snap the bill. Everyone pays their bit.

**Live demo:** https://split-b66c0.web.app

**API health:** https://split-api-k5ai.onrender.com/v1/health

After a group meal, the person who paid photographs the receipt. Split reads every line and service charge and checks they add up to the printed total. Friends say what they had in plain words from a link, with no app to install. Code, not the AI, works out each share to the penny, and each friend pays their share by PayPal straight to the organiser.

Split is the sister app to [Sorted](https://github.com/tade-dev/sorted) and reuses its design system, motion layer, API shell, AI seam and PayPal pipeline. [docs/reused-from-sorted.md](docs/reused-from-sorted.md) lists every file that came from it.

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
