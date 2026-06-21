# Execution Plan: Phase 1 — Nav Restructure + Reports + Cleanup

**Status:** Active  
**Created:** 2026-05-16  
**Design Doc:** `docs/plans/phase1-nav-reports-cleanup-design.md`  
**Plan JSON:** `.agents/results/plan-95531e0b-dfcc-4098-9cf3-f81ea725a007.json`  

## Overview

Implement Phase 1 from the remaining-tasks plan: restructure navigation (Settings → gear icon, Reports → bottom tab), build full Reports screen with charts, delete orphan files, and remove backend dead code.

## Execution Order

### Wave 1 (parallel, no dependencies)
- [x] **T1:** Refactor `ScaffoldWithNavBar` to own AppBar + gear icon
- [x] **T5:** Create Reports providers (`reports_providers.dart`)
- [x] **T11:** Delete orphan files + empty directories
- [x] **T13:** Remove `OptionalAuthGuard` from backend

### Wave 2 (parallel, depends on T1 and/or T5)
- [x] **T2:** Refactor child screens to body-only (Home, Wallets, Budgets)
- [x] **T3:** Add Reports route + nav tab
- [x] **T4:** Move Settings to non-shell full-screen route
- [x] **T6:** Build `SpendBarChart` widget
- [x] **T7:** Build `SpendTrendLineChart` widget
- [x] **T8:** Build `PeriodComparisonCard` widget
- [x] **T9:** Build `CategorySpendList` widget

### Wave 3 (sequential, depends on Wave 2)
- [x] **T12:** Remove `_PlaceholderScreen` + `/expenses/:id` route

### Wave 4 (sequential, depends on T3 + all widgets)
- [x] **T10:** Assemble `ReportsScreen` with all widgets

### Wave 5 (final, depends on everything)
- [x] **T14:** Update `remaining-tasks.md` — mark Phase 1 complete

## Task Details

### T1: Refactor ScaffoldWithNavBar to own AppBar + gear icon
- **Agent:** Mobile | **Priority:** P0 | **Effort:** M
- **Files:** `apps/mobile/lib/core/router/app_router.dart`
- ScaffoldWithNavBar takes ownership of full Scaffold including AppBar
- Add title resolution logic based on current route
- Add gear icon to AppBar actions → navigates to `/settings`
- Route-aware FAB: budget add FAB on `/budgets`, transaction add FAB elsewhere

### T2: Refactor child screens to body-only
- **Agent:** Mobile | **Priority:** P0 | **Effort:** M | **Depends:** T1
- **Files:** `home_screen.dart`, `wallets_screen.dart`, `budgets_screen.dart`
- Remove Scaffold and AppBar from all 3 screens
- Remove `account_circle` icon from HomeScreen
- Move BudgetsScreen FAB to ScaffoldWithNavBar

### T3: Add Reports route + nav tab
- **Agent:** Mobile | **Priority:** P0 | **Effort:** S | **Depends:** T1
- **Files:** `app_router.dart`, `reports_screen.dart` (new)
- Add `/reports` GoRoute to ShellRoute at tab index 3
- Add Reports `_NavBarItem` (icon: `bar_chart`)
- Create minimal placeholder ReportsScreen

### T4: Move Settings to non-shell full-screen route
- **Agent:** Mobile | **Priority:** P0 | **Effort:** S | **Depends:** T1
- **Files:** `app_router.dart`, `settings_screen.dart`
- Remove `/settings` from ShellRoute children
- Add as top-level GoRoute with `/settings/categories` child

### T5: Create Reports providers
- **Agent:** Mobile | **Priority:** P0 | **Effort:** M
- **Files:** `reports_providers.dart` (new)
- 5 providers: `previousPeriodTransactionsProvider`, `dailySpendAggregateProvider`, `categorySpendProvider`, `trendSpendProvider`, `periodComparisonProvider`

### T6: Build SpendBarChart widget
- **Agent:** Mobile | **Priority:** P1 | **Effort:** M | **Depends:** T5
- **Files:** `spend_bar_chart.dart` (new)
- fl_chart BarChart, one bar per day, tooltip on touch

### T7: Build SpendTrendLineChart widget
- **Agent:** Mobile | **Priority:** P1 | **Effort:** M | **Depends:** T5
- **Files:** `spend_trend_line_chart.dart` (new)
- fl_chart LineChart, cumulative spend, gradient fill

### T8: Build PeriodComparisonCard widget
- **Agent:** Mobile | **Priority:** P1 | **Effort:** S | **Depends:** T5
- **Files:** `period_comparison_card.dart` (new)
- Two cards (this vs previous), delta with color coding

### T9: Build CategorySpendList widget
- **Agent:** Mobile | **Priority:** P1 | **Effort:** S | **Depends:** T5
- **Files:** `category_spend_list.dart` (new)
- Sorted category rows with progress bars, tappable → drill-down

### T10: Assemble ReportsScreen
- **Agent:** Mobile | **Priority:** P1 | **Effort:** M | **Depends:** T3, T5–T9
- **Files:** `reports_screen.dart`
- Full screen with all widgets in CustomScrollView

### T11: Delete orphan files + empty directories
- **Agent:** Mobile | **Priority:** P2 | **Effort:** S
- Delete 7 files, remove 5 empty directories
- Keep `mock_data.dart`

### T12: Remove _PlaceholderScreen + /expenses/:id route
- **Agent:** Mobile | **Priority:** P2 | **Effort:** S | **Depends:** T4
- Dead code cleanup in `app_router.dart`

### T13: Remove OptionalAuthGuard from backend
- **Agent:** Backend | **Priority:** P2 | **Effort:** S
- **Files:** `apps/api/src/auth/guards/jwt-auth.guard.ts`
- Remove class, keep JwtAuthGuard

### T14: Update remaining-tasks.md
- **Agent:** Mobile | **Priority:** P3 | **Effort:** S | **Depends:** T10–T13
- Mark Phase 1 tasks as complete in exec plan
