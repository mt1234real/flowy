import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/feedback/app_feedback.dart';
import '../services/backup_state.dart';
import '../theme/app_theme.dart';
import 'backup_status_details.dart';

// Presentation receipt only; never part of the portable backup preferences.
const backupLivePresentedKey = 'pfm_backup_live_presented_v1';

/// A single root bridge. B1 persisted state remains the source of truth.
class BackupLiveFeedbackHost extends ConsumerStatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final bool reduceMotion;
  const BackupLiveFeedbackHost(
      {super.key,
      required this.child,
      required this.navigatorKey,
      this.reduceMotion = false});

  @override
  ConsumerState<BackupLiveFeedbackHost> createState() =>
      _BackupLiveFeedbackHostState();
}

class _BackupLiveFeedbackHostState extends ConsumerState<BackupLiveFeedbackHost>
    with WidgetsBindingObserver {
  ManualBackupRequest? _latest;
  String? _shown, _liveId;
  bool _foreground = true;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    ref.listenManual(backupStatusProvider, (_, next) {
      if (next.isLoading || !next.hasValue) return;
      _latest = next.valueOrNull?.manualRequest;
      _schedulePresentation();
    }, fireImmediately: true);
  }

  @override
  void didUpdateWidget(covariant BackupLiveFeedbackHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion != widget.reduceMotion) {
      _shown = null;
      _schedulePresentation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _epoch++;
    if (!_foreground) {
      if (_liveId != null) AppFeedback.dismissLive(_liveId!);
      _shown = null;
    } else {
      // Refresh cross-isolate persisted writes immediately on foreground resume.
      ref.invalidate(backupStatusProvider);
    }
  }

  void _schedulePresentation() {
    final epoch = ++_epoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && epoch == _epoch && _foreground) {
        _present(epoch);
      }
    });
  }

  void _present(int epoch) {
    AppFeedback.attachNavigatorKey(widget.navigatorKey);
    final request = _latest;
    if (request == null) {
      if (_liveId != null) AppFeedback.dismissLive(_liveId!);
      _liveId = _shown = null;
      return;
    }
    final signature =
        '${request.id}:${request.phase.name}:${request.finishedAt}';
    if (_shown == signature) return;
    if (!request.pending) {
      final prefs = ref.read(sharedPreferencesProvider);
      final alreadyPresented =
          prefs.getString(backupLivePresentedKey) == signature;
      final finished = request.finishedAt;
      final fresh = finished != null &&
          DateTime.now().difference(finished).abs() <
              const Duration(minutes: 2);
      if (alreadyPresented || !fresh) {
        if (_liveId != null) AppFeedback.dismissLive(_liveId!);
        _liveId = null;
        _shown = signature;
        return;
      }
    }
    if (!mounted || epoch != _epoch || !_foreground) return;
    _shown = signature;
    _liveId = request.id;
    final phase = request.phase;
    AppFeedback.showLive(AppLiveFeedback(
      id: request.id,
      message: switch (phase) {
        ManualBackupPhase.queued => 'Đang chờ sao lưu…',
        ManualBackupPhase.running => 'Đang sao lưu dữ liệu…',
        ManualBackupPhase.success => 'Đã sao lưu lên Google Drive',
        // Intentionally concise: never render arbitrary exception text here.
        ManualBackupPhase.failure => 'Chưa thể sao lưu',
      },
      icon: switch (phase) {
        ManualBackupPhase.queued => Icons.schedule_rounded,
        ManualBackupPhase.running => Icons.sync_rounded,
        ManualBackupPhase.success => Icons.check_circle_rounded,
        ManualBackupPhase.failure => Icons.error_outline_rounded,
      },
      tone: phase == ManualBackupPhase.success
          ? AppTopFeedbackTone.success
          : phase == ManualBackupPhase.failure
              ? AppTopFeedbackTone.error
              : AppTopFeedbackTone.info,
      terminal: !request.pending,
      spinning: phase == ManualBackupPhase.running,
      reduceMotion: widget.reduceMotion,
      onPresented: () {
        if (mounted) unawaited(_recordPresentation(signature));
      },
    ));
  }

  Future<void> _recordPresentation(String signature) async {
    // Only a visible terminal state earns a local presentation receipt.
    // This is not a BackupStateStore write and cannot dirty/schedule backup.
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setString(backupLivePresentedKey, signature);
    } catch (_) {
      // Keep runtime deduplication if storage is unavailable; status stays usable.
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    _epoch++;
    WidgetsBinding.instance.removeObserver(this);
    if (_liveId != null) AppFeedback.dismissLive(_liveId!);
    super.dispose();
  }
}
