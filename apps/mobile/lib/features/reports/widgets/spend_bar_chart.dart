import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/reports_providers.dart';

/// PRD §14 — Bar chart showing daily spend within the selected period.
class SpendBarChart extends ConsumerWidget {
  const SpendBarChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailySpend = ref.watch(dailySpendAggregateProvider);
    final theme = Theme.of(context);

    if (dailySpend.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('No expenses in this period.',
              style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final sortedDays = dailySpend.keys.toList()..sort();
    final maxY = dailySpend.values.reduce((a, b) => a > b ? a : b);

    // Decide label frequency based on number of days
    final labelEvery = sortedDays.length <= 7
        ? 1
        : sortedDays.length <= 14
            ? 2
            : sortedDays.length <= 31
                ? 5
                : 10;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.15,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final day = sortedDays[group.x.toInt()];
                return BarTooltipItem(
                  '${DateFormat.MMMd().format(day)}\n',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: rod.toY.toStringAsFixed(2),
                      style: TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontWeight: FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      value.toInt().toString(),
                      style: theme.textTheme.labelSmall,
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= sortedDays.length) {
                    return const SizedBox.shrink();
                  }
                  if (idx % labelEvery != 0 &&
                      idx != sortedDays.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat.Md().format(sortedDays[idx]),
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(sortedDays.length, (i) {
            final day = sortedDays[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: dailySpend[day]!,
                  color: theme.colorScheme.primary,
                  width: sortedDays.length > 20 ? 6 : 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
