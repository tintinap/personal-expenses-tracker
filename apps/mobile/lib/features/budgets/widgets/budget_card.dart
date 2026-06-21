import 'package:flutter/material.dart';

import '../providers/budget_providers.dart';

class BudgetCard extends StatelessWidget {
  final BudgetProgress progress;
  final String? categoryName;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const BudgetCard({
    super.key,
    required this.progress,
    this.categoryName,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color progressColor = Colors.green;
    if (progress.isCritical) {
      progressColor = Colors.red;
    } else if (progress.isWarning) {
      progressColor = Colors.orange;
    }

    final title = progress.budget.name?.isNotEmpty == true
        ? progress.budget.name!
        : (progress.budget.scopeType == 'all'
            ? 'Global Budget'
            : (categoryName ?? 'Category Budget'));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      progress.budget.periodType.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error, size: 20),
                      tooltip: 'Delete budget',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmDelete(context),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${progress.budget.currency} ${progress.spentAmount.toStringAsFixed(2)} spent',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    '${progress.budget.currency} ${progress.limitAmount.toStringAsFixed(2)} limit',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.percentageUsed.clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final title = progress.budget.name?.isNotEmpty == true
        ? progress.budget.name!
        : 'this budget';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
