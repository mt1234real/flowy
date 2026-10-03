import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'backup_crypto.dart';

const _keyPrefix = 'flowy_backup_key_v1_';
const _cachePrefix = 'flowy_backup_v2_key_';
const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock));

typedef _LocatedBackupKey = ({BackupMasterKey key, String fileId});

Future<void> clearBackupKeyCache() async {
  for (final key in (await _storage.readAll()).keys.toList()) {
    if (key.startsWith(_cachePrefix)) await _storage.delete(key: key);
  }
}

abstract class BackupKeyRemote {
  Future<List<String>> listRecords();
  Future<String> readRecord(String fileId);
  Future<String> createRecord(BackupMasterKey key);
  Future<Set<String>> referencedKeyIds();
}

/// Immutable generations allow concurrent first creation on different devices:
/// keep every record, read back before use, and authenticate its ID in backups.
/// Never replace/delete remote key material, even when a newer candidate wins.
class AccountBackupKeys {
  final String accountId;
  final BackupKeyRemote remote;
  final FlutterSecureStorage storage;
  static final Map<String, Future<BackupMasterKey>> _initializing = {};
  AccountBackupKeys(this.accountId, this.remote, {this.storage = _storage});

  String get _namespace =>
      sha256.convert(utf8.encode(accountId.trim())).toString();
  String get _activeCacheKey => '$_cachePrefix${_namespace}_active';

  Future<Map<String, _LocatedBackupKey>> _records() async {
    final result = <String, _LocatedBackupKey>{};
    for (final file in await remote.listRecords()) {
      final key = BackupMasterKey.decodeRecord(await remote.readRecord(file));
      result[key.id] = (key: key, fileId: file);
    }
    return result;
  }

  Future<BackupMasterKey> _cache(BackupMasterKey key) async {
    await storage.write(
        key: '$_cachePrefix${_namespace}_${key.id}', value: key.encodeRecord());
    return key;
  }

  Future<BackupMasterKey> _cacheActive(_LocatedBackupKey located) async {
    await storage.write(
        key: _activeCacheKey,
        value: jsonEncode({
          'version': 1,
          'namespace': _namespace,
          'generation': located.key.id,
          'fileId': located.fileId,
          'record': located.key.encodeRecord(),
        }));
    return located.key;
  }

  Future<_LocatedBackupKey?> _readActive() async {
    final stored = await storage.read(key: _activeCacheKey);
    if (stored == null) return null;
    // Old generation-only caches, malformed entries and wrong-account entries
    // require full safe discovery. Never use unverified local key material.
    try {
      if (stored.length > 8192) return null;
      final data = jsonDecode(stored) as Map<String, dynamic>;
      if (data['version'] != 1 || data['namespace'] != _namespace) return null;
      final key = BackupMasterKey.decodeRecord(data['record'] as String);
      final fileId = data['fileId'] as String;
      if (key.id != data['generation'] || fileId.trim().isEmpty) return null;
      return (key: key, fileId: fileId);
    } catch (_) {
      return null;
    }
  }

  Future<BackupMasterKey> forRestore(String id) async {
    final located = (await _records())[id];
    if (located == null) {
      throw const BackupCryptoFailure(BackupCryptoError.missingKey);
    }
    // Always verify portable material, even if this device has a cached copy.
    return _cache(located.key);
  }

  Future<BackupMasterKey> forBackup() async {
    final existing = _initializing[accountId];
    if (existing != null) return existing;
    final future = _resolveForBackup();
    _initializing[accountId] = future;
    try {
      return await future;
    } finally {
      if (identical(_initializing[accountId], future)) {
        _initializing.remove(accountId);
      }
    }
  }

  Future<BackupMasterKey> _resolveForBackup() async {
    final active = await _readActive();
    if (active == null) return _discoverWithHistoricalIntegrity();

    // One exact remote GET per ordinary backup. A missing/corrupt/mismatched
    // current record must fail, not select another generation or create a key.
    final verified =
        BackupMasterKey.decodeRecord(await remote.readRecord(active.fileId));
    if (verified.id != active.key.id) {
      throw const BackupCryptoFailure(BackupCryptoError.corruptKey);
    }
    return verified;
  }

  // Full historical integrity is retained for cache misses/recovery and before
  // first creation. Steady-state writes verify only the generation they use.
  Future<BackupMasterKey> _discoverWithHistoricalIntegrity() async {
    var keys = await _records();
    final required = await remote.referencedKeyIds();
    if (required.any((id) => !keys.containsKey(id))) {
      throw const BackupCryptoFailure(BackupCryptoError.missingKey);
    }
    if (keys.isEmpty) {
      final candidate = BackupMasterKey.generate();
      final file = await remote.createRecord(candidate);
      final confirmed =
          BackupMasterKey.decodeRecord(await remote.readRecord(file));
      if (confirmed.id != candidate.id) {
        throw const BackupCryptoFailure(BackupCryptoError.corruptKey);
      }
      keys = await _records();
      if (!keys.containsKey(candidate.id)) {
        throw const BackupCryptoFailure(BackupCryptoError.missingKey);
      }
    }
    final ids = keys.keys.toList()..sort();
    return _cacheActive(keys[ids.first]!);
  }
}

class DriveBackupKeyRemote implements BackupKeyRemote {
  final drive.DriveApi api;
  DriveBackupKeyRemote(this.api);

  Future<List<drive.File>> _list(String query) async {
    final result = <drive.File>[];
    String? token;
    do {
      final page = await api.files.list(
          spaces: 'appDataFolder',
          q: query,
          pageSize: 1000,
          pageToken: token,
          $fields: 'nextPageToken,files(id,name,properties)');
      result.addAll(page.files ?? []);
      token = page.nextPageToken;
    } while (token != null && token.isNotEmpty);
    return result;
  }

  @override
  Future<List<String>> listRecords() async =>
      (await _list("name contains 'flowy_backup_key_'"))
          .map((f) => f.id!)
          .toList();

  @override
  Future<String> readRecord(String fileId) async {
    final drive.Media media;
    try {
      media = await api.files.get(fileId,
          downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    } on drive.DetailedApiRequestError catch (error) {
      if (error.status == 404) {
        throw const BackupCryptoFailure(BackupCryptoError.missingKey);
      }
      rethrow;
    }
    final bytes = <int>[];
    await for (final chunk in media.stream) {
      if (bytes.length + chunk.length > 4096) {
        throw const BackupCryptoFailure(BackupCryptoError.corruptKey);
      }
      bytes.addAll(chunk);
    }
    try {
      return utf8.decode(bytes);
    } catch (_) {
      throw const BackupCryptoFailure(BackupCryptoError.corruptKey);
    }
  }

  @override
  Future<String> createRecord(BackupMasterKey key) async {
    final bytes = utf8.encode(key.encodeRecord());
    final file = await api.files.create(
        drive.File()
          ..name = '$_keyPrefix${key.id}.json'
          ..parents = ['appDataFolder']
          ..mimeType = 'application/json',
        uploadMedia: drive.Media(Stream.value(bytes), bytes.length),
        $fields: 'id');
    if (file.id == null) {
      throw const BackupCryptoFailure(BackupCryptoError.missingKey);
    }
    return file.id!;
  }

  @override
  Future<Set<String>> referencedKeyIds() async {
    final ids = <String>{};
    for (final file in await _list("name contains 'pfm_vault_backup_'")) {
      final recordedId = file.properties?['encryption_key_id'];
      if (file.properties?['encryption_version'] == '2' &&
          recordedId != null &&
          RegExp(r'^[a-f0-9]{64}$').hasMatch(recordedId)) {
        ids.add(recordedId);
        continue;
      }
      // A header read also detects V2 when Drive metadata is absent/stale.
      final media = await api.files.get(file.id!,
          downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      final prefix = <int>[];
      await for (final chunk in media.stream) {
        prefix.addAll(chunk.take(backupV2HeaderSize - prefix.length));
        if (prefix.length == backupV2HeaderSize) break;
      }
      final id = backupEnvelopeKeyId(prefix);
      if (id != null) ids.add(id);
      if (id == null && file.properties?['encryption_version'] == '2') {
        throw const BackupCryptoFailure(BackupCryptoError.malformed);
      }
    }
    return ids;
  }
}
