import { describe, expect, it } from 'vitest';
import { CLAIM_SYSTEM, parseClaim, toClaimPreview, type ClaimContext } from '../src/ai/parse_claim.js';
import type { ClaimParse } from '../src/ai/schemas.js';
import type { ChatTransport } from '../src/ai/client.js';

const lines = [
  { id: 'lager-8', name: 'Lager', qty: 3, lineTotalMinor: 1650 },
  { id: 'nachos-2', name: 'Nachos', qty: 1, lineTotalMinor: 900 },
  { id: 'pork-bao-1', name: 'Pork bao', qty: 3, lineTotalMinor: 1800 },
];
const participants = [
  { id: 'kemi', name: 'Kemi' },
  { id: 'josh', name: 'Josh' },
  { id: 'amaka', name: 'Amaka' },
  { id: 'dan', name: 'Dan' },
];
const ctx = (over: Partial<ClaimContext> = {}): ClaimContext => ({
  lines,
  claims: {},
  participants,
  writer: { id: 'josh', name: 'Josh' },
  ...over,
});
const raw = (claims: ClaimParse['claims'], extra: Partial<ClaimParse> = {}): ClaimParse => ({ claims, ambiguities: [], ignored: [], ...extra });

describe('toClaimPreview', () => {
  it('drops a line id the receipt does not have, and says so', () => {
    const p = toClaimPreview(raw([{ lineId: 'ghost-9', participantId: 'josh', weight: 1 }]), ctx());
    expect(p.matched).toEqual([]);
    expect(p.problems).toEqual([expect.objectContaining({ kind: 'unclear', blocking: true })]);
  });

  it('turns a weight that is not whole into a question', () => {
    const p = toClaimPreview(raw([{ lineId: 'pork-bao-1', participantId: 'josh', weight: 1.5 }]), ctx());
    expect(p.problems).toEqual([expect.objectContaining({ kind: 'qty_unclear', field: 'claims.pork-bao-1' })]);
  });

  it("leaves out a friend's claim for someone else and tells them", () => {
    const p = toClaimPreview(raw([
      { lineId: 'lager-8', participantId: 'josh', weight: 1 },
      { lineId: 'pork-bao-1', participantId: 'dan', weight: 1 },
    ]), ctx());
    expect(p.matched.map((m) => [m.lineId, m.participantId])).toEqual([['lager-8', 'josh']]);
    expect(p.ignored).toEqual(["You can only claim for yourself, so Dan's pork bao was left out."]);
  });

  it('refuses two lagers when one is left', () => {
    const claims = { 'lager-8': { claims: [{ participantId: 'dan', weight: 2, source: 'friend' as const }], shared: false } };
    const p = toClaimPreview(raw([{ lineId: 'lager-8', participantId: 'josh', weight: 2 }]), ctx({ claims }));
    expect(p.matched).toEqual([]);
    expect(p.problems).toEqual([expect.objectContaining({ kind: 'qty_unclear', question: 'Only 1 lager is left to claim' })]);
  });

  it('gives "me and Amaka shared the nachos" weight 1 each, when the organiser writes it', () => {
    const p = toClaimPreview(raw([
      { lineId: 'nachos-2', participantId: 'josh', weight: 1 },
      { lineId: 'nachos-2', participantId: 'amaka', weight: 1 },
    ]), ctx({ writer: null }));
    expect(p.matched).toEqual([
      { lineId: 'nachos-2', participantId: 'josh', name: 'Nachos', weight: 1, portionLabel: '' },
      { lineId: 'nachos-2', participantId: 'amaka', name: 'Nachos', weight: 1, portionLabel: '' },
    ]);
    expect(p.problems).toEqual([]);
  });

  it('labels part of a line, and says when nothing matched', () => {
    const p = toClaimPreview(raw([{ lineId: 'lager-8', participantId: 'josh', weight: 1 }]), ctx());
    expect(p.matched[0]!.portionLabel).toBe('1 of 3');
    expect(toClaimPreview(raw([]), ctx()).problems).toEqual([
      expect.objectContaining({ question: "I couldn't match that to the bill. Try naming the dish." }),
    ]);
  });

  it('keeps the model\'s own questions, as blocking', () => {
    const p = toClaimPreview(raw([], {
      ambiguities: [{ field: 'claims', kind: 'unclear', question: 'The beef or the prawn ramen?', options: ['Beef ramen', 'Prawn ramen'], blocking: false }],
    }), ctx());
    expect(p.problems).toEqual([{ field: 'claims', kind: 'unclear', question: 'The beef or the prawn ramen?', options: ['Beef ramen', 'Prawn ramen'], blocking: true }]);
  });
});

describe('parseClaim', () => {
  it('sends the lines with what is left, the group, the writer and the message', async () => {
    let sent: { messages: { role: string; content: unknown }[] } | undefined;
    const transport: ChatTransport = async (body) => {
      sent = body as typeof sent;
      return { content: JSON.stringify(raw([{ lineId: 'lager-8', participantId: 'josh', weight: 1 }])) };
    };
    const claims = { 'lager-8': { claims: [{ participantId: 'dan', weight: 1, source: 'friend' as const }], shared: false } };
    const out = await parseClaim('a lager', ctx({ claims }), transport, 'm');
    expect(out.claims).toHaveLength(1);
    const text = JSON.stringify(sent);
    expect(text).toContain(JSON.stringify(CLAIM_SYSTEM).slice(1, -1));
    expect(text).toContain('\\"remaining\\":2');
    expect(text).toContain('\\"writer\\":{\\"id\\":\\"josh\\",\\"name\\":\\"Josh\\"}');
    expect(text).toContain('a lager');
  });
});
