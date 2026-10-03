import 'dart:async';
import 'dart:convert';

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
const backupManualRequestKey = 'pfm_backup_manual_request_v1';

enum ManualBackupPhase { queued, running, success, failure }

class ManualBackupRequest {
  final String id;
  final ManualBackupPhase phase;
  final DateTime queuedAt;
  final DateTime? startedAt, finishedAt;
  final String? message;
  const ManualBackupRequest(
      {required this.id,
      required this.phase,
      required this.queuedAt,
      this.startedAt,
      this.finishedAt,
      this.message});
  bool get pending =>
      phase == ManualBackupPhase.queued || phase == ManualBackupPhase.running;
  Map<String, dynamic> toJson() => {
        'version': 1,
        'id': id,
        'phase': phase.name,
        'queuedAt': queuedAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'message': message,
      };
  factory ManualBackupRequest.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Invalid manual request');
    }
    return ManualBackupRequest(
        id: json['id'] as String,
        phase: ManualBackupPhase.values.byName(json['phase'] as String),
        queuedAt: DateTime.parse(json['queuedAt'] as String),
        startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
        finishedAt: DateTime.tryParse(json['finishedAt'] as String? ?? ''),
        message: json['message'] as String?);
  }
}

class BackupAuthenticationFailure implements Exception {
  const BackupAuthenticationFailure();
  @override
  String toString() => 'Chưa đăng nhập Google hoặc người dùng hủy xác thực.';
}

class BackupStatus {
  final String? revision, uploadedRevision, failureMessage;
  final DateTime? dirtySince, lastAttempt, lastFailure, lastSuccess;
  final ManualBackupRequest? manualRequest;
  const BackupStatus(
      {this.revision,
      this.uploadedRevision,
      this.dirtySince,
      this.lastAttempt,
      this.lastFailure,
      this.lastSuccess,
      this.failureMessage,
      this.manualRequest});
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
      manualRequest: await readManualRequest(),
    );
  }

  Future<ManualBackupRequest?> readManualRequest() async {
    await prefs.reload();
    final value = prefs.getString(backupManualRequestKey);
    return value == null
        ? null
        : ManualBackupRequest.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map));
  }

  // Callers serialize request changes with manual_backup_request.lock.
  Future<void> writeManualRequest(ManualBackupRequest request) async {
    await _write(backupManualRequestKey, jsonEncode(request.toJson()));
    _changes.add(null);
  }

  Future<bool> transitionManualRequest(String id, ManualBackupPhase phase,
      {String? message}) async {
    final previous = await readManualRequest();
    if (previous == null ||
        previous.id != id ||
        previous.phase == ManualBackupPhase.success) {
      return false;
    }
    if (previous.phase == phase && previous.message == message) return true;
    await writeManualRequest(ManualBackupRequest(
        id: id,
        phase: phase,
        queuedAt: previous.queuedAt,
        startedAt: phase == ManualBackupPhase.running
            ? previous.startedAt ?? DateTime.now()
            : previous.startedAt,
        finishedAt: phase == ManualBackupPhase.success ||
                phase == ManualBackupPhase.failure
            ? DateTime.now()
            : null,
        message: message));
    return true;
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
