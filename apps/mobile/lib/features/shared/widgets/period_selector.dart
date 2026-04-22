import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/shared_providers.dart';

/// PRD §12 — Segmented control + left/right nav + date picker for period selection
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  String _formatPeriod(PeriodState state) {
    if (state.type == PeriodType.daily) {
      if (state.from.year == DateTime.now().year &&
          state.from.month == DateTime.now().month &&
          state.from.day == DateTime.now().day) {
        return 'Today';
      }
      return DateFormat.yMMMd().format(state.from);
    }

    if (state.type == PeriodType.monthly) {
      return DateFormat.yMMMM().format(state.from);
    }

    if (state.type == PeriodType.yearly) {
      return DateFormat.y().format(state.from);
    }

    // Weekly, Fortnightly, Custom ranges
    return '${DateFormat.MMMd().format(state.from)} - ${DateFormat.yMMMd().format(state.to)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodState = ref.watch(selectedPeriodProvider);
    final notifier = ref.read(selectedPeriodProvider.notifier);
    final theme = Theme.of(context);

    // Disable next button if 'to' date is today or in the future
    final isNextDisabled = periodState.to.isAfter(DateTime.now()) ||
        periodState.to.day == DateTime.now().day &&
            periodState.to.month == DateTime.now().month &&
            periodState.to.year == DateTime.now().year;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Type Selector (Segmented Button)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<PeriodType>(
            segments: const [
              ButtonSegment(value: PeriodType.daily, label: Text('Daily')),
              ButtonSegment(value: PeriodType.weekly, label: Text('Weekly')),
              ButtonSegment(value: PeriodType.fortnightly, label: Text('Fortnightly')),
              ButtonSegment(value: PeriodType.monthly, label: Text('Monthly')),
              ButtonSegment(value: PeriodType.yearly, label: Text('Yearly')),
            ],
            selected: {periodState.type == PeriodType.custom ? PeriodType.monthly : periodState.type},
            onSelectionChanged: (Set<PeriodType> newSelection) {
              notifier.setType(newSelection.first);
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),

        // Navigation Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => notifier.previous(),
                tooltip: 'Previous period',
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    if (periodState.type == PeriodType.custom) return;

                    final initial = periodState.from.isAfter(DateTime.now()) 
                        ? DateTime.now() 
                        : periodState.from;

                    final pickedDate = await showDialog<DateTime>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          contentPadding: const EdgeInsets.only(top: 16),
                          content: SizedBox(
                            width: 320,
                            height: 400,
                            child: Column(
                              children: [
                                Expanded(
                                  child: CalendarDatePicker(
                                    initialDate: initial,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now(),
                                    onDateChanged: (date) {
                                      Navigator.pop(context, date);
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, DateTime.now()),
                                        child: const Text('Today'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                    
                    if (pickedDate != null) {
                      notifier.setDate(pickedDate);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _formatPeriod(periodState),
                          style: theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        if (periodState.type != PeriodType.daily &&
                            periodState.type != PeriodType.monthly &&
                            periodState.type != PeriodType.yearly)
                          Text(
                            '${periodState.to.difference(periodState.from).inDays + 1} days',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: isNextDisabled ? null : () => notifier.next(),
                tooltip: 'Next period',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
