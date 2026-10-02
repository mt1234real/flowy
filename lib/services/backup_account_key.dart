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

  Future<Map<String, BackupMasterKey>> _records() async {
    final result = <String, BackupMasterKey>{};
    for (final file in await remote.listRecords()) {
      final key = BackupMasterKey.decodeRecord(await remote.readRecord(file));
      result[key.id] = key;
    }
    return result;
  }

  Future<BackupMasterKey> _cache(BackupMasterKey key) async {
    final namespace = sha256.convert(utf8.encode(accountId.trim()));
    await storage.write(
        key: '$_cachePrefix${namespace}_${key.id}', value: key.encodeRecord());
    return key;
  }

  Future<BackupMasterKey> forRestore(String id) async {
    final key = (await _records())[id];
    if (key == null) {
      throw const BackupCryptoFailure(BackupCryptoError.missingKey);
    }
    // Always verify portable material, even if this device has a cached copy.
    return _cache(key);
  }

  Future<BackupMasterKey> forBackup() async {
    final existing = _initializing[accountId];
    if (existing != null) return existing;
    final future = _initialize();
    _initializing[accountId] = future;
    try {
      return await future;
    } finally {
      if (identical(_initializing[accountId], future)) {
        _initializing.remove(accountId);
      }
    }
  }

  Future<BackupMasterKey> _initialize() async {
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
    return _cache(keys[ids.first]!);
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
    final media = await api.files.get(fileId,
        downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
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
