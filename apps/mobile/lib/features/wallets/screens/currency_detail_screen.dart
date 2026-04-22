import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
                      onTap: () => TransactionBottomSheet.show(context, transaction: tx),
                    );
                  },
                  childCount: transactions.length,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
