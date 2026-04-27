import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../../shared/providers/shared_providers.dart';
import '../../transactions/widgets/transaction_bottom_sheet.dart';

final currencyTransactionsProvider = StreamProvider.family<List<TransactionData>, String>((ref, currency) {
  final dao = ref.watch(transactionDaoProvider);
  return Stream.fromFuture(dao.getByCurrency(currency)); 
  // Ideally this would be watchByCurrency in the dao, but we'll use Stream.fromFuture with getByCurrency for simplicity, 
  // or add a watch method to the DAO later
});

class CurrencyDetailScreen extends ConsumerWidget {
  final String currency;

  const CurrencyDetailScreen({super.key, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactionsAsync = ref.watch(currencyTransactionsProvider(currency));

    return Scaffold(
      appBar: AppBar(
        title: Text('$currency Wallet'),
      ),
      body: CustomScrollView(
        slivers: [
          // Balance Header
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) {
                final balances = ref.watch(currencyBalancesProvider).valueOrNull ?? [];
                final balanceData = balances.where((b) => b.currency == currency).firstOrNull;
                final balance = balanceData?.balance ?? 0.0;
                
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: theme.colorScheme.surfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Current Balance', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            '$currency ${balance.toStringAsFixed(2)}',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: balance < 0 ? theme.colorScheme.error : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // List Header
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Transaction History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Transaction List
          transactionsAsync.when(
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (err, _) => SliverFillRemaining(child: Center(child: Text('Error: $err'))),
            data: (transactions) {
              if (transactions.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: Text('No transactions found for this currency.')),
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
                    
                    final tx = item as TransactionData;
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
                        onTap: () => TransactionBottomSheet.show(context, transaction: tx),
                      ),
                    );
                  },
                  childCount: listItems.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
