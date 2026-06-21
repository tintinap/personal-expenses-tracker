import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/shared_providers.dart';

class CategoryDonutChart extends ConsumerStatefulWidget {
  final Set<String>? excludedCategoryIds;
  final Set<String>? filterCurrencies;

  /// Fired when the user taps a pie slice. Receives the **parent** category id
  /// that the slice represents.
  final void Function(String parentCategoryId)? onSliceTap;

  final bool showViewCurrency;

  const CategoryDonutChart({
    super.key,
    this.excludedCategoryIds,
    this.filterCurrencies,
    this.onSliceTap,
    this.showViewCurrency = true,
  });

  @override
  ConsumerState<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends ConsumerState<CategoryDonutChart> {
  int _touchedIndex = -1;
  // Most recent sorted slice → categoryId mapping, kept in sync with [build]
  // so the touch callback can resolve the index back to a category id.
  List<String> _sortedKeys = const [];

  @override
  Widget build(BuildContext context) {
    var expenses = ref.watch(expenseListProvider);
    final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final viewCurrency = ref.watch(viewCurrencyProvider);
    final viewRate = ref.watch(viewCurrencyRateProvider).valueOrNull ?? 1.0;
    final theme = Theme.of(context);

    if (widget.excludedCategoryIds != null) {
      expenses = expenses.where((e) => !widget.excludedCategoryIds!.contains(e.categoryId)).toList();
    }

    if (widget.filterCurrencies != null && widget.filterCurrencies!.isNotEmpty) {
      expenses = expenses.where((e) => widget.filterCurrencies!.contains(e.originalCurrency)).toList();
    }

    if (expenses.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('No expenses in this scope.', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    // Group expenses by category — resolve sub-categories to their parent
    final categoryTotals = <String, double>{};
    double totalSpent = 0;
    
    for (final exp in expenses) {
      if (exp.categoryId != null) {
        // Find the category and resolve to parent if it's a sub-category
        final cat = categories.where((c) => c.id == exp.categoryId).firstOrNull;
        final displayId = (cat != null && cat.parentId != null) ? cat.parentId! : exp.categoryId!;
        final amt = exp.amountBase.abs(); // Ensure positive for chart rendering
        categoryTotals[displayId] = (categoryTotals[displayId] ?? 0) + amt;
        totalSpent += amt;
      }
    }

    // Sort to handle colors consistently
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _sortedKeys = sortedEntries.map((e) => e.key).toList(growable: false);

    // Largest Remainder Method to ensure rounded percentages sum exactly to 100%
    final exactPercentages = sortedEntries.map((e) => totalSpent > 0 ? (e.value / totalSpent * 100) : 0.0).toList();
    final intPercentages = exactPercentages.map((e) => e.floor()).toList();
    
    if (totalSpent > 0 && sortedEntries.isNotEmpty) {
      int remainder = 100 - intPercentages.fold(0, (sum, val) => sum + val);
      final indices = List.generate(exactPercentages.length, (i) => i);
      indices.sort((a, b) => (exactPercentages[b] - intPercentages[b]).compareTo(exactPercentages[a] - intPercentages[a]));
      
      for (int i = 0; i < remainder && i < indices.length; i++) {
        intPercentages[indices[i]]++;
      }
    }

    // Fallback colors if category doesn't have one
    final fallbackColors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, 
      Colors.purple, Colors.teal, Colors.amber, Colors.pink
    ];

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 60.0 : 50.0;
      final fontSize = isTouched ? 16.0 : 12.0;
      final displayPercent = intPercentages[i];

      final category = categories.where((c) => c.id == entry.key).firstOrNull;
      
      Color catColor = fallbackColors[colorIndex % fallbackColors.length];
      if (category != null && category.colourHex.startsWith('#')) {
        try {
          catColor = Color(int.parse(category.colourHex.substring(1, 7), radix: 16) + 0xFF000000);
        } catch (_) {}
      }

      sections.add(
        PieChartSectionData(
          color: catColor,
          value: entry.value,
          title: displayPercent > 0 ? '$displayPercent%' : '', // Hide 0% labels
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        )
      );
      colorIndex++;
    }

    String centerLabel = 'Total';
    double centerAmount = totalSpent;

    if (_touchedIndex >= 0 && _touchedIndex < sortedEntries.length) {
      final touchedEntry = sortedEntries[_touchedIndex];
      final touchedCategory = categories.where((c) => c.id == touchedEntry.key).firstOrNull;
      centerLabel = touchedCategory?.name ?? 'Unknown';
      centerAmount = touchedEntry.value;
    }

    String centerValue = '$baseCurrency ${centerAmount.toStringAsFixed(2)}';
    String? centerSecondaryValue = widget.showViewCurrency && baseCurrency != viewCurrency 
        ? '≈ $viewCurrency ${(centerAmount * viewRate).toStringAsFixed(2)}'
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = constraints.maxHeight != double.infinity 
            ? constraints.maxHeight 
            : 250.0;
        
        return SizedBox(
          height: chartSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      final touched = pieTouchResponse?.touchedSection;
                      // Always update the highlight ring while the finger is
                      // interacting with the chart.
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            touched == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = touched.touchedSectionIndex;
                      });

                      // Drill into transactions only on tap-up over a slice.
                      if (event is FlTapUpEvent &&
                          touched != null &&
                          widget.onSliceTap != null) {
                        final idx = touched.touchedSectionIndex;
                        if (idx >= 0 && idx < _sortedKeys.length) {
                          widget.onSliceTap!(_sortedKeys[idx]);
                        }
                      }
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: chartSize * 0.25,
                  sections: sections,
                ),
              ),
              // Dynamic center text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerLabel,
                    style: theme.textTheme.labelMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                    width: chartSize * 0.45,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        centerValue,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24, // bigger font that will scale down if too wide
                        ),
                      ),
                    ),
                  ),
                  if (centerSecondaryValue != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      centerSecondaryValue,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      }
    );
  }
}
