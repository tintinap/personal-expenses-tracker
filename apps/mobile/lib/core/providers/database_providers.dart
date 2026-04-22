import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../database/daos/budget_dao.dart';
import '../database/daos/category_dao.dart';
import '../database/daos/currency_balance_dao.dart';
import '../database/daos/exchange_rate_dao.dart';
import '../database/daos/transaction_dao.dart';

/// Provider for the main AppDatabase singleton
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// --- DAO Providers ---

final transactionDaoProvider = Provider<TransactionDao>((ref) {
  return ref.watch(databaseProvider).transactionDao;
});

final categoryDaoProvider = Provider<CategoryDao>((ref) {
  return ref.watch(databaseProvider).categoryDao;
});

final budgetDaoProvider = Provider<BudgetDao>((ref) {
  return ref.watch(databaseProvider).budgetDao;
});

final exchangeRateDaoProvider = Provider<ExchangeRateDao>((ref) {
  return ref.watch(databaseProvider).exchangeRateDao;
});

final currencyBalanceDaoProvider = Provider<CurrencyBalanceDao>((ref) {
  return ref.watch(databaseProvider).currencyBalanceDao;
});
