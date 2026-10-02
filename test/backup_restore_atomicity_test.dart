import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/services/auth_profile_service.dart';
import 'package:pfm_app/services/backup_capsule.dart';
import 'package:pfm_app/services/cloud_backup_service.dart';
import 'package:pfm_app/services/vault_security_service.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _security(int sentinel) => {
      'algorithm': 'pbkdf2-sha256',
      'salt': base64Encode(List.filled(16, sentinel)),
      'hash': base64Encode(List.filled(32, sentinel)),
      'iterations': 120000,
      'length': 6,
      'isCustom': true,
    };

/// Simulate a storage write that commits but reports a platform failure.
/// This exercises real restore rollback without adding production hooks.
class _Storage extends MapBase<String, String> {
  final Map<String, String> data = {'unrelated_secret': 'keep'};
  String? failAfterWriting;
  int writes = 0;
  @override
  String? operator [](Object? key) => data[key];
  @override
  void operator []=(String key, String value) {
    writes++;
    data[key] = value;
    if (key == VaultSecurityService.storageKey && value == failAfterWriting) {
      failAfterWriting = null;
      throw StateError('Injected failure after security write');
    }
  }

  @override
  Iterable<String> get keys => data.keys;
  @override
  void clear() => data.clear();
  @override
  String? remove(Object? key) => data.remove(key);
}

Future<void> _seed(File file, double balance) async {
  final db = AppDatabase.forTesting(NativeDatabase(file));
  try {
    await db.into(db.wallets).insert(WalletsCompanion.insert(
        id: 'wallet',
        name: 'Sentinel wallet',
        type: 'cash',
        balance: Value(balance)));
  } finally {
    await db.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final existing = const JsonEncoder.withIndent('  ').convert(_security(1));
  final restored = jsonEncode(_security(2));
  late Directory root, docs;
  late File live, cloud;
  late SharedPreferences prefs;
  late ProviderContainer container;
  late AppDatabase liveDb;
  late _Storage storage;

  Map<String, Object?> preferenceSnapshot() => {
        for (final key in prefs.getKeys()) key: prefs.get(key),
      };

  setUp(() async {
    root = await Directory.systemTemp.createTemp('flowy-fix-e-');
    docs = await Directory('${root.path}/docs').create();
    final incoming = await Directory('${root.path}/incoming').create();
    messenger.setMockMethodCallHandler(
        pathChannel,
        (call) async => switch (call.method) {
              'getApplicationDocumentsDirectory' => docs.path,
              'getTemporaryDirectory' => root.path,
              _ => throw UnsupportedError(call.method),
            });
    SharedPreferences.setMockInitialValues({
      'has_completed_onboarding': true,
      'user_display_name': 'Local sentinel',
      'pfm_backup_cadence_mode': 3,
      'pfm_backup_dirty_revision': 'local-revision',
      'pfm_backup_uploaded_revision': 'local-receipt',
    });
    prefs = await SharedPreferences.getInstance();
    storage = _Storage();
    FlutterSecureStorage.setMockInitialValues(storage);
    live = File('${docs.path}/pfm_local_vault.sqlite');
    cloud = File('${incoming.path}/pfm_local_vault.sqlite');
    await _seed(live, 123);
    await _seed(cloud, 999);
    liveDb = AppDatabase.forTesting(NativeDatabase(live));
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(liveDb),
    ]);
    // Settle the same profile lifecycle used by the restore UI before snapshotting.
    container.read(userProfileNotifierProvider);
    while (container.read(userProfileNotifierProvider).isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await liveDb.select(liveDb.wallets).get();
  });

  tearDown(() async {
    container.dispose();
    await liveDb.close();
    messenger.setMockMethodCallHandler(pathChannel, null);
    await root.delete(recursive: true);
  });

  test('cold security snapshot is read-only and preserves a legacy PIN file',
      () async {
    final legacy = File('${docs.path}/vault_security_config.json');
    const legacyBytes = '{"pin":"654321","isCustom":true}';
    await legacy.writeAsString(legacyBytes);
    final beforePrefs = preferenceSnapshot();
    final beforeSecurity = Map<String, String>.from(storage);
    final snapshot = await VaultSecurityService().snapshotPersistedState();
    expect(snapshot, {'snapshotVersion': 1, 'secureStorageValue': null});
    expect(storage, beforeSecurity);
    expect(storage.writes, 0);
    expect(await legacy.readAsString(), legacyBytes);
    expect(preferenceSnapshot(), beforePrefs);
  });

  for (final configured in [false, true]) {
    test(
        '${configured ? 'existing' : 'cold'}Security_failedRestore_preservesDbPreferencesAndSecurity',
        () async {
      if (configured) storage.data[VaultSecurityService.storageKey] = existing;
      final diff = inspectReconciliation(live.path, cloud.path);
      // A genuine committed local change makes the UI's earlier diff stale.
      await (liveDb.update(liveDb.wallets)..where((w) => w.id.equals('wallet')))
          .write(
              const WalletsCompanion(name: Value('Changed after inspection')));
      final beforeDb = ledgerFingerprint(live.path);
      final beforePrefs = preferenceSnapshot();
      final beforeSecurity = Map<String, String>.from(storage);
      await expectLater(
          container
              .read(cloudBackupServiceProvider)
              .restorePreparedBackup(cloud, reconciliation: diff),
          throwsA(isA<StateError>().having((e) => e.message, 'guard',
              contains('Dữ liệu trên máy đã thay đổi'))));
      expect(ledgerFingerprint(live.path), beforeDb);
      expect(preferenceSnapshot(), beforePrefs);
      expect(storage, beforeSecurity);
      expect(storage.writes, 0);
      expect(Directory('${docs.path}/restore_recovery').existsSync(), false);
      expect(cloud.parent.listSync().where((f) => f.path.contains('staged_')),
          isEmpty);
    });
  }

  test('successfulRestore_appliesSecurityAsBefore', () async {
    await File('${cloud.parent.path}/security_manifest.json')
        .writeAsString(restored);
    await container
        .read(cloudBackupServiceProvider)
        .restorePreparedBackup(cloud);
    expect(storage[VaultSecurityService.storageKey], restored);
    expect(ledgerFingerprint(live.path), ledgerFingerprint(cloud.path));
    expect(prefs.getBool('flowy_restored_private'), isTrue);
    expect(storage['unrelated_secret'], 'keep');
  });

  for (final configured in [false, true]) {
    test(
        'failureAfterSecurityApply_rollsBackTo${configured ? 'ExactExistingBytes' : 'AbsentState'}',
        () async {
      if (configured) storage.data[VaultSecurityService.storageKey] = existing;
      await File('${cloud.parent.path}/security_manifest.json')
          .writeAsString(restored);
      await File('${cloud.parent.path}/preferences_manifest.json')
          .writeAsString(jsonEncode({
        'user_display_name': 'Cloud name',
        'pfm_backup_cadence_mode': 3
      }));
      final beforeDb = ledgerFingerprint(live.path);
      final beforePrefs = preferenceSnapshot();
      final beforeSecurity = Map<String, String>.from(storage);
      storage.failAfterWriting = restored;
      await expectLater(
          container
              .read(cloudBackupServiceProvider)
              .restorePreparedBackup(cloud),
          throwsA(isA<StateError>().having((e) => e.message, 'injected fault',
              'Injected failure after security write')));
      await prefs.reload();
      expect(ledgerFingerprint(live.path), beforeDb);
      expect(preferenceSnapshot(), beforePrefs);
      expect(storage, beforeSecurity);
      expect(storage.failAfterWriting,
          isNull); // The restored config was actually written.
      final journal = jsonDecode(
          await File('${docs.path}/restore_recovery/security_manifest.json')
              .readAsString());
      expect(journal, {
        'snapshotVersion': 1,
        'secureStorageValue': configured ? existing : null
      });
      expect(File('${docs.path}/restore_recovery/pending').existsSync(), false);
    });
  }

  for (final prior in ['absent', 'configured', 'legacy-journal']) {
    test('interruptedRestore_recoversSecurity_$prior', () async {
      if (prior != 'absent') {
        storage.data[VaultSecurityService.storageKey] = existing;
      }
      final beforeDb = ledgerFingerprint(live.path);
      final beforePrefs = preferenceSnapshot();
      final snapshot = prior == 'legacy-journal'
          ? _security(1)
          : await VaultSecurityService().snapshotPersistedState();
      final journal = await Directory('${docs.path}/restore_recovery').create();
      await liveDb.customStatement(
          'VACUUM INTO ?', ['${journal.path}/pfm_local_vault.sqlite']);
      await File('${journal.path}/preferences_manifest.json')
          .writeAsString(jsonEncode(await exportBackupPreferences(prefs)));
      await File('${journal.path}/security_manifest.json')
          .writeAsString(jsonEncode(snapshot));
      await File('${journal.path}/pending').writeAsString('installing');
      await liveDb.close();
      await cloud.copy(live.path);
      await prefs.setString(
          'user_display_name', 'Partially applied Cloud name');
      await VaultSecurityService.restoreManifest(_security(2));
      await recoverInterruptedRestore(docs.path, prefs);
      expect(ledgerFingerprint(live.path), beforeDb);
      expect(preferenceSnapshot(), beforePrefs);
      expect(
          storage[VaultSecurityService.storageKey],
          prior == 'absent'
              ? isNull
              : prior == 'legacy-journal'
                  ? jsonEncode(_security(1))
                  : existing);
      expect(storage['unrelated_secret'], 'keep');
      expect(File('${journal.path}/pending').existsSync(), false);
    });
  }

  test('normalVaultInitialization_stillCreatesAndVerifiesDefaultPin', () async {
    final service = VaultSecurityService();
    await service.init();
    expect(storage[VaultSecurityService.storageKey], isNotNull);
    expect(await service.verifyPin('1234'), isTrue);
    expect(await service.verifyPin('4321'), isFalse);
  });
}
