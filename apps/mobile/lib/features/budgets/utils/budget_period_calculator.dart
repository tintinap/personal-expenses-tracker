import 'package:daily_spend/core/database/database.dart';

class BudgetPeriod {
  final DateTime from;
  final DateTime to;
  final int periodIndex;

  const BudgetPeriod({
    required this.from,
    required this.to,
    required this.periodIndex,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetPeriod &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to &&
          periodIndex == other.periodIndex;

  @override
  int get hashCode => from.hashCode ^ to.hashCode ^ periodIndex.hashCode;
}

class BudgetPeriodCalculator {
  /// Returns the current active period window for a budget
  static BudgetPeriod currentPeriod(BudgetData budget, {DateTime? today}) {
    final now = today ?? DateTime.now();
    final start = budget.startDate;
    
    if (!budget.isRecurring) {
      final end = budget.endDate ?? _calculateSinglePeriodEnd(start, budget.periodType);
      return BudgetPeriod(from: start, to: end, periodIndex: 0);
    }
    
    if (now.isBefore(start)) {
      final end = _calculateSinglePeriodEnd(start, budget.periodType);
      return BudgetPeriod(from: start, to: end, periodIndex: 0);
    }

    switch (budget.periodType) {
      case 'weekly':
        const duration = Duration(days: 7);
        final diff = now.difference(start);
        final index = diff.inDays ~/ 7;
        final currentStart = start.add(Duration(days: index * 7));
        return BudgetPeriod(
          from: currentStart,
          to: currentStart.add(duration).subtract(const Duration(milliseconds: 1)),
          periodIndex: index,
        );
      
      case 'fortnightly':
        const duration = Duration(days: 14);
        final diff = now.difference(start);
        final index = diff.inDays ~/ 14;
        final currentStart = start.add(Duration(days: index * 14));
        return BudgetPeriod(
          from: currentStart,
          to: currentStart.add(duration).subtract(const Duration(milliseconds: 1)),
          periodIndex: index,
        );
        
      case 'monthly':
        int monthsDiff = (now.year - start.year) * 12 + now.month - start.month;
        if (now.day < start.day) {
          monthsDiff--;
        }
        
        final index = monthsDiff < 0 ? 0 : monthsDiff;
        final currentStart = DateTime(start.year, start.month + index, start.day, start.hour, start.minute, start.second);
        final nextMonthStart = DateTime(start.year, start.month + index + 1, start.day, start.hour, start.minute, start.second);
        
        return BudgetPeriod(
          from: currentStart,
          to: nextMonthStart.subtract(const Duration(milliseconds: 1)),
          periodIndex: index,
        );
        
      default:
        final end = budget.endDate ?? start.add(const Duration(days: 30));
        return BudgetPeriod(from: start, to: end, periodIndex: 0);
    }
  }

  static DateTime _calculateSinglePeriodEnd(DateTime start, String periodType) {
    switch (periodType) {
      case 'weekly':
        return start.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
      case 'fortnightly':
        return start.add(const Duration(days: 14)).subtract(const Duration(milliseconds: 1));
      case 'monthly':
        return DateTime(start.year, start.month + 1, start.day, start.hour, start.minute, start.second)
            .subtract(const Duration(milliseconds: 1));
      default:
        return start.add(const Duration(days: 30));
    }
  }

  /// Returns all past completed periods (for history screen)
  /// Ordered most-recent-first, capped at 52 periods
  static List<BudgetPeriod> pastPeriods(BudgetData budget, {DateTime? today}) {
    if (!budget.isRecurring) return [];
    
    final current = currentPeriod(budget, today: today);
    if (current.periodIndex == 0) return [];
    
    final past = <BudgetPeriod>[];
    final maxPeriods = current.periodIndex > 52 ? 52 : current.periodIndex;
    
    for (int i = 1; i <= maxPeriods; i++) {
      final indexToFind = current.periodIndex - i;
      DateTime pastStart;
      DateTime pastEnd;
      
      switch (budget.periodType) {
        case 'weekly':
          pastStart = budget.startDate.add(Duration(days: indexToFind * 7));
          pastEnd = pastStart.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
          break;
        case 'fortnightly':
          pastStart = budget.startDate.add(Duration(days: indexToFind * 14));
          pastEnd = pastStart.add(const Duration(days: 14)).subtract(const Duration(milliseconds: 1));
          break;
        case 'monthly':
          pastStart = DateTime(budget.startDate.year, budget.startDate.month + indexToFind, budget.startDate.day, budget.startDate.hour, budget.startDate.minute, budget.startDate.second);
          final nextStart = DateTime(budget.startDate.year, budget.startDate.month + indexToFind + 1, budget.startDate.day, budget.startDate.hour, budget.startDate.minute, budget.startDate.second);
          pastEnd = nextStart.subtract(const Duration(milliseconds: 1));
          break;
        default:
          pastStart = budget.startDate;
          pastEnd = budget.endDate ?? budget.startDate;
      }
      
      past.add(BudgetPeriod(from: pastStart, to: pastEnd, periodIndex: indexToFind));
    }
    
    return past;
  }

  /// Returns true if the budget has expired (non-recurring + past endDate)
  static bool isExpired(BudgetData budget, {DateTime? today}) {
    if (budget.isRecurring) return false;
    
    final now = today ?? DateTime.now();
    final end = budget.endDate ?? _calculateSinglePeriodEnd(budget.startDate, budget.periodType);
    
    return now.isAfter(end);
  }
}
