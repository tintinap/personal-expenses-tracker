# Budgets Feature — Design Document

**Status:** Approved  
**Created:** 2026-05-12  
**Scope:** Mobile (Flutter) only — backend/web changes deferred  

---

## 1. Overview

Implement the budgets feature end-to-end on the Flutter mobile app. The backend API and Prisma schema already have basic CRUD; this design focuses on the **missing mobile UI**, **auto-rolling period logic**, **per-currency budgets**, **flexible category scoping**, **period history**, and **budget-aware transaction entry with notifications**.

### What exists today

| Layer | Status |
|-------|--------|
| DB Schema (Prisma) | ✅ Basic Budget model (scope, categoryId, amountBase, periodType, dates) |
| Backend API (NestJS) | ✅ Full CRUD + BudgetAlertsService (80%/100% FCM push) |
| Mobile DB (Drift) | ✅ Budgets table + BudgetDao with CRUD + watch |
| Mobile Providers | ⚠️ BudgetProgress model + budgetProgressListProvider (basic) |
| Mobile UI — List | ⚠️ BudgetsScreen + BudgetCard render, FAB is TODO |
| Mobile UI — Detail | ⚠️ BudgetDetailScreen shows progress, edit is TODO |
| Add/Edit Budget | ❌ No bottom sheet or form |
| Delete Budget | ❌ No UI |
| Rolling periods | ❌ Basic startDate→endDate/now only |
| Per-currency | ❌ No currency field on budgets |
| Flexible categories | ❌ Single category only |
| Period history | ❌ Not implemented |
| Budget-aware tx entry | ❌ Not implemented |

### What this design adds

- Per-currency budgets (one currency per budget, chosen by user)
- Flexible category scoping: all / include / exclude (multi-select)
- Recurring vs one-shot budgets
- Auto-rolling period calculator
- BudgetBottomSheet (create/edit)
- Delete with confirmation
- Budget History Screen (past periods)
- Budget-aware inline warnings in TransactionBottomSheet (≥90%)
- Local push notifications at 75%, 90%, 100% thresholds

---

## 2. Schema Changes (Drift only)

### New/modified columns on `Budgets` table

```dart
@DataClassName('BudgetData')
class Budgets extends Table {
  TextColumn get id => text()();

  // ── NEW: replaces old `scope` + `categoryId` ──
  TextColumn get scopeType => text().named('scope_type').withLength(max: 10)();
  // 'all' | 'include' | 'exclude'

  TextColumn get categoryIds => text().named('category_ids').nullable()();
  // JSON array of category IDs: '["cat-1","cat-2"]' or null when scopeType='all'

  TextColumn get currency => text().withLength(max: 3)();
  // User-chosen currency. Only expenses with matching original_currency count.

  RealColumn get amountBase => real().named('amount_base')();

  TextColumn get periodType =>
      text().named('period_type').withLength(max: 12)();
  // 'weekly' | 'fortnightly' | 'monthly' | 'custom'

  BoolColumn get isRecurring =>
      boolean().named('is_recurring').withDefault(const Constant(true))();
  // true = auto-rolls to next period; false = one-shot

  DateTimeColumn get startDate => dateTime().named('start_date')();
  DateTimeColumn get endDate => dateTime().named('end_date').nullable()();

  BoolColumn get isActive =>
      boolean().named('is_active').withDefault(const Constant(true))();

  // ── NEW: three notification flags (replaces notified_80 + notified_100) ──
  BoolColumn get notified75 =>
      boolean().named('notified_75').withDefault(const Constant(false))();
  BoolColumn get notified90 =>
      boolean().named('notified_90').withDefault(const Constant(false))();
  BoolColumn get notified100 =>
      boolean().named('notified_100').withDefault(const Constant(false))();

  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
```

### Migration v4

```dart
if (from < 4) {
  // Add new columns
  await m.addColumn(budgets, budgets.scopeType);
  await m.addColumn(budgets, budgets.categoryIds);
  await m.addColumn(budgets, budgets.currency);
  await m.addColumn(budgets, budgets.isRecurring);
  await m.addColumn(budgets, budgets.notified75);
  await m.addColumn(budgets, budgets.notified90);

  // Migrate existing data
  await customStatement(
    "UPDATE budgets SET scope_type = 'all', currency = 'AUD' WHERE scope = 'global'",
  );
  await customStatement(
    "UPDATE budgets SET scope_type = 'include', "
    "category_ids = '[\"' || category_id || '\"]', currency = 'AUD' "
    "WHERE scope = 'category'",
  );

  // Old columns (scope, category_id, notified_80) will be handled
  // by Drift's table rebuild on schema change
}
```

### Data flow diagram

```
┌──────────────────┐     ┌──────────────────┐     ┌───────────────────┐
│ BudgetBottomSheet│────▶│   BudgetDao      │────▶│   Drift DB        │
│ (create/edit)    │     │ (insert/update)   │     │ (budgets table)   │
└──────────────────┘     └──────────────────┘     └───────────────────┘
                                                          │
                                                          ▼ watch
                              ┌──────────────────────────────────────┐
                              │   budgetProgressListProvider          │
                              │   ┌─────────────────────┐            │
                              │   │ PeriodCalculator     │            │
                              │   │ (current window)     │            │
                              │   └─────────────────────┘            │
                              │   + TransactionDao.sumExpenses()      │
                              │   + Notification flag evaluation      │
                              └──────────────┬───────────────────────┘
                                             │
                         ┌───────────────────┼───────────────────┐
                         ▼                   ▼                   ▼
                  BudgetsScreen    BudgetDetailScreen   TransactionBottomSheet
                  (card list)     (progress + history)  (budget warning ≥90%)
```

---

## 3. Period Calculator

### Data class

```dart
class BudgetPeriod {
  final DateTime from;
  final DateTime to;
  final int periodIndex; // 0 = first period, 1 = second, etc.
  const BudgetPeriod({required this.from, required this.to, required this.periodIndex});
}
```

### Behavior

| Scenario | Input | Output |
|----------|-------|--------|
| Monthly, recurring | startDate: Jan 1, today: May 12 | Window: May 1–31, periodIndex: 4 |
| Weekly, recurring | startDate: May 5, today: May 12 | Window: May 12–18, periodIndex: 1 |
| Fortnightly, recurring | startDate: May 1, today: May 12 | Window: May 1–14, periodIndex: 0 |
| Custom (one-shot) | startDate: Apr 1, endDate: Jun 30 | Fixed: Apr 1–Jun 30, periodIndex: 0 |
| Non-recurring monthly | startDate: Apr 1, isRecurring: false | Window: Apr 1–30 only, expired after |

### API

```dart
class BudgetPeriodCalculator {
  /// Returns the current active period window for a budget
  static BudgetPeriod currentPeriod(BudgetData budget);

  /// Returns all past completed periods (for history screen)
  /// Ordered most-recent-first, capped at 52 periods
  static List<BudgetPeriod> pastPeriods(BudgetData budget);

  /// Returns true if the budget has expired (non-recurring + past endDate)
  static bool isExpired(BudgetData budget);
}
```

### Rolling logic

1. Calculate period duration from `periodType` (7 days / 14 days / calendar month)
2. Count how many full periods have elapsed since `startDate`
3. Current window = `startDate + (periodIndex × duration)` → end of that period
4. Monthly: calendar month arithmetic (Jan 1→31, Feb 1→28/29, etc.)
5. Fortnightly: 14 days starting from the budget's `startDate`
6. Non-recurring: if today > computed end, return last valid period + mark expired

---

## 4. Providers & State Management

### Updated `BudgetProgress` model

```dart
class BudgetProgress {
  final BudgetData budget;
  final BudgetPeriod currentPeriod;
  final double spentAmount;
  final double limitAmount;
  final double percentageUsed;
  final String currency;
  final bool isExpired;
  final List<String> categoryNames; // resolved names for display

  bool get isWarning => percentageUsed >= 0.75 && percentageUsed < 0.90;
  bool get isCritical => percentageUsed >= 0.90 && percentageUsed < 1.0;
  bool get isOverBudget => percentageUsed >= 1.0;

  double get remainingAmount => (limitAmount - spentAmount).clamp(0, double.infinity);
}
```

### Provider architecture

| Provider | Type | Purpose |
|----------|------|---------|
| `budgetProgressListProvider` | `FutureProvider<List<BudgetProgress>>` | Reworked — uses PeriodCalculator + currency + scope filtering |
| `activeBudgetWarningsProvider` | `Provider<List<BudgetProgress>>` | Derived — filters to budgets ≥90%. Used by TransactionBottomSheet |
| `budgetHistoryProvider(budgetId)` | `FutureProvider.family<List<BudgetPeriodHistory>, String>` | Past periods + spent amounts for history screen |

### New DAO methods on `TransactionDao`

```dart
/// Sum expenses in a specific currency within a date range
Future<double> sumExpensesByCurrency(String currency, DateTime from, DateTime to);

/// Sum expenses in specific currency + specific categories
Future<double> sumExpensesByCurrencyAndCategories(
  String currency, List<String> categoryIds, DateTime from, DateTime to);

/// Sum expenses in specific currency EXCLUDING specific categories
Future<double> sumExpensesByCurrencyExcludingCategories(
  String currency, List<String> excludeIds, DateTime from, DateTime to);
```

### Query logic

```dart
switch (budget.scopeType) {
  case 'all':
    spent = await txDao.sumExpensesByCurrency(currency, from, to);
  case 'include':
    final ids = jsonDecode(budget.categoryIds!) as List<String>;
    spent = await txDao.sumExpensesByCurrencyAndCategories(currency, ids, from, to);
  case 'exclude':
    final ids = jsonDecode(budget.categoryIds!) as List<String>;
    spent = await txDao.sumExpensesByCurrencyExcludingCategories(currency, ids, from, to);
}
```

### `BudgetPeriodHistory` (for history screen)

```dart
class BudgetPeriodHistory {
  final BudgetPeriod period;
  final double spentAmount;
  final double limitAmount;
  final double percentageUsed;
}
```

---

## 5. UI Components

### 5a. `BudgetBottomSheet` (Create / Edit)

Follows `TransactionBottomSheet` pattern — `ConsumerStatefulWidget` via `showModalBottomSheet`.

**Form fields:**

| Field | Widget | Required | Notes |
|-------|--------|----------|-------|
| Scope Type | `SegmentedButton` | Yes | `[All]` `[Include]` `[Exclude]` |
| Categories | Multi-select checklist | If include/exclude | Shows parent categories, checkbox per category |
| Amount | `TextField` (numeric) | Yes | Budget limit |
| Currency | `CurrencyPrefixDropdown` | Yes | Reuses existing widget |
| Period Type | `SegmentedButton` | Yes | `[Weekly]` `[Fortnightly]` `[Monthly]` `[Custom]` |
| Recurring | `SwitchListTile` | Yes | Default: on. Disabled when custom |
| Start Date | `TextButton` + `DatePicker` | Yes | Defaults to today |
| End Date | `TextButton` + `DatePicker` | If !recurring or custom | Required when not recurring |

**Behavior:**
- `All` → hide category checklist
- `Include`/`Exclude` → show multi-select checklist of parent categories
- `Custom` periodType → force `isRecurring = false`, show endDate picker
- `isRecurring` toggled off → show endDate picker
- Edit mode: pre-fills all fields from existing `BudgetData`
- Save → `BudgetDao.insertBudget()` or `BudgetDao.updateBudget()`

**Budget card label:**

| Scope | Display |
|-------|---------|
| `all` | "All categories" |
| `include` (1) | "Food & dining" |
| `include` (2+) | "Food, Groceries +1 more" |
| `exclude` (1) | "All except Transport" |
| `exclude` (2+) | "All except Transport, Bills +1 more" |

### 5b. `BudgetDetailScreen` (updated)

- **Edit button** (AppBar) → opens `BudgetBottomSheet` in edit mode
- **Delete button** (AppBar overflow menu) → confirmation dialog → `BudgetDao.deleteBudget()`
- **"View History"** button → navigates to `/budgets/:id/history` (recurring only)
- Currency symbol/code shown alongside amounts
- Category scope label shown (e.g. "Food, Groceries" or "All except Bills")

### 5c. `BudgetHistoryScreen` (new)

**Route:** `/budgets/:id/history`

- Scrollable list of past period cards, most-recent-first
- Each card: date range, spent/limit, percentage, color-coded progress bar
- Over-budget periods marked with ⚠️
- Capped at 52 past periods for performance

### 5d. `TransactionBottomSheet` — budget warning

When adding an expense, if any matching budget is ≥90% used:

```
⚠️ Food budget: $12.50 remaining
⚠️ Global AUD: $45.00 remaining
```

- Matching = same currency + (scopeType=all OR category in include list OR category NOT in exclude list)
- Informational only — does not block saving
- Sourced from `activeBudgetWarningsProvider`

---

## 6. Local Notification Logic

### Flow

```
Transaction saved/updated/deleted
  → budgetProgressListProvider recalculates
  → For each BudgetProgress:
      ├── ≥ 1.0 && !notified_100 → notify "Over budget" → set all flags true
      ├── ≥ 0.90 && !notified_90 → notify "90% critical" → set notified_90+75 true
      ├── ≥ 0.75 && !notified_75 → notify "75% warning" → set notified_75 true
      └── < 0.75 && any flag true → reset all flags
```

### Period rollover

When `PeriodCalculator.currentPeriod(budget).periodIndex` differs from last evaluated index, all three flags reset automatically. No cron needed.

### Flutter package

`flutter_local_notifications` with a dedicated `budget_alerts` notification channel.

### Platform-specific delivery (future)

| Platform | Method |
|----------|--------|
| Mobile | Local push notification (this design) |
| Web | Toast notification (noted in PRD, not implemented yet) |
| Backend | FCM push (existing, supplements local) |

---

## 7. Edge Cases

| Scenario | Handling |
|----------|----------|
| Budget created mid-period | Current period starts at `startDate` |
| Category deleted | Remove ID from JSON array. If `include` becomes empty → deactivate budget |
| Currency with no transactions | Shows 0% used, no alerts |
| Very old recurring budget | `pastPeriods()` capped at 52 periods |
| Expense deleted drops below threshold | Flags reset when < 75% |
| Multiple budgets match one transaction | Each evaluated independently |
| Non-recurring budget after endDate | `isExpired = true`, shows "Expired" badge |

---

## 8. Files to Create/Modify

### New files

| File | Purpose |
|------|---------|
| `lib/features/budgets/utils/budget_period_calculator.dart` | Pure period calculation utility |
| `lib/features/budgets/widgets/budget_bottom_sheet.dart` | Create/Edit budget form |
| `lib/features/budgets/screens/budget_history_screen.dart` | Past period history |
| `lib/features/budgets/providers/budget_notification_service.dart` | Local notification trigger logic |

### Modified files

| File | Changes |
|------|---------|
| `lib/core/database/tables.dart` | Update `Budgets` table (scopeType, categoryIds, currency, isRecurring, notified75/90) |
| `lib/core/database/database.dart` | Migration v4 |
| `lib/core/database/daos/budget_dao.dart` | Add/update methods for new schema |
| `lib/core/database/daos/transaction_dao.dart` | Add currency+category sum methods |
| `lib/features/budgets/providers/budget_providers.dart` | Rework BudgetProgress with PeriodCalculator + scope logic |
| `lib/features/budgets/screens/budgets_screen.dart` | Wire FAB → BudgetBottomSheet, update card labels |
| `lib/features/budgets/screens/budget_detail_screen.dart` | Wire edit/delete/history buttons |
| `lib/features/budgets/widgets/budget_card.dart` | Show currency, scope label, updated thresholds |
| `lib/features/transactions/widgets/transaction_bottom_sheet.dart` | Add budget warning when ≥90% |
| `lib/core/router/app_router.dart` | Add `/budgets/:id/history` route |
| `docs/prd-project-pet.md` | ✅ Already updated (§13) |

---

## 9. PRD Changes Made

- **§13 Budget alerts** fully rewritten:
  - Per-currency budgets
  - Recurring toggle (is_recurring)
  - Auto-rolling period calculator
  - Flexible category scope (all/include/exclude)
  - Three alert thresholds: 75%, 90%, 100%
  - Budget-aware transaction entry (inline warning ≥90%)
  - Platform-specific delivery: mobile=local push, web=toast, backend=FCM
  - Period history screen
  - Updated acceptance criteria (19 items)
- **Success metrics** updated: "Fires once at 75%, once at 90%, once at 100% per period"
