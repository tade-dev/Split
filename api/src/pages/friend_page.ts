import { escapeHtml } from '../paypal/buyer_page.js';
import { formatGbp, type Minor } from '../domain/money.js';
import type { ParticipantDoc, SplitDoc } from '../domain/splits.js';

/**
 * Everything a friend's page can show, decided from the split and the
 * participant alone (spec §4, friend pages). Rendering is a pure function of
 * this, so each state is tested without Firestore.
 */
export type FriendView =
  | { kind: 'gone' }
  | { kind: 'cancelled'; organiser: string }
  | { kind: 'claim'; name: string; organiser: string; merchant: string | null; totalMinor: Minor | null; lines: { name: string; qty: number; minor: Minor | null }[]; action: string; pickHref: string }
  | { kind: 'claimed'; name: string; organiser: string; mine: { label: string; minor: Minor | null }[]; changeHref: string }
  | { kind: 'preview'; name: string; matched: { lineId: string; label: string; weight: number }[]; notes: string[]; message: string; action: string; pickHref: string; retryHref: string }
  | { kind: 'pick'; name: string; lines: { lineId: string; label: string; qty: number; weight: number }[]; notes: string[]; action: string }
  | { kind: 'pay'; name: string; organiser: string; title: string; shareMinor: Minor; rows: { label: string; minor: number }[]; action: string }
  | { kind: 'processing'; organiser: string }
  | { kind: 'paid'; organiser: string }
  | { kind: 'on_us' };

/** What this participant has claimed, as the page lists it: "Lager, 1 of 3". */
function myLines(split: SplitDoc, participantId: string): { label: string; minor: Minor | null }[] {
  const computed = split.computed?.ok ? split.computed.perParticipant[participantId] : undefined;
  const out: { label: string; minor: Minor | null }[] = [];
  for (const line of split.receipt.lines) {
    const entry = split.claims[line.id];
    const weight = (entry?.claims ?? []).filter((c) => c.participantId === participantId).reduce((t, c) => t + c.weight, 0);
    if (weight === 0) continue;
    const label = weight >= line.qty && (entry?.claims.length ?? 0) === 1 ? line.name : `${line.name}, ${weight} of ${line.qty}`;
    out.push({ label, minor: computed?.lines.find((l) => l.lineId === line.id)?.minor ?? null });
  }
  return out;
}

/** The FriendPay rows: what they had, then what the group's rules add. */
function payRows(split: SplitDoc, participantId: string): { label: string; minor: number }[] {
  const b = split.computed?.ok ? split.computed.perParticipant[participantId] : undefined;
  if (!b) return [];
  const service = split.receipt.serviceChargeLabel ? `Service charge, ${split.receipt.serviceChargeLabel}` : 'Service charge';
  // "Spicy miso ramen, lager, pork bao", as FriendPay lists them.
  const names = b.lines.map((l) => split.receipt.lines.find((r) => r.id === l.lineId)?.name).filter((n): n is string => Boolean(n));
  const had = names.length === 0 ? 'What you had' : names.map((n, i) => (i === 0 ? n : n.toLowerCase())).join(', ');
  return [
    { label: had, minor: b.itemsMinor },
    { label: 'Your share of what is on the group', minor: b.sharedFromOnUsMinor },
    { label: service, minor: b.serviceMinor },
    { label: 'Tip', minor: b.tipMinor },
    { label: 'Discount', minor: -b.discountMinor },
  ].filter((r) => r.minor !== 0);
}

/** The checklist: every line with this person's current weight on it. */
export function pickView(split: SplitDoc, participant: ParticipantDoc, selfPath: string, notes: string[] = []): FriendView {
  return {
    kind: 'pick',
    name: participant.name,
    lines: split.receipt.lines.map((l) => ({
      lineId: l.id,
      label: l.name,
      qty: l.qty,
      weight: (split.claims[l.id]?.claims ?? []).filter((c) => c.participantId === participant.id).reduce((t, c) => t + c.weight, 0),
    })),
    notes,
    action: `${selfPath}/claim/confirm`,
  };
}

export function friendView(split: SplitDoc, participant: ParticipantDoc, organiser: string, selfPath: string, opts: { pick?: boolean } = {}): FriendView {
  if (split.status === 'cancelled') return { kind: 'cancelled', organiser };
  if (split.status === 'draft') return { kind: 'gone' };
  if (participant.status === 'paid' || participant.status === 'paid_cash') return { kind: 'paid', organiser };
  if (participant.status === 'on_us') return { kind: 'on_us' };
  if (split.status === 'claiming') {
    if (opts.pick) return pickView(split, participant, selfPath);
    if (participant.status === 'claimed') {
      return { kind: 'claimed', name: participant.name, organiser, mine: myLines(split, participant.id), changeHref: `${selfPath}?pick=1` };
    }
    return {
      kind: 'claim',
      name: participant.name,
      organiser,
      merchant: split.merchant,
      totalMinor: split.receipt.printedTotalMinor,
      lines: split.receipt.lines.map((l) => ({ name: l.name, qty: l.qty, minor: l.lineTotalMinor })),
      action: `${selfPath}/claim`,
      pickHref: `${selfPath}?pick=1`,
    };
  }
  if (split.status === 'collecting' && (participant.status === 'processing' || participant.status === 'pending')) {
    return { kind: 'processing', organiser };
  }
  if (split.status === 'collecting' && participant.shareMinor !== null) {
    return {
      kind: 'pay',
      name: participant.name,
      organiser,
      title: split.title,
      shareMinor: participant.shareMinor,
      rows: payRows(split, participant.id),
      action: `${selfPath}/pay`,
    };
  }
  // Settled with nothing owed by this person, or a state the page has no
  // words for yet: say nothing is needed rather than guess at money.
  return { kind: 'paid', organiser };
}

const notes = (lines: string[]) => lines.map((n) => `<p class="note">${escapeHtml(n)}</p>`).join('');
const money = (minor: number) => (minor < 0 ? `−${formatGbp(-minor as Minor)}` : formatGbp(minor as Minor));
const possessive = (name: string) => `${name}${name.endsWith('s') ? "'" : "'s"}`;

function body(view: FriendView): { title: string; html: string } {
  switch (view.kind) {
    case 'gone':
      return { title: "This link doesn't work", html: `<h1>This link doesn't work</h1><p>Ask whoever sent it for a fresh one.</p>` };
    case 'cancelled':
      return {
        title: 'This bill was cancelled',
        html: `<h1>This bill was cancelled</h1><p>${escapeHtml(view.organiser)} cancelled it, so there is nothing to pay.</p>`,
      };
    case 'claim': {
      const where = view.merchant ? ` at ${escapeHtml(view.merchant)}` : '';
      const paid = view.totalMinor === null ? `${escapeHtml(view.organiser)} paid the bill${where}` : `${escapeHtml(view.organiser)} paid ${formatGbp(view.totalMinor)}${where}`;
      const lines = view.lines
        .map((l) => `<li><span>${l.qty > 1 ? `${l.qty} × ` : ''}${escapeHtml(l.name)}</span><span>${l.minor === null ? '' : formatGbp(l.minor)}</span></li>`)
        .join('');
      return {
        title: `What did you have, ${view.name}?`,
        html: `<p class="lede">Opened from ${escapeHtml(possessive(view.organiser))} link. No app needed.</p>
  <p>${paid}.</p>
  <h1>What did you have, ${escapeHtml(view.name)}?</h1>
  <form method="post" action="${escapeHtml(view.action)}">
    <label for="message" class="sr">What you had</label>
    <textarea id="message" name="message" rows="3" maxlength="500" placeholder="spicy ramen, a lager and one of the bao" required></textarea>
    <button type="submit">Check it against the bill</button>
  </form>
  <p><a href="${escapeHtml(view.pickHref)}">Pick from the bill instead</a></p>
  <h2>On the bill</h2>
  <ul class="rows">${lines}</ul>`,
      };
    }
    case 'claimed': {
      const rows = view.mine.map((l) => `<li><span>${escapeHtml(l.label)}</span><span>${l.minor === null ? '' : formatGbp(l.minor)}</span></li>`).join('');
      return {
        title: 'Waiting for everyone else',
        html: `<h1>Waiting for everyone else</h1>
  <p>You said what you had, ${escapeHtml(view.name)}. ${escapeHtml(view.organiser)} sends your share once everyone has.</p>
  <ul class="rows">${rows}</ul>
  <p><a href="${escapeHtml(view.changeHref)}">Change what I had</a></p>`,
      };
    }
    case 'preview': {
      const rows = view.matched.map((m) => `<li><span>${escapeHtml(m.label)}</span></li>`).join('');
      const hidden = view.matched.map((m) => `<input type="hidden" name="w_${escapeHtml(m.lineId)}" value="${m.weight}">`).join('');
      const confirm = view.matched.length > 0
        ? `<form method="post" action="${escapeHtml(view.action)}">${hidden}<input type="hidden" name="message" value="${escapeHtml(view.message)}"><button type="submit">That's right</button></form>`
        : '';
      return {
        title: 'Split matched this to the bill',
        html: `<p class="lede">${escapeHtml(view.message)}</p>
  <h1>${view.matched.length > 0 ? 'Split matched this to the bill' : 'Not quite'}</h1>
  ${notes(view.notes)}
  ${view.matched.length > 0 ? `<ul class="rows">${rows}</ul>` : ''}
  <p class="lede">Your share of anything shared, and the service, is added once everyone has claimed.</p>
  ${confirm}
  <p><a href="${escapeHtml(view.retryHref)}">Try saying it again</a> · <a href="${escapeHtml(view.pickHref)}">Pick from the bill instead</a></p>`,
      };
    }
    case 'pick': {
      const rows = view.lines
        .map((l) => `<li><label for="w_${escapeHtml(l.lineId)}">${escapeHtml(l.label)}</label><input id="w_${escapeHtml(l.lineId)}" name="w_${escapeHtml(l.lineId)}" type="number" inputmode="numeric" min="0" max="${l.qty}" value="${l.weight}"></li>`)
        .join('');
      return {
        title: `What did you have, ${view.name}?`,
        html: `<h1>What did you have, ${escapeHtml(view.name)}?</h1>
  <p>Put how many of each you had. Leave the rest at 0.</p>
  ${notes(view.notes)}
  <form method="post" action="${escapeHtml(view.action)}">
    <ul class="rows pick">${rows}</ul>
    <button type="submit">That's what I had</button>
  </form>`,
      };
    }
    case 'pay': {
      const rows = view.rows.map((r) => `<li><span>${escapeHtml(r.label)}</span><span>${money(r.minor)}</span></li>`).join('');
      return {
        title: `Your share, ${view.name}`,
        html: `<p class="lede">${escapeHtml(view.title)}, from ${escapeHtml(view.organiser)}</p>
  <h1>Your share, ${escapeHtml(view.name)}</h1>
  <p class="amount">${formatGbp(view.shareMinor)}</p>
  <ul class="rows">${rows}</ul>
  <p>Goes straight to ${escapeHtml(view.organiser)} through PayPal, so you both get a record and ${escapeHtml(view.organiser)} sees it the moment you pay.</p>
  <form method="post" action="${escapeHtml(view.action)}">
    <button type="submit">Pay ${formatGbp(view.shareMinor)} with PayPal</button>
  </form>`,
      };
    }
    case 'processing':
      return { title: 'PayPal is confirming it', html: `<h1>PayPal is confirming it</h1><p>${escapeHtml(view.organiser)} sees it as soon as it clears.</p>` };
    case 'paid':
      return { title: 'Paid', html: `<h1>Paid. Thanks</h1><p>${escapeHtml(view.organiser)}'s been told.</p>` };
    case 'on_us':
      return { title: 'On the group', html: `<h1>This one's on the group</h1><p>Nothing for you to pay.</p>` };
  }
}

export function friendPage(view: FriendView): string {
  const { title, html } = body(view);
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="no-referrer">
<meta name="robots" content="noindex">
<title>${escapeHtml(title)}</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:wght@700&amp;family=Plus+Jakarta+Sans:wght@400;600&amp;display=swap">
<style>
  body { margin: 0; background: #F5F7FA; color: #001C64; font-family: "Plus Jakarta Sans", sans-serif; }
  main { max-width: 28rem; margin: 0 auto; padding: 3rem 1.25rem 3rem; }
  .mark { margin: 0 0 1.5rem; font-weight: 600; font-size: 0.875rem; letter-spacing: 0.04em; color: #0070E0; }
  .lede { color: #515A6B; font-size: 0.875rem; }
  h1 { margin: 0.5rem 0 0; font-family: "Bricolage Grotesque", sans-serif; font-weight: 700; font-size: 1.75rem; letter-spacing: -0.03em; line-height: 1.25; }
  h2 { margin: 2rem 0 0.5rem; font-size: 1rem; }
  p { margin: 1rem 0 0; color: #515A6B; font-size: 1rem; line-height: 1.5; }
  .amount { margin: 0.5rem 0 0; color: #001C64; font-family: "Bricolage Grotesque", sans-serif; font-size: 2.5rem; font-weight: 700; }
  .rows { list-style: none; margin: 1rem 0 0; padding: 0.25rem 1rem; background: #FFFFFF; border: 1px solid #E3E8EF; border-radius: 18px; }
  .rows li { display: flex; justify-content: space-between; gap: 1rem; padding: 0.6rem 0; border-bottom: 1px solid #E3E8EF; }
  .rows li:last-child { border-bottom: 0; }
  .rows li span:last-child { font-weight: 600; white-space: nowrap; }
  form { margin: 1.25rem 0 0; }
  textarea { box-sizing: border-box; width: 100%; padding: 0.875rem; border: 1px solid #E3E8EF; border-radius: 16px; font: inherit; color: inherit; background: #FFFFFF; }
  button { width: 100%; min-height: 54px; margin-top: 0.75rem; border: 0; border-radius: 16px; background: #0070E0; color: #FFFFFF; font: 600 1.0625rem "Plus Jakarta Sans", sans-serif; cursor: pointer; }
  .note { padding: 0.75rem 1rem; background: #FFF6E0; border-radius: 14px; color: #6B4A00; }
  .pick input { width: 4rem; padding: 0.4rem; border: 1px solid #E3E8EF; border-radius: 10px; font: inherit; text-align: center; }
  .sr { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
</style>
</head>
<body>
<main>
  <p class="mark">Split</p>
  ${html}
</main>
</body>
</html>
`;
}
