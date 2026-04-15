import 'category.dart';

class Expense {
  final String id;
  final double amount;
  final DateTime date;
  final int categoryIndex;
  final String? note;
  final bool isIncome;
  final String currencyCode;

  Expense({
    required this.id,
    required this.amount,
    required this.date,
    required this.categoryIndex,
    this.note,
    this.isIncome = false,
    this.currencyCode = 'AUD',
  });

  Category get category => CategoryExtension.fromIndex(categoryIndex);

  Expense copyWith({
    String? id,
    double? amount,
    DateTime? date,
    int? categoryIndex,
    String? note,
    bool? isIncome,
    String? currencyCode,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryIndex: categoryIndex ?? this.categoryIndex,
      note: note ?? this.note,
      isIncome: isIncome ?? this.isIncome,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}
