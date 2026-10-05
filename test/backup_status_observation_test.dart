import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pfm_app/core/feedback/app_feedback.dart';
import 'package:pfm_app/services/backup_state.dart';
import 'package:pfm_app/services/backup_status_observation.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/backup_live_feedback_host.dart';
import 'package:pfm_app/widgets/backup_status_details.dart';

void main() {
  const fast = Duration(milliseconds: 750);
  final queuedAt = DateTime(2026, 10, 4);
  BackupStatus status(ManualBackupPhase phase) => BackupStatus(
      manualRequest: ManualBackupRequest(
          id: 'request',
          phase: phase,
          queuedAt: queuedAt,
          finishedAt: phase == ManualBackupPhase.success ||
                  phase == ManualBackupPhase.failure
              ? DateTime.now()
              : null));
  late BackupStatus current;
  late StreamController<void> changes;
  late StreamSubscription<BackupStatus> subscription;
  late List<BackupStatus> observed;
  late int reads;
  BackupStatusObservation? observation;

  Stream<BackupStatus> observe({
    required Future<BackupStatus> Function() read,
    required Stream<void> changes,
  }) {
    observation = BackupStatusObservation(
        coordinator: BackupStatusReadCoordinator(read), changes: changes);
    return observation!.stream;
  }

  Future<void> start(WidgetTester tester,
      {Future<BackupStatus> Function()? read}) async {
    subscription = observe(
            read: read ??
                () async {
                  reads++;
                  return current;
                },
            changes: changes.stream)
        .listen(observed.add);
    await tester.pump();
  }

  setUp(() {
    current = const BackupStatus();
    changes = StreamController<void>.broadcast();
    observed = [];
    reads = 0;
    observation = null;
  });
  // Each observation test cancels its subscription in the fake timer zone.
  tearDown(() {
    observation?.dispose();
    unawaited(changes.close());
    AppFeedback.dismissImmediately();
  });

  for (final phase in [ManualBackupPhase.queued, ManualBackupPhase.running]) {
    testWidgets('backupStatus_active${phase.name}_usesFastRefresh',
        (tester) async {
      current = status(phase);
      await start(tester);
      expect(reads, 1);
      await tester.pump(const Duration(milliseconds: 749));
      expect(reads, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(reads, 2);
      unawaited(subscription.cancel());
      await tester.pump();
    });
  }
  for (final phase in [ManualBackupPhase.success, ManualBackupPhase.failure]) {
    testWidgets('backupStatus_${phase.name}_returnsToSlowRefresh',
        (tester) async {
      current = status(ManualBackupPhase.running);
      await start(tester);
      current = status(phase);
      await tester.pump(fast);
      expect(observed.last.manualRequest!.phase, phase);
      expect(reads, 2);
      await tester.pump(const Duration(seconds: 14));
      expect(reads, 2);
      await tester.pump(const Duration(seconds: 1));
      expect(reads, 3);
      unawaited(subscription.cancel());
      await tester.pump();
    });
  }
  testWidgets('backupStatus_noRequest_usesSlowRefresh', (tester) async {
    await start(tester);
    await tester.pump(const Duration(seconds: 14));
    expect(reads, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(reads, 2);
    unawaited(subscription.cancel());
    await tester.pump();
  });
  for (final lifecycle in [
    AppLifecycleState.paused,
    AppLifecycleState.inactive
  ]) {
    testWidgets('backupStatus_${lifecycle.name}_stopsFastPolling',
        (tester) async {
      current = status(ManualBackupPhase.running);
      await start(tester);
      tester.binding.handleAppLifecycleStateChanged(lifecycle);
      changes.add(null);
      await tester.pump(const Duration(minutes: 1));
      expect(reads, 1);
      unawaited(subscription.cancel());
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
  }
  testWidgets('backupStatus_resumeRefreshesImmediately', (tester) async {
    current = status(ManualBackupPhase.queued);
    await start(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    current = status(ManualBackupPhase.success);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(observed.last.manualRequest!.phase, ManualBackupPhase.success);
    expect(reads, 2);
    unawaited(subscription.cancel());
    await tester.pump();
  });
  testWidgets('backupStatus_localQueuedEvent_startsFastRefreshImmediately',
      (tester) async {
    await start(tester);
    current = status(ManualBackupPhase.queued);
    changes.add(null);
    await tester.pump();
    expect(observed.last.manualRequest!.phase, ManualBackupPhase.queued);
    await tester.pump(fast);
    expect(reads, 3);
    unawaited(subscription.cancel());
    await tester.pump();
  });
  testWidgets('backupStatus_sameState_doesNotEmitRepeatedTransition',
      (tester) async {
    current = status(ManualBackupPhase.running);
    await start(tester);
    for (var i = 0; i < 5; i++) {
      current = status(ManualBackupPhase.running); // New object, same values.
      await tester.pump(fast);
    }
    expect(reads, 6);
    expect(observed, hasLength(1));
    unawaited(subscription.cancel());
    await tester.pump();
  });
  testWidgets('backupStatus_changedDetails_emitEvenWhenPhaseIsUnchanged',
      (tester) async {
    await start(tester);
    current =
        const BackupStatus(revision: 'new', failureMessage: 'Safe failure');
    changes.add(null);
    await tester.pump();
    expect(observed, hasLength(2));
    expect(observed.last.dirty, isTrue);
    unawaited(subscription.cancel());
    await tester.pump();
  });
  testWidgets('backupStatus_disposeCancelsTimerAndLocalEvents', (tester) async {
    current = status(ManualBackupPhase.running);
    await start(tester);
    unawaited(subscription.cancel());
    await tester.pump();
    changes.add(null);
    await tester.pump(const Duration(minutes: 1));
    expect(reads, 1);
  });
  testWidgets('backupStatus_refreshesNeverOverlapAndDisposedReadCannotEmit',
      (tester) async {
    final gate = Completer<BackupStatus>();
    await start(tester, read: () {
      reads++;
      return gate.future;
    });
    changes.add(null);
    changes.add(null);
    await tester.pump(const Duration(seconds: 15));
    expect(reads, 1);
    unawaited(subscription.cancel());
    await tester.pump();
    gate.complete(status(ManualBackupPhase.running));
    await tester.pump(const Duration(seconds: 15));
    expect(reads, 1);
    expect(observed, isEmpty);
  });
  testWidgets('backupStatus_readFailureRetainsStateAndContinuesPolling',
      (tester) async {
    current = status(ManualBackupPhase.queued);
    await start(tester, read: () async {
      reads++;
      if (reads == 2) throw StateError('storage unavailable');
      return current;
    });
    current = status(ManualBackupPhase.success);
    await tester.pump(fast);
    expect(observed.last.manualRequest!.phase, ManualBackupPhase.queued);
    await tester.pump(fast);
    expect(observed.last.manualRequest!.phase, ManualBackupPhase.success);
    unawaited(subscription.cancel());
    await tester.pump();
  });

  for (final phase in [ManualBackupPhase.running, ManualBackupPhase.success]) {
    testWidgets('foregroundRefresh_seesBackground${phase.name}Write_freshCache',
        (tester) async {
      final original = status(ManualBackupPhase.queued).manualRequest!;
      SharedPreferences.setMockInitialValues(
          {backupManualRequestKey: jsonEncode(original.toJson())});
      final prefs = await SharedPreferences.getInstance();
      subscription =
          observe(read: BackupStateStore(prefs).read, changes: changes.stream)
              .listen(observed.add);
      await tester.pump();
      final advanced = status(phase).manualRequest!;
      // Replace platform contents without touching this foreground instance's
      // cache or emitting its local stream, just like a separate engine write.
      SharedPreferences.setMockInitialValues(
          {backupManualRequestKey: jsonEncode(advanced.toJson())});
      expect(prefs.getString(backupManualRequestKey),
          jsonEncode(original.toJson()));
      await tester.pump(fast);
      expect(observed.last.manualRequest!.phase, phase);
      expect(prefs.getString(backupManualRequestKey),
          jsonEncode(advanced.toJson()));
      unawaited(subscription.cancel());
      await tester.pump();
    });
  }
  testWidgets('foregroundRefresh_topPillAndSettingsObserveSamePersistedSource',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      backupManualRequestKey:
          jsonEncode(status(ManualBackupPhase.queued).manualRequest!.toJson())
    });
    final prefs = await SharedPreferences.getInstance();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) => BackupLiveFeedbackHost(
                navigatorKey: navigator, reduceMotion: true, child: child!),
            home: const Scaffold(body: BackupStatusDetails()))));
    Future<void> frames() async {
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
    }

    await frames();
    for (final phase in [
      ManualBackupPhase.running,
      ManualBackupPhase.success
    ]) {
      SharedPreferences.setMockInitialValues({
        backupManualRequestKey:
            jsonEncode(status(phase).manualRequest!.toJson())
      });
      await tester.pump(fast);
      await frames();
      expect(
          find.textContaining(phase == ManualBackupPhase.running
              ? 'đang chạy trong nền'
              : 'đã thành công'),
          findsOneWidget);
      if (phase == ManualBackupPhase.success) {
        // B2 keeps its existing minimum visible live duration independently
        // of the freshly observed persisted state.
        await tester.pump(const Duration(milliseconds: 850));
        await frames();
      }
      expect(
          find.text(phase == ManualBackupPhase.running
              ? 'Đang sao lưu dữ liệu…'
              : 'Đã sao lưu lên Google Drive'),
          findsOneWidget);
    }
    AppFeedback.dismissImmediately();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
