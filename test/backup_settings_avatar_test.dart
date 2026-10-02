import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pfm_app/services/auth_profile_service.dart';
import 'package:pfm_app/services/avatar_storage.dart';
import 'package:pfm_app/services/backup_capsule.dart';
import 'package:pfm_app/services/backup_schedule.dart';
import 'package:pfm_app/services/backup_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class _Scheduler implements BackupWorkScheduler {
  final Map<String, Constraints> pending = {};
  int registrations = 0;
  @override
  Future<void> cancel(String name) async => pending.remove(name);
  @override
  Future<void> entry(Constraints constraints) async {
    registrations++;
    pending[cloudEntryBackupTask] = constraints;
  }

  @override
  Future<void> periodic(Constraints constraints) async {
    registrations++;
    pending[cloudBackupTask] = constraints;
  }
}

const _configuration = <String, Object>{
  'pfm_backup_cadence_mode': 4,
  'pfm_backup_custom_unit': 'weeks',
  'pfm_backup_custom_value': 2,
  'pfm_backup_wifi_only': true,
  'pfm_backup_battery_safe': true,
};
const _runtimeKeys = <String>[
  backupDirtyRevisionKey,
  backupUploadedRevisionKey,
  backupDirtySinceKey,
  backupLastAttemptKey,
  backupLastFailureKey,
  backupLastFailureMessageKey,
  backupLastSuccessKey,
];
const _initialProfile = UserProfile(
  displayName: 'An',
  avatarType: UserAvatarType.initials,
  avatarValue: 'A',
  avatarColorHex: '#10B981',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final imageA = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aC1sAAAAASUVORK5CYII=');
  final imageB = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');
  late Directory root, docs, cache;
  late SharedPreferences prefs;
  late _Scheduler scheduler;
  late AuthProfileService profileService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    scheduler = _Scheduler();
    profileService = AuthProfileService();
    root = await Directory.systemTemp.createTemp('flowy-fix-c-');
    docs = await Directory(p.join(root.path, 'documents')).create();
    cache = await Directory(p.join(root.path, 'cache')).create();
    messenger.setMockMethodCallHandler(channel, (call) async {
      return switch (call.method) {
        'getApplicationDocumentsDirectory' => docs.path,
        'getTemporaryDirectory' => cache.path,
        _ => null,
      };
    });
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await root.delete(recursive: true);
  });

  Future<UserProfile> select(List<int> bytes, String name) async {
    final source = await File(p.join(cache.path, name)).writeAsBytes(bytes);
    return profileService.updateCustomAvatar(_initialProfile,
        type: UserAvatarType.customImage, value: source.path);
  }

  void expectOwned(UserProfile profile, List<int> bytes) {
    expect(profile.avatarType, UserAvatarType.customImage);
    expect(p.isWithin(docs.path, profile.avatarValue), isTrue);
    expect(p.basename(profile.avatarValue),
        matches(r'^avatar_[a-f0-9]{64}\.img$'));
    expect(File(profile.avatarValue).readAsBytesSync(), bytes);
  }

  test('backupPreferences_roundTripsTypedCadenceConfiguration', () async {
    SharedPreferences.setMockInitialValues(_configuration);
    prefs = await SharedPreferences.getInstance();
    final exported = await exportBackupPreferences(prefs);
    expect(exported, _configuration);
    SharedPreferences.setMockInitialValues({
      'pfm_backup_cadence_mode': 1,
      'pfm_backup_custom_unit': 'hours',
      'pfm_backup_custom_value': 6,
      'pfm_backup_wifi_only': false,
      'pfm_backup_battery_safe': false,
    });
    prefs = await SharedPreferences.getInstance();
    await applyBackupPreferences(prefs, exported, scheduler: scheduler);
    for (final entry in _configuration.entries) {
      expect(prefs.get(entry.key), entry.value);
      expect(prefs.get(entry.key).runtimeType, entry.value.runtimeType);
    }
  });

  test('backupPreferences_doesNotExportOrRestoreRuntimeAndIdentity', () async {
    SharedPreferences.setMockInitialValues({
      ..._configuration,
      for (final key in _runtimeKeys) key: 'source-$key',
      'user_email': 'source@example.invalid',
      'has_completed_onboarding': true,
      'flowy_restored_private': true,
      'vault_pin': 'source-secret',
    });
    prefs = await SharedPreferences.getInstance();
    final exported = await exportBackupPreferences(prefs);
    expect(exported.keys.toSet(), _configuration.keys.toSet());
    final local = <String, Object>{
      for (final key in _runtimeKeys) key: 'target-$key',
      'user_email': 'target@example.invalid',
      'has_completed_onboarding': false,
      'flowy_restored_private': false,
      'vault_pin': 'target-secret',
    };
    SharedPreferences.setMockInitialValues(local);
    prefs = await SharedPreferences.getInstance();
    await applyBackupPreferences(prefs, exported, scheduler: scheduler);
    for (final entry in local.entries) {
      expect(prefs.get(entry.key), entry.value);
    }
  });

  for (final key in _runtimeKeys) {
    test('backupPreferences_rejectsRuntimeInjection_$key', () async {
      await prefs.setString(key, 'local');
      await expectLater(
        applyBackupPreferences(prefs, {key: 'source'}, scheduler: scheduler),
        throwsFormatException,
      );
      expect(prefs.getString(key), 'local');
      expect(scheduler.registrations, 0);
    });
  }

  test('legacyBackup_withoutNewPreferenceKeysRetainsLocalConfiguration',
      () async {
    SharedPreferences.setMockInitialValues(_configuration);
    prefs = await SharedPreferences.getInstance();
    await applyBackupPreferences(prefs, {'user_display_name': 'Restored'},
        scheduler: scheduler);
    for (final entry in _configuration.entries) {
      expect(prefs.get(entry.key), entry.value);
    }
    expect(prefs.getString('user_display_name'), 'Restored');
  });

  test('legacyBackup_missingConfigurationUsesExistingDefaults', () async {
    await applyBackupPreferences(prefs, {}, scheduler: scheduler);
    expect(prefs.getInt('pfm_backup_cadence_mode'), isNull);
    expect(scheduler.pending.containsKey(cloudBackupTask), isTrue);
    final constraints = scheduler.pending[cloudBackupTask]!;
    expect(constraints.networkType, NetworkType.unmetered);
    expect(constraints.requiresBatteryNotLow, isTrue);
  });

  for (final mode in [1, 2, 4]) {
    test('restoredCadence_reconfiguresPeriodicScheduler_mode$mode', () async {
      await prefs.setInt('pfm_backup_cadence_mode', 0);
      await markBackupDirty(prefs, scheduler: scheduler);
      expect(scheduler.pending.containsKey(cloudEntryBackupTask), isTrue);
      await applyBackupPreferences(
          prefs,
          {
            ..._configuration,
            'pfm_backup_cadence_mode': mode,
            'pfm_backup_wifi_only': false,
            'pfm_backup_battery_safe': false,
          },
          scheduler: scheduler);
      expect(scheduler.pending.keys, [cloudBackupTask]);
      final constraints = scheduler.pending[cloudBackupTask]!;
      expect(constraints.networkType, NetworkType.connected);
      expect(constraints.requiresBatteryNotLow, isFalse);
      expect(prefs.getInt('pfm_backup_cadence_mode'), mode);
    });
  }

  test('restoredEntry_refreshesConstraintsWithoutChangingDirtyRevision',
      () async {
    await prefs.setInt('pfm_backup_cadence_mode', 0);
    await markBackupDirty(prefs, scheduler: scheduler);
    final revision = prefs.getString(backupDirtyRevisionKey);
    await applyBackupPreferences(
        prefs,
        {
          ..._configuration,
          'pfm_backup_cadence_mode': 0,
          'pfm_backup_wifi_only': false,
        },
        scheduler: scheduler);
    expect(scheduler.pending.keys, [cloudEntryBackupTask]);
    expect(scheduler.pending[cloudEntryBackupTask]!.networkType,
        NetworkType.connected);
    expect(prefs.getString(backupDirtyRevisionKey), revision);
  });

  test('manualOnlyRestore_cancelsAutomaticWorkButKeepsManualBackupAvailable',
      () async {
    await prefs.setInt('pfm_backup_cadence_mode', 0);
    await markBackupDirty(prefs, scheduler: scheduler);
    await scheduler.periodic(Constraints(networkType: NetworkType.connected));
    await applyBackupPreferences(
        prefs, {..._configuration, 'pfm_backup_cadence_mode': 3},
        scheduler: scheduler);
    expect(prefs.getInt('pfm_backup_cadence_mode'), 3);
    expect(scheduler.pending, isEmpty);
    expect(isBackupDue(prefs, entryTask: true), isFalse);
    expect(isBackupDue(prefs, entryTask: false), isFalse);
    var uploaded = false;
    await runBackupAttempt(BackupStateStore(prefs), () async {
      uploaded = true;
      return DateTime(2026, 10, 2);
    }, uploadedAt: (result) => result);
    expect(uploaded, isTrue);
    expect((await BackupStateStore(prefs).read()).dirty, isFalse);
  });

  test('restorePreferences_doesNotCreateDirtyLoop', () async {
    final entry = {..._configuration, 'pfm_backup_cadence_mode': 0};
    for (var i = 0; i < 3; i++) {
      await applyBackupPreferences(prefs, entry, scheduler: scheduler);
      await recoverPendingBackup(prefs, scheduler: scheduler);
      await exportBackupPreferences(prefs);
    }
    expect(prefs.getString(backupDirtyRevisionKey), isNull);
    expect(scheduler.pending, isEmpty);
    expect(scheduler.registrations, 0);
  });

  test('backupPreferences_rejectsWrongTypesBeforeAnyWrite', () async {
    for (final entry in _configuration.entries) {
      final wrong = entry.value is String ? 1 : '${entry.value}';
      await expectLater(
        applyBackupPreferences(prefs, {..._configuration, entry.key: wrong},
            scheduler: scheduler),
        throwsFormatException,
      );
      expect(prefs.getKeys(), isEmpty);
    }
  });

  test('avatarSelection_copiesIntoDurableStorageBeforePublishing', () async {
    final profile = await select(imageA, 'picker.png');
    expectOwned(profile, imageA);
    expect(profile.avatarValue, isNot(p.join(cache.path, 'picker.png')));
    expect(prefs.getString('user_avatar_value'), profile.avatarValue);
    expect((await BackupStateStore(prefs).read()).dirty, isTrue);
  });

  test('avatarBackup_survivesOriginalCacheDeletionAndRestoresOnAnotherDevice',
      () async {
    final profile = await select(imageA, 'picker.png');
    await File(p.join(cache.path, 'picker.png')).delete();
    expectOwned(await profileService.loadProfile(), imageA);
    final exported = await exportBackupPreferences(prefs);
    expect(
        base64Decode(exported['user_avatar_image_base64'] as String), imageA);
    expect(exported.containsKey('user_avatar_value'), isFalse);
    expect(jsonEncode(exported), isNot(contains(root.path)));

    docs = await Directory(p.join(root.path, 'destination-documents')).create();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await applyBackupPreferences(prefs, exported, scheduler: scheduler);
    final restored = await profileService.loadProfile();
    expectOwned(restored, imageA);
    expect(restored.avatarValue, isNot(profile.avatarValue));
    await cache.delete(recursive: true);
    expectOwned(await profileService.loadProfile(), imageA);
    expect(prefs.getString(backupDirtyRevisionKey), isNull);
    final reexported = await exportBackupPreferences(prefs);
    expect(reexported['user_avatar_image_base64'],
        exported['user_avatar_image_base64']);
  });

  test('legacyReadableCacheAvatar_isMigratedOnceAndKeepsProfile', () async {
    final source =
        await File(p.join(cache.path, 'legacy.png')).writeAsBytes(imageA);
    await prefs.setString('user_display_name', 'Restored name');
    await prefs.setString('user_email', 'local@example.invalid');
    await prefs.setString('user_avatar_type', 'customImage');
    await prefs.setString('user_avatar_value', source.path);
    final migrated = await profileService.loadProfile();
    expectOwned(migrated, imageA);
    expect(migrated.displayName, 'Restored name');
    expect(migrated.email, 'local@example.invalid');
    expect(prefs.getString('user_avatar_value'), migrated.avatarValue);
    final modified = await File(migrated.avatarValue).lastModified();
    final revision = prefs.getString(backupDirtyRevisionKey);
    await source.delete();
    expectOwned(await profileService.loadProfile(), imageA);
    expect(await File(migrated.avatarValue).lastModified(), modified);
    expect(prefs.getString(backupDirtyRevisionKey), revision);
    expect(await docs.list().length, 1);
  });

  test('missingLegacyCacheAvatar_fallsBackSafelyWithoutLosingProfile',
      () async {
    await prefs.setString('user_display_name', 'An');
    await prefs.setString('user_email', 'local@example.invalid');
    await prefs.setString('user_avatar_type', 'customImage');
    await prefs.setString('user_avatar_value', p.join(cache.path, 'gone.png'));
    final profile = await profileService.loadProfile();
    expect(profile.avatarType, UserAvatarType.initials);
    expect(profile.avatarValue, 'A');
    expect(profile.displayName, 'An');
    expect(profile.email, 'local@example.invalid');
    final exported = await exportBackupPreferences(prefs);
    expect(exported['user_avatar_type'], 'initials');
    expect(exported.containsKey('user_avatar_image_base64'), isFalse);
  });

  test('legacyBackup_withoutAvatarBytesNeverTrustsSourceDevicePath', () async {
    final source =
        await File(p.join(cache.path, 'external.png')).writeAsBytes(imageA);
    await applyBackupPreferences(
        prefs,
        {
          'user_display_name': 'An',
          'user_avatar_type': 'customImage',
          'user_avatar_value': source.path,
        },
        scheduler: scheduler);
    expect(prefs.getString('user_avatar_type'), 'initials');
    expect(prefs.getString('user_avatar_value'), '');
    expect(await docs.list().length, 0);
    expect(await source.exists(), isTrue);
  });

  test('avatarReplacement_exportsNewestAvatarAndRemovalOmitsStaleBytes',
      () async {
    final a = await select(imageA, 'a.png');
    final b = await select(imageB, 'b.png');
    expectOwned(b, imageB);
    expect(b.avatarValue, isNot(a.avatarValue));
    expect(
        base64Decode(
            (await exportBackupPreferences(prefs))['user_avatar_image_base64']
                as String),
        imageB);
    await profileService.updateCustomAvatar(b,
        type: UserAvatarType.initials, value: 'A');
    final removed = await exportBackupPreferences(prefs);
    expect(removed['user_avatar_type'], 'initials');
    expect(removed.containsKey('user_avatar_image_base64'), isFalse);
    expect(await File(a.avatarValue).exists(), isTrue);
    expect(await File(b.avatarValue).exists(), isTrue);
  });

  test('oversizedAvatarSelection_retainsPreviousCanonicalAvatar', () async {
    final previous = await select(imageA, 'a.png');
    final source = await File(p.join(cache.path, 'oversized.png'))
        .writeAsBytes(List.filled(maxAvatarBytes + 1, 1));
    await expectLater(
      profileService.updateCustomAvatar(previous,
          type: UserAvatarType.customImage, value: source.path),
      throwsStateError,
    );
    expect(prefs.getString('user_avatar_value'), previous.avatarValue);
    expectOwned(await profileService.loadProfile(), imageA);
  });

  test('avatarCopyFailure_retainsPreviousProfileAndCanonicalPath', () async {
    final previous = await select(imageA, 'a.png');
    final source = await File(p.join(cache.path, 'b.png')).writeAsBytes(imageB);
    docs = Directory(
        (await File(p.join(root.path, 'not-a-directory')).writeAsString('x'))
            .path);
    await expectLater(
      profileService.updateCustomAvatar(previous,
          type: UserAvatarType.customImage, value: source.path),
      throwsStateError,
    );
    expect(prefs.getString('user_avatar_value'), previous.avatarValue);
    expect(File(previous.avatarValue).readAsBytesSync(), imageA);
  });

  test('identicalAvatarImport_reusesOwnedContentWithoutTemporaryFiles',
      () async {
    final a = await select(imageA, 'a.png');
    final b = await select(imageA, 'b.png');
    expect(b.avatarValue, a.avatarValue);
    expect(await docs.list().length, 1);
    expect(
        await docs.list().any((file) => file.path.endsWith('.tmp')), isFalse);
  });
}
