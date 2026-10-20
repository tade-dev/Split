# Sample receipts

Fictional bills, hand-written as HTML and rendered to PNG with
`scripts/render-receipts.mjs`. Every one adds up exactly, so a correct read
raises no ambiguity: anything Split flags on these is a misread.

| Receipt | What it exercises | Printed total |
|---|---|---|
| `little-bao-house.png` | The canonical demo bill (`samples/demo-split.json`): quantities like "Lager x3", a 12.5% service charge | £154.69 |
| `brunch-discount.png` | A percentage discount taken off, no service charge | £53.77 |
| `pub-no-service.png` | No service, no discount, multi-quantity rounds | £88.30 |
| `long-curry-part1.png` + `long-curry-part2.png` | One long bill in two photos. Dal makhani and Saag paneer appear in both, and must be counted once (18 lines) | £193.84 |

Change the HTML, never the PNG, and re-render. Check any total you change
by hand: these are test inputs, so an arithmetic slip reads as a model failure.
