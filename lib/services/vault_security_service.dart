import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart' show sharedPreferencesProvider;

// PBKDF2-HMAC-SHA256, one 32-byte block. Runs outside the UI isolate.
String _derivePin(Map<String, dynamic> input) {
  final hmac = Hmac(sha256, utf8.encode(input['pin'] as String));
  var u = hmac
      .convert([...base64Decode(input['salt'] as String), 0, 0, 0, 1]).bytes;
  final result = List<int>.from(u);
  for (var i = 1; i < (input['iterations'] as int); i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= u[j];
    }
  }
  return base64Encode(result);
}

class VaultSecurityConfig {
  // Compatibility for injected in-memory repositories; never serialized or loaded from secure storage.
  final String pin;
  final String salt;
  final String hash;
  final int iterations;
  final int length;
  final bool isCustom;
  const VaultSecurityConfig(
      {this.pin = '',
      this.salt = '',
      this.hash = '',
      this.iterations = 120000,
      required this.length,
      required this.isCustom});
  static const defaultConfig =
      VaultSecurityConfig(salt: '', hash: '', length: 4, isCustom: false);
  Map<String, dynamic> toJson() => {
        'algorithm': 'pbkdf2-sha256',
        'salt': salt,
        'hash': hash,
        'iterations': iterations,
        'length': length,
        'isCustom': isCustom
      };
  factory VaultSecurityConfig.fromJson(Map<String, dynamic> json) {
    if (json['algorithm'] != 'pbkdf2-sha256' ||
        ![4, 6].contains(json['length']) ||
        json['iterations'] != 120000 ||
        json['isCustom'] is! bool ||
        base64Decode(json['salt'] as String).length != 16 ||
        base64Decode(json['hash'] as String).length != 32) {
      throw const FormatException('Cấu hình PIN không hợp lệ');
    }
    return VaultSecurityConfig(
        salt: json['salt'] as String,
        hash: json['hash'] as String,
        length: json['length'] as int,
        isCustom: json['isCustom'] as bool);
  }
}

class VaultSecurityService {
  static const storageKey = 'flowy_vault_pin_v2';
  static const storage = FlutterSecureStorage();
  VaultSecurityConfig _config = VaultSecurityConfig.defaultConfig;
  Future<void>? _initialization;
  Future<void> init() => _initialization ??= _load();
  Future<void> _load() async {
    final stored = await storage.read(key: storageKey);
    final folder = await getApplicationDocumentsDirectory();
    final legacy = File(p.join(folder.path, 'vault_security_config.json'));
    if (stored != null) {
      _config = VaultSecurityConfig.fromJson(
          jsonDecode(stored) as Map<String, dynamic>);
    } else {
      final old = await legacy.exists()
          ? jsonDecode(await legacy.readAsString()) as Map<String, dynamic>
          : <String, dynamic>{};
      final pin = old['pin'] as String? ?? '1234';
      _config = await _make(pin, pin.length, old['isCustom'] as bool? ?? false);
      await storage.write(key: storageKey, value: jsonEncode(_config.toJson()));
    }
    // Delete plaintext only after the secure write/read succeeded.
    if (await legacy.exists()) await legacy.delete();
  }

  Future<VaultSecurityConfig> _make(String pin, int length, bool custom) async {
    if (![4, 6].contains(length) ||
        !RegExp(r'^\d+$').hasMatch(pin) ||
        pin.length != length) {
      throw ArgumentError('Mã PIN cần có 4 hoặc 6 chữ số');
    }
    final random = math.Random.secure();
    final salt =
        base64Encode(List<int>.generate(16, (_) => random.nextInt(256)));
    final hash = await compute(
        _derivePin, {'pin': pin, 'salt': salt, 'iterations': 120000});
    return VaultSecurityConfig(
        salt: salt, hash: hash, length: length, isCustom: custom);
  }

  VaultSecurityConfig get currentConfig => _config;
  int get currentPinLength => _config.length;
  Future<bool> hasCustomPin() async {
    await init();
    return _config.isCustom;
  }

  Future<bool> verifyPin(String pin) async {
    await init();
    if (pin.length != _config.length) return false;
    final actual = base64Decode(await compute(_derivePin,
        {'pin': pin, 'salt': _config.salt, 'iterations': _config.iterations}));
    final expected = base64Decode(_config.hash);
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }

  Future<void> updatePin({required String newPin, required int length}) async {
    await init();
    final next = await _make(newPin, length, true);
    await storage.write(key: storageKey, value: jsonEncode(next.toJson()));
    _config = next;
  }

  Future<Map<String, dynamic>> exportManifest() async {
    await init();
    return _config.toJson();
  }

  /// Rollback snapshots must preserve absence without initializing a PIN or
  /// migrating the legacy file. Preserve the stored bytes exactly.
  Future<Map<String, dynamic>> snapshotPersistedState() async => {
        'snapshotVersion': 1,
        'secureStorageValue': await storage.read(key: storageKey),
      };

  static Future<void> restorePersistedSnapshot(
      Map<String, dynamic> snapshot) async {
    if (!snapshot.containsKey('snapshotVersion')) {
      // Recovery journals written before read-only snapshots contain a manifest.
      await restoreManifest(snapshot);
      return;
    }
    final value = snapshot['secureStorageValue'];
    if (snapshot['snapshotVersion'] != 1 ||
        !snapshot.containsKey('secureStorageValue') ||
        (value != null && value is! String)) {
      throw const FormatException('Bản dự phòng bảo mật không hợp lệ');
    }
    if (value == null) {
      await storage.delete(key: storageKey);
    } else {
      await storage.write(key: storageKey, value: value as String);
    }
  }

  static Future<void> restoreManifest(Map<String, dynamic> manifest) async {
    final config = VaultSecurityConfig.fromJson(manifest);
    await storage.write(key: storageKey, value: jsonEncode(config.toJson()));
  }
}

class VaultSecurityNotifier extends StateNotifier<VaultSecurityConfig> {
  final VaultSecurityService _service;
  VaultSecurityNotifier(this._service)
      : super(VaultSecurityConfig.defaultConfig) {
    _load();
  }
  Future<void> _load() async {
    try {
      await _service.init();
      if (mounted) state = _service.currentConfig;
    } catch (error) {
      debugPrint('Vault security unavailable: $error');
    }
  }

  Future<bool> verifyPin(String pin) => _service.verifyPin(pin);
  Future<void> updatePin({required String newPin, required int length}) async {
    await _service.updatePin(newPin: newPin, length: length);
    if (mounted) state = _service.currentConfig;
  }

  bool get hasCustomPin => state.isCustom;
}

final vaultSecurityServiceProvider = Provider((ref) => VaultSecurityService());
final vaultSecurityNotifierProvider =
    StateNotifierProvider<VaultSecurityNotifier, VaultSecurityConfig>((ref) =>
        VaultSecurityNotifier(ref.watch(vaultSecurityServiceProvider)));
final vaultPinLengthProvider =
    Provider<int>((ref) => ref.watch(vaultSecurityNotifierProvider).length);

class VaultBiometricsNotifier extends StateNotifier<bool> {
  final SharedPreferences prefs;
  VaultBiometricsNotifier(this.prefs)
      : super(prefs.getBool('vault_biometrics_enabled') ?? true);
  Future<void> setEnabled(bool value) async {
    if (!await prefs.setBool('vault_biometrics_enabled', value)) {
      throw StateError('Cannot save biometric preference');
    }
    state = value;
  }
}

final vaultBiometricsProvider =
    StateNotifierProvider<VaultBiometricsNotifier, bool>(
        (ref) => VaultBiometricsNotifier(ref.watch(sharedPreferencesProvider)));
