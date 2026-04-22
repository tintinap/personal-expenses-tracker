import 'package:flutter/material.dart';

import '../providers/budget_providers.dart';

class BudgetCard extends StatelessWidget {
  final BudgetProgress progress;
  final String? categoryName;
  final VoidCallback onTap;

  const BudgetCard({
    super.key,
    required this.progress,
    this.categoryName,
    required this.onTap,
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

    final title = progress.budget.scope == 'global' 
        ? 'Global Budget' 
        : (categoryName ?? 'Category Budget');

    return Card(
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
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      progress.budget.periodType.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${progress.spentAmount.toStringAsFixed(2)} spent',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    '\$${progress.limitAmount.toStringAsFixed(2)} limit',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.percentageUsed.clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.surfaceVariant,
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
}
