import type { CSSProperties } from 'react';

export const theme = {
  gold: '#D4AF37',
  goldLight: '#E8C874',
  deepBlack: '#0A0A0F',
  surface: '#12121A',
  surfaceElevated: '#181825',
  textPrimary: '#F5F0E6',
  textSecondary: '#9A948A',
  success: '#4AE8A0',
  error: '#E84A4A',
} as const;

export const fonts = {
  playfair: "'Playfair Display', serif",
  inter: "'Inter', sans-serif",
} as const;

export function playfair(size: number, weight: number, color = theme.textPrimary): CSSProperties {
  return { fontFamily: fonts.playfair, fontSize: size, fontWeight: weight, color };
}

export function inter(size: number, weight: number, color = theme.textPrimary, letterSpacing?: number): CSSProperties {
  return { fontFamily: fonts.inter, fontSize: size, fontWeight: weight, color, letterSpacing };
}

export function naira(amount: number): string {
  return `\u20A6${amount.toLocaleString('en-NG')}`;
}
