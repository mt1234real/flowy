import 'dart:async';

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/features/insights/insights_data.dart';
import 'package:pfm_app/features/notifications/notification_preferences.dart';
import 'package:pfm_app/screens/ledger_screen.dart'
    show cycleStartDaysByMonthProvider;
import 'package:pfm_app/services/auth_profile_service.dart';
import 'package:pfm_app/services/backup_change_observer.dart';
import 'package:pfm_app/services/backup_schedule.dart';
import 'package:pfm_app/services/backup_state.dart';
import 'package:pfm_app/services/cloud_backup_service.dart';
import 'package:pfm_app/services/fiscal_day.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/backup_progress_curtain.dart';
import 'package:pfm_app/widgets/backup_status_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class RecordingWorkmanager extends WorkmanagerPlatform {
  final Map<String, Constraints?> pending = {};
  int registrations = 0;
  bool fail = false;
  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    pending.remove(uniqueName);
  }

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
    expect(uniqueName, cloudEntryBackupTask);
    expect(taskName, cloudEntryBackupTask);
    expect(initialDelay, const Duration(minutes: 3));
    expect(existingWorkPolicy, ExistingWorkPolicy.replace);
    registrations++;
    if (fail) throw StateError('registration unavailable');
    pending[uniqueName] = constraints;
  }

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    expect(uniqueName, cloudBackupTask);
    expect(frequency, const Duration(hours: 1));
    expect(existingWorkPolicy, ExistingPeriodicWorkPolicy.update);
    registrations++;
    if (fail) throw StateError('registration unavailable');
    pending[uniqueName] = constraints;
  }
}

class NoSilentAccount extends GoogleSignIn {
  int interactiveCalls = 0;
  int silentCalls = 0;
  @override
  GoogleSignInAccount? get currentUser => null;
  @override
  Future<GoogleSignInAccount?> signInSilently(
      {bool suppressErrors = true, bool reAuthenticate = false}) async {
    silentCalls++;
    return null;
  }

  @override
  Future<GoogleSignInAccount?> signIn() async {
    interactiveCalls++;
    throw StateError('Interactive auth must not run in a background backup');
  }
}

class TestCloudService extends CloudBackupService {
  TestCloudService(
      {required super.db, required super.ref, super.googleSignIn, this.upload});
  final Future<CloudBackupItem> Function()? upload;
  @override
  Future<List<CloudBackupItem>> listBackups() async => [];
  @override
  Future<CloudBackupItem> createBackup({
    void Function(CloudBackupStatus, String, double)? onProgress,
  }) =>
      upload != null ? upload!() : super.createBackup(onProgress: onProgress);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late BackupStateStore store;
  late RecordingWorkmanager platform;
  late WorkmanagerPlatform original;
  const scheduler = _SchedulerFactory();
  final date = DateTime(2026, 10, 2, 3);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'pfm_backup_cadence_mode': 0});
    prefs = await SharedPreferences.getInstance();
    store = BackupStateStore(prefs);
    original = WorkmanagerPlatform.instance;
    platform = RecordingWorkmanager();
    WorkmanagerPlatform.instance = platform;
  });
  tearDown(() {
    WorkmanagerPlatform.instance = original;
  });

  Future<void> successfulUpload() =>
      runBackupAttempt<void>(store, () async {}, uploadedAt: (_) => date);

  test('mutation marks persistent dirty state before scheduling', () async {
    platform.fail = true;
    await markBackupDirty(prefs, scheduler: scheduler.create());
    expect((await store.read()).dirty, isTrue);
    expect((await store.read()).dirtySince, isNotNull);
    expect((await store.read()).lastFailure, isNotNull);
    platform.fail = false;
    await recoverPendingBackup(prefs, scheduler: scheduler.create());
    expect(platform.pending.keys, contains(cloudEntryBackupTask));
    expect((await store.read()).dirty, isTrue);
  });
  test('restart with dirty state reschedules work', () async {
    await store.markDirty();
    platform.pending.clear();
    final restarted = await SharedPreferences.getInstance();
    await recoverPendingBackup(restarted, scheduler: scheduler.create());
    expect(platform.pending.keys, [cloudEntryBackupTask]);
  });
  test('clean restart does not schedule entry work', () async {
    await recoverPendingBackup(prefs, scheduler: scheduler.create());
    expect(platform.pending, isEmpty);
  });
  test('rapid writes debounce into one unique replacing task', () async {
    for (var i = 0; i < 8; i++) {
      await markBackupDirty(prefs, scheduler: scheduler.create());
    }
    expect(platform.registrations, 8);
    expect(platform.pending.length, 1);
    expect((await store.read()).dirty, isTrue);
  });
  for (final constraint in [
    'pfm_backup_wifi_only',
    'pfm_backup_battery_safe'
  ]) {
    test('dirty constraint change refreshes $constraint', () async {
      await markBackupDirty(prefs, scheduler: scheduler.create());
      await prefs.setBool(constraint, false);
      await configureBackupSchedule(prefs, scheduler: scheduler.create());
      final current = platform.pending[cloudEntryBackupTask]!;
      if (constraint == 'pfm_backup_wifi_only') {
        expect(current.networkType, NetworkType.connected);
      } else {
        expect(current.requiresBatteryNotLow, isFalse);
      }
      expect(platform.registrations, 2);
      await successfulUpload();
      await prefs.setBool(constraint, true);
      await configureBackupSchedule(prefs, scheduler: scheduler.create());
      expect(platform.registrations, 2);
      expect(platform.pending, isEmpty);
    });
  }
  test('manual only keeps dirty without auto work', () async {
    await prefs.setInt('pfm_backup_cadence_mode', 3);
    await markBackupDirty(prefs, scheduler: scheduler.create());
    await recoverPendingBackup(prefs, scheduler: scheduler.create());
    expect((await store.read()).dirty, isTrue);
    expect(platform.pending, isEmpty);
    expect(isBackupDue(prefs, entryTask: false, at: date), isFalse);
  });
  test('failed upload keeps dirty and records sanitized failure', () async {
    await store.markDirty();
    await prefs.setString(backupLastSuccessKey, '2026-09-01T00:00:00.000');
    await expectLater(
        runBackupAttempt<void>(
            store, () async => throw Exception('secret token ABC raw stack'),
            uploadedAt: (_) => date),
        throwsException);
    final status = await store.read();
    expect(status.dirty, isTrue);
    expect(status.lastAttempt, isNotNull);
    expect(status.lastFailure, isNotNull);
    expect(status.failureMessage, isNot(contains('ABC')));
    expect(status.lastSuccess, DateTime(2026, 9, 1));
  });
  test('successful upload clears dirty and stale failure only after completion',
      () async {
    await store.markDirty();
    await store.failure('Earlier failure');
    final upload = Completer<void>();
    final attempted = runBackupAttempt<void>(store, () => upload.future,
        uploadedAt: (_) => date);
    await Future<void>.delayed(Duration.zero);
    expect((await store.read()).dirty, isTrue);
    expect((await store.read()).lastSuccess, isNull);
    upload.complete();
    await attempted;
    final status = await store.read();
    expect(status.dirty, isFalse);
    expect(status.lastSuccess, date);
    expect(status.lastFailure, isNull);
    expect(status.failureMessage, isNull);
  });
  test('upload cannot acknowledge mutation arriving during snapshot upload',
      () async {
    await store.markDirty();
    final started = Completer<void>();
    final upload = Completer<void>();
    final attempted = runBackupAttempt<void>(store, () {
      started.complete();
      return upload.future;
    }, uploadedAt: (_) => date);
    await started.future;
    await markBackupDirty(prefs, scheduler: scheduler.create());
    upload.complete();
    await attempted;
    expect((await store.read()).dirty, isTrue);
    expect(platform.pending.keys, contains(cloudEntryBackupTask));
    await successfulUpload();
    expect((await store.read()).dirty, isFalse);
  });
  test('manual upload succeeds even with clean state', () async {
    expect((await store.read()).dirty, isFalse);
    await successfulUpload();
    expect((await store.read()).lastSuccess, date);
    expect((await store.read()).lastAttempt, isNotNull);
  });
  test('older upload preserves failure associated with a newer mutation',
      () async {
    await store.markDirty();
    final revision = await store.beginAttempt();
    await store.markDirty();
    await store.failure('Chưa đặt được lịch sao lưu.');
    await store.success(revision, date);
    final status = await store.read();
    expect(status.dirty, isTrue);
    expect(status.failureMessage, 'Chưa đặt được lịch sao lưu.');
    await successfulUpload();
    expect((await store.read()).failureMessage, isNull);
  });
  test('failed clean manual attempt does not invent a mutation', () async {
    await expectLater(
        runBackupAttempt<void>(
            store, () async => throw const BackupAuthenticationFailure(),
            uploadedAt: (_) => date),
        throwsA(isA<BackupAuthenticationFailure>()));
    expect((await store.read()).dirty, isFalse);
    expect((await store.read()).lastFailure, isNotNull);
  });
  test('foreground status reloads persistent worker writes without dirtying',
      () async {
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    final subscription = container.listen(backupStatusProvider, (_, __) {});
    try {
      expect(
          (await container.read(backupStatusProvider.future)).dirty, isFalse);
      await store.markDirty();
      await store.beginAttempt();
      await store.failure('Cần đăng nhập lại Google để tiếp tục sao lưu.');
      for (var i = 0; i < 100; i++) {
        if (container.read(backupStatusProvider).valueOrNull?.lastFailure !=
            null) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      final visible = container.read(backupStatusProvider).requireValue;
      expect(visible.dirty, isTrue);
      expect(visible.lastAttempt, isNotNull);
      expect(visible.failureMessage, contains('đăng nhập lại'));
      await successfulUpload();
      for (var i = 0; i < 100; i++) {
        if (container.read(backupStatusProvider).valueOrNull?.dirty == false) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(container.read(backupStatusProvider).requireValue.dirty, isFalse);
    } finally {
      subscription.close();
      container.dispose();
    }
  });
  for (final mode in [1, 2, 4]) {
    test('periodic mode $mode requires both due and dirty', () async {
      await prefs.setInt('pfm_backup_cadence_mode', mode);
      await prefs.setInt('pfm_backup_custom_value', 6);
      await prefs.setString('pfm_backup_custom_unit', 'hours');
      final now = mode == 2 ? DateTime(2026, 10, 4, 23, 30) : date;
      expect(isBackupDue(prefs, entryTask: false, at: now), isFalse);
      await store.markDirty();
      expect(isBackupDue(prefs, entryTask: false, at: now), isTrue);
      expect(isBackupDue(prefs, entryTask: true, at: now), isFalse);
      await prefs.setString(backupLastSuccessKey, now.toIso8601String());
      expect(isBackupDue(prefs, entryTask: false, at: now), isFalse);
      await configureBackupSchedule(prefs, scheduler: scheduler.create());
      expect(platform.pending.keys, [cloudBackupTask]);
    });
  }

  group('committed data and persistent preference coverage', () {
    late AppDatabase db;
    late ProviderContainer container;
    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: 'w', name: 'Cash', type: 'cash', balance: const Value(10000000)));
      await db
          .into(db.wallets)
          .insert(WalletsCompanion.insert(id: 'v', name: 'Bank', type: 'bank'));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'food', name: 'Food', type: CategoryType.expense));
      await db
          .into(db.debtContacts)
          .insert(DebtContactsCompanion.insert(id: 'contact', name: 'An'));
      container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ]);
      container.read(backupChangeObserverProvider);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });
    Future<void> expectDirty() async {
      for (var i = 0; i < 100; i++) {
        if ((await store.read()).dirty) return;
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      fail('Committed mutation was not marked dirty');
    }

    Future<void> expense() =>
        db.insertTransactionWithBalanceUpdate(TransactionsCompanion.insert(
            id: 'expense',
            walletId: 'w',
            categoryId: 'food',
            amount: 200,
            type: CategoryType.expense,
            date: date));
    test('transaction create delete restore are covered', () async {
      await expense();
      await expectDirty();
      await successfulUpload();
      await db.softDeleteTransaction('expense');
      await expectDirty();
      await successfulUpload();
      await db.restoreTransaction('expense');
      await expectDirty();
    });
    test('transfer commit is covered', () async {
      await db.executeInternalTransfer(
          fromWalletId: 'w', toWalletId: 'v', amount: 300, date: date);
      await expectDirty();
    });
    test('wallet metadata default and archive writes are covered', () async {
      await db.update(db.wallets).write(const WalletsCompanion(
          name: Value('Renamed'),
          isDefault: Value(true),
          isArchived: Value(true)));
      await expectDirty();
    });
    test('wallet creation is covered without a transaction side effect',
        () async {
      await db.into(db.wallets).insert(
          WalletsCompanion.insert(id: 'new', name: 'New', type: 'ewallet'));
      await expectDirty();
    });
    test('category hierarchy and metadata writes are covered', () async {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'child',
          name: 'Child',
          type: CategoryType.expense,
          parentId: const Value('food')));
      await expectDirty();
    });
    test('recurring budget write is covered', () async {
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
          id: 'budget', categoryId: 'food', amount: 1000, periodMonth: date));
      await expectDirty();
    });
    test('project create edit delete are covered independently', () async {
      await db.createProjectBudget(
          id: 'project',
          title: 'Trip',
          tag: '#trip',
          targetAmount: 1000,
          startDate: date,
          endDate: date.add(const Duration(days: 2)));
      await expectDirty();
      await successfulUpload();
      await db.updateProjectBudget(id: 'project', title: 'Updated');
      await expectDirty();
      await successfulUpload();
      await (db.delete(db.projectBudgets)..where((p) => p.id.equals('project')))
          .go();
      await expectDirty();
    });
    test('goal create edit delete are covered without transaction effects',
        () async {
      await db.createSavingsGoal(
          id: 'goal', title: 'Savings', targetAmount: 1000);
      await expectDirty();
      await successfulUpload();
      await db.updateSavingsGoal(id: 'goal', title: 'New savings');
      await expectDirty();
      await successfulUpload();
      await (db.delete(db.savingsGoals)..where((g) => g.id.equals('goal')))
          .go();
      await expectDirty();
    });
    test('debt contact metadata write is covered', () async {
      await db.updateDebtContactMetadata(
          id: 'contact', name: 'New An', phone: '123');
      await expectDirty();
    });
    test('debt transaction commit is covered', () async {
      await db.createDebtTransaction(
          id: 'debt',
          contactId: 'contact',
          walletId: 'w',
          type: 'LEND',
          amount: 200,
          date: date);
      await expectDirty();
    });
    test('category archive and restore are covered', () async {
      await db.archiveEntity('category', 'food');
      await expectDirty();
      await successfulUpload();
      await db.restoreArchivedEntity('category', 'food');
      await expectDirty();
    });
    test('read queries do not dirty state', () async {
      await db.select(db.wallets).get();
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect((await store.read()).dirty, isFalse);
    });
    test('rollback conservatively dirties without changing persisted data',
        () async {
      await expectLater(db.transaction(() async {
        await db
            .update(db.categories)
            .write(const CategoriesCompanion(name: Value('Temporary')));
        throw StateError('abort');
      }), throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      await expectDirty();
      expect(
          (await (db.select(db.categories)..where((c) => c.id.equals('food')))
                  .getSingle())
              .name,
          'Food');
    });
    test('backup bookkeeping and notifications do not recursively dirty',
        () async {
      await successfulUpload();
      await db.into(db.appNotifications).insert(
          AppNotificationsCompanion.insert(
              id: 'reminder',
              title: 'Reminder',
              body: 'Review',
              type: 'reminder'));
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect((await store.read()).dirty, isFalse);
    });
    test('mutation during a backup is not skipped', () async {
      container.read(backupOperationProvider.notifier).state = 'Uploading';
      await expense();
      await expectDirty();
    });
    test('theme preference changes are covered', () async {
      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);
      await expectDirty();
    });
    test('classification changes are covered', () async {
      await container.read(classificationSchemesProvider.notifier).save(
          const ClassificationScheme(id: 'custom', name: 'Custom', groups: []));
      await expectDirty();
    });
    test('notification preferences are covered', () async {
      await container
          .read(notificationPreferencesProvider.notifier)
          .save(const NotificationPreferences({'evening': false}));
      await expectDirty();
    });
    test('fiscal cutoff is covered', () async {
      await container.read(dayCutoffProvider.notifier).setMinutes(240);
      await expectDirty();
    });
    test('cycle snapshot is persisted before dirty state', () async {
      container.read(cycleStartDaysByMonthProvider.notifier).state = {
        'default': 5
      };
      await expectDirty();
      expect(prefs.getString('notification_cycle_snapshot'), contains('5'));
    });
    test('profile and avatar metadata changes are covered', () async {
      final profile = await AuthProfileService()
          .updateDisplayName(UserProfile.guest(), 'An');
      await expectDirty();
      await successfulUpload();
      await AuthProfileService()
          .updateCustomAvatar(profile, type: UserAvatarType.emoji, value: 'A');
      await expectDirty();
    });
  });

  group('real performBackup attempt wrapper', () {
    late AppDatabase db;
    late ProviderContainer container;
    late NoSilentAccount google;
    Future<CloudBackupItem> Function()? upload;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      google = NoSilentAccount();
      upload = null;
      container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        cloudBackupServiceProvider.overrideWith((ref) => TestCloudService(
            db: db, ref: ref, googleSignIn: google, upload: upload)),
      ]);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });
    test('silent authentication failure is visible and never opens login',
        () async {
      await store.markDirty();
      await expectLater(
          container
              .read(cloudBackupServiceProvider)
              .performBackup(silent: true),
          throwsA(isA<BackupAuthenticationFailure>()));
      expect(google.interactiveCalls, 0);
      expect(google.silentCalls, 1);
      final status = await store.read();
      expect(status.dirty, isTrue);
      expect(status.lastAttempt, isNotNull);
      expect(status.lastFailure, isNotNull);
      expect(status.lastSuccess, isNull);
      expect(status.failureMessage, contains('đăng nhập lại'));
      expect(
          const BackupAuthenticationFailure().toString(), contains('Google'));
    });
    test('manual successful backup acknowledges dirty state', () async {
      upload = () async => CloudBackupItem(
          fileId: 'file',
          fileName: 'backup',
          sizeBytes: 100,
          createdTime: date,
          properties: const {});
      await store.markDirty();
      await container.read(cloudBackupServiceProvider).performBackup();
      expect((await store.read()).dirty, isFalse);
      expect((await store.read()).lastSuccess, date);
    });
    test('upload failure preserves success timestamp and dirty state',
        () async {
      upload =
          () async => throw StateError('Drive unavailable sensitive payload');
      await store.markDirty();
      await prefs.setString(
          backupLastSuccessKey, DateTime(2026, 9, 1).toIso8601String());
      await expectLater(
          container
              .read(cloudBackupServiceProvider)
              .performBackup(silent: true),
          throwsStateError);
      expect((await store.read()).dirty, isTrue);
      expect((await store.read()).lastSuccess, DateTime(2026, 9, 1));
      expect((await store.read()).failureMessage, isNot(contains('sensitive')));
    });
  });
}

class _SchedulerFactory {
  const _SchedulerFactory();
  BackupWorkScheduler create() => WorkmanagerBackupScheduler();
}
