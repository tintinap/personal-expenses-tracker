import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../wallets/providers/wallet_providers.dart';

/// PRD §11c — Horizontally scrollable balance chips for currencies with
/// non-zero balances.
///
/// Reuses [portfolioProvider] so the chip order matches the Wallets screen
/// exactly (base currency first → most transactions → highest base-currency
/// equivalent).
class RunningBalanceChips extends ConsumerWidget {
  const RunningBalanceChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolioAsync = ref.watch(portfolioProvider);
    final theme = Theme.of(context);

    return portfolioAsync.when(
      data: (portfolio) {
        if (portfolio.cards.isEmpty) return const SizedBox.shrink();

        final cards = portfolio.cards;

        return SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: cards.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == cards.length) {
                return ActionChip(
                  label: const Text('See all'),
                  avatar: const Icon(Icons.arrow_forward, size: 16),
                  onPressed: () => context.go('/wallets'),
                );
              }

              final card = cards[index];
              return InputChip(
                label: Text(
                  '${card.currency} ${card.latestBalance.toStringAsFixed(2)}',
                ),
                labelStyle: TextStyle(
                  color: card.latestBalance < 0
                      ? theme.colorScheme.error
                      : null,
                  fontWeight: FontWeight.w500,
                ),
                onPressed: () => context.push('/wallets/${card.currency}'),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
