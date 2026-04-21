export default function SettingsPage() {
  return (
    <div className="page">
      <header className="page__header">
        <h1 className="page__title">Settings</h1>
        <p className="page__subtitle">Manage your account, preferences, and data export</p>
      </header>
      <div className="page__content">
        <section className="settings-section">
          <h2 className="settings-section__title">Account</h2>
          <p className="card__empty">Sign in with Google or Apple to enable cloud sync.</p>
        </section>
        <section className="settings-section">
          <h2 className="settings-section__title">Preferences</h2>
          <div className="settings-row">
            <span>Base Currency</span>
            <span className="settings-row__value">AUD</span>
          </div>
          <div className="settings-row">
            <span>Theme</span>
            <span className="settings-row__value">System</span>
          </div>
        </section>
        <section className="settings-section">
          <h2 className="settings-section__title">Export</h2>
          <button className="btn btn--primary" id="export-excel-btn">Export as Excel (.xlsx)</button>
        </section>
      </div>
    </div>
  );
}
