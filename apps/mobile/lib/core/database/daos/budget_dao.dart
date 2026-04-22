import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'budget_dao.g.dart';

/// PRD §13 — DAO for budgets
@DriftAccessor(tables: [Budgets])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  /// Get all active budgets
  Future<List<BudgetData>> getActive() {
    return (select(budgets)
          ..where((b) => b.isActive.equals(true))
          ..orderBy([
            (b) => OrderingTerm.asc(b.scope), // global first, then category
            (b) => OrderingTerm.desc(b.createdAt),
          ]))
        .get();
  }

  /// Watch all active budgets (reactive)
  Stream<List<BudgetData>> watchActive() {
    return (select(budgets)
          ..where((b) => b.isActive.equals(true))
          ..orderBy([
            (b) => OrderingTerm.asc(b.scope),
            (b) => OrderingTerm.desc(b.createdAt),
          ]))
        .watch();
  }

  /// Get a single budget by ID
  Future<BudgetData?> getById(String id) {
    return (select(budgets)..where((b) => b.id.equals(id))).getSingleOrNull();
  }

  /// Insert a new budget
  Future<void> insertBudget(BudgetsCompanion entry) {
    return into(budgets).insert(entry);
  }

  /// Update an existing budget
  Future<bool> updateBudget(BudgetsCompanion entry) {
    return update(budgets).replace(entry);
  }

  /// Calculate end date based on actual start and current date config
  /// Note: Real implementation might need more complex Dart date logic,
  /// this is just fetching the raw bounds
  Future<List<BudgetData>> getExpiringThisMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return (select(budgets)
          ..where((b) => b.isActive.equals(true))
          ..where((b) => b.endDate.isBetweenValues(startOfMonth, endOfMonth)))
        .get();
  }

  /// Delete a budget
  Future<void> deleteBudget(String id) {
    return (delete(budgets)..where((b) => b.id.equals(id))).go();
  }
}
