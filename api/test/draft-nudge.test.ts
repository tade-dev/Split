import { describe, expect, it, vi } from 'vitest';
import { NUDGE_SYSTEM, draftNudge, fallbackNudge, nudgeProblem, type NudgeInput } from '../src/ai/draft_nudge.js';
import type { ChatTransport } from '../src/ai/client.js';

const link = 'https://split-api-k5ai.onrender.com/v1/s/kemi/s1/dan/sig';

function said(text: string, extra: Record<string, unknown> = {}): ChatTransport {
  return async () => ({
    content: JSON.stringify({ text, recommendChannel: 'manual_copy', shouldSkip: false, skipReason: null, ...extra }),
  });
}

const input: NudgeInput = {
  friend: 'Dan', organiser: 'Kemi', title: 'Friday dinner', merchant: 'Little Bao House',
  amountMinor: 3923, link, tone: 'friendly', priorCount: 0, daysUnpaid: 2, openedRecently: false,
};

describe('nudgeProblem', () => {
  it('passes a reminder with the link once and the amount', () => {
    expect(nudgeProblem(`Hey Dan! Your £39.23 for Friday: ${link}`, link, 3923)).toBeNull();
    expect(nudgeProblem(`Hey Dan! £20 for Friday: ${link}`, link, 2000)).toBeNull();
  });

  it.each([
    ['', 'empty'],
    [`£39.23, pay here: ${link} or ${link}`, 'link not exactly once'],
    ['£39.23, pay here: https://paypal.example/other', 'link not exactly once'],
    [`£39.23 ${link} and www.example.com`, 'extra link'],
    [`<b>£39.23</b> ${link}`, 'markup'],
    [`Pay here: ${link}`, 'amount missing'],
    [`£39.23 ${link} ${'x'.repeat(500)}`, 'too long'],
  ])('refuses %j (%s)', (text, problem) => {
    expect(nudgeProblem(text, link, 3923)).toBe(problem);
  });
});

describe('fallbackNudge', () => {
  it('says who, what, how much and the link', () => {
    expect(fallbackNudge(input)).toBe(`Hey Dan! Your bit for Friday dinner at Little Bao House is £39.23. Here's your link: ${link}`);
  });

  it('passes its own checks, whatever the tone', () => {
    for (const tone of ['friendly', 'cheeky', 'firm'] as const) {
      for (const priorCount of [0, 1]) {
        expect(nudgeProblem(fallbackNudge({ ...input, tone, priorCount }), link, 3923)).toBeNull();
      }
    }
  });
});

describe('draftNudge', () => {
  it("uses the model's reminder when it passes", async () => {
    const text = `Hey Dan! Friday was class. Your bit for Little Bao House is £39.23: ${link}`;
    expect(await draftNudge(input, said(text), 'm')).toEqual({ text, source: 'ai', shouldSkip: false, skipReason: null });
  });

  it('tells the model the facts, the link, the tone and the guardrails', async () => {
    const transport = vi.fn<ChatTransport>().mockResolvedValue({
      content: JSON.stringify({ text: `£39.23 ${link}`, recommendChannel: 'manual_copy', shouldSkip: false, skipReason: null }),
    });
    await draftNudge({ ...input, tone: 'cheeky', priorCount: 1, openedRecently: true }, transport, 'm');
    const body = JSON.stringify(transport.mock.calls[0]![0]);
    expect(body).toContain(link);
    expect(body).toContain('£39.23');
    expect(body).toContain('Friday dinner at Little Bao House');
    expect(body).toContain('Reminders already sent: 1');
    expect(body).toContain('playful');
    expect(body).toContain('opened their link within the last hour');
    expect(NUDGE_SYSTEM).toMatch(/Never guilt-trip/);
    expect(NUDGE_SYSTEM).toMatch(/Under 40 words/);
  });

  it('falls back to the template when the model mangles the link', async () => {
    const out = await draftNudge(input, said('£39.23, pay here: https://paypal.example/made-up'), 'm');
    expect(out.source).toBe('template');
    expect(out.text).toBe(fallbackNudge(input));
  });

  it('falls back to the template when the model is down', async () => {
    const down: ChatTransport = async () => { throw new Error('503'); };
    expect(await draftNudge(input, down, 'm')).toEqual({ text: fallbackNudge(input), source: 'template', shouldSkip: false, skipReason: null });
  });

  it('passes on a model that would rather not chase, with something correct to paste anyway', async () => {
    const out = await draftNudge(input, said('', { shouldSkip: true, skipReason: 'Dan opened the link minutes ago.' }), 'm');
    expect(out.shouldSkip).toBe(true);
    expect(out.skipReason).toBe('Dan opened the link minutes ago.');
    expect(out.text).toBe(fallbackNudge(input));
  });
});
