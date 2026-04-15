// Root layout — minimal shell that delegates to [locale]/layout.tsx
// This file is required by Next.js but should NOT set lang or provide i18n.

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return children;
}
