import 'package:flutter/material.dart';

import '../providers/wallet_providers.dart';

class CurrencyCard extends StatelessWidget {
  final CurrencyCardData data;
  final String baseCurrency;
  final VoidCallback onTap;

  const CurrencyCard({
    super.key,
    required this.data,
    required this.baseCurrency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBase = data.currency == baseCurrency;
    final isNegative = data.latestBalance < 0;

    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    data.currency,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isBase)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Base',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data.currency} ${data.latestBalance.toStringAsFixed(2)}',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: isNegative ? theme.colorScheme.error : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isBase) ...[
                        const SizedBox(height: 4),
                        Text(
                          '≈ $baseCurrency ${data.baseEquivalent.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              // Simplified Breakdown / Sparkline placeholder
              // TODO: Integrate actual breakdown stats from individual Currency Detail logic
              LinearProgressIndicator(
                value: 0.5,
                backgroundColor: theme.colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('In: +0.00', style: theme.textTheme.bodySmall),
                  Text('Spent: -0.00', style: theme.textTheme.bodySmall),
                  Text('Exchanged: 0.00', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
