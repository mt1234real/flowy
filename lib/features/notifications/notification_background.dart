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
import '../../services/backup_dispatcher.dart';
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
  registerBackupBackgroundHandler(dispatchNotificationBackgroundTask);
}

bool isRecognizedBackgroundTask(String task) =>
    isAnyBackupTask(task) ||
    task == notificationRefreshTask ||
    task == Workmanager.iOSBackgroundTask;

Future<bool> dispatchNotificationBackgroundTask(
    String task, Map<String, dynamic>? input) async {
  if (!isRecognizedBackgroundTask(task)) {
    debugPrint('Unknown background task: $task');
    return false;
  }
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final documents = await getApplicationDocumentsDirectory();
  Future<bool> restorePending() =>
      File(p.join(documents.path, 'restore_recovery', 'pending')).exists();
  if (isAnyBackupTask(task)) {
    return runCloudBackupTask(
      task: task,
      requestId:
          input?['requestId'] is String ? input!['requestId'] as String : null,
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
}

Future<void>? _workerInitialization;
Future<void> ensureBackupWorkerInitialized() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  try {
    await (_workerInitialization ??=
        Workmanager().initialize(notificationBackgroundDispatcher));
  } catch (_) {
    _workerInitialization = null;
    rethrow;
  }
}

Future<void> reconcileManualBackgroundBackup() async {
  if (!Platform.isAndroid) return;
  final prefs = await SharedPreferences.getInstance();
  if ((await BackupStateStore(prefs).readManualRequest())?.pending != true) {
    return;
  }
  try {
    await ensureBackupWorkerInitialized();
    final documents = await getApplicationDocumentsDirectory();
    await recoverManualBackup(prefs, directory: documents.path);
  } catch (_) {
    debugPrint('Manual backup recovery unavailable');
  }
}

Future<void> startNotificationBackgroundRefresh() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  final prefs = await SharedPreferences.getInstance();
  try {
    await ensureBackupWorkerInitialized();
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
