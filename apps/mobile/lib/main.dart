import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'features/budgets/providers/budget_notification_service.dart';
import 'features/transactions/providers/recurring_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } on Exception {
    debugPrint('No .env file found — using default configuration');
  }

  await initializeNotifications();

  final container = ProviderContainer();
  
  // Trigger recurring evaluation in background
  container.read(recurringEvaluationProvider.future).catchError((e) {
    debugPrint('Failed to evaluate recurring expenses: $e');
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const DailySpendApp(),
    ),
  );
}
