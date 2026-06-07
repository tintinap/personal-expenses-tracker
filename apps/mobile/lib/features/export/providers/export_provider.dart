import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';

final exportProvider = Provider<ExportService>((ref) {
  return ExportService(ref);
});

class ExportResult {
  final bool success;
  final String? filePath;
  final String? error;

  const ExportResult({required this.success, this.filePath, this.error});
}

class ExportService {
  final Ref _ref;

  ExportService(this._ref);

  Future<ExportResult> exportToExcel({DateTime? from, DateTime? to}) async {
    try {
      final db = _ref.read(databaseProvider);

      final now = DateTime.now();
      from ??= DateTime(now.year, 1, 1);
      to ??= DateTime(now.year, 12, 31, 23, 59, 59);

      final allTransactions = await db.select(db.transactions).get();
      final categories = await db.select(db.categories).get();

      final transactions = allTransactions.where((tx) {
        if (tx.deletedAt != null) return false;
        final d = tx.transactionDate;
        return !d.isBefore(from!) && !d.isAfter(to!);
      }).toList()
        ..sort((a, b) => a.transactionDate.compareTo(b.transactionDate));

      if (transactions.isEmpty) {
        return const ExportResult(
          success: false,
          error: 'No transactions to export',
        );
      }

      final categoryMap = {for (var c in categories) c.id: c.name};
      // Map from child category ID to parent category name (for Subcategory Of column)
      final categoryParentMap = <String, String>{};
      final categoryColorMap = {for (var c in categories) c.id: c.colourHex};
      final categoryIconMap = {for (var c in categories) c.id: c.iconCodePoint};
      for (final c in categories) {
        if (c.parentId != null && categoryMap.containsKey(c.parentId)) {
          categoryParentMap[c.id] = categoryMap[c.parentId]!;
        }
      }

      var excel = Excel.createExcel();

      _buildAllTransactionsSheet(
        excel,
        transactions,
        categoryMap,
        categoryParentMap,
        categoryColorMap,
        categoryIconMap,
        from,
        to,
      );
      _buildCurrencyIncomeSheet(excel, transactions, categoryMap);
      _buildCurrencyExchangesSheet(excel, transactions);
      _buildDailySummarySheet(excel, transactions, categoryMap, from, to);
      _buildWeeklySummarySheet(excel, transactions, categoryMap, from, to);
      _buildFortnightlySummarySheet(excel, transactions, categoryMap, from, to);
      _buildMonthlySummarySheet(excel, transactions, categoryMap, from, to);
      _buildYearlySummarySheet(excel, transactions, categoryMap, from, to);
      _buildWalletsSheet(excel, transactions);

      // Remove the default "Sheet1" created by the package
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Auto-fit column widths for all sheets
      for (final sheetName in excel.sheets.keys) {
        _autoFitColumns(excel[sheetName]);
      }

      final fileBytes = excel.encode();
      if (fileBytes == null) {
        return const ExportResult(
          success: false,
          error: 'Failed to encode Excel file',
        );
      }

      final fileName = 'ProjectPET_Export_${DateTime.now().millisecondsSinceEpoch}';
      
      final String? filePath = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: Uint8List.fromList(fileBytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (filePath == null) {
        return const ExportResult(
          success: false,
          error: 'Export cancelled',
        );
      }

      // Show notification on platforms that support it
      if (!kIsWeb) {
        await _showExportCompleteNotification(filePath, transactions.length);
      }

      return ExportResult(success: true, filePath: filePath);
    } on Exception catch (e) {
      debugPrint('Export error: $e');
      return ExportResult(success: false, error: e.toString());
    }
  }

  // ── Sheet 1: All Transactions ───────────────────────────────

  void _buildAllTransactionsSheet(
    Excel excel,
    List<TransactionData> transactions,
    Map<String, String> categoryMap,
    Map<String, String> categoryParentMap,
    Map<String, String> categoryColorMap,
    Map<String, int> categoryIconMap,
    DateTime from,
    DateTime to,
  ) {
    final sheet = excel['All Transactions'];
    excel.setDefaultSheet('All Transactions');

    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Description'),
      TextCellValue('Category'),
      TextCellValue('Subcategory Of'),
      TextCellValue('Category Color'),
      TextCellValue('Category Icon'),
      TextCellValue('Original Amount'),
      TextCellValue('Original Currency'),
      TextCellValue('Base Amount'),
      TextCellValue('Exchange Rate'),
      TextCellValue('Rate Source'),
      TextCellValue('UUID'),
    ]);

    // Group transactions by date
    final txByDate = <String, List<TransactionData>>{};
    for (final tx in transactions) {
      final key = _fmtDate(tx.transactionDate);
      txByDate.putIfAbsent(key, () => []).add(tx);
    }

    // Iterate every day in the range, writing transactions or no_transaction rows
    final startDate = DateTime(from.year, from.month, from.day);
    final endDate = DateTime(to.year, to.month, to.day);
    var current = startDate;
    while (!current.isAfter(endDate)) {
      final key = _fmtDate(current);
      final dayTxs = txByDate[key];

      if (dayTxs != null && dayTxs.isNotEmpty) {
        for (final tx in dayTxs) {
          final parentName = tx.categoryId != null
              ? (categoryParentMap[tx.categoryId!] ?? '')
              : '';
          final catColor = tx.categoryId != null
              ? (categoryColorMap[tx.categoryId!] ?? '')
              : '';
          final catIcon = tx.categoryId != null
              ? (categoryIconMap[tx.categoryId!] ?? 0)
              : 0;
          sheet.appendRow([
            TextCellValue(_fmtDateTime(tx.transactionDate)),
            TextCellValue(tx.transactionType),
            TextCellValue(tx.note ?? ''),
            TextCellValue(_categoryName(tx.categoryId, categoryMap)),
            TextCellValue(parentName),
            TextCellValue(catColor),
            IntCellValue(catIcon),
            DoubleCellValue(tx.originalAmount),
            TextCellValue(tx.originalCurrency),
            DoubleCellValue(tx.amountBase),
            DoubleCellValue(tx.exchangeRate),
            TextCellValue(tx.rateSource),
            TextCellValue(tx.id),
          ]);
        }
      } else {
        // Empty date — insert a no_transaction row
        sheet.appendRow([
          TextCellValue(key),
          TextCellValue('no_transaction'),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          IntCellValue(0),
          DoubleCellValue(0),
          TextCellValue(''),
          DoubleCellValue(0),
          DoubleCellValue(0),
          TextCellValue(''),
          TextCellValue(''),
        ]);
      }

      current = current.add(const Duration(days: 1));
    }
  }

  // ── Sheet 2: Currency Income ────────────────────────────────

  void _buildCurrencyIncomeSheet(
    Excel excel,
    List<TransactionData> transactions,
    Map<String, String> categoryMap,
  ) {
    final sheet = excel['Currency Income'];

    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Currency'),
      TextCellValue('Amount'),
      TextCellValue('Source'),
      TextCellValue('Base Currency Equivalent'),
      TextCellValue('UUID'),
    ]);

    final incomes = transactions
        .where((tx) => tx.transactionType == 'currency_income');

    for (final tx in incomes) {
      sheet.appendRow([
        TextCellValue(_fmtDateTime(tx.transactionDate)),
        TextCellValue(tx.originalCurrency),
        DoubleCellValue(tx.originalAmount),
        TextCellValue(tx.sourceLabel ?? ''),
        DoubleCellValue(tx.amountBase),
        TextCellValue(tx.id),
      ]);
    }
  }

  // ── Sheet 3: Currency Exchanges ─────────────────────────────

  void _buildCurrencyExchangesSheet(
    Excel excel,
    List<TransactionData> transactions,
  ) {
    final sheet = excel['Currency Exchanges'];

    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('From Currency'),
      TextCellValue('From Amount'),
      TextCellValue('To Currency'),
      TextCellValue('To Amount'),
      TextCellValue('Rate'),
      TextCellValue('Rate Source'),
      TextCellValue('Note'),
      TextCellValue('UUID'),
    ]);

    final exchangeTxs = transactions
        .where((tx) =>
            tx.transactionType == 'currency_exchange_out' ||
            tx.transactionType == 'currency_exchange_in')
        .toList();

    final grouped = <String, List<TransactionData>>{};
    for (final tx in exchangeTxs) {
      final key = tx.exchangeEventId ?? tx.id;
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    for (final entry in grouped.entries) {
      final pair = entry.value;
      final outTx = pair.cast<TransactionData?>().firstWhere(
            (tx) => tx!.transactionType == 'currency_exchange_out',
            orElse: () => null,
          ) ??
          pair.first;
      final inTx = pair.cast<TransactionData?>().firstWhere(
            (tx) => tx!.transactionType == 'currency_exchange_in',
            orElse: () => null,
          ) ??
          pair.last;

      sheet.appendRow([
        TextCellValue(_fmtDateTime(outTx.transactionDate)),
        TextCellValue(outTx.originalCurrency),
        DoubleCellValue(outTx.originalAmount.abs()),
        TextCellValue(inTx.originalCurrency),
        DoubleCellValue(inTx.originalAmount.abs()),
        DoubleCellValue(outTx.exchangeRate),
        TextCellValue(outTx.rateSource),
        TextCellValue(outTx.note ?? ''),
        TextCellValue(entry.key),
      ]);
    }
  }

  // ── Sheet 4: Daily Summary ──────────────────────────────────

  void _buildDailySummarySheet(
    Excel excel,
    List<TransactionData> transactions,
    Map<String, String> categoryMap,
    DateTime from,
    DateTime to,
  ) {
    _buildPeriodSummarySheet(
      excel: excel,
      sheetName: 'Daily',
      transactions: transactions,
      categoryMap: categoryMap,
      from: from,
      to: to,
      periodKeyFn: (d) => _fmtDate(d),
      periodLabelFn: (key) => key,
      allPeriodKeysFn: (from, to) {
        final keys = <String>[];
        var d = DateTime(from.year, from.month, from.day);
        final end = DateTime(to.year, to.month, to.day);
        while (!d.isAfter(end)) {
          keys.add(_fmtDate(d));
          d = d.add(const Duration(days: 1));
        }
        return keys;
      },
    );
  }

  // ── Sheet 5: Weekly Summary ─────────────────────────────────

  void _buildWeeklySummarySheet(
    Excel excel,
    List<TransactionData> transactions,
    Map<String, String> categoryMap,
    DateTime from,
    DateTime to,
  ) {
    _buildPeriodSummarySheet(
      excel: excel,
      sheetName: 'Weekly',
      transactions: transactions,
      categoryMap: categoryMap,
      from: from,
      to: to,
      periodKeyFn: (d) {
        final monday = d.subtract(Duration(days: d.weekday - 1));
        return _fmtDate(monday);
      },
      periodLabelFn: (key) {
        final monday = DateTime.parse(key);
        final sunday = monday.add(const Duration(days: 6));
        return '${_fmtDate(monday)} to ${_fmtDate(sunday)}';
      },
      allPeriodKeysFn: (from, to) {
        final keys = <String>[];
        var d = DateTime(from.year, from.month, from.day);
        d = d.subtract(Duration(days: d.weekday - 1)); // roll to Monday
        final end = DateTime(to.year, to.month, to.day);
        while (!d.isAfter(end)) {
          keys.add(_fmtDate(d));
          d = d.add(const Duration(days: 7));
        }
        return keys;
      },
    );
  }

  // ── Sheet 6: Fortnightly Summary ────────────────────────────

  void _buildFortnightlySummarySheet(
    Excel excel,
    List<TransactionData> transactions,
    Map<String, String> categoryMap,
    DateTime from,
    DateTime to,
  ) {
    final fortnightKeyFn = (DateTime d) {
      final yearStart = DateTime(d.year, 1, 1);
      final dayOfYear = d.difference(yearStart).inDays;
      final fortnightIndex = dayOfYear ~/ 14;
      final fortnightStart =
          yearStart.add(Duration(days: fortnightIndex * 14));
      return _fmtDate(fortnightStart);
    };
    _buildPeriodSummarySheet(
      excel: excel,
      sheetName: 'Fortnightly',
      transactions: transactions,
      categoryMap: categoryMap,
      from: from,
      to: to,
      periodKeyFn: fortnightKeyFn,
      periodLabelFn: (key) {
        final start = DateTime.parse(key);
        final end = start.add(const Duration(days: 13));
        return '${_fmtDate(start)} to ${_fmtDate(end)}';
      },
      allPeriodKeysFn: (from, to) {
        final keys = <String>[];
        final seen = <String>{};
        var d = DateTime(from.year, from.month, from.day);
        final end = DateTime(to.year, to.month, to.day);
        while (!d.isAfter(end)) {
          final key = fortnightKeyFn(d);
          if (seen.add(key)) keys.add(key);
          d = d.add(const Duration(days: 1));
        }
        return keys;
      },
    );
  }

  // ── Sheet 7: Monthly Summary ────────────────────────────────

  void _buildMonthlySummarySheet(
    Excel excel,
    List<TransactionData> transactions,
    Map<String, String> categoryMap,
    DateTime from,
    DateTime to,
  ) {
    _buildPeriodSummarySheet(
      excel: excel,
      sheetName: 'Monthly',
      transactions: transactions,
      categoryMap: categoryMap,
      from: from,
      to: to,
      periodKeyFn: (d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}',
      periodLabelFn: (key) => key,
      allPeriodKeysFn: (from, to) {
        final keys = <String>[];
        var y = from.year;
        var m = from.month;
        while (y < to.year || (y == to.year && m <= to.month)) {
          keys.add('$y-${m.toString().padLeft(2, '0')}');
          m++;
          if (m > 12) { m = 1; y++; }
        }
        return keys;
      },
    );
  }

  // ── Sheet 8: Yearly Summary ─────────────────────────────────

  void _buildYearlySummarySheet(
    Excel excel,
    List<TransactionData> transactions,
    Map<String, String> categoryMap,
    DateTime from,
    DateTime to,
  ) {
    _buildPeriodSummarySheet(
      excel: excel,
      sheetName: 'Yearly',
      transactions: transactions,
      categoryMap: categoryMap,
      from: from,
      to: to,
      periodKeyFn: (d) => '${d.year}',
      periodLabelFn: (key) => key,
      allPeriodKeysFn: (from, to) {
        final keys = <String>[];
        for (var y = from.year; y <= to.year; y++) {
          keys.add('$y');
        }
        return keys;
      },
    );
  }

  // ── Sheet 9: Wallets ────────────────────────────────────────

  void _buildWalletsSheet(
    Excel excel,
    List<TransactionData> transactions,
  ) {
    final sheet = excel['Wallets'];

    sheet.appendRow([
      TextCellValue('Currency'),
      TextCellValue('Income'),
      TextCellValue('Spent'),
      TextCellValue('Exchanged In'),
      TextCellValue('Exchanged Out'),
      TextCellValue('Balance'),
      TextCellValue('(Computed summary)'),
    ]);

    final currencies = <String>{};
    for (final tx in transactions) {
      currencies.add(tx.originalCurrency);
    }

    final sortedCurrencies = currencies.toList()..sort();

    for (final currency in sortedCurrencies) {
      final currencyTxs =
          transactions.where((tx) => tx.originalCurrency == currency);

      double income = 0;
      double spent = 0;
      double exchangedIn = 0;
      double exchangedOut = 0;

      for (final tx in currencyTxs) {
        switch (tx.transactionType) {
          case 'currency_income':
            income += tx.originalAmount.abs();
            break;
          case 'expense':
            spent += tx.originalAmount.abs();
            break;
          case 'currency_exchange_in':
            exchangedIn += tx.originalAmount.abs();
            break;
          case 'currency_exchange_out':
            exchangedOut += tx.originalAmount.abs();
            break;
        }
      }

      final balance = income + exchangedIn - spent - exchangedOut;

      sheet.appendRow([
        TextCellValue(currency),
        DoubleCellValue(income),
        DoubleCellValue(spent),
        DoubleCellValue(exchangedIn),
        DoubleCellValue(exchangedOut),
        DoubleCellValue(balance),
      ]);
    }
  }

  // ── Generic period summary builder ──────────────────────────

  void _buildPeriodSummarySheet({
    required Excel excel,
    required String sheetName,
    required List<TransactionData> transactions,
    required Map<String, String> categoryMap,
    required DateTime from,
    required DateTime to,
    required String Function(DateTime) periodKeyFn,
    required String Function(String key) periodLabelFn,
    required List<String> Function(DateTime from, DateTime to) allPeriodKeysFn,
  }) {
    final sheet = excel[sheetName];

    final expenseTxs =
        transactions.where((tx) => tx.transactionType == 'expense').toList();

    final uniqueCategories = <String>{};
    for (final tx in expenseTxs) {
      uniqueCategories.add(_categoryName(tx.categoryId, categoryMap));
    }
    final sortedCategories = uniqueCategories.toList()..sort();

    final headers = [
      TextCellValue('Period'),
      TextCellValue('Total (Base)'),
      TextCellValue('Transaction Count'),
      ...sortedCategories.map((c) => TextCellValue(c)),
      TextCellValue('(Computed summary)'),
    ];
    sheet.appendRow(headers);

    final periodData = <String, _PeriodBucket>{};

    for (final tx in expenseTxs) {
      final key = periodKeyFn(tx.transactionDate);
      final bucket = periodData.putIfAbsent(key, () => _PeriodBucket());
      bucket.total += tx.amountBase;
      bucket.count++;
      final cat = _categoryName(tx.categoryId, categoryMap);
      bucket.categoryTotals[cat] =
          (bucket.categoryTotals[cat] ?? 0) + tx.amountBase;
    }

    // Generate ALL periods in the date range (including empty ones)
    final allKeys = allPeriodKeysFn(from, to);

    for (final key in allKeys) {
      final bucket = periodData[key];
      sheet.appendRow([
        TextCellValue(periodLabelFn(key)),
        DoubleCellValue(bucket?.total ?? 0),
        IntCellValue(bucket?.count ?? 0),
        ...sortedCategories.map(
          (c) => DoubleCellValue(bucket?.categoryTotals[c] ?? 0),
        ),
      ]);
    }
  }

  // ── Notifications ───────────────────────────────────────────

  Future<void> _showExportCompleteNotification(String filePath, int rowCount) async {
    const androidDetails = AndroidNotificationDetails(
      'export_complete',
      'Export Complete',
      channelDescription: 'Notifies when Excel export is ready',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await FlutterLocalNotificationsPlugin().show(
      id: 9999,
      title: 'Excel Export Complete',
      body: '$rowCount transactions exported successfully.',
      notificationDetails: details,
    );
  }




  // ── Helpers ─────────────────────────────────────────────────

  /// Auto-size columns based on content length (header + data rows).
  /// The `excel` package doesn't have built-in autofit, so we estimate
  /// widths from the longest cell value in each column.
  void _autoFitColumns(Sheet sheet) {
    final maxCols = sheet.maxColumns;
    final maxRows = sheet.maxRows;

    for (int col = 0; col < maxCols; col++) {
      double maxWidth = 8.0; // minimum column width
      for (int row = 0; row < maxRows; row++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
        );
        final value = cell.value;
        if (value != null) {
          final length = value.toString().length;
          final estimated = (length * 1.2) + 2;
          if (estimated > maxWidth) maxWidth = estimated;
        }
      }
      // Cap at 50 to avoid absurdly wide columns (e.g. UUIDs)
      sheet.setColumnWidth(col, maxWidth.clamp(8.0, 50.0));
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

  String _categoryName(String? categoryId, Map<String, String> categoryMap) {
    if (categoryId == null) return 'Uncategorized';
    return categoryMap[categoryId] ?? 'Unknown';
  }
}

class _PeriodBucket {
  double total = 0;
  int count = 0;
  final Map<String, double> categoryTotals = {};
}
