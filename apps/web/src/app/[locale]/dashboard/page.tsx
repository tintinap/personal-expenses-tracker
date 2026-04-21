export default function DashboardPage() {
  return (
    <div className="dashboard">
      <header className="dashboard__header">
        <h1 className="dashboard__title">Dashboard</h1>
        <p className="dashboard__subtitle">Your financial overview at a glance</p>
      </header>

      <div className="dashboard__grid">
        {/* Summary card — total spend */}
        <section className="card card--summary" id="total-spend-card">
          <h2 className="card__label">Total spent this month</h2>
          <p className="card__value card__value--large">$0.00</p>
          <span className="card__badge card__badge--neutral">AUD</span>
        </section>

        {/* Budget progress card */}
        <section className="card card--budget" id="budget-progress-card">
          <h2 className="card__label">Budget remaining</h2>
          <p className="card__value card__value--large">—</p>
          <div className="progress-bar">
            <div className="progress-bar__fill" style={{ width: '0%' }} />
          </div>
        </section>

        {/* Currency wallets preview */}
        <section className="card card--wallets" id="currency-wallets-card">
          <h2 className="card__label">Currency Wallets</h2>
          <div className="wallet-chips">
            <span className="wallet-chip">🇦🇺 AUD $0.00</span>
          </div>
        </section>

        {/* Recent transactions */}
        <section className="card card--transactions" id="recent-transactions-card">
          <h2 className="card__label">Recent Transactions</h2>
          <p className="card__empty">No transactions yet. Tap + to add your first expense.</p>
        </section>
      </div>
    </div>
  );
}
