import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'transaction_dao.g.dart';

/// PRD §11c — per-currency activity totals shown on each Currency Card.
///
/// - [totalIn]: sum of `currency_income` original amounts (all-time).
/// - [totalSpent]: sum of `expense` original amounts (all-time, positive).
/// - [netExchanged]: net of (`currency_exchange_in` − `currency_exchange_out`)
///   for this currency. Positive ⇒ net inflow via exchanges; negative ⇒
///   net outflow.
class CurrencyBreakdown {
  final double totalIn;
  final double totalSpent;
  final double netExchanged;

  const CurrencyBreakdown({
    this.totalIn = 0,
    this.totalSpent = 0,
    this.netExchanged = 0,
  });
}

/// PRD §8, §11 — DAO for all transaction types (expense, income, exchange)
@DriftAccessor(tables: [Transactions, Categories])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  /// Get all transactions for a date range, optionally filtered by type
  Future<List<TransactionData>> getByDateRange(
    DateTime from,
    DateTime to, {
    String? transactionType,
    String? categoryId,
  }) {
    final query = select(transactions)
      ..where((t) => t.transactionDate.isBetweenValues(from, to))
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]);

    if (transactionType != null) {
      query.where((t) => t.transactionType.equals(transactionType));
    }
    if (categoryId != null) {
      query.where((t) => t.categoryId.equals(categoryId));
    }

    return query.get();
  }

  /// Get expenses only (for budget calculations)
  Future<List<TransactionData>> getExpensesByDateRange(
    DateTime from,
    DateTime to,
  ) {
    return getByDateRange(from, to, transactionType: 'expense');
  }

  /// Get all transactions for a specific currency
  Future<List<TransactionData>> getByCurrency(String currency) {
    return (select(transactions)
          ..where((t) => t.originalCurrency.equals(currency))
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .get();
  }

  /// Watch all transactions for a specific currency (reactive)
  Stream<List<TransactionData>> watchByCurrency(String currency) {
    return (select(transactions)
          ..where((t) => t.originalCurrency.equals(currency))
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .watch();
  }

  /// Get the paired exchange transaction (the other side of a currency exchange)
  Future<TransactionData?> getPairedTransaction(String exchangeEventId, String excludeId) {
    return (select(transactions)
          ..where((t) => t.exchangeEventId.equals(exchangeEventId))
          ..where((t) => t.id.equals(excludeId).not())
          ..where((t) => t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// Get a single transaction by ID
  Future<TransactionData?> getById(String id) {
    return (select(transactions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new transaction
  Future<void> insertTransaction(TransactionsCompanion entry) {
    return into(transactions).insert(entry);
  }

  /// Update an existing transaction
  Future<bool> updateTransaction(TransactionsCompanion entry) {
    return update(transactions).replace(entry);
  }

  /// Soft-delete a transaction
  Future<void> softDelete(String id) {
    return (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Watch all transactions for a date range (reactive)
  Stream<List<TransactionData>> watchByDateRange(
    DateTime from,
    DateTime to,
  ) {
    return (select(transactions)
          ..where((t) => t.transactionDate.isBetweenValues(from, to))
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
        .watch();
  }

  /// Count expenses by category for a date range (for reports)
  Future<double> sumExpensesByCategory(
    String categoryId,
    DateTime from,
    DateTime to,
  ) async {
    final result = await (select(transactions)
          ..where((t) => t.categoryId.equals(categoryId))
          ..where((t) => t.transactionType.equals('expense'))
          ..where((t) => t.transactionDate.isBetweenValues(from, to))
          ..where((t) => t.deletedAt.isNull()))
        .get();

    return result.fold<double>(0.0, (double sum, tx) => sum + tx.amountBase);
  }

  /// Sum all expenses in a date range (for budget progress)
  Future<double> sumExpenses(DateTime from, DateTime to) async {
    final result = await getExpensesByDateRange(from, to);
    return result.fold<double>(0.0, (double sum, tx) => sum + tx.amountBase);
  }

  /// Sum expenses in a specific currency within a date range
  Future<double> sumExpensesByCurrency(
    String currency,
    DateTime from,
    DateTime to,
  ) async {
    final result = await (select(transactions)
          ..where((t) => t.originalCurrency.equals(currency))
          ..where((t) => t.transactionType.equals('expense'))
          ..where((t) => t.transactionDate.isBetweenValues(from, to))
          ..where((t) => t.deletedAt.isNull()))
        .get();

    return result.fold<double>(0.0, (double sum, tx) => sum + tx.originalAmount);
  }

  /// Sum expenses in specific currency + specific categories
  Future<double> sumExpensesByCurrencyAndCategories(
    String currency,
    List<String> categoryIds,
    DateTime from,
    DateTime to,
  ) async {
    final result = await (select(transactions)
          ..where((t) => t.originalCurrency.equals(currency))
          ..where((t) => t.categoryId.isIn(categoryIds))
          ..where((t) => t.transactionType.equals('expense'))
          ..where((t) => t.transactionDate.isBetweenValues(from, to))
          ..where((t) => t.deletedAt.isNull()))
        .get();

    return result.fold<double>(0.0, (double sum, tx) => sum + tx.originalAmount);
  }

  /// Sum expenses in specific currency EXCLUDING specific categories
  Future<double> sumExpensesByCurrencyExcludingCategories(
    String currency,
    List<String> excludeIds,
    DateTime from,
    DateTime to,
  ) async {
    final result = await (select(transactions)
          ..where((t) => t.originalCurrency.equals(currency))
          ..where((t) => t.categoryId.isNotIn(excludeIds))
          ..where((t) => t.transactionType.equals('expense'))
          ..where((t) => t.transactionDate.isBetweenValues(from, to))
          ..where((t) => t.deletedAt.isNull()))
        .get();

    return result.fold<double>(0.0, (double sum, tx) => sum + tx.originalAmount);
  }

  /// One-shot variant of [watchCountByCurrency].
  Future<Map<String, int>> countByCurrency() async {
    final countExpr = transactions.id.count();
    final query = selectOnly(transactions)
      ..addColumns([transactions.originalCurrency, countExpr])
      ..where(transactions.deletedAt.isNull())
      ..groupBy([transactions.originalCurrency]);
    final rows = await query.get();
    return _rowsToCountMap(rows, countExpr);
  }

  /// Streaming variant — Drift re-executes the underlying query only when the
  /// `transactions` table changes, so the result is naturally cached between
  /// emissions. Combine with a Riverpod `StreamProvider` to share a single
  /// cached value across the whole app.
  Stream<Map<String, int>> watchCountByCurrency() {
    final countExpr = transactions.id.count();
    final query = selectOnly(transactions)
      ..addColumns([transactions.originalCurrency, countExpr])
      ..where(transactions.deletedAt.isNull())
      ..groupBy([transactions.originalCurrency]);
    return query.watch().map((rows) => _rowsToCountMap(rows, countExpr));
  }

  Map<String, int> _rowsToCountMap(
    List<TypedResult> rows,
    Expression<int> countExpr,
  ) {
    final result = <String, int>{};
    for (final row in rows) {
      final currency = row.read(transactions.originalCurrency);
      final count = row.read(countExpr) ?? 0;
      if (currency != null) result[currency] = count;
    }
    return result;
  }

  /// Reactive per-currency breakdown (income / spent / net exchanged).
  ///
  /// PRD §11c — used by the Currency Wallets cards. Grouped at the database
  /// level (one query per emission) and re-executed by Drift only when
  /// `transactions` rows change, so consumers can safely share the stream
  /// via a Riverpod `StreamProvider` without re-querying per card.
  Stream<Map<String, CurrencyBreakdown>> watchBreakdownByCurrency() {
    final amountSum = transactions.originalAmount.sum();
    final query = selectOnly(transactions)
      ..addColumns([
        transactions.originalCurrency,
        transactions.transactionType,
        amountSum,
      ])
      ..where(transactions.deletedAt.isNull())
      ..groupBy([transactions.originalCurrency, transactions.transactionType]);
    return query
        .watch()
        .map((rows) => _rowsToBreakdownMap(rows, amountSum));
  }

  Map<String, CurrencyBreakdown> _rowsToBreakdownMap(
    List<TypedResult> rows,
    Expression<double> amountSum,
  ) {
    final totals = <String, _MutableBreakdown>{};
    for (final row in rows) {
      final currency = row.read(transactions.originalCurrency);
      final type = row.read(transactions.transactionType);
      final sum = row.read(amountSum) ?? 0.0;
      if (currency == null || type == null) continue;

      final entry = totals.putIfAbsent(currency, _MutableBreakdown.new);
      switch (type) {
        case 'currency_income':
          entry.totalIn += sum;
          break;
        case 'expense':
          entry.totalSpent += sum;
          break;
        case 'currency_exchange_in':
          entry.netExchanged += sum;
          break;
        case 'currency_exchange_out':
          entry.netExchanged -= sum;
          break;
      }
    }
    return totals.map((k, v) => MapEntry(k, v.toImmutable()));
  }
}

class _MutableBreakdown {
  double totalIn = 0;
  double totalSpent = 0;
  double netExchanged = 0;

  CurrencyBreakdown toImmutable() => CurrencyBreakdown(
        totalIn: totalIn,
        totalSpent: totalSpent,
        netExchanged: netExchanged,
      );
}
