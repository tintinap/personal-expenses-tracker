import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';

/// PRD §21 — Period Selector State
enum PeriodType { daily, weekly, fortnightly, monthly, yearly, custom }

class PeriodState {
  final PeriodType type;
  final DateTime from;
  final DateTime to;

  const PeriodState({
    required this.type,
    required this.from,
    required this.to,
  });
}

class PeriodNotifier extends Notifier<PeriodState> {
  @override
  PeriodState build() {
    final now = DateTime.now();
    return _calculatePeriod(PeriodType.daily, now);
  }

  PeriodState _calculatePeriod(PeriodType type, DateTime referenceDate) {
    DateTime from;
    DateTime to;

    switch (type) {
      case PeriodType.daily:
        from = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
        to = DateTime(referenceDate.year, referenceDate.month, referenceDate.day, 23, 59, 59);
        break;
      case PeriodType.weekly:
        // Assuming Monday is start of week
        final daysToMonday = referenceDate.weekday - 1;
        from = DateTime(referenceDate.year, referenceDate.month, referenceDate.day - daysToMonday);
        to = from.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case PeriodType.fortnightly:
        final daysToMonday = referenceDate.weekday - 1;
        from = DateTime(referenceDate.year, referenceDate.month, referenceDate.day - daysToMonday);
        to = from.add(const Duration(days: 13, hours: 23, minutes: 59, seconds: 59));
        break;
      case PeriodType.monthly:
        from = DateTime(referenceDate.year, referenceDate.month, 1);
        to = DateTime(referenceDate.year, referenceDate.month + 1, 0, 23, 59, 59);
        break;
      case PeriodType.yearly:
        from = DateTime(referenceDate.year, 1, 1);
        to = DateTime(referenceDate.year, 12, 31, 23, 59, 59);
        break;
      case PeriodType.custom:
        from = state.from;
        to = state.to;
        break;
    }

    return PeriodState(type: type, from: from, to: to);
  }

  void setType(PeriodType type) {
    if (type == PeriodType.custom) return; // Custom handled separately
    state = _calculatePeriod(type, DateTime.now());
  }

  void setToday() {
    state = _calculatePeriod(state.type, DateTime.now());
  }

  void setDate(DateTime date) {
    if (state.type == PeriodType.custom) return;
    state = _calculatePeriod(state.type, date);
  }

  void previous() {
    if (state.type == PeriodType.custom) return;
    
    DateTime ref;
    switch (state.type) {
      case PeriodType.daily:
        ref = state.from.subtract(const Duration(days: 1));
      case PeriodType.weekly:
        ref = state.from.subtract(const Duration(days: 7));
      case PeriodType.fortnightly:
        ref = state.from.subtract(const Duration(days: 14));
      case PeriodType.monthly:
        ref = DateTime(state.from.year, state.from.month - 1, 1);
      case PeriodType.yearly:
        ref = DateTime(state.from.year - 1, 1, 1);
      case PeriodType.custom:
        return;
    }
    state = _calculatePeriod(state.type, ref);
  }

  void next() {
    if (state.type == PeriodType.custom) return;
    
    // Don't navigate into the future
    if (state.to.isAfter(DateTime.now())) return;

    DateTime ref;
    switch (state.type) {
      case PeriodType.daily:
        ref = state.from.add(const Duration(days: 1));
      case PeriodType.weekly:
        ref = state.from.add(const Duration(days: 7));
      case PeriodType.fortnightly:
        ref = state.from.add(const Duration(days: 14));
      case PeriodType.monthly:
        ref = DateTime(state.from.year, state.from.month + 1, 1);
      case PeriodType.yearly:
        ref = DateTime(state.from.year + 1, 1, 1);
      case PeriodType.custom:
        return;
    }
    state = _calculatePeriod(state.type, ref);
  }
}

/// Provides the currently selected period for filtering transactions
final selectedPeriodProvider = NotifierProvider<PeriodNotifier, PeriodState>(() => PeriodNotifier());

/// PRD §21 — Transaction List Provider (Filtered by period)
final transactionListProvider = StreamProvider<List<TransactionData>>((ref) {
  final period = ref.watch(selectedPeriodProvider);
  final dao = ref.watch(transactionDaoProvider);
  return dao.watchByDateRange(period.from, period.to);
});

/// PRD §21 — Expense List Provider (Derived from transactionListProvider)
final expenseListProvider = Provider<List<TransactionData>>((ref) {
  final transactions = ref.watch(transactionListProvider).valueOrNull ?? [];
  return transactions.where((t) => t.transactionType == 'expense').toList();
});

/// PRD §21 — Category List Provider (All)
final categoryListProvider = StreamProvider<List<CategoryData>>((ref) {
  final dao = ref.watch(categoryDaoProvider);
  return dao.watchAll();
});

/// PRD §21 — Active Category List Provider (Non-hidden)
final activeCategoryListProvider = Provider<List<CategoryData>>((ref) {
  final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
  return categories.where((c) => !c.isHidden).toList();
});

/// PRD §21 — Budget List Provider
final budgetListProvider = StreamProvider<List<BudgetData>>((ref) {
  final dao = ref.watch(budgetDaoProvider);
  return dao.watchActive();
});

/// PRD §21 — Currency Balances Provider
final currencyBalancesProvider = StreamProvider<List<CurrencyBalanceData>>((ref) {
  final dao = ref.watch(currencyBalanceDaoProvider);
  return dao.watchBalances();
});

/// PRD §21 — Dashboard Summary Provider
class DashboardSummary {
  final double totalSpent;
  final String topCategoryName;
  final double topCategoryAmount;
  final int transactionCount;

  const DashboardSummary({
    required this.totalSpent,
    required this.topCategoryName,
    required this.topCategoryAmount,
    required this.transactionCount,
  });
}

final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  final expenses = ref.watch(expenseListProvider);
  final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
  
  if (expenses.isEmpty) {
    return const DashboardSummary(
      totalSpent: 0,
      topCategoryName: 'None',
      topCategoryAmount: 0,
      transactionCount: 0,
    );
  }

  double totalSpent = 0;
  final categoryTotals = <String, double>{};

  for (final expense in expenses) {
    totalSpent += expense.amountBase;
    if (expense.categoryId != null) {
      categoryTotals[expense.categoryId!] = (categoryTotals[expense.categoryId!] ?? 0) + expense.amountBase;
    }
  }

  String topCategoryId = '';
  double maxAmount = 0;
  
  categoryTotals.forEach((id, amount) {
    if (amount > maxAmount) {
      maxAmount = amount;
      topCategoryId = id;
    }
  });

  String topCategoryName = 'Unknown';
  if (topCategoryId.isNotEmpty) {
    final cat = categories.where((c) => c.id == topCategoryId).firstOrNull;
    if (cat != null) topCategoryName = cat.name;
  }

  return DashboardSummary(
    totalSpent: totalSpent,
    topCategoryName: topCategoryName,
    topCategoryAmount: maxAmount,
    transactionCount: expenses.length,
  );
});
