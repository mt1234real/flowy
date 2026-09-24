// ==============================================================================
// File: lib/widgets/restore_diff_modal.dart
// Architecture: Pre-Restore Diff & Sign-Out Backup Interception Sheet (Zero Silent Data Loss)
// Stack: flutter, flutter_riverpod, drift, intl, path, path_provider, sqlite3
// Features:
// 1. Sign-Out Backup Interception Sheet (`SignOutBackupSheet`):
//    - Header: Icon 🔒 viền phát quang Emerald + Tiêu đề "BẢO VỆ DỮ LIỆU TRƯỚC KHI ĐĂNG XUẤT".
//    - Phụ đề: "Bạn có muốn sao lưu dữ liệu mới nhất lên Google Drive trước khi đăng xuất không?"
//    - Comparison Card:
//      * 📱 Dữ liệu hiện tại trên máy: X giao dịch • Y nguồn ví • Giao dịch mới nhất định dạng trực quan.
//      * ☁️ Lần sao lưu gần nhất trên Cloud: mốc thời gian • Ghi chú chênh lệch nếu có.
//    - 3 Nút hành động:
//      1. [ ☁️ Sao lưu và Đăng xuất (Khuyên dùng) ]:
//         Gọi performBackup(), toast "Đã sao lưu an toàn", thu hồi token, ngắt phiên.
//      2. [ 🚪 Chỉ đăng xuất (Không sao lưu) ]:
//         Tạo snapshot an toàn 'old_account_unsaved.bak' ngầm, sau đó đăng xuất.
//      3. [ Hủy bỏ (Ở lại tài khoản này) ]:
//         Đóng sheet, giữ nguyên ứng dụng.
// 2. Dual-Column Split Comparison Matrix (Pre-Restore Diff Engine).
// 3. Safety Rollback Architecture (.bak Cloning).
// ==============================================================================

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../services/cloud_backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_text.dart';

/// DTO lưu trữ chỉ số đối soát giữa 2 CSDL
class DatabaseInspectionMetrics {
  final int transactionCount;
  final int walletCount;
  final DateTime? latestTransactionDate;
  final double totalBalance;

  const DatabaseInspectionMetrics({
    required this.transactionCount,
    required this.walletCount,
    this.latestTransactionDate,
    required this.totalBalance,
  });

  String get formattedLatestDate {
    if (latestTransactionDate == null) return 'Chưa có giao dịch';
    return DateFormat('dd/MM/yyyy HH:mm').format(latestTransactionDate!);
  }
}

class RestoreDiffModal extends ConsumerStatefulWidget {
  final CloudBackupItem? backupItem;
  final BackupDiffReport? signoutReport;

  const RestoreDiffModal({
    super.key,
    this.backupItem,
    this.signoutReport,
  });

  /// Static helper mở modal đối soát trực tiếp từ danh sách backup
  static Future<void> show(
      BuildContext context, {
        required CloudBackupItem backupItem,
      }) {
    HapticFeedback.selectionClick();
    return AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => RestoreDiffModal(backupItem: backupItem),
    );
  }

  /// 🌟 Static helper mở Cổng an toàn trước khi Đăng xuất (Sign-Out Backup Interception Sheet)
  static Future<bool> showPreSignoutGate(
      BuildContext context, {
        required BackupDiffReport report,
      }) async {
    HapticFeedback.mediumImpact();
    final result = await AppAnimationPolicy.showFluidSheet<bool>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => RestoreDiffModal(signoutReport: report),
    );
    return result ?? false;
  }

  @override
  ConsumerState<RestoreDiffModal> createState() => _RestoreDiffModalState();
}

class _RestoreDiffModalState extends ConsumerState<RestoreDiffModal> {
  bool _isLoading = true;
  String? _loadingMessage;
  File? _decryptedTempFile;

  DatabaseInspectionMetrics? _localMetrics;
  DatabaseInspectionMetrics? _backupMetrics;

  bool get _isSignoutMode => widget.signoutReport != null;

  @override
  void initState() {
    super.initState();
    if (_isSignoutMode) {
      _isLoading = false;
    } else {
      _loadAndCompareMetrics();
    }
  }

  @override
  void dispose() {
    _cleanTempFile();
    super.dispose();
  }

  void _cleanTempFile() {
    if (_decryptedTempFile != null && _decryptedTempFile!.existsSync()) {
      try {
        _decryptedTempFile!.parent.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount);
  }

  /// Định dạng thời gian trực quan thân thiện (vd: "Hôm nay 10:30", "Hôm qua 15:45", "3 ngày trước")
  String _formatFriendlyRelativeTime(DateTime? date) {
    if (date == null) return 'Chưa có';
    final now = DateTime.now();
    final diff = now.difference(date.toLocal());

    final isSameDay = now.year == date.year && now.month == date.month && now.day == date.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == date.year && yesterday.month == date.month && yesterday.day == date.day;

    if (isSameDay) {
      return 'Hôm nay ${DateFormat('HH:mm').format(date.toLocal())}';
    } else if (isYesterday) {
      return 'Hôm qua ${DateFormat('HH:mm').format(date.toLocal())}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước (${DateFormat('HH:mm').format(date.toLocal())})';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
    }
  }

  /// Trích xuất metrics từ tệp SQLite độc lập bằng sqlite3 thuần
  DatabaseInspectionMetrics _inspectSqliteFile(File dbFile) {
    final rawDb = sqlite.sqlite3.open(dbFile.path);
    try {
      final txResult = rawDb.select('SELECT COUNT(*) AS count, MAX(date) AS max_date FROM transactions;');
      int txCount = 0;
      DateTime? maxDate;
      if (txResult.isNotEmpty) {
        txCount = txResult.first['count'] as int? ?? 0;
        final rawMaxDate = txResult.first['max_date'];
        if (rawMaxDate != null) {
          if (rawMaxDate is int) {
            maxDate = DateTime.fromMillisecondsSinceEpoch(rawMaxDate * 1000);
          } else if (rawMaxDate is String) {
            maxDate = DateTime.tryParse(rawMaxDate);
          }
        }
      }

      final walletResult = rawDb.select('SELECT COUNT(*) AS count, SUM(balance) AS total_balance FROM wallets WHERE is_archived = 0;');
      int walletCount = 0;
      double totalBalance = 0.0;
      if (walletResult.isNotEmpty) {
        walletCount = walletResult.first['count'] as int? ?? 0;
        totalBalance = (walletResult.first['total_balance'] as num?)?.toDouble() ?? 0.0;
      }

      return DatabaseInspectionMetrics(
        transactionCount: txCount,
        walletCount: walletCount,
        latestTransactionDate: maxDate,
        totalBalance: totalBalance,
      );
    } finally {
      rawDb.dispose();
    }
  }

  Future<void> _loadAndCompareMetrics() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Đang tải và giải mã tệp sao lưu...';
    });

    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final localDbFile = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite'));

      if (await localDbFile.exists()) {
        _localMetrics = _inspectSqliteFile(localDbFile);
      } else {
        _localMetrics = const DatabaseInspectionMetrics(
          transactionCount: 0,
          walletCount: 0,
          totalBalance: 0.0,
        );
      }

      final backupService = ref.read(cloudBackupServiceProvider);
      _decryptedTempFile = await backupService.downloadAndDecryptBackup(widget.backupItem!.fileId);

      _backupMetrics = _inspectSqliteFile(_decryptedTempFile!);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('RestoreDiffModal: Error inspecting diff: $e');
      if (mounted) {
        AppFeedback.showError(
          context,
          'Lỗi giải mã bản sao lưu: $e',
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _executeRestore({required bool createLocalBackupFirst}) async {
    if (_decryptedTempFile == null || !_decryptedTempFile!.existsSync()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Đang tiến hành khôi phục dữ liệu an toàn...';
    });

    try {
      final db = ref.read(databaseProvider);
      final backupService = ref.read(cloudBackupServiceProvider);

      if (createLocalBackupFirst) {
        setState(() => _loadingMessage = 'Đang tạo bản sao lưu máy lên Google Drive...');
        await backupService.createBackup();
      }

      await db.customStatement('PRAGMA wal_checkpoint(FULL);');

      final dbFolder = await getApplicationDocumentsDirectory();
      final mainDbFile = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite'));
      final walFile = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite-wal'));
      final shmFile = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite-shm'));
      final backupBakFile = File(p.join(dbFolder.path, 'pfm_local_vault.sqlite.bak'));

      if (await mainDbFile.exists()) {
        await mainDbFile.copy(backupBakFile.path);
      }

      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      await _decryptedTempFile!.copy(mainDbFile.path);

      ref.invalidate(databaseProvider);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final providerContainer = ProviderScope.containerOf(
          context,
          listen: false,
        );

        // Safety-critical exception: restoring a database replaces local data.
        // Preserve the existing rollback affordance through the unified Undo Dock
        // instead of leaving an 8-second legacy SnackBar behind the modal layer.
        AppFeedback.showUndo(
          context,
          message: '✓ Khôi phục CSDL từ Cloud thành công!',
          actionColor: Colors.yellowAccent,
          onUndo: () async {
            if (await backupBakFile.exists()) {
              if (await walFile.exists()) await walFile.delete();
              if (await shmFile.exists()) await shmFile.delete();

              await backupBakFile.copy(mainDbFile.path);
              providerContainer.invalidate(databaseProvider);

              AppFeedback.showSuccessWithMessenger(
                messenger,
                '✓ Đã hoàn tác trở lại trạng thái cũ trên máy.',
                emitHaptic: false,
              );
            }
          },
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('RestoreDiffModal: Error during restore: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        AppFeedback.showError(
          context,
          'Lỗi trong quá trình khôi phục: $e',
        );
      }
    }
  }

  Future<void> _showDangerousOverrideConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTokens.expense, size: 24),
            SizedBox(width: 8),
            Text('Xác nhận ghi đè?'),
          ],
        ),
        content: const Text(
          'Dữ liệu mới trên thiết bị này sẽ bị thay thế bằng bản sao lưu Cloud cũ hơn. '
              'Hệ thống sẽ tạo bản sao dự phòng .bak để hoàn tác nếu cần. Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('VẪN GHI ĐÈ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _executeRestore(createLocalBackupFirst: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    return AppFeedbackDismissRegion(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF151C28).withValues(alpha: 0.98)
                  : Colors.white.withValues(alpha: 0.98),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
              ),
            ),
            child: SafeArea(
              top: false,
              child: _isLoading
                  ? SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(accent.primary),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _loadingMessage ?? 'Đang đối soát dữ liệu...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  : (_isSignoutMode
                  ? _buildSignOutBackupSheet(isDark, accent)
                  : _buildDiffContent(isDark, accent)),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 🌟 GIAO DIỆN SIGN-OUT BACKUP INTERCEPTION SHEET
  // ===========================================================================
  Widget _buildSignOutBackupSheet(bool isDark, AppAccentPreset accent) {
    final report = widget.signoutReport!;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 1. Header: Icon 🔒 viền phát quang Emerald + Tiêu đề
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accent.primary.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.lock_outline_rounded,
                    color: accent.primary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BẢO VỆ DỮ LIỆU TRƯỚC KHI ĐĂNG XUẤT',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      report.userEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: accent.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Phụ đề hướng dẫn
          Text(
            'Bạn có muốn sao lưu dữ liệu mới nhất lên Google Drive trước khi đăng xuất không?',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
            ),
          ),
          const SizedBox(height: 14),

          // 3. Khung so sánh dữ liệu (Comparison Card)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📱 Dòng dữ liệu máy này
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.phone_android_rounded, size: 16, color: Color(0xFF0EA5E9)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dữ liệu hiện tại trên máy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${report.localTxCount} giao dịch • ${report.localWalletCount} nguồn ví',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                            ),
                          ),
                          Text(
                            'Giao dịch mới nhất: ${_formatFriendlyRelativeTime(report.localLatestTxDate)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const Divider(height: 18),

                // ☁️ Dòng dữ liệu trên Cloud
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.cloud_done_rounded, size: 16, color: accent.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lần sao lưu gần nhất trên Cloud',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _formatFriendlyRelativeTime(report.cloudBackupDate),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: accent.primary,
                                ),
                              ),
                              if (report.unsavedTxDifference > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTokens.expense.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Chưa có ${report.unsavedTxDifference} GD gần đây',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppTokens.expense,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${report.cloudTxCount} giao dịch • ${report.cloudWalletCount} nguồn ví',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. 3 Nút hành động chuẩn UX Flowy
          // NÚT 1: Sao lưu và Đăng xuất (Khuyên dùng)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: accent.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                  _loadingMessage = 'Đang sao lưu CSDL lên Google Drive...';
                });
                final backupService = ref.read(cloudBackupServiceProvider);
                try {
                  await backupService.performBackup();
                  await backupService.createEmergencyLocalSnapshot();
                  await backupService.signOutAndClearSession();

                  if (context.mounted) {
                    AppFeedback.showSuccess(
                      context,
                      '✓ Đã sao lưu an toàn và đăng xuất thành công.',
                    );
                    Navigator.of(context).pop(true);
                  }
                } catch (e) {
                  if (context.mounted) {
                    setState(() => _isLoading = false);
                    AppFeedback.showError(
                      context,
                      'Lỗi sao lưu: $e',
                    );
                  }
                }
              },
              icon: const Icon(Icons.cloud_upload_rounded, size: 18),
              label: const Text(
                'SAO LƯU VÀ ĐĂNG XUẤT (Khuyên dùng)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // NÚT 2: Chỉ đăng xuất (Không sao lưu)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? AppTokens.darkCard.withValues(alpha: 0.5) : Colors.white,
                foregroundColor: const Color(0xFFF43F5E),
                side: BorderSide(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final backupService = ref.read(cloudBackupServiceProvider);
                // Tạo snapshot cục bộ dự phòng ngầm (pre_logout_backup.bak)
                await backupService.createEmergencyLocalSnapshot();
                await backupService.signOutAndClearSession();

                if (context.mounted) {
                  AppFeedback.showSuccess(
                    context,
                    'Đã đăng xuất tài khoản (Đã tạo snapshot dự phòng trên máy).',
                    emitHaptic: false,
                  );
                  Navigator.of(context).pop(true);
                }
              },
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text(
                'Chỉ đăng xuất (Không sao lưu)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // NÚT 3: Hủy bỏ
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Hủy bỏ (Ở lại tài khoản này)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // GIAO DIỆN ĐỐI SOÁT KHÔI PHỤC (RESTORE DIFF)
  // ===========================================================================
  Widget _buildDiffContent(bool isDark, AppAccentPreset accent) {
    final local = _localMetrics!;
    final backup = _backupMetrics!;

    final int diffTx = local.transactionCount - backup.transactionCount;
    final bool isLocalNewer = diffTx > 0 ||
        (local.latestTransactionDate != null &&
            backup.latestTransactionDate != null &&
            local.latestTransactionDate!.isAfter(backup.latestTransactionDate!));

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isLocalNewer ? AppTokens.expense : const Color(0xFF10B981))
                          .withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isLocalNewer ? Icons.warning_amber_rounded : Icons.verified_rounded,
                      color: isLocalNewer ? AppTokens.expense : const Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ĐỐI SOÁT TRƯỚC KHI KHÔI PHỤC',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      Text(
                        'Kiểm tra kỹ để tránh ghi đè làm mất giao dịch mới',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // BẢNG SO SÁNH 2 CỘT
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.phone_android_rounded, size: 14, color: Color(0xFF0EA5E9)),
                          const SizedBox(width: 4),
                          Text(
                            '📱 DỮ LIỆU TRÊN MÁY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${NumberFormat('#,###').format(local.transactionCount)} GD',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${local.walletCount} nguồn ví',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                      ),
                      const SizedBox(height: 2),
                      CurrencyText(
                        'Số dư: ${_formatCurrency(local.totalBalance)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Giao dịch gần nhất:',
                        style: TextStyle(fontSize: 10, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                      ),
                      Text(
                        local.formattedLatestDate,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 1,
                  height: 130,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cloud_done_rounded, size: 14, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            '☁️ BẢN CLOUD CHỌN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${NumberFormat('#,###').format(backup.transactionCount)} GD',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: accent.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${backup.walletCount} nguồn ví',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                      ),
                      const SizedBox(height: 2),
                      CurrencyText(
                        'Số dư: ${_formatCurrency(backup.totalBalance)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bản tạo lúc:',
                        style: TextStyle(fontSize: 10, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                      ),
                      Text(
                        widget.backupItem!.formattedDate,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (isLocalNewer)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTokens.expense.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTokens.expense.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppTokens.expense, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🚨 CẢNH BÁO NGUY CƠ MẤT DỮ LIỆU',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppTokens.expense,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          diffTx > 0
                              ? 'Dữ liệu trên máy đang MỚI HƠN bản sao lưu Cloud. Nếu khôi phục trực tiếp, bạn sẽ MẤT $diffTx GIAO DỊCH được ghi chép gần đây!'
                              : 'Thời điểm ghi chép trên máy mới hơn bản sao lưu Cloud này. Hãy cẩn trọng trước khi ghi đè.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bản sao lưu Cloud mới hơn dữ liệu hiện tại trên thiết bị. An toàn để khôi phục và đồng bộ.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Nút hành động
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _executeRestore(createLocalBackupFirst: true),
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: const Text(
                '🛡️ SAO LƯU MÁY NÀY TRƯỚC RỒI KHÔI PHỤC',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.3),
              ),
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: isLocalNewer ? AppTokens.expense : (isDark ? AppTokens.darkText : AppTokens.lightText),
                side: BorderSide(
                  color: isLocalNewer
                      ? AppTokens.expense.withValues(alpha: 0.6)
                      : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                if (isLocalNewer) {
                  _showDangerousOverrideConfirmation();
                } else {
                  _executeRestore(createLocalBackupFirst: false);
                }
              },
              icon: Icon(
                isLocalNewer ? Icons.warning_rounded : Icons.restore_rounded,
                size: 16,
                color: isLocalNewer ? AppTokens.expense : null,
              ),
              label: Text(
                isLocalNewer ? '⚠️ Vẫn ghi đè (Chấp nhận thay thế)' : 'Tiến hành khôi phục ngay',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isLocalNewer ? AppTokens.expense : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Hủy bỏ',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}