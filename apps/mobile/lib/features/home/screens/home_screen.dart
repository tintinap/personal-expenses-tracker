import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
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

                // Sort transactions by date descending
                final sortedTransactions = List.of(transactions)
                  ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

                // Group transactions by date
                final listItems = [];
                String? lastDateStr;
                
                for (final tx in sortedTransactions) {
                  final dateStr = DateFormat.yMMMd().format(tx.transactionDate);
                  if (dateStr != lastDateStr) {
                    listItems.add(dateStr); // Add date header
                    lastDateStr = dateStr;
                  }
                  listItems.add(tx);
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = listItems[index];
                      
                      if (item is String) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                item,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Divider(
                                  color: theme.colorScheme.primary.withOpacity(0.2),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      final tx = item;
                      final isIncome = tx.transactionType == 'currency_income' || 
                                       tx.transactionType == 'currency_exchange_in';
                      final color = isIncome ? Colors.green : theme.textTheme.bodyLarge?.color;
                      final prefix = isIncome ? '+' : '-';
                      
                      return Dismissible(
                        key: ValueKey(tx.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20.0),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Delete Transaction'),
                                content: const Text('Are you sure you want to delete this transaction?'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) async {
                          final dao = ref.read(transactionDaoProvider);
                          final db = ref.read(databaseProvider);
                          await dao.softDelete(tx.id);
                          await db.addToSyncQueue(
                            id: const Uuid().v4(),
                            recordType: 'transaction',
                            recordId: tx.id,
                            operation: 'delete',
                            payload: '{}',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Transaction deleted')),
                            );
                          }
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              isIncome ? Icons.arrow_downward : Icons.shopping_bag,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          title: Text(tx.note?.isNotEmpty == true ? tx.note! : tx.transactionType),
                          subtitle: Text(DateFormat.jm().format(tx.transactionDate)),
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
                        ),
                      );
                    },
                    childCount: listItems.length,
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
