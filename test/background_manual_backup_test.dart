import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/services/backup_access.dart';
import 'package:pfm_app/services/backup_capsule.dart';
import 'package:pfm_app/services/backup_schedule.dart';
import 'package:pfm_app/services/backup_state.dart';
import 'package:pfm_app/services/backup_worker.dart';
import 'package:pfm_app/services/cloud_backup_service.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/backup_progress_curtain.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:workmanager/workmanager.dart';
import 'backup_reliability_test.dart' show TestCloudService, NoSilentAccount;

class _Workmanager extends WorkmanagerPlatform {
  final pending = <String, String>{};
  final registrations = <String>[];
  bool fail = false;
  @override
  Future<bool> isScheduledByUniqueName(String name) async =>
      pending.containsKey(name);
  @override
  Future<WorkInfo?> getWorkInfo(String name) async => pending.containsKey(name)
      ? WorkInfo(
          uniqueName: name,
          state: WorkState.scheduled,
          isPeriodic: false,
          taskName: cloudManualBackupTask)
      : null;
  @override
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    ForegroundServiceConfig? foregroundServiceConfig,
    bool expedited = false,
  }) async {
    expect(taskName, cloudManualBackupTask);
    expect(uniqueName, '$cloudManualBackupTask.${inputData!['requestId']}');
    expect(initialDelay, isNull);
    expect(existingWorkPolicy, ExistingWorkPolicy.keep);
    expect(constraints!.networkType, NetworkType.connected);
    expect(constraints.requiresBatteryNotLow, isNot(true));
    if (fail) throw StateError('secret raw platform failure');
    registrations.add(uniqueName);
    pending.putIfAbsent(uniqueName, () => inputData['requestId'] as String);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SharedPreferences prefs;
  late BackupStateStore store;
  late _Workmanager work;
  late WorkmanagerPlatform previousPlatform;
  final scheduler = WorkmanagerBackupScheduler();
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('manual_backup_');
    SharedPreferences.setMockInitialValues({'has_completed_onboarding': true});
    prefs = await SharedPreferences.getInstance();
    store = BackupStateStore(prefs);
    work = _Workmanager();
    previousPlatform = WorkmanagerPlatform.instance;
    WorkmanagerPlatform.instance = work;
  });
  tearDown(() async {
    WorkmanagerPlatform.instance = previousPlatform;
    await directory.delete(recursive: true);
  });

  Future<ManualBackupRequest> enqueue() => enqueueManualBackup(prefs,
      directory: directory.path, scheduler: scheduler);
  Future<bool> run({
    String task = cloudManualBackupTask,
    String? id,
    Future<void> Function({required bool silent})? pipeline,
    Future<bool> Function()? restorePending,
    Future<bool> Function(Future<bool> Function())? access,
  }) =>
      runCloudBackupTask(
          task: task,
          requestId: id,
          prefs: prefs,
          withAccess:
              access ?? (action) => withBackupAccess(directory.path, action),
          withRequestAccess: (action) => withBackupAccess(
              directory.path, action,
              name: 'manual_backup_request.lock'),
          restorePending: restorePending ?? () async => false,
          performBackup: pipeline ??
              ({required bool silent}) async {
                expect(silent, isTrue);
                await runBackupAttempt(
                    store, () async => DateTime(2026, 10, 3, 12),
                    uploadedAt: (date) => date);
              });

  test('manualBackup_enqueueDoesNotExecuteForegroundPipeline', () async {
    final request = await enqueue();
    expect(request.phase, ManualBackupPhase.queued);
    expect((await store.read()).lastAttempt, isNull);
    expect((await store.read()).lastSuccess, isNull);
    expect(work.pending, hasLength(1));
  });
  test('manualBackup_enqueuesWithoutThreeMinuteDelay_andAutomaticConstraints',
      () async {
    await prefs.setBool('pfm_backup_wifi_only', true);
    await prefs.setBool('pfm_backup_battery_safe', true);
    await enqueue(); // Platform fake asserts zero delay, KEEP, network only.
    expect(work.registrations, hasLength(1));
  });
  test('manualBackup_repeatedRequestsCoalesce', () async {
    final requests = await Future.wait(List.generate(4, (_) => enqueue()));
    expect(requests.map((r) => r.id).toSet(), hasLength(1));
    expect(work.pending, hasLength(1));
    expect((await store.read()).lastSuccess, isNull);
  });
  test('manualBackup_enqueueFailure_persistsSafeFailureWithoutAcknowledgement',
      () async {
    await store.markDirty();
    work.fail = true;
    await expectLater(enqueue(), throwsStateError);
    final status = await store.read();
    expect(status.manualRequest!.phase, ManualBackupPhase.failure);
    expect(status.manualRequest!.message, isNot(contains('secret')));
    expect(status.dirty, isTrue);
    expect(status.lastSuccess, isNull);
  });
  for (final revision in [null, 'clean']) {
    test('manualBackup_worksWhenClean_$revision', () async {
      if (revision != null) {
        await prefs.setString(backupDirtyRevisionKey, revision);
        await prefs.setString(backupUploadedRevisionKey, revision);
      }
      final request = await enqueue();
      expect(await run(id: request.id), isTrue);
      final status = await store.read();
      expect(status.dirty, isFalse);
      expect(status.lastSuccess, isNotNull);
      expect(status.manualRequest!.phase, ManualBackupPhase.success);
    });
  }
  test('manualBackup_worksInManualOnlyCadence_bypassesAutomaticDueGate',
      () async {
    await prefs.setInt('pfm_backup_cadence_mode', 3);
    await store.markDirty();
    expect(isBackupDue(prefs, entryTask: true), isFalse);
    final request = await enqueue();
    expect(await run(id: request.id), isTrue);
    expect((await store.read()).dirty, isFalse);
  });
  test('manualBackup_usesSilentAuth', () async {
    var silentCalls = 0;
    final request = await enqueue();
    expect(
        await run(
            id: request.id,
            pipeline: ({required bool silent}) async {
              expect(silent, isTrue);
              silentCalls++;
              await runBackupAttempt(store, () async => DateTime.now(),
                  uploadedAt: (t) => t);
            }),
        isTrue);
    expect(silentCalls, 1);
  });
  test('manualWorker_realPipelineSilentAuthFailure_neverOpensCurtain',
      () async {
    await prefs.setString('user_email', 'A@example.invalid');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final google = NoSilentAccount();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      cloudBackupServiceProvider.overrideWith(
          (ref) => TestCloudService(db: db, ref: ref, googleSignIn: google)),
    ]);
    final operations = <String?>[];
    final listener = container.listen(
        backupOperationProvider, (_, next) => operations.add(next));
    try {
      await store.markDirty();
      final request = await enqueue();
      expect(
          await run(
              id: request.id,
              pipeline: ({required bool silent}) async {
                await container
                    .read(cloudBackupServiceProvider)
                    .performBackup(silent: silent);
              }),
          isFalse);
      expect(google.interactiveCalls, 0);
      expect(google.silentCalls, 1);
      expect(operations, isEmpty);
      final status = await store.read();
      expect(status.dirty, isTrue);
      expect(status.uploadedRevision, isNull);
      expect(status.lastSuccess, isNull);
      expect(status.manualRequest!.message, contains('đăng nhập lại'));
    } finally {
      listener.close();
      container.dispose();
      await db.close();
    }
  });
  for (final error in [
    const BackupAuthenticationFailure(),
    StateError('token secret upload')
  ]) {
    test('manualBackup_failureDoesNotAcknowledgeSuccess_${error.runtimeType}',
        () async {
      await store.markDirty();
      final before = await store.read();
      final request = await enqueue();
      expect(
          await run(
              id: request.id,
              pipeline: ({required bool silent}) async {
                await runBackupAttempt<DateTime>(store, () async => throw error,
                    uploadedAt: (t) => t);
              }),
          isFalse);
      final status = await store.read();
      expect(status.revision, before.revision);
      expect(status.uploadedRevision, before.uploadedRevision);
      expect(status.lastSuccess, before.lastSuccess);
      expect(status.lastAttempt, isNotNull);
      expect(status.lastFailure, isNotNull);
      expect(status.manualRequest!.phase, ManualBackupPhase.failure);
      expect(status.manualRequest!.message, isNot(contains('token')));
    });
  }
  test('manualRequest_isRunning_thenSuccessOnlyAfterActualUpload', () async {
    final request = await enqueue();
    final started = Completer<void>(), uploaded = Completer<DateTime>();
    final future = run(
        id: request.id,
        pipeline: ({required bool silent}) async {
          await runBackupAttempt(store, () {
            started.complete();
            return uploaded.future;
          }, uploadedAt: (t) => t);
        });
    await started.future;
    expect(
        (await store.read()).manualRequest!.phase, ManualBackupPhase.running);
    expect((await store.read()).lastSuccess, isNull);
    final repeated = await enqueue();
    expect(repeated.id, request.id);
    expect(work.pending, hasLength(1));
    uploaded.complete(DateTime.now());
    expect(await future, isTrue);
    expect(
        (await store.read()).manualRequest!.phase, ManualBackupPhase.success);
  });
  test('manualRunning_newMutationRemainsDirty', () async {
    await store.markDirty();
    final revision = (await store.read()).revision;
    final request = await enqueue();
    final started = Completer<void>(), uploaded = Completer<DateTime>();
    final future = run(
        id: request.id,
        pipeline: ({required bool silent}) async {
          await runBackupAttempt(store, () {
            started.complete();
            return uploaded.future;
          }, uploadedAt: (t) => t);
        });
    await started.future;
    await store.markDirty();
    final newer = (await store.read()).revision;
    uploaded.complete(DateTime.now());
    expect(await future, isTrue);
    final after = await store.read();
    expect(after.uploadedRevision, revision);
    expect(after.revision, newer);
    expect(after.dirty, isTrue);
  });
  test('automaticTask_rechecksDueAfterLock_manualSuccessMakesWaitingAutoSkip',
      () async {
    await prefs.setInt('pfm_backup_cadence_mode', 0);
    await store.markDirty();
    final request = await enqueue();
    final started = Completer<void>(), uploaded = Completer<DateTime>();
    var calls = 0;
    final manual = run(
        id: request.id,
        pipeline: ({required bool silent}) async {
          calls++;
          await runBackupAttempt(store, () {
            started.complete();
            return uploaded.future;
          }, uploadedAt: (t) => t);
        });
    await started.future;
    final waiting = Completer<void>();
    final automatic = run(
        task: cloudEntryBackupTask,
        access: (action) {
          waiting.complete();
          return withBackupAccess(directory.path, action);
        },
        pipeline: ({required bool silent}) async {
          calls++;
        });
    await waiting.future;
    uploaded.complete(DateTime.now());
    expect(await manual, isTrue);
    expect(await automatic, isTrue);
    expect(calls, 1);
  });
  test('manualAndAutomatic_neverRunConcurrently_whenNewMutationStillDue',
      () async {
    await prefs.setInt('pfm_backup_cadence_mode', 0);
    await store.markDirty();
    final request = await enqueue();
    var active = 0, maxActive = 0, calls = 0;
    final started = Completer<void>(), release = Completer<void>();
    Future<void> pipeline({required bool silent}) async {
      active++;
      calls++;
      if (active > maxActive) maxActive = active;
      await runBackupAttempt(store, () async {
        if (calls == 1) {
          started.complete();
          await release.future;
        }
        return DateTime.now();
      }, uploadedAt: (t) => t);
      active--;
    }

    final manual = run(id: request.id, pipeline: pipeline);
    await started.future;
    final waiting = Completer<void>();
    final automatic = run(
        task: cloudEntryBackupTask,
        pipeline: pipeline,
        access: (action) {
          waiting.complete();
          return withBackupAccess(directory.path, action);
        });
    await waiting.future;
    await store.markDirty();
    release.complete();
    expect(await manual, isTrue);
    expect(await automatic, isTrue);
    expect(maxActive, 1);
    expect(calls, 2);
  });
  test('restorePending_blocksManualBackup_withoutOpeningDbPipeline', () async {
    await store.markDirty();
    final request = await enqueue();
    var calls = 0;
    expect(
        await run(
            id: request.id,
            restorePending: () async => true,
            pipeline: ({required bool silent}) async {
              calls++;
            }),
        isFalse);
    expect(calls, 0);
    final status = await store.read();
    expect(status.dirty, isTrue);
    expect(status.lastSuccess, isNull);
    expect(status.lastAttempt, isNotNull);
    expect(status.manualRequest!.message, contains('khôi phục'));
  });
  test('repeatedManualRequest_doesNotDuplicateUpload', () async {
    final request = await enqueue();
    var calls = 0;
    Future<void> pipeline({required bool silent}) async {
      calls++;
      await runBackupAttempt(store, () async => DateTime.now(),
          uploadedAt: (t) => t);
    }

    expect(await run(id: request.id, pipeline: pipeline), isTrue);
    expect(await run(id: request.id, pipeline: pipeline), isTrue);
    expect(calls, 1);
  });
  test('newRequest_doesNotGetLostBehindCompletingUniqueWork', () async {
    final previous = await enqueue();
    await run(id: previous.id);
    final next = await enqueue();
    expect(next.id, isNot(previous.id));
    expect(work.pending, hasLength(2)); // Previous work may still be exiting.
    var staleCalls = 0;
    expect(
        await run(
            id: previous.id,
            pipeline: ({required bool silent}) async {
              staleCalls++;
            }),
        isTrue);
    expect(staleCalls, 0);
    expect((await store.read()).manualRequest!.id, next.id);
  });
  for (final phase in [ManualBackupPhase.queued, ManualBackupPhase.running]) {
    test('manualRequest_restartRecovers_${phase.name}_withSameId', () async {
      final request = await enqueue();
      if (phase == ManualBackupPhase.running) {
        await store.transitionManualRequest(request.id, phase);
      }
      work.pending.clear();
      await recoverManualBackup(prefs,
          directory: directory.path, scheduler: scheduler);
      final recreated = BackupStateStore(await SharedPreferences.getInstance());
      expect((await recreated.read()).manualRequest!.id, request.id);
      expect(work.pending.values.single, request.id);
      expect(await run(id: request.id), isTrue);
    });
  }
  test('cleanRestart_doesNotScheduleManualWork', () async {
    await recoverManualBackup(prefs,
        directory: directory.path, scheduler: scheduler);
    expect(work.pending, isEmpty);
  });
  test('restartRecovery_registrationFailure_isVisibleAndRetryable', () async {
    final request = await enqueue();
    work.pending.clear();
    work.fail = true;
    await expectLater(
        recoverManualBackup(prefs,
            directory: directory.path, scheduler: scheduler),
        throwsStateError);
    final status = await store.read();
    expect(status.manualRequest!.id, request.id);
    expect(status.manualRequest!.phase, ManualBackupPhase.failure);
    expect(status.manualRequest!.pending, isFalse);
    expect(status.lastSuccess, isNull);
    work.fail = false;
    expect((await enqueue()).id, isNot(request.id));
  });
  test('restartRecovery_doesNotCreateIntentAfterPendingRequestCompletes',
      () async {
    final request = await enqueue();
    work.pending.clear();
    final guard = await acquireBackupAccess(directory.path,
        name: 'manual_backup_request.lock');
    final recovery = recoverManualBackup(prefs,
        directory: directory.path, scheduler: scheduler);
    try {
      await store.transitionManualRequest(
          request.id, ManualBackupPhase.success);
    } finally {
      await guard.close();
    }
    await recovery;
    expect(work.pending, isEmpty);
    expect((await store.read()).manualRequest!.id, request.id);
    expect(
        (await store.read()).manualRequest!.phase, ManualBackupPhase.success);
  });
  test('manualRuntimeState_notExportedToCloudPreferences', () async {
    await enqueue();
    final exported = await exportBackupPreferences(prefs);
    expect(exported.containsKey(backupManualRequestKey), isFalse);
    expect(backupPreferenceKeys.contains(backupManualRequestKey), isFalse);
  });
  test('taskClassification_preservesAutomaticAndManualPolicies', () {
    expect(isAutomaticBackupTask(cloudBackupTask), isTrue);
    expect(isAutomaticBackupTask(cloudEntryBackupTask), isTrue);
    expect(isAutomaticBackupTask(cloudManualBackupTask), isFalse);
    expect(isManualBackupTask(cloudManualBackupTask), isTrue);
    expect(isAnyBackupTask('notifications'), isFalse);
  });
  test('accessGuard_excludesSameProcessConnections_andReleasesOnFailure',
      () async {
    final guard = await acquireBackupAccess(directory.path);
    final other =
        sql.sqlite3.open('${directory.path}/restore_access.lock.sqlite');
    try {
      expect(() => other.execute('BEGIN EXCLUSIVE'),
          throwsA(isA<sql.SqliteException>()));
      await guard.close();
      other.execute('BEGIN EXCLUSIVE');
      other.execute('ROLLBACK');
      await expectLater(
          withBackupAccess<void>(directory.path, () async {
            throw StateError('failed');
          }),
          throwsStateError);
      other.execute('BEGIN EXCLUSIVE');
      other.execute('ROLLBACK');
    } finally {
      other.close();
    }
  });
  test('manualRequest_terminalTransition_isIdempotent', () async {
    final request = await enqueue();
    await run(id: request.id);
    final before = prefs.getString(backupManualRequestKey);
    expect(
        await store.transitionManualRequest(
            request.id, ManualBackupPhase.running),
        isFalse);
    expect(prefs.getString(backupManualRequestKey), before);
  });
}
