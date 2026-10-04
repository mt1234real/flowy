import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'backup_state.dart';
import 'backup_access.dart';
import 'package:uuid/uuid.dart';

const cloudBackupTask = 'com.mt1234.flowy.cloudBackup';
const cloudEntryBackupTask = 'com.mt1234.flowy.cloudEntryBackup';
const cloudManualBackupTask = 'com.mt1234.flowy.cloudManualBackup';
bool isAutomaticBackupTask(String task) =>
    task == cloudBackupTask || task == cloudEntryBackupTask;
bool isManualBackupTask(String task) => task == cloudManualBackupTask;
bool isAnyBackupTask(String task) =>
    isAutomaticBackupTask(task) || isManualBackupTask(task);

Constraints _constraints(SharedPreferences prefs) => Constraints(
      networkType: (prefs.getBool('pfm_backup_wifi_only') ?? true)
          ? NetworkType.unmetered
          : NetworkType.connected,
      requiresBatteryNotLow: prefs.getBool('pfm_backup_battery_safe') ?? true,
    );

abstract class BackupWorkScheduler {
  Future<void> cancel(String name);
  Future<void> entry(Constraints constraints);
  Future<void> periodic(Constraints constraints);
  Future<void> manual(String requestId);
}

/// Optional authoritative inspection; test/non-Android schedulers can retain
/// the conservative KEEP re-registration fallback.
abstract class ManualBackupWorkInspector {
  Future<WorkState?> manualState(String requestId);
}

class WorkmanagerBackupScheduler
    implements BackupWorkScheduler, ManualBackupWorkInspector {
  @override
  Future<WorkState?> manualState(String requestId) async {
    final name = '$cloudManualBackupTask.$requestId';
    // KEEP uses a stable name per logical request. Do not replace active work.
    if (await Workmanager().isScheduledByUniqueName(name)) {
      final info = await Workmanager().getWorkInfo(name);
      return info?.state == WorkState.running
          ? WorkState.running
          : WorkState.scheduled;
    }
    return (await Workmanager().getWorkInfo(name))?.state;
  }

  @override
  Future<void> manual(String requestId) => Workmanager().registerOneOffTask(
      '$cloudManualBackupTask.$requestId', cloudManualBackupTask,
      inputData: {'requestId': requestId},
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep);
  @override
  Future<void> cancel(String name) => Workmanager().cancelByUniqueName(name);
  @override
  Future<void> entry(Constraints constraints) => Workmanager()
      .registerOneOffTask(cloudEntryBackupTask, cloudEntryBackupTask,
          initialDelay: const Duration(minutes: 3),
          constraints: constraints,
          existingWorkPolicy: ExistingWorkPolicy.replace);
  @override
  Future<void> periodic(Constraints constraints) =>
      Workmanager().registerPeriodicTask(cloudBackupTask, cloudBackupTask,
          frequency: const Duration(hours: 1),
          constraints: constraints,
          existingWorkPolicy: ExistingPeriodicWorkPolicy.update);
}

Future<ManualBackupRequest> enqueueManualBackup(SharedPreferences prefs,
    {required String directory, BackupWorkScheduler? scheduler}) async {
  final work = _scheduler(scheduler);
  if (work == null) {
    throw UnsupportedError('Background manual backup requires Android');
  }
  return withBackupAccess(directory, () async {
    final store = BackupStateStore(prefs);
    final previous = await store.readManualRequest();
    final request = previous?.pending == true
        ? previous!
        : ManualBackupRequest(
            id: const Uuid().v4(),
            phase: ManualBackupPhase.queued,
            queuedAt: DateTime.now());
    if (request != previous) await store.writeManualRequest(request);
    try {
      await work.manual(request.id);
    } catch (_) {
      await store.transitionManualRequest(request.id, ManualBackupPhase.failure,
          message: 'Chưa đưa được yêu cầu sao lưu vào hàng đợi. Hãy thử lại.');
      rethrow;
    }
    return request;
  }, name: 'manual_backup_request.lock');
}

Future<void> recoverManualBackup(SharedPreferences prefs,
    {required String directory, BackupWorkScheduler? scheduler}) async {
  final work = _scheduler(scheduler);
  if (work == null) return;
  await withBackupAccess(directory, () async {
    // Do not turn a just-completed request into a new user intent at startup.
    final store = BackupStateStore(prefs);
    final request = await store.readManualRequest();
    if (request?.pending == true) {
      try {
        WorkState? state;
        if (work is ManualBackupWorkInspector) {
          try {
            state = await (work as ManualBackupWorkInspector)
                .manualState(request!.id);
          } catch (_) {
            // Failed inspection is not evidence that a live worker has died.
            // A later lifecycle reconciliation can query it again.
            return;
          }
          if (state == WorkState.running) return;
          if (state == WorkState.scheduled) {
            if (request.phase == ManualBackupPhase.running) {
              await store.transitionManualRequest(
                  request.id, ManualBackupPhase.queued);
            }
            return;
          }
          if (state != null) {
            // A scheduler terminal result alone is never an upload receipt.
            await store.transitionManualRequest(
                request.id, ManualBackupPhase.failure,
                message: 'Sao lưu theo yêu cầu đã dừng. Hãy thử lại.');
            return;
          }
        }
        // No scheduler record: recover the SAME intent with KEEP, not a new
        // request or a replacement that could interrupt an active pipeline.
        if (request!.phase == ManualBackupPhase.running) {
          await store.transitionManualRequest(
              request.id, ManualBackupPhase.queued);
        }
        await work.manual(request.id);
      } catch (_) {
        await store.transitionManualRequest(
            request!.id, ManualBackupPhase.failure,
            message:
                'Chưa khôi phục được lịch sao lưu theo yêu cầu. Hãy thử lại.');
        rethrow;
      }
    }
  }, name: 'manual_backup_request.lock');
}

BackupWorkScheduler? _scheduler(BackupWorkScheduler? override) =>
    override ?? (Platform.isAndroid ? WorkmanagerBackupScheduler() : null);

Future<void> configureBackupSchedule(SharedPreferences prefs,
    {BackupWorkScheduler? scheduler}) async {
  final work = _scheduler(scheduler);
  if (work == null) return;
  await prefs.reload();
  final mode = prefs.getInt('pfm_backup_cadence_mode') ?? 1;
  if (mode != 0) await work.cancel(cloudEntryBackupTask);
  if (mode == 0 || mode == 3) {
    await work.cancel(cloudBackupTask);
    if (mode == 0 && (await BackupStateStore(prefs).read()).dirty) {
      await scheduleEntryBackup(prefs, scheduler: work);
    } else {
      await work.cancel(cloudEntryBackupTask);
    }
    return;
  }
  await work.periodic(_constraints(prefs));
}

Future<void> scheduleEntryBackup(SharedPreferences prefs,
    {BackupWorkScheduler? scheduler}) async {
  final work = _scheduler(scheduler);
  await prefs.reload();
  if (work == null ||
      prefs.getInt('pfm_backup_cadence_mode') != 0 ||
      !(await BackupStateStore(prefs).read()).dirty) {
    return;
  }
  await work.entry(_constraints(prefs));
}

Future<void> markBackupDirty(SharedPreferences prefs,
    {BackupWorkScheduler? scheduler}) async {
  await BackupStateStore(prefs).markDirty();
  try {
    await scheduleEntryBackup(prefs, scheduler: scheduler);
  } catch (_) {
    await BackupStateStore(prefs).failure(
        'Chưa đặt được lịch sao lưu. Các thay đổi vẫn đang chờ sao lưu.');
  }
}

Future<void> recoverPendingBackup(SharedPreferences prefs,
    {BackupWorkScheduler? scheduler}) async {
  try {
    await configureBackupSchedule(prefs, scheduler: scheduler);
  } catch (_) {
    await BackupStateStore(prefs).failure(
        'Chưa đặt được lịch sao lưu. Các thay đổi vẫn đang chờ sao lưu.');
  }
}

bool isBackupDue(SharedPreferences prefs,
    {required bool entryTask, DateTime? at}) {
  final revision = prefs.getString(backupDirtyRevisionKey);
  if (revision == null ||
      revision == prefs.getString(backupUploadedRevisionKey)) {
    return false;
  }
  final mode = prefs.getInt('pfm_backup_cadence_mode') ?? 1;
  if (mode == 3) return false;
  if (entryTask) return mode == 0;
  if (mode == 0) return false;
  final now = at ?? DateTime.now();
  final last = DateTime.tryParse(prefs.getString('flowy_last_backup_at') ?? '');
  if (mode == 1) {
    var cutoff = DateTime(now.year, now.month, now.day, 2);
    if (cutoff.isAfter(now)) cutoff = cutoff.subtract(const Duration(days: 1));
    return last == null || last.isBefore(cutoff);
  }
  if (mode == 2) {
    var cutoff = DateTime(now.year, now.month, now.day, 23)
        .subtract(Duration(days: now.weekday % 7));
    if (cutoff.isAfter(now)) cutoff = cutoff.subtract(const Duration(days: 7));
    return last == null || last.isBefore(cutoff);
  }
  final value = (prefs.getInt('pfm_backup_custom_value') ?? 6).clamp(1, 168);
  final unit = prefs.getString('pfm_backup_custom_unit');
  final hours = unit == 'weeks'
      ? value * 168
      : unit == 'days'
          ? value * 24
          : value.clamp(4, 24);
  return last == null || now.difference(last) >= Duration(hours: hours);
}
