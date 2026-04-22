import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/shared_providers.dart';

class CategoryDonutChart extends ConsumerStatefulWidget {
  final Set<String>? excludedCategoryIds;
  
  const CategoryDonutChart({super.key, this.excludedCategoryIds});

  @override
  ConsumerState<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends ConsumerState<CategoryDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    var expenses = ref.watch(expenseListProvider);
    final categories = ref.watch(categoryListProvider).valueOrNull ?? [];
    final theme = Theme.of(context);

    if (widget.excludedCategoryIds != null) {
      expenses = expenses.where((e) => !widget.excludedCategoryIds!.contains(e.categoryId)).toList();
    }

    if (expenses.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('No expenses in this scope.', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    // Group expenses by category
    final categoryTotals = <String, double>{};
    double totalSpent = 0;
    
    for (final exp in expenses) {
      if (exp.categoryId != null) {
        final amt = exp.amountBase.abs(); // Ensure positive for chart rendering
        categoryTotals[exp.categoryId!] = (categoryTotals[exp.categoryId!] ?? 0) + amt;
        totalSpent += amt;
      }
    }

    // Sort to handle colors consistently
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: chartSize * 0.25,
                  sections: sections,
                ),
              ),
              // Total spent in center
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.labelMedium,
                  ),
                  Text(
                    totalSpent.toStringAsFixed(2), // Normally formatted with currency
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }
}
