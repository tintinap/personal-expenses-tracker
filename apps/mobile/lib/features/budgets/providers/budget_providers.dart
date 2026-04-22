import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../../shared/providers/shared_providers.dart';

class BudgetProgress {
  final BudgetData budget;
  final double spentAmount;
  final double limitAmount;
  final double percentageUsed;

  const BudgetProgress({
    required this.budget,
    required this.spentAmount,
    required this.limitAmount,
    required this.percentageUsed,
  });
  
  bool get isWarning => percentageUsed >= 0.8 && percentageUsed < 1.0;
  bool get isCritical => percentageUsed >= 1.0;
}

final budgetProgressListProvider = FutureProvider<List<BudgetProgress>>((ref) async {
  final budgetsAsync = ref.watch(budgetListProvider);
  final budgets = budgetsAsync.valueOrNull ?? [];
  final txDao = ref.watch(transactionDaoProvider);
  
  final List<BudgetProgress> results = [];
  
  for (final budget in budgets) {
    // Determine the current active period for this budget
    // PRD §13 allows weekly, fortnightly, monthly, custom.
    // For simplicity of this UI mockup, assuming `startDate` and `endDate` map closely
    // to the active period, or we calculate based on `periodType`.
    
    // Fallback: If no end date, assume start to now.
    final end = budget.endDate ?? DateTime.now();
    double spent = 0;
    
    if (budget.scope == 'global') {
      spent = await txDao.sumExpenses(budget.startDate, end);
    } else if (budget.scope == 'category' && budget.categoryId != null) {
      spent = await txDao.sumExpensesByCategory(budget.categoryId!, budget.startDate, end);
    }
    
    final percentage = spent / budget.amountBase;
    
    results.add(BudgetProgress(
      budget: budget,
      spentAmount: spent,
      limitAmount: budget.amountBase,
      percentageUsed: percentage,
    ));
  }
  
  return results;
});
