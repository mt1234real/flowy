import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/backup_state.dart';
import '../theme/app_theme.dart';

final backupStatusProvider = StreamProvider.autoDispose<BackupStatus>((ref) {
  final store = BackupStateStore(ref.read(sharedPreferencesProvider));
  return Stream<BackupStatus>.multi((events) {
    var active = true;
    Future<void> refresh() async {
      try {
        final status = await store.read();
        if (active) events.add(status);
      } catch (_) {
        // Keep the last readable state; never display a raw storage exception.
      }
    }

    unawaited(refresh());
    final changes = BackupStateStore.changes.listen((_) => refresh());
    // A background isolate writes preferences independently of foreground cache.
    final timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
    events.onCancel = () {
      active = false;
      timer.cancel();
      changes.cancel();
    };
  });
});

class BackupStatusDetails extends ConsumerWidget {
  const BackupStatusDetails({super.key});
  static final _date = DateFormat('dd/MM HH:mm');
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(backupStatusProvider).valueOrNull;
    if (status == null) return const SizedBox.shrink();
    final lines = <String>[
      if (status.manualRequest != null)
        switch (status.manualRequest!.phase) {
          ManualBackupPhase.queued => 'Sao lưu theo yêu cầu: đang chờ chạy',
          ManualBackupPhase.running =>
            'Sao lưu theo yêu cầu: đang chạy trong nền',
          ManualBackupPhase.success => 'Sao lưu theo yêu cầu: đã thành công',
          ManualBackupPhase.failure =>
            'Sao lưu theo yêu cầu: ${status.manualRequest!.message ?? "Chưa thành công. Hãy thử lại."}',
        },
      if (status.dirty) 'Có thay đổi đang chờ sao lưu',
      if (status.lastSuccess != null)
        'Thành công: ${_date.format(status.lastSuccess!.toLocal())}',
      if (status.lastAttempt != null)
        'Lần thử: ${_date.format(status.lastAttempt!.toLocal())}',
      if (status.lastFailure != null && status.failureMessage != null)
        'Lần chưa thành công (${_date.format(status.lastFailure!.toLocal())}): ${status.failureMessage}',
    ];
    return Text(lines.join('\n'),
        style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant));
  }
}
