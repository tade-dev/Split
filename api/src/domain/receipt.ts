import type { Ambiguity } from '../ai/schemas.js';
import { formatGbp, type Minor } from './money.js';
import type { Receipt } from './split.js';

/** `Lager x3` at index 8 becomes `lager-x3-8`. Stable while the line keeps its place. */
export function lineIdFor(name: string, index: number): string {
  const slug = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 40);
  return `${slug || 'line'}-${index}`;
}

/**
 * Lines + service + tip − discounts, or null while any line price is unread.
 * This is what the printed total has to equal.
 */
export function receiptSumMinor(receipt: Receipt): number | null {
  let sum = receipt.serviceChargeMinor + receipt.tipMinor;
  for (const line of receipt.lines) {
    if (line.lineTotalMinor === null) return null;
    sum += line.lineTotalMinor;
  }
  for (const d of receipt.discounts) sum -= d.amountMinor;
  return sum;
}

/**
 * Everything about the receipt itself that blocks a split. Derived from the
 * receipt every time, so fixing the receipt is what clears them: there is no
 * stored "resolved" flag to fall out of step.
 */
export function receiptProblems(receipt: Receipt): Ambiguity[] {
  const problems: Ambiguity[] = [];
  // One copy for a bill the model found nothing on and a bill typed in from
  // blank (spec Q2): either way the organiser is the one who adds the items.
  if (receipt.lines.length === 0) {
    problems.push({
      field: 'lines',
      kind: 'missing',
      question: 'Add the items on the bill.',
      options: [],
      blocking: true,
    });
  }
  for (const line of receipt.lines) {
    if (line.lineTotalMinor === null) {
      problems.push({
        field: `lines.${line.id}.lineTotalMinor`,
        kind: 'missing',
        question: `What did the ${line.name} cost? Split could not read the price.`,
        options: [],
        blocking: true,
      });
    }
  }
  if (receipt.printedTotalMinor === null) {
    problems.push({
      field: 'printedTotalMinor',
      kind: 'missing',
      question: "What's the total on the bill?",
      options: [],
      blocking: true,
    });
    return problems;
  }
  if (receipt.lines.length === 0) return problems;
  const sum = receiptSumMinor(receipt);
  if (sum !== null && sum !== receipt.printedTotalMinor) {
    problems.push({
      field: 'printedTotalMinor',
      kind: 'price_conflict',
      question:
        sum < 0
          ? `The discounts come to more than the bill, which says ${formatGbp(receipt.printedTotalMinor)}. Check the photo or edit a line.`
          : `Items add up to ${formatGbp(sum as Minor)} but the bill says ${formatGbp(receipt.printedTotalMinor)}. Check the photo or edit a line.`,
      options: [],
      blocking: true,
    });
  }
  return problems;
}
