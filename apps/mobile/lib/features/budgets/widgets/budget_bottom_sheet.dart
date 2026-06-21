import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../../shared/providers/shared_providers.dart';
import '../../transactions/widgets/currency_prefix_dropdown.dart';

class BudgetBottomSheet extends ConsumerStatefulWidget {
  final BudgetData? initialBudget;

  const BudgetBottomSheet({super.key, this.initialBudget});

  @override
  ConsumerState<BudgetBottomSheet> createState() => _BudgetBottomSheetState();
}

class _BudgetBottomSheetState extends ConsumerState<BudgetBottomSheet> {
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  
  String _scopeType = 'all';
  Set<String> _selectedCategoryIds = {};
  Set<String> _expandedParentIds = {};
  
  String _currency = 'AUD';
  String _periodType = 'monthly';
  bool _isRecurring = true;
  
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  
  bool _isSaving = false;

  /// Generate a display name from the current form values (used as placeholder
  /// and as the stored name when the user leaves the field blank).
  String _autoName(List<CategoryData> allCategories) {
    if (_scopeType == 'all') return 'Global Budget';
    final catNames = _selectedCategoryIds
        .map((id) => allCategories.where((c) => c.id == id).firstOrNull?.name)
        .whereType<String>()
        .toList();
    if (catNames.isEmpty) return 'Category Budget';
    return '${catNames.join(', ')} Budget';
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialBudget != null) {
      final b = widget.initialBudget!;
      _amountController.text = b.amountBase.toString();
      _nameController.text = b.name ?? '';
      _scopeType = b.scopeType;
      _currency = b.currency;
      _periodType = b.periodType;
      _isRecurring = b.isRecurring;
      _startDate = b.startDate;
      _endDate = b.endDate;
      
      if (b.categoryIds != null) {
        try {
          final ids = (jsonDecode(b.categoryIds!) as List).cast<String>();
          _selectedCategoryIds = ids.toSet();
          // Parents of selected sub-categories will be expanded in build()
          // once we have the category list — see _ensureParentsExpanded()
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate.add(const Duration(days: 30))),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    
    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
          }
        } else {
          _endDate = date;
        }
      });
    }
  }

  Future<void> _save(List<CategoryData> allCategories) async {
    if (_amountController.text.isEmpty) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) return;

    if (_scopeType != 'all' && _selectedCategoryIds.isEmpty) return;
    if (!_isRecurring && _endDate == null) return;

    setState(() => _isSaving = true);
    
    final dao = ref.read(budgetDaoProvider);
    final now = DateTime.now();

    final trimmedName = _nameController.text.trim();
    final finalName = trimmedName.isEmpty ? _autoName(allCategories) : trimmedName;

    String? categoryIdsJson;
    if (_scopeType != 'all' && _selectedCategoryIds.isNotEmpty) {
      categoryIdsJson = jsonEncode(_selectedCategoryIds.toList());
    }

    try {
      if (widget.initialBudget != null) {
        await dao.updateBudget(widget.initialBudget!.toCompanion(true).copyWith(
              name: Value(finalName),
              amountBase: Value(amount),
              scopeType: Value(_scopeType),
              categoryIds: Value(categoryIdsJson),
              currency: Value(_currency),
              periodType: Value(_periodType),
              isRecurring: Value(_isRecurring),
              startDate: Value(_startDate),
              endDate: Value(_endDate),
              updatedAt: Value(now),
            ));
      } else {
        await dao.insertBudget(BudgetsCompanion.insert(
          id: const Uuid().v4(),
          name: Value(finalName),
          amountBase: amount,
          scopeType: _scopeType,
          categoryIds: Value(categoryIdsJson),
          currency: _currency,
          periodType: _periodType,
          isRecurring: Value(_isRecurring),
          startDate: _startDate,
          endDate: Value(_endDate),
          isActive: const Value(true),
          syncStatus: const Value('pending'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
      }

      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Auto-expand parents of any already-selected sub-categories.
  void _ensureParentsExpanded(List<CategoryData> categories) {
    final childIds = _selectedCategoryIds.where((id) {
      final cat = categories.where((c) => c.id == id).firstOrNull;
      return cat?.parentId != null;
    });
    for (final id in childIds) {
      final cat = categories.where((c) => c.id == id).firstOrNull;
      if (cat?.parentId != null) _expandedParentIds.add(cat!.parentId!);
    }
  }

  Widget _buildCategoryPicker(
    BuildContext context,
    List<CategoryData> categories,
  ) {
    final parentCategories =
        categories.where((c) => c.parentId == null).toList();
    final childrenByParent = <String, List<CategoryData>>{};
    for (final cat in categories) {
      if (cat.parentId != null) {
        childrenByParent.putIfAbsent(cat.parentId!, () => []).add(cat);
      }
    }

    _ensureParentsExpanded(categories);

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parentCategories.map((parent) {
        final children = childrenByParent[parent.id] ?? [];
        final hasChildren = children.isNotEmpty;
        final isExpanded = _expandedParentIds.contains(parent.id);
        final isParentSelected = _selectedCategoryIds.contains(parent.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Parent row
            Row(
              children: [
                FilterChip(
                  label: Text(parent.name),
                  selected: isParentSelected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedCategoryIds.add(parent.id);
                      } else {
                        _selectedCategoryIds.remove(parent.id);
                      }
                    });
                  },
                ),
                if (hasChildren) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedParentIds.remove(parent.id);
                          // Deselect any children when collapsing
                          for (final child in children) {
                            _selectedCategoryIds.remove(child.id);
                          }
                        } else {
                          _expandedParentIds.add(parent.id);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // Sub-category chips (indented, only when expanded)
            if (hasChildren && isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: children.map((child) {
                    final isChildSelected =
                        _selectedCategoryIds.contains(child.id);
                    return FilterChip(
                      label: Text(child.name),
                      selected: isChildSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedCategoryIds.add(child.id);
                          } else {
                            _selectedCategoryIds.remove(child.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(activeCategoryListProvider);
    final isEdit = widget.initialBudget != null;
    final autoNameHint = _autoName(categories);
    
    final mq = MediaQuery.of(context);
    // Cap the sheet at 90 % of the screen so it never clips behind the status
    // bar, and clamp upward for the software keyboard.
    final maxHeight = mq.size.height * 0.9 - mq.viewInsets.bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight.clamp(200.0, double.infinity)),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: mq.viewInsets.bottom,
          left: 16, right: 16, top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? 'Edit Budget' : 'New Budget',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Budget Name',
                hintText: autoNameHint,
                border: const OutlineInputBorder(),
                helperText: 'Leave blank to use "$autoNameHint"',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount',
                border: const OutlineInputBorder(),
                prefixIcon: CurrencyPrefixDropdown(
                  selectedCurrency: _currency,
                  onChanged: (val) => setState(() => _currency = val),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Text('Scope', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All')),
                ButtonSegment(value: 'include', label: Text('Include')),
                ButtonSegment(value: 'exclude', label: Text('Exclude')),
              ],
              selected: {_scopeType},
              onSelectionChanged: (set) {
                setState(() {
                  _scopeType = set.first;
                  if (_scopeType == 'all') {
                    _selectedCategoryIds.clear();
                    _expandedParentIds.clear();
                  }
                });
              },
            ),
            
            if (_scopeType != 'all') ...[
              const SizedBox(height: 16),
              _buildCategoryPicker(context, categories),
            ],
            
            const SizedBox(height: 16),
            Text('Period', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'weekly', label: Text('Weekly')),
                ButtonSegment(value: 'fortnightly', label: Text('14 Days')),
                ButtonSegment(value: 'monthly', label: Text('Monthly')),
                ButtonSegment(value: 'custom', label: Text('Custom')),
              ],
              selected: {_periodType},
              onSelectionChanged: (set) {
                setState(() {
                  _periodType = set.first;
                  if (_periodType == 'custom') _isRecurring = false;
                });
              },
            ),
            
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Recurring'),
              value: _isRecurring,
              onChanged: _periodType == 'custom' ? null : (val) {
                setState(() => _isRecurring = val);
              },
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Start Date', border: OutlineInputBorder()),
                      child: Text(DateFormat.yMMMd().format(_startDate)),
                    ),
                  ),
                ),
                if (!_isRecurring || _endDate != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(false),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'End Date', border: OutlineInputBorder()),
                        child: Text(_endDate != null ? DateFormat.yMMMd().format(_endDate!) : 'Select'),
                      ),
                    ),
                  ),
                ]
              ],
            ),
            
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : () => _save(categories),
              child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Budget'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ));
  }
}
