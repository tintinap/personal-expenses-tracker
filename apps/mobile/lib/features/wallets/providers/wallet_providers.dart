import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/database/database.dart';
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
  
  const CurrencyCardData({
    required this.currency,
    required this.latestBalance,
    required this.baseEquivalent,
  });
}

/// Provider that calculates the total portfolio value using the latest exchange rates
final portfolioProvider = FutureProvider<CurrencyPortfolio>((ref) async {
  final balancesAsync = ref.watch(currencyBalancesProvider);
  
  if (balancesAsync.hasError) {
    throw balancesAsync.error!;
  }
  
  final balances = balancesAsync.valueOrNull ?? [];
  final erDao = ref.watch(exchangeRateDaoProvider);
  
  // TODO: get from real settings provider once implemented
  const baseCurrency = 'AUD'; 
  
  double totalValue = 0.0;
  final List<CurrencyCardData> cards = [];

  for (final b in balances) {
    double equivalent = b.balance;
    
    if (b.currency != baseCurrency) {
      // Find latest rate
      final rate = await erDao.getMostRecent(baseCurrency, b.currency);
      // rate represents: 1 Base = X Quote
      // So equivalent = balance / rate
      if (rate != null && rate.rate > 0) {
        equivalent = b.balance / rate.rate;
      } else {
        // Fallback: try to fetch directly from public API
        try {
          final publicDio = Dio(); // bypass auth interceptors
          final res = await publicDio.get('https://api.frankfurter.app/latest', queryParameters: {
            'from': baseCurrency,
            'to': b.currency,
          });
          
          if (res.data != null && res.data['rates'] != null && res.data['rates'][b.currency] != null) {
            final rateValue = (res.data['rates'][b.currency] as num).toDouble();
            final now = DateTime.now();
            final dateOnly = DateTime(now.year, now.month, now.day);
            
            await erDao.cacheRate(ExchangeRatesCompanion.insert(
              id: 'er-${baseCurrency}-${b.currency}-${dateOnly.millisecondsSinceEpoch}',
              baseCurrency: baseCurrency,
              quoteCurrency: b.currency,
              rateDate: dateOnly,
              rate: rateValue,
            ));
            
            equivalent = b.balance / rateValue;
          } else {
            equivalent = b.balance;
          }
        } catch (e) {
          // If completely failed, assume parity
          equivalent = b.balance; 
        }
      }
    }
    
    totalValue += equivalent;
    cards.add(CurrencyCardData(
      currency: b.currency,
      latestBalance: b.balance,
      baseEquivalent: equivalent,
    ));
  }
  
  // Sort cards: base currency first, then by largest equivalent descending
  cards.sort((a, b) {
    if (a.currency == baseCurrency) return -1;
    if (b.currency == baseCurrency) return 1;
    return b.baseEquivalent.compareTo(a.baseEquivalent);
  });

  return CurrencyPortfolio(
    totalBaseEquivalent: totalValue,
    baseCurrency: baseCurrency,
    cards: cards,
  );
});
