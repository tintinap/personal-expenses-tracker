import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'category_dao.g.dart';

/// PRD §9 — DAO for category management
@DriftAccessor(tables: [Categories, Transactions])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  /// Get all categories ordered by sortOrder
  Future<List<CategoryData>> getAll() {
    return (select(categories)
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  /// Get only visible (non-hidden) categories for pickers
  Future<List<CategoryData>> getActive() {
    return (select(categories)
          ..where((c) => c.isHidden.equals(false))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  /// Watch all categories (reactive)
  Stream<List<CategoryData>> watchAll() {
    return (select(categories)
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .watch();
  }

  /// Get a single category by ID
  Future<CategoryData?> getById(String id) {
    return (select(categories)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new category
  Future<void> insertCategory(CategoriesCompanion entry) {
    return into(categories).insert(entry);
  }

  /// Update a category
  Future<bool> updateCategory(CategoriesCompanion entry) {
    return update(categories).replace(entry);
  }

  /// Count expenses associated with a category (for delete guard)
  Future<int> countAssociatedExpenses(String categoryId) async {
    final result = await (select(transactions)
          ..where((t) => t.categoryId.equals(categoryId))
          ..where((t) => t.deletedAt.isNull()))
        .get();
    return result.length;
  }

  /// Delete a category (only if no associated expenses)
  Future<void> deleteCategory(String id) {
    return (delete(categories)..where((c) => c.id.equals(id))).go();
  }

  /// Toggle hidden status
  Future<void> toggleHidden(String id, bool isHidden) {
    return (update(categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        isHidden: Value(isHidden),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value('pending'),
      ),
    );
  }
}
