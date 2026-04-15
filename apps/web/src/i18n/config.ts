// ============================================================
// i18n Configuration — supported locales and default locale
// ============================================================

export const locales = ['en', 'th'] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = 'en';
