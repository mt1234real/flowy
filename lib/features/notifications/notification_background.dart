import 'dart:convert';
import '../../services/fiscal_day.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/backup_schedule.dart';
import '../../services/backup_state.dart';
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
    final backupTask = task == cloudBackupTask || task == cloudEntryBackupTask;
    if (backupTask &&
        !isBackupDue(prefs, entryTask: task == cloudEntryBackupTask)) {
      return true;
    }
    try {
      if (backupTask) await BackupStateStore(prefs).beginAttempt();
      if (!(prefs.getBool('has_completed_onboarding') ?? false)) {
        await NotificationPlatform.instance.initialize();
        if (NotificationPlatform.instance.ready) {
          await NotificationPlatform.instance.plugin.cancelAll();
        }
        return true;
      }
      final documents = await getApplicationDocumentsDirectory();
      final guard = await File(p.join(documents.path, 'restore_access.lock'))
          .open(mode: FileMode.append);
      await guard.lock(FileLock.blockingExclusive);
      if (await File(p.join(documents.path, 'restore_recovery', 'pending'))
          .exists()) {
        await guard.unlock();
        await guard.close();
        if (backupTask) {
          final store = BackupStateStore(prefs);
          await store.beginAttempt();
          await store
              .failure('Đang khôi phục dữ liệu. Sao lưu sẽ thử lại sau.');
        }
        return false;
      }
      final db = AppDatabase();
      try {
        if (backupTask) {
          final container = ProviderContainer(overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db)
          ]);
          try {
            await container
                .read(cloudBackupServiceProvider)
                .performBackup(silent: true);
            return true;
          } finally {
            container.dispose();
          }
        }
        final settings = NotificationPreferences(Map<String, dynamic>.from(
            jsonDecode(prefs.getString('notification_preferences_v1') ?? '{}')
                as Map));
        final cycles = Map<String, int>.from(jsonDecode(
            prefs.getString('notification_cycle_snapshot') ??
                '{"default":10}') as Map);
        await NotificationCoordinator(db).refresh(settings, cycles,
            boundary: FiscalDayBoundary.fromPreferences(prefs));
        return true;
      } catch (e) {
        if (backupTask) {
          await BackupStateStore(prefs).failure(backupFailureMessage(e));
        }
        debugPrint('Notification background refresh failed: $e');
        return false;
      } finally {
        await db.close();
        await guard.unlock();
        await guard.close();
      }
    } catch (error) {
      if (backupTask) {
        await BackupStateStore(prefs).failure(backupFailureMessage(error));
        return false;
      }
      rethrow;
    }
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
  await Workmanager().registerPeriodicTask(
      notificationRefreshTask, notificationRefreshTask,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep);
}
