import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Regression: v3 budgets had NOT NULL `scope`. After v4, Drift INSERT omits it → SQLite error.
void main() {
  test('legacy NOT NULL scope rejects insert when omitted like Drift does', () {
    final db = sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE budgets (
        id TEXT NOT NULL PRIMARY KEY,
        scope TEXT NOT NULL,
        scope_type TEXT NOT NULL,
        category_ids TEXT,
        currency TEXT NOT NULL,
        amount_base REAL NOT NULL,
        period_type TEXT NOT NULL,
        is_recurring INTEGER NOT NULL DEFAULT 1,
        start_date INTEGER NOT NULL,
        end_date INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        notified_75 INTEGER NOT NULL DEFAULT 0,
        notified_90 INTEGER NOT NULL DEFAULT 0,
        notified_100 INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    expect(
      () => db.execute('''
        INSERT INTO budgets (
          id, scope_type, currency, amount_base, period_type,
          is_recurring, start_date, created_at, updated_at
        ) VALUES (
          'test-id', 'all', 'AUD', 100.0, 'monthly',
          1, 0, 0, 0
        )
      '''),
      throwsException,
    );

    db.dispose();
  });

  test('after dropping legacy scope, insert succeeds', () {
    final db = sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE budgets (
        id TEXT NOT NULL PRIMARY KEY,
        scope TEXT NOT NULL,
        scope_type TEXT NOT NULL,
        category_ids TEXT,
        currency TEXT NOT NULL,
        amount_base REAL NOT NULL,
        period_type TEXT NOT NULL,
        is_recurring INTEGER NOT NULL DEFAULT 1,
        start_date INTEGER NOT NULL,
        end_date INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        notified_75 INTEGER NOT NULL DEFAULT 0,
        notified_90 INTEGER NOT NULL DEFAULT 0,
        notified_100 INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    db.execute('ALTER TABLE budgets DROP COLUMN scope');

    db.execute('''
      INSERT INTO budgets (
        id, scope_type, currency, amount_base, period_type,
        is_recurring, start_date, created_at, updated_at
      ) VALUES (
        'test-id', 'all', 'AUD', 100.0, 'monthly',
        1, 0, 0, 0
      )
    ''');

    final row = db.select('SELECT id FROM budgets WHERE id = ?', ['test-id']);
    expect(row.length, 1);

    db.dispose();
  });
}
