import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';
import '../models/import_row.dart';

class ImportState {
  final List<ImportRow> rows;
  final bool isParsing;
  final bool isImporting;
  final String? error;
  final Map<String, CategoriesCompanion> pendingCategories;
  final List<CategoryData> existingCategories;

  ImportState({
    this.rows = const [],
    this.isParsing = false,
    this.isImporting = false,
    this.error,
    this.pendingCategories = const {},
    this.existingCategories = const [],
  });

  ImportState copyWith({
    List<ImportRow>? rows,
    bool? isParsing,
    bool? isImporting,
    String? error,
    Map<String, CategoriesCompanion>? pendingCategories,
    List<CategoryData>? existingCategories,
  }) {
    return ImportState(
      rows: rows ?? this.rows,
      isParsing: isParsing ?? this.isParsing,
      isImporting: isImporting ?? this.isImporting,
      error: error,
      pendingCategories: pendingCategories ?? this.pendingCategories,
      existingCategories: existingCategories ?? this.existingCategories,
    );
  }
}

final importProvider = StateNotifierProvider.autoDispose<ImportNotifier, ImportState>((ref) {
  return ImportNotifier(ref);
});

class ImportNotifier extends StateNotifier<ImportState> {
  final Ref _ref;

  ImportNotifier(this._ref) : super(ImportState());

  /// Sets the checked state of a specific row in the preview
  void toggleRowChecked(int index, bool checked) {
    if (state.rows.length <= index) return;
    final updatedRows = List<ImportRow>.from(state.rows);
    updatedRows[index] = updatedRows[index].copyWith(checked: checked);
    state = state.copyWith(rows: updatedRows);
  }

  /// Sets checked state for all rows matching status
  void toggleAllRows(bool checked, {ImportRowStatus? status}) {
    final updatedRows = state.rows.map((row) {
      if (status != null && row.status != status) return row;
      if (row.status == ImportRowStatus.error) return row.copyWith(checked: false);
      return row.copyWith(checked: checked);
    }).toList();
    state = state.copyWith(rows: updatedRows);
  }

  /// Updates the parent of a pending auto-created category.
  /// When a parent is set, the category colour is automatically inherited from the parent.
  void updatePendingCategoryParent(String categoryId, String? parentId) {
    if (!state.pendingCategories.containsKey(categoryId)) return;
    
    final updatedCategories = Map<String, CategoriesCompanion>.from(state.pendingCategories);
    final companion = updatedCategories[categoryId]!;
    
    // Resolve parent colour and icon so subcategories auto-inherit them
    String? parentColour;
    int? parentIcon;
    if (parentId != null) {
      // Check existing DB categories first
      final parentCat = state.existingCategories.where((c) => c.id == parentId).firstOrNull;
      if (parentCat != null) {
        parentColour = parentCat.colourHex;
        parentIcon = parentCat.iconCodePoint;
      } else if (updatedCategories.containsKey(parentId)) {
        // Fallback: check other pending categories
        parentColour = updatedCategories[parentId]!.colourHex.value;
        parentIcon = updatedCategories[parentId]!.iconCodePoint.value;
      }
    }
    
    updatedCategories[categoryId] = companion.copyWith(
      parentId: Value(parentId),
      // Auto-inherit parent colour and icon when becoming a subcategory
      colourHex: parentColour != null ? Value(parentColour) : companion.colourHex,
      iconCodePoint: parentIcon != null ? Value(parentIcon) : companion.iconCodePoint,
    );
    
    state = state.copyWith(pendingCategories: updatedCategories);
  }

  /// Updates the colour of a pending category (only applicable to top-level categories)
  void updatePendingCategoryColor(String categoryId, String colourHex) {
    if (!state.pendingCategories.containsKey(categoryId)) return;
    
    final updatedCategories = Map<String, CategoriesCompanion>.from(state.pendingCategories);
    final companion = updatedCategories[categoryId]!;
    
    updatedCategories[categoryId] = companion.copyWith(
      colourHex: Value(colourHex),
    );
    
    state = state.copyWith(pendingCategories: updatedCategories);
  }

  /// Updates the icon of a pending category
  void updatePendingCategoryIcon(String categoryId, int iconCodePoint) {
    if (!state.pendingCategories.containsKey(categoryId)) return;
    
    final updatedCategories = Map<String, CategoriesCompanion>.from(state.pendingCategories);
    final companion = updatedCategories[categoryId]!;
    
    updatedCategories[categoryId] = companion.copyWith(
      iconCodePoint: Value(iconCodePoint),
    );
    
    state = state.copyWith(pendingCategories: updatedCategories);
  }

  /// Parses Excel file and validates contents
  Future<void> parseExcel(String filePath) async {
    state = state.copyWith(isParsing: true, rows: [], error: null);

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        state = state.copyWith(isParsing: false, error: 'File does not exist');
        return;
      }

      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final db = _ref.read(databaseProvider);
      
      // Fetch categories & existing transactions for duplicate detection
      final categories = await db.categoryDao.getAll();
      final existingTxns = await db.select(db.transactions).get();
      final baseCurrency = await db.getSetting('base_currency') ?? 'AUD';

      final catMap = {for (var c in categories) c.name.toLowerCase().trim(): c.id};
      final autoCreatedCategoryNames = <String>{};

      // Create a map of keys for duplicate checking: date_amount_category
      final duplicateKeys = <String, List<TransactionData>>{};
      for (final t in existingTxns) {
        if (t.deletedAt == null && t.transactionType == 'expense') {
          final key = '${_fmtDate(t.transactionDate)}_${t.originalAmount.toStringAsFixed(4)}_${t.categoryId ?? ""}';
          duplicateKeys.putIfAbsent(key, () => []).add(t);
        }
      }

      // Create a map of keys for income duplicate checking: date_amount_currency
      final incomeDuplicateKeys = <String, List<TransactionData>>{};
      for (final t in existingTxns) {
        if (t.deletedAt == null && t.transactionType == 'currency_income') {
          final key = '${_fmtDate(t.transactionDate)}_${t.originalAmount.toStringAsFixed(4)}_${t.originalCurrency}';
          incomeDuplicateKeys.putIfAbsent(key, () => []).add(t);
        }
      }

      // Create a map of keys for exchange duplicate checking: date_amount_fromCurrency_toAmount
      // We look at currency_exchange_out rows as the representative side
      final exchangeDuplicateKeys = <String, List<TransactionData>>{};
      for (final t in existingTxns) {
        if (t.deletedAt == null && t.transactionType == 'currency_exchange_out') {
          final key = '${_fmtDate(t.transactionDate)}_${t.originalAmount.toStringAsFixed(4)}_${t.originalCurrency}_${t.amountBase.toStringAsFixed(4)}';
          exchangeDuplicateKeys.putIfAbsent(key, () => []).add(t);
        }
      }

      final parsedRows = <ImportRow>[];
      final seenUuidsInFile = <String>{};
      final pendingCats = <String, CategoriesCompanion>{};

      // 1. Parse "All Transactions" sheet
      if (excel.sheets.containsKey('All Transactions')) {
        final sheet = excel.sheets['All Transactions']!;
        if (sheet.maxRows > 1) {
          final headerRow = sheet.rows.first;
          final headers = headerRow.map((c) => _parseString(c?.value)?.toLowerCase() ?? '').toList();

          final dateIdx = headers.indexOf('date');
          final typeIdx = headers.indexOf('type');
          final descIdx = headers.indexOf('description');
          final catIdx = headers.indexOf('category');
          final subcatOfIdx = headers.indexOf('subcategory of');
          final catColorIdx = headers.indexOf('category color');
          final catIconIdx = headers.indexOf('category icon');
          final origAmtIdx = headers.indexOf('original amount');
          final origCurrIdx = headers.indexOf('original currency');
          final baseAmtIdx = headers.indexOf('base amount');
          final rateIdx = headers.indexOf('exchange rate');
          final rateSrcIdx = headers.indexOf('rate source');
          final uuidIdx = headers.indexOf('uuid');
          final periodIdx = headers.indexOf('period');

          if (dateIdx == -1 || typeIdx == -1 || origAmtIdx == -1 || origCurrIdx == -1) {
            state = state.copyWith(
              isParsing: false,
              error: "Missing mandatory headers ('Date', 'Type', 'Original Amount', or 'Original Currency') in 'All Transactions' sheet.",
            );
            return;
          }

          for (int r = 1; r < sheet.maxRows; r++) {
            final row = sheet.rows[r];
            if (row.isEmpty || row.every((c) => c?.value == null)) continue;

            final typeStr = _parseString(row[typeIdx]?.value);
            if (typeStr == 'no_transaction') continue; // Skip empty dates

            // Skip specialized types if their dedicated sheets exist, so they are parsed 
            // with their full contextual data and not duplicated.
            if ((typeStr == 'currency_exchange_out' || typeStr == 'currency_exchange_in') && 
                excel.sheets.containsKey('Currency Exchanges')) {
              continue;
            }
            if (typeStr == 'currency_income' && excel.sheets.containsKey('Currency Income')) {
              continue;
            }

            final dateVal = _parseDate(row[dateIdx]?.value);
            final amtVal = _parseDouble(row[origAmtIdx]?.value);
            final currVal = _parseString(row[origCurrIdx]?.value);
            final descVal = _parseString(row[descIdx]?.value);
            final catVal = _parseString(row[catIdx]?.value);
            final subcatOfVal = subcatOfIdx != -1 ? _parseString(row[subcatOfIdx]?.value) : null;
            final catColorVal = catColorIdx != -1 ? _parseString(row[catColorIdx]?.value) : null;
            final catIconVal = catIconIdx != -1 ? _parseInt(row[catIconIdx]?.value) : null;
            final baseAmtVal = baseAmtIdx != -1 ? _parseDouble(row[baseAmtIdx]?.value) : null;
            final rateVal = rateIdx != -1 ? _parseDouble(row[rateIdx]?.value) : null;
            final rateSrcVal = rateSrcIdx != -1 ? _parseString(row[rateSrcIdx]?.value) : 'import';
            var uuidVal = uuidIdx != -1 ? _parseString(row[uuidIdx]?.value) : null;
            final periodVal = periodIdx != -1 ? _parseString(row[periodIdx]?.value) : null;

            // Basic validation
            String? errorMsg;
            if (dateVal == null) {
              errorMsg = 'Row ${r + 1}: Missing or invalid Date';
            } else if (typeStr == null || !['expense', 'currency_income', 'currency_exchange_out', 'currency_exchange_in'].contains(typeStr)) {
              errorMsg = 'Row ${r + 1}: Invalid or missing transaction type';
            } else if (amtVal == null || amtVal <= 0) {
              errorMsg = 'Row ${r + 1}: Invalid or missing Original Amount';
            } else if (currVal == null || currVal.length != 3) {
              errorMsg = 'Row ${r + 1}: Invalid or missing Original Currency';
            }

            // Category validation for expenses
            String? resolvedCatId;
            if (errorMsg == null && typeStr == 'expense') {
              if (catVal == null || catVal.isEmpty) {
                errorMsg = 'Row ${r + 1}: Category is required for expenses';
              } else {
                resolvedCatId = _resolveCategoryId(catVal, catMap, categories);
                if (resolvedCatId == null) {
                  // Auto-create the missing category, preserving its color, icon and parent
                  resolvedCatId = _autoCreateCategory(
                    pendingCats,
                    catVal,
                    catMap,
                    categories,
                    parentName: subcatOfVal,
                    colourHex: catColorVal,
                    iconCodePoint: catIconVal,
                  );
                  autoCreatedCategoryNames.add(catVal);
                }
              }
            }

            // Duplicate UUID check in the same file
            if (errorMsg == null && uuidVal != null && uuidVal.isNotEmpty) {
              if (!seenUuidsInFile.add(uuidVal)) {
                errorMsg = 'Row ${r + 1}: Duplicate UUID "$uuidVal" found in the file';
              }
            }

            // Aggregate / Missing date calculation
            bool isAggregate = false;
            DateTime finalDate = dateVal ?? DateTime.now();
            String? cleanNote = descVal;

            if (errorMsg == null) {
              // 1. Period column check
              if (periodVal != null && ['week', 'fortnight', 'month', 'year'].contains(periodVal.toLowerCase().trim())) {
                isAggregate = true;
                finalDate = _adjustDateToPeriodStart(finalDate, periodVal);
              }
              // 2. Note prefix fallback
              else if (descVal != null) {
                final match = RegExp(r'^\[(WEEK|FORTNIGHT|MONTH|YEAR)\]', caseSensitive: false).firstMatch(descVal);
                if (match != null) {
                  isAggregate = true;
                  final periodStr = match.group(1)!;
                  finalDate = _adjustDateToPeriodStart(finalDate, periodStr);
                  // Strip prefix
                  cleanNote = descVal.replaceFirst(RegExp(r'^\[.*?\]\s*'), '');
                }
              }
            }

            // Base currency rates calculations
            double finalRate = rateVal ?? 1.0;
            double finalBaseAmt = baseAmtVal ?? 0.0;
            if (errorMsg == null) {
              if (currVal == baseCurrency) {
                finalRate = 1.0;
                finalBaseAmt = amtVal!;
              } else if (rateVal != null) {
                finalBaseAmt = baseAmtVal ?? (amtVal! * rateVal);
              } else {
                // Fetch cached rate if possible
                final cachedRate = await db.exchangeRateDao.getRate(currVal!, baseCurrency, finalDate);
                if (cachedRate != null) {
                  finalRate = cachedRate.rate;
                  finalBaseAmt = amtVal! * finalRate;
                } else {
                  // Try most recent fallback
                  final recentRate = await db.exchangeRateDao.getMostRecent(currVal, baseCurrency);
                  if (recentRate != null) {
                    finalRate = recentRate.rate;
                    finalBaseAmt = amtVal! * finalRate;
                  } else {
                    finalRate = 1.0;
                    finalBaseAmt = amtVal!;
                  }
                }
              }
            }

            // Determine status
            ImportRowStatus status = ImportRowStatus.ready;
            if (errorMsg != null) {
              status = ImportRowStatus.error;
            } else {
              final dupKey = '${_fmtDate(finalDate)}_${amtVal!.toStringAsFixed(4)}_${resolvedCatId ?? ""}';
              final incDupKey = '${_fmtDate(finalDate)}_${amtVal.toStringAsFixed(4)}_$currVal';
              
              if (typeStr == 'expense' && duplicateKeys[dupKey]?.isNotEmpty == true) {
                final existing = duplicateKeys[dupKey]!.removeAt(0);
                if (uuidVal != null && uuidVal == existing.id) {
                  status = ImportRowStatus.update;
                } else {
                  uuidVal = null;
                  status = ImportRowStatus.duplicate;
                }
              } else if (typeStr == 'currency_income' && incomeDuplicateKeys[incDupKey]?.isNotEmpty == true) {
                final existing = incomeDuplicateKeys[incDupKey]!.removeAt(0);
                if (uuidVal != null && uuidVal == existing.id) {
                  status = ImportRowStatus.update;
                } else {
                  uuidVal = null;
                  status = ImportRowStatus.duplicate;
                }
              }
            }

            parsedRows.add(ImportRow(
              rowIndex: r + 1,
              rowType: ImportRowType.transaction,
              date: finalDate,
              transactionType: typeStr ?? 'expense',
              note: cleanNote,
              categoryName: catVal,
              categoryId: resolvedCatId,
              originalAmount: amtVal ?? 0.0,
              originalCurrency: currVal ?? 'AUD',
              amountBase: finalBaseAmt,
              exchangeRate: finalRate,
              rateSource: rateSrcVal ?? 'import',
              id: uuidVal,
              isAggregate: isAggregate,
              status: status,
              errorMessage: errorMsg,
              checked: status == ImportRowStatus.ready || status == ImportRowStatus.update,
            ));
          }
        }
      }

      // 2. Parse "Currency Income" sheet
      if (excel.sheets.containsKey('Currency Income')) {
        final sheet = excel.sheets['Currency Income']!;
        if (sheet.maxRows > 1) {
          final headerRow = sheet.rows.first;
          final headers = headerRow.map((c) => _parseString(c?.value)?.toLowerCase() ?? '').toList();

          final dateIdx = headers.indexOf('date');
          final currIdx = headers.indexOf('currency');
          final amtIdx = headers.indexOf('amount');
          final srcIdx = headers.indexOf('source');
          final baseEquivIdx = headers.indexOf('base currency equivalent');
          final uuidIdx = headers.indexOf('uuid');

          if (dateIdx == -1 || currIdx == -1 || amtIdx == -1) {
            state = state.copyWith(
              isParsing: false,
              error: "Missing mandatory headers ('Date', 'Currency', or 'Amount') in 'Currency Income' sheet.",
            );
            return;
          }

          for (int r = 1; r < sheet.maxRows; r++) {
            final row = sheet.rows[r];
            if (row.isEmpty || row.every((c) => c?.value == null)) continue;

            var uuidVal = uuidIdx != -1 ? _parseString(row[uuidIdx]?.value) : null;
            
            // Avoid double-processing if it was already in "All Transactions"
            if (uuidVal != null && uuidVal.isNotEmpty && seenUuidsInFile.contains(uuidVal)) {
              continue;
            }

            final dateVal = _parseDate(row[dateIdx]?.value);
            final currVal = _parseString(row[currIdx]?.value);
            final amtVal = _parseDouble(row[amtIdx]?.value);
            final srcVal = srcIdx != -1 ? _parseString(row[srcIdx]?.value) : null;
            final baseEquivVal = baseEquivIdx != -1 ? _parseDouble(row[baseEquivIdx]?.value) : null;

            String? errorMsg;
            if (dateVal == null) {
              errorMsg = 'Row ${r + 1}: Missing or invalid Date';
            } else if (currVal == null || currVal.length != 3) {
              errorMsg = 'Row ${r + 1}: Invalid or missing Currency';
            } else if (amtVal == null || amtVal <= 0) {
              errorMsg = 'Row ${r + 1}: Invalid or missing Amount';
            }

            if (errorMsg == null && uuidVal != null && uuidVal.isNotEmpty) {
              seenUuidsInFile.add(uuidVal);
            }

            double finalRate = 1.0;
            double finalBaseAmt = baseEquivVal ?? 0.0;
            if (errorMsg == null) {
              if (currVal == baseCurrency) {
                finalRate = 1.0;
                finalBaseAmt = amtVal!;
              } else if (baseEquivVal != null) {
                finalRate = baseEquivVal / amtVal!;
              } else {
                final cachedRate = await db.exchangeRateDao.getRate(currVal!, baseCurrency, dateVal!);
                if (cachedRate != null) {
                  finalRate = cachedRate.rate;
                  finalBaseAmt = amtVal! * finalRate;
                } else {
                  finalRate = 1.0;
                  finalBaseAmt = amtVal!;
                }
              }
            }

            ImportRowStatus status = ImportRowStatus.ready;
            if (errorMsg != null) {
              status = ImportRowStatus.error;
            } else {
              final dupKey = '${_fmtDate(dateVal!)}_${amtVal!.toStringAsFixed(4)}_${currVal!}';
              if (incomeDuplicateKeys[dupKey]?.isNotEmpty == true) {
                final existing = incomeDuplicateKeys[dupKey]!.removeAt(0);
                if (uuidVal != null && uuidVal == existing.id) {
                  status = ImportRowStatus.update;
                } else {
                  uuidVal = null;
                  status = ImportRowStatus.duplicate;
                }
              }
            }

            parsedRows.add(ImportRow(
              rowIndex: r + 1,
              rowType: ImportRowType.income,
              date: dateVal ?? DateTime.now(),
              transactionType: 'currency_income',
              note: srcVal,
              sourceLabel: srcVal,
              originalAmount: amtVal ?? 0.0,
              originalCurrency: currVal ?? 'AUD',
              amountBase: finalBaseAmt,
              exchangeRate: finalRate,
              rateSource: 'import',
              id: uuidVal,
              isAggregate: false,
              status: status,
              errorMessage: errorMsg,
              checked: status == ImportRowStatus.ready || status == ImportRowStatus.update,
            ));
          }
        }
      }

      // 3. Parse "Currency Exchanges" sheet
      if (excel.sheets.containsKey('Currency Exchanges')) {
        final sheet = excel.sheets['Currency Exchanges']!;
        if (sheet.maxRows > 1) {
          final headerRow = sheet.rows.first;
          final headers = headerRow.map((c) => _parseString(c?.value)?.toLowerCase() ?? '').toList();

          final dateIdx = headers.indexOf('date');
          final fromCurrIdx = headers.indexOf('from currency');
          final fromAmtIdx = headers.indexOf('from amount');
          final toCurrIdx = headers.indexOf('to currency');
          final toAmtIdx = headers.indexOf('to amount');
          final rateIdx = headers.indexOf('rate');
          final rateSrcIdx = headers.indexOf('rate source');
          final noteIdx = headers.indexOf('note');
          final uuidIdx = headers.indexOf('uuid');

          if (dateIdx == -1 || fromCurrIdx == -1 || fromAmtIdx == -1 || toCurrIdx == -1 || toAmtIdx == -1) {
            state = state.copyWith(
              isParsing: false,
              error: "Missing mandatory headers ('Date', 'From Currency', 'From Amount', 'To Currency', or 'To Amount') in 'Currency Exchanges' sheet.",
            );
            return;
          }

          for (int r = 1; r < sheet.maxRows; r++) {
            final row = sheet.rows[r];
            if (row.isEmpty || row.every((c) => c?.value == null)) continue;

            var uuidVal = uuidIdx != -1 ? _parseString(row[uuidIdx]?.value) : null;
            if (uuidVal != null && uuidVal.isNotEmpty && seenUuidsInFile.contains(uuidVal)) {
              continue;
            }

            final dateVal = _parseDate(row[dateIdx]?.value);
            final fromCurr = _parseString(row[fromCurrIdx]?.value);
            final fromAmt = _parseDouble(row[fromAmtIdx]?.value);
            final toCurr = _parseString(row[toCurrIdx]?.value);
            final toAmt = _parseDouble(row[toAmtIdx]?.value);
            final rateVal = rateIdx != -1 ? _parseDouble(row[rateIdx]?.value) : null;
            final rateSrc = rateSrcIdx != -1 ? _parseString(row[rateSrcIdx]?.value) : 'import';
            final noteVal = noteIdx != -1 ? _parseString(row[noteIdx]?.value) : null;

            String? errorMsg;
            if (dateVal == null) {
              errorMsg = 'Row ${r + 1}: Missing or invalid Date';
            } else if (fromCurr == null || fromCurr.length != 3) {
              errorMsg = 'Row ${r + 1}: Invalid or missing From Currency';
            } else if (fromAmt == null || fromAmt <= 0) {
              errorMsg = 'Row ${r + 1}: Invalid or missing From Amount';
            } else if (toCurr == null || toCurr.length != 3) {
              errorMsg = 'Row ${r + 1}: Invalid or missing To Currency';
            } else if (toAmt == null || toAmt <= 0) {
              errorMsg = 'Row ${r + 1}: Invalid or missing To Amount';
            } else if (fromCurr == toCurr) {
              errorMsg = 'Row ${r + 1}: From and To currencies must be different';
            }

            if (errorMsg == null && uuidVal != null && uuidVal.isNotEmpty) {
              seenUuidsInFile.add(uuidVal);
            }

            double finalRate = rateVal ?? (fromAmt! / toAmt!);

            ImportRowStatus status = ImportRowStatus.ready;
            String? rowId;
            if (errorMsg != null) {
              status = ImportRowStatus.error;
            } else {
              final dupKey = '${_fmtDate(dateVal!)}_${fromAmt!.toStringAsFixed(4)}_${fromCurr!}_${toAmt!.toStringAsFixed(4)}';
              if (exchangeDuplicateKeys[dupKey]?.isNotEmpty == true) {
                final existingTx = exchangeDuplicateKeys[dupKey]!.removeAt(0);
                if (uuidVal != null && (uuidVal == existingTx.exchangeEventId || uuidVal == existingTx.id)) {
                  uuidVal = existingTx.exchangeEventId ?? existingTx.id;
                  rowId = existingTx.id;
                  status = ImportRowStatus.update;
                } else {
                  uuidVal = null;
                  rowId = null;
                  status = ImportRowStatus.duplicate;
                }
              }
            }

            parsedRows.add(ImportRow(
              rowIndex: r + 1,
              rowType: ImportRowType.exchange,
              date: dateVal ?? DateTime.now(),
              transactionType: 'currency_exchange_out',
              note: noteVal,
              sourceLabel: toCurr, // Reuse sourceLabel to store toCurrency
              originalAmount: fromAmt ?? 0.0,
              originalCurrency: fromCurr ?? 'AUD',
              amountBase: toAmt ?? 0.0, // Reuse amountBase to store toAmount
              exchangeRate: finalRate,
              rateSource: rateSrc ?? 'import',
              exchangeEventId: uuidVal,
              id: rowId,
              isAggregate: false,
              status: status,
              errorMessage: errorMsg,
              checked: status == ImportRowStatus.ready || status == ImportRowStatus.update,
            ));
          }
        }
      }

      state = state.copyWith(
        rows: parsedRows, 
        isParsing: false, 
        pendingCategories: pendingCats,
        existingCategories: categories,
      );
    } catch (e) {
      debugPrint('Parsing error: $e');
      state = state.copyWith(isParsing: false, error: 'Failed to parse Excel file: ${e.toString()}');
    }
  }

  /// Commits checked rows to the local Drift database
  Future<bool> importCheckedRows() async {
    final checkedRows = state.rows.where((row) => row.checked && row.status != ImportRowStatus.error).toList();
    if (checkedRows.isEmpty) return true;

    state = state.copyWith(isImporting: true);
    final db = _ref.read(databaseProvider);

    try {
      await db.transaction(() async {
        // Insert any required pending categories
        final requiredCategoryIds = checkedRows.map((r) => r.categoryId).where((id) => id != null).toSet();
        for (final catId in requiredCategoryIds) {
          if (state.pendingCategories.containsKey(catId)) {
            final companion = state.pendingCategories[catId]!;
            await db.categoryDao.insertCategory(companion);
            
            // Queue category for sync
            await db.addToSyncQueue(
              id: const Uuid().v4(),
              recordType: 'category',
              recordId: catId!,
              operation: 'insert',
              payload: '{}',
            );
          }
        }

        for (final row in checkedRows) {
          final now = DateTime.now();

          if (row.rowType == ImportRowType.exchange) {
            // Exchanges consist of 2 records sharing exchangeEventId
            final eventId = row.exchangeEventId ?? const Uuid().v4();
            final outId = row.id ?? const Uuid().v4();
            
            // Try to find the paired inSide transaction if editing
            String inId = const Uuid().v4();
            if (row.id != null) {
              final paired = await db.transactionDao.getPairedTransaction(eventId, row.id!);
              if (paired != null) {
                inId = paired.id;
              }
            }

            final outSide = TransactionsCompanion(
              id: Value(outId),
              transactionType: const Value('currency_exchange_out'),
              amountBase: Value(row.amountBase),
              originalAmount: Value(row.originalAmount),
              originalCurrency: Value(row.originalCurrency),
              exchangeRate: Value(row.exchangeRate),
              rateDate: Value(row.date),
              exchangeEventId: Value(eventId),
              transactionDate: Value(row.date),
              note: Value(row.note),
              updatedAt: Value(now),
              syncStatus: const Value('pending'),
            );

            final inSide = TransactionsCompanion(
              id: Value(inId),
              transactionType: const Value('currency_exchange_in'),
              amountBase: Value(row.amountBase),
              originalAmount: Value(row.amountBase), // For IN it is toAmount
              originalCurrency: Value(row.sourceLabel!), // Holds toCurrency
              exchangeRate: const Value(1.0),
              rateDate: Value(row.date),
              exchangeEventId: Value(eventId),
              transactionDate: Value(row.date),
              note: Value(row.note),
              updatedAt: Value(now),
              syncStatus: const Value('pending'),
            );

            await db.into(db.transactions).insertOnConflictUpdate(outSide);
            await db.into(db.transactions).insertOnConflictUpdate(inSide);

            // Add to Sync Queue
            await db.addToSyncQueue(
              id: const Uuid().v4(),
              recordType: 'transaction',
              recordId: outId,
              operation: row.status == ImportRowStatus.update ? 'update' : 'insert',
              payload: '{}',
            );
            await db.addToSyncQueue(
              id: const Uuid().v4(),
              recordType: 'transaction',
              recordId: inId,
              operation: row.status == ImportRowStatus.update ? 'update' : 'insert',
              payload: '{}',
            );
          } else {
            // Normal expense / income rows
            final id = row.id ?? const Uuid().v4();
            final entry = TransactionsCompanion(
              id: Value(id),
              transactionType: Value(row.transactionType),
              amountBase: Value(row.amountBase),
              originalAmount: Value(row.originalAmount),
              originalCurrency: Value(row.originalCurrency),
              exchangeRate: Value(row.exchangeRate),
              rateDate: Value(row.date),
              categoryId: Value(row.categoryId),
              note: Value(row.note),
              transactionDate: Value(row.date),
              sourceLabel: Value(row.sourceLabel),
              isAggregate: Value(row.isAggregate),
              updatedAt: Value(now),
              syncStatus: const Value('pending'),
            );

            await db.into(db.transactions).insertOnConflictUpdate(entry);

            // Add to Sync Queue
            await db.addToSyncQueue(
              id: const Uuid().v4(),
              recordType: 'transaction',
              recordId: id,
              operation: row.status == ImportRowStatus.update ? 'update' : 'insert',
              payload: '{}',
            );
          }
        }
      });

      state = state.copyWith(isImporting: false, rows: []);
      return true;
    } catch (e) {
      debugPrint('Import error: $e');
      state = state.copyWith(isImporting: false, error: 'Import failed: ${e.toString()}');
      return false;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _resolveCategoryId(String name, Map<String, String> catMap, List<CategoryData> categories) {
    final clean = name.toLowerCase().trim();
    if (catMap.containsKey(clean)) return catMap[clean];

    // Check aliases
    if (clean == 'uncategorized' || clean == 'uncategorised' || clean == 'unknown') {
      for (final c in categories) {
        final cName = c.name.toLowerCase();
        if (cName.contains('other') || cName.contains('uncategorised')) {
          return c.id;
        }
      }
    }

    // Fuzzy matching
    for (final c in categories) {
      final cName = c.name.toLowerCase();
      if (cName.contains(clean) || clean.contains(cName)) {
        return c.id;
      }
    }
    return null;
  }

  /// Auto-creates a missing category in memory during parsing.
  /// If [parentName] is provided, the parent is resolved (or also auto-created)
  /// and the new category is linked to it as a subcategory.
  /// [colourHex] and [iconCodePoint] from the Excel file are used when available
  /// to exactly restore the category's visual appearance.
  String _autoCreateCategory(
    Map<String, CategoriesCompanion> pendingCats,
    String name,
    Map<String, String> catMap,
    List<CategoryData> categories, {
    String? parentName,
    String? colourHex,
    int? iconCodePoint,
  }) {
    // Resolve or create the parent category first
    String? resolvedParentId;
    if (parentName != null && parentName.isNotEmpty) {
      resolvedParentId = _resolveCategoryId(parentName, catMap, categories);
      if (resolvedParentId == null) {
        // Parent also doesn't exist — create it as a top-level category
        resolvedParentId = _autoCreateCategory(pendingCats, parentName, catMap, categories);
      }
    }

    final id = const Uuid().v4();
    
    // Sort order heuristic combining existing DB categories and pending ones
    final dbMaxSort = categories.isEmpty
        ? 0
        : categories.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b);
    final pendingMaxSort = pendingCats.isEmpty 
        ? 0 
        : pendingCats.values.map((c) => c.sortOrder.value).reduce((a, b) => a > b ? a : b);
    final maxSort = dbMaxSort > pendingMaxSort ? dbMaxSort : pendingMaxSort;

    // Use provided colour/icon from export, fall back to hash colour & default icon
    final finalColour = (colourHex != null && colourHex.isNotEmpty)
        ? colourHex
        : _hashColor(name);
    final finalIcon = (iconCodePoint != null && iconCodePoint > 0)
        ? iconCodePoint
        : 0xe148; // Icons.category

    final companion = CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      colourHex: Value(finalColour),
      iconCodePoint: Value(finalIcon),
      isDefault: const Value(false),
      isHidden: const Value(false),
      sortOrder: Value(maxSort + 1),
      parentId: Value(resolvedParentId), // null → top-level, non-null → subcategory
      syncStatus: const Value('pending'),
    );

    // Save to pending list instead of inserting directly
    pendingCats[id] = companion;

    // Update in-memory map so later rows re-use this category
    catMap[name.toLowerCase().trim()] = id;

    debugPrint(
      'Queued category "$name" for auto-creation. colour=$finalColour icon=$finalIcon parentId=$resolvedParentId id=$id',
    );

    return id;
  }

  /// Generates a deterministic hex colour from a category name.
  /// Uses HSL with varied hue, fixed saturation/lightness for visual consistency.
  String _hashColor(String name) {
    final hash = name.codeUnits.fold<int>(0, (prev, c) => (prev * 31 + c) & 0x7FFFFFFF);
    final hue = (hash % 360).toDouble();
    // Convert HSL(hue, 65%, 50%) to hex
    final h = hue / 360;
    const s = 0.65;
    const l = 0.50;
    double hueToRgb(double p, double q, double t) {
      var tt = t;
      if (tt < 0) tt += 1;
      if (tt > 1) tt -= 1;
      if (tt < 1 / 6) return p + (q - p) * 6 * tt;
      if (tt < 1 / 2) return q;
      if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
      return p;
    }
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    final r = (hueToRgb(p, q, h + 1 / 3) * 255).round();
    final g = (hueToRgb(p, q, h) * 255).round();
    final b = (hueToRgb(p, q, h - 1 / 3) * 255).round();
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }

  DateTime _adjustDateToPeriodStart(DateTime date, String period) {
    final cleanPeriod = period.toLowerCase().trim();
    if (cleanPeriod == 'week') {
      return date.subtract(Duration(days: date.weekday - 1));
    } else if (cleanPeriod == 'month') {
      return DateTime(date.year, date.month, 1);
    } else if (cleanPeriod == 'year') {
      return DateTime(date.year, 1, 1);
    } else if (cleanPeriod == 'fortnight') {
      final yearStart = DateTime(date.year, 1, 1);
      final dayOfYear = date.difference(yearStart).inDays;
      final fortnightIndex = dayOfYear ~/ 14;
      return yearStart.add(Duration(days: fortnightIndex * 14));
    }
    return date;
  }

  double? _parseDouble(CellValue? val) {
    if (val == null) return null;
    if (val is DoubleCellValue) return val.value;
    if (val is IntCellValue) return val.value.toDouble();
    if (val is TextCellValue) {
      return double.tryParse(val.value.toString());
    }
    return double.tryParse(val.toString());
  }

  int? _parseInt(CellValue? val) {
    if (val == null) return null;
    if (val is IntCellValue) return val.value;
    if (val is DoubleCellValue) return val.value.toInt();
    if (val is TextCellValue) {
      return int.tryParse(val.value.toString());
    }
    return int.tryParse(val.toString());
  }

  String? _parseString(CellValue? val) {
    if (val == null) return null;
    if (val is TextCellValue) return val.value.toString().trim();
    return val.toString().trim();
  }

  DateTime? _parseDate(CellValue? val) {
    if (val == null) return null;
    if (val is DateCellValue) {
      return DateTime(val.year, val.month, val.day);
    }
    if (val is DateTimeCellValue) {
      return DateTime(val.year, val.month, val.day, val.hour, val.minute, val.second.toInt());
    }
    final s = val.toString().trim();
    if (s.isEmpty) return null;
    final parsedIso = DateTime.tryParse(s);
    if (parsedIso != null) return parsedIso;

    final numVal = double.tryParse(s);
    if (numVal != null) {
      final excelEpoch = DateTime(1899, 12, 30);
      final days = numVal.floor();
      final fraction = numVal - days;
      final ms = (fraction * 24 * 60 * 60 * 1000).round();
      return excelEpoch.add(Duration(days: days, milliseconds: ms));
    }
    return null;
  }
}
