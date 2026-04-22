import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/period_selector.dart';
import '../../shared/providers/shared_providers.dart';
import '../widgets/category_donut_chart.dart';

class DashboardDetailScreen extends ConsumerStatefulWidget {
  const DashboardDetailScreen({super.key});

  @override
  ConsumerState<DashboardDetailScreen> createState() => _DashboardDetailScreenState();
}

class _DashboardDetailScreenState extends ConsumerState<DashboardDetailScreen> {
  final Set<String> _excludedCategoryIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
    final expenses = ref.watch(expenseListProvider);

    // Get unique categories actively used in current period's expenses
    final activeCategoryIds = expenses
        .where((e) => e.categoryId != null)
        .map((e) => e.categoryId!)
        .toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: PeriodSelector(),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Builder(
                builder: (context) {
                  final filteredExpenses = expenses.where((e) => !_excludedCategoryIds.contains(e.categoryId));
                  final totalSpent = filteredExpenses.fold(0.0, (sum, e) => sum + e.amountBase);
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Spent',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${totalSpent.toStringAsFixed(2)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${filteredExpenses.length} transactions',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
            ),
          ),
          
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
                      CategoryDonutChart(excludedCategoryIds: _excludedCategoryIds),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Categories',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),

          if (activeCategoryIds.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text('No categories in this period.', style: theme.textTheme.bodyMedium),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final catId = activeCategoryIds.elementAt(index);
                  final category = categories.where((c) => c.id == catId).firstOrNull;
                  final name = category?.name ?? 'Unknown Category';
                  final isExcluded = _excludedCategoryIds.contains(catId);

                  Color catColor = Colors.grey;
                  if (category != null && category.colourHex.startsWith('#')) {
                    try {
                       catColor = Color(int.parse(category.colourHex.substring(1, 7), radix: 16) + 0xFF000000);
                    } catch (_) {}
                  }

                  return CheckboxListTile(
                    title: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: catColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(name),
                      ],
                    ),
                    value: !isExcluded,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _excludedCategoryIds.remove(catId);
                        } else {
                          _excludedCategoryIds.add(catId);
                        }
                      });
                    },
                  );
                },
                childCount: activeCategoryIds.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }
}
