# Dashboard Revamp & FAB Redesign

## 1. Intent & Scope
Redesign the Mobile App's core navigation and home screen interaction by elevating the Floating Action Button, consolidating the metrics visuals into the Home screen, creating an interactive detailed dashboard viewer, and introducing a direct deletion capability for logged transactions.

## 2. Architecture & Top-Level Router
*   **Remove Reports:** Delete the standalone `/reports` route and tab from `app_router.dart` and `ScaffoldWithNavBar`.
*   **New Dashboard Detail:** Inject a new nested route `/dashboard-detail` natively underneath the root `/` Home shell route. Because it resides inside the `ShellRoute`, navigating to it guarantees the bottom tab bar continues to overlay smoothly without disappearing.

## 3. UI Components & Navigational Flow

### 3.1 The 4-Tab Notched Nav Bar
*   Replace standard flat `NavigationBar` with a core Flutter `BottomAppBar`.
*   Implement `shape: const CircularNotchedRectangle()`.
*   Balance out the layout: 2 `IconButton` links (Home, Wallets) → Spacer (The Notch gap) → 2 `IconButton` links (Budgets, Settings).

### 3.2 The Home Screen Mini-Dashboard
*   Extract the static Donut Chart and insert a compact, tappable variation onto `HomeScreen.dart`.
*   Wrap it in an `InkWell` or `GestureDetector` hooked up to `context.go('/dashboard-detail')`.

### 3.3 Dashboard Detail Page (New Screen)
*   Create `DashboardDetailScreen`.
*   Include the `PeriodSelector` globally governing the timeline of data viewed.
*   Render the prominent categorical Donut Chart.
*   Beneath the chart, map through all categories and provide togglable filtered checkboxes. The Donut Chart natively responds to standard state changes when these filters are selectively checked off/on.

### 4. Transaction Deletion Capability
*   **UI Integration:** Implement an `IconButton` shaped as a prominent Red Trash Can positioned top-right within the `TransactionBottomSheet` (Visible exclusively if `widget.initialTransaction != null`).
*   **Database Transaction:** 
    1. Await confirmation prompt (optional buffer but highly recommended).
    2. Invoke `transactionDao.deleteTransaction(transaction.id)`.
    3. Generate a `syncQueue` record parameterized with `operation: 'delete'`.
    4. Force exactly `Navigator.pop(context)` immediately.
