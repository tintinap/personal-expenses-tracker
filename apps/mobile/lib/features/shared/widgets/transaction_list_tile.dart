import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/presentation/category_visuals.dart';
import '../../../core/providers/database_providers.dart';
import '../../shared/providers/shared_providers.dart';
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

/// Reusable transaction tile.
///
/// Slide reveals fixed-width action buttons (does NOT fully dismiss):
/// - Slide right ➜ Edit button (tap to open edit sheet)
/// - Slide left  ➜ Delete button (tap shows confirm dialog, then deletes)
///
/// Tapping the row body opens a dialog showing the transaction's note.
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

    TransactionData? pairedTx;
    if (_isExchange && tx.exchangeEventId != null) {
      final pairedAsync = ref.watch(
        _pairedTransactionProvider('${tx.exchangeEventId}|${tx.id}'),
      );
      pairedTx = pairedAsync.valueOrNull;
    }

    return Slidable(
      key: ValueKey(tx.id),
      groupTag: 'transactions',
      closeOnScroll: true,
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          _buildSquareAction(
            color: Colors.blue,
            icon: Icons.edit,
            label: 'Edit',
            onTap: () => _onEdit(context, tx, pairedTx),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          _buildSquareAction(
            color: Colors.red,
            icon: Icons.delete,
            label: 'Delete',
            onTap: () => _onDelete(context, ref, tx, pairedTx),
          ),
        ],
      ),
      child: _isExchange
          ? _buildExchangeTile(context, ref, theme, tx, pairedTx)
          : _buildStandardTile(context, ref, theme, tx),
    );
  }

  /// Square slide button with an icon + a responsive (auto-shrinking) label.
  /// Using [CustomSlidableAction] so the label can use [FittedBox] and never
  /// clip on narrow screens.
  Widget _buildSquareAction({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return CustomSlidableAction(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: EdgeInsets.zero,
      onPressed: (_) => onTap(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onEdit(
    BuildContext context,
    TransactionData tx,
    TransactionData? pairedTx,
  ) {
    Slidable.of(context)?.close();
    TransactionBottomSheet.show(
      context,
      transaction: tx,
      pairedTransaction: pairedTx,
    );
  }

  Future<void> _onDelete(
    BuildContext context,
    WidgetRef ref,
    TransactionData tx,
    TransactionData? pairedTx,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content:
            const Text('Are you sure you want to delete this transaction?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      if (context.mounted) Slidable.of(context)?.close();
      return;
    }

    final dao = ref.read(transactionDaoProvider);
    final db = ref.read(databaseProvider);

    await dao.softDelete(tx.id);
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

  void _showDetailsDialog(
    BuildContext context,
    TransactionData tx, {
    CategoryData? category,
    CategoryData? parent,
  }) {
    final theme = Theme.of(context);
    final note = tx.note?.trim();
    final isSub = parent != null && category != null;
    final headerCategory = parent ?? category;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          title: Row(
            children: [
              if (headerCategory != null)
                categoryGlyphAvatar(
                  colour: parseHexColour(headerCategory.colourHex),
                  iconCodePoint: headerCategory.iconCodePoint,
                  radius: 18,
                ),
              if (headerCategory != null) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  headerCategory?.name ?? 'Transaction',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSub)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.subdirectory_arrow_right,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      categoryGlyphAvatar(
                        colour: parseHexColour(category.colourHex),
                        iconCodePoint: category.iconCodePoint,
                        radius: 10,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          category.name,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              _kv(
                theme,
                'Date',
                DateFormat.yMMMd().add_jm().format(tx.transactionDate),
              ),
              const SizedBox(height: 6),
              _kv(
                theme,
                'Amount',
                '${tx.originalCurrency} ${tx.originalAmount.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 12),
              Text(
                'Note',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                note != null && note.isNotEmpty
                    ? note
                    : 'No note for this transaction.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }

  /// Returns (display, sub) where display is the parent (or self if top-level)
  /// and sub is non-null only when the transaction is on a sub-category.
  ({CategoryData? display, CategoryData? sub}) _resolveCategoryHierarchy(
    List<CategoryData> categories,
    String? categoryId,
  ) {
    if (categoryId == null) return (display: null, sub: null);
    final cat = categories.where((c) => c.id == categoryId).firstOrNull;
    if (cat == null) return (display: null, sub: null);
    if (cat.parentId == null) return (display: cat, sub: null);
    final parent = categories.where((c) => c.id == cat.parentId).firstOrNull;
    return (display: parent ?? cat, sub: cat);
  }

  String _typeFallbackLabel(String transactionType) {
    switch (transactionType) {
      case 'expense':
        return 'Expense';
      case 'currency_income':
        return 'Income';
      case 'currency_exchange_out':
        return 'Exchange out';
      case 'currency_exchange_in':
        return 'Exchange in';
      default:
        return transactionType;
    }
  }

  Widget _buildStandardTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    TransactionData tx,
  ) {
    final isIncome = tx.transactionType == 'currency_income';
    final color = isIncome ? Colors.green : theme.textTheme.bodyLarge?.color;
    final prefix = isIncome ? '+' : '-';
    final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
    final hierarchy = _resolveCategoryHierarchy(categories, tx.categoryId);
    final display = hierarchy.display;
    final titleText = display?.name ??
        (tx.note?.trim().isNotEmpty == true
            ? tx.note!.trim()
            : _typeFallbackLabel(tx.transactionType));

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: ListTile(
        onTap: () => _showDetailsDialog(
          context,
          tx,
          category: hierarchy.sub ?? display,
          parent: hierarchy.sub != null ? display : null,
        ),
        leading: display != null
            ? categoryGlyphAvatar(
                colour: parseHexColour(display.colourHex),
                iconCodePoint: display.iconCodePoint,
              )
            : CircleAvatar(
                backgroundColor: isIncome
                    ? Colors.green.withValues(alpha: 0.2)
                    : theme.colorScheme.primaryContainer,
                child: Icon(
                  isIncome ? Icons.arrow_downward : Icons.receipt_long,
                  color: isIncome
                      ? Colors.green
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
        title: Text(
          titleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(DateFormat.jm().format(tx.transactionDate)),
        trailing: Text(
          '$prefix ${tx.originalCurrency} ${tx.originalAmount.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeTile(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    TransactionData tx,
    TransactionData? pairedTx,
  ) {
    final isOut = tx.transactionType == 'currency_exchange_out';
    final outTx = isOut ? tx : pairedTx;
    final inTx = isOut ? pairedTx : tx;

    final fromCurrency = outTx?.originalCurrency ?? tx.originalCurrency;
    final fromAmount = outTx?.originalAmount ?? tx.originalAmount;
    final toCurrency = inTx?.originalCurrency;
    final toAmount = inTx?.originalAmount;

    final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
    final hierarchy = _resolveCategoryHierarchy(categories, tx.categoryId);
    final display = hierarchy.display;
    final titleText = display?.name ??
        (tx.note?.trim().isNotEmpty == true
            ? tx.note!.trim()
            : (toCurrency != null
                ? '$fromCurrency → $toCurrency'
                : 'Exchange'));

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: ListTile(
        onTap: () => _showDetailsDialog(
          context,
          tx,
          category: hierarchy.sub ?? display,
          parent: hierarchy.sub != null ? display : null,
        ),
        leading: display != null
            ? categoryGlyphAvatar(
                colour: parseHexColour(display.colourHex),
                iconCodePoint: display.iconCodePoint,
              )
            : CircleAvatar(
                backgroundColor: theme.colorScheme.tertiaryContainer,
                child: Icon(
                  Icons.currency_exchange,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
        title: Text(
          titleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
