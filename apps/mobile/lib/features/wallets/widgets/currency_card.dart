import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../providers/wallet_providers.dart';

/// PRD §11c — Currency Wallets card.
///
/// Shows the per-currency balance, base-currency equivalent, a "spent ratio"
/// progress bar, and the income / spent / exchanged breakdown.
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

  static final NumberFormat _amountFmt = NumberFormat('#,##0.00');

  String _formatSigned(double value) {
    if (value == 0) return '0.00';
    final sign = value > 0 ? '+' : '-';
    return '$sign${_amountFmt.format(value.abs())}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBase = data.currency == baseCurrency;
    final isNegative = data.latestBalance < 0;

    final breakdown = data.breakdown;

    // Bucket cash flows. Exchange-in counts as income, exchange-out as spend
    // — so the bar reflects "did I net more than I parted with this currency?".
    final exchangeIn =
        breakdown.netExchanged > 0 ? breakdown.netExchanged : 0.0;
    final exchangeOut =
        breakdown.netExchanged < 0 ? -breakdown.netExchanged : 0.0;
    final inflow = breakdown.totalIn + exchangeIn;
    final outflow = breakdown.totalSpent + exchangeOut;
    final flowMagnitude = inflow > outflow ? inflow : outflow;
    // Range: -1 (pure deficit) … 0 (balanced) … +1 (pure surplus).
    final flowRatio = flowMagnitude > 0
        ? ((inflow - outflow) / flowMagnitude).clamp(-1.0, 1.0)
        : 0.0;

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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data.currency} ${_amountFmt.format(data.latestBalance)}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color:
                                isNegative ? theme.colorScheme.error : null,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!isBase) ...[
                          const SizedBox(height: 4),
                          Text(
                            '≈ $baseCurrency ${_amountFmt.format(data.baseEquivalent)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              _SignedFlowBar(ratio: flowRatio),
              const SizedBox(height: 8),
              _BreakdownRow(
                totalIn: breakdown.totalIn,
                totalSpent: breakdown.totalSpent,
                netExchanged: breakdown.netExchanged,
                formatter: _amountFmt,
                signedFormatter: _formatSigned,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final double totalIn;
  final double totalSpent;
  final double netExchanged;
  final NumberFormat formatter;
  final String Function(double) signedFormatter;

  const _BreakdownRow({
    required this.totalIn,
    required this.totalSpent,
    required this.netExchanged,
    required this.formatter,
    required this.signedFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget cell(String label, String value, {Color? valueColor}) {
      return Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              style: labelStyle,
              children: [
                TextSpan(text: '$label: '),
                TextSpan(
                  text: value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: valueColor ?? theme.colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        cell(
          'In',
          totalIn > 0 ? '+${formatter.format(totalIn)}' : '0.00',
          valueColor: totalIn > 0 ? Colors.green.shade700 : null,
        ),
        cell(
          'Spent',
          totalSpent > 0 ? '-${formatter.format(totalSpent)}' : '0.00',
          valueColor: totalSpent > 0 ? theme.colorScheme.error : null,
        ),
        cell(
          'Exchanged',
          signedFormatter(netExchanged),
          valueColor: netExchanged == 0
              ? null
              : (netExchanged > 0
                  ? Colors.green.shade700
                  : theme.colorScheme.error),
        ),
      ],
    );
  }
}

/// Edge-anchored signed progress bar. [ratio] must be in `[-1.0, 1.0]`.
///
/// - `ratio >= 0` (surplus): fills from the **left** in primary.
/// - `ratio <  0` (deficit): fills from the **right** in error.
/// - `|ratio|` controls the fill width as a fraction of the track.
class _SignedFlowBar extends StatelessWidget {
  final double ratio;

  const _SignedFlowBar({required this.ratio});

  static const double _height = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = ratio.clamp(-1.0, 1.0);
    final isSurplus = clamped >= 0;
    final fillFraction = clamped.abs();
    final fillColour =
        isSurplus ? theme.colorScheme.primary : theme.colorScheme.error;
    final trackColour = theme.colorScheme.surfaceContainerHighest;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: _height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: trackColour)),
            if (fillFraction > 0)
              Align(
                alignment: isSurplus
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: fillFraction,
                  heightFactor: 1,
                  child: ColoredBox(color: fillColour),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
