import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'exchange_rate_dao.g.dart';

/// PRD §20 — DAO for offline exchange rate cache
@DriftAccessor(tables: [ExchangeRates])
class ExchangeRateDao extends DatabaseAccessor<AppDatabase>
    with _$ExchangeRateDaoMixin {
  ExchangeRateDao(super.db);

  /// Get cached rate for specific date
  Future<ExchangeRateData?> getRate(
    String baseCurrency,
    String quoteCurrency,
    DateTime date,
  ) {
    // Normalise date to midnight for comparison
    final normalisedDate = DateTime(date.year, date.month, date.day);

    return (select(exchangeRates)
          ..where((r) =>
              r.baseCurrency.equals(baseCurrency) &
              r.quoteCurrency.equals(quoteCurrency) &
              r.rateDate.equals(normalisedDate)))
        .getSingleOrNull();
  }

  /// Get most recent rate (fallback)
  Future<ExchangeRateData?> getMostRecent(
    String baseCurrency,
    String quoteCurrency,
  ) {
    return (select(exchangeRates)
          ..where((r) =>
              r.baseCurrency.equals(baseCurrency) &
              r.quoteCurrency.equals(quoteCurrency))
          ..orderBy([(r) => OrderingTerm.desc(r.rateDate)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Cache a new rate
  Future<void> cacheRate(ExchangeRatesCompanion entry) {
    return into(exchangeRates).insertOnConflictUpdate(entry);
  }
}
