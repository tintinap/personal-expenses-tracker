import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'transaction_dao.g.dart';

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
}
