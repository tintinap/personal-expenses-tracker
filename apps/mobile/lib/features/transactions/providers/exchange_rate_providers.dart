import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/providers/database_providers.dart';
import '../repositories/exchange_rate_repository.dart';

/// Provider for the ExchangeRateRepository singleton
final exchangeRateRepositoryProvider = Provider<ExchangeRateRepository>((ref) {
  return ExchangeRateRepository(
    dao: ref.watch(exchangeRateDaoProvider),
    dio: ref.watch(dioProvider),
  );
});

/// Parameters for the recommended rate provider
class RateParams {
  final String baseCurrency;
  final String quoteCurrency;
  final DateTime date;

  const RateParams({
    required this.baseCurrency,
    required this.quoteCurrency,
    required this.date,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RateParams &&
          runtimeType == other.runtimeType &&
          baseCurrency == other.baseCurrency &&
          quoteCurrency == other.quoteCurrency &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day;

  @override
  int get hashCode =>
      baseCurrency.hashCode ^
      quoteCurrency.hashCode ^
      DateTime(date.year, date.month, date.day).hashCode;
}

/// FutureProvider.family to fetch recommended exchange rate.
/// Returns an [ExchangeRateResult] or throws on total failure.
final recommendedRateProvider =
    FutureProvider.autoDispose.family<ExchangeRateResult, RateParams>(
  (ref, params) {
    final repo = ref.watch(exchangeRateRepositoryProvider);
    return repo.getRecommendedRate(
      baseCurrency: params.baseCurrency,
      quoteCurrency: params.quoteCurrency,
      date: params.date,
    );
  },
);
