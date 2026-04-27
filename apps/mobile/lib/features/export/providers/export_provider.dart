import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/database_providers.dart';

final exportProvider = Provider<ExportService>((ref) {
  return ExportService(ref);
});

class ExportService {
  final Ref _ref;

  ExportService(this._ref);

  Future<void> exportToExcel() async {
    final db = _ref.read(databaseProvider);
    
    // Get all transactions
    final transactions = await db.select(db.transactions).get();
    final categories = await db.select(db.categories).get();
    
    final categoryMap = {for (var c in categories) c.id: c.name};

    var excel = Excel.createExcel();
    
    // Raw Data Sheet
    var rawSheet = excel['Raw Data'];
    excel.setDefaultSheet('Raw Data');
    
    rawSheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Category'),
      TextCellValue('Amount (Base)'),
      TextCellValue('Original Amount'),
      TextCellValue('Currency'),
      TextCellValue('Rate'),
      TextCellValue('Note'),
    ]);

    for (final tx in transactions) {
      rawSheet.appendRow([
        TextCellValue(tx.id),
        TextCellValue(tx.transactionDate.toString().split(' ')[0]),
        TextCellValue(tx.transactionType),
        TextCellValue(tx.categoryId != null ? (categoryMap[tx.categoryId] ?? 'Unknown') : 'Uncategorized'),
        DoubleCellValue(tx.amountBase),
        DoubleCellValue(tx.originalAmount),
        TextCellValue(tx.originalCurrency),
        DoubleCellValue(tx.exchangeRate),
        TextCellValue(tx.note ?? ''),
      ]);
    }

    // Save locally to temp folder and share
    final fileBytes = excel.encode();
    if (fileBytes != null) {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/ProjectPET_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
        
      await Share.shareXFiles([XFile(file.path)], text: 'My Expense Export');
    }
  }
}
