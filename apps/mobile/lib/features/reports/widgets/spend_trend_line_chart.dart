import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/reports_providers.dart';

/// PRD §14 — Line chart showing cumulative spend trend over time.
class SpendTrendLineChart extends ConsumerWidget {
  const SpendTrendLineChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendPoints = ref.watch(trendSpendProvider);
    final theme = Theme.of(context);

    if (trendPoints.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('No trend data available.',
              style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final maxY = trendPoints.isNotEmpty
        ? trendPoints.last.cumulativeAmount
        : 0.0;

    // Decide label frequency based on number of points
    final labelEvery = trendPoints.length <= 7
        ? 1
        : trendPoints.length <= 14
            ? 2
            : trendPoints.length <= 31
                ? 5
                : 10;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final point = trendPoints[spot.x.toInt()];
                  return LineTooltipItem(
                    '${DateFormat.MMMd().format(point.date)}\n',
                    TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: spot.y.toStringAsFixed(2),
                        style: TextStyle(
                          color: theme.colorScheme.onInverseSurface,
                          fontWeight: FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
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
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
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
                  if (idx < 0 || idx >= trendPoints.length) {
                    return const SizedBox.shrink();
                  }
                  if (idx % labelEvery != 0 &&
                      idx != trendPoints.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat.Md().format(trendPoints[idx].date),
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (trendPoints.length - 1).toDouble(),
          minY: 0,
          maxY: maxY * 1.15,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                trendPoints.length,
                (i) => FlSpot(i.toDouble(), trendPoints[i].cumulativeAmount),
              ),
              isCurved: true,
              color: theme.colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.3),
                    theme.colorScheme.primary.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
