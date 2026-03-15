import 'lib/data/models/expense.dart';
import 'lib/core/constants.dart';
import 'package:flutter/material.dart';

void main() {
  final now = DateTime.now();
  print('Now: \$now');
  
  final start = DateTime(now.year, now.month, 1);
  final end = now;
  print('Range: \$start to \$end');
  
  final expenseDate = DateTime(2026, 3, 15);
  final isBeforeStart = expenseDate.isBefore(start);
  final isAfterEnd = expenseDate.isAfter(end);
  
  print('Expense: \$expenseDate');
  print('Before start? \$isBeforeStart');
  print('After end? \$isAfterEnd');
}
