import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/shared_providers.dart';

class DashboardSummaryCards extends ConsumerWidget {
  const DashboardSummaryCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCard(
                theme: theme,
                title: 'Total Spent',
                value: '$baseCurrency ${summary.totalSpent.toStringAsFixed(2)}',
                subtitle: '${summary.transactionCount} transactions',
                color: theme.colorScheme.primaryContainer,
                onColor: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCard(
                theme: theme,
                title: 'Net Income',
                value: '$baseCurrency ${summary.netIncome.toStringAsFixed(2)}',
                subtitle: 'Total Net Flow',
                color: theme.colorScheme.tertiaryContainer,
                onColor: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildCard(
          theme: theme,
          title: 'Top Category',
          value: summary.topCategoryName,
          subtitle: '$baseCurrency ${summary.topCategoryAmount.toStringAsFixed(2)} spent',
          color: theme.colorScheme.secondaryContainer,
          onColor: theme.colorScheme.onSecondaryContainer,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildCard({
    required ThemeData theme,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color onColor,
    bool isFullWidth = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(color: onColor),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: onColor,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: onColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
