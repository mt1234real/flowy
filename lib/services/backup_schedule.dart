import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const cloudBackupTask = 'com.mt1234.flowy.cloudBackup';
const cloudEntryBackupTask = 'com.mt1234.flowy.cloudEntryBackup';

Constraints _constraints(SharedPreferences prefs) => Constraints(
      networkType: (prefs.getBool('pfm_backup_wifi_only') ?? true)
          ? NetworkType.unmetered
          : NetworkType.connected,
      requiresBatteryNotLow: prefs.getBool('pfm_backup_battery_safe') ?? true,
    );

Future<void> configureBackupSchedule(SharedPreferences prefs) async {
  if (!Platform.isAndroid) return;
  final mode = prefs.getInt('pfm_backup_cadence_mode') ?? 1;
  if (mode != 0) await Workmanager().cancelByUniqueName(cloudEntryBackupTask);
  if (mode == 0 || mode == 3) {
    await Workmanager().cancelByUniqueName(cloudBackupTask);
    return;
  }
  await Workmanager().registerPeriodicTask(cloudBackupTask, cloudBackupTask,
      frequency: const Duration(hours: 1),
      constraints: _constraints(prefs),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update);
}

Future<void> scheduleEntryBackup(SharedPreferences prefs) async {
  if (!Platform.isAndroid || prefs.getInt('pfm_backup_cadence_mode') != 0) {
    return;
  }
  await Workmanager().registerOneOffTask(
      cloudEntryBackupTask, cloudEntryBackupTask,
      initialDelay: const Duration(minutes: 3),
      constraints: _constraints(prefs),
      existingWorkPolicy: ExistingWorkPolicy.replace);
}

bool isBackupDue(SharedPreferences prefs, {required bool entryTask}) {
  final mode = prefs.getInt('pfm_backup_cadence_mode') ?? 1;
  if (mode == 3) return false;
  if (entryTask) return mode == 0;
  if (mode == 0) return false;
  final now = DateTime.now();
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
