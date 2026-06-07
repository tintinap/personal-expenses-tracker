import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/presentation/category_visuals.dart';
import '../../categories/category_icon_picker_data.dart';
import '../models/import_row.dart';
import '../providers/import_provider.dart';

class ImportPreviewScreen extends ConsumerWidget {
  final String filePath;

  const ImportPreviewScreen({super.key, required this.filePath});

  static Route<void> route(String filePath) {
    return MaterialPageRoute<void>(
      builder: (context) => ImportPreviewScreen(filePath: filePath),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importProvider);
    final notifier = ref.read(importProvider.notifier);

    // Run Excel parsing once on enter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.rows.isEmpty && !state.isParsing && state.error == null) {
        notifier.parseExcel(filePath);
      }
    });

    final errorRows = state.rows.where((r) => r.status == ImportRowStatus.error).toList();
    final duplicateRows = state.rows.where((r) => r.status == ImportRowStatus.duplicate).toList();
    final updateRows = state.rows.where((r) => r.status == ImportRowStatus.update).toList();
    final readyRows = state.rows.where((r) => r.status == ImportRowStatus.ready).toList();
    final checkedCount = state.rows.where((r) => r.checked && r.status != ImportRowStatus.error).length;

    final hasErrors = errorRows.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Preview'),
        centerTitle: true,
      ),
      body: state.isParsing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Parsing Excel file... Please wait.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : state.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _buildSummaryCard(
                              context,
                              total: state.rows.length,
                              ready: readyRows.length,
                              duplicates: duplicateRows.length,
                              updates: updateRows.length,
                              errors: errorRows.length,
                            ),
                          ),
                          if (state.pendingCategories.isNotEmpty && !hasErrors)
                            SliverToBoxAdapter(
                              child: _buildPendingCategoriesMapping(context, state, notifier),
                            ),
                          SliverToBoxAdapter(
                            child: hasErrors
                                ? _buildErrorAlert(context, errorRows)
                                : _buildHeaderControls(context, notifier, state.rows),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final row = state.rows[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: _buildRowItem(context, row, index, notifier, hasErrors),
                                  );
                                },
                                childCount: state.rows.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildBottomActionBar(context, ref, checkedCount, state.isImporting, hasErrors),
                  ],
                ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required int total,
    required int ready,
    required int duplicates,
    required int updates,
    required int errors,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Summary', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$total rows', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCol(context, 'Ready', ready, Colors.green),
              _buildStatCol(context, 'Duplicates', duplicates, Colors.amber),
              _buildStatCol(context, 'Updates', updates, Colors.blue),
              _buildStatCol(context, 'Errors', errors, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  static const _colorOptions = [
    '#378ADD', '#4CAF50', '#FF7043', '#E91E8C',
    '#9C27B0', '#009688', '#FFC107', '#FF8F00',
    '#F44336', '#455A64', '#4FC3F7', '#9E9E9E',
    '#00BCD4', '#8BC34A', '#FF5722', '#795548',
  ];

  Widget _buildPendingCategoriesMapping(BuildContext context, ImportState state, ImportNotifier notifier) {
    final theme = Theme.of(context);
    final pendingList = state.pendingCategories.entries.toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Map New Categories',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${pendingList.length} new',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'We found categories in the file that don\'t exist in your database. Please confirm if they are new top-level categories or subcategories.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ...pendingList.map((entry) {
            final catId = entry.key;
            final companion = state.pendingCategories[catId]!;
            final catName = companion.name.value;
            final currentParentId = companion.parentId.present ? companion.parentId.value : null;
            final currentColour = companion.colourHex.value;
            final currentIconCode = companion.iconCodePoint.value;
            final isSubcategory = currentParentId != null;

            // Build items list
            final items = <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Top-Level Category'),
              ),
            ];

            // Filter existing categories to only top-level (parentId == null)
            final topLevelExisting = state.existingCategories.where((c) => c.parentId == null).toList();
            if (topLevelExisting.isNotEmpty) {
              items.add(const DropdownMenuItem<String?>(
                enabled: false,
                value: 'divider_existing',
                child: Text('-- Existing Categories --', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ));
              items.addAll(topLevelExisting.map((c) => DropdownMenuItem<String?>(
                value: c.id,
                child: Text(c.name),
              )));
            }

            // Filter pending categories to only top-level (parentId is absent or null)
            final topLevelPending = state.pendingCategories.entries.where((e) {
              if (e.key == catId) return false; // don't show self
              return !e.value.parentId.present || e.value.parentId.value == null;
            }).toList();

            if (topLevelPending.isNotEmpty) {
              items.add(const DropdownMenuItem<String?>(
                enabled: false,
                value: 'divider_new',
                child: Text('-- Other New Categories --', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ));
              items.addAll(topLevelPending.map((e) => DropdownMenuItem<String?>(
                value: e.key,
                child: Text('${e.value.name.value} (New)'),
              )));
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Original row: name + dropdown ──
                  Row(
                    children: [
                      categoryGlyphAvatar(
                        colour: parseHexColour(currentColour),
                        iconCodePoint: currentIconCode,
                        radius: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          catName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(),
                          ),
                          initialValue: currentParentId,
                          items: items,
                          onChanged: (newParentId) {
                            notifier.updatePendingCategoryParent(catId, newParentId);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ── Color & Icon picker (only for new top-level categories) ──
                  if (!isSubcategory) ...[
                    Text('Color', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _colorOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 5),
                        itemBuilder: (context, index) {
                          final hex = _colorOptions[index];
                          final isSelected = hex == currentColour;
                          final color = parseHexColour(hex);
                          return GestureDetector(
                            onTap: () => notifier.updatePendingCategoryColor(catId, hex),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: theme.colorScheme.onSurface, width: 2.5)
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Icon', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: kCategoryIconChoices.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 3),
                        itemBuilder: (context, index) {
                          final icon = kCategoryIconChoices[index];
                          final code = icon.codePoint;
                          final isSelected = code == currentIconCode;
                          final previewColor = parseHexColour(currentColour);
                          return GestureDetector(
                            onTap: () => notifier.updatePendingCategoryIcon(catId, code),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                  width: isSelected ? 2 : 1,
                                ),
                                color: previewColor.withValues(alpha: isSelected ? 0.25 : 0.08),
                              ),
                              child: Icon(icon, color: previewColor, size: 18),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    // Color is locked to parent — show a hint only
                    Row(
                      children: [
                        Icon(Icons.palette_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Color inherited from parent',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: parseHexColour(currentColour),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Icon IS choosable for subcategories (defaults to parent icon)
                    Text('Icon', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: kCategoryIconChoices.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 3),
                        itemBuilder: (context, index) {
                          final icon = kCategoryIconChoices[index];
                          final code = icon.codePoint;
                          final isSelected = code == currentIconCode;
                          final previewColor = parseHexColour(currentColour);
                          return GestureDetector(
                            onTap: () => notifier.updatePendingCategoryIcon(catId, code),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                  width: isSelected ? 2 : 1,
                                ),
                                color: previewColor.withValues(alpha: isSelected ? 0.25 : 0.08),
                              ),
                              child: Icon(icon, color: previewColor, size: 18),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],


                  // Divider between categories
                  if (entry.key != pendingList.last.key)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatCol(BuildContext context, String label, int value, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text('$value', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }

  Widget _buildErrorAlert(BuildContext context, List<ImportRow> errorRows) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validation Errors Found',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade900, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Excel sheet contains errors. First failure: ${errorRows.first.errorMessage ?? ""}. Please fix in your file and retry.',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderControls(BuildContext context, ImportNotifier notifier, List<ImportRow> rows) {
    final theme = Theme.of(context);
    final allChecked = rows.every((r) => r.checked || r.status == ImportRowStatus.error);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Transactions List', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          TextButton.icon(
            onPressed: () => notifier.toggleAllRows(!allChecked),
            icon: Icon(allChecked ? Icons.deselect : Icons.select_all, size: 18),
            label: Text(allChecked ? 'Deselect All' : 'Select All'),
          ),
        ],
      ),
    );
  }

  Widget _buildRowItem(
    BuildContext context,
    ImportRow row,
    int index,
    ImportNotifier notifier,
    bool hasErrors,
  ) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat('yyyy-MM-dd').format(row.date);

    Color statusColor;
    IconData statusIcon;
    String statusText = '';

    switch (row.status) {
      case ImportRowStatus.ready:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case ImportRowStatus.duplicate:
        statusColor = Colors.amber;
        statusIcon = Icons.warning_amber_rounded;
        statusText = 'Probable duplicate';
        break;
      case ImportRowStatus.update:
        statusColor = Colors.blue;
        statusIcon = Icons.update_rounded;
        statusText = 'Existing (will overwrite)';
        break;
      case ImportRowStatus.error:
        statusColor = Colors.red;
        statusIcon = Icons.error_outline_rounded;
        statusText = row.errorMessage ?? 'Validation error';
        break;
    }

    // Format display texts
    final isExpense = row.transactionType == 'expense';
    final isExchange = row.rowType == ImportRowType.exchange;

    String title = '';
    String details = '';

    if (isExchange) {
      title = 'Exchange: ${row.originalCurrency} ➔ ${row.sourceLabel!}';
      details = '${row.originalAmount} ${row.originalCurrency} ➔ ${row.amountBase} ${row.sourceLabel!}';
    } else {
      title = isExpense ? 'Expense: ${row.categoryName ?? "Uncategorized"}' : 'Income: ${row.sourceLabel ?? "Received"}';
      details = '${row.originalAmount} ${row.originalCurrency}';
      if (row.originalCurrency != 'AUD') {
        details += ' (~${row.amountBase.toStringAsFixed(2)} AUD)';
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: row.status == ImportRowStatus.error
              ? Colors.red.shade200
              : theme.colorScheme.outlineVariant,
        ),
      ),
      color: row.status == ImportRowStatus.error ? Colors.red.shade50 : theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (row.status != ImportRowStatus.error && !hasErrors)
              Checkbox(
                value: row.checked,
                onChanged: (val) {
                  if (val != null) notifier.toggleRowChecked(index, val);
                },
              ),
            const SizedBox(width: 4),
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration: row.status == ImportRowStatus.error ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          details,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                        ),
                      ),
                      if (row.isAggregate)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Aggregate (Σ)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (row.note != null && row.note!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      row.note!,
                      style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (statusText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    WidgetRef ref,
    int checkedCount,
    bool isImporting,
    bool hasErrors,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isImporting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: hasErrors || checkedCount == 0 || isImporting
                  ? null
                  : () async {
                      final success = await ref.read(importProvider.notifier).importCheckedRows();
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$checkedCount transactions imported successfully.'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.pop(context);
                      } else if (!success && context.mounted) {
                        final state = ref.read(importProvider);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.error ?? 'Failed to import records.'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Import ($checkedCount)'),
            ),
          ),
        ],
      ),
    );
  }
}
