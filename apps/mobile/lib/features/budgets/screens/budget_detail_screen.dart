import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/budget_providers.dart';

class BudgetDetailScreen extends ConsumerWidget {
  final String id;

  const BudgetDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressList = ref.watch(budgetProgressListProvider).valueOrNull ?? [];
    final progress = progressList.where((p) => p.budget.id == id).firstOrNull;
    final theme = Theme.of(context);

    if (progress == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Budget Detail')),
        body: const Center(child: Text('Budget not found')),
      );
    }

    final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
    String? catName;
    if (progress.budget.scope == 'category') {
      catName = categories.where((c) => c.id == progress.budget.categoryId).firstOrNull?.name;
    }

    final title = progress.budget.scope == 'global' 
        ? 'Global Budget' 
        : (catName ?? 'Category Budget');

    Color progressColor = Colors.green;
    if (progress.isCritical) progressColor = Colors.red;
    else if (progress.isWarning) progressColor = Colors.orange;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Open edit budget sheet
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    '${(progress.percentageUsed * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: progressColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('of \$${progress.limitAmount.toStringAsFixed(2)} used', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 24),
                  LinearProgressIndicator(
                    value: progress.percentageUsed.clamp(0.0, 1.0),
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Spent', style: theme.textTheme.bodySmall),
                          Text('\$${progress.spentAmount.toStringAsFixed(2)}', style: theme.textTheme.titleMedium),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Remaining', style: theme.textTheme.bodySmall),
                          Text(
                            '\$${(progress.limitAmount - progress.spentAmount).toStringAsFixed(2)}', 
                            style: theme.textTheme.titleMedium
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          const Text('Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Period Mode'),
            trailing: Text(progress.budget.periodType.toUpperCase()),
          ),
          ListTile(
            title: const Text('Scope'),
            trailing: Text(progress.budget.scope.toUpperCase()),
          ),
        ],
      ),
    );
  }
}
