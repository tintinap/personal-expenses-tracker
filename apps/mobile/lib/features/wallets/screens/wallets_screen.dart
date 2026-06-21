import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/shared_providers.dart';
import '../providers/wallet_providers.dart';
import '../widgets/currency_card.dart';

/// PRD §11c — Currency Wallets Screen
class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioAsync = ref.watch(portfolioProvider);
    final viewCurrency = ref.watch(viewCurrencyProvider);
    final viewRate = ref.watch(viewCurrencyRateProvider).valueOrNull ?? 1.0;
    
    final theme = Theme.of(context);

    return portfolioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading portfolio: $err')),
        data: (portfolio) {
          if (portfolio.cards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 80, color: theme.colorScheme.primary.withOpacity(0.4)),
                    const SizedBox(height: 24),
                    Text('No currencies yet', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Start by adding an income or expense transaction. Each currency you use will appear here automatically.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // Total Portfolio Value
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Total Net Worth',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${portfolio.baseCurrency} ${portfolio.totalBaseEquivalent.toStringAsFixed(2)}',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (portfolio.baseCurrency != viewCurrency) ...[
                            const SizedBox(height: 4),
                            Text(
                              '≈ $viewCurrency ${(portfolio.totalBaseEquivalent * viewRate).toStringAsFixed(2)}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            '(converted at latest rates)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // All Currencies (including negative and zero balances)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final cardData = portfolio.cards[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: CurrencyCard(
                          data: cardData,
                          baseCurrency: portfolio.baseCurrency,
                          onTap: () => context.push('/wallets/${cardData.currency}'),
                        ),
                      );
                    },
                    childCount: portfolio.cards.length,
                  ),
                ),
              ),
                
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
    );
  }
}
