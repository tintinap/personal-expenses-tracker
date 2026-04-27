import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../../shared/providers/shared_providers.dart';
import '../providers/exchange_rate_providers.dart';
import 'package:drift/drift.dart' hide Column;
import 'currency_prefix_dropdown.dart';

enum TransactionTabType { expense, income, exchange }

class TransactionBottomSheet extends ConsumerStatefulWidget {
  final TransactionData? initialTransaction;

  const TransactionBottomSheet({super.key, this.initialTransaction});

  static Future<void> show(BuildContext context, {TransactionData? transaction}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => TransactionBottomSheet(initialTransaction: transaction),
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
  String? _selectedCategoryId;

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
      _amountController.text = tx.originalAmount.toString();
      _noteController.text = tx.note ?? '';
      _selectedDate = tx.transactionDate;
      _fromCurrency = tx.originalCurrency;
      _selectedCategoryId = tx.categoryId;
      
      if (tx.transactionType == 'expense') {
        _selectedTab = TransactionTabType.expense;
      } else if (tx.transactionType == 'currency_income') {
        _selectedTab = TransactionTabType.income;
      } else {
        _selectedTab = TransactionTabType.exchange;
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

  void _save() async {
    final amountText = _amountController.text;
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    if (_selectedTab == TransactionTabType.exchange && _fromCurrency == _toCurrency) {
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
      final eventId = const Uuid().v4();
      
      final outSide = TransactionsCompanion.insert(
        id: id,
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
        id: const Uuid().v4(),
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
      
      await dao.insertTransaction(outSide);
      await dao.insertTransaction(inSide);

      // Adjust balances: deduct from source, add to target
      await balanceDao.adjustBalance(_fromCurrency, -amount);
      await balanceDao.adjustBalance(_toCurrency, toAmount);
      
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
      categoryId: Value(_selectedCategoryId),
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
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                hint: const Text('Select Category'),
                items: ref.watch(activeCategoryListProvider).map<DropdownMenuItem<String>>((c) {
                  return DropdownMenuItem<String>(value: c.id, child: Text(c.name));
                }).toList(),
                onChanged: (id) => setState(() => _selectedCategoryId = id),
              ),
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
