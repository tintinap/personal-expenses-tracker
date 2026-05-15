import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:drift/drift.dart' show Value;
import '../../../core/providers/database_providers.dart';
import 'budget_providers.dart';

final flutterLocalNotificationsPluginProvider = Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

/// Initializes local notifications plugin and returns bool indicating success.
/// Call this from main() before runApp().
Future<bool> initializeNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  return await FlutterLocalNotificationsPlugin().initialize(settings: initSettings) ?? false;
}

Future<void> _showBudgetNotification({
  required int id,
  required String title,
  required String body,
}) async {
  const androidDetails = AndroidNotificationDetails(
    'budget_alerts',
    'Budget Alerts',
    channelDescription: 'Notifications for budget thresholds',
    importance: Importance.high,
    priority: Priority.high,
  );
  const iosDetails = DarwinNotificationDetails();
  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  await FlutterLocalNotificationsPlugin().show(
    id: id,
    title: title,
    body: body,
    notificationDetails: details,
  );
}

/// Provider that watches budget progress and fires notifications as side effects.
/// Must be read/watched at app startup to keep it alive.
final budgetNotificationServiceProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<List<BudgetProgress>>>(
    budgetProgressListProvider,
    (previous, next) {
      next.whenData((progressList) => _evaluateAlerts(ref, progressList));
    },
  );
});

Future<void> _evaluateAlerts(Ref ref, List<BudgetProgress> progressList) async {
  final dao = ref.read(budgetDaoProvider);

  for (final progress in progressList) {
    if (progress.isExpired) continue;

    final budget = progress.budget;
    final percentage = progress.percentageUsed;

    bool needsUpdate = false;
    bool n75 = budget.notified75;
    bool n90 = budget.notified90;
    bool n100 = budget.notified100;

    if (percentage >= 1.0 && !budget.notified100) {
      await _showBudgetNotification(
        id: budget.id.hashCode,
        title: 'Budget Exceeded',
        body: 'You have exceeded your ${budget.currency} budget.',
      );
      n75 = true; n90 = true; n100 = true;
      needsUpdate = true;
    } else if (percentage >= 0.90 && percentage < 1.0 && !budget.notified90) {
      await _showBudgetNotification(
        id: budget.id.hashCode,
        title: 'Budget Critical',
        body: 'You have used 90% of your ${budget.currency} budget.',
      );
      n75 = true; n90 = true;
      needsUpdate = true;
    } else if (percentage >= 0.75 && percentage < 0.90 && !budget.notified75) {
      await _showBudgetNotification(
        id: budget.id.hashCode,
        title: 'Budget Warning',
        body: 'You have used 75% of your ${budget.currency} budget.',
      );
      n75 = true;
      needsUpdate = true;
    } else if (percentage < 0.75 && (budget.notified75 || budget.notified90 || budget.notified100)) {
      n75 = false; n90 = false; n100 = false;
      needsUpdate = true;
    }

    if (needsUpdate) {
      await dao.updateBudget(
        budget.toCompanion(true).copyWith(
          notified75: Value(n75),
          notified90: Value(n90),
          notified100: Value(n100),
        ),
      );
    }
  }
}
