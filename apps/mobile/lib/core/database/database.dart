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
  int get schemaVersion => 2;

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
      },
    );
  }

  Future<void> _seedDefaultCategories() async {
    final defaults = [
      ('Food & dining', '#378ADD', 0),
      ('Groceries', '#4CAF50', 1),
      ('Transport', '#FF7043', 2),
      ('Health & medical', '#E91E8C', 3),
      ('Shopping & retail', '#9C27B0', 4),
      ('Bills & utilities', '#009688', 5),
      ('Entertainment', '#FFC107', 6),
      ('Travel', '#FF8F00', 7),
      ('Subscriptions', '#F44336', 8),
      ('Education', '#455A64', 9),
      ('Personal care', '#4FC3F7', 10),
      ('Other / uncategorised', '#9E9E9E', 11),
    ];

    for (final (name, colour, order) in defaults) {
      await into(categories).insert(CategoriesCompanion.insert(
        id: 'default-cat-$order',
        name: name,
        colourHex: colour,
        sortOrder: order,
        isDefault: const Value(true),
      ));
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
