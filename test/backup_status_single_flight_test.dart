import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Platform fault injection holds the actual production prefs.reload boundary.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:pfm_app/services/backup_state.dart';
import 'package:pfm_app/services/backup_status_observation.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/backup_live_feedback_host.dart';
import 'package:pfm_app/widgets/backup_status_details.dart';
import 'package:pfm_app/core/feedback/app_feedback.dart';

class _Reads {
  final gates = <Completer<BackupStatus>>[];
  int active = 0, maximum = 0;
  Future<BackupStatus> read() {
    active++;
    if (active > maximum) maximum = active;
    final gate = Completer<BackupStatus>();
    gates.add(gate);
    return gate.future.whenComplete(() => active--);
  }
}

class _DelayedPreferences extends InMemorySharedPreferencesStore {
  _DelayedPreferences() : super.empty();
  final gate = Completer<void>();
  int active = 0, maximum = 0;
  @override
  Future<Map<String, Object>> getAll() async {
    active++;
    if (active > maximum) maximum = active;
    await gate.future;
    active--;
    return super.getAll();
  }
}

void main() {
  const fast = Duration(milliseconds: 750);
  final queuedAt = DateTime(2026, 10, 4);
  BackupStatus status(ManualBackupPhase phase) => BackupStatus(
      manualRequest:
          ManualBackupRequest(id: 'request', phase: phase, queuedAt: queuedAt));
  late _Reads reads;
  late StreamController<void> changes;
  late BackupStatusObservation engine;
  late List<BackupStatus> values;
  late StreamSubscription<BackupStatus> listener;

  setUp(() {
    reads = _Reads();
    changes = StreamController<void>.broadcast();
    engine = BackupStatusObservation(
        coordinator: BackupStatusReadCoordinator(reads.read),
        changes: changes.stream);
    values = [];
  });
  tearDown(() {
    engine.dispose();
    unawaited(changes.close());
    AppFeedback.dismissImmediately();
  });
  Future<void> start(WidgetTester tester) async {
    listener = engine.stream.listen(values.add);
    await tester.pump();
    expect(reads.gates, hasLength(1));
  }

  Future<void> stop(WidgetTester tester) async {
    unawaited(listener.cancel());
    engine.dispose();
    await tester.pump();
  }

  testWidgets('backupStatus_providerRecreation_doesNotOverlapRead',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final previous = SharedPreferencesStorePlatform.instance;
    final delayed = _DelayedPreferences();
    SharedPreferencesStorePlatform.instance = delayed;
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    final consumer = container.listen(backupStatusProvider, (_, __) {});
    try {
      await tester.pump();
      expect(delayed.active, 1);
      final observation = container.read(backupStatusObservationProvider);
      container.invalidate(backupStatusProvider);
      container.read(backupStatusProvider);
      await tester.pump(const Duration(milliseconds: 1));
      expect(
          container.read(backupStatusObservationProvider), same(observation));
      expect(delayed.maximum, 1);
      delayed.gate.complete();
      await tester.pump();
      expect(container.read(backupStatusProvider).requireValue.dirty, isFalse);
      await tester.pump(const Duration(seconds: 14));
      expect(delayed.maximum, 1);
    } finally {
      if (!delayed.gate.isCompleted) delayed.gate.complete();
      await tester.pump();
      consumer.close();
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
      SharedPreferencesStorePlatform.instance = previous;
    }
  });

  testWidgets('backupStatus_settingsAndHost_shareSingleRead', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          backupStatusObservationProvider.overrideWithValue(engine),
        ],
        child: MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) => BackupLiveFeedbackHost(
                navigatorKey: navigator, reduceMotion: true, child: child!),
            home: const Scaffold(body: BackupStatusDetails()))));
    expect(reads.gates, hasLength(1));
    reads.gates.single.complete(status(ManualBackupPhase.running));
    await tester.pump();
    await tester.pump();
    await tester.pump(fast);
    expect(reads.gates, hasLength(2));
    expect(reads.maximum, 1);
    await tester.pump(const Duration(seconds: 15));
    expect(reads.gates, hasLength(2)); // One engine, not a timer per consumer.
    engine.dispose();
    reads.gates.last.complete(status(ManualBackupPhase.success));
    AppFeedback.dismissImmediately();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final signal in ['resume', 'poll', 'event']) {
    testWidgets('backupStatus_${signal}DuringPendingRead_doesNotOverlap',
        (tester) async {
      await start(tester);
      if (signal == 'resume') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding
            .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      } else if (signal == 'event') {
        changes.add(null);
      }
      await tester.pump(const Duration(seconds: 15));
      expect(reads.gates, hasLength(1));
      expect(reads.maximum, 1);
      await stop(tester);
      reads.gates.first.complete(status(ManualBackupPhase.running));
      await tester.pump();
    });
  }

  testWidgets('backupStatus_concurrentCallersShareIdenticalFuture',
      (tester) async {
    final coordinator = BackupStatusReadCoordinator(reads.read);
    final first = coordinator.readFresh();
    final second = coordinator.readFresh();
    expect(second, same(first));
    expect(reads.gates, hasLength(1));
    reads.gates.first.complete(const BackupStatus());
    await tester.pump();
  });

  testWidgets('backupStatus_failedRead_releasesSingleFlightGate',
      (tester) async {
    final coordinator = BackupStatusReadCoordinator(reads.read);
    final first = coordinator.readFresh();
    final failure = expectLater(first, throwsStateError);
    reads.gates.first.completeError(StateError('storage unavailable'));
    await tester.pump();
    await failure;
    final retry = coordinator.readFresh();
    expect(retry, isNot(same(first)));
    expect(reads.gates, hasLength(2));
    expect(reads.maximum, 1);
    reads.gates.last.complete(const BackupStatus());
    await tester.pump();
  });

  testWidgets('backupStatus_disposedConsumer_doesNotCancelSharedRead',
      (tester) async {
    await start(tester);
    unawaited(listener.cancel());
    await tester.pump();
    final latest = <BackupStatus>[];
    final replacement = engine.stream.listen(latest.add);
    await tester.pump();
    expect(reads.gates, hasLength(1));
    reads.gates.first.complete(status(ManualBackupPhase.queued));
    await tester.pump();
    expect(values, isEmpty); // Disposed generation cannot publish to old owner.
    expect(reads.gates, hasLength(2));
    reads.gates.last.complete(status(ManualBackupPhase.running));
    await tester.pump();
    expect(latest.single.manualRequest!.phase, ManualBackupPhase.running);
    expect(reads.maximum, 1);
    unawaited(replacement.cancel());
    await tester.pump();
  });

  for (final count in [1, 20]) {
    testWidgets(
        'backupStatus_${count}RefreshesDuringRead_coalesceToOneFollowUp',
        (tester) async {
      await start(tester);
      for (var i = 0; i < count; i++) {
        engine.refreshNow();
      }
      expect(reads.gates, hasLength(1));
      reads.gates.first.complete(status(ManualBackupPhase.queued));
      await tester.pump();
      expect(reads.gates, hasLength(2));
      reads.gates.last.complete(status(ManualBackupPhase.running));
      await tester.pump();
      expect(reads.gates, hasLength(2));
      expect(reads.maximum, 1);
      await stop(tester);
    });
  }

  testWidgets('backupStatus_followUpReadSeesNewerPersistedState',
      (tester) async {
    await start(tester);
    changes
        .add(null); // A worker/local write occurred after read A captured data.
    await tester.pump();
    reads.gates.first.complete(status(ManualBackupPhase.queued));
    await tester.pump();
    reads.gates.last.complete(status(ManualBackupPhase.success));
    await tester.pump();
    expect(values.last.manualRequest!.phase, ManualBackupPhase.success);
    expect(reads.gates, hasLength(2));
    expect(reads.maximum, 1);
    await tester.pump(const Duration(seconds: 14));
    expect(reads.gates, hasLength(2));
    await stop(tester);
  });

  testWidgets('backupStatus_resumeUsesRefreshNotProviderRecreation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final navigator = GlobalKey<NavigatorState>();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      backupStatusObservationProvider.overrideWithValue(engine),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) => BackupLiveFeedbackHost(
                navigatorKey: navigator, reduceMotion: true, child: child!),
            home: const Scaffold(body: BackupStatusDetails()))));
    reads.gates.first.complete(const BackupStatus());
    await tester.pump();
    final providerElement = container.readProviderElement(backupStatusProvider);
    final before = container.read(backupStatusProvider);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(container.readProviderElement(backupStatusProvider),
        same(providerElement));
    expect(container.read(backupStatusProvider), same(before));
    expect(container.read(backupStatusObservationProvider), same(engine));
    expect(reads.gates, hasLength(2));
    reads.gates.last.complete(status(ManualBackupPhase.running));
    await tester.pump();
    // Repeated refresh/resume is bounded to one follow-up if one was requested.
    for (final gate
        in reads.gates.where((gate) => !gate.isCompleted).toList()) {
      gate.complete(status(ManualBackupPhase.running));
    }
    engine.dispose();
    AppFeedback.dismissImmediately();
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('backupStatus_resumeRefreshesImmediately', (tester) async {
    await start(tester);
    reads.gates.first.complete(status(ManualBackupPhase.queued));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(reads.gates, hasLength(2)); // No 750ms / 15s wait.
    await stop(tester);
    reads.gates.last.complete(status(ManualBackupPhase.success));
    await tester.pump();
  });

  testWidgets(
      'backupStatus_repeatedResumeDoesNotCreateMultipleTimersOrObservers',
      (tester) async {
    await start(tester);
    reads.gates.first.complete(status(ManualBackupPhase.running));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    await tester.pump();
    expect(reads.gates, hasLength(2));
    reads.gates.last.complete(status(ManualBackupPhase.running));
    await tester.pump();
    expect(reads.gates, hasLength(3)); // Exactly one coalesced follow-up.
    reads.gates.last.complete(status(ManualBackupPhase.running));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 749));
    expect(reads.gates, hasLength(3));
    await tester.pump(const Duration(milliseconds: 1));
    expect(reads.gates, hasLength(4)); // Exactly one timer/engine tick.
    expect(values, hasLength(1));
    expect(reads.maximum, 1);
    await stop(tester);
    reads.gates.last.complete(status(ManualBackupPhase.running));
    await tester.pump();
  });
}
