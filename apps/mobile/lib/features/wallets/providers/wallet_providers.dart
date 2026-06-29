import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/transaction_dao.dart' show CurrencyBreakdown;
import '../../../core/providers/database_providers.dart';
import '../../shared/providers/shared_providers.dart';

class CurrencyPortfolio {
  final double totalBaseEquivalent;
  final String baseCurrency;
  final List<CurrencyCardData> cards;

  const CurrencyPortfolio({
    required this.totalBaseEquivalent,
    required this.baseCurrency,
    required this.cards,
  });
}

class CurrencyCardData {
  final String currency;
  final double latestBalance;
  final double baseEquivalent;
  final CurrencyBreakdown breakdown;

  const CurrencyCardData({
    required this.currency,
    required this.latestBalance,
    required this.baseEquivalent,
    this.breakdown = const CurrencyBreakdown(),
  });
}

/// Provider that calculates the total portfolio value using the latest
/// exchange rates and orders the cards by user activity.
///
/// Sort order:
///   1. Base currency (always first)
///   2. Highest `transaction count` (descending)
///   3. Tie-break: highest base-currency equivalent (descending)
final portfolioProvider = FutureProvider<CurrencyPortfolio>((ref) async {
  final balancesAsync = ref.watch(currencyBalancesProvider);

  if (balancesAsync.hasError) {
    throw balancesAsync.error!;
  }

  final balances = balancesAsync.valueOrNull ?? const [];
  final erDao = ref.watch(exchangeRateDaoProvider);
  final baseCurrency = ref.watch(baseCurrencyProvider);
  final txCounts =
      ref.watch(transactionCountByCurrencyProvider).valueOrNull ?? const {};
  final breakdowns =
      ref.watch(currencyBreakdownProvider).valueOrNull ?? const {};

  double totalValue = 0.0;
  final List<CurrencyCardData> cards = [];

  for (final b in balances) {
    double equivalent = b.balance;

    if (b.currency != baseCurrency) {
      // rate represents: 1 Base = X Quote ⇒ equivalent = balance / rate
      final rate = await erDao.getMostRecentOrFetch(baseCurrency, b.currency);
      if (rate > 0) {
        equivalent = b.balance / rate;
      }
    }

    totalValue += equivalent;
    cards.add(CurrencyCardData(
      currency: b.currency,
      latestBalance: b.balance,
      baseEquivalent: equivalent,
      breakdown: breakdowns[b.currency] ?? const CurrencyBreakdown(),
    ));
  }

  cards.sort((a, b) {
    if (a.currency == baseCurrency) return -1;
    if (b.currency == baseCurrency) return 1;

    final countA = txCounts[a.currency] ?? 0;
    final countB = txCounts[b.currency] ?? 0;
    if (countA != countB) return countB.compareTo(countA);

    return b.baseEquivalent.compareTo(a.baseEquivalent);
  });

  return CurrencyPortfolio(
    totalBaseEquivalent: totalValue,
    baseCurrency: baseCurrency,
    cards: cards,
  );
});
