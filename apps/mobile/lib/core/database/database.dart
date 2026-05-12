import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

import 'daos/transaction_dao.dart';
import 'daos/category_dao.dart';
import 'daos/budget_dao.dart';
import 'daos/exchange_rate_dao.dart';
import 'daos/currency_balance_dao.dart';

part 'database.g.dart';

/// PRD §5 — Drift database: offline source of truth on device
@DriftDatabase(
  tables: [
    Transactions,
    Categories,
    Budgets,
    ExchangeRates,
    CurrencyBalances,
    SyncQueue,
    Settings,
  ],
  daos: [
    TransactionDao,
    CategoryDao,
    BudgetDao,
    ExchangeRateDao,
    CurrencyBalanceDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // For testing
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Seed default categories
        await _seedDefaultCategories();
        // Seed default settings
        await _seedDefaultSettings();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // Add parent_id column to categories table
          await m.addColumn(categories, categories.parentId);
        }
        if (from < 3) {
          await m.addColumn(categories, categories.iconCodePoint);
          await _migrateCategoryIconsForExistingRows();
        }
      },
    );
  }

  Future<void> _seedDefaultCategories() async {
    // MaterialIcons code points (matches Icons.* in Flutter Material font).
    final defaults = <(String name, String colour, int order, int iconCodePoint)>[
      ('Food & dining', '#378ADD', 0, 0xe532), // restaurant
      ('Groceries', '#4CAF50', 1, 0xe395), // local_grocery_store
      ('Transport', '#FF7043', 2, 0xe1d7), // directions_car
      ('Health & medical', '#E91E8C', 3, 0xe396), // local_hospital
      ('Shopping & retail', '#9C27B0', 4, 0xe59a), // shopping_bag
      ('Bills & utilities', '#009688', 5, 0xe50d), // receipt_long
      ('Entertainment', '#FFC107', 6, 0xe40d), // movie
      ('Travel', '#FF8F00', 7, 0xe297), // flight
      ('Subscriptions', '#F44336', 8, 0xe618), // subscriptions
      ('Education', '#455A64', 9, 0xe559), // school
      ('Personal care', '#4FC3F7', 10, 0xe5d8), // spa
      ('Other / uncategorised', '#9E9E9E', 11, 0xe148), // category
    ];

    for (final (name, colour, order, iconCp) in defaults) {
      await into(categories).insert(CategoriesCompanion.insert(
        id: 'default-cat-$order',
        name: name,
        colourHex: colour,
        iconCodePoint: Value(iconCp),
        sortOrder: order,
        isDefault: const Value(true),
      ));
    }
  }

  /// Sets icons for seeded default categories when upgrading from schema before v3.
  Future<void> _migrateCategoryIconsForExistingRows() async {
    final defaults = <(String id, int iconCodePoint)>[
      ('default-cat-0', 0xe532),
      ('default-cat-1', 0xe395),
      ('default-cat-2', 0xe1d7),
      ('default-cat-3', 0xe396),
      ('default-cat-4', 0xe59a),
      ('default-cat-5', 0xe50d),
      ('default-cat-6', 0xe40d),
      ('default-cat-7', 0xe297),
      ('default-cat-8', 0xe618),
      ('default-cat-9', 0xe559),
      ('default-cat-10', 0xe5d8),
      ('default-cat-11', 0xe148),
    ];
    for (final (id, iconCp) in defaults) {
      await customStatement(
        'UPDATE categories SET icon_code_point = ? WHERE id = ?',
        [iconCp, id],
      );
    }
  }

  Future<void> _seedDefaultSettings() async {
    final defaultSettings = {
      'base_currency': 'AUD',
      'view_currency': 'AUD',
      'theme_mode': 'system',
      'last_used_currency': 'AUD',
      'sign_in_prompt_dismissed': 'false',
    };

    for (final entry in defaultSettings.entries) {
      await into(settings).insert(SettingsCompanion.insert(
        key: entry.key,
        value: entry.value,
      ));
    }
  }

  // ── Settings helpers ──────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final row = await (select(settings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(SettingsCompanion.insert(
      key: key,
      value: value,
    ));
  }

  // ── Sync Queue helpers ────────────────────────────────────

  Future<List<SyncQueueData>> getPendingSyncItems() async {
    return (select(syncQueue)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> addToSyncQueue({
    required String id,
    required String recordType,
    required String recordId,
    required String operation,
    required String payload,
  }) async {
    await into(syncQueue).insert(SyncQueueCompanion.insert(
      id: id,
      recordType: recordType,
      recordId: recordId,
      operation: operation,
      payload: payload,
    ));
  }

  Future<void> removeSyncItem(String id) async {
    await (delete(syncQueue)..where((t) => t.id.equals(id))).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'daily_spend.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
