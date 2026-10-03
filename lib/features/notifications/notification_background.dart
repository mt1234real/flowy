import 'dart:convert';
import '../../services/fiscal_day.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/backup_schedule.dart';
import '../../services/backup_state.dart';
import '../../services/backup_access.dart';
import '../../services/backup_worker.dart';
import '../../services/cloud_backup_service.dart';
import '../../theme/app_theme.dart';
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
    final documents = await getApplicationDocumentsDirectory();
    Future<bool> restorePending() =>
        File(p.join(documents.path, 'restore_recovery', 'pending')).exists();
    if (isAnyBackupTask(task)) {
      return runCloudBackupTask(
        task: task,
        requestId: input?['requestId'] as String?,
        prefs: prefs,
        withAccess: (action) => withBackupAccess(documents.path, action),
        withRequestAccess: (action) => withBackupAccess(documents.path, action,
            name: 'manual_backup_request.lock'),
        restorePending: restorePending,
        performBackup: ({required bool silent}) async {
          final db = AppDatabase();
          final container = ProviderContainer(overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
          ]);
          try {
            await container
                .read(cloudBackupServiceProvider)
                .performBackup(silent: silent);
          } finally {
            container.dispose();
            await db.close();
          }
        },
      );
    }
    if (!(prefs.getBool('has_completed_onboarding') ?? false)) {
      await NotificationPlatform.instance.initialize();
      if (NotificationPlatform.instance.ready) {
        await NotificationPlatform.instance.plugin.cancelAll();
      }
      return true;
    }
    return withBackupAccess(documents.path, () async {
      if (await restorePending()) return false;
      final db = AppDatabase();
      try {
        final settings = NotificationPreferences(Map<String, dynamic>.from(
            jsonDecode(prefs.getString('notification_preferences_v1') ?? '{}')
                as Map));
        final cycles = Map<String, int>.from(jsonDecode(
            prefs.getString('notification_cycle_snapshot') ??
                '{"default":10}') as Map);
        await NotificationCoordinator(db).refresh(settings, cycles,
            boundary: FiscalDayBoundary.fromPreferences(prefs));
        return true;
      } catch (_) {
        debugPrint('Notification background refresh failed');
        return false;
      } finally {
        await db.close();
      }
    });
  });
}

Future<void> startNotificationBackgroundRefresh() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  final prefs = await SharedPreferences.getInstance();
  try {
    await Workmanager().initialize(notificationBackgroundDispatcher);
  } catch (_) {
    if ((await BackupStateStore(prefs).read()).dirty &&
        prefs.getInt('pfm_backup_cadence_mode') != 3) {
      await BackupStateStore(prefs).failure(
          'Chưa đặt được lịch sao lưu. Các thay đổi vẫn đang chờ sao lưu.');
    }
    rethrow;
  }
  await recoverPendingBackup(prefs);
  if (Platform.isAndroid) {
    final documents = await getApplicationDocumentsDirectory();
    try {
      await recoverManualBackup(prefs, directory: documents.path);
    } catch (_) {
      await BackupStateStore(prefs).failure(
          'Chưa khôi phục được lịch sao lưu theo yêu cầu. Hãy thử lại.');
    }
  }
  await Workmanager().registerPeriodicTask(
      notificationRefreshTask, notificationRefreshTask,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep);
}
