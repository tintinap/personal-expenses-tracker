import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/shared_providers.dart';
import '../providers/reports_providers.dart';

/// PRD §14 — Period comparison card showing this period vs previous period delta.
class PeriodComparisonCard extends ConsumerWidget {
  const PeriodComparisonCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comparison = ref.watch(periodComparisonProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final viewCurrency = ref.watch(viewCurrencyProvider);
    final viewRate = ref.watch(viewCurrencyRateProvider).valueOrNull ?? 1.0;
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatColumn(
                    label: 'This Period',
                    amount: comparison.currentTotal,
                    currency: baseCurrency,
                    viewCurrency: viewCurrency,
                    viewRate: viewRate,
                    isHighlight: true,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outlineVariant,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                Expanded(
                  child: _StatColumn(
                    label: 'Previous',
                    amount: comparison.previousTotal,
                    currency: baseCurrency,
                    viewCurrency: viewCurrency,
                    viewRate: viewRate,
                    isHighlight: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (!comparison.hasPreviousData)
              Text(
                'No data from previous period to compare.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              _DeltaRow(comparison: comparison, baseCurrency: baseCurrency),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final double amount;
  final String currency;
  final String viewCurrency;
  final double viewRate;
  final bool isHighlight;

  const _StatColumn({
    required this.label,
    required this.amount,
    required this.currency,
    required this.viewCurrency,
    required this.viewRate,
    required this.isHighlight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$currency ${amount.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            color: isHighlight
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (currency != viewCurrency) ...[
          const SizedBox(height: 2),
          Text(
            '≈ $viewCurrency ${(amount * viewRate).toStringAsFixed(2)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _DeltaRow extends StatelessWidget {
  final PeriodComparison comparison;
  final String baseCurrency;

  const _DeltaRow({
    required this.comparison,
    required this.baseCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Green = spent less (good). Red = spent more (bad).
    final isDecrease = comparison.absoluteDiff < 0;
    final isIncrease = comparison.absoluteDiff > 0;
    final isSame = comparison.absoluteDiff == 0;

    Color color = theme.colorScheme.onSurfaceVariant;
    IconData? icon;
    String text = 'Same as previous period';

    if (isDecrease) {
      color = Colors.green.shade600;
      icon = Icons.arrow_downward;
      text = 'Spent less than previous period';
    } else if (isIncrease) {
      color = Colors.red.shade600;
      icon = Icons.arrow_upward;
      text = 'Spent more than previous period';
    }

    // Use dark mode friendly colors if needed
    if (theme.brightness == Brightness.dark) {
      if (isDecrease) color = Colors.green.shade400;
      if (isIncrease) color = Colors.red.shade400;
    }

    final diffAbs = comparison.absoluteDiff.abs();
    final percentStr = (comparison.percentDiff.abs() * 100).toStringAsFixed(1);

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSame
                    ? text
                    : '$baseCurrency ${diffAbs.toStringAsFixed(2)} ($percentStr%)',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isSame)
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
