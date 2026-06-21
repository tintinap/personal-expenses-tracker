import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/shared_providers.dart';
import '../../shared/widgets/period_selector.dart';
import '../../home/widgets/category_donut_chart.dart';
import '../../home/widgets/category_transactions_sheet.dart';
import '../widgets/spend_bar_chart.dart';
import '../widgets/spend_trend_line_chart.dart';
import '../widgets/period_comparison_card.dart';
import '../widgets/category_spend_list.dart';

/// PRD §14 — Main Reports Screen showing period charts and comparisons.
/// This screen is body-only (no Scaffold/AppBar) as it's owned by ScaffoldWithNavBar.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final baseCurrency = ref.watch(baseCurrencyProvider);

    return CustomScrollView(
      slivers: [
        // Period Selector
        const SliverToBoxAdapter(
          child: PeriodSelector(),
        ),

        // Period Comparison Card
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: PeriodComparisonCard(),
          ),
        ),

        // Spend by Category Donut Chart
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Spend by Category',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CategoryDonutChart(
                      excludedCategoryIds: const {},
                      onSliceTap: (parentId) => CategoryTransactionsSheet.show(
                        context,
                        parentCategoryId: parentId,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Daily Spend Bar Chart
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Daily Spend',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SpendBarChart(),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Cumulative Spend Trend Chart
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cumulative Trend',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SpendTrendLineChart(),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Category Spend List
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Category Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: CategorySpendList(),
        ),

        // Bottom padding for FAB clearance
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }
}
