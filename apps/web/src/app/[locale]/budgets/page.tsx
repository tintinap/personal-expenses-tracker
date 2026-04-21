export default function BudgetsPage() {
  return (
    <div className="page">
      <header className="page__header">
        <h1 className="page__title">Budgets</h1>
        <p className="page__subtitle">Set spending limits and monitor progress</p>
      </header>
      <div className="page__content">
        <p className="card__empty">No budgets configured yet. Create your first budget to start tracking.</p>
      </div>
    </div>
  );
}
