import { describe, expect, it } from 'vitest';
import { shareSignature, shareUrl, verifyShareSignature } from '../src/domain/links.js';

const SECRET = 'link-secret';

describe('share link signatures', () => {
  it('is stable and 32 base64url characters', () => {
    const sig = shareSignature(SECRET, 'kemi', 'split1', 'dan');
    expect(sig).toBe(shareSignature(SECRET, 'kemi', 'split1', 'dan'));
    expect(sig).toMatch(/^[A-Za-z0-9_-]{32}$/);
  });

  it('verifies its own signature and rejects any change', () => {
    const sig = shareSignature(SECRET, 'kemi', 'split1', 'dan');
    expect(verifyShareSignature(SECRET, 'kemi', 'split1', 'dan', sig)).toBe(true);
    expect(verifyShareSignature(SECRET, 'kemi', 'split1', 'josh', sig)).toBe(false);
    expect(verifyShareSignature(SECRET, 'kemi', 'split2', 'dan', sig)).toBe(false);
    expect(verifyShareSignature('other', 'kemi', 'split1', 'dan', sig)).toBe(false);
    expect(verifyShareSignature(SECRET, 'kemi', 'split1', 'dan', sig.slice(0, 31))).toBe(false);
    expect(verifyShareSignature(SECRET, 'kemi', 'split1', 'dan', `${sig}x`)).toBe(false);
    expect(verifyShareSignature(SECRET, '../x', 'split1', 'dan', sig)).toBe(false);
  });

  it('builds a URL that carries a signature it verifies', () => {
    const url = shareUrl('https://api.example.com', SECRET, 'kemi', 'split1', 'dan');
    const sig = url.split('/').pop()!;
    expect(url).toBe(`https://api.example.com/v1/s/kemi/split1/dan/${sig}`);
    expect(verifyShareSignature(SECRET, 'kemi', 'split1', 'dan', sig)).toBe(true);
  });
});
