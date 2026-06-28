import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_providers.dart';
import '../services/recurring_service.dart';

final recurringServiceProvider = Provider<RecurringService>((ref) {
  final dao = ref.watch(transactionDaoProvider);
  return RecurringService(dao);
});

final recurringEvaluationProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(recurringServiceProvider);
  await service.evaluateRecurringExpenses();
});
