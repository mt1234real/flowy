import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'backup_crypto.dart';

const backupDirtyRevisionKey = 'pfm_backup_dirty_revision';
const backupUploadedRevisionKey = 'pfm_backup_uploaded_revision';
const backupDirtySinceKey = 'pfm_backup_dirty_since';
const backupLastAttemptKey = 'pfm_backup_last_attempt_at';
const backupLastFailureKey = 'pfm_backup_last_failure_at';
const backupLastFailureMessageKey = 'pfm_backup_last_failure_message';
const backupLastSuccessKey = 'flowy_last_backup_at';

class BackupAuthenticationFailure implements Exception {
  const BackupAuthenticationFailure();
  @override
  String toString() => 'Chưa đăng nhập Google hoặc người dùng hủy xác thực.';
}

class BackupStatus {
  final String? revision, uploadedRevision, failureMessage;
  final DateTime? dirtySince, lastAttempt, lastFailure, lastSuccess;
  const BackupStatus(
      {this.revision,
      this.uploadedRevision,
      this.dirtySince,
      this.lastAttempt,
      this.lastFailure,
      this.lastSuccess,
      this.failureMessage});
  bool get dirty => revision != null && revision != uploadedRevision;
}

/// Revision/receipt keys are separate so an upload never clears a newer write,
/// including writes made in another isolate while the upload is in progress.
class BackupStateStore {
  final SharedPreferences prefs;
  BackupStateStore(this.prefs);
  static final _changes = StreamController<void>.broadcast();
  static Stream<void> get changes => _changes.stream;

  Future<BackupStatus> read() async {
    await prefs.reload();
    DateTime? date(String key) => DateTime.tryParse(prefs.getString(key) ?? '');
    return BackupStatus(
      revision: prefs.getString(backupDirtyRevisionKey),
      uploadedRevision: prefs.getString(backupUploadedRevisionKey),
      dirtySince: date(backupDirtySinceKey),
      lastAttempt: date(backupLastAttemptKey),
      lastFailure: date(backupLastFailureKey),
      lastSuccess: date(backupLastSuccessKey),
      failureMessage: prefs.getString(backupLastFailureMessageKey),
    );
  }

  Future<void> _write(String key, String value) async {
    if (!await prefs.setString(key, value)) {
      throw StateError('Không lưu được trạng thái sao lưu');
    }
  }

  Future<void> markDirty() async {
    final before = await read();
    await _write(backupDirtyRevisionKey, const Uuid().v4());
    if (!before.dirty) {
      await _write(backupDirtySinceKey, DateTime.now().toIso8601String());
    }
    _changes.add(null);
  }

  Future<String?> beginAttempt() async {
    final status = await read();
    await _write(backupLastAttemptKey, DateTime.now().toIso8601String());
    _changes.add(null);
    return status.revision;
  }

  Future<void> success(String? revision, DateTime uploadedAt) async {
    // This is called only after the upload future has completed successfully.
    await _write(backupLastSuccessKey, uploadedAt.toIso8601String());
    if (revision != null) await _write(backupUploadedRevisionKey, revision);
    // A newer mutation may have failed to schedule while this upload ran.
    if ((await read()).revision == revision) {
      await prefs.remove(backupLastFailureKey);
      await prefs.remove(backupLastFailureMessageKey);
    }
    _changes.add(null);
  }

  Future<void> failure(String safeMessage) async {
    await _write(backupLastFailureKey, DateTime.now().toIso8601String());
    await _write(backupLastFailureMessageKey, safeMessage);
    _changes.add(null);
  }
}

String backupFailureMessage(Object error) => error is BackupCryptoFailure
    ? error.toString()
    : error is BackupAuthenticationFailure
        ? 'Cần đăng nhập lại Google để tiếp tục sao lưu.'
        : 'Chưa sao lưu được. Dữ liệu trên máy vẫn được giữ; Flowy sẽ thử lại theo lịch.';

Future<T> runBackupAttempt<T>(
    BackupStateStore store, Future<T> Function() upload,
    {required DateTime Function(T) uploadedAt}) async {
  final revision = await store.beginAttempt();
  try {
    final result = await upload();
    await store.success(revision, uploadedAt(result));
    return result;
  } catch (error) {
    await store.failure(backupFailureMessage(error));
    rethrow;
  }
}
