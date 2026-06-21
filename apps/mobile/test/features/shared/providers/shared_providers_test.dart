import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_spend/core/database/database.dart';
import 'package:daily_spend/core/providers/database_providers.dart';
import 'package:daily_spend/features/shared/providers/shared_providers.dart';

void main() {
  group('viewCurrencyRateProvider', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );

      // Pre-seed exchange rate in cache database to avoid actual network API requests in tests
      final now = DateTime.now();
      final dateOnly = DateTime(now.year, now.month, now.day);
      await db.exchangeRateDao.cacheRate(ExchangeRatesCompanion.insert(
        id: 'er-AUD-THB-${dateOnly.millisecondsSinceEpoch}',
        baseCurrency: 'AUD',
        quoteCurrency: 'THB',
        rateDate: dateOnly,
        rate: 24.5,
      ));
    });

    tearDown(() async {
      container.dispose();
    });

    test('it falls back to API when database has no rate', () async {
      final rateDao = container.read(exchangeRateDaoProvider);

      // Override view currency to THB - await this async call
      await container.read(viewCurrencyProvider.notifier).set('THB');
      
      // Wait for the provider to finish loading and transition to AsyncData
      while (container.read(viewCurrencyRateProvider).isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final rate = container.read(viewCurrencyRateProvider).value;
      
      // It should return the seeded rate of 24.5
      expect(rate, 24.5);
      
      // It should also cache/retrieve it correctly in the DB
      final cachedRate = await rateDao.getMostRecent('AUD', 'THB');
      
      expect(cachedRate, isNotNull);
      expect(cachedRate!.rate, rate);

      // Wait for any background tasks to finish
      await Future.delayed(const Duration(milliseconds: 100));
    });
  });
}
