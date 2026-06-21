import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/database_providers.dart';
import '../providers/budget_providers.dart';
import '../widgets/budget_card.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressListAsync = ref.watch(budgetProgressListProvider);
    final theme = Theme.of(context);

    return progressListAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (progressList) {
          if (progressList.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.savings_outlined, size: 64, color: theme.colorScheme.surfaceContainerHighest),
                  const SizedBox(height: 16),
                  Text('No active budgets', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text('Tap the + button in the top bar to create one', style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Active Budgets',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final prog = progressList[index];
                      String? catName;
                      if (prog.budget.scopeType == 'include') {
                        catName = prog.categoryNames.join(', ');
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: BudgetCard(
                          progress: prog,
                          categoryName: catName,
                          onTap: () => context.go('/budgets/${prog.budget.id}'),
                          onDelete: () => ref
                              .read(budgetDaoProvider)
                              .deleteBudget(prog.budget.id),
                        ),
                      );
                    },
                    childCount: progressList.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
    );
  }
}
