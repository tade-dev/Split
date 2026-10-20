import { describe, expect, it } from 'vitest';
import { RECEIPT_SYSTEM, extractReceipt, remapLineField, toDraftReceipt } from '../src/ai/extract_receipt.js';
import type { ChatTransport } from '../src/ai/client.js';
import type { ReceiptExtraction } from '../src/ai/schemas.js';

const bao: ReceiptExtraction = {
  merchant: 'Little Bao House',
  receiptDate: '2026-10-02',
  lines: [
    { name: 'Prawn crackers', qty: 1, lineTotalMinor: 550 },
    { name: 'Lager', qty: 3, lineTotalMinor: 1650 },
  ],
  serviceChargeMinor: 275,
  serviceChargeLabel: '12.5% discretionary',
  tipMinor: null,
  discounts: [],
  printedTotalMinor: 2475,
  ambiguities: [],
};

const replying = (payload: unknown): ChatTransport & { bodies: unknown[] } => {
  const bodies: unknown[] = [];
  const t = (async (body: unknown) => { bodies.push(body); return { content: JSON.stringify(payload) }; }) as ChatTransport & { bodies: unknown[] };
  t.bodies = bodies;
  return t;
};

const png = { buffer: Buffer.from('x'), mime: 'image/png' };

describe('extractReceipt', () => {
  it('sends the spec prompt, every image, and no temperature', async () => {
    const t = replying(bao);
    await extractReceipt([png, png], t, 'm');
    const body = t.bodies[0] as { messages: { content: unknown }[]; temperature?: number };
    expect(JSON.stringify(body.messages[0])).toContain("not three lines");
    expect((body.messages[1]!.content as { type: string }[]).filter((p) => p.type === 'image_url')).toHaveLength(2);
    expect(body.temperature).toBeUndefined();
    expect(RECEIPT_SYSTEM).toContain('Never compute or correct a total');
  });

  it('refuses no images or more than two', async () => {
    await expect(extractReceipt([], replying(bao), 'm')).rejects.toThrow();
    await expect(extractReceipt([png, png, png], replying(bao), 'm')).rejects.toThrow();
  });
});

describe('toDraftReceipt', () => {
  it('gives lines stable ids and a receipt that adds up raises nothing', () => {
    const { receipt, ambiguities } = toDraftReceipt(bao);
    expect(receipt.lines.map((l) => l.id)).toEqual(['prawn-crackers-0', 'lager-1']);
    expect(receipt.lines[1]).toMatchObject({ qty: 3, lineTotalMinor: 1650 });
    expect(receipt.tipMinor).toBe(0);
    expect(ambiguities).toEqual([]);
  });

  it('blocks a bill that does not add up, naming both numbers', () => {
    const { ambiguities } = toDraftReceipt({ ...bao, printedTotalMinor: 15469 });
    expect(ambiguities).toEqual([expect.objectContaining({
      kind: 'price_conflict', blocking: true,
      question: 'Items add up to £24.75 but the bill says £154.69. Check the photo or edit a line.',
    })]);
  });

  it('blocks an unread price and an unread total', () => {
    const lines = [{ name: 'Lager', qty: 3, lineTotalMinor: null }];
    expect(toDraftReceipt({ ...bao, lines }).ambiguities[0]).toMatchObject({ kind: 'missing', field: 'lines.lager-0.lineTotalMinor', blocking: true });
    expect(toDraftReceipt({ ...bao, printedTotalMinor: null }).ambiguities[0]).toMatchObject({ kind: 'missing', field: 'printedTotalMinor' });
  });

  it("keeps the model's own questions, as notes that do not block", () => {
    const { ambiguities } = toDraftReceipt({
      ...bao,
      ambiguities: [{ field: 'lines[1].qty', kind: 'qty_unclear', question: 'Is that 3 lagers or 2?', options: ['3', '2'], blocking: true }],
    });
    expect(ambiguities).toEqual([expect.objectContaining({ field: 'lines.lager-1.qty', blocking: false })]);
  });

  it('drops a model note a derived problem already covers', () => {
    const { ambiguities } = toDraftReceipt({
      ...bao,
      printedTotalMinor: null,
      ambiguities: [{ field: 'printedTotalMinor', kind: 'missing', question: 'Total unreadable', options: [], blocking: true }],
    });
    expect(ambiguities.filter((a) => a.field === 'printedTotalMinor')).toHaveLength(1);
    expect(ambiguities[0]!.blocking).toBe(true);
  });

  it('remaps the model\'s line positions to ids and leaves other fields alone', () => {
    const lines = [{ id: 'a-0' }, { id: 'b-1' }];
    expect(remapLineField('lines[1].lineTotalMinor', lines)).toBe('lines.b-1.lineTotalMinor');
    expect(remapLineField('lines[9].qty', lines)).toBe('lines[9].qty');
    expect(remapLineField('serviceChargeMinor', lines)).toBe('serviceChargeMinor');
  });
});
