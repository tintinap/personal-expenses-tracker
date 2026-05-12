import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/presentation/category_visuals.dart';
import '../../shared/providers/shared_providers.dart';
import '../../shared/widgets/transaction_list_tile.dart';

/// Modal bottom sheet that lists every transaction belonging to the given
/// parent category (and any of its sub-categories) for the currently selected
/// period.
///
/// Driven by [transactionListProvider] so it reflects the same period filters
/// used elsewhere in the app.
class CategoryTransactionsSheet extends ConsumerWidget {
  final String parentCategoryId;
  final Set<String>? filterCurrencies;

  const CategoryTransactionsSheet({
    super.key,
    required this.parentCategoryId,
    this.filterCurrencies,
  });

  static Future<void> show(
    BuildContext context, {
    required String parentCategoryId,
    Set<String>? filterCurrencies,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CategoryTransactionsSheet(
        parentCategoryId: parentCategoryId,
        filterCurrencies: filterCurrencies,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoryListProvider).valueOrNull ?? const [];
    final allTx = ref.watch(transactionListProvider).valueOrNull ?? const [];

    final parent = categories
        .where((c) => c.id == parentCategoryId)
        .firstOrNull;

    final relevantIds = <String>{
      parentCategoryId,
      ...categories
          .where((c) => c.parentId == parentCategoryId)
          .map((c) => c.id),
    };

    var transactions = allTx
        .where((tx) =>
            tx.categoryId != null &&
            relevantIds.contains(tx.categoryId) &&
            tx.transactionType == 'expense')
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    if (filterCurrencies != null && filterCurrencies!.isNotEmpty) {
      transactions = transactions
          .where((tx) => filterCurrencies!.contains(tx.originalCurrency))
          .toList();
    }

    final total = transactions.fold<double>(
      0,
      (sum, tx) => sum + tx.originalAmount.abs(),
    );

    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SlidableAutoCloseBehavior(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                children: [
                  if (parent != null)
                    categoryGlyphAvatar(
                      colour: parseHexColour(parent.colourHex),
                      iconCodePoint: parent.iconCodePoint,
                      radius: 22,
                    )
                  else
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.category,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parent?.name ?? 'Category',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${transactions.length} ${transactions.length == 1 ? 'transaction' : 'transactions'} · '
                          '${_formatTotal(total, transactions, filterCurrencies)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: transactions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No transactions in this category for the selected period.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      // Clear the docked FAB on the parent shell. The modal
                      // is hosted in the shell's body, so the FAB overlaps
                      // the last list items unless we leave room for it.
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (index == 0 ||
                                !_isSameDay(
                                  transactions[index - 1].transactionDate,
                                  tx.transactionDate,
                                ))
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                child: Text(
                                  DateFormat.yMMMd()
                                      .format(tx.transactionDate),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            TransactionListTile(transaction: tx),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatTotal(
    double total,
    List<TransactionData> txs,
    Set<String>? filterCurrencies,
  ) {
    if (txs.isEmpty) return '0.00';
    final currency = filterCurrencies != null && filterCurrencies.length == 1
        ? filterCurrencies.first
        : (txs.first.originalCurrency);
    return '$currency ${total.toStringAsFixed(2)}';
  }
}
