import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/services/auth_profile_service.dart';
import 'package:pfm_app/services/backup_account_key.dart';
import 'package:pfm_app/services/backup_capsule.dart';
import 'package:pfm_app/services/backup_crypto.dart';
import 'package:pfm_app/services/backup_state.dart';
import 'package:pfm_app/services/cloud_backup_service.dart';
import 'package:pfm_app/services/vault_security_service.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

// Frozen pre-Fix-D V1 writer: exact original HMAC pepper/account key and
// encrypt 5.0.3 AES-GCM layout. Deliberately independent of production crypto.
List<int> _legacyFixture(List<int> zip, String account) {
  final key = Hmac(sha256, utf8.encode('flowy_secure_vault_salt_2026_@#\$'))
      .convert(utf8.encode(account.trim()))
      .bytes;
  final iv = enc.IV(Uint8List.fromList(List.generate(16, (i) => i)));
  final crypt = enc.Encrypter(
      enc.AES(enc.Key(Uint8List.fromList(key)), mode: enc.AESMode.gcm));
  return [...iv.bytes, ...crypt.encryptBytes(zip, iv: iv).bytes];
}

Matcher _error(BackupCryptoError code) =>
    isA<BackupCryptoFailure>().having((e) => e.code, 'code', code);

class _Remote implements BackupKeyRemote {
  final records = <String, String>{};
  final referenced = <String>{};
  int creates = 0;
  int lists = 0, reads = 0, historyScans = 0;
  final readIds = <String>[];
  bool failRead = false;
  bool competingCreation = false;
  @override
  Future<List<String>> listRecords() async {
    lists++;
    return records.keys.toList();
  }

  @override
  Future<String> readRecord(String fileId) async {
    reads++;
    readIds.add(fileId);
    if (failRead) throw StateError('Network unavailable');
    final record = records[fileId];
    if (record == null) {
      throw const BackupCryptoFailure(BackupCryptoError.missingKey);
    }
    return record;
  }

  @override
  Future<Set<String>> referencedKeyIds() async {
    historyScans++;
    return referenced;
  }

  void resetCounts() {
    lists = reads = historyScans = creates = 0;
    readIds.clear();
  }

  @override
  Future<String> createRecord(BackupMasterKey key) async {
    creates++;
    records[key.id] = key.encodeRecord();
    if (competingCreation) {
      final other = BackupMasterKey.generate();
      records[other.id] = other.encodeRecord();
    }
    return key.id;
  }
}

class _Account implements GoogleSignInAccount {
  @override
  final String id;
  _Account(this.id);
  @override
  String get email => '$id@example.invalid';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Google extends GoogleSignIn {
  @override
  GoogleSignInAccount? currentUser;
  int interactive = 0;
  _Google(String account) : currentUser = _Account(account);
  @override
  Future<GoogleSignInAccount?> signIn() async {
    interactive++;
    return currentUser;
  }

  @override
  Future<GoogleSignInAccount?> signInSilently(
          {bool suppressErrors = true, bool reAuthenticate = false}) async =>
      currentUser;
  @override
  Future<GoogleSignInAccount?> signOut() async {
    currentUser = null;
    return null;
  }

  @override
  Future<bool> isSignedIn() async => currentUser != null;
}

class _Drive implements drive.DriveApi {
  @override
  final _Files files = _Files();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Exercise the real DriveBackupKeyRemote adapter, including appData queries,
// pagination, separate key records and backup upload/download bytes.
class _Files implements drive.FilesResource {
  final metadata = <String, drive.File>{};
  final contents = <String, List<int>>{};
  bool failBackupUpload = false;
  int serial = 0;
  int keyLists = 0, historyLists = 0, keyGets = 0, backupGets = 0;
  final mediaIds = <String>[];
  void resetCounts() {
    keyLists = historyLists = keyGets = backupGets = 0;
    mediaIds.clear();
  }

  String add(String name, List<int> bytes, {Map<String, String>? properties}) {
    final id = 'file-${serial++}';
    metadata[id] = drive.File()
      ..id = id
      ..name = name
      ..size = '${bytes.length}'
      ..createdTime = DateTime.utc(2026, 10, 2)
      ..properties = properties;
    contents[id] = List.from(bytes);
    return id;
  }

  @override
  dynamic noSuchMethod(Invocation call) {
    if (call.memberName == #list) return _list(call);
    if (call.memberName == #get) return _get(call);
    if (call.memberName == #create) return _create(call);
    return super.noSuchMethod(call);
  }

  Future<drive.FileList> _list(Invocation call) async {
    expect(call.namedArguments[#spaces], 'appDataFolder');
    final query = call.namedArguments[#q] as String;
    final keyQuery = query.contains('flowy_backup_key_');
    if (keyQuery) {
      keyLists++;
    } else {
      historyLists++;
    }
    final matches = metadata.values
        .where((f) => f.name!
            .startsWith(keyQuery ? 'flowy_backup_key_' : 'pfm_vault_backup_'))
        .toList();
    final start = int.parse(call.namedArguments[#pageToken] as String? ?? '0');
    // Small pages force key management to prove it reads all remote records.
    final result = drive.FileList()
      ..files = matches.skip(start).take(2).toList();
    if (start + 2 < matches.length) result.nextPageToken = '${start + 2}';
    return result;
  }

  Future<Object> _get(Invocation call) async {
    final id = call.positionalArguments.single as String;
    final meta = metadata[id];
    if (meta == null) {
      throw drive.DetailedApiRequestError(404, 'File not found');
    }
    if (call.namedArguments[#downloadOptions] !=
        drive.DownloadOptions.fullMedia) {
      return meta;
    }
    mediaIds.add(id);
    if (meta.name!.startsWith('flowy_backup_key_')) {
      keyGets++;
    } else {
      backupGets++;
    }
    final bytes = contents[id]!;
    return drive.Media(Stream.value(bytes), bytes.length);
  }

  Future<drive.File> _create(Invocation call) async {
    final meta = call.positionalArguments.single as drive.File;
    expect(meta.parents, ['appDataFolder']);
    if (failBackupUpload && meta.name!.startsWith('pfm_vault_backup_')) {
      throw StateError('Upload failed');
    }
    final media = call.namedArguments[#uploadMedia] as drive.Media;
    final bytes = await media.stream.expand((chunk) => chunk).toList();
    final id = add(meta.name!, bytes,
        properties: meta.properties?.cast<String, String>());
    return metadata[id]!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('V2 authenticated envelope', () {
    final plain = utf8.encode('Flowy financial backup fixture');
    late BackupMasterKey key;
    late Uint8List encrypted;
    setUp(() {
      key = BackupMasterKey.generate();
      encrypted = encryptBackupV2(plain, key, 'A');
    });

    test('same plaintext differs; both round trips preserve bytes', () {
      final second = encryptBackupV2(plain, key, 'A');
      expect(encrypted, isNot(second));
      expect(encrypted.sublist(43, 75), isNot(second.sublist(43, 75)));
      expect(encrypted.sublist(75, backupV2HeaderSize),
          isNot(second.sublist(75, backupV2HeaderSize)));
      expect(backupEnvelopeKeyId(encrypted), key.id);
      for (final bytes in [encrypted, second]) {
        expect(
            decryptBackupEnvelope(bytes, accountId: 'A', master: key), plain);
        expect(bytes.sublist(43, 75), hasLength(32));
        expect(bytes.sublist(75, backupV2HeaderSize), hasLength(12));
      }
    });
    test('public account data cannot derive V2 key', () {
      expect(() => decryptBackupEnvelope(encrypted, accountId: 'A'),
          throwsA(_error(BackupCryptoError.missingKey)));
      final publicDerived =
          Hmac(sha256, utf8.encode('flowy_secure_vault_salt_2026_@#\$'))
              .convert(utf8.encode('A'))
              .bytes;
      expect(
          () => decryptBackupEnvelope(encrypted,
              accountId: 'A', master: BackupMasterKey(publicDerived)),
          throwsA(_error(BackupCryptoError.authentication)));
      expect(base64Encode(encrypted), isNot(contains(base64Encode(key.bytes))));
    });
    test('wrong account or independent key fails', () {
      expect(
          () => decryptBackupEnvelope(encrypted, accountId: 'B', master: key),
          throwsA(_error(BackupCryptoError.authentication)));
      expect(
          () => decryptBackupEnvelope(encrypted,
              accountId: 'A', master: BackupMasterKey.generate()),
          throwsA(_error(BackupCryptoError.authentication)));
    });
    for (final entry in {
      'magic': 0,
      'version': 8,
      'algorithm': 9,
      'kdf': 10,
      'key ID': 11,
      'salt': 43,
      'nonce': 75,
      'ciphertext': 87,
      'tag': -1
    }.entries) {
      test('${entry.key} tamper fails closed without legacy fallback', () {
        final modified = Uint8List.fromList(encrypted);
        modified[entry.value < 0 ? modified.length - 1 : entry.value] ^= 1;
        expect(
            () => decryptBackupEnvelope(modified, accountId: 'A', master: key),
            throwsA(isA<BackupCryptoFailure>()));
      });
    }
    test('truncated and malformed envelopes fail safely', () {
      for (final length in [
        0,
        1,
        8,
        9,
        16,
        31,
        32,
        86,
        87,
        102,
        encrypted.length - 1
      ]) {
        expect(
            () => decryptBackupEnvelope(encrypted.sublist(0, length),
                accountId: 'A', master: key),
            throwsA(isA<BackupCryptoFailure>()));
      }
      final future = Uint8List.fromList(encrypted)..[8] = 255;
      expect(() => decryptBackupEnvelope(future, accountId: 'A', master: key),
          throwsA(_error(BackupCryptoError.unsupported)));
    });
    test(
        'frozen V1 legacy derivation/layout still decrypts and rejects wrong account',
        () {
      final legacy = _legacyFixture(plain, 'A');
      expect(backupEnvelopeKeyId(legacy), isNull);
      expect(decryptBackupEnvelope(legacy, accountId: 'A'), plain);
      expect(() => decryptBackupEnvelope(legacy, accountId: 'B'),
          throwsA(_error(BackupCryptoError.authentication)));
    });
  });

  group('Portable master keys', () {
    late _Remote remote;
    setUp(() {
      remote = _Remote();
    });
    test(
        'first initialization and concurrent callers reuse one confirmed remote record',
        () async {
      final keys = await Future.wait(
          List.generate(8, (_) => AccountBackupKeys('A', remote).forBackup()));
      expect(remote.creates, 1);
      expect(keys.map((k) => k.id).toSet(), hasLength(1));
      expect(
          (await AccountBackupKeys('A', remote).forBackup()).id, keys.first.id);
      expect(remote.creates, 1);
    });
    test('cross-device first creation retains both immutable generations',
        () async {
      remote.competingCreation = true;
      final canonical = await AccountBackupKeys('A', remote).forBackup();
      expect(remote.records, hasLength(2));
      expect(remote.records.keys, contains(canonical.id));
      for (final id in remote.records.keys) {
        expect((await AccountBackupKeys('A', remote).forRestore(id)).id, id);
      }
    });
    test(
        'account separation, missing local cache fetch and logout keep remote material',
        () async {
      final other = _Remote();
      final a = await AccountBackupKeys('A', remote).forBackup();
      final b = await AccountBackupKeys('B', other).forBackup();
      expect(a.id, isNot(b.id));
      expect((await const FlutterSecureStorage().readAll()).length, 2);
      await clearBackupKeyCache();
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
      final aRecovered = await AccountBackupKeys('A', remote).forRestore(a.id);
      final encrypted = encryptBackupV2([1, 2, 3], a, 'A');
      expect(
          decryptBackupEnvelope(encrypted, accountId: 'A', master: aRecovered),
          [1, 2, 3]);
      expect(() => decryptBackupEnvelope(encrypted, accountId: 'B', master: b),
          throwsA(isA<BackupCryptoFailure>()));
      expect(remote.creates, 1);
    });
    test(
        'existing V2 missing remote key refuses replacement despite local cache',
        () async {
      final key = await AccountBackupKeys('A', remote).forBackup();
      remote.referenced.add(key.id);
      remote.records.clear();
      await expectLater(AccountBackupKeys('A', remote).forBackup(),
          throwsA(_error(BackupCryptoError.missingKey)));
      await expectLater(AccountBackupKeys('A', remote).forRestore(key.id),
          throwsA(_error(BackupCryptoError.missingKey)));
      expect(remote.creates, 1);
    });
    for (final record in [
      'not json',
      '{"version":9}',
      '{"version":1,"secret":"AAAA","keyId":"bad"}',
      '{"version":1,"secret":"***"}'
    ]) {
      test('malformed/unsupported record fails closed: $record', () async {
        remote.records['record'] = record;
        await expectLater(AccountBackupKeys('A', remote).forBackup(),
            throwsA(isA<BackupCryptoFailure>()));
        expect(remote.creates, 0);
      });
    }
    test('valid-length secret corruption is caught by content generation ID',
        () async {
      final key = BackupMasterKey.generate();
      final record = jsonDecode(key.encodeRecord()) as Map<String, dynamic>;
      record['secret'] = base64Encode(List.filled(32, 1));
      remote.records['record'] = jsonEncode(record);
      await expectLater(AccountBackupKeys('A', remote).forBackup(),
          throwsA(_error(BackupCryptoError.corruptKey)));
    });
    test(
        'Drive adapter paginates and detects V2 without metadata before creating keys',
        () async {
      final api = _Drive();
      for (var i = 0; i < 4; i++) {
        api.files
            .add('pfm_vault_backup_legacy$i.enc', _legacyFixture([1, 2], 'A'));
      }
      api.files.add('pfm_vault_backup_v2.enc',
          encryptBackupV2([3], BackupMasterKey.generate(), 'A'));
      await expectLater(
          AccountBackupKeys('A', DriveBackupKeyRemote(api)).forBackup(),
          throwsA(_error(BackupCryptoError.missingKey)));
      expect(
          api.files.metadata.values
              .where((f) => f.name!.startsWith('flowy_backup_key_')),
          isEmpty);
    });
  });

  group('Steady-state key resolution', () {
    const secure = FlutterSecureStorage();
    String activeSlot(String account) =>
        'flowy_backup_v2_key_${sha256.convert(utf8.encode(account))}_active';
    Future<Map<String, dynamic>> activeData(String account) async =>
        jsonDecode((await secure.read(key: activeSlot(account)))!)
            as Map<String, dynamic>;
    late _Remote remote;
    setUp(() => remote = _Remote());

    test('existingKey_firstInitialization_canUseDiscoveryPath', () async {
      final key = BackupMasterKey.generate();
      remote.records['immutable-file'] = key.encodeRecord();
      remote.referenced.add(key.id);
      expect((await AccountBackupKeys('A', remote).forBackup()).id, key.id);
      expect(remote.lists, 1);
      expect(remote.reads, 1);
      expect(remote.historyScans, 1);
      expect(remote.creates, 0);
      final cached = await activeData('A');
      expect(cached['fileId'], 'immutable-file');
      expect(cached['generation'], key.id);
      expect(
          BackupMasterKey.decodeRecord(cached['record'] as String).id, key.id);
    });

    test('existingKey_secondBackup_remoteCallsAreO1_withoutHistoricalScan',
        () async {
      final first = await AccountBackupKeys('A', remote).forBackup();
      remote.resetCounts();
      // A new resolver instance models the absence of a completed in-memory cache.
      final second = await AccountBackupKeys('A', remote).forBackup();
      expect(second.id, first.id);
      expect(remote.readIds, [first.id]);
      expect(remote.reads, 1);
      expect(remote.lists, 0);
      expect(remote.historyScans, 0);
      expect(remote.creates, 0);
    });

    test('cachedKey_wrongAccount_isNeverUsed', () async {
      final a = await AccountBackupKeys('A', remote).forBackup();
      final other = _Remote();
      // Even an A entry misplaced under B's slot must not address A's locator.
      await secure.write(
          key: activeSlot('B'), value: await secure.read(key: activeSlot('A')));
      final b = await AccountBackupKeys('B', other).forBackup();
      expect(b.id, isNot(a.id));
      expect(other.readIds, isNot(contains(a.id)));
      expect(other.historyScans, 1);
      remote.resetCounts();
      expect((await AccountBackupKeys('A', remote).forBackup()).id, a.id);
      expect(remote.reads, 1);
      expect(remote.historyScans, 0);
    });

    for (final corruption in ['json', 'locator', 'generation', 'record']) {
      test('invalid local $corruption cache uses full safe discovery',
          () async {
        final key = await AccountBackupKeys('A', remote).forBackup();
        final cached = await activeData('A');
        if (corruption == 'locator') cached.remove('fileId');
        if (corruption == 'generation') cached['generation'] = 'wrong';
        if (corruption == 'record') cached['record'] = 'invalid';
        await secure.write(
            key: activeSlot('A'),
            value: corruption == 'json' ? 'invalid' : jsonEncode(cached));
        remote.resetCounts();
        expect((await AccountBackupKeys('A', remote).forBackup()).id, key.id);
        expect(remote.lists, 1);
        expect(remote.historyScans, 1);
        expect(remote.creates, 0);
      });
    }

    test('old generation-only secure cache upgrades through safe discovery',
        () async {
      final key = BackupMasterKey.generate();
      remote.records['old-file'] = key.encodeRecord();
      await secure.write(
          key:
              'flowy_backup_v2_key_${sha256.convert(utf8.encode('A'))}_${key.id}',
          value: key.encodeRecord());
      expect((await AccountBackupKeys('A', remote).forBackup()).id, key.id);
      expect(remote.historyScans, 1);
      expect((await activeData('A'))['fileId'], 'old-file');
    });

    test('currentGenerationMissing_neverSilentlyCreatesOrSelectsReplacement',
        () async {
      final key = await AccountBackupKeys('A', remote).forBackup();
      remote.records.remove(key.id);
      final other = BackupMasterKey.generate();
      remote.records['other-file'] = other.encodeRecord();
      remote.referenced.add(key.id);
      remote.resetCounts();
      await expectLater(AccountBackupKeys('A', remote).forBackup(),
          throwsA(_error(BackupCryptoError.missingKey)));
      expect(remote.readIds, [key.id]);
      expect(remote.lists, 0);
      expect(remote.historyScans, 0);
      expect(remote.creates, 0);
      expect((await activeData('A'))['generation'], key.id);
    });

    for (final corruption in ['malformed', 'different generation']) {
      test('cachedRemoteRecord $corruption fails without fallback', () async {
        final key = await AccountBackupKeys('A', remote).forBackup();
        remote.records[key.id] = corruption == 'malformed'
            ? 'not json'
            : BackupMasterKey.generate().encodeRecord();
        remote.resetCounts();
        await expectLater(AccountBackupKeys('A', remote).forBackup(),
            throwsA(_error(BackupCryptoError.corruptKey)));
        expect(remote.reads, 1);
        expect(remote.lists, 0);
        expect(remote.historyScans, 0);
        expect(remote.creates, 0);
      });
    }

    test(
        'remote network failure cannot use cached bytes or acknowledge revision',
        () async {
      await AccountBackupKeys('A', remote).forBackup();
      remote.failRead = true;
      final prefs = await SharedPreferences.getInstance();
      final store = BackupStateStore(prefs);
      await store.markDirty();
      await prefs.setString(backupUploadedRevisionKey, 'previous-receipt');
      await prefs.setString(backupLastSuccessKey, '2026-09-01T00:00:00.000');
      final before = await store.read();
      var uploaded = false;
      await expectLater(
          runBackupAttempt(store, () async {
            await AccountBackupKeys('A', remote).forBackup();
            uploaded = true;
            return DateTime.now();
          }, uploadedAt: (value) => value),
          throwsStateError);
      final after = await store.read();
      expect(uploaded, isFalse);
      expect(after.revision, before.revision);
      expect(after.uploadedRevision, before.uploadedRevision);
      expect(after.lastSuccess, before.lastSuccess);
      expect(after.dirty, isTrue);
      expect(after.lastAttempt, isNotNull);
      expect(after.lastFailure, isNotNull);
    });

    test('freshAccount_noKey_noV2References_createsAndVerifiesOnce', () async {
      final key = await AccountBackupKeys('A', remote).forBackup();
      expect(remote.historyScans, 1);
      expect(remote.creates, 1);
      expect(remote.readIds, [key.id, key.id]);
      expect((await activeData('A'))['generation'], key.id);
    });

    test('freshAccount_existingV2MissingKey_failsClosed', () async {
      remote.referenced.add(BackupMasterKey.generate().id);
      await expectLater(AccountBackupKeys('A', remote).forBackup(),
          throwsA(_error(BackupCryptoError.missingKey)));
      expect(remote.historyScans, 1);
      expect(remote.creates, 0);
      expect(await secure.read(key: activeSlot('A')), isNull);
    });

    test('restore_exactGeneration_doesNotChangeActiveWriteGeneration',
        () async {
      final active = await AccountBackupKeys('A', remote).forBackup();
      final older = BackupMasterKey.generate();
      remote.records['older-file'] = older.encodeRecord();
      expect((await AccountBackupKeys('A', remote).forRestore(older.id)).id,
          older.id);
      remote.resetCounts();
      expect((await AccountBackupKeys('A', remote).forBackup()).id, active.id);
      expect(remote.readIds, [active.id]);
      remote.records.remove('older-file');
      await expectLater(AccountBackupKeys('A', remote).forRestore(older.id),
          throwsA(_error(BackupCryptoError.missingKey)));
    });

    test('nonCurrentMissingGeneration_checkedDuringDiscovery_notOrdinaryWrite',
        () async {
      final active = await AccountBackupKeys('A', remote).forBackup();
      remote.referenced.add(BackupMasterKey.generate().id);
      remote.resetCounts();
      expect((await AccountBackupKeys('A', remote).forBackup()).id, active.id);
      expect(remote.reads, 1);
      expect(remote.historyScans, 0);
      await clearBackupKeyCache();
      await expectLater(AccountBackupKeys('A', remote).forBackup(),
          throwsA(_error(BackupCryptoError.missingKey)));
      expect(remote.historyScans, 1);
      expect(remote.creates, 0);
    });

    test('concurrentFastPath_sharesOneVerification_noNewGeneration', () async {
      final first = await AccountBackupKeys('A', remote).forBackup();
      remote.resetCounts();
      final keys = await Future.wait(
          List.generate(12, (_) => AccountBackupKeys('A', remote).forBackup()));
      expect(keys.map((k) => k.id).toSet(), {first.id});
      expect(remote.reads, 1);
      expect(remote.lists, 0);
      expect(remote.historyScans, 0);
      expect(remote.creates, 0);
    });

    for (final legacyCount in [0, 4, 40]) {
      test(
          'Drive adapter: $legacyCount legacy backups do not increase warm calls',
          () async {
        final api = _Drive();
        final remote = DriveBackupKeyRemote(api);
        for (var i = 0; i < legacyCount; i++) {
          api.files.add(
              'pfm_vault_backup_legacy_$i.enc', _legacyFixture([1, 2], 'A'));
        }
        final key = await AccountBackupKeys('A', remote).forBackup();
        expect(api.files.backupGets, legacyCount);
        final cached = await activeData('A');
        // Extra generations also must not increase steady-state enumeration.
        for (var i = 0; i < 3; i++) {
          final other = BackupMasterKey.generate();
          api.files.add('flowy_backup_key_v1_${other.id}.json',
              utf8.encode(other.encodeRecord()));
        }
        api.files.resetCounts();
        expect((await AccountBackupKeys('A', remote).forBackup()).id, key.id);
        expect(api.files.mediaIds, [cached['fileId']]);
        expect(api.files.keyGets, 1);
        expect(api.files.keyLists, 0);
        expect(api.files.historyLists, 0);
        expect(api.files.backupGets, 0);
      });
    }

    test('Drive adapter: cached locator 404 fails even if other keys exist',
        () async {
      final api = _Drive();
      final remote = DriveBackupKeyRemote(api);
      await AccountBackupKeys('A', remote).forBackup();
      final cached = await activeData('A');
      api.files.metadata.remove(cached['fileId']);
      final other = BackupMasterKey.generate();
      api.files.add('flowy_backup_key_v1_${other.id}.json',
          utf8.encode(other.encodeRecord()));
      final before = api.files.metadata.length;
      api.files.resetCounts();
      await expectLater(AccountBackupKeys('A', remote).forBackup(),
          throwsA(_error(BackupCryptoError.missingKey)));
      expect(api.files.keyLists, 0);
      expect(api.files.historyLists, 0);
      expect(api.files.metadata.length, before);
    });
  });

  group('Production backup/restore integration', () {
    late Directory root, docs, cache;
    late File live;
    late ProviderContainer container;
    late SharedPreferences prefs;
    late _Drive api;
    late _Google google;
    final opened = <AppDatabase>[];
    final avatar = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aC1sAAAAASUVORK5CYII=');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final security = {
      'algorithm': 'pbkdf2-sha256',
      'salt': base64Encode(List.filled(16, 0)),
      'hash': base64Encode(List.filled(32, 0)),
      'iterations': 120000,
      'length': 4,
      'isCustom': false
    };
    setUp(() async {
      opened.clear();
      root = await Directory.systemTemp.createTemp('flowy-crypto-');
      docs = await Directory('${root.path}/docs').create();
      cache = await Directory('${root.path}/cache').create();
      live = File('${docs.path}/pfm_local_vault.sqlite');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              pathChannel,
              (call) async => call.method == 'getApplicationDocumentsDirectory'
                  ? docs.path
                  : cache.path);
      FlutterSecureStorage.setMockInitialValues(
          {VaultSecurityService.storageKey: jsonEncode(security)});
      prefs = await SharedPreferences.getInstance();
      await applyBackupPreferences(prefs, {
        'pfm_backup_cadence_mode': 4,
        'pfm_backup_custom_unit': 'weeks',
        'pfm_backup_custom_value': 2,
        'pfm_backup_wifi_only': true,
        'pfm_backup_battery_safe': true,
        'user_display_name': 'An',
        'user_avatar_type': 'customImage',
        'user_avatar_image_base64': base64Encode(avatar),
      });
      // Auth identity is local-only, deliberately not imported from a capsule.
      await prefs.setString('user_email', 'A@example.invalid');
      await prefs.setBool('has_completed_onboarding', true);
      api = _Drive();
      google = _Google('A');
      container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWith((ref) {
          final db = AppDatabase.forTesting(NativeDatabase(live));
          opened.add(db);
          ref.onDispose(() => db.close());
          return db;
        }),
        cloudBackupServiceProvider.overrideWith((ref) => CloudBackupService(
            db: ref.read(databaseProvider),
            ref: ref,
            googleSignIn: google,
            driveApi: api)),
      ]);
      // Match the app lifecycle: profile finishes loading before restore UI opens.
      container.read(userProfileNotifierProvider);
      while (container.read(userProfileNotifierProvider).isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final db = container.read(databaseProvider);
      await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: 'wallet',
          name: 'Wallet',
          type: 'cash',
          balance: const Value(9000000)));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'food', name: 'Food', type: CategoryType.expense));
      await db.into(db.savingsGoals).insert(SavingsGoalsCompanion.insert(
          id: 'goal',
          title: 'Goal',
          targetAmount: 5000000,
          currentAmount: const Value(1000000)));
      for (final savings in [false, true]) {
        await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: savings ? 'savings' : 'normal',
            walletId: 'wallet',
            categoryId: 'food',
            amount: savings ? 1000000 : 2000000,
            type: CategoryType.expense,
            date: DateTime.now(),
            goalId: Value(savings ? 'goal' : null),
            envelopeType: Value(savings ? 'savings' : 'needs')));
      }
    });
    tearDown(() async {
      container.dispose();
      for (final db in opened) {
        await db.close();
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      await root.delete(recursive: true);
    });

    for (final silent in [false, true]) {
      test(
          'new ${silent ? 'background' : 'manual'} backups write V2 only; success acknowledges uploaded revision',
          () async {
        final store = BackupStateStore(prefs);
        await store.markDirty();
        final revision = (await store.read()).revision;
        final item = await container
            .read(cloudBackupServiceProvider)
            .performBackup(silent: silent);
        expect(item.properties['encryption_version'], '2');
        expect(
            backupEnvelopeKeyId(api.files.contents[item.fileId]!), isNotNull);
        expect((await store.read()).uploadedRevision, revision);
        expect((await store.read()).dirty, isFalse);
        expect(google.interactive, 0);
        final listed =
            await container.read(cloudBackupServiceProvider).listBackups();
        expect(listed.map((i) => i.fileId), [item.fileId]);
        expect(api.files.metadata, hasLength(2));
      });
    }
    for (final failure in ['missing', 'corrupt', 'mismatch']) {
      test('warm $failure key failure cannot upload or acknowledge changes',
          () async {
        final service = container.read(cloudBackupServiceProvider);
        final store = BackupStateStore(prefs);
        await store.markDirty();
        await service.performBackup(silent: true);
        final keyFile = api.files.metadata.values
            .singleWhere((f) => f.name!.startsWith('flowy_backup_key_'));
        if (failure == 'missing') {
          api.files.metadata.remove(keyFile.id);
        } else {
          api.files.contents[keyFile.id!] = failure == 'corrupt'
              ? utf8.encode('invalid')
              : utf8.encode(BackupMasterKey.generate().encodeRecord());
        }
        await store.markDirty();
        final before = await store.read();
        final filesBefore = api.files.metadata.length;
        api.files.resetCounts();
        await expectLater(service.performBackup(silent: true),
            throwsA(isA<BackupCryptoFailure>()));
        final after = await store.read();
        expect(after.revision, before.revision);
        expect(after.uploadedRevision, before.uploadedRevision);
        expect(after.lastSuccess, before.lastSuccess);
        expect(after.dirty, isTrue);
        expect(after.lastAttempt, isNotNull);
        expect(after.lastFailure, isNotNull);
        expect(api.files.metadata.length, filesBefore);
        expect(api.files.keyLists, 0);
        expect(api.files.historyLists, 0);
        expect(await cache.list().length, 0);
      });
    }

    test('progress verifies remote key before packing and labels upload last',
        () async {
      final stages = <String>[];
      await container.read(cloudBackupServiceProvider).createBackup(
          onProgress: (status, message, _) {
        stages.add(message);
        if (message == 'Đang xác minh khóa sao lưu…') {
          expect(api.files.keyGets, 0);
        }
        if (message == 'Đang nén và mã hóa bản sao lưu…') {
          expect(api.files.keyGets, greaterThan(0));
          expect(
              api.files.metadata.values
                  .where((f) => f.name!.startsWith('pfm_vault_backup_')),
              isEmpty);
        }
        if (status == CloudBackupStatus.uploading) {
          expect(stages.last, 'Đang tải lên thư mục an toàn Google Drive...');
          expect(
              api.files.metadata.values
                  .where((f) => f.name!.startsWith('pfm_vault_backup_')),
              isEmpty);
        }
      });
      expect(stages, [
        'Đang đồng bộ sổ cái CSDL...',
        'Đang xác minh khóa sao lưu…',
        'Đang nén và mã hóa bản sao lưu…',
        'Đang tổng hợp thông tin bản sao lưu…',
        'Đang tải lên thư mục an toàn Google Drive...',
        'Sao lưu thành công lên Google Drive!',
      ]);
    });

    test(
        'background key failure keeps dirty, attempt/failure visible, success unchanged',
        () async {
      api.files.add('pfm_vault_backup_missing-key.enc',
          encryptBackupV2([1, 2], BackupMasterKey.generate(), 'A'));
      final store = BackupStateStore(prefs);
      await store.markDirty();
      await prefs.setString(backupLastSuccessKey, '2026-09-01T00:00:00.000');
      await expectLater(
          container
              .read(cloudBackupServiceProvider)
              .performBackup(silent: true),
          throwsA(_error(BackupCryptoError.missingKey)));
      final state = await store.read();
      expect(state.dirty, isTrue);
      expect(state.uploadedRevision, isNull);
      expect(state.lastAttempt, isNotNull);
      expect(state.lastFailure, isNotNull);
      expect(state.lastSuccess, DateTime(2026, 9, 1));
      expect(state.failureMessage, contains('khóa khôi phục'));
      expect(api.files.metadata, hasLength(1));
      expect(google.interactive, 0);
      expect(await cache.list().length, 0);
    });
    test(
        'account switch during snapshot cannot change the authenticated backup account binding',
        () async {
      final service = container.read(cloudBackupServiceProvider);
      final item = await service.createBackup(onProgress: (status, _, __) {
        if (status == CloudBackupStatus.checkpointing) {
          google.currentUser = _Account('B');
        }
      });
      final master =
          await AccountBackupKeys('A', DriveBackupKeyRemote(api)).forBackup();
      final encrypted = api.files.contents[item.fileId]!;
      expect(decryptBackupEnvelope(encrypted, accountId: 'A', master: master),
          isNotEmpty);
      expect(
          () =>
              decryptBackupEnvelope(encrypted, accountId: 'B', master: master),
          throwsA(_error(BackupCryptoError.authentication)));
    });
    test('upload failure after V2 encryption cannot acknowledge dirty revision',
        () async {
      api.files.failBackupUpload = true;
      final store = BackupStateStore(prefs);
      await store.markDirty();
      await expectLater(
          container
              .read(cloudBackupServiceProvider)
              .performBackup(silent: true),
          throwsStateError);
      final state = await store.read();
      expect(state.dirty, isTrue);
      expect(state.uploadedRevision, isNull);
      expect(state.lastSuccess, isNull);
      expect(state.lastFailure, isNotNull);
      expect(
          api.files.metadata.values
              .every((f) => f.name!.startsWith('flowy_backup_key_')),
          isTrue);
    });

    for (final envelope in [1, 2]) {
      for (final schema in [10, 11]) {
        test(
            'V$envelope schema $schema full restore preserves savings, Fix C preferences/avatar and normalizes legacy',
            () async {
          final service = container.read(cloudBackupServiceProvider);
          final uploaded = await service.performBackup();
          final master = await AccountBackupKeys('A', DriveBackupKeyRemote(api))
              .forBackup();
          var zip = decryptBackupEnvelope(api.files.contents[uploaded.fileId]!,
              accountId: 'A', master: master);
          if (schema == 10) {
            final folder = await Directory('${root.path}/legacy').create();
            final archive = ZipDecoder().decodeBytes(zip);
            for (final file in archive) {
              await File('${folder.path}/${file.name}')
                  .writeAsBytes(file.content);
            }
            final raw =
                sql.sqlite3.open('${folder.path}/pfm_local_vault.sqlite');
            raw.execute('ALTER TABLE transactions DROP COLUMN goal_id');
            raw.execute('PRAGMA user_version=10');
            raw.close();
            final encoder = ZipFileEncoder()..create('${root.path}/legacy.zip');
            for (final file in folder.listSync().whereType<File>()) {
              await encoder.addFile(file);
            }
            encoder.close();
            zip = await File('${root.path}/legacy.zip').readAsBytes();
          }
          final bytes = envelope == 1
              ? _legacyFixture(zip, 'A')
              : encryptBackupV2(zip, master, 'A');
          final restoreId =
              api.files.add('pfm_vault_backup_fixture.enc', bytes);
          await prefs.setInt('pfm_backup_cadence_mode', 3);
          await prefs.setString('user_display_name', 'Changed');
          final receipt = prefs.getString(backupUploadedRevisionKey);
          await clearBackupKeyCache(); // New device/session has no local master key.
          final prepared = await service.downloadAndDecryptBackup(restoreId);
          await service.restorePreparedBackup(prepared);
          final raw = sql.sqlite3.open(live.path);
          expect(raw.select('PRAGMA user_version').single.values.single, 12);
          expect(raw.select('SELECT balance FROM wallets').single['balance'],
              9000000);
          expect(
              raw
                  .select('SELECT current_amount FROM savings_goals')
                  .single['current_amount'],
              1000000);
          expect(raw.select('SELECT id FROM transactions'), hasLength(2));
          raw.close();
          expect(prefs.getInt('pfm_backup_cadence_mode'), 4);
          expect(prefs.getString('pfm_backup_custom_unit'), 'weeks');
          expect(prefs.getInt('pfm_backup_custom_value'), 2);
          expect(prefs.getBool('pfm_backup_wifi_only'), isTrue);
          expect(prefs.getBool('pfm_backup_battery_safe'), isTrue);
          expect(prefs.getString(backupUploadedRevisionKey), receipt);
          expect(prefs.getBool('has_completed_onboarding'), isTrue);
          expect(
              await File(prefs.getString('user_avatar_value')!).readAsBytes(),
              avatar);
        });
      }
    }
    for (final failure in [
      'tag',
      'header',
      'missing-key',
      'wrong-account',
      'downgrade'
    ]) {
      test(
          'restore $failure fails before plaintext/live/preferences/security mutation and cleans staging',
          () async {
        final service = container.read(cloudBackupServiceProvider);
        final item = await service.performBackup();
        final before = ledgerFingerprint(live.path);
        final beforePrefs = {
          for (final key in prefs.getKeys()) key: prefs.get(key)
        };
        final securityBefore = await VaultSecurityService.storage
            .read(key: VaultSecurityService.storageKey);
        if (failure == 'tag') api.files.contents[item.fileId]!.last ^= 1;
        if (failure == 'header') api.files.contents[item.fileId]![43] ^= 1;
        if (failure == 'missing-key') {
          api.files.metadata
              .removeWhere((_, f) => f.name!.startsWith('flowy_backup_key_'));
        }
        if (failure == 'wrong-account') google.currentUser = _Account('B');
        if (failure == 'downgrade') {
          api.files.contents[item.fileId] = _legacyFixture([1, 2, 3], 'A');
        }
        await expectLater(service.downloadAndDecryptBackup(item.fileId),
            throwsA(failure == 'wrong-account'
                ? isA<BackupAuthenticationFailure>()
                : isA<BackupCryptoFailure>()));
        expect(ledgerFingerprint(live.path), before);
        expect({for (final key in prefs.getKeys()) key: prefs.get(key)},
            beforePrefs);
        expect(
            await VaultSecurityService.storage
                .read(key: VaultSecurityService.storageKey),
            securityBefore);
        expect(await cache.list().length, 0);
      });
    }
    test(
        'logout clears only local master cache and leaves remote backups/keys intact',
        () async {
      final service = container.read(cloudBackupServiceProvider);
      await service.performBackup();
      expect(
          (await const FlutterSecureStorage().readAll())
              .keys
              .any((k) => k.startsWith('flowy_backup_v2_key_')),
          isTrue);
      await service.signOutAndClearSession();
      expect(
          (await const FlutterSecureStorage().readAll())
              .keys
              .any((k) => k.startsWith('flowy_backup_v2_key_')),
          isFalse);
      expect(api.files.metadata, hasLength(2));
    });
    test(
        'profile logout also removes local backup keys without deleting financial data',
        () async {
      await container.read(cloudBackupServiceProvider).performBackup();
      await AuthProfileService(googleSignIn: google).signOut();
      expect(
          (await const FlutterSecureStorage().readAll())
              .keys
              .any((k) => k.startsWith('flowy_backup_v2_key_')),
          isFalse);
      expect(api.files.metadata, hasLength(2));
      expect(
          (await container
                  .read(databaseProvider)
                  .select(container.read(databaseProvider).wallets)
                  .get())
              .single
              .balance,
          9000000);
    });
  });
}
