import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

      var excel = Excel.createExcel();

      _buildAllTransactionsSheet(excel, transactions, categoryMap);
      _buildCurrencyIncomeSheet(excel, transactions, categoryMap);
      _buildCurrencyExchangesSheet(excel, transactions);
      _buildDailySummarySheet(excel, transactions, categoryMap);
      _buildWeeklySummarySheet(excel, transactions, categoryMap);
      _buildFortnightlySummarySheet(excel, transactions, categoryMap);
      _buildMonthlySummarySheet(excel, transactions, categoryMap);
      _buildYearlySummarySheet(excel, transactions, categoryMap);
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

      final file = await _saveFile(fileBytes);

      try {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'My Expense Export',
        );
      } on Exception catch (e) {
        debugPrint('Share sheet unavailable, file saved to: ${file.path} ($e)');
      }

      await _showExportCompleteNotification(file.path, transactions.length);

      return ExportResult(success: true, filePath: file.path);
    } on Exception catch (e) {
      debugPrint('Export failed: $e');
      return ExportResult(success: false, error: e.toString());
    }
  }

  // ── Sheet 1: All Transactions ───────────────────────────────

  void _buildAllTransactionsSheet(
    Excel excel,
    List<TransactionData> transactions,
    Map<String, String> categoryMap,
  ) {
    final sheet = excel['All Transactions'];
    excel.setDefaultSheet('All Transactions');

    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Description'),
      TextCellValue('Category'),
      TextCellValue('Original Amount'),
      TextCellValue('Original Currency'),
      TextCellValue('Base Amount'),
      TextCellValue('Exchange Rate'),
      TextCellValue('Rate Source'),
      TextCellValue('UUID'),
    ]);

    for (final tx in transactions) {
      sheet.appendRow([
        TextCellValue(_fmtDate(tx.transactionDate)),
        TextCellValue(tx.transactionType),
        TextCellValue(tx.note ?? ''),
        TextCellValue(_categoryName(tx.categoryId, categoryMap)),
        DoubleCellValue(tx.originalAmount),
        TextCellValue(tx.originalCurrency),
        DoubleCellValue(tx.amountBase),
        DoubleCellValue(tx.exchangeRate),
        TextCellValue(tx.rateSource),
        TextCellValue(tx.id),
      ]);
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
        TextCellValue(_fmtDate(tx.transactionDate)),
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
        TextCellValue(_fmtDate(outTx.transactionDate)),
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
  ) {
    _buildPeriodSummarySheet(
      excel: excel,
      sheetName: 'Daily',
      transactions: transactions,
      categoryMap: categoryMap,
      periodKeyFn: (d) => _fmtDate(d),
      periodLabelFn: (key) => key,
    );
  }

  // ── Sheet 5: Weekly Summary ─────────────────────────────────

  void _buildWeeklySummarySheet(
    Excel excel,
    List<TransactionData> transactions,
    Map<String, String> categoryMap,
  ) {
    _buildPeriodSummarySheet(
      excel: excel,
      sheetName: 'Weekly',
      transactions: transactions,
      categoryMap: categoryMap,
      periodKeyFn: (d) {
        final monday = d.subtract(Duration(days: d.weekday - 1));
        return _fmtDate(monday);
      },
      periodLabelFn: (key) {
        final monday = DateTime.parse(key);
        final sunday = monday.add(const Duration(days: 6));
        return '${_fmtDate(monday)} to ${_fmtDate(sunday)}';
      },
    );
  }

  // ── Sheet 6: Fortnightly Summary ────────────────────────────

  void _buildFortnightlySummarySheet(
    Excel excel,
    List<TransactionData> transactions,
    Map<String, String> categoryMap,
  ) {
    _buildPeriodSummarySheet(
      excel: excel,
      sheetName: 'Fortnightly',
      transactions: transactions,
      categoryMap: categoryMap,
      periodKeyFn: (d) {
        final yearStart = DateTime(d.year, 1, 1);
        final dayOfYear = d.difference(yearStart).inDays;
        final fortnightIndex = dayOfYear ~/ 14;
        final fortnightStart =
            yearStart.add(Duration(days: fortnightIndex * 14));
        return _fmtDate(fortnightStart);
      },
      periodLabelFn: (key) {
        final start = DateTime.parse(key);
        final end = start.add(const Duration(days: 13));
        return '${_fmtDate(start)} to ${_fmtDate(end)}';
      },
    );
  }

  // ── Sheet 7: Monthly Summary ────────────────────────────────

  void _buildMonthlySummarySheet(
    Excel excel,
    List<TransactionData> transactions,
    Map<String, String> categoryMap,
  ) {
    _buildPeriodSummarySheet(
      excel: excel,
      sheetName: 'Monthly',
      transactions: transactions,
      categoryMap: categoryMap,
      periodKeyFn: (d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}',
      periodLabelFn: (key) => key,
    );
  }

  // ── Sheet 8: Yearly Summary ─────────────────────────────────

  void _buildYearlySummarySheet(
    Excel excel,
    List<TransactionData> transactions,
    Map<String, String> categoryMap,
  ) {
    _buildPeriodSummarySheet(
      excel: excel,
      sheetName: 'Yearly',
      transactions: transactions,
      categoryMap: categoryMap,
      periodKeyFn: (d) => '${d.year}',
      periodLabelFn: (key) => key,
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
    required String Function(DateTime) periodKeyFn,
    required String Function(String key) periodLabelFn,
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

    final sortedKeys = periodData.keys.toList()..sort();

    for (final key in sortedKeys) {
      final bucket = periodData[key]!;
      sheet.appendRow([
        TextCellValue(periodLabelFn(key)),
        DoubleCellValue(bucket.total),
        IntCellValue(bucket.count),
        ...sortedCategories.map(
          (c) => DoubleCellValue(bucket.categoryTotals[c] ?? 0),
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

  // ── File I/O ────────────────────────────────────────────────

  Future<File> _saveFile(List<int> bytes) async {
    final date = _fmtDate(DateTime.now());
    final fileName = 'project-pet-export-$date.xlsx';

    Directory directory;
    try {
      directory = await getApplicationDocumentsDirectory();
    } on Exception {
      directory = await getTemporaryDirectory();
    }

    final path = '${directory.path}/$fileName';
    final file = File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    return file;
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
