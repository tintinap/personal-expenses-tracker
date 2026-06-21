# Phase 1 Design: Nav Restructure + Reports + Cleanup

**Status:** Approved  
**Created:** 2026-05-16  
**Approach:** A — Scaffold-Level Shared AppBar  

## Overview

Implement Phase 1 from the remaining-tasks execution plan:
- **T1:** Move Settings from bottom nav to AppBar gear icon (shared across all tabs)
- **T2:** Add full Reports tab + screen with charts
- **T3:** Remove orphan files and dead code
- **T4:** Remove unused `OptionalAuthGuard` from backend

---

## 1. Navigation Restructure (T1 + T2 nav)

### Architecture

`ScaffoldWithNavBar` owns the full `Scaffold` including `AppBar`, body, and `BottomAppBar`. Child screens become body-only widgets (no own Scaffold).

### Key Changes

| Component | Before | After |
|-----------|--------|-------|
| `ScaffoldWithNavBar` | Only provides BottomAppBar + FAB | Owns full Scaffold: AppBar (title + gear icon) + body + BottomAppBar + FAB |
| Child screens | Each returns `Scaffold(appBar: ..., body: ...)` | Returns body content only (no Scaffold wrapper) |
| AppBar title | Hardcoded per screen | Derived from route location in ScaffoldWithNavBar |
| Settings tab | Bottom nav tab at index 3 | Removed from bottom nav; accessed via gear icon. Route becomes non-shell full-screen route |
| Reports tab | Does not exist | New tab at index 3 (replacing Settings) |
| Bottom nav items | Home, Wallets, Budgets, Settings | Home, Wallets, Budgets, Reports |
| `/settings` route | ShellRoute child | Top-level GoRoute (non-shell) with back button |

### Title Resolution

```dart
static String _resolveTitle(BuildContext context) {
  final location = GoRouterState.of(context).uri.path;
  if (location == '/' || location.startsWith('/dashboard-detail')) return 'DailySpend';
  if (location.startsWith('/wallets')) return 'Wallets';
  if (location.startsWith('/budgets')) return 'Budgets';
  if (location.startsWith('/reports')) return 'Reports';
  return 'DailySpend';
}
```

### Edge Cases

- HomeScreen currently has `account_circle` icon → removed (gear icon in shared AppBar replaces it)
- `/dashboard-detail` is a child of `/` inside ShellRoute → still works, title shows "DailySpend"
- Settings sub-routes (`/settings/categories`) render full-screen with own AppBar + back button
- `SignInBanner` on HomeScreen stays in screen body, unaffected

---

## 2. Reports Screen (T2)

### File Structure

```
features/reports/
├── screens/
│   └── reports_screen.dart          # Main screen (body-only, no Scaffold)
├── widgets/
│   ├── spend_bar_chart.dart         # Daily spend bar chart (fl_chart)
│   ├── spend_trend_line_chart.dart  # Rolling spend trend line chart (fl_chart)
│   ├── period_comparison_card.dart  # This vs previous period card
│   └── category_spend_list.dart     # Category list with amount + %
└── providers/
    └── reports_providers.dart       # All Reports-specific providers
```

### New Providers

| Provider | Type | Input | Output |
|----------|------|-------|--------|
| `previousPeriodTransactionsProvider` | `StreamProvider<List<TransactionData>>` | Computes previous period from `selectedPeriodProvider` | Transactions in previous period |
| `dailySpendAggregateProvider` | `Provider<Map<DateTime, double>>` | `transactionListProvider` (expenses, base currency) | Day → total spend |
| `categorySpendProvider` | `Provider<List<CategorySpend>>` | `transactionListProvider` + `categoryListProvider` | Sorted list of {name, colour, amount, percentage} |
| `trendSpendProvider` | `Provider<List<TrendPoint>>` | `transactionListProvider` | Cumulative daily spend points |
| `periodComparisonProvider` | `Provider<PeriodComparison>` | Current + previous period transactions | {currentTotal, previousTotal, absoluteDiff, percentDiff} |

### Screen Layout (scrollable, top to bottom)

1. **PeriodSelector** — reused from `shared/widgets/`
2. **PeriodComparisonCard** — two side-by-side cards (This Period vs Previous), absolute + % diff below, green/red coloring
3. **CategoryDonutChart** — reused from `home/widgets/`, with `onSliceTap` drill-down
4. **SpendBarChart** — fl_chart BarChart, one bar per day, tooltip on touch
5. **SpendTrendLineChart** — fl_chart LineChart, cumulative spend, gradient fill
6. **CategorySpendList** — sorted by amount desc, colored dot + name + amount + % + progress bar, tappable → `CategoryTransactionsSheet`
7. **SizedBox(height: 80)** — FAB clearance

### Reused Components

- `CategoryDonutChart` — as-is with `filterCurrencies: {baseCurrency}`
- `PeriodSelector` — as-is
- `CategoryTransactionsSheet.show()` — drill-down from donut and list

---

## 3. Orphan Cleanup (T3)

### Files to Delete

| File | Reason |
|------|--------|
| `core/providers/database_provider.dart` | Duplicate — real one is `database_providers.dart` (plural) |
| `data/models/expense.dart` | Legacy model, replaced by Drift `TransactionData` |
| `data/models/category.dart` | Legacy model, replaced by Drift `CategoryData` |
| `data/database/database_service.dart` | Legacy DB service, replaced by Drift database |
| `services/export_helper_stub.dart` | Dead code — `export_provider.dart` doesn't reference it |
| `services/export_helper_web.dart` | Dead code |
| `services/export_helper_native.dart` | Dead code |

### Files Kept (explicit decision)

| File | Reason |
|------|--------|
| `features/budgets/utils/mock_data.dart` | User requested to keep |

### Directories to Remove (empty after deletions)

- `data/models/`
- `data/database/`
- `data/`
- `services/`
- `providers/` (already empty)

### Code Cleanup in `app_router.dart`

- Delete `_PlaceholderScreen` class
- Delete `/expenses/:id` route (uses `_PlaceholderScreen`)
- Move `/settings` from ShellRoute child to top-level GoRoute

---

## 4. Backend Cleanup (T4)

| File | Change |
|------|--------|
| `apps/api/src/auth/guards/jwt-auth.guard.ts` | Remove `OptionalAuthGuard` class (lines 7–18). Keep `JwtAuthGuard` only. Verified: never imported or used anywhere else. |

---

## Verification Summary

All orphan files verified with zero imports via grep across the entire mobile codebase. `OptionalAuthGuard` verified as defined-only with no consumers. `export_provider.dart` confirmed to use direct `dart:io` imports with no conditional import pattern.
