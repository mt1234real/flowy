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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../main.dart' show resetAppRootSession, hasCompletedOnboardingProvider;
import '../services/backup_capsule.dart';
import 'flowy_selection_picker.dart';
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
  final File? localRecovery;
  final bool finishOnboarding;
  final ScrollController? scrollController;

  const RestoreDiffModal({
    super.key,
    this.backupItem,
    this.signoutReport,
    this.localRecovery,
    this.finishOnboarding = false,
    this.scrollController,
  });

  /// Static helper mở modal đối soát trực tiếp từ danh sách backup
  static Future<void> show(
    BuildContext context, {
    required CloudBackupItem backupItem,
    bool finishOnboarding = false,
  }) {
    HapticFeedback.selectionClick();
    return AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.scrollable,
      enableBlur: false,
      backgroundColor: Colors.transparent,
      builder: (_, scroll) => RestoreDiffModal(
          backupItem: backupItem,
          finishOnboarding: finishOnboarding,
          scrollController: scroll),
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
      mode: FluidSheetMode.scrollable,
      backgroundColor: Colors.transparent,
      builder: (_, scroll) =>
          RestoreDiffModal(signoutReport: report, scrollController: scroll),
    );
    return result ?? false;
  }

  static Future<void> showLocalRecovery(BuildContext context) async {
    final documents = await getApplicationDocumentsDirectory();
    final source = File(
        p.join(documents.path, 'restore_recovery', 'pfm_local_vault.sqlite'));
    if (!await source.exists()) {
      if (context.mounted) {
        AppFeedback.showInfo(context, 'Chưa có bản dự phòng trước khôi phục.');
      }
      return;
    }
    final modified = await source.lastModified();
    final length = await source.length();
    if (!context.mounted) return;
    await AppAnimationPolicy.showFluidSheet<void>(
        context: context,
        mode: FluidSheetMode.scrollable,
        enableBlur: false,
        builder: (_, scroll) => RestoreDiffModal(
            scrollController: scroll,
            localRecovery: source,
            backupItem: CloudBackupItem(
                fileId: 'local',
                fileName: 'Bản dự phòng trên máy',
                sizeBytes: length,
                createdTime: modified,
                properties: const {})));
  }

  @override
  ConsumerState<RestoreDiffModal> createState() => _RestoreDiffModalState();
}

class _RestoreDiffModalState extends ConsumerState<RestoreDiffModal> {
  bool _isLoading = true;
  String? _loadingMessage;
  File? _decryptedTempFile;
  BackupReconciliation? _reconciliation;
  Map<String, dynamic>? _savedPreferences;
  bool _keepLocal = true;
  final Set<String> _selected = {};
  final Map<String, String> _walletMapping = {};

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
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(amount);
  }

  /// Định dạng thời gian trực quan thân thiện (vd: "Hôm nay 10:30", "Hôm qua 15:45", "3 ngày trước")
  String _formatFriendlyRelativeTime(DateTime? date) {
    if (date == null) return 'Chưa có';
    final now = DateTime.now();
    final diff = now.difference(date.toLocal());

    final isSameDay =
        now.year == date.year && now.month == date.month && now.day == date.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == date.year &&
        yesterday.month == date.month &&
        yesterday.day == date.day;

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
      final txResult = rawDb.select(
          'SELECT COUNT(*) AS count, MAX(date) AS max_date FROM (SELECT date FROM transactions UNION ALL SELECT date FROM debt_transactions);');
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

      final walletResult = rawDb.select(
          'SELECT COUNT(*) AS count, SUM(balance) AS total_balance FROM wallets WHERE is_archived = 0;');
      int walletCount = 0;
      double totalBalance = 0.0;
      if (walletResult.isNotEmpty) {
        walletCount = walletResult.first['count'] as int? ?? 0;
        totalBalance =
            (walletResult.first['total_balance'] as num?)?.toDouble() ?? 0.0;
      }

      return DatabaseInspectionMetrics(
        transactionCount: txCount,
        walletCount: walletCount,
        latestTransactionDate: maxDate,
        totalBalance: totalBalance,
      );
    } finally {
      rawDb.close();
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
      if (widget.localRecovery != null) {
        final temp = await getTemporaryDirectory();
        await temp.create(recursive: true);
        final folder = await temp.createTemp('flowy_recovery_');
        for (final name in [
          'pfm_local_vault.sqlite',
          'preferences_manifest.json',
          'security_manifest.json'
        ]) {
          final source = File(p.join(widget.localRecovery!.parent.path, name));
          if (await source.exists()) {
            await source.copy(p.join(folder.path, name));
          }
        }
        _decryptedTempFile =
            File(p.join(folder.path, 'pfm_local_vault.sqlite'));
      } else {
        _decryptedTempFile = await backupService
            .downloadAndDecryptBackup(widget.backupItem!.fileId);
      }
      if (!mounted) {
        _cleanTempFile();
        return;
      }

      _savedPreferences = readManifest(
          _decryptedTempFile!.parent.path, 'preferences_manifest.json');
      _backupMetrics = _inspectSqliteFile(_decryptedTempFile!);
      final snapshot = await backupService.snapshotForInspection();
      try {
        _reconciliation =
            inspectReconciliation(snapshot.path, _decryptedTempFile!.path);
        _localMetrics = _inspectSqliteFile(snapshot);
        final local = sqlite.sqlite3.open(snapshot.path);
        try {
          final rows =
              local.select('SELECT id,name,type,currency FROM wallets');
          final cloud = _reconciliation!.wallets;
          // Stable identity takes precedence; ambiguous matches require a choice.
          for (final row in rows) {
            final id = row['id'] as String;
            if (cloud.any((w) => w['id'] == id)) _walletMapping[id] = id;
          }
          String normalize(Object? name) => (name as String? ?? '')
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'\s+'), ' ');
          for (final row in rows) {
            final id = row['id'] as String;
            if (_walletMapping.containsKey(id)) continue;
            final compatible = cloud
                .where((w) =>
                    w['type'] == row['type'] &&
                    w['currency'] == row['currency'])
                .toList();
            final named = compatible
                .where((w) => normalize(w['name']) == normalize(row['name']))
                .toList();
            final localNamed = rows
                .where((w) =>
                    normalize(w['name']) == normalize(row['name']) &&
                    w['type'] == row['type'])
                .length;
            final localType = rows
                .where((w) =>
                    w['type'] == row['type'] &&
                    w['currency'] == row['currency'])
                .length;
            final match = named.length == 1 && localNamed == 1
                ? named.single
                : named.isEmpty && compatible.length == 1 && localType == 1
                    ? compatible.single
                    : null;
            if (match != null && !_walletMapping.containsValue(match['id'])) {
              _walletMapping[id] = match['id'] as String;
            }
          }
        } finally {
          local.close();
        }
      } finally {
        await snapshot.parent.delete(recursive: true);
      }
      for (final wallet in _reconciliation!.wallets) {
        final id = wallet['id'] as String;
        if (_reconciliation!.localWalletNames.containsKey(id)) {
          _walletMapping[id] = id;
        }
      }
      _keepLocal = _reconciliation!.entries.any((e) => e.blockedReason == null);
      _selected.addAll(_reconciliation!.entries
          .where((e) => e.blockedReason == null)
          .map((e) => e.key));

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
    final file = _decryptedTempFile;
    if (file == null || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(cloudBackupServiceProvider).restorePreparedBackup(file,
          reconciliation: _reconciliation,
          selected: _keepLocal ? _selected : <String>{},
          walletMapping: _walletMapping);
      if (!mounted) return;
      if (widget.finishOnboarding) {
        await ref
            .read(sharedPreferencesProvider)
            .setBool('has_completed_onboarding', true);
        if (!mounted) return;
        ref.read(hasCompletedOnboardingProvider.notifier).state = true;
      }
      AppFeedback.showSuccess(
          context, 'Đã khôi phục. Bản dữ liệu trước đó vẫn được giữ trên máy.');
      resetAppRootSession(ref);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppFeedback.showError(context, 'Chưa khôi phục được: $e');
    }
  }

  Future<void> _confirmRestore() async {
    if (_keepLocal) {
      for (final entry
          in _reconciliation!.entries.where((e) => _selected.contains(e.key))) {
        final source = _walletMapping[entry.walletId];
        final targetId = entry.row['to_wallet_id'] as String?;
        if (source == null ||
            (targetId != null && _walletMapping[targetId] == null)) {
          AppFeedback.showInfo(context,
              'Chọn ví tương ứng cho các giao dịch mới trước khi khôi phục.');
          return;
        }
        if (targetId != null && source == _walletMapping[targetId]) {
          AppFeedback.showInfo(context,
              'Ví gửi và ví nhận của giao dịch chuyển tiền phải khác nhau.');
          return;
        }
      }
    }
    final confirmed = await AppAnimationPolicy.showPreservedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận khôi phục'),
        content: const Text(
          'Dữ liệu Cloud sẽ thay thế dữ liệu đang dùng. Các mục không chọn nhập lại vẫn nằm trong bản dự phòng trên máy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Khôi phục'),
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

    final media = MediaQuery.of(context);
    final topInset =
        View.of(context).padding.top / View.of(context).devicePixelRatio;
    return AppFeedbackDismissRegion(
        child: SizedBox(
      height: (media.size.height - topInset - 12).clamp(0.0, media.size.height),
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
            top: false,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 54),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  _isSignoutMode
                                      ? 'Sao lưu trước khi đăng xuất'
                                      : 'Chi tiết bản sao lưu',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                  widget.localRecovery != null
                                      ? 'Bản dự phòng được giữ trên thiết bị'
                                      : 'Đồng bộ dữ liệu an toàn cùng Google Drive',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                            ])),
                        IconButton(
                            tooltip: 'Đóng',
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                                backgroundColor:
                                    accent.primary.withValues(alpha: .08)),
                            icon: const Icon(Icons.close_rounded, size: 18)),
                      ]))),
              Expanded(
                  child: _isLoading
                      ? Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                          CircularProgressIndicator(
                              strokeWidth: 2.5, color: accent.primary),
                          const SizedBox(height: 16),
                          Text(_loadingMessage ?? 'Đang đối soát dữ liệu…',
                              textAlign: TextAlign.center),
                        ]))
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _isSignoutMode
                              ? _buildSignOutBackupSheet(isDark, accent)
                              : _buildDiffContent(isDark, accent))),
              if (!_isLoading && !_isSignoutMode)
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                backgroundColor: accent.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16))),
                            onPressed: _confirmRestore,
                            child: Text(
                                _keepLocal && _selected.isNotEmpty
                                    ? 'Khôi phục và nhập ${_selected.length} giao dịch'
                                    : 'Khôi phục bản sao lưu',
                                textAlign: TextAlign.center)))),
            ])),
      ),
    ));
  }

  // ===========================================================================
  // 🌟 GIAO DIỆN SIGN-OUT BACKUP INTERCEPTION SHEET
  // ===========================================================================
  Widget _buildSignOutBackupSheet(bool isDark, AppAccentPreset accent) {
    final report = widget.signoutReport!;

    return SingleChildScrollView(
      controller: widget.scrollController,
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      'Sao lưu trước khi đăng xuất',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color:
                            isDark ? AppTokens.darkText : AppTokens.lightText,
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
                      child: Icon(Icons.phone_android_rounded,
                          size: 16, color: Color(0xFF0EA5E9)),
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
                              color: isDark
                                  ? AppTokens.darkMuted
                                  : AppTokens.lightMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${report.localTxCount} giao dịch • ${report.localWalletCount} nguồn ví',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppTokens.darkText
                                  : AppTokens.lightText,
                            ),
                          ),
                          Text(
                            'Giao dịch mới nhất: ${_formatFriendlyRelativeTime(report.localLatestTxDate)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppTokens.darkMuted
                                  : AppTokens.lightMuted,
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
                      child: Icon(Icons.cloud_done_rounded,
                          size: 16, color: accent.primary),
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
                              color: isDark
                                  ? AppTokens.darkMuted
                                  : AppTokens.lightMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _formatFriendlyRelativeTime(
                                    report.cloudBackupDate),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: accent.primary,
                                ),
                              ),
                              if (report.unsavedTxDifference > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTokens.expense
                                        .withValues(alpha: 0.16),
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
                              color: isDark
                                  ? AppTokens.darkMuted
                                  : AppTokens.lightMuted,
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                setState(() {
                  _isLoading = true;
                  _loadingMessage = 'Đang sao lưu lên Google Drive…';
                });
                final backupService = ref.read(cloudBackupServiceProvider);
                try {
                  await backupService.performBackup();
                  await backupService.createEmergencyLocalSnapshot();
                  await backupService.signOutAndClearSession();

                  if (mounted) {
                    AppFeedback.showSuccess(
                      context,
                      '✓ Đã sao lưu an toàn và đăng xuất thành công.',
                    );
                    Navigator.of(context).pop(true);
                  }
                } catch (e) {
                  if (mounted) {
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
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2),
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
                backgroundColor: isDark
                    ? AppTokens.darkCard.withValues(alpha: 0.5)
                    : Colors.white,
                foregroundColor: const Color(0xFFF43F5E),
                side: BorderSide(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final backupService = ref.read(cloudBackupServiceProvider);
                // Tạo snapshot cục bộ dự phòng ngầm (pre_logout_backup.bak)
                await backupService.createEmergencyLocalSnapshot();
                await backupService.signOutAndClearSession();

                if (mounted) {
                  AppFeedback.showSuccess(
                    context,
                    'Đã đăng xuất. Bản dự phòng vẫn được giữ trên máy.',
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
  String get _sourceLabel =>
      widget.localRecovery == null ? 'Cloud' : 'dự phòng';

  Widget _glassCard(Widget child, {bool selected = false}) {
    final theme = Theme.of(context);
    final accent = ref.watch(accentPresetProvider).primary;
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: .08)
                : theme.colorScheme.surfaceContainer.withValues(alpha: .6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected
                    ? accent
                    : theme.colorScheme.outlineVariant.withValues(alpha: .5),
                width: .8)),
        child: child);
  }

  Widget _buildDiffContent(bool isDark, AppAccentPreset accent) {
    final diff = _reconciliation!;
    final available =
        diff.entries.where((e) => e.blockedReason == null).toList();
    final blocked = diff.entries.where((e) => e.blockedReason != null).toList();
    final groups = <String>{
      for (final e in available) e.walletId,
      for (final e in available)
        if (e.row['to_wallet_id'] is String) e.row['to_wallet_id'] as String
    };
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SingleChildScrollView(
        controller: widget.scrollController,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _glassCard(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bản $_sourceLabel (${widget.backupItem!.formattedDate})',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent.primary)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final metric in [
                '${_backupMetrics!.transactionCount} giao dịch',
                '${_backupMetrics!.walletCount} ví',
                if (widget.backupItem!.sizeBytes > 0)
                  widget.backupItem!.formattedSize
              ])
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                        color: accent.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(metric,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800))),
            ]),
            const Divider(height: 24),
            Text(
                'Trên máy: ${_localMetrics!.transactionCount} giao dịch • ${_localMetrics!.walletCount} ví',
                style: TextStyle(fontSize: 12, color: muted)),
            const SizedBox(height: 8),
            Text(
                'Phát hiện ${diff.entries.length} giao dịch chỉ có trên máy này',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
                'Bản $_sourceLabel là dữ liệu gốc để khôi phục. Bạn có thể nhập thêm các giao dịch mới vào ví tương ứng.',
                style: TextStyle(fontSize: 12, height: 1.4, color: muted)),
            if (diff.conflicts > 0) ...[
              const SizedBox(height: 8),
              Text(
                  '${diff.conflicts} giao dịch khác nội dung sẽ giữ theo bản $_sourceLabel. Nội dung trên máy vẫn được giữ trong bản dự phòng.',
                  style: TextStyle(fontSize: 12, color: muted)),
            ],
          ])),
          const SizedBox(height: 12),
          if (available.isNotEmpty) ...[
            _restoreChoice(
                true,
                'Nạp ${available.length} giao dịch mới vào bản $_sourceLabel',
                'Chọn ví tương ứng để cập nhật số dư chính xác. Khuyên dùng.'),
            const SizedBox(height: 10),
          ],
          _restoreChoice(false, 'Chỉ khôi phục bản $_sourceLabel',
              'Dữ liệu trên máy được giữ trong bản dự phòng trước khi khôi phục.'),
          if (_keepLocal && available.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Ghép nguồn tiền',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
                'Kiểm tra ví được gợi ý trước khi tiếp tục. Với chuyển tiền, chọn riêng ví gửi và ví nhận.',
                style: TextStyle(fontSize: 12, color: muted)),
            for (final id in groups)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _glassCard(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${diff.localWalletNames[id] ?? 'Ví cũ'} (máy này) • ${available.where((e) => e.walletId == id || e.row['to_wallet_id'] == id).length} giao dịch',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _walletChoice(id),
                      ]))),
          ],
          if (blocked.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
                '${blocked.length} giao dịch cần đối soát riêng, được giữ trong bản dự phòng:',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            for (final reason in blocked.map((e) => e.blockedReason!).toSet())
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $reason',
                      style: TextStyle(fontSize: 12, color: muted))),
          ],
          const SizedBox(height: 16),
          _glassCard(Text(
              _savedPreferences != null
                  ? 'Bao gồm giao diện, phông chữ, chu kỳ, lịch nhắc và mã PIN két đã băm. Bản dữ liệu hiện tại luôn được giữ lại trước khi khôi phục.'
                  : 'Bản cũ chỉ có dữ liệu tài chính. Giao diện và thiết lập hiện tại được giữ nguyên. Bản dữ liệu trên máy được lưu dự phòng trước khi khôi phục.',
              style: TextStyle(fontSize: 12, height: 1.4, color: muted))),
        ]));
  }

  Widget _restoreChoice(bool value, String title, String subtitle) {
    final selected = _keepLocal == value;
    return Semantics(
        selected: selected,
        button: true,
        child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _keepLocal = value);
            },
            child: _glassCard(
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      size: 20,
                      color: selected
                          ? ref.watch(accentPresetProvider).primary
                          : Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ])),
                ]),
                selected: selected)));
  }

  Widget _cloudWalletLabel(Map<String, dynamic> wallet) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(wallet['name'] as String,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            CurrencyText(
                _formatCurrency((wallet['balance'] as num?)?.toDouble() ?? 0),
                style: const TextStyle(fontSize: 11)),
          ]);

  Widget _walletChoice(String localId) {
    final wallets = _reconciliation!.wallets;
    final match =
        wallets.where((w) => w['id'] == _walletMapping[localId]).firstOrNull;
    return FlowyPickerTrigger(
        minHeight: 46,
        onTap: () async {
          final result = await showFlowyPicker<String>(
              context: context,
              title: 'Ví nhận trong bản $_sourceLabel',
              selected: match == null ? {} : {match['id'] as String},
              items: [
                for (final wallet in wallets)
                  DropdownMenuItem(
                      value: wallet['id'] as String,
                      child: _cloudWalletLabel(wallet))
              ]);
          if (!mounted || result == null || result.isEmpty) return;
          setState(() => _walletMapping[localId] = result.first);
        },
        child: match == null
            ? const Text('Chọn ví tương ứng', style: TextStyle(fontSize: 12))
            : _cloudWalletLabel(match));
  }
}
