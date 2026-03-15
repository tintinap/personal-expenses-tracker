import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/currency_helper.dart';
import '../providers/settings_provider.dart';
import '../data/models/category.dart';
import '../data/models/expense.dart';
import '../providers/expense_provider.dart';

class CategoryPieChart extends StatefulWidget {
  final List<Expense> expenses;
  final FilterType filter;

  const CategoryPieChart({
    super.key,
    required this.expenses,
    required this.filter,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  Future<Map<Category, double>>? _totalsFuture;
  String? _lastCurrency;
  int? _lastExpenseHash;

  void _refreshFuture() {
    final displayCurrency = context.read<SettingsProvider>().currency.code;
    final expenseHash = Object.hashAll(widget.expenses.map((e) => e.id));

    // Only recreate the future if inputs actually changed.
    if (_totalsFuture != null &&
        _lastCurrency == displayCurrency &&
        _lastExpenseHash == expenseHash) {
      return;
    }

    _lastCurrency = displayCurrency;
    _lastExpenseHash = expenseHash;
    _totalsFuture =
        context.read<ExpenseProvider>().getConvertedTotalsByCategory(
              widget.filter,
              displayCurrency,
            );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshFuture();
  }

  @override
  void didUpdateWidget(covariant CategoryPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter ||
        oldWidget.expenses.length != widget.expenses.length) {
      _totalsFuture = null; // force refresh
      _refreshFuture();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings so we rebuild if currency changes.
    final displayCurrency = context.watch<SettingsProvider>().currency;
    if (_lastCurrency != displayCurrency.code) {
      _totalsFuture = null;
      _refreshFuture();
    }

    return FutureBuilder<Map<Category, double>>(
      future: _totalsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            height: 200,
            child: Center(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const CircularProgressIndicator()
                  : Text(
                      'No data for the selected period',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
            ),
          );
        }
        final data = snapshot.data!;
        if (data.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'No data for the selected period',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }

        final total = data.values.fold<double>(0, (a, b) => a + b.abs());
        if (total == 0) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'No expenses in this period',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }

        final sections = data.entries
            .where((e) => e.value.abs() > 0)
            .map((e) => PieChartSectionData(
                  value: e.value.abs(),
                  title: '',
                  color: e.key.color,
                  radius: 80,
                ))
            .toList();

        return Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: data.entries
                  .where((e) => e.value.abs() > 0)
                  .map((e) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: e.key.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${e.key.label}: ${displayCurrency.format(e.value.abs())}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ))
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}
