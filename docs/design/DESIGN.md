# Split: Design Spec

The visual source of truth for **Split**, the sister app to Sorted. It uses the same design system: same tokens, same type, same motion rules. Anything not listed here works exactly as in Sorted's `docs/design/DESIGN.md` and `app/lib/core/theme/`.

- `screens/` holds one HTML file per screen (390×844). Read them for layout, spacing, copy and colour. They are references to rebuild as Flutter widgets, not code to port.
- Ignore the `<script src="./support.js">`, `<x-dc>`, `<helmet>` and `data-dc-script` wrappers. They belong to the design tool.
- `FriendLink.dc.html` and `FriendPay.dc.html` are **not Flutter screens**. They are the API's server-rendered friend pages, built with the same tokens.
- Names and numbers (Kemi, Little Bao House, £154.69, Dan £39.23) are the seeded demo split. Keep them as seed data, never as strings in widgets. The figures are exactly what `allocate()` produces for the golden fixture in the spec.

---

## Tokens

Identical to Sorted. Copy `sorted_colors.dart`, `sorted_shape.dart` and `sorted_theme.dart`, renamed to `split_*`.

| Token | Hex | Use |
|---|---|---|
| `background` | `#F5F7FA` | App background |
| `surface` | `#FFFFFF` | Cards, inputs |
| `ink` | `#001C64` | Primary text, dark cards, selected chips, organiser's outgoing chat bubble |
| `muted` | `#515A6B` | Secondary text |
| `line` | `#DCE2EA` | Borders, dividers |
| `primary` | `#0070E0` | Primary buttons, progress, organiser's chat bubble on Claim |
| `primaryTint` | `#E6F0FC` | Info cards ("Or share one link", PayPal protection note) |
| `success` / `successTint` | `#147A47` / `#E3F4EA` | Paid, Settled, "Adds up to the bill" |
| `highlight` | `#FFC439` | Scan frame, gold accents |
| `warningTint` / `warningText` / `warningBorder` | `#FFF4D6` / `#7A5200` / `#F1D27A` | Anything the AI needs the organiser to decide |
| `neutralTint` | `#EBEEF3` | Progress track, system chips in the claim chat |
| `darkBg` / `darkSurface` / `darkTrack` / `darkLink` | `#00123F` / `#0B2A78` / `#0F3488` / `#123C96` | Scan screen, Home summary card, link chip in bubbles |
| `onDarkMuted` / `accentCyan` | `#B9C8EE` / `#60CDFF` | Text and progress on dark surfaces |

### New: participant colours

Add a `participants` list to `SplitColors`. Each entry is a fill and the text that sits on it. Assign in join order. The organiser always gets the first.

| # | Fill | Text |
|---|---|---|
| 0 | `#FFC439` | `#3D2B00` |
| 1 | `#FF9F80` | `#4A1A0A` |
| 2 | `#9DBEFF` | `#0A2560` |
| 3 | `#7AD9AE` | `#063D26` |
| 4 | `#D6B0FF` | `#3A1466` |
| 5–7 | choose three more at the same lightness, distinct from 0–4 | dark text at 4.5:1 |

A person's colour follows their items everywhere: receipt dots, avatar, claim card tint (fill at 20% with a 1 px fill border), breakdown row, tracker row. That is Split's signature. Never use colour alone for meaning: avatars always carry the initial, and claim cards say "Added to Amaka".

### Type

Bricolage Grotesque for wordmark, headings and money. Plus Jakarta Sans for everything else. Bundle the same static weights as Sorted. The friend pages load both from Google Fonts, as Sorted's buyer page does.

---

## Components

**Reused from Sorted (renamed):** PrimaryButton, CompactButton, SelectableChip, SegmentedControl, WarningCard, Skeleton set, Toast, AppBar, Icon set, MoneyRoll, ReplyBubble (for nudges and the group message), PressScale, Reveal, EnterStagger, PaidPop.

**New:**

- **Avatar**: circle with the initial, participant fill and text, sizes 24/30/36/40/44. In stacks, a 2 px ring in the background colour behind each, overlapping −8 px.
- **ItemDots**: row of 10 px participant dots after a receipt line, showing who had it.
- **ClaimCard**: under a chat message, tinted in the claimant's colour, with a tick, "Added to {name}" and the lines with their amounts ("Lager, 2 of 3 · £11.00").
- **ProgressHeader**: 8 px track, `primary` fill, "9 of 10 items claimed".
- **ShareStatusPill**: adapted from Sorted's StatusPill. Invited (neutral), Claimed (blue), Waiting (warning), Paid (success), Paid in cash (success, outlined), Birthday / On us (neutral). The same morph animation.
- **SummaryCard**: the dark Home card with the amount back, "of £118.26 back", the progress bar in `accentCyan` and the avatar stack.
- **SettledStamp**: Sorted's stamp, saying "Settled". One of the two uses of the bouncy spring. The other is PaidPop on a tracker row.

---

## Screens and flow

1. `Main.dc.html`: Welcome, first run only.
2. `Home.dc.html`: Active split card, needs-you card, Settled list, Split a new bill. Add a **Try a sample bill** row for judges (not drawn).
3. `Scan.dc.html`: Camera, or file picker on web.
4. *(Reading, not drawn)*: Reuse Sorted's Reading screen pattern with receipt steps.
5. `Receipt.dc.html`: Check the bill, service charge choice, total.
6. `People.dc.html`: Who was there. Names are typed (the "Add from contacts" field becomes "Add a name" in v1).
7. `Claim.dc.html`: Group claim chat with ClaimCards, unclaimed warning, composer, Totals.
8. `Rules.dc.html`: Shared items, on-us toggle, service charge.
9. `Breakdown.dc.html`: Who owes what, add-up check, Send links.
10. `Tracker.dc.html`: Live payment tracking, Nudge, Preview as Dan, Settled stamp.
11. `Nudge.dc.html`: Drafted reminder.
12. `FriendLink.dc.html` → **server page**: "What did you have, Dan?" and the matched preview.
13. `FriendPay.dc.html` → **server page**: Your share and Pay with PayPal.

Use no PayPal logo or imitation PayPal buttons in custom UI. Wherever the PayPal checkout itself appears, use PayPal's official assets.
