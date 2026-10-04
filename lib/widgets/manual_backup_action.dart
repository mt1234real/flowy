import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../services/backup_schedule.dart';
import '../services/backup_state.dart';
import '../features/notifications/notification_background.dart';
import '../theme/app_theme.dart';
import '../core/feedback/app_feedback.dart';
import 'backup_status_details.dart';

final manualBackupEnqueueProvider =
    Provider<Future<ManualBackupRequest> Function()>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return () async {
    await ensureBackupWorkerInitialized();
    final documents = await getApplicationDocumentsDirectory();
    return enqueueManualBackup(prefs, directory: documents.path);
  };
});

/// Both manual buttons await registration only, never snapshot/encryption/upload.
class ManualBackupAction extends ConsumerStatefulWidget {
  final bool enabled;
  final Widget Function(bool pending, VoidCallback? enqueue) builder;
  const ManualBackupAction(
      {super.key, required this.enabled, required this.builder});
  @override
  ConsumerState<ManualBackupAction> createState() => _ManualBackupActionState();
}

class _ManualBackupActionState extends ConsumerState<ManualBackupAction> {
  bool _enqueueing = false;
  Future<void> _enqueue() async {
    if (_enqueueing) return;
    setState(() => _enqueueing = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(manualBackupEnqueueProvider)();
      if (mounted) {
        AppFeedback.showInfo(context, 'Đã đưa yêu cầu sao lưu vào hàng đợi.');
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.showError(context,
            'Chưa đưa được yêu cầu sao lưu vào hàng đợi. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _enqueueing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(backupStatusProvider);
    final pending =
        _enqueueing || status.valueOrNull?.manualRequest?.pending == true;
    return widget.builder(pending,
        widget.enabled && status.hasValue && !pending ? _enqueue : null);
  }
}
