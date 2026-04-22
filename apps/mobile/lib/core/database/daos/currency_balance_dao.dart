import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'currency_balance_dao.g.dart';

/// PRD §20 — DAO for running currency balances
@DriftAccessor(tables: [CurrencyBalances, Transactions])
class CurrencyBalanceDao extends DatabaseAccessor<AppDatabase>
    with _$CurrencyBalanceDaoMixin {
  CurrencyBalanceDao(super.db);

  /// Watch all balances (reactive directly from Transactions)
  Stream<List<CurrencyBalanceData>> watchBalances() {
    final amountSum = transactions.originalAmount.sum();
    
    final query = selectOnly(transactions)
      ..addColumns([transactions.originalCurrency, transactions.transactionType, amountSum])
      ..where(transactions.deletedAt.isNull())
      ..groupBy([transactions.originalCurrency, transactions.transactionType]);

    return query.watch().map((rows) {
      final Map<String, double> balances = {};
      for (final row in rows) {
        final currency = row.read(transactions.originalCurrency);
        final type = row.read(transactions.transactionType);
        final total = row.read(amountSum);

        if (currency == null || type == null || total == null) continue;

        balances.putIfAbsent(currency, () => 0.0);

        if (type == 'currency_income' || type == 'currency_exchange_in') {
          balances[currency] = balances[currency]! + total;
        } else if (type == 'expense' || type == 'currency_exchange_out') {
          balances[currency] = balances[currency]! - total;
        }
      }

      return balances.entries.map((e) => CurrencyBalanceData(
        id: 'cb-${e.key}',
        currency: e.key,
        balance: e.value,
        updatedAt: DateTime.now(),
      )).toList();
    });
  }

  /// Get specific currency balance (Derived dynamically)
  Future<CurrencyBalanceData?> getBalance(String currency) async {
    final balances = await watchBalances().first;
    return balances.where((b) => b.currency == currency).firstOrNull;
  }

  /// OBSOLETE: Balances are now dynamically derived via SQL. 
  /// This method is a no-op kept to avoid breaking older UI code.
  Future<void> adjustBalance(String currency, double delta) async {}

  /// OBSOLETE: Balances are now derived in real-time.
  Future<void> recalculateAllBalances(DatabaseAccessor<AppDatabase> txDao) async {}
}
