import type { Metadata } from 'next';
import { Sidebar } from '@/components/sidebar';

export const metadata: Metadata = {
  title: 'Dashboard — DailySpend',
  description: 'Overview of your expenses, budgets, and currency wallets.',
};

type Props = {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
};

export default async function DashboardLayout({ children, params }: Props) {
  const { locale } = await params;

  return (
    <div className="app-shell">
      <Sidebar locale={locale} />
      <main className="app-shell__main">
        {children}
      </main>
    </div>
  );
}
