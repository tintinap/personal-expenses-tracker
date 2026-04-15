import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/expense.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  String get _baseUrl {
    final url = dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
    return '$url/expenses';
  }

  Future<void> init() async {
    // No direct DB init needed — the backend handles table creation
  }

  Future<void> insertExpense(Expense expense) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(_expenseToJson(expense)),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create expense: ${response.body}');
    }
  }

  Future<void> updateExpense(Expense expense) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/${expense.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(_expenseToJson(expense)),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update expense: ${response.body}');
    }
  }

  Future<void> deleteExpense(String id) async {
    final response = await http.delete(Uri.parse('$_baseUrl/$id'));
    if (response.statusCode != 204) {
      throw Exception('Failed to delete expense: ${response.body}');
    }
  }

  Future<List<Expense>> getAllExpenses() async {
    final response = await http.get(Uri.parse(_baseUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch expenses: ${response.body}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((row) {
      return Expense(
        id: row['id'] as String,
        amount: (row['amount'] as num).toDouble(),
        date: DateTime.parse(row['date'] as String).toLocal(),
        categoryIndex: row['categoryIndex'] as int,
        note: row['note'] as String?,
        isIncome: row['isIncome'] as bool,
        currencyCode: row['currencyCode'] as String,
      );
    }).toList();
  }

  Future<void> clearAll() async {
    final response = await http.delete(Uri.parse(_baseUrl));
    if (response.statusCode != 204) {
      throw Exception('Failed to clear expenses: ${response.body}');
    }
  }

  Map<String, dynamic> _expenseToJson(Expense expense) {
    return {
      'id': expense.id,
      'amount': expense.amount,
      'date': expense.date.toUtc().toIso8601String(),
      'categoryIndex': expense.categoryIndex,
      'note': expense.note,
      'isIncome': expense.isIncome,
      'currencyCode': expense.currencyCode,
    };
  }
}
