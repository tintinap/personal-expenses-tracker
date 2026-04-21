export default function WalletsPage() {
  return (
    <div className="page">
      <header className="page__header">
        <h1 className="page__title">Currency Wallets</h1>
        <p className="page__subtitle">Track your balances across currencies</p>
      </header>
      <div className="page__content">
        <section className="card">
          <h2 className="card__label">Total Portfolio Value</h2>
          <p className="card__value card__value--large">$0.00 AUD</p>
        </section>
        <p className="card__empty">No currency balances yet. Add a currency income to get started.</p>
      </div>
    </div>
  );
}
