import { readFileSync, existsSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { makeOpenAiTransport } from '../src/ai/client.js';
import { parseClaim, toClaimPreview, type ClaimContext } from '../src/ai/parse_claim.js';
import { loadDemoSplit } from '../src/domain/demo.js';
import { loadEnv } from '../src/env.js';

const envFile = existsSync('.env') ? readFileSync('.env', 'utf8') : '';
const key = envFile.match(/^OPENAI_API_KEY=(.+)$/m)?.[1]?.trim();
const model = envFile.match(/^OPENAI_VISION_MODEL=(.+)$/m)?.[1]?.trim();
const ready = Boolean(key) && Boolean(model) && model !== 'pending';

describe.skipIf(!ready)('parseClaim against the real model', () => {
  // See ai-client.live.test.ts: leave before loadEnv when there is no key.
  if (!ready) return;

  const env = loadEnv({
    NODE_ENV: 'test',
    PAYPAL_CLIENT_ID: 'x', PAYPAL_CLIENT_SECRET: 'x', PAYPAL_WEBHOOK_ID: 'x',
    OPENAI_API_KEY: key!, OPENAI_VISION_MODEL: model!,
    FIREBASE_PROJECT_ID: 'x', INTERNAL_TOKEN: 'x', LINK_SECRET: 'link-secret',
  });
  const transport = makeOpenAiTransport(env);
  const demo = loadDemoSplit();
  const ctx = (writer: string | null): ClaimContext => ({
    lines: demo.receipt.lines,
    claims: {},
    participants: demo.participants.map((p) => ({ id: p.id, name: p.name })),
    writer: writer ? { id: writer, name: demo.participants.find((p) => p.id === writer)!.name } : null,
  });
  const run = async (message: string, writer: string | null) => {
    const c = ctx(writer);
    return toClaimPreview(await parseClaim(message, c, transport, env.OPENAI_VISION_MODEL), c);
  };
  const pairs = (p: Awaited<ReturnType<typeof run>>) => p.matched.map((m) => [m.lineId, m.participantId, m.weight]);

  it('reads the video line', async () => {
    const p = await run('spicy ramen, a lager and one of the bao', 'josh');
    expect(pairs(p)).toEqual(expect.arrayContaining([
      ['spicy-miso-ramen-5', 'josh', 1], ['lager-8', 'josh', 1], ['pork-bao-1', 'josh', 1],
    ]));
    expect(p.matched).toHaveLength(3);
  }, 60_000);

  it('splits a shared dish between the writer and a friend', async () => {
    const organiser = await run('Josh and Amaka shared the prawn crackers', null);
    expect(pairs(organiser)).toEqual(expect.arrayContaining([['prawn-crackers-0', 'josh', 1], ['prawn-crackers-0', 'amaka', 1]]));
    expect(organiser.matched).toHaveLength(2);
    const josh = await run('me and Amaka shared the prawn crackers', 'josh');
    expect(pairs(josh)).toEqual([['prawn-crackers-0', 'josh', 1]]);
    expect(josh.ignored.length).toBeGreaterThan(0);
  }, 60_000);

  it('asks rather than guessing which ramen', async () => {
    const p = await run('the ramen', 'dan');
    expect(p.matched).toEqual([]);
    expect(p.problems.length).toBeGreaterThan(0);
  }, 60_000);
});
