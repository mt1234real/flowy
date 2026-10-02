import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'backup_state.dart';

const cloudBackupTask = 'com.mt1234.flowy.cloudBackup';
const cloudEntryBackupTask = 'com.mt1234.flowy.cloudEntryBackup';

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
}

class WorkmanagerBackupScheduler implements BackupWorkScheduler {
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
