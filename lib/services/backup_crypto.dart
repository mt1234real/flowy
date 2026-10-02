import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;

enum BackupCryptoError {
  unsupported,
  missingKey,
  corruptKey,
  authentication,
  malformed
}

class BackupCryptoFailure implements Exception {
  final BackupCryptoError code;
  const BackupCryptoFailure(this.code);
  @override
  String toString() => switch (code) {
        BackupCryptoError.unsupported =>
          'Định dạng mã hóa cần phiên bản Flowy mới hơn.',
        BackupCryptoError.missingKey =>
          'Không tìm thấy khóa khôi phục trên Google Drive. Không tạo khóa thay thế để tránh mất khả năng khôi phục bản sao lưu cũ.',
        BackupCryptoError.corruptKey =>
          'Khóa khôi phục trên Google Drive không hợp lệ.',
        BackupCryptoError.authentication =>
          'Không xác thực được bản sao lưu. Hãy kiểm tra tài khoản hoặc chọn bản sao lưu khác.',
        BackupCryptoError.malformed =>
          'Tệp sao lưu mã hóa bị thiếu hoặc không hợp lệ.',
      };
}

/// V2 fixed header: magic(8), version(1), AES-GCM ID(1), HKDF ID(1),
/// key generation SHA-256(32), salt(32), nonce(12). All 87 bytes are AAD.
const backupV2HeaderSize = 87;
const _magic = 'FLOWYENC';
const _maxEncryptedBytes = 256 * 1024 * 1024;

class BackupMasterKey {
  final Uint8List bytes;
  String get id => sha256.convert(bytes).toString();
  BackupMasterKey(List<int> secret) : bytes = Uint8List.fromList(secret) {
    if (bytes.length != 32) {
      throw const BackupCryptoFailure(BackupCryptoError.corruptKey);
    }
  }
  factory BackupMasterKey.generate() =>
      BackupMasterKey(enc.Key.fromSecureRandom(32).bytes);
  String encodeRecord() =>
      jsonEncode({'version': 1, 'keyId': id, 'secret': base64Encode(bytes)});
  factory BackupMasterKey.decodeRecord(String record) {
    try {
      if (record.length > 4096) throw const FormatException();
      final data = jsonDecode(record) as Map<String, dynamic>;
      if (data['version'] != 1) {
        throw const BackupCryptoFailure(BackupCryptoError.unsupported);
      }
      final key = BackupMasterKey(base64Decode(data['secret'] as String));
      if (key.id != data['keyId']) throw const FormatException();
      return key;
    } on BackupCryptoFailure {
      rethrow;
    } catch (_) {
      throw const BackupCryptoFailure(BackupCryptoError.corruptKey);
    }
  }
}

/// Null means the unmarked legacy IV+ciphertext format. There is never an
/// authentication-failure fallback from V2 to legacy.
String? backupEnvelopeKeyId(List<int> bytes) {
  if (bytes.length < 32) {
    throw const BackupCryptoFailure(BackupCryptoError.malformed);
  }
  final magic = ascii.encode(_magic);
  if (!List.generate(8, (i) => bytes[i] == magic[i]).every((v) => v)) {
    return null;
  }
  if (bytes[8] != 2 || bytes[9] != 1 || bytes[10] != 1) {
    throw const BackupCryptoFailure(BackupCryptoError.unsupported);
  }
  if (bytes.length < backupV2HeaderSize) {
    throw const BackupCryptoFailure(BackupCryptoError.malformed);
  }
  return bytes
      .sublist(11, 43)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

Uint8List _derive(BackupMasterKey master, Uint8List salt) {
  final hkdf = pc.HKDFKeyDerivator(pc.SHA256Digest())
    ..init(pc.HkdfParameters(master.bytes, 32, salt,
        Uint8List.fromList(utf8.encode('flowy-backup-v2'))));
  final output = Uint8List(32);
  hkdf.deriveKey(null, 0, output, 0);
  return output;
}

Uint8List _aad(List<int> header, String accountId) => Uint8List.fromList([
      ...header,
      ...utf8.encode(jsonEncode(['flowy-backup-v2', accountId.trim()]))
    ]);

Uint8List encryptBackupV2(
    List<int> plaintext, BackupMasterKey master, String accountId) {
  final salt = enc.SecureRandom(32).bytes;
  final nonce = enc.IV.fromSecureRandom(12);
  final header = Uint8List.fromList([
    ...ascii.encode(_magic),
    2,
    1,
    1,
    ...sha256.convert(master.bytes).bytes,
    ...salt,
    ...nonce.bytes,
  ]);
  final cipher = enc.Encrypter(
      enc.AES(enc.Key(_derive(master, salt)), mode: enc.AESMode.gcm));
  final encrypted = cipher.encryptBytes(plaintext,
      iv: nonce, associatedData: _aad(header, accountId));
  return Uint8List.fromList([...header, ...encrypted.bytes]);
}

/// Compatibility ONLY. No legacy encryption API exists in production.
Uint8List _legacyKey(String accountId) => Uint8List.fromList(
    Hmac(sha256, utf8.encode('flowy_secure_vault_salt_2026_@#\$'))
        .convert(utf8.encode(accountId.trim()))
        .bytes);

Uint8List decryptBackupEnvelope(List<int> input,
    {required String accountId, BackupMasterKey? master}) {
  if (input.length > _maxEncryptedBytes) {
    throw const BackupCryptoFailure(BackupCryptoError.malformed);
  }
  final id = backupEnvelopeKeyId(input);
  final bytes = Uint8List.fromList(input);
  if (id != null) {
    if (master == null) {
      throw const BackupCryptoFailure(BackupCryptoError.missingKey);
    }
    if (master.id != id) {
      throw const BackupCryptoFailure(BackupCryptoError.authentication);
    }
    if (bytes.length < backupV2HeaderSize + 16) {
      throw const BackupCryptoFailure(BackupCryptoError.malformed);
    }
    final header = Uint8List.sublistView(bytes, 0, backupV2HeaderSize);
    final key = _derive(master, Uint8List.sublistView(header, 43, 75));
    try {
      return Uint8List.fromList(enc.Encrypter(
              enc.AES(enc.Key(key), mode: enc.AESMode.gcm))
          .decryptBytes(
              enc.Encrypted(Uint8List.sublistView(bytes, backupV2HeaderSize)),
              iv: enc.IV(Uint8List.sublistView(header, 75)),
              associatedData: _aad(header, accountId)));
    } catch (_) {
      throw const BackupCryptoFailure(BackupCryptoError.authentication);
    }
  }
  try {
    return Uint8List.fromList(enc.Encrypter(
            enc.AES(enc.Key(_legacyKey(accountId)), mode: enc.AESMode.gcm))
        .decryptBytes(enc.Encrypted(Uint8List.sublistView(bytes, 16)),
            iv: enc.IV(Uint8List.sublistView(bytes, 0, 16))));
  } catch (_) {
    throw const BackupCryptoFailure(BackupCryptoError.authentication);
  }
}
