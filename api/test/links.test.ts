import { describe, expect, it } from 'vitest';
import {
  invoiceSignature,
  invoiceUrl,
  verifyInvoiceSignature,
} from '../src/domain/links.js';

const SECRET = 'invoice-secret';

describe('link signatures', () => {
  it('verifies its own signature and rejects others', () => {
    const sig = invoiceSignature(SECRET, 's', 'o');
    expect(verifyInvoiceSignature(SECRET, 's', 'o', sig)).toBe(true);
    expect(verifyInvoiceSignature(SECRET, 's', 'o2', sig)).toBe(false);
    expect(verifyInvoiceSignature('other', 's', 'o', sig)).toBe(false);
    expect(verifyInvoiceSignature(SECRET, 's', 'o', 'short')).toBe(false);
    expect(verifyInvoiceSignature(SECRET, '../x', 'o', sig)).toBe(false);
  });

  it('builds a URL that carries a signature it verifies', () => {
    const url = invoiceUrl('https://api.example.com', SECRET, 'organiser-a', 'order123abc');
    const sig = url.split('/').pop()!;
    expect(url).toBe(`https://api.example.com/v1/invoice/organiser-a/order123abc/${sig}`);
    expect(verifyInvoiceSignature(SECRET, 'organiser-a', 'order123abc', sig)).toBe(true);
  });
});
