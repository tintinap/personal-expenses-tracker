enum ImportRowStatus {
  ready,
  duplicate,
  update,
  error,
}

enum ImportRowType {
  transaction,
  income,
  exchange,
}

class ImportRow {
  final int rowIndex; // 1-indexed Excel row number
  final ImportRowType rowType;
  
  // Parsed and validated fields
  final DateTime date;
  final String transactionType; // expense | currency_income | currency_exchange_out | currency_exchange_in
  final String? note;
  final String? categoryName; // Category name in Excel
  final String? categoryId; // Resolved local DB ID
  final double originalAmount;
  final String originalCurrency;
  final double amountBase;
  final double exchangeRate;
  final String rateSource;
  final String? id; // UUID
  final String? exchangeEventId; // For exchange pairs
  final String? sourceLabel; // For income rows
  final bool isAggregate;

  // UI / Import State
  final ImportRowStatus status;
  final String? errorMessage;
  final bool checked;

  ImportRow({
    required this.rowIndex,
    required this.rowType,
    required this.date,
    required this.transactionType,
    this.note,
    this.categoryName,
    this.categoryId,
    required this.originalAmount,
    required this.originalCurrency,
    required this.amountBase,
    required this.exchangeRate,
    required this.rateSource,
    this.id,
    this.exchangeEventId,
    this.sourceLabel,
    required this.isAggregate,
    required this.status,
    this.errorMessage,
    required this.checked,
  });

  ImportRow copyWith({
    int? rowIndex,
    ImportRowType? rowType,
    DateTime? date,
    String? transactionType,
    String? note,
    String? categoryName,
    String? categoryId,
    double? originalAmount,
    String? originalCurrency,
    double? amountBase,
    double? exchangeRate,
    String? rateSource,
    String? id,
    String? exchangeEventId,
    String? sourceLabel,
    bool? isAggregate,
    ImportRowStatus? status,
    String? errorMessage,
    bool? checked,
  }) {
    return ImportRow(
      rowIndex: rowIndex ?? this.rowIndex,
      rowType: rowType ?? this.rowType,
      date: date ?? this.date,
      transactionType: transactionType ?? this.transactionType,
      note: note ?? this.note,
      categoryName: categoryName ?? this.categoryName,
      categoryId: categoryId ?? this.categoryId,
      originalAmount: originalAmount ?? this.originalAmount,
      originalCurrency: originalCurrency ?? this.originalCurrency,
      amountBase: amountBase ?? this.amountBase,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      rateSource: rateSource ?? this.rateSource,
      id: id ?? this.id,
      exchangeEventId: exchangeEventId ?? this.exchangeEventId,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      isAggregate: isAggregate ?? this.isAggregate,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      checked: checked ?? this.checked,
    );
  }
}
