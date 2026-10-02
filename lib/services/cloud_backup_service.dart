// ==============================================================================
// File: lib/services/cloud_backup_service.dart
// Architecture: Google Drive AppData Cloud Backup Engine with Pre-Signout Safety Gate
// Stack: flutter_riverpod, googleapis, archive, encrypt, crypto, flutter_secure_storage, drift, shared_preferences
// Features:
// 1. V2 account-scoped random master keys stored separately in Drive appData.
//    Legacy deterministic V1 is supported only for decryption.
// 2. Pre-Signout Safety Gate & Diff Inspection (Zero Silent Data Loss):
//    - checkPreSignoutDiff(): So sánh metadata bản Cloud gần nhất với dữ liệu thực tế trong SQLite.
//    - createEmergencyLocalSnapshot(): Tạo snapshot an toàn 'old_account_unsaved.bak' trong thư mục documents.
//    - signOutAndClearSession(): Ngắt kết nối phiên Google Sign-In và reset trạng thái CSDL an toàn.
// 3. Self-Contained Binary Payload:
//    - Versioned authenticated V2 envelope around the unchanged inner capsule.
// 4. Silent Auto-Detect & Rollback Snapshot:
//    - checkForNewerBackup(), performRestoreFromCloud(), notifyDataChanged() (Debounce 3 phút).
// ==============================================================================

import 'dart:async';
import 'fiscal_day.dart';
import 'dart:convert';
import 'dart:io';

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
import '../theme/app_theme.dart';
import '../widgets/backup_progress_curtain.dart';
import '../features/notifications/notification_preferences.dart';
import '../features/insights/insights_data.dart';
import '../screens/ledger_screen.dart' show cycleStartDaysByMonthProvider;
import 'auth_profile_service.dart';
import 'vault_security_service.dart';
import 'backup_capsule.dart';
import 'backup_database_normalizer.dart' as backup_database;
import 'backup_schedule.dart';
import 'backup_state.dart';
import 'backup_crypto.dart';
import 'backup_account_key.dart';

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
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
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

  final AppDatabase _db;
  final GoogleSignIn _googleSignIn;
  final Ref _ref;
  final drive.DriveApi? _driveApiOverride;

  Timer? _debounceTimer;
  bool _silentAuth = false;

  CloudBackupService({
    required AppDatabase db,
    required Ref ref,
    GoogleSignIn? googleSignIn,
    drive.DriveApi? driveApi,
  })  : _db = db,
        _ref = ref,
        _driveApiOverride = driveApi,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: [
                'email',
                'https://www.googleapis.com/auth/drive.appdata',
              ],
            );

  /// Kích hoạt bộ đếm debounce 3 phút sau mỗi lần ghi chép mới
  Future<void> notifyDataChanged() async {
    final prefs = await SharedPreferences.getInstance();
    await markBackupDirty(prefs);
  }

  /// Khởi tạo Google Drive API client có chứng thực
  Future<({drive.DriveApi api, String accountId})> _getDriveSession() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    account ??= await _googleSignIn.signInSilently();
    if (!_silentAuth) account ??= await _googleSignIn.signIn();

    if (account == null) {
      throw const BackupAuthenticationFailure();
    }

    final accountId = account.id.trim();
    if (_driveApiOverride != null) {
      return (api: _driveApiOverride, accountId: accountId);
    }
    if (_googleSignIn.currentUser?.id.trim() != accountId) {
      throw const BackupAuthenticationFailure();
    }

    final authClient = await _googleSignIn.authenticatedClient();
    if (authClient == null ||
        _googleSignIn.currentUser?.id.trim() != accountId) {
      authClient?.close();
      throw const BackupAuthenticationFailure();
    }

    return (api: drive.DriveApi(authClient), accountId: accountId);
  }

  Future<drive.DriveApi> _getDriveApi() async => (await _getDriveSession()).api;

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
      hasUnsavedChanges: hasUnsaved ||
          (await BackupStateStore(await SharedPreferences.getInstance()).read())
              .dirty,
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
    final folder = await getApplicationDocumentsDirectory();
    final file = File(p.join(folder.path,
        'old_account_unsaved_${DateTime.now().microsecondsSinceEpoch}.bak'));
    await _db.customStatement('VACUUM INTO ?', [file.path]);
  }

  /// 🌟 NGẮT PHIÊN GOOGLE VÀ LÀM SẠCH KẾT NỐI (ZERO DATA LOCK-IN)
  Future<void> signOutAndClearSession() async {
    _debounceTimer?.cancel();
    await clearBackupKeyCache();
    await _googleSignIn.signOut();

    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'google_user_profile');
    await secureStorage.delete(key: 'flowy_master_key_aes256');

    _ref.invalidate(databaseProvider);
  }

  /// Thực thi sao lưu và đồng bộ StateNotifier
  Future<CloudBackupItem> performBackup({bool silent = false}) async {
    if (_busy || _attempting) throw StateError('Một tác vụ sao lưu đang chạy');
    _silentAuth = silent;
    final notifier = _ref.read(cloudBackupNotifierProvider.notifier);

    if (!silent) {
      notifier.updateStateForStart();
    }

    _attempting = true;
    try {
      final store = BackupStateStore(await SharedPreferences.getInstance());
      final item = await runBackupAttempt(
          store,
          () => createBackup(
                onProgress: (status, message, progress) {
                  if (!silent) {
                    notifier.updateProgress(status, message, progress);
                  }
                },
              ),
          uploadedAt: (item) => item.createdTime);
      notifier.updateSuccess(item);
      if (!silent && !(await store.read()).dirty) {
        _ref.read(backupSyncNotifierProvider.notifier).markAsUpToDate();
      }
      return item;
    } catch (e) {
      if (!silent) {
        notifier.updateFailure(backupFailureMessage(e));
      }
      rethrow;
    } finally {
      _attempting = false;
    }
  }

  /// Tạo bản sao lưu hoàn chỉnh lên Google Drive AppData
  static bool _busy = false;
  static bool _attempting = false;

  Future<CloudBackupItem> createBackup({
    void Function(CloudBackupStatus status, String message, double progress)?
        onProgress,
  }) async {
    if (_busy) throw StateError('Một tác vụ sao lưu đang chạy');
    _busy = true;
    final progress = _ref.read(backupOperationProvider.notifier);
    progress.state = 'Đang chuẩn bị bản sao lưu…';
    Directory? tempDir;
    try {
      final session = await _getDriveSession();
      final driveApi = session.api;
      onProgress?.call(
          CloudBackupStatus.checkpointing, 'Đang đồng bộ sổ cái CSDL...', 0.15);

      await _db.customStatement('PRAGMA wal_checkpoint(FULL);');

      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite'));

      if (!await dbFile.exists()) {
        throw Exception(
            'Không tìm thấy tệp cơ sở dữ liệu gốc: pfm_local_vault.sqlite');
      }

      final cacheDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      await cacheDir.create(recursive: true);
      tempDir = await cacheDir.createTemp('backup_${timestamp}_');

      final tempDbCopy = File(p.join(tempDir.path, 'pfm_local_vault.sqlite'));
      await _db.customStatement('VACUUM INTO ?', [tempDbCopy.path]);
      final prefs = await SharedPreferences.getInstance();
      final preferences = await exportBackupPreferences(prefs);
      preferences['notification_cycle_snapshot'] =
          jsonEncode(_ref.read(cycleStartDaysByMonthProvider));
      final security =
          await _ref.read(vaultSecurityServiceProvider).exportManifest();
      security['biometricsEnabled'] =
          prefs.getBool('vault_biometrics_enabled') ?? true;
      for (final entry in {
        'preferences_manifest.json': preferences,
        'security_manifest.json': security,
        'backup_metadata.json': {
          'version': 4,
          'schema_version': _db.schemaVersion,
          'created_at': DateTime.now().toIso8601String(),
          'device': Platform.operatingSystem
        },
      }.entries) {
        await File(p.join(tempDir.path, entry.key))
            .writeAsString(jsonEncode(entry.value), flush: true);
      }

      onProgress?.call(CloudBackupStatus.encrypting,
          'Đang nén và mã hóa AES-GCM 256-bit...', 0.40);

      progress.state = 'Đang nén và mã hóa bản sao lưu…';
      final accountId = session.accountId;
      final master =
          await AccountBackupKeys(accountId, DriveBackupKeyRemote(driveApi))
              .forBackup();
      final encryptedPath = await compute(packBackup, {
        'folder': tempDir.path,
        'master': master.bytes,
        'accountId': accountId
      });
      final finalEncryptedFile = File(encryptedPath);
      progress.state = 'Đang tải bản sao lưu lên Google Drive…';

      onProgress?.call(CloudBackupStatus.uploading,
          'Đang tải lên thư mục an toàn Google Drive...', 0.70);

      // 3. Tải lên Google Drive AppData
      final statistics = await compute(backupStatistics, tempDbCopy.path);
      final latest = statistics['latest']!;
      final maxTxDate = latest == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(latest * 1000);

      final driveFile = drive.File()
        ..name = 'pfm_vault_backup_$timestamp.enc'
        ..parents = [_appDataFolderName]
        ..description = 'PFM Vault Encrypted Backup'
        ..properties = {
          'encryption_version': '2',
          'encryption_key_id': master.id,
          'version': '4',
          'theme': prefs.getString(kPrefKeyAccentPreset) ?? 'grass',
          'font':
              prefs.getString(kPrefKeyCurrencyFont) ?? kCurrencyFontFollowApp,
          'has_preferences': 'true',
          'has_vault_pin': 'true',
          'schema_version': _db.schemaVersion.toString(),
          'device': Platform.operatingSystem,
          'tx_count': statistics['transactions'].toString(),
          'wallet_count': statistics['wallets'].toString(),
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

      onProgress?.call(CloudBackupStatus.success,
          'Sao lưu thành công lên Google Drive!', 1.0);

      return CloudBackupItem(
        fileId: uploadedFile.id ?? '',
        fileName: uploadedFile.name ?? 'pfm_vault_backup_$timestamp.enc',
        sizeBytes: int.tryParse(uploadedFile.size ?? '0') ??
            await finalEncryptedFile.length(),
        createdTime: uploadedFile.createdTime ?? DateTime.now(),
        properties: _sanitizeProperties(uploadedFile.properties),
      );
    } catch (e) {
      debugPrint('CloudBackupService: createBackup error: $e');
      onProgress?.call(CloudBackupStatus.failure, 'Lỗi sao lưu: $e', 0.0);
      rethrow;
    } finally {
      _busy = false;
      progress.state = null;
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
        q: "name contains 'pfm_vault_backup_'",
        orderBy: 'createdTime desc',
        pageSize: 30,
        $fields: 'files(id, name, size, createdTime, properties)',
      );

      final items = <CloudBackupItem>[];
      for (final f in fileList.files ?? <drive.File>[]) {
        if (f.name != null &&
            f.name!.startsWith('pfm_vault_backup_') &&
            f.name!.endsWith('.enc')) {
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
      final session = await _getDriveSession();
      final driveApi = session.api;
      final fileMetadata =
          await driveApi.files.get(fileId, $fields: 'properties') as drive.File;
      final expectedVersion = fileMetadata.properties?['encryption_version'];
      if (expectedVersion != null && expectedVersion != '2') {
        throw const BackupCryptoFailure(BackupCryptoError.unsupported);
      }

      final drive.Media media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final cacheDir = await getTemporaryDirectory();
      tempDir = Directory(p.join(
          cacheDir.path, 'restore_${DateTime.now().millisecondsSinceEpoch}'))
        ..createSync(recursive: true);

      final encFile = File(p.join(tempDir.path, 'downloaded.enc'));
      final sink = encFile.openWrite();
      await media.stream.pipe(sink);
      await sink.close();

      final accountId = session.accountId;
      final headerFile = await encFile.open();
      final List<int> header;
      try {
        header = await headerFile.read(backupV2HeaderSize);
      } finally {
        await headerFile.close();
      }
      final keyId = backupEnvelopeKeyId(header);
      if (expectedVersion == '2' && keyId == null) {
        throw const BackupCryptoFailure(BackupCryptoError.malformed);
      }
      final master = keyId == null
          ? null
          : await AccountBackupKeys(accountId, DriveBackupKeyRemote(driveApi))
              .forRestore(keyId);
      final extracted = await compute(unpackBackup, {
        'folder': tempDir.path,
        'accountId': accountId,
        if (master != null) 'master': master.bytes,
        'schema': _db.schemaVersion
      });
      return await prepareBackupForInspection(File(extracted));
    } catch (e) {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  /// 🌟 THỰC THI KHÔI PHỤC TỪ CLOUD CÓ TẠO SNAPSHOT .BAK ROLLBACK
  Future<void> performRestoreFromCloud(String fileId) async {
    final file = await downloadAndDecryptBackup(fileId);
    try {
      final snapshot = await snapshotForInspection();
      try {
        final statistics = backupStatistics(snapshot.path);
        if (statistics['transactions']! > 0 || statistics['wallets']! > 0) {
          throw StateError(
              'Thiết bị đã có dữ liệu. Hãy mở Chi tiết bản sao lưu để đối soát trước.');
        }
      } finally {
        await snapshot.parent.delete(recursive: true);
      }
      await restorePreparedBackup(file);
    } finally {
      if (await file.parent.exists()) await file.parent.delete(recursive: true);
    }
  }

  Future<File> snapshotForInspection() async {
    final folder = await getTemporaryDirectory();
    await folder.create(recursive: true);
    final dir = await folder.createTemp('flowy_inspection_');
    final file = File(p.join(dir.path, 'local.sqlite'));
    await _db.customStatement('VACUUM INTO ?', [file.path]);
    return file;
  }

  Future<File> prepareBackupForInspection(File source) async => File(
      await compute(backup_database.prepareBackupForInspection, source.path));

  /// The prepared file is a validated staging copy; no live DB is overwritten
  /// until a durable local recovery set exists and Drift has fully closed.
  Future<void> restorePreparedBackup(File file,
      {BackupReconciliation? reconciliation,
      Set<String> selected = const {},
      Map<String, String> walletMapping = const {}}) async {
    if (_busy) throw StateError('Một tác vụ sao lưu đang chạy');
    _busy = true;
    _debounceTimer?.cancel();
    final progress = _ref.read(backupOperationProvider.notifier);
    progress.state = 'Đang kiểm tra bản khôi phục…';
    late SharedPreferences prefs;
    late Map<String, Object> beforePrefs;
    late Map<String, dynamic> beforeSecurity;
    late File mainFile;
    late Directory recovery;
    RandomAccessFile? restoreGuard;
    var closed = false;
    var replacing = false;
    File? stagedFile;
    try {
      stagedFile = await file.copy(p.join(file.parent.path,
          'staged_${DateTime.now().microsecondsSinceEpoch}.sqlite'));
      // Reject or migrate before taking read-only rollback snapshots.
      await compute(backup_database.normalizeStagedBackup, stagedFile.path);
      prefs = await SharedPreferences.getInstance();
      beforePrefs = await exportBackupPreferences(prefs);
      final securityService = _ref.read(vaultSecurityServiceProvider);
      beforeSecurity = await securityService.snapshotPersistedState();
      final folder = await getApplicationDocumentsDirectory();
      mainFile = File(p.join(folder.path, 'pfm_local_vault.sqlite'));
      recovery = Directory(p.join(folder.path, 'restore_recovery'));
      if (await File(p.join(recovery.path, 'pending')).exists()) {
        throw StateError(
            'Có lần khôi phục chưa hoàn tất. Hãy mở lại ứng dụng để phục hồi trước.');
      }
      restoreGuard = await File(p.join(folder.path, 'restore_access.lock'))
          .open(mode: FileMode.append);
      await restoreGuard.lock(FileLock.blockingExclusive);
      if (reconciliation != null &&
          ledgerFingerprint(mainFile.path) != reconciliation.fingerprint) {
        throw StateError(
            'Dữ liệu trên máy đã thay đổi. Hãy mở lại bản sao lưu để đối soát.');
      }
      if (reconciliation != null && selected.isNotEmpty) {
        await compute(_reconcileInBackground, {
          'path': stagedFile.path,
          'diff': reconciliation,
          'selected': selected,
          'mapping': walletMapping
        });
      }
      final settings =
          readManifest(file.parent.path, 'preferences_manifest.json');
      final security = readManifest(file.parent.path, 'security_manifest.json');
      if (settings != null) validatePreferences(settings);
      if (security != null) VaultSecurityConfig.fromJson(security);
      if (await recovery.exists()) {
        // Retain earlier recovery sets rather than silently overwriting them.
        await recovery.rename(
            '${recovery.path}_${DateTime.now().microsecondsSinceEpoch}');
      }
      await recovery.create();
      await _db.customStatement(
          'VACUUM INTO ?', [p.join(recovery.path, 'pfm_local_vault.sqlite')]);
      await File(p.join(recovery.path, 'preferences_manifest.json'))
          .writeAsString(jsonEncode(beforePrefs), flush: true);
      await File(p.join(recovery.path, 'security_manifest.json'))
          .writeAsString(jsonEncode(beforeSecurity), flush: true);
      await File(p.join(recovery.path, 'pending'))
          .writeAsString('prepared', flush: true);
      progress.state = 'Đang khôi phục dữ liệu và thiết lập…';
      await _db.close();
      closed = true;
      // Capture again after all queued Drift writes have drained during close.
      await mainFile.copy(p.join(recovery.path, 'pfm_local_vault.sqlite'));
      if (reconciliation != null &&
          ledgerFingerprint(mainFile.path) != reconciliation.fingerprint) {
        throw StateError(
            'Có giao dịch vừa thay đổi. Hãy mở lại đối soát trước khi khôi phục.');
      }
      await File(p.join(recovery.path, 'pending'))
          .writeAsString('installing', flush: true);
      replacing = true;
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('${mainFile.path}$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }
      await stagedFile.copy(mainFile.path);
      if (settings != null) await applyBackupPreferences(prefs, settings);
      if (security != null) {
        await VaultSecurityService.restoreManifest(security);
      }
      await prefs.setBool('flowy_restored_private', true);
      await File(p.join(recovery.path, 'pending')).delete();
    } catch (_) {
      if (replacing) {
        await File(p.join(recovery.path, 'pfm_local_vault.sqlite'))
            .copy(mainFile.path);
        await applyBackupPreferences(prefs, beforePrefs);
        await VaultSecurityService.restorePersistedSnapshot(beforeSecurity);
        final marker = File(p.join(recovery.path, 'pending'));
        if (await marker.exists()) await marker.delete();
      }
      if (closed && !replacing) {
        final marker = File(p.join(recovery.path, 'pending'));
        if (await marker.exists()) await marker.delete();
      }
      rethrow;
    } finally {
      if (stagedFile != null) {
        for (final suffix in ['', '-wal', '-shm', '-journal']) {
          final artifact = File('${stagedFile.path}$suffix');
          if (await artifact.exists()) await artifact.delete();
        }
      }
      if (restoreGuard != null) {
        try {
          await restoreGuard.unlock();
        } finally {
          await restoreGuard.close();
        }
      }
      _busy = false;
      progress.state = null;
      if (closed) {
        _ref.invalidate(themeModeProvider);
        _ref.invalidate(accentPresetProvider);
        _ref.invalidate(fontFamilyProvider);
        _ref.invalidate(currencyFontProvider);
        _ref.invalidate(notificationPreferencesProvider);
        _ref.invalidate(dayCutoffProvider);
        _ref.invalidate(classificationSchemesProvider);
        _ref.invalidate(userProfileNotifierProvider);
        _ref.invalidate(vaultSecurityServiceProvider);
        _ref.invalidate(vaultBiometricsProvider);
        _ref.invalidate(cycleStartDaysByMonthProvider);
        _ref.invalidate(databaseProvider);
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
    state =
        state.copyWith(status: BackupSyncStatus.upToDate, isDismissed: true);
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
      if (!mounted) return;
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
        if (cloudLatestTxDate != null &&
            cloudLatestTxDate.isAfter(latestLocalTxDate)) {
          isCloudNewer = true;
        } else if (cloudBackupTime.isAfter(latestLocalTxDate) &&
            cloudMetadata.transactionCount >
                (localTxs.length + localDebtTxs.length)) {
          isCloudNewer = true;
        }
      }

      if (!mounted) return;
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
      if (!mounted) return;
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

  void updateProgress(
      CloudBackupStatus status, String message, double progress) {
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
      message:
          'Sao lưu thành công lúc ${DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now())}',
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
      if (!mounted) return;
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
      final updatedList =
          state.backups.where((b) => b.fileId != fileId).toList();
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
void _reconcileInBackground(Map<String, dynamic> args) => reconcileBackup(
    args['path'] as String,
    args['diff'] as BackupReconciliation,
    args['selected'] as Set<String>,
    args['mapping'] as Map<String, String>);
