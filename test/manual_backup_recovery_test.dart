import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/features/notifications/notification_background.dart';
import 'package:pfm_app/services/backup_access.dart';
import 'package:pfm_app/services/backup_dispatcher.dart';
import 'package:pfm_app/services/backup_schedule.dart';
import 'package:pfm_app/services/backup_state.dart';
import 'package:pfm_app/services/backup_worker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class _Scheduler implements BackupWorkScheduler, ManualBackupWorkInspector {
  WorkState? state;
  bool failRegistration = false, failInspection = false;
  final ids = <String>[];
  @override
  Future<WorkState?> manualState(String id) async {
    if (failInspection) throw StateError('query unavailable');
    return state;
  }

  @override
  Future<void> manual(String id) async {
    if (failRegistration) throw StateError('raw secret');
    ids.add(id);
    state = WorkState.scheduled;
  }

  @override
  Future<void> cancel(String name) async {}
  @override
  Future<void> entry(Constraints constraints) async {}
  @override
  Future<void> periodic(Constraints constraints) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late BackupStateStore store;
  late Directory directory;
  late _Scheduler scheduler;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
    prefs = await SharedPreferences.getInstance();
    store = BackupStateStore(prefs);
    directory = await Directory.systemTemp.createTemp('manual_recovery_');
    scheduler = _Scheduler();
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    WorkmanagerFlutterApi.setUp(null);
    await directory.delete(recursive: true);
  });
  Future<ManualBackupRequest> enqueue() => enqueueManualBackup(prefs,
      directory: directory.path, scheduler: scheduler);
  Future<void> recover() => recoverManualBackup(prefs,
      directory: directory.path, scheduler: scheduler);
  Future<bool> run(String? id, {Future<void> Function()? upload}) =>
      runCloudBackupTask(
          task: cloudManualBackupTask,
          requestId: id,
          prefs: prefs,
          withAccess: (action) => withBackupAccess(directory.path, action),
          withRequestAccess: (action) => withBackupAccess(
              directory.path, action,
              name: 'manual_backup_request.lock'),
          restorePending: () async => false,
          performBackup: ({required bool silent}) async {
            expect(silent, isTrue);
            await upload?.call();
          });

  test('manualBackup_registrationFailure_doesNotRemainQueued', () async {
    scheduler.failRegistration = true;
    await expectLater(enqueue(), throwsStateError);
    final request = (await store.readManualRequest())!;
    expect(request.phase, ManualBackupPhase.failure);
    expect(request.message, isNot(contains('raw secret')));
    expect((await store.read()).lastSuccess, isNull);
  });
  test('manualBackup_startupQueuedRequest_isReconciled_withSameId', () async {
    final request = await enqueue();
    scheduler.state = null;
    await recover();
    expect(scheduler.ids, [request.id, request.id]);
    expect((await store.readManualRequest())!.id, request.id);
  });
  test('manualBackup_reconcileSameRequest_isIdempotent', () async {
    final request = await enqueue();
    scheduler.state = null;
    await Future.wait(List.generate(5, (_) => recover()));
    expect(scheduler.ids, [request.id, request.id]);
  });
  for (final state in [
    WorkState.failed,
    WorkState.cancelled,
    WorkState.succeeded
  ]) {
    test(
        'manualBackup_queuedWithoutExecutableWorker_${state.name}_doesNotRemainForever',
        () async {
      final request = await enqueue();
      scheduler.state = state;
      await recover();
      expect(
          (await store.readManualRequest())!.phase, ManualBackupPhase.failure);
      expect((await store.read()).lastSuccess, isNull);
      expect(scheduler.ids, [request.id]);
      await recover();
      expect(scheduler.ids, hasLength(1));
    });
  }
  test('manualBackup_runningWorkerCrash_recoversSafelyWhenNoWorkRemains',
      () async {
    final request = await enqueue();
    await store.transitionManualRequest(request.id, ManualBackupPhase.running);
    scheduler.state = null;
    await recover();
    expect((await store.readManualRequest())!.phase, ManualBackupPhase.queued);
    expect(scheduler.ids.last, request.id);
    expect(await run(request.id), isTrue);
  });
  test('manualBackup_runningWorkerCrash_rescheduledByAndroid_returnsToQueued',
      () async {
    final request = await enqueue();
    await store.transitionManualRequest(request.id, ManualBackupPhase.running);
    await recover();
    expect((await store.readManualRequest())!.phase, ManualBackupPhase.queued);
    expect(scheduler.ids, [request.id]);
  });
  test('manualBackup_runningWorkerCrash_nativeFailure_isSafeFailure', () async {
    final request = await enqueue();
    await store.transitionManualRequest(request.id, ManualBackupPhase.running);
    scheduler.state = WorkState.failed;
    await recover();
    expect((await store.readManualRequest())!.phase, ManualBackupPhase.failure);
  });
  test('manualBackup_activeWorker_isNotTimedOutOrReplaced', () async {
    final request = await enqueue();
    await store.transitionManualRequest(request.id, ManualBackupPhase.running);
    scheduler.state = WorkState.running;
    await recover();
    expect((await store.readManualRequest())!.phase, ManualBackupPhase.running);
    expect(scheduler.ids, [request.id]);
  });
  test('manualBackup_failedInspection_doesNotInventWorkerFailure', () async {
    await enqueue();
    scheduler.failInspection = true;
    await recover();
    expect((await store.readManualRequest())!.phase, ManualBackupPhase.queued);
    expect(scheduler.ids, hasLength(1));
  });
  for (final phase in [ManualBackupPhase.success, ManualBackupPhase.failure]) {
    test('manualBackup_terminalRequest_${phase.name}_notReenqueued', () async {
      final request = await enqueue();
      await store.transitionManualRequest(request.id, phase);
      await recover();
      await recover();
      expect(scheduler.ids, [request.id]);
      expect((await store.readManualRequest())!.pending, isFalse);
    });
  }
  test('manualBackup_unknownTask_doesNotAcknowledgeSuccess', () async {
    await enqueue();
    expect(
        await dispatchNotificationBackgroundTask(
            '$cloudManualBackupTask.typo', null),
        isFalse);
    expect((await store.read()).lastSuccess, isNull);
    expect((await store.readManualRequest())!.phase, ManualBackupPhase.queued);
  });
  test('manualBackup_dispatcherRecognizesExactProductionTaskName', () {
    expect(isRecognizedBackgroundTask(cloudManualBackupTask), isTrue);
    expect(isRecognizedBackgroundTask(notificationRefreshTask), isTrue);
    expect(isRecognizedBackgroundTask('$cloudManualBackupTask.extra'), isFalse);
  });
  test('manualBackup_missingRequestId_isFailure_notSilentSuccess', () async {
    await enqueue();
    expect(await run(null), isFalse);
    expect((await store.readManualRequest())!.phase, ManualBackupPhase.failure);
    expect((await store.read()).lastSuccess, isNull);
  });
  test('manualBackup_queuedCanReachRunning_thenTerminal', () async {
    final request = await enqueue();
    expect(
        await run(request.id, upload: () async {
          expect((await store.readManualRequest())!.phase,
              ManualBackupPhase.running);
        }),
        isTrue);
    expect((await store.readManualRequest())!.phase, ManualBackupPhase.success);
  });

  test('manualBackup_requestIdSurvivesWorkManagerBoundary_andReadyHandshake',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const prefix = 'dev.flutter.pigeon.workmanager_platform_interface.';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var readySignals = 0;
    const readyChannel = BasicMessageChannel<Object?>(
        '${prefix}WorkmanagerHostApi.notifyBackgroundChannelInitialized',
        WorkmanagerHostApi.pigeonChannelCodec);
    messenger.setMockDecodedMessageHandler<Object?>(readyChannel, (_) async {
      readySignals++;
      return <Object?>[null];
    });
    addTearDown(() =>
        messenger.setMockDecodedMessageHandler<Object?>(readyChannel, null));
    final request = await enqueue();
    registerBackupBackgroundHandler((task, input) async {
      expect(task, cloudManualBackupTask);
      expect(input!['requestId'], request.id);
      return run(input['requestId'] as String);
    });
    await Future<void>.delayed(Duration.zero);
    expect(readySignals, 1);
    Object? response;
    await messenger.handlePlatformMessage(
        '${prefix}WorkmanagerFlutterApi.executeTask',
        WorkmanagerFlutterApi.pigeonChannelCodec.encodeMessage(<Object?>[
          cloudManualBackupTask,
          <String?, Object?>{'requestId': request.id}
        ]),
        (data) => response =
            WorkmanagerFlutterApi.pigeonChannelCodec.decodeMessage(data));
    expect(response, <Object?>[true]);
    expect((await store.readManualRequest())!.phase, ManualBackupPhase.success);
  });
}
