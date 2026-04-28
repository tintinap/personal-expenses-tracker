import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../../transactions/widgets/transaction_bottom_sheet.dart';

/// Provider to fetch the paired exchange transaction.
/// Key is "exchangeEventId|currentTxId".
final _pairedTransactionProvider =
    FutureProvider.family<TransactionData?, String>((ref, key) async {
  final parts = key.split('|');
  if (parts.length != 2) return null;
  final dao = ref.watch(transactionDaoProvider);
  return dao.getPairedTransaction(parts[0], parts[1]);
});

/// Reusable transaction list tile with swipe-to-edit (right) and swipe-to-delete (left).
/// Renders exchange transactions as a single merged tile showing both currencies.
/// Used by HomeScreen and CurrencyDetailScreen.
class TransactionListTile extends ConsumerWidget {
  final TransactionData transaction;

  const TransactionListTile({super.key, required this.transaction});

  bool get _isExchange =>
      transaction.transactionType == 'currency_exchange_out' ||
      transaction.transactionType == 'currency_exchange_in';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tx = transaction;

    // For exchange transactions, fetch the paired transaction
    TransactionData? pairedTx;
    if (_isExchange && tx.exchangeEventId != null) {
      final pairedAsync = ref.watch(
        _pairedTransactionProvider('${tx.exchangeEventId}|${tx.id}'),
      );
      pairedTx = pairedAsync.valueOrNull;
    }

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Colors.blue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right -> Edit
          TransactionBottomSheet.show(
            context,
            transaction: tx,
            pairedTransaction: pairedTx,
          );
          return false; // Don't dismiss the item visually
        }

        // Swipe left -> Delete
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Transaction'),
              content: const Text(
                  'Are you sure you want to delete this transaction?'),
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
        if (direction == DismissDirection.endToStart) {
          final dao = ref.read(transactionDaoProvider);
          final db = ref.read(databaseProvider);
          await dao.softDelete(tx.id);
          // Also soft-delete the paired exchange transaction
          if (_isExchange && pairedTx != null) {
            await dao.softDelete(pairedTx.id);
          }
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
        }
      },
      child: _isExchange
          ? _buildExchangeTile(theme, tx, pairedTx)
          : _buildStandardTile(theme, tx),
    );
  }

  Widget _buildStandardTile(ThemeData theme, TransactionData tx) {
    final isIncome = tx.transactionType == 'currency_income';
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
      title:
          Text(tx.note?.isNotEmpty == true ? tx.note! : tx.transactionType),
      subtitle: Text(DateFormat.jm().format(tx.transactionDate)),
      trailing: Text(
        '$prefix ${tx.originalCurrency} ${tx.originalAmount.toStringAsFixed(2)}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildExchangeTile(
      ThemeData theme, TransactionData tx, TransactionData? pairedTx) {
    // Determine out (source) and in (target) sides
    final isOut = tx.transactionType == 'currency_exchange_out';
    final outTx = isOut ? tx : pairedTx;
    final inTx = isOut ? pairedTx : tx;

    final fromCurrency = outTx?.originalCurrency ?? tx.originalCurrency;
    final fromAmount = outTx?.originalAmount ?? tx.originalAmount;
    final toCurrency = inTx?.originalCurrency;
    final toAmount = inTx?.originalAmount;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.tertiaryContainer,
        child: Icon(
          Icons.currency_exchange,
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
      title: Text(
        tx.note?.isNotEmpty == true
            ? tx.note!
            : toCurrency != null
                ? '$fromCurrency → $toCurrency'
                : 'Exchange',
      ),
      subtitle: Text(DateFormat.jm().format(tx.transactionDate)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '- $fromCurrency ${fromAmount.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (toCurrency != null && toAmount != null)
            Text(
              '+ $toCurrency ${toAmount.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
