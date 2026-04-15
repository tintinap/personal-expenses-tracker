import 'package:flutter/material.dart';
import 'providers/expense_provider.dart';
import 'core/constants.dart';

void main() async {
  final p = ExpenseProvider();
  await Future.delayed(Duration(seconds: 1));
  print('Total expenses: \${p.expenses.length}');
  final filtered = p.filteredExpenses(FilterType.monthly);
  print('Filtered (monthly): \${filtered.length}');
}
