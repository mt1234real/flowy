// ==============================================================================
// File: lib/services/cloud_backup_service.dart
// Architecture: Google Drive AppData Cloud Backup Engine with Pre-Signout Safety Gate
// Stack: flutter_riverpod, googleapis, archive, encrypt, crypto, flutter_secure_storage, drift, shared_preferences
// Features:
// 1. Cross-Device Deterministic Key Derivation (Fix InvalidCipherTextException):
//    - Master Key 256-bit (32 bytes) phái sinh qua HMAC-SHA256 từ Google ID/Email + static pepper salt.
// 2. Pre-Signout Safety Gate & Diff Inspection (Zero Silent Data Loss):
//    - checkPreSignoutDiff(): So sánh metadata bản Cloud gần nhất với dữ liệu thực tế trong SQLite.
//    - createEmergencyLocalSnapshot(): Tạo snapshot an toàn 'old_account_unsaved.bak' trong thư mục documents.
//    - signOutAndClearSession(): Ngắt kết nối phiên Google Sign-In và reset trạng thái CSDL an toàn.
// 3. Self-Contained Binary Payload:
//    - [16 bytes IV] + [Ciphertext + Auth Tag GCM], giải mã an toàn chống crash.
// 4. Silent Auto-Detect & Rollback Snapshot:
//    - checkForNewerBackup(), performRestoreFromCloud(), notifyDataChanged() (Debounce 3 phút).
// ==============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';

/// Helper chuyển đổi và lọc sạch các trường properties nullable từ Google Drive API
Map<String, String> _sanitizeProperties(Map<String, String?>? raw) {
  if (raw == null) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.value != null) entry.key: entry.value!,
  };
}

/// Trạng thái tiến trình sao lưu đám mây thủ công
enum CloudBackupStatus {
  idle,
  checkpointing,
  encrypting,
  uploading,
  success,
  failure,
}

/// DTO thông tin bản sao lưu trên Google Drive AppData
class CloudBackupItem {
  final String fileId;
  final String fileName;
  final int sizeBytes;
  final DateTime createdTime;
  final Map<String, String> properties;

  const CloudBackupItem({
    required this.fileId,
    required this.fileName,
    required this.sizeBytes,
    required this.createdTime,
    required this.properties,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedDate {
    return DateFormat('dd/MM/yyyy HH:mm').format(createdTime.toLocal());
  }

  int get txCount => int.tryParse(properties['tx_count'] ?? '0') ?? 0;
  int get walletCount => int.tryParse(properties['wallet_count'] ?? '0') ?? 0;
  String get device => properties['device'] ?? 'Unknown';
  String? get latestTxDate => properties['latest_tx_date'];
}

/// DTO Báo cáo đối soát trước khi Đăng xuất (Pre-Signout Safety Diff Report)
class BackupDiffReport {
  final bool hasUnsavedChanges;
  final int localTxCount;
  final int cloudTxCount;
  final int localWalletCount;
  final int cloudWalletCount;
  final DateTime? localLatestTxDate;
  final DateTime? cloudBackupDate;
  final String userEmail;
  final int unsavedTxDifference;

  const BackupDiffReport({
    required this.hasUnsavedChanges,
    required this.localTxCount,
    required this.cloudTxCount,
    required this.localWalletCount,
    required this.cloudWalletCount,
    this.localLatestTxDate,
    this.cloudBackupDate,
    required this.userEmail,
    required this.unsavedTxDifference,
  });
}

/// State Model lưu trữ tiến độ và danh sách sao lưu thủ công
class CloudBackupState {
  final CloudBackupStatus status;
  final String? message;
  final double progress;
  final List<CloudBackupItem> backups;
  final DateTime? lastBackupTime;

  const CloudBackupState({
    required this.status,
    this.message,
    this.progress = 0.0,
    this.backups = const [],
    this.lastBackupTime,
  });

  CloudBackupState copyWith({
    CloudBackupStatus? status,
    String? message,
    double? progress,
    List<CloudBackupItem>? backups,
    DateTime? lastBackupTime,
  }) {
    return CloudBackupState(
      status: status ?? this.status,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      backups: backups ?? this.backups,
      lastBackupTime: lastBackupTime ?? this.lastBackupTime,
    );
  }
}

// ==============================================================================
// 🌟 METADATA & STATE CHO ĐỘNG CƠ TỰ ĐỘNG PHÁT HIỆN SAO LƯU (SILENT AUTO-LOAD)
// ==============================================================================

class CloudBackupMetadata {
  final String fileId;
  final DateTime updatedAt;
  final int transactionCount;
  final int walletCount;
  final DateTime? latestTxDate;

  const CloudBackupMetadata({
    required this.fileId,
    required this.updatedAt,
    required this.transactionCount,
    required this.walletCount,
    this.latestTxDate,
  });

  factory CloudBackupMetadata.fromDriveItem(CloudBackupItem item) {
    DateTime? parsedLatestTx;
    if (item.latestTxDate != null && item.latestTxDate!.isNotEmpty) {
      parsedLatestTx = DateTime.tryParse(item.latestTxDate!);
    }
    return CloudBackupMetadata(
      fileId: item.fileId,
      updatedAt: item.createdTime,
      transactionCount: item.txCount,
      walletCount: item.walletCount,
      latestTxDate: parsedLatestTx,
    );
  }
}

enum BackupSyncStatus {
  idle,
  checking,
  foundNewer,
  upToDate,
  error,
}

class BackupSyncState {
  final BackupSyncStatus status;
  final CloudBackupMetadata? cloudMetadata;
  final String? errorMessage;
  final bool isDismissed;

  const BackupSyncState({
    this.status = BackupSyncStatus.idle,
    this.cloudMetadata,
    this.errorMessage,
    this.isDismissed = false,
  });

  BackupSyncState copyWith({
    BackupSyncStatus? status,
    CloudBackupMetadata? cloudMetadata,
    String? errorMessage,
    bool? isDismissed,
  }) {
    return BackupSyncState(
      status: status ?? this.status,
      cloudMetadata: cloudMetadata ?? this.cloudMetadata,
      errorMessage: errorMessage ?? this.errorMessage,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}

// ==============================================================================
// 🌟 CLOUD BACKUP SERVICE CORE
// ==============================================================================

class CloudBackupService {
  static const String _appDataFolderName = 'appDataFolder';
  static const String _appFixedPepper = 'flowy_secure_vault_salt_2026_@#\$';

  final AppDatabase _db;
  final GoogleSignIn _googleSignIn;
  final Ref _ref;

  Timer? _debounceTimer;

  CloudBackupService({
    required AppDatabase db,
    required Ref ref,
    GoogleSignIn? googleSignIn,
  })  : _db = db,
        _ref = ref,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: [
                'email',
                'https://www.googleapis.com/auth/drive.appdata',
              ],
            );

  /// Kích hoạt bộ đếm debounce 3 phút sau mỗi lần ghi chép mới
  Future<void> notifyDataChanged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cadenceIndex = prefs.getInt('pfm_backup_cadence_mode') ?? 1;

      // 0 = afterEachEntry (Debounce 3 phút)
      if (cadenceIndex == 0) {
        _debounceTimer?.cancel();
        debugPrint('[Flowy Cloud] Nhận tín hiệu ghi chép mới. Lên lịch sao lưu sau 3 phút debounce...');

        _debounceTimer = Timer(const Duration(minutes: 3), () async {
          debugPrint('[Flowy Cloud] Đủ 3 phút debounce! Kích hoạt tự động sao lưu ngầm lên Google Drive...');
          try {
            await performBackup(silent: true);
          } catch (e) {
            debugPrint('[Flowy Cloud] Lỗi tự động sao lưu: $e');
          }
        });
      }
    } catch (e) {
      debugPrint('[Flowy Cloud] Lỗi notifyDataChanged: $e');
    }
  }

  /// Khởi tạo Google Drive API client có chứng thực
  Future<drive.DriveApi> _getDriveApi() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    account ??= await _googleSignIn.signIn();

    if (account == null) {
      throw Exception('Chưa đăng nhập Google hoặc người dùng hủy xác thực.');
    }

    final authClient = await _googleSignIn.authenticatedClient();
    if (authClient == null) {
      throw Exception('Không thể tạo HTTP Auth Client cho Google Drive.');
    }

    return drive.DriveApi(authClient);
  }

  /// Khóa 256-bit (32 bytes) phái sinh thống nhất bằng HMAC-SHA256
  Future<List<int>> _getOrCreateDeterministicKey() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();

    final userIdentifier = (account?.id != null && account!.id.isNotEmpty)
        ? account.id.trim()
        : (account?.email.toLowerCase().trim() ?? 'flowy_universal_user_account');

    final pepperBytes = utf8.encode(_appFixedPepper);
    final dataBytes = utf8.encode(userIdentifier);

    final hmacSha256 = Hmac(sha256, pepperBytes);
    final digest = hmacSha256.convert(dataBytes);

    return digest.bytes;
  }

  /// 🌟 KIỂM TRA ĐỐI SOÁT TRƯỚC KHI ĐĂNG XUẤT (PRE-SIGNOUT DIFF)
  Future<BackupDiffReport> checkPreSignoutDiff() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    final userEmail = account?.email ?? 'Tài khoản hiện tại';

    // 1. Lấy dữ liệu SQLite cục bộ
    final localTxs = await _db.select(_db.transactions).get();
    final localDebtTxs = await _db.select(_db.debtTransactions).get();
    final localWallets = await _db.select(_db.wallets).get();

    final int totalLocalTxCount = localTxs.length + localDebtTxs.length;
    final int totalLocalWalletCount = localWallets.length;

    DateTime? latestLocalTxDate;
    for (final t in localTxs) {
      if (latestLocalTxDate == null || t.date.isAfter(latestLocalTxDate)) {
        latestLocalTxDate = t.date;
      }
    }
    for (final d in localDebtTxs) {
      if (latestLocalTxDate == null || d.date.isAfter(latestLocalTxDate)) {
        latestLocalTxDate = d.date;
      }
    }

    // 2. Lấy metadata bản Cloud gần nhất
    int cloudTx = 0;
    int cloudWallets = 0;
    DateTime? cloudBackupDate;

    try {
      final backups = await listBackups();
      if (backups.isNotEmpty) {
        final newest = backups.first;
        cloudTx = newest.txCount;
        cloudWallets = newest.walletCount;
        cloudBackupDate = newest.createdTime;
      }
    } catch (_) {}

    // So sánh xem có dữ liệu chưa được sao lưu không
    final int diff = totalLocalTxCount - cloudTx;
    bool hasUnsaved = false;

    if (totalLocalTxCount > 0 && cloudTx == 0) {
      hasUnsaved = true;
    } else if (diff > 0) {
      hasUnsaved = true;
    } else if (latestLocalTxDate != null && cloudBackupDate != null) {
      if (latestLocalTxDate.isAfter(cloudBackupDate)) {
        hasUnsaved = true;
      }
    }

    return BackupDiffReport(
      hasUnsavedChanges: hasUnsaved,
      localTxCount: totalLocalTxCount,
      cloudTxCount: cloudTx,
      localWalletCount: totalLocalWalletCount,
      cloudWalletCount: cloudWallets,
      localLatestTxDate: latestLocalTxDate,
      cloudBackupDate: cloudBackupDate,
      userEmail: userEmail,
      unsavedTxDifference: diff > 0 ? diff : 0,
    );
  }

  /// 🌟 TẠO BẢN SAO LƯU DỰ PHÒNG KHẨN CẤP TRÊN MÁY (EMERGENCY SNAPSHOT)
  Future<void> createEmergencyLocalSnapshot() async {
    try {
      await _db.customStatement('PRAGMA wal_checkpoint(FULL);');

      final dbFolder = await getApplicationDocumentsDirectory();
      final mainDbFile = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite'));
      final emergencyFile = File(p.join(dbFolder.path, 'old_account_unsaved.bak'));

      if (await mainDbFile.exists()) {
        await mainDbFile.copy(emergencyFile.path);
        debugPrint('[Flowy Cloud] Đã tạo emergency snapshot an toàn: ${emergencyFile.path}');
      }
    } catch (e) {
      debugPrint('[Flowy Cloud] Lỗi tạo emergency snapshot: $e');
    }
  }

  /// 🌟 NGẮT PHIÊN GOOGLE VÀ LÀM SẠCH KẾT NỐI (ZERO DATA LOCK-IN)
  Future<void> signOutAndClearSession() async {
    _debounceTimer?.cancel();
    await _googleSignIn.signOut();

    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'google_user_profile');
    await secureStorage.delete(key: 'flowy_master_key_aes256');

    _ref.invalidate(databaseProvider);
  }

  /// Thực thi sao lưu và đồng bộ StateNotifier
  Future<CloudBackupItem> performBackup({bool silent = false}) async {
    final notifier = _ref.read(cloudBackupNotifierProvider.notifier);

    if (!silent) {
      notifier.updateStateForStart();
    }

    try {
      final item = await createBackup(
        onProgress: (status, message, progress) {
          if (!silent) {
            notifier.updateProgress(status, message, progress);
          }
        },
      );

      notifier.updateSuccess(item);
      _ref.read(backupSyncNotifierProvider.notifier).markAsUpToDate();
      return item;
    } catch (e) {
      if (!silent) {
        notifier.updateFailure('Lỗi sao lưu: ${e.toString().replaceAll('Exception: ', '')}');
      }
      rethrow;
    }
  }

  /// Tạo bản sao lưu hoàn chỉnh lên Google Drive AppData
  Future<CloudBackupItem> createBackup({
    void Function(CloudBackupStatus status, String message, double progress)? onProgress,
  }) async {
    Directory? tempDir;
    try {
      onProgress?.call(CloudBackupStatus.checkpointing, 'Đang đồng bộ sổ cái CSDL...', 0.15);

      await _db.customStatement('PRAGMA wal_checkpoint(FULL);');

      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite'));

      if (!await dbFile.exists()) {
        throw Exception('Không tìm thấy tệp cơ sở dữ liệu gốc: pfm_local_vault.sqlite');
      }

      final cacheDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      tempDir = Directory(p.join(cacheDir.path, 'backup_$timestamp'))..createSync(recursive: true);

      final tempDbCopy = File(p.join(tempDir.path, 'pfm_local_vault.sqlite'));
      await dbFile.copy(tempDbCopy.path);

      onProgress?.call(CloudBackupStatus.encrypting, 'Đang nén và mã hóa AES-GCM 256-bit...', 0.40);

      // 1. Nén ZIP
      final zipFilePath = p.join(tempDir.path, 'database.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);
      await encoder.addFile(tempDbCopy);
      encoder.close();

      final zipBytes = await File(zipFilePath).readAsBytes();

      // 2. Mã hóa AES-GCM 256-bit với Deterministic Cross-Device Key
      final keyBytes = await _getOrCreateDeterministicKey();
      final key = enc.Key(Uint8List.fromList(keyBytes));

      final secureRandom = Random.secure();
      final ivBytes = Uint8List.fromList(List<int>.generate(16, (_) => secureRandom.nextInt(256)));
      final iv = enc.IV(ivBytes);

      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      final encryptedData = encrypter.encryptBytes(zipBytes, iv: iv);

      // Cấu trúc payload chuẩn: [16 bytes IV] + [Ciphertext + Auth Tag]
      final payload = BytesBuilder(copy: false)
        ..add(ivBytes)
        ..add(encryptedData.bytes);

      final finalEncryptedFile = File(p.join(tempDir.path, 'pfm_vault_backup_$timestamp.enc'));
      await finalEncryptedFile.writeAsBytes(payload.toBytes(), flush: true);

      onProgress?.call(CloudBackupStatus.uploading, 'Đang tải lên thư mục an toàn Google Drive...', 0.70);

      // 3. Tải lên Google Drive AppData
      final driveApi = await _getDriveApi();
      final txs = await _db.select(_db.transactions).get();
      final debtTxs = await _db.select(_db.debtTransactions).get();
      final wallets = await _db.select(_db.wallets).get();

      DateTime? maxTxDate;
      for (final t in txs) {
        if (maxTxDate == null || t.date.isAfter(maxTxDate)) {
          maxTxDate = t.date;
        }
      }
      for (final d in debtTxs) {
        if (maxTxDate == null || d.date.isAfter(maxTxDate)) {
          maxTxDate = d.date;
        }
      }

      final driveFile = drive.File()
        ..name = 'pfm_vault_backup_$timestamp.enc'
        ..parents = [_appDataFolderName]
        ..description = 'PFM Vault Encrypted Backup'
        ..properties = {
          'version': '3',
          'schema_version': _db.schemaVersion.toString(),
          'device': Platform.operatingSystem,
          'tx_count': (txs.length + debtTxs.length).toString(),
          'wallet_count': wallets.length.toString(),
          'latest_tx_date': maxTxDate?.toIso8601String() ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        };

      final media = drive.Media(
        finalEncryptedFile.openRead(),
        await finalEncryptedFile.length(),
      );

      final uploadedFile = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id, name, size, createdTime, properties',
      );

      onProgress?.call(CloudBackupStatus.success, 'Sao lưu thành công lên Google Drive!', 1.0);

      return CloudBackupItem(
        fileId: uploadedFile.id ?? '',
        fileName: uploadedFile.name ?? 'pfm_vault_backup_$timestamp.enc',
        sizeBytes: int.tryParse(uploadedFile.size ?? '0') ?? await finalEncryptedFile.length(),
        createdTime: uploadedFile.createdTime ?? DateTime.now(),
        properties: _sanitizeProperties(uploadedFile.properties),
      );
    } catch (e) {
      debugPrint('CloudBackupService: createBackup error: $e');
      onProgress?.call(CloudBackupStatus.failure, 'Lỗi sao lưu: $e', 0.0);
      rethrow;
    } finally {
      if (tempDir != null && tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Liệt kê danh sách các bản sao lưu từ thư mục ẩn appDataFolder
  Future<List<CloudBackupItem>> listBackups() async {
    try {
      final driveApi = await _getDriveApi();

      final fileList = await driveApi.files.list(
        spaces: _appDataFolderName,
        orderBy: 'createdTime desc',
        pageSize: 30,
        $fields: 'files(id, name, size, createdTime, properties)',
      );

      final items = <CloudBackupItem>[];
      for (final f in fileList.files ?? <drive.File>[]) {
        if (f.name != null && f.name!.startsWith('pfm_vault_backup_') && f.name!.endsWith('.enc')) {
          items.add(
            CloudBackupItem(
              fileId: f.id ?? '',
              fileName: f.name ?? 'backup.enc',
              sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
              createdTime: f.createdTime ?? DateTime.now(),
              properties: _sanitizeProperties(f.properties),
            ),
          );
        }
      }

      return items;
    } catch (e) {
      debugPrint('CloudBackupService: listBackups error: $e');
      rethrow;
    }
  }

  /// Tải về và giải mã an toàn đa thiết bị (Chống văng Exception InvalidCipherTextException)
  Future<File> downloadAndDecryptBackup(String fileId) async {
    Directory? tempDir;
    try {
      final driveApi = await _getDriveApi();

      final drive.Media media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final cacheDir = await getTemporaryDirectory();
      tempDir = Directory(p.join(cacheDir.path, 'restore_${DateTime.now().millisecondsSinceEpoch}'))
        ..createSync(recursive: true);

      final encFile = File(p.join(tempDir.path, 'downloaded.enc'));
      final sink = encFile.openWrite();
      await media.stream.pipe(sink);
      await sink.close();

      final fileBytes = await encFile.readAsBytes();
      if (fileBytes.length <= 16) {
        throw Exception('Tệp sao lưu bị lỗi hoặc kích thước không hợp lệ.');
      }

      // Trích xuất chính xác 16 bytes IV từ header
      final ivBytes = Uint8List.sublistView(fileBytes, 0, 16);
      final cipherBytes = Uint8List.sublistView(fileBytes, 16);

      final keyBytes = await _getOrCreateDeterministicKey();
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV(ivBytes);

      List<int> decryptedZipBytes;
      try {
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
        decryptedZipBytes = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
      } catch (e) {
        debugPrint('[CloudBackupService] Lỗi giải mã AES: $e');
        throw Exception('Bản sao lưu không tương thích hoặc được tạo từ một tài khoản Google khác.');
      }

      final archive = ZipDecoder().decodeBytes(decryptedZipBytes);
      File? extractedSqliteFile;

      for (final file in archive) {
        if (file.isFile && file.name.endsWith('.sqlite')) {
          extractedSqliteFile = File(p.join(tempDir.path, 'decrypted_inspection.sqlite'));
          await extractedSqliteFile.writeAsBytes(file.content as List<int>, flush: true);
          break;
        }
      }

      if (extractedSqliteFile == null || !extractedSqliteFile.existsSync()) {
        throw Exception('Không tìm thấy tệp CSDL hợp lệ trong file nén sao lưu.');
      }

      return extractedSqliteFile;
    } catch (e) {
      debugPrint('CloudBackupService: downloadAndDecryptBackup error: $e');
      rethrow;
    }
  }

  /// 🌟 THỰC THI KHÔI PHỤC TỪ CLOUD CÓ TẠO SNAPSHOT .BAK ROLLBACK
  Future<void> performRestoreFromCloud(String fileId) async {
    File? decryptedFile;
    try {
      decryptedFile = await downloadAndDecryptBackup(fileId);

      // 1. Ép xả WAL log
      await _db.customStatement('PRAGMA wal_checkpoint(FULL);');

      final dbFolder = await getApplicationDocumentsDirectory();
      final mainDbFile = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite'));
      final walFile = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite-wal'));
      final shmFile = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite-shm'));
      final backupBakFile = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite.bak'));

      // 2. Tạo snapshot an toàn pfm_local_vault.sqlite.bak
      if (await mainDbFile.exists()) {
        await mainDbFile.copy(backupBakFile.path);
      }

      // 3. Xóa các tệp phụ WAL và SHM
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      // 4. Ghi đè file mới từ Cloud
      await decryptedFile.copy(mainDbFile.path);

      // 5. Invalidate toàn bộ providers CSDL
      _ref.invalidate(databaseProvider);
      _ref.read(backupSyncNotifierProvider.notifier).markAsUpToDate();
    } finally {
      if (decryptedFile != null && decryptedFile.existsSync()) {
        try {
          decryptedFile.parent.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  /// Xóa một bản sao lưu trên Google Drive AppData
  Future<void> deleteBackup(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      await driveApi.files.delete(fileId);
    } catch (e) {
      debugPrint('CloudBackupService: deleteBackup error: $e');
      rethrow;
    }
  }
}

// ==============================================================================
// 🌟 RIVERPOD STATE: BACKUP SYNC NOTIFIER (SILENT AUTO-DETECT ENGINE)
// ==============================================================================

class BackupSyncNotifier extends StateNotifier<BackupSyncState> {
  final CloudBackupService _service;
  final AppDatabase _db;
  final GoogleSignIn _googleSignIn;

  BackupSyncNotifier(this._service, this._db, this._googleSignIn)
      : super(const BackupSyncState()) {
    checkForNewerBackup();
  }

  void dismissBanner() {
    state = state.copyWith(isDismissed: true);
  }

  void markAsUpToDate() {
    state = state.copyWith(status: BackupSyncStatus.upToDate, isDismissed: true);
  }

  /// Quét ngầm Google Drive appDataFolder và so sánh thời gian giao dịch mới nhất
  Future<void> checkForNewerBackup() async {
    if (_googleSignIn.currentUser == null) {
      state = state.copyWith(status: BackupSyncStatus.idle);
      return;
    }

    state = state.copyWith(status: BackupSyncStatus.checking);

    try {
      final backups = await _service.listBackups();
      if (backups.isEmpty) {
        state = state.copyWith(status: BackupSyncStatus.upToDate);
        return;
      }

      final newestCloud = backups.first;
      final localTxs = await _db.select(_db.transactions).get();
      final localDebtTxs = await _db.select(_db.debtTransactions).get();

      DateTime? latestLocalTxDate;
      for (final tx in localTxs) {
        if (latestLocalTxDate == null || tx.date.isAfter(latestLocalTxDate)) {
          latestLocalTxDate = tx.date;
        }
      }
      for (final d in localDebtTxs) {
        if (latestLocalTxDate == null || d.date.isAfter(latestLocalTxDate)) {
          latestLocalTxDate = d.date;
        }
      }

      final cloudMetadata = CloudBackupMetadata.fromDriveItem(newestCloud);
      final cloudLatestTxDate = cloudMetadata.latestTxDate;
      final cloudBackupTime = cloudMetadata.updatedAt;

      bool isCloudNewer = false;
      if (latestLocalTxDate == null) {
        isCloudNewer = cloudMetadata.transactionCount > 0;
      } else {
        if (cloudLatestTxDate != null && cloudLatestTxDate.isAfter(latestLocalTxDate)) {
          isCloudNewer = true;
        } else if (cloudBackupTime.isAfter(latestLocalTxDate) &&
            cloudMetadata.transactionCount > (localTxs.length + localDebtTxs.length)) {
          isCloudNewer = true;
        }
      }

      if (isCloudNewer) {
        state = state.copyWith(
          status: BackupSyncStatus.foundNewer,
          cloudMetadata: cloudMetadata,
          isDismissed: false,
        );
      } else {
        state = state.copyWith(status: BackupSyncStatus.upToDate);
      }
    } catch (e) {
      debugPrint('[BackupSyncNotifier] Lỗi quét kiểm tra backup: $e');
      state = state.copyWith(
        status: BackupSyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Khôi phục dữ liệu từ Cloud thông qua Service
  Future<void> restoreCloudBackup(String fileId) async {
    await _service.performRestoreFromCloud(fileId);
  }
}

final backupSyncNotifierProvider =
StateNotifierProvider<BackupSyncNotifier, BackupSyncState>((ref) {
  final service = ref.watch(cloudBackupServiceProvider);
  final db = ref.watch(databaseProvider);
  final googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/drive.appdata'],
  );
  return BackupSyncNotifier(service, db, googleSignIn);
});

// ==============================================================================
// 🌟 RIVERPOD STATE ARCHITECTURE PROVIDERS
// ==============================================================================

final cloudBackupServiceProvider = Provider<CloudBackupService>((ref) {
  final db = ref.watch(databaseProvider);
  return CloudBackupService(db: db, ref: ref);
});

class CloudBackupNotifier extends StateNotifier<CloudBackupState> {
  final CloudBackupService _service;

  CloudBackupNotifier(this._service)
      : super(const CloudBackupState(status: CloudBackupStatus.idle)) {
    loadBackups();
  }

  void updateStateForStart() {
    state = state.copyWith(
      status: CloudBackupStatus.checkpointing,
      message: 'Bắt đầu quá trình sao lưu...',
      progress: 0.05,
    );
  }

  void updateProgress(CloudBackupStatus status, String message, double progress) {
    state = state.copyWith(
      status: status,
      message: message,
      progress: progress,
    );
  }

  void updateSuccess(CloudBackupItem item) {
    final updatedBackups = [item, ...state.backups];
    state = state.copyWith(
      status: CloudBackupStatus.success,
      message: 'Sao lưu thành công lúc ${DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now())}',
      progress: 1.0,
      backups: updatedBackups,
      lastBackupTime: item.createdTime,
    );
  }

  void updateFailure(String errorMessage) {
    state = state.copyWith(
      status: CloudBackupStatus.failure,
      message: errorMessage,
      progress: 0.0,
    );
  }

  Future<void> loadBackups() async {
    try {
      final backups = await _service.listBackups();
      DateTime? latestTime;
      if (backups.isNotEmpty) {
        latestTime = backups.first.createdTime;
      }
      state = state.copyWith(
        backups: backups,
        lastBackupTime: latestTime,
      );
    } catch (e) {
      debugPrint('CloudBackupNotifier: loadBackups error: $e');
    }
  }

  Future<void> performBackup() async {
    await _service.performBackup(silent: false);
  }

  Future<void> deleteBackup(String fileId) async {
    try {
      await _service.deleteBackup(fileId);
      final updatedList = state.backups.where((b) => b.fileId != fileId).toList();
      state = state.copyWith(backups: updatedList);
    } catch (e) {
      debugPrint('CloudBackupNotifier: deleteBackup error: $e');
      rethrow;
    }
  }
}

final cloudBackupNotifierProvider =
StateNotifierProvider<CloudBackupNotifier, CloudBackupState>((ref) {
  final service = ref.watch(cloudBackupServiceProvider);
  return CloudBackupNotifier(service);
});