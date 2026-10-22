import { nudgeDraftSchema } from './schemas.js';
import { generateStructured, type ChatTransport } from './client.js';
import { formatGbp } from '../domain/money.js';

/** Nudge.dc.html's three chips. */
export type NudgeTone = 'friendly' | 'cheeky' | 'firm';

export const NUDGE_TONES: readonly NudgeTone[] = ['friendly', 'cheeky', 'firm'];

// Spec §7.4: Sorted's nudge, re-prompted for a friend.
export const NUDGE_SYSTEM = [
  'You write a friendly reminder to a friend about their share of a group bill, sent by the friend who paid the bill.',
  'Write as the organiser, casually, the way friends text each other. UK English.',
  'Under 40 words. Never guilt-trip, pressure, shame or threaten. It is a friend, not a debt.',
  'Say what it is for and the amount, exactly as given.',
  'Include the link exactly once, exactly as given, with nothing appended to it. Do not invent, shorten or wrap any link.',
  'No HTML or markdown. At most one emoji.',
  'Do not mention anything that is not in the details given.',
  'If this is not the first reminder, keep it lighter still and make it easy: whenever suits them.',
  'Set recommendChannel to manual_copy: the organiser pastes this into the chat themselves.',
  'Set shouldSkip to true only if chasing now would clearly be wrong from the details given (for example, they opened the link moments ago); otherwise false, with skipReason null.',
].join(' ');

export const NUDGE_JSON_SCHEMA: Record<string, unknown> = {
  type: 'object',
  additionalProperties: false,
  required: ['text', 'recommendChannel', 'shouldSkip', 'skipReason'],
  properties: {
    text: { type: 'string' },
    recommendChannel: { type: 'string', enum: ['paypal_invoice', 'manual_copy'] },
    shouldSkip: { type: 'boolean' },
    skipReason: { type: ['string', 'null'] },
  },
};

const TONE_GUIDANCE: Record<NudgeTone, string> = {
  friendly: 'Tone: warm and chatty.',
  cheeky: 'Tone: playful and teasing, the way close friends wind each other up. Still kind.',
  firm: 'Tone: clear and direct, still friendly. Ask them to sort it when they can.',
};

export type NudgeInput = {
  friend: string;
  organiser: string;
  /** The split's title, e.g. "Friday dinner". */
  title: string;
  merchant: string | null;
  amountMinor: number;
  /** The friend's own share link. */
  link: string;
  tone: NudgeTone;
  /** How many nudges have already gone out. */
  priorCount: number;
  /** Whole days since the links went out. */
  daysUnpaid: number;
  /** The friend opened their link within the last hour. */
  openedRecently: boolean;
};

export type DraftedNudge = {
  text: string;
  /** 'ai' when the model's text passed every check, 'template' otherwise. */
  source: 'ai' | 'template';
  shouldSkip: boolean;
  skipReason: string | null;
};

function amountForms(minor: number): string[] {
  const full = formatGbp(minor);
  return full.endsWith('.00') ? [full, full.slice(0, -3)] : [full];
}

/**
 * Why a model draft cannot be pasted, or null if it can. A nudge with the
 * wrong link is worse than none: the friend cannot pay, and the organiser
 * looks careless at the exact moment they are asking for money.
 */
export function nudgeProblem(text: string, link: string, amountMinor: number): string | null {
  if (!text.trim()) return 'empty';
  if (text.length > 500) return 'too long';
  if (/<[a-z/!][^>]*>/i.test(text)) return 'markup';
  if (text.split(link).length - 1 !== 1) return 'link not exactly once';
  const others = text.split(link).join(' ').match(/https?:\/\/\S+|www\.\S+/gi);
  if (others) return 'extra link';
  if (!amountForms(amountMinor).some((a) => text.includes(a))) return 'amount missing';
  return null;
}

const firstName = (name: string) => name.trim().split(/\s+/)[0] || 'there';

/** Used whenever the model cannot write a nudge that passes. Same facts, plainer words. */
export function fallbackNudge(input: Pick<NudgeInput, 'friend' | 'title' | 'merchant' | 'amountMinor' | 'link' | 'tone' | 'priorCount'>): string {
  const { link, tone, priorCount } = input;
  const who = firstName(input.friend);
  const what = input.merchant ? `${input.title} at ${input.merchant}` : input.title;
  const amount = formatGbp(input.amountMinor);
  const easy = priorCount > 0 ? ' No rush, whenever suits.' : '';
  const opener = tone === 'firm'
    ? `Hi ${who}, your ${amount} for ${what} is still outstanding.`
    : tone === 'cheeky'
      ? `Oi ${who}! ${what} isn't going to pay for itself 😄 Your bit's ${amount}.`
      : `Hey ${who}! Your bit for ${what} is ${amount}.`;
  return `${opener} Here's your link: ${link}${easy}`;
}

/**
 * Drafts a nudge. Never throws: a model failure, or a draft that fails the
 * checks above, falls back to the template, so the organiser always has
 * something correct to paste.
 */
export async function draftNudge(input: NudgeInput, transport: ChatTransport, model: string): Promise<DraftedNudge> {
  const { link, tone, amountMinor } = input;
  const fallback = (): DraftedNudge => ({
    text: fallbackNudge(input),
    source: 'template',
    shouldSkip: false,
    skipReason: null,
  });

  const details = [
    `Friend: ${input.friend}`,
    `From: ${input.organiser}, who paid the bill`,
    `It is for: ${input.title}${input.merchant ? ` at ${input.merchant}` : ''}`,
    `Their share: ${formatGbp(amountMinor)}`,
    `Unpaid for: ${input.daysUnpaid} day${input.daysUnpaid === 1 ? '' : 's'}`,
    `Reminders already sent: ${input.priorCount}`,
    input.openedRecently ? 'They opened their link within the last hour.' : '',
    `Their link, to include verbatim: ${link}`,
  ].filter(Boolean).join('\n');

  const system = `${NUDGE_SYSTEM}\n\n${TONE_GUIDANCE[tone]}\n\nDetails:\n${details}`;

  try {
    const drafted = await generateStructured(
      {
        schemaName: 'nudge_draft',
        schema: nudgeDraftSchema,
        jsonSchema: NUDGE_JSON_SCHEMA,
        system,
        text: 'Write the reminder.',
      },
      transport,
      model,
    );
    const text = drafted.text.trim();
    if (nudgeProblem(text, link, amountMinor) !== null) {
      return { ...fallback(), shouldSkip: drafted.shouldSkip, skipReason: drafted.skipReason };
    }
    return { text, source: 'ai', shouldSkip: drafted.shouldSkip, skipReason: drafted.skipReason };
  } catch {
    return fallback();
  }
}
