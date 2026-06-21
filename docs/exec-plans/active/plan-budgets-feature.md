# Execution Plan: Budgets Feature (Mobile)

**Status:** Complete  
**Created:** 2026-05-12  
**Completed:** 2026-05-16  

## Overview
Implement the full budgets feature on the mobile app, including per-currency tracking, flexible category scoping (All, Include, Exclude), auto-rolling periods (where fortnightly is exactly 14 days), budget-aware transaction entry, and local notification alerts at 75%, 90%, and 100% usage thresholds.

## Tasks

### [x] Phase 1: Data Layer
- [x] **T1: Dependencies & Schema Update**
  - Add `flutter_local_notifications` to `pubspec.yaml`
  - Update `Budgets` table schema in `tables.dart` (scopeType, categoryIds, currency, isRecurring, notified75, notified90, notified100)
  - Implement Migration v4 in `database.dart`
- [x] **T2: Transaction DAO Updates**
  - Add `sumExpensesByCurrency`, `sumExpensesByCurrencyAndCategories`, and `sumExpensesByCurrencyExcludingCategories` methods

### [x] Phase 2: Logic Layer
- [x] **T3: Budget Period Calculator**
  - Create utility class for `currentPeriod()`, `pastPeriods()`, and `isExpired()` logic
- [x] **T4: State Management & Providers**
  - Refactor `BudgetProgress` model
  - Update `budgetProgressListProvider` to use new scope logic
  - Create `activeBudgetWarningsProvider` and `budgetHistoryProvider`
- [x] **T5: Notification Service Setup**
  - Configure `flutter_local_notifications` and `budget_alerts` channel
  - Wire up notification triggering from `budgetProgressListProvider`

### [x] Phase 3: UI Layer
- [x] **T6: Budget Bottom Sheet (Create/Edit)**
  - Create `BudgetBottomSheet` with flexible scope, currency picker, and recurring toggle
  - Wire save logic to `BudgetDao`
- [x] **T7: Budget Details & History UI**
  - Update `BudgetDetailScreen` with edit/delete buttons
  - Create `BudgetHistoryScreen`
- [x] **T8: Budget-aware Transaction Entry**
  - Update `TransactionBottomSheet` to display inline warning when budget is >=90% used
