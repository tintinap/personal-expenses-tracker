import 'package:flutter_test/flutter_test.dart';
import 'package:daily_spend/features/budgets/utils/budget_period_calculator.dart';
import 'package:daily_spend/core/database/database.dart';

void main() {
  group('BudgetPeriodCalculator', () {
    final start = DateTime(2026, 1, 1, 0, 0, 0); // Thursday, Jan 1
    
    // Helper to create dummy budget data
    BudgetData createBudget(String periodType, bool isRecurring) {
      return BudgetData(
        id: 'test-id',
        scopeType: 'all',
        categoryIds: null,
        currency: 'AUD',
        amountBase: 100,
        periodType: periodType,
        isRecurring: isRecurring,
        startDate: start,
        endDate: null,
        isActive: true,
        notified75: false,
        notified90: false,
        notified100: false,
        syncStatus: 'pending',
        createdAt: start,
        updatedAt: start,
      );
    }

    test('Weekly recurring budget periods', () {
      final budget = createBudget('weekly', true);
      
      // Period 0: Jan 1 - Jan 7 (end of Jan 7)
      final period0 = BudgetPeriodCalculator.currentPeriod(budget, today: DateTime(2026, 1, 2));
      expect(period0.periodIndex, 0);
      expect(period0.from, start);
      expect(period0.to, DateTime(2026, 1, 7, 23, 59, 59, 999));
      
      // Period 1: Jan 8 - Jan 14
      final period1 = BudgetPeriodCalculator.currentPeriod(budget, today: DateTime(2026, 1, 9));
      expect(period1.periodIndex, 1);
      expect(period1.from, DateTime(2026, 1, 8));
      
      final past = BudgetPeriodCalculator.pastPeriods(budget, today: DateTime(2026, 1, 9));
      expect(past.length, 1);
      expect(past.first.periodIndex, 0);
      expect(past.first.from, start);
    });

    test('Fortnightly recurring budget periods (14 days)', () {
      final budget = createBudget('fortnightly', true);
      
      // Period 0: Jan 1 - Jan 14 (end of Jan 14)
      final period0 = BudgetPeriodCalculator.currentPeriod(budget, today: DateTime(2026, 1, 10));
      expect(period0.periodIndex, 0);
      expect(period0.from, start);
      expect(period0.to, DateTime(2026, 1, 14, 23, 59, 59, 999));
      
      // Period 1: Jan 15 - Jan 28
      final period1 = BudgetPeriodCalculator.currentPeriod(budget, today: DateTime(2026, 1, 16));
      expect(period1.periodIndex, 1);
      expect(period1.from, DateTime(2026, 1, 15));
      expect(period1.to, DateTime(2026, 1, 28, 23, 59, 59, 999));
      
      final past = BudgetPeriodCalculator.pastPeriods(budget, today: DateTime(2026, 1, 16));
      expect(past.length, 1);
      expect(past.first.periodIndex, 0);
      expect(past.first.from, start);
    });

    test('Monthly recurring budget periods', () {
      final budget = createBudget('monthly', true);
      
      // Period 0: Jan 1 - Jan 31
      final period0 = BudgetPeriodCalculator.currentPeriod(budget, today: DateTime(2026, 1, 15));
      expect(period0.periodIndex, 0);
      expect(period0.from, start);
      expect(period0.to, DateTime(2026, 1, 31, 23, 59, 59, 999));
      
      // Period 1: Feb 1 - Feb 28
      final period1 = BudgetPeriodCalculator.currentPeriod(budget, today: DateTime(2026, 2, 1));
      expect(period1.periodIndex, 1);
      expect(period1.from, DateTime(2026, 2, 1));
      expect(period1.to, DateTime(2026, 2, 28, 23, 59, 59, 999)); // Non-leap year
      
      // Period 5: June 1 - June 30
      final period5 = BudgetPeriodCalculator.currentPeriod(budget, today: DateTime(2026, 6, 15));
      expect(period5.periodIndex, 5);
      expect(period5.from, DateTime(2026, 6, 1));
      expect(period5.to, DateTime(2026, 6, 30, 23, 59, 59, 999));
    });

    test('Non-recurring expiration logic', () {
      final budget = createBudget('fortnightly', false); // Start: Jan 1
      
      expect(BudgetPeriodCalculator.isExpired(budget, today: DateTime(2026, 1, 10)), false);
      expect(BudgetPeriodCalculator.isExpired(budget, today: DateTime(2026, 1, 15)), true); // Jan 14 end
      
      final current = BudgetPeriodCalculator.currentPeriod(budget, today: DateTime(2026, 1, 20));
      expect(current.periodIndex, 0); // Always returns the first period for non-recurring
    });
  });
}
