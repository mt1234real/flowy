// ==============================================================================
// File: lib/services/auth_profile_service.dart
// Architecture: User Identity & Profile Management Service (Phase 1)
// Stack: flutter, flutter_riverpod, google_sign_in, flutter_secure_storage, shared_preferences
// Features:
// 1. Dual Storage Layer:
//    - SharedPreferences: Non-sensitive display metadata (displayName, avatarType, avatarValue, avatarColorHex)
//    - FlutterSecureStorage: Encrypted authentication tokens & secure credentials (google_auth_token)
// 2. Google OAuth 2.0 Integration:
//    - Scopes: email, https://www.googleapis.com/auth/drive.appdata (Zero Server Cost Cloud Sync)
//    - Auto-extracts HD Google avatar (=s256-c) with smooth fallback
// 3. Zero Account Lock-in Principle:
//    - Sign-out clears OAuth tokens & resets profile to Guest while preserving 100% of SQLite ledger data
// 4. Fully Reactive Riverpod Architecture:
//    - userProfileNotifierProvider exposes real-time state mutations across UI screens
// ==============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_schedule.dart';
import 'avatar_storage.dart';

/// Các hình thức hiển thị Avatar người dùng
enum UserAvatarType {
  google,
  customImage,
  emoji,
  initials,
}

/// DTO Hồ sơ định danh người dùng
class UserProfile {
  final String displayName;
  final String? email;
  final UserAvatarType avatarType;
  final String avatarValue;
  final String avatarColorHex;

  const UserProfile({
    required this.displayName,
    this.email,
    required this.avatarType,
    required this.avatarValue,
    required this.avatarColorHex,
  });

  /// Kiểm tra trạng thái đã đăng nhập tài khoản Google hay chưa
  bool get isSignedIn => email != null && email!.trim().isNotEmpty;

  /// Hồ sơ khách mặc định (Guest Profile)
  factory UserProfile.guest() {
    return const UserProfile(
      displayName: 'Khách',
      email: null,
      avatarType: UserAvatarType.initials,
      avatarValue: 'K',
      avatarColorHex: '#10B981',
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? email,
    bool clearEmail = false,
    UserAvatarType? avatarType,
    String? avatarValue,
    String? avatarColorHex,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      email: clearEmail ? null : (email ?? this.email),
      avatarType: avatarType ?? this.avatarType,
      avatarValue: avatarValue ?? this.avatarValue,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'email': email,
      'avatarType': avatarType.name,
      'avatarValue': avatarValue,
      'avatarColorHex': avatarColorHex,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final avatarTypeName = json['avatarType'] as String? ?? 'initials';
    final avatarType = UserAvatarType.values.firstWhere(
          (e) => e.name == avatarTypeName,
      orElse: () => UserAvatarType.initials,
    );

    return UserProfile(
      displayName: json['displayName'] as String? ?? 'Khách',
      email: json['email'] as String?,
      avatarType: avatarType,
      avatarValue: json['avatarValue'] as String? ?? 'K',
      avatarColorHex: json['avatarColorHex'] as String? ?? '#10B981',
    );
  }
}

/// Dịch vụ quản lý xác thực Google và hồ sơ cá nhân
class AuthProfileService {
  static const String _keyDisplayName = 'user_display_name';
  static const String _keyEmail = 'user_email';
  static const String _keyAvatarType = 'user_avatar_type';
  static const String _keyAvatarValue = 'user_avatar_value';
  static const String _keyAvatarColorHex = 'user_avatar_color_hex';

  static const String _secureKeyGoogleAuthToken = 'google_auth_token';
  static const String _secureKeyGoogleIdToken = 'google_id_token';

  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _secureStorage;

  AuthProfileService({
    GoogleSignIn? googleSignIn,
    FlutterSecureStorage? secureStorage,
  })  : _googleSignIn = googleSignIn ??
      GoogleSignIn(
        scopes: [
          'email',
          'https://www.googleapis.com/auth/drive.appdata',
        ],
      ),
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  /// Đọc hồ sơ người dùng đã lưu từ SharedPreferences
  Future<UserProfile> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final displayName = prefs.getString(_keyDisplayName);
      final email = prefs.getString(_keyEmail);
      final avatarTypeRaw = prefs.getString(_keyAvatarType);
      final avatarValue = prefs.getString(_keyAvatarValue);
      final avatarColorHex = prefs.getString(_keyAvatarColorHex);

      if (displayName == null && email == null) {
        return UserProfile.guest();
      }

      final avatarType = UserAvatarType.values.firstWhere(
            (e) => e.name == avatarTypeRaw,
        orElse: () => UserAvatarType.initials,
      );

      var profile = UserProfile(
        displayName: displayName ?? (email?.split('@').first ?? 'Khách'),
        email: email,
        avatarType: avatarType,
        avatarValue: avatarValue ?? (displayName?.isNotEmpty == true ? displayName![0].toUpperCase() : 'K'),
        avatarColorHex: avatarColorHex ?? '#10B981',
      );
      if (profile.avatarType == UserAvatarType.customImage) {
        final source = File(profile.avatarValue);
        if (!await source.exists()) {
          profile = profile.copyWith(
            avatarType: UserAvatarType.initials,
            avatarValue: profile.displayName.isNotEmpty
                ? profile.displayName[0].toUpperCase()
                : 'K',
          );
        } else {
          try {
            final owned = await importAvatar(source);
            if (owned.path != source.path &&
                await prefs.setString(_keyAvatarValue, owned.path)) {
              profile = profile.copyWith(avatarValue: owned.path);
              await markBackupDirty(prefs);
            }
          } catch (_) {
            // Keep a readable legacy image if migration is temporarily unavailable.
          }
        }
      }
      return profile;
    } catch (e) {
      debugPrint('AuthProfileService: Error loading profile: $e');
      return UserProfile.guest();
    }
  }

  /// Đăng nhập tài khoản Google và trích xuất hồ sơ cá nhân
  Future<UserProfile> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Người dùng đã hủy đăng nhập Google.');
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      // Lưu trữ an toàn Access Token & ID Token vào Secure Storage
      if (auth.accessToken != null) {
        await _secureStorage.write(
          key: _secureKeyGoogleAuthToken,
          value: auth.accessToken,
        );
      }
      if (auth.idToken != null) {
        await _secureStorage.write(
          key: _secureKeyGoogleIdToken,
          value: auth.idToken,
        );
      }

      final String name = account.displayName?.trim().isNotEmpty == true
          ? account.displayName!
          : account.email.split('@').first;

      // Tối ưu hóa chất lượng avatar Google lên chuẩn s256-c
      String? photoUrl = account.photoUrl;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        if (photoUrl.contains('=s')) {
          photoUrl = photoUrl.replaceAll(RegExp(r'=s\d+(-c)?'), '=s256-c');
        } else {
          photoUrl = '$photoUrl=s256-c';
        }
      }

      final UserAvatarType avatarType = (photoUrl != null && photoUrl.isNotEmpty)
          ? UserAvatarType.google
          : UserAvatarType.initials;

      final String avatarValue = photoUrl ?? (name.isNotEmpty ? name[0].toUpperCase() : 'G');
      const String avatarColorHex = '#10B981';

      final userProfile = UserProfile(
        displayName: name,
        email: account.email,
        avatarType: avatarType,
        avatarValue: avatarValue,
        avatarColorHex: avatarColorHex,
      );

      await _persistProfile(userProfile);
      await recoverPendingBackup(await SharedPreferences.getInstance());
      return userProfile;
    } catch (e) {
      debugPrint('AuthProfileService: signInWithGoogle error: $e');
      rethrow;
    }
  }

  /// Đăng xuất tài khoản Google và xóa token bảo mật
  /// (Dữ liệu SQLite cục bộ được giữ nguyên vẹn - Zero Account Lock-in)
  Future<UserProfile> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('AuthProfileService: Error during Google signOut: $e');
    }

    try {
      await _secureStorage.delete(key: _secureKeyGoogleAuthToken);
      await _secureStorage.delete(key: _secureKeyGoogleIdToken);
    } catch (e) {
      debugPrint('AuthProfileService: Error clearing secure storage: $e');
    }

    final guestProfile = UserProfile.guest();
    await _persistProfile(guestProfile);
    return guestProfile;
  }

  /// Cập nhật tên hiển thị
  Future<UserProfile> updateDisplayName(UserProfile current, String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Tên hiển thị không được để trống.');
    }

    String nextAvatarValue = current.avatarValue;
    if (current.avatarType == UserAvatarType.initials) {
      nextAvatarValue = trimmedName[0].toUpperCase();
    }

    final updated = current.copyWith(
      displayName: trimmedName,
      avatarValue: nextAvatarValue,
    );

    await _persistProfile(updated);
    return updated;
  }

  /// Cập nhật avatar tùy biến (Google / Ảnh máy / Emoji / Initials)
  Future<UserProfile> updateCustomAvatar(
    UserProfile current, {
    required UserAvatarType type,
    required String value,
    String? colorHex,
  }) async {
    if (type == UserAvatarType.customImage) {
      value = (await importAvatar(File(value))).path;
    }
    final updated = current.copyWith(
      avatarType: type,
      avatarValue: value,
      avatarColorHex: colorHex ?? current.avatarColorHex,
    );

    await _persistProfile(updated);
    return updated;
  }

  /// Lấy Google Access Token còn hạn từ Secure Storage
  Future<String?> getGoogleAccessToken() async {
    try {
      return await _secureStorage.read(key: _secureKeyGoogleAuthToken);
    } catch (e) {
      debugPrint('AuthProfileService: Error reading Google access token: $e');
      return null;
    }
  }

  /// Lưu trữ hồ sơ hiển thị vào SharedPreferences
  Future<void> _persistProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDisplayName, profile.displayName);

    if (profile.email != null) {
      await prefs.setString(_keyEmail, profile.email!);
    } else {
      await prefs.remove(_keyEmail);
    }

    await prefs.setString(_keyAvatarType, profile.avatarType.name);
    await prefs.setString(_keyAvatarValue, profile.avatarValue);
    await prefs.setString(_keyAvatarColorHex, profile.avatarColorHex);
    await markBackupDirty(prefs);
  }
}

// ==============================================================================
// RIVERPOD ARCHITECTURE PROVIDERS
// ==============================================================================

/// Singleton provider cho AuthProfileService
final authProfileServiceProvider = Provider<AuthProfileService>((ref) {
  return AuthProfileService();
});

/// StateNotifier quản lý phản ứng thời gian thực trạng thái UserProfile
class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  final AuthProfileService _service;

  UserProfileNotifier(this._service) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final profile = await _service.loadProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signInWithGoogle() async {
    final previous = state.valueOrNull ?? UserProfile.guest();
    state = const AsyncValue.loading();
    try {
      final newProfile = await _service.signInWithGoogle();
      state = AsyncValue.data(newProfile);
    } catch (e, st) {
      state = AsyncValue.data(previous);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      final guest = await _service.signOut();
      state = AsyncValue.data(guest);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateDisplayName(String newName) async {
    final current = state.valueOrNull ?? UserProfile.guest();
    try {
      final updated = await _service.updateDisplayName(current, newName);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateCustomAvatar({
    required UserAvatarType type,
    required String value,
    String? colorHex,
  }) async {
    final current = state.valueOrNull ?? UserProfile.guest();
    try {
      final updated = await _service.updateCustomAvatar(
        current,
        type: type,
        value: value,
        colorHex: colorHex,
      );
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// Provider phản ứng toàn cục để toàn bộ widget lắng nghe hồ sơ cá nhân
final userProfileNotifierProvider =
StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile>>((ref) {
  final service = ref.watch(authProfileServiceProvider);
  return UserProfileNotifier(service);
});

/// Provider tiện ích lấy nhanh đối tượng UserProfile hiện tại
final currentUserProfileProvider = Provider<UserProfile>((ref) {
  final asyncProfile = ref.watch(userProfileNotifierProvider);
  return asyncProfile.maybeWhen(
    data: (profile) => profile,
    orElse: () => UserProfile.guest(),
  );
});
