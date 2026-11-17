import { describe, expect, it } from 'vitest';
import { foregroundBounds, validateProductImage } from '../src/utils/productImage';

describe('product image preparation', () => {
  it('rejects unsupported, empty and oversized input before loading the model', () => {
    expect(() => validateProductImage({ type: 'image/svg+xml', size: 20 })).toThrow('JPG');
    expect(() => validateProductImage({ type: 'image/png', size: 0 })).toThrow('5 MB');
    expect(() => validateProductImage({ type: 'image/png', size: 5 * 1024 * 1024 + 1 })).toThrow(
      '5 MB',
    );
    for (const type of ['image/png', 'image/jpeg', 'image/webp'])
      expect(() => validateProductImage({ type, size: 5 * 1024 * 1024 })).not.toThrow();
  });

  it('crops to the product without including almost transparent background noise', () => {
    const pixels = new Uint8ClampedArray(6 * 5 * 4);
    pixels[(1 * 6 + 2) * 4 + 3] = 255;
    pixels[(3 * 6 + 4) * 4 + 3] = 128;
    pixels[3] = 8;
    expect(foregroundBounds(pixels, 6, 5)).toEqual({ left: 2, top: 1, width: 3, height: 3 });
  });

  it('preserves a product touching image edges', () => {
    const pixels = new Uint8ClampedArray(3 * 2 * 4).fill(255);
    expect(foregroundBounds(pixels, 3, 2)).toEqual({ left: 0, top: 0, width: 3, height: 2 });
  });

  it('rejects a result containing no foreground instead of saving a blank image', () => {
    expect(() => foregroundBounds(new Uint8ClampedArray(16), 2, 2)).toThrow('Không nhận diện');
  });
});
