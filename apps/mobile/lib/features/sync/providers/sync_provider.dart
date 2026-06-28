import 'dart:async';
import 'dart:math' as math;
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../../auth/providers/auth_provider.dart';

class SyncState {
  final bool isSyncing;
  final int pendingCount;
  final String? lastError;
  final DateTime? lastSync;

  const SyncState({
    this.isSyncing = false,
    this.pendingCount = 0,
    this.lastError,
    this.lastSync,
  });

  SyncState copyWith({
    bool? isSyncing,
    int? pendingCount,
    String? lastError,
    DateTime? lastSync,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: lastError, // Nullable to clear
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  Timer? _periodicTimer;
  bool _isProcessing = false;

  SyncNotifier(this._ref) : super(const SyncState()) {
    _init();
  }

  void _init() {
    _updatePendingCount();
    // Start periodic sync attempting every 30 seconds
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      processQueue();
    });
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  Future<void> _updatePendingCount() async {
    final db = _ref.read(databaseProvider);

    // All items in the sync queue are pending; completed items are deleted.
    // Items with attempts >= 5 are considered failed.
    final allItems = await db.select(db.syncQueue).get();
    final pendingCount = allItems.where((q) => q.attempts < 5).length;

    state = state.copyWith(pendingCount: pendingCount);
  }

  Future<void> processQueue() async {
    if (_isProcessing) return;
    final authState = _ref.read(authStateProvider);
    if (!authState.isAuthenticated) return;

    _isProcessing = true;
    state = state.copyWith(isSyncing: true, lastError: null);

    final db = _ref.read(databaseProvider);

    try {
      // 1. Get pending queue items ordered by createdAt ascending
      final pendingItems = await (db.select(db.syncQueue)
            ..where((q) => q.attempts.isSmallerThanValue(5))
            ..orderBy([(q) => drift.OrderingTerm.asc(q.createdAt)]))
          .get();

      for (final item in pendingItems) {
        try {
          // PRD §15 — Push records to backend
          // Mock Network call
          await Future.delayed(const Duration(milliseconds: 200));

          // On success, remove from queue
          await (db.delete(db.syncQueue)
                ..where((q) => q.id.equals(item.id)))
              .go();
        } catch (e) {
          // On failure, apply exponential backoff logic mapping to attempts
          final waitSeconds = math.pow(2, item.attempts).toInt() * 5;
          await Future.delayed(Duration(seconds: waitSeconds));

          await (db.update(db.syncQueue)
                ..where((q) => q.id.equals(item.id)))
              .write(SyncQueueCompanion(
            attempts: drift.Value(item.attempts + 1),
            lastError: drift.Value(e.toString()),
          ));
          rethrow; // Break inner loop on first failure to respect ordering
        }
      }

      // 2. PRD §15 - Pull remote changes
      // Mock fetch
      await Future.delayed(const Duration(milliseconds: 500));
      // Process received records (last-write-wins)

      state = state.copyWith(isSyncing: false, lastSync: DateTime.now());
    } catch (e) {
      state = state.copyWith(isSyncing: false, lastError: e.toString());
    } finally {
      await _updatePendingCount();
      _isProcessing = false;
    }
  }

  Future<void> pushAllLocalRecords() async {
    final db = _ref.read(databaseProvider);
    
    // Add all existing categories
    final categories = await db.select(db.categories).get();
    for (final c in categories) {
      await db.into(db.syncQueue).insert(SyncQueueCompanion(
        recordType: const drift.Value('category'),
        recordId: drift.Value(c.id),
        operation: const drift.Value('insert'),
        payload: drift.Value(jsonEncode({
          'name': c.name,
          'colourHex': c.colourHex,
          'iconCodePoint': c.iconCodePoint,
          'isDefault': c.isDefault,
          'isHidden': c.isHidden,
          'sortOrder': c.sortOrder,
          'parentId': c.parentId,
        })),
      ));
    }

    // Add all existing budgets
    final budgets = await db.select(db.budgets).get();
    for (final b in budgets) {
      await db.into(db.syncQueue).insert(SyncQueueCompanion(
        recordType: const drift.Value('budget'),
        recordId: drift.Value(b.id),
        operation: const drift.Value('insert'),
        payload: drift.Value(jsonEncode({
          'name': b.name,
          'scopeType': b.scopeType,
          'categoryIds': b.categoryIds,
          'currency': b.currency,
          'amountBase': b.amountBase,
          'periodType': b.periodType,
          'isRecurring': b.isRecurring,
          'startDate': b.startDate.toIso8601String(),
          'endDate': b.endDate?.toIso8601String(),
          'isActive': b.isActive,
        })),
      ));
    }

    // Add all existing transactions
    final transactions = await db.select(db.transactions).get();
    for (final t in transactions) {
      await db.into(db.syncQueue).insert(SyncQueueCompanion(
        recordType: const drift.Value('transaction'),
        recordId: drift.Value(t.id),
        operation: const drift.Value('insert'),
        payload: drift.Value(jsonEncode({
          'transactionType': t.transactionType,
          'amountBase': t.amountBase,
          'originalAmount': t.originalAmount,
          'originalCurrency': t.originalCurrency,
          'exchangeRate': t.exchangeRate,
          'rateDate': t.rateDate.toIso8601String(),
          'rateEstimated': t.rateEstimated,
          'rateSource': t.rateSource,
          'exchangeEventId': t.exchangeEventId,
          'categoryId': t.categoryId,
          'note': t.note,
          'sourceLabel': t.sourceLabel,
          'transactionDate': t.transactionDate.toIso8601String(),
          'isRecurring': t.isRecurring,
          'recurrenceType': t.recurrenceType,
        })),
      ));
    }

    await processQueue();
  }
}
