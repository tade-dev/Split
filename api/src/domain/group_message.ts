/**
 * The ready-to-paste text the organiser drops in the group chat (spec §4,
 * endpoint 8): one line saying what the bill was, then each friend's link.
 *
 *   Friday dinner at Little Bao House. Tap your link and say what you had:
 *   Amaka: https://…/v1/s/…
 */
export function groupMessage(
  split: { title: string; merchant: string | null },
  links: { name: string; url: string }[],
): string {
  const what = split.merchant ? `${split.title} at ${split.merchant}` : split.title;
  return [`${what}. Tap your link and say what you had:`, ...links.map((l) => `${l.name}: ${l.url}`)].join('\n');
}
