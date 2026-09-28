import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../../data/database.dart';
import 'notification_preferences.dart';
import 'notification_service.dart';

const notificationRefreshTask = 'com.mt1234.flowy.notificationRefresh';
@pragma('vm:entry-point')
void notificationBackgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!(prefs.getBool('has_completed_onboarding') ?? false)) {
      await NotificationPlatform.instance.initialize();
      if (NotificationPlatform.instance.ready) {
        await NotificationPlatform.instance.plugin.cancelAll();
      }
      return true;
    }
    final db = AppDatabase();
    try {
      final settings = NotificationPreferences(Map<String, dynamic>.from(
          jsonDecode(prefs.getString('notification_preferences_v1') ?? '{}')
              as Map));
      final cycles = Map<String, int>.from(jsonDecode(
          prefs.getString('notification_cycle_snapshot') ??
              '{"default":10}') as Map);
      await NotificationCoordinator(db).refresh(settings, cycles);
      return true;
    } catch (e) {
      debugPrint('Notification background refresh failed: $e');
      return false;
    } finally {
      await db.close();
    }
  });
}

Future<void> startNotificationBackgroundRefresh() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  await Workmanager().initialize(notificationBackgroundDispatcher);
  await Workmanager().registerPeriodicTask(
      notificationRefreshTask, notificationRefreshTask,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep);
}
