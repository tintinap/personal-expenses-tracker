import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/shared/providers/shared_providers.dart';
import 'features/budgets/providers/budget_notification_service.dart';
import 'features/sync/providers/sync_provider.dart';

/// PRD §5 — Root MaterialApp using go_router
class DailySpendApp extends ConsumerWidget {
  const DailySpendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Activate budget notification listener (ref.listen inside this provider fires on changes)
    ref.watch(budgetNotificationServiceProvider);
    // Mount sync provider to start background worker
    ref.watch(syncProvider);

    return MaterialApp.router(
      title: 'DailySpend',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
