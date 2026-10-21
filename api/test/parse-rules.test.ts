import { describe, expect, it } from 'vitest';
import { NOTHING_CAUGHT, RULES_SYSTEM, parseRules, toRulesPreview, type RulesContext } from '../src/ai/parse_rules.js';
import type { RulesParse } from '../src/ai/schemas.js';
import type { ChatTransport } from '../src/ai/client.js';
import { loadDemoSplit } from '../src/domain/demo.js';
import { DEFAULT_RULES } from '../src/domain/split.js';

const demo = loadDemoSplit();
const ctx = (over: Partial<RulesContext> = {}): RulesContext => ({
  receipt: demo.receipt,
  claims: demo.claims,
  rules: DEFAULT_RULES,
  participants: demo.participants,
  ...over,
});
const raw = (over: Partial<RulesParse> = {}): RulesParse => ({
  onUs: [], onUsPaidBy: null, serviceMode: null, serviceOptOut: [], confirmationText: 'ok?', ...over,
});

describe('toRulesPreview', () => {
  it("prices Sam's birthday from allocate(), not the model", () => {
    const p = toRulesPreview(raw({ onUs: ['sam'], confirmationText: 'Sam is on us for £5?' }), ctx());
    expect(p).toEqual({
      rules: { ...DEFAULT_RULES, onUs: ['sam'] },
      confirmationText: "Sam's share, £29.10, split between the other 4?",
      figureMinor: 2910,
    });
  });

  it('names who covers it when the message says', () => {
    const p = toRulesPreview(raw({ onUs: ['sam'], onUsPaidBy: ['kemi', 'josh'] }), ctx());
    expect(p!.confirmationText).toBe("Sam's share, £29.10, paid by Kemi and Josh?");
  });

  it('drops ids not in the group, and never puts the organiser on us', () => {
    const p = toRulesPreview(raw({ onUs: ['sam', 'ghost', 'kemi'], serviceOptOut: ['nobody'] }), ctx());
    expect(p!.rules.onUs).toEqual(['sam']);
    expect(p!.rules.serviceOptOut).toEqual([]);
  });

  it('returns null when nothing would change', () => {
    expect(toRulesPreview(raw(), ctx())).toBeNull();
    expect(toRulesPreview(raw({ onUs: ['ghost'] }), ctx())).toBeNull();
    expect(NOTHING_CAUGHT).toBe("I didn't catch a rule in that. Try 'Sam's on us'.");
  });

  it('words a service change and leaves the amount out when claims are not done', () => {
    expect(toRulesPreview(raw({ serviceMode: 'even' }), ctx())!.confirmationText).toBe('Split the service evenly?');
    const p = toRulesPreview(raw({ onUs: ['sam'] }), ctx({ claims: {} }));
    expect(p).toMatchObject({ confirmationText: "Sam's share split between the other 4?", figureMinor: null });
  });
});

describe('parseRules', () => {
  it('sends the group, the current rules and the message', async () => {
    let sent = '';
    const transport: ChatTransport = async (body) => {
      sent = JSON.stringify(body);
      return { content: JSON.stringify(raw({ onUs: ['sam'] })) };
    };
    const out = await parseRules("it's Sam's birthday so his is on us", ctx(), transport, 'm');
    expect(out.onUs).toEqual(['sam']);
    expect(sent).toContain(JSON.stringify(RULES_SYSTEM).slice(1, -1));
    expect(sent).toContain('Sam');
    expect(sent).toContain('birthday');
  });
});
