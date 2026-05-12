import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../../categories/widgets/category_bottom_sheet.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/exchange_rate_providers.dart';
import 'package:drift/drift.dart' hide Column;
import 'currency_prefix_dropdown.dart';

enum TransactionTabType { expense, income, exchange }

class TransactionBottomSheet extends ConsumerStatefulWidget {
  final TransactionData? initialTransaction;
  final TransactionData? pairedTransaction;

  const TransactionBottomSheet({super.key, this.initialTransaction, this.pairedTransaction});

  static Future<void> show(BuildContext context, {TransactionData? transaction, TransactionData? pairedTransaction}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TransactionBottomSheet(initialTransaction: transaction, pairedTransaction: pairedTransaction),
    );
  }

  @override
  ConsumerState<TransactionBottomSheet> createState() => _TransactionBottomSheetState();
}

class _TransactionBottomSheetState extends ConsumerState<TransactionBottomSheet> {
  TransactionTabType _selectedTab = TransactionTabType.expense;
  
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _exchangeToAmountController = TextEditingController();
  final _exchangeRateController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String _fromCurrency = 'AUD';
  String _toCurrency = 'AUD';
  /// The top-level (parent) category the user picked
  String? _selectedCategoryId;
  /// The optional sub-category within the selected parent
  String? _selectedSubCategoryId;

  // Tracks which field the user is currently editing to prevent infinite update loops
  String? _lastEditedField;
  // Once the user manually types a rate, it becomes locked
  bool _isRateLocked = false;
  // Loading state for the "Get Rate" button
  bool _isFetchingRate = false;
  // Error message for the rate fetch
  String? _rateError;

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final tx = widget.initialTransaction!;
      _noteController.text = tx.note ?? '';
      _selectedDate = tx.transactionDate;
      _selectedCategoryId = tx.categoryId;
      // If editing a sub-category, resolve the parent
      // (handled in build via category list lookup)
      
      if (tx.transactionType == 'expense') {
        _selectedTab = TransactionTabType.expense;
        _amountController.text = tx.originalAmount.toString();
        _fromCurrency = tx.originalCurrency;
      } else if (tx.transactionType == 'currency_income') {
        _selectedTab = TransactionTabType.income;
        _amountController.text = tx.originalAmount.toString();
        _fromCurrency = tx.originalCurrency;
      } else {
        // Exchange transaction — determine out/in sides
        _selectedTab = TransactionTabType.exchange;
        final paired = widget.pairedTransaction;
        final isOut = tx.transactionType == 'currency_exchange_out';
        final outTx = isOut ? tx : paired;
        final inTx = isOut ? paired : tx;
        
        _fromCurrency = outTx?.originalCurrency ?? tx.originalCurrency;
        _amountController.text = (outTx?.originalAmount ?? tx.originalAmount).toString();
        
        if (inTx != null) {
          _toCurrency = inTx.originalCurrency;
          _exchangeToAmountController.text = inTx.originalAmount.toString();
          
          // Rate = fromAmount / toAmount (how many from-currency per 1 to-currency)
          final fromAmt = outTx?.originalAmount ?? tx.originalAmount;
          if (inTx.originalAmount > 0) {
            _exchangeRateController.text = (fromAmt / inTx.originalAmount).toStringAsFixed(2);
            _isRateLocked = true;
          }
        }
      }
    }
    _amountController.addListener(_onFromAmountChanged);
    _exchangeToAmountController.addListener(_onToAmountChanged);
    _exchangeRateController.addListener(_onRateChanged);
  }

  void _onFromAmountChanged() {
    if (_lastEditedField == 'from') return;
    _lastEditedField = 'from';
    _recalculateFromAmount();
    _lastEditedField = null;
    setState(() {});
  }

  void _onToAmountChanged() {
    if (_lastEditedField == 'to') return;
    _lastEditedField = 'to';
    _recalculateFromToAmount();
    _lastEditedField = null;
    setState(() {});
  }

  void _onRateChanged() {
    if (_lastEditedField == 'rate') return;
    _lastEditedField = 'rate';
    final rateText = _exchangeRateController.text.trim();
    _isRateLocked = rateText.isNotEmpty && double.tryParse(rateText) != null;
    _recalculateFromRate();
    _lastEditedField = null;
    setState(() {});
  }

  /// Rate means: 1 TO-currency = Rate FROM-currency
  /// E.g. Rate 23.90 means 1 AUD = 23.90 THB
  /// So: To = From / Rate, From = To × Rate, Rate = From / To
  ///
  /// RULE: Once the user manually sets the rate, it is LOCKED.
  /// Only From and To recalculate each other using the fixed rate.
  /// If rate is not locked, From+To will derive the rate.

  /// When "From Amount" changes
  void _recalculateFromAmount() {
    final fromAmount = double.tryParse(_amountController.text);
    if (fromAmount == null || fromAmount <= 0) return;

    final rate = double.tryParse(_exchangeRateController.text);

    if (_isRateLocked && rate != null && rate > 0) {
      // Rate is locked → recalculate To = From / Rate
      _exchangeToAmountController.removeListener(_onToAmountChanged);
      _exchangeToAmountController.text = (fromAmount / rate).toStringAsFixed(2);
      _exchangeToAmountController.addListener(_onToAmountChanged);
    } else if (!_isRateLocked) {
      // Rate is not locked → derive rate from From + To
      final toAmount = double.tryParse(_exchangeToAmountController.text);
      if (toAmount != null && toAmount > 0) {
        _exchangeRateController.removeListener(_onRateChanged);
        _exchangeRateController.text = (fromAmount / toAmount).toStringAsFixed(2);
        _exchangeRateController.addListener(_onRateChanged);
      }
    }
  }

  /// When "To Amount" changes
  void _recalculateFromToAmount() {
    final toAmount = double.tryParse(_exchangeToAmountController.text);
    if (toAmount == null) return;

    final rate = double.tryParse(_exchangeRateController.text);

    if (_isRateLocked && rate != null && rate > 0) {
      // Rate is locked → recalculate From = To × Rate
      _amountController.removeListener(_onFromAmountChanged);
      _amountController.text = (toAmount * rate).toStringAsFixed(2);
      _amountController.addListener(_onFromAmountChanged);
    } else if (!_isRateLocked) {
      // Rate is not locked → derive rate from From + To
      final fromAmount = double.tryParse(_amountController.text);
      if (fromAmount != null && fromAmount > 0) {
        _exchangeRateController.removeListener(_onRateChanged);
        _exchangeRateController.text = (fromAmount / toAmount).toStringAsFixed(2);
        _exchangeRateController.addListener(_onRateChanged);
      }
    }
  }

  /// When "Rate" changes: recalculate To if From exists, else From if To exists
  void _recalculateFromRate() {
    final rate = double.tryParse(_exchangeRateController.text);
    if (rate == null || rate <= 0) return;

    final fromAmount = double.tryParse(_amountController.text);
    final toAmount = double.tryParse(_exchangeToAmountController.text);

    if (fromAmount != null && fromAmount > 0) {
      _exchangeToAmountController.removeListener(_onToAmountChanged);
      _exchangeToAmountController.text = (fromAmount / rate).toStringAsFixed(2);
      _exchangeToAmountController.addListener(_onToAmountChanged);
    } else if (toAmount != null && toAmount > 0) {
      _amountController.removeListener(_onFromAmountChanged);
      _amountController.text = (toAmount * rate).toStringAsFixed(2);
      _amountController.addListener(_onFromAmountChanged);
    }
  }

  /// Fetches the recommended exchange rate via the 3-tier strategy:
  /// Local DB → Backend Server → Direct Frankfurter API
  Future<void> _fetchRecommendedRate() async {
    if (_fromCurrency == _toCurrency) return;

    setState(() {
      _isFetchingRate = true;
      _rateError = null;
    });

    try {
      final repo = ref.read(exchangeRateRepositoryProvider);

      // The UI rate = "1 _toCurrency = ? _fromCurrency"
      // So baseCurrency = _toCurrency, quoteCurrency = _fromCurrency
      final result = await repo.getRecommendedRate(
        baseCurrency: _toCurrency,
        quoteCurrency: _fromCurrency,
        date: _selectedDate,
      );

      if (!mounted) return;

      // Fill the rate field and lock it
      _exchangeRateController.removeListener(_onRateChanged);
      _exchangeRateController.text = result.rate.toStringAsFixed(2);
      _exchangeRateController.addListener(_onRateChanged);
      _isRateLocked = true;

      // Recalculate To amount if From amount exists
      _recalculateFromAmount();

      setState(() => _isFetchingRate = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rate loaded from ${result.source}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingRate = false;
        _rateError = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onFromAmountChanged);
    _exchangeToAmountController.removeListener(_onToAmountChanged);
    _exchangeRateController.removeListener(_onRateChanged);
    _amountController.dispose();
    _noteController.dispose();
    _exchangeToAmountController.dispose();
    _exchangeRateController.dispose();
    super.dispose();
  }

  /// Return only top-level (parent) categories for the first dropdown.
  List<DropdownMenuItem<String>> _buildParentDropdownItems(List<CategoryData> allCategories) {
    final parents = allCategories.where((c) => c.parentId == null).toList();
    return parents.map((c) => DropdownMenuItem<String>(
      value: c.id,
      child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    )).toList();
  }

  /// Return sub-category items for the selected parent.
  List<DropdownMenuItem<String?>> _buildSubDropdownItems(
    List<CategoryData> allCategories,
    String parentId,
  ) {
    final children = allCategories.where((c) => c.parentId == parentId).toList();
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('— None —'),
      ),
    ];
    items.addAll(children.map((c) => DropdownMenuItem<String?>(
      value: c.id,
      child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    )));
    return items;
  }

  /// Opens [CategoryBottomSheet] in sub-category mode, then auto-selects the
  /// newly created sub-category once it appears in the category list.
  Future<void> _addSubCategory(CategoryData parent) async {
    // Need the full list (incl. hidden) so the diff isn't skewed by hidden ones.
    final beforeIds = (ref.read(categoryListProvider).valueOrNull ?? const [])
        .map((c) => c.id)
        .toSet();

    await CategoryBottomSheet.show(
      context,
      parentId: parent.id,
      parentName: parent.name,
      parentColor: parent.colourHex,
      parentIconCodePoint: parent.iconCodePoint,
    );

    if (!mounted) return;

    // Find the newly created sub-category for this parent.
    final after = ref.read(categoryListProvider).valueOrNull ?? const [];
    final newSubs = after
        .where((c) => c.parentId == parent.id && !beforeIds.contains(c.id))
        .toList();
    if (newSubs.isNotEmpty) {
      setState(() => _selectedSubCategoryId = newSubs.first.id);
    }
  }

  void _save() async {
    final amountText = _amountController.text;
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    if (_selectedTab == TransactionTabType.exchange && _fromCurrency == _toCurrency) {
      return;
    }

    if (_selectedTab == TransactionTabType.expense && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final dao = ref.read(transactionDaoProvider);
    final db = ref.read(databaseProvider);
    final balanceDao = ref.read(currencyBalanceDaoProvider);

    final id = widget.initialTransaction?.id ?? const Uuid().v4();
    final now = DateTime.now();

    if (_selectedTab == TransactionTabType.exchange) {
      final toAmount = double.tryParse(_exchangeToAmountController.text);
      if (toAmount == null || toAmount <= 0) return;

      final exchangeRate = toAmount / amount;
      final isEditing = widget.initialTransaction != null;
      
      // Determine which side is the out and which is the in
      final initTx = widget.initialTransaction;
      final pairedTx = widget.pairedTransaction;
      final isInitOut = initTx?.transactionType == 'currency_exchange_out';
      
      // Preserve existing IDs when editing, generate new ones when creating
      final eventId = isEditing 
          ? (initTx!.exchangeEventId ?? const Uuid().v4())
          : const Uuid().v4();
      final outId = isEditing
          ? (isInitOut ? initTx!.id : pairedTx?.id ?? const Uuid().v4())
          : id;
      final inId = isEditing
          ? (isInitOut ? pairedTx?.id ?? const Uuid().v4() : initTx!.id)
          : const Uuid().v4();
      
      final outSide = TransactionsCompanion.insert(
        id: outId,
        transactionType: 'currency_exchange_out',
        amountBase: toAmount,
        originalAmount: amount,
        originalCurrency: _fromCurrency,
        exchangeRate: exchangeRate,
        rateDate: _selectedDate,
        exchangeEventId: Value(eventId),
        transactionDate: _selectedDate,
        note: Value(_noteController.text),
      );

      final inSide = TransactionsCompanion.insert(
        id: inId,
        transactionType: 'currency_exchange_in',
        amountBase: toAmount,
        originalAmount: toAmount,
        originalCurrency: _toCurrency,
        exchangeRate: 1.0,
        rateDate: _selectedDate,
        exchangeEventId: Value(eventId),
        transactionDate: _selectedDate,
        note: Value(_noteController.text),
      );

      if (isEditing) {
        await dao.updateTransaction(outSide);
        await dao.updateTransaction(inSide);
      } else {
        await dao.insertTransaction(outSide);
        await dao.insertTransaction(inSide);
        // Adjust balances only on create
        await balanceDao.adjustBalance(_fromCurrency, -amount);
        await balanceDao.adjustBalance(_toCurrency, toAmount);
      }
      
      if (mounted) Navigator.pop(context);
      return;
    }

    String txType = _selectedTab == TransactionTabType.income ? 'currency_income' : 'expense';
    
    final entry = TransactionsCompanion.insert(
      id: id,
      transactionType: txType,
      amountBase: amount,
      originalAmount: amount,
      originalCurrency: _fromCurrency,
      exchangeRate: 1.0,
      rateDate: _selectedDate,
      categoryId: Value(_selectedSubCategoryId ?? _selectedCategoryId),
      note: Value(_noteController.text),
      transactionDate: _selectedDate,
      updatedAt: Value(now),
      syncStatus: const Value('pending'),
    );

    if (widget.initialTransaction != null) {
      await dao.updateTransaction(entry);
    } else {
      await dao.insertTransaction(entry);
      // Adjust balance: income adds, expense subtracts
      final delta = _selectedTab == TransactionTabType.income ? amount : -amount;
      await balanceDao.adjustBalance(_fromCurrency, delta);
    }

    await db.addToSyncQueue(
      id: const Uuid().v4(),
      recordType: 'transaction',
      recordId: id,
      operation: widget.initialTransaction != null ? 'update' : 'insert',
      payload: '{}',
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    // Check for negative balance warning
    bool showNegativeWarning = false;
    double currentBalance = 0;
    if (_selectedTab != TransactionTabType.income) {
      final amount = double.tryParse(_amountController.text) ?? 0;
      final balances = ref.watch(currencyBalancesProvider).valueOrNull ?? [];
      final match = balances.where((b) => b.currency == _fromCurrency).firstOrNull;
      currentBalance = match?.balance ?? 0;
      if (amount > 0 && (currentBalance - amount < 0)) {
        showNegativeWarning = true;
      }
    }

    final isExchangeInvalid = _selectedTab == TransactionTabType.exchange && _fromCurrency == _toCurrency;
    
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomPadding + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<TransactionTabType>(
              segments: const [
                ButtonSegment(value: TransactionTabType.expense, label: Text('Expense')),
                ButtonSegment(value: TransactionTabType.income, label: Text('Income')),
                ButtonSegment(value: TransactionTabType.exchange, label: Text('Exchange')),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (set) => setState(() => _selectedTab = set.first),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _selectedTab == TransactionTabType.exchange ? 'From Amount' : 'Amount',
                prefixIcon: CurrencyPrefixDropdown(
                  selectedCurrency: _fromCurrency,
                  onChanged: (val) => setState(() => _fromCurrency = val),
                ),
              ),
              autofocus: true,
            ),
            
            if (showNegativeWarning) ...[
              const SizedBox(height: 8),
              Text(
                '⚠️ This transaction exceeds your $_fromCurrency balance ($currentBalance).',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ],
            
            if (_selectedTab == TransactionTabType.exchange) ...[
              const SizedBox(height: 12),
              // Exchange Rate field with "Get Rate" button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _exchangeRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Exchange Rate',
                        hintText: '1 $_toCurrency = ? $_fromCurrency',
                        prefixIcon: const Icon(Icons.swap_horiz),
                        helperText: 'How many $_fromCurrency per 1 $_toCurrency',
                        errorText: _rateError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _isFetchingRate
                        ? const SizedBox(
                            width: 48,
                            height: 48,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton.filled(
                            onPressed: (_fromCurrency == _toCurrency)
                                ? null
                                : _fetchRecommendedRate,
                            icon: const Icon(Icons.auto_awesome),
                            tooltip: 'Get recommended rate',
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _exchangeToAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'To Amount',
                  prefixIcon: CurrencyPrefixDropdown(
                    selectedCurrency: _toCurrency,
                    onChanged: (val) => setState(() => _toCurrency = val),
                  ),
                ),
              ),
              if (isExchangeInvalid) ...[
                const SizedBox(height: 8),
                Text(
                  '❌ "From" and "To" currencies must be different.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ],
            ],
            
            if (_selectedTab == TransactionTabType.expense) ...[
              const SizedBox(height: 16),
              Builder(builder: (context) {
                final allCategories = ref.watch(activeCategoryListProvider);
                final subItems = _selectedCategoryId != null
                    ? _buildSubDropdownItems(allCategories, _selectedCategoryId!)
                    : <DropdownMenuItem<String?>>[];
                
                // When editing a sub-category, resolve initial parent
                if (_selectedCategoryId != null && _selectedSubCategoryId == null) {
                  final cat = allCategories.where((c) => c.id == _selectedCategoryId).firstOrNull;
                  if (cat != null && cat.parentId != null) {
                    // This is actually a sub-category; separate parent from sub
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _selectedSubCategoryId = cat.id;
                          _selectedCategoryId = cat.parentId;
                        });
                      }
                    });
                  }
                }

                final selectedParent = _selectedCategoryId == null
                    ? null
                    : allCategories
                        .where((c) => c.id == _selectedCategoryId)
                        .firstOrNull;
                final hasSubCategories = subItems.length > 1;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // First dropdown: parent category
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedCategoryId,
                      hint: const Text('Select Category', maxLines: 1, overflow: TextOverflow.ellipsis),
                      items: _buildParentDropdownItems(allCategories),
                      onChanged: (id) => setState(() {
                        _selectedCategoryId = id;
                        _selectedSubCategoryId = null;
                      }),
                    ),
                    // Sub-category row: dropdown + "add sub" button.
                    if (selectedParent != null) ...[
                      const SizedBox(height: 12),
                      if (hasSubCategories)
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                isExpanded: true,
                                value: _selectedSubCategoryId,
                                hint: const Text(
                                  'Select Sub-category (optional)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                items: subItems,
                                onChanged: (id) =>
                                    setState(() => _selectedSubCategoryId = id),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: 'Add sub-category',
                              icon: const Icon(Icons.add),
                              onPressed: () => _addSubCategory(selectedParent),
                            ),
                          ],
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _addSubCategory(selectedParent),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add sub-category'),
                          ),
                        ),
                    ],
                  ],
                );
              }),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_selectedDate.toString().split(' ')[0]),
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        final now = DateTime.now();
                        setState(() {
                          _selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            now.hour,
                            now.minute,
                            now.second,
                          );
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (Optional)'),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: isExchangeInvalid ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
