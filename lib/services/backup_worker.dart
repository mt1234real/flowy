import 'package:shared_preferences/shared_preferences.dart';

import 'backup_schedule.dart';
import 'backup_state.dart';

/// Task policy around the existing upload pipeline. Access guards are supplied
/// by the dispatcher so production and tests use the same post-lock decisions.
Future<bool> runCloudBackupTask({
  required String task,
  String? requestId,
  required SharedPreferences prefs,
  required Future<bool> Function(Future<bool> Function()) withAccess,
  required Future<void> Function(Future<void> Function()) withRequestAccess,
  required Future<bool> Function() restorePending,
  required Future<void> Function({required bool silent}) performBackup,
}) async {
  final automatic = isAutomaticBackupTask(task);
  final manual = isManualBackupTask(task);
  if (!automatic && !manual) throw ArgumentError.value(task);
  bool due() => isBackupDue(prefs, entryTask: task == cloudEntryBackupTask);
  await prefs.reload();
  if (automatic && !due()) return true;
  final store = BackupStateStore(prefs);
  Future<void> transition(ManualBackupPhase phase, {String? message}) =>
      withRequestAccess(() async {
        if (requestId != null) {
          await store.transitionManualRequest(requestId, phase,
              message: message);
        }
      });
  try {
    return await withAccess(() async {
      await prefs.reload();
      // An upload/restore can finish while this task waits for exclusive access.
      if (automatic && !due()) return true;
      if (manual) {
        var claimed = false;
        await withRequestAccess(() async {
          if (requestId != null) {
            claimed = await store.transitionManualRequest(
                requestId, ManualBackupPhase.running);
          }
        });
        if (!claimed) return true; // Superseded or already completed request.
      }
      if (await restorePending()) {
        await store.beginAttempt();
        throw const _BackupDeferred(
            'Đang khôi phục dữ liệu. Sao lưu sẽ thử lại sau.');
      }
      if (!(prefs.getBool('has_completed_onboarding') ?? false)) {
        await store.beginAttempt();
        throw const _BackupDeferred(
            'Cần hoàn tất thiết lập trước khi sao lưu.');
      }
      // This pipeline owns the upload-only revision acknowledgement.
      await performBackup(silent: true);
      if (manual) await transition(ManualBackupPhase.success);
      return true;
    });
  } catch (error) {
    final message =
        error is _BackupDeferred ? error.message : backupFailureMessage(error);
    await store.failure(message);
    if (manual) await transition(ManualBackupPhase.failure, message: message);
    return false;
  }
}

class _BackupDeferred implements Exception {
  final String message;
  const _BackupDeferred(this.message);
}
