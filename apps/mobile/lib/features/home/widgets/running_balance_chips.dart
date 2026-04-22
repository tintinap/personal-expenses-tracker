import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/shared_providers.dart';

/// PRD §11c — Horizontally scrollable balance chips for currencies with non-zero balances
class RunningBalanceChips extends ConsumerWidget {
  const RunningBalanceChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(currencyBalancesProvider);
    final theme = Theme.of(context);

    return balancesAsync.when(
      data: (balances) {
        if (balances.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: balances.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == balances.length) {
                // "See all" chip
                return ActionChip(
                  label: const Text('See all'),
                  avatar: const Icon(Icons.arrow_forward, size: 16),
                  onPressed: () => context.go('/wallets'),
                );
              }

              final balance = balances[index];
              return InputChip(
                label: Text('${balance.currency} ${balance.balance.toStringAsFixed(2)}'),
                labelStyle: TextStyle(
                  color: balance.balance < 0 ? theme.colorScheme.error : null,
                  fontWeight: FontWeight.w500,
                ),
                onPressed: () => context.go('/wallets/${balance.currency}'),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
