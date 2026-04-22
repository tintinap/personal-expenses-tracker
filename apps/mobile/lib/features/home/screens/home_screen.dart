import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/providers/shared_providers.dart';
import '../../shared/widgets/period_selector.dart';
import '../widgets/dashboard_summary_cards.dart';
import '../widgets/running_balance_chips.dart';
import '../widgets/category_donut_chart.dart';
import '../../transactions/widgets/transaction_bottom_sheet.dart';
import '../../auth/widgets/sign_in_banner.dart';

/// PRD §6 — Home (Dashboard) Screen
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DailySpend'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              context.go('/settings');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // In a real app we might trigger a background sync here
          ref.invalidate(transactionListProvider);
        },
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: SignInBanner(),
            ),

            // Segmented Period Selector
            const SliverToBoxAdapter(
              child: PeriodSelector(),
            ),

            // Summary Cards 
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: DashboardSummaryCards(),
              ),
            ),

            // Mini Dashboard Chart (Tappable)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: InkWell(
                  onTap: () => context.go('/dashboard-detail'),
                  borderRadius: BorderRadius.circular(12),
                  child: Card(
                    color: theme.colorScheme.surfaceContainerHighest,
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Spend by Category',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Making it miniature
                          const SizedBox(
                            height: 150,
                            child: CategoryDonutChart(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Running Balance Chips
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: RunningBalanceChips(),
              ),
            ),

            // Header for transactions list
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Transactions',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),

            // Transaction List
            transactionsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(child: Text('Error loading transactions:\n$err')),
              ),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: theme.colorScheme.surfaceVariant),
                          const SizedBox(height: 16),
                          Text('No transactions yet', style: theme.textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Tap the + button to add one.', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  );
                }

                // Group transactions by date
                // For simplicity here we just list them flat, but real app group by date
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tx = transactions[index];
                      final isIncome = tx.transactionType == 'currency_income' || 
                                       tx.transactionType == 'currency_exchange_in';
                      final color = isIncome ? Colors.green : theme.textTheme.bodyLarge?.color;
                      final prefix = isIncome ? '+' : '-';
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            isIncome ? Icons.arrow_downward : Icons.shopping_bag,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(tx.note?.isNotEmpty == true ? tx.note! : tx.transactionType),
                        subtitle: Text(DateFormat.yMMMd().format(tx.transactionDate)),
                        trailing: Text(
                          '$prefix ${tx.originalCurrency} ${tx.originalAmount.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          TransactionBottomSheet.show(context, transaction: tx);
                        },
                      );
                    },
                    childCount: transactions.length,
                  ),
                );
              },
            ),
            
            // Padding for FAB
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }
}
