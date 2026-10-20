import { receiptExtractionSchema, type Ambiguity, type ReceiptExtraction } from './schemas.js';
import { generateStructured, toDataUri, type ChatTransport } from './client.js';
import { lineIdFor, receiptProblems } from '../domain/receipt.js';
import type { Receipt } from '../domain/split.js';

/** Spec §7.1, plus the units the schema needs spelled out. */
export const RECEIPT_SYSTEM = [
  'You read a UK restaurant or bar receipt.',
  'Return every purchased line exactly as printed with its quantity and line total in pence (GBP 16.50 is 1650).',
  'Return the service charge, tip, discounts and the printed total separately. Discount amounts are positive numbers of pence taken off.',
  "A line like 'Lager x3 16.50' is qty 3 with a line total of 1650, not three lines.",
  'If two images are given, they are parts of one long receipt: join them and do not double-count the overlap.',
  'If a value is unreadable, return null and add an ambiguity. Refer to a line by its position from 0, as lines[3].',
  'Never compute or correct a total; report what is printed.',
  'If the image is not a receipt, return no lines and a null total.',
].join(' ');

const nullableInt = { type: ['integer', 'null'] };

export const RECEIPT_JSON_SCHEMA: Record<string, unknown> = {
  type: 'object',
  additionalProperties: false,
  required: [
    'merchant', 'receiptDate', 'lines', 'serviceChargeMinor', 'serviceChargeLabel',
    'tipMinor', 'discounts', 'printedTotalMinor', 'ambiguities',
  ],
  properties: {
    merchant: { type: ['string', 'null'] },
    receiptDate: { type: ['string', 'null'], description: 'ISO date, YYYY-MM-DD' },
    lines: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['name', 'qty', 'lineTotalMinor'],
        properties: { name: { type: 'string' }, qty: { type: 'integer' }, lineTotalMinor: nullableInt },
      },
    },
    serviceChargeMinor: nullableInt,
    serviceChargeLabel: { type: ['string', 'null'] },
    tipMinor: nullableInt,
    discounts: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['label', 'amountMinor'],
        properties: { label: { type: 'string' }, amountMinor: { type: 'integer' } },
      },
    },
    printedTotalMinor: nullableInt,
    ambiguities: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['field', 'kind', 'question', 'options', 'blocking'],
        properties: {
          field: { type: 'string' },
          kind: { type: 'string', enum: ['missing', 'unclear', 'price_conflict', 'qty_unclear'] },
          question: { type: 'string' },
          options: { type: 'array', items: { type: 'string' } },
          blocking: { type: 'boolean' },
        },
      },
    },
  },
};

export async function extractReceipt(
  images: { buffer: Buffer; mime: string }[],
  transport: ChatTransport,
  model: string,
): Promise<ReceiptExtraction> {
  if (images.length < 1 || images.length > 2) throw new Error('extractReceipt takes one or two images');
  return generateStructured(
    {
      schemaName: 'receipt_extraction',
      schema: receiptExtractionSchema,
      jsonSchema: RECEIPT_JSON_SCHEMA,
      system: RECEIPT_SYSTEM,
      ...(images.length === 2 ? { text: 'These are two parts of one long receipt, top part first.' } : {}),
      images: images.map((i) => toDataUri(i.buffer, i.mime)),
    },
    transport,
    model,
  );
}

/**
 * The draft receipt and its ambiguities. Code checks the arithmetic: the
 * model's own questions are kept as non-blocking notes, and every blocking
 * problem (an unread price, an unread total, a bill that does not add up) is
 * derived from the numbers by receiptProblems().
 */
export function toDraftReceipt(extraction: ReceiptExtraction): { receipt: Receipt; ambiguities: Ambiguity[] } {
  const lines = extraction.lines.map((l, i) => ({
    id: lineIdFor(l.name, i),
    name: l.name.trim(),
    qty: l.qty,
    lineTotalMinor: l.lineTotalMinor,
  }));
  const receipt: Receipt = {
    lines,
    serviceChargeMinor: extraction.serviceChargeMinor ?? 0,
    serviceChargeLabel: extraction.serviceChargeLabel,
    tipMinor: extraction.tipMinor ?? 0,
    discounts: extraction.discounts,
    printedTotalMinor: extraction.printedTotalMinor,
    currency: 'GBP',
  };
  const derived = receiptProblems(receipt);
  const notes = extraction.ambiguities
    .map((a) => ({ ...a, field: remapLineField(a.field, lines), blocking: false }))
    .filter((a) => !derived.some((d) => d.field === a.field));
  return { receipt, ambiguities: [...derived, ...notes] };
}

/** The model says `lines[3].qty`; Split's fields name lines by id. */
export function remapLineField(field: string, lines: { id: string }[]): string {
  const m = /^lines\[(\d+)\](.*)$/.exec(field);
  if (!m) return field;
  const line = lines[Number(m[1])];
  return line ? `lines.${line.id}${m[2]}` : field;
}
