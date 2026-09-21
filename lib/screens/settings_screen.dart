// ==============================================================================
// File: lib/screens/settings_screen.dart
// Architecture: Settings Screen with Cloud Sync Hub, Identity, Luminescent Edge & Recycle Bin
// Stack: flutter_riverpod, drift, google_fonts, intl, shared_preferences
// Features:
// 1. Tích hợp LuminescentEdgeScaffoldWrapper.
// 2. Chặn đăng xuất đột ngột với Pre-Signout Gate.
// 3. [Khối 1]: Hero Profile Card (Avatar Squircle, Edit Name, Cloud Sync Badge).
// 4. [Khối 2]: Trung Tâm Đồng Bộ Đám Mây (Google Drive AppData Sync Hub).
// 5. [Khối 3]: GIAO DIỆN & MÀU SẮC (5 Nature Accents) & [Khối 4]: KIỂU CHỮ (5 Fonts).
// 6. [Khối 5]: QUẢN LÝ DỮ LIỆU & BẢO MẬT:
//    - Quản lý danh mục & Ngân sách.
//    - Sổ Nợ & Danh Bạ Đối Ứng.
//    - Đổi mã PIN Két Tiết Kiệm.
//    - 🌟 THÙNG RÁC & LỊCH SỬ XÓA (hiển thị badge số lượng real-time từ SQLite).
// 7. [Khối 6]: Drift SQLite Zero-Latency Engine & Khôi phục dữ liệu mẫu.
// ==============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/sliding_segmented_bar.dart';
import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../data/database_seeder.dart';
import '../main.dart';
import '../services/auth_profile_service.dart';
import '../services/cloud_backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_customization_sheet.dart';
import '../widgets/cloud_cadence_modal.dart';
import '../widgets/restore_diff_modal.dart';
import '../widgets/two_stage_overscroll_header.dart';
import 'category_manager_screen.dart';
import 'debt_dashboard_screen.dart';
import 'recycle_bin_screen.dart';
import 'vault_pin_change_screen.dart';

class FontItemDef {
  final String name;
  final String badge;
  final String description;
  final TextStyle Function({TextStyle? textStyle, Color? color, FontWeight? fontWeight, double? fontSize}) fontBuilder;

  const FontItemDef({
    required this.name,
    required this.badge,
    required this.description,
    required this.fontBuilder,
  });
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static final List<FontItemDef> _fontDefinitions = [
    FontItemDef(
      name: 'Comfortaa',
      badge: 'Cute / Rounded',
      description: 'Bo tròn, siêu đáng yêu & nhẹ nhàng',
      fontBuilder: GoogleFonts.comfortaa,
    ),
    FontItemDef(
      name: 'Nunito',
      badge: 'Rounded Soft',
      description: 'Bo góc mềm mại, thân thiện dễ nhìn',
      fontBuilder: GoogleFonts.nunito,
    ),
    FontItemDef(
      name: 'Plus Jakarta Sans',
      badge: 'Modern',
      description: 'Sắc nét, thanh lịch chuẩn Fintech',
      fontBuilder: GoogleFonts.plusJakartaSans,
    ),
    FontItemDef(
      name: 'Be Vietnam Pro',
      badge: 'Vietnamese',
      description: 'Tối ưu độ đọc & hiển thị dấu tiếng Việt',
      fontBuilder: GoogleFonts.beVietnamPro,
    ),
    FontItemDef(
      name: 'Lora',
      badge: 'Elegant Serif',
      description: 'Cổ điển, thanh lịch & đậm chất sổ tay',
      fontBuilder: GoogleFonts.lora,
    ),
  ];

  String _cadenceSummary = 'Mỗi ngày (02:00 sáng)';

  @override
  void initState() {
    super.initState();
    _loadCadenceSummary();
  }

  Future<void> _loadCadenceSummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt('pfm_backup_cadence_mode') ?? 1;
      final customUnit = prefs.getString('pfm_backup_custom_unit') ?? 'hours';
      final customVal = prefs.getInt('pfm_backup_custom_value') ?? 6;

      String summary;
      switch (modeIndex) {
        case 0:
          summary = 'Sau mỗi lần ghi (3 phút)';
          break;
        case 1:
          summary = 'Mỗi ngày (02:00 sáng)';
          break;
        case 2:
          summary = 'Mỗi tuần (Tối CN)';
          break;
        case 3:
          summary = 'Tắt tự động (Thủ công)';
          break;
        case 4:
        default:
          String unitStr = 'Giờ';
          if (customUnit == 'days') unitStr = 'Ngày';
          if (customUnit == 'weeks') unitStr = 'Tuần';
          summary = 'Mỗi $customVal $unitStr một lần';
          break;
      }

      if (mounted) {
        setState(() => _cadenceSummary = summary);
      }
    } catch (_) {}
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  Future<void> _handleSettingsRefresh() async {
    HapticFeedback.lightImpact();
    final userProfile = ref.read(currentUserProfileProvider);

    if (userProfile.isSignedIn) {
      try {
        await ref.read(backupSyncNotifierProvider.notifier).checkForNewerBackup();
        await ref.read(cloudBackupNotifierProvider.notifier).loadBackups();
      } catch (_) {}
    }
    await _loadCadenceSummary();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _handleSignOutInterception() async {
    HapticFeedback.selectionClick();
    final backupService = ref.read(cloudBackupServiceProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2.5),
                SizedBox(height: 16),
                Text('Đang kiểm tra an toàn dữ liệu...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final report = await backupService.checkPreSignoutDiff();
      if (!mounted) return;
      Navigator.of(context).pop();

      final signedOut = await RestoreDiffModal.showPreSignoutGate(
        context,
        report: report,
      );

      if (signedOut && mounted) {
        await ref.read(userProfileNotifierProvider.notifier).signOut();
        resetAppRootSession(ref);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        AppFeedback.showError(
          context,
          'Lỗi kiểm tra sao lưu: $e',
        );
      }
    }
  }

  Future<void> _showEditDisplayNameDialog(UserProfile profile) async {
    final controller = TextEditingController(text: profile.displayName);
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên hiển thị'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nhập tên của bạn...',
              labelText: 'Tên hiển thị',
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Tên không được để trống';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: const Text('LƯU'),
          ),
        ],
      ),
    );

    if (updated != null && mounted) {
      await ref.read(userProfileNotifierProvider.notifier).updateDisplayName(updated);
      HapticFeedback.mediumImpact();
      if (mounted) {
        AppFeedback.showSuccess(
          context,
          '✓ Đã cập nhật tên thành "$updated"',
        );
      }
    }
  }

  Future<void> _openCloudRestorePicker(BuildContext context) async {
    HapticFeedback.selectionClick();
    final backupService = ref.read(cloudBackupServiceProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 2.5),
                SizedBox(height: 16),
                Text('Đang quét danh sách bản sao lưu trên Drive...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final backups = await backupService.listBackups();
      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (backups.isEmpty) {
        AppFeedback.showInfo(
          context,
          'Không tìm thấy bản sao lưu nào trong thư mục bí mật Google Drive.',
        );
        return;
      }

      AppAnimationPolicy.showFluidSheet(
        context: context,
        mode: FluidSheetMode.nestedScrollable,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx, __) {
          final isDark = Theme.of(sheetCtx).brightness == Brightness.dark;
          final accent = ref.watch(accentPresetProvider);

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151C28) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                top: false,
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
                    Text(
                      'Chọn Bản Sao Lưu Để Khôi Phục',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hệ thống sẽ mở Ma trận đối soát trước khi tiến hành ghi đè.',
                      style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(sheetCtx).size.height * 0.45,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: backups.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final b = backups[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: accent.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.inventory_2_outlined, color: accent.primary, size: 20),
                            ),
                            title: Text(
                              b.formattedDate,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                              ),
                            ),
                            subtitle: Text(
                              '${b.formattedSize} • ${b.txCount > 0 ? '${b.txCount} giao dịch' : b.fileName}',
                              style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: () {
                              Navigator.of(sheetCtx).pop();
                              RestoreDiffModal.show(context, backupItem: b);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        AppFeedback.showError(
          context,
          'Lỗi kết nối Google Drive: $e',
        );
      }
    }
  }

  Widget _buildProfileSquircleAvatar(UserProfile profile, bool isDark) {
    final avatarColor = _parseColor(profile.avatarColorHex);

    Widget avatarContent;
    switch (profile.avatarType) {
      case UserAvatarType.google:
        if (profile.isSignedIn && profile.avatarValue.startsWith('http')) {
          avatarContent = Image.network(
            profile.avatarValue,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackInitialText(profile, avatarColor),
          );
        } else {
          avatarContent = _buildFallbackInitialText(profile, avatarColor);
        }
        break;

      case UserAvatarType.customImage:
        final file = File(profile.avatarValue);
        if (file.existsSync()) {
          avatarContent = Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackInitialText(profile, avatarColor),
          );
        } else {
          avatarContent = _buildFallbackInitialText(profile, avatarColor);
        }
        break;

      case UserAvatarType.emoji:
        avatarContent = Center(
          child: Text(
            profile.avatarValue,
            style: const TextStyle(fontSize: 26),
          ),
        );
        break;

      case UserAvatarType.initials:
      default:
        avatarContent = _buildFallbackInitialText(profile, avatarColor);
        break;
    }

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: avatarColor.withValues(alpha: isDark ? 0.22 : 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: avatarColor.withValues(alpha: 0.6),
          width: 2.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: avatarContent,
      ),
    );
  }

  Widget _buildFallbackInitialText(UserProfile profile, Color color) {
    final initial = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()[0].toUpperCase()
        : 'K';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentThemeMode = ref.watch(themeModeProvider);
    final currentAccent = ref.watch(accentPresetProvider);
    final currentFont = ref.watch(fontFamilyProvider);
    final userProfile = ref.watch(currentUserProfileProvider);
    final backupState = ref.watch(cloudBackupNotifierProvider);
    final db = ref.watch(databaseProvider);
    final deletedCountAsync = ref.watch(deletedTransactionsCountStreamProvider);

    final latestBackup = backupState.backups.isNotEmpty ? backupState.backups.first : null;

    return AppFeedbackDismissRegion(
      child: Scaffold(
        backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
        body: SafeArea(
          child: LuminescentEdgeScaffoldWrapper(
            onRefresh: _handleSettingsRefresh,
            glowColor: currentAccent.primary,
            child: ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                // Header Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tùy chỉnh hệ thống',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                    Text(
                      'Cài Đặt & Giao Diện',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // ===============================================================
                // [KHỐI 1]: HERO PROFILE CARD (TÀI KHOẢN & ĐỊNH DANH)
                // ===============================================================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTokens.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: currentAccent.primary.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: currentAccent.primary.withValues(alpha: isDark ? 0.08 : 0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => AvatarCustomizationSheet.show(context),
                        borderRadius: BorderRadius.circular(18),
                        child: _buildProfileSquircleAvatar(userProfile, isDark),
                      ),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    userProfile.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => _showEditDisplayNameDialog(userProfile),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(3.0),
                                    child: Icon(Icons.edit_outlined, size: 14, color: currentAccent.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),

                            if (userProfile.isSignedIn) ...[
                              Text(
                                userProfile.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.cloud_done_rounded, size: 11, color: Color(0xFF10B981)),
                                        SizedBox(width: 3),
                                        Text(
                                          'Google Drive AppData',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: _handleSignOutInterception,
                                    child: const Text(
                                      'Đăng xuất',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTokens.expense,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Chế độ Ngoại tuyến (Local Only)',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  await ref.read(userProfileNotifierProvider.notifier).signInWithGoogle();
                                  ref.read(cloudBackupNotifierProvider.notifier).loadBackups();
                                },
                                child: Text(
                                  '🔗 Kết nối Google Drive ❯',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: currentAccent.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ===============================================================
                // [KHỐI 2]: TRUNG TÂM ĐỒNG BỘ ĐÁM MÂY (CLOUD SYNC TILES)
                // ===============================================================
                _buildSectionHeader('ĐỒNG BỘ ĐÁM MÂY (GOOGLE DRIVE APPDATA)', isDark),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTokens.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.timer_outlined, color: Color(0xFF0EA5E9), size: 20),
                        ),
                        title: const Text('Tần suất sao lưu tự động', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          _cadenceSummary,
                          style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await CloudCadenceModal.show(context);
                          _loadCadenceSummary();
                        },
                      ),

                      Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),

                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF10B981), size: 20),
                        ),
                        title: const Text('Sao lưu lên Cloud ngay bây giờ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          latestBackup != null
                              ? 'Bản gần nhất: ${latestBackup.formattedDate} (${latestBackup.formattedSize})'
                              : 'Chưa có bản sao lưu trên đám mây',
                          style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                        ),
                        trailing: (backupState.status == CloudBackupStatus.checkpointing ||
                            backupState.status == CloudBackupStatus.encrypting ||
                            backupState.status == CloudBackupStatus.uploading)
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.play_circle_outline_rounded),
                        onTap: (!userProfile.isSignedIn ||
                            backupState.status == CloudBackupStatus.checkpointing ||
                            backupState.status == CloudBackupStatus.encrypting ||
                            backupState.status == CloudBackupStatus.uploading)
                            ? null
                            : () async {
                          HapticFeedback.mediumImpact();
                          try {
                            await ref.read(cloudBackupNotifierProvider.notifier).performBackup();
                            if (context.mounted) {
                              AppFeedback.showSuccess(
                                context,
                                '✓ Đã sao lưu mã hóa AES-GCM lên Google Drive thành công!',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              AppFeedback.showError(
                                context,
                                'Lỗi sao lưu Google Drive: $e',
                              );
                            }
                          }
                        },
                      ),

                      Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),

                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.cloud_download_outlined, color: Color(0xFF6366F1), size: 20),
                        ),
                        title: const Text('Khôi phục dữ liệu từ Cloud', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          userProfile.isSignedIn ? 'Quét và đối soát các bản sao lưu trên Google Drive' : 'Cần đăng nhập Google để sử dụng',
                          style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: userProfile.isSignedIn ? () => _openCloudRestorePicker(context) : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ===============================================================
                // [KHỐI 3]: GIAO DIỆN & MÀU SẮC (PERSISTENT SHARDEPREFERENCES)
                // ===============================================================
                _buildSectionHeader('GIAO DIỆN & MÀU SẮC', isDark),
                const SizedBox(height: 10),

                SlidingSegmentedBar<ThemeMode>(
                  height: 50,
                  duration: const Duration(milliseconds: 185),
                  overshootPx: 1.8,
                  debugLabel: 'Settings.themeMode',
                  selectedValue: currentThemeMode == ThemeMode.dark
                      ? ThemeMode.dark
                      : ThemeMode.light,
                  trackColor: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
                  trackBorderColor: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                  indicatorColor: isDark ? AppTokens.darkCard : Colors.white,
                  indicatorBorderColor: currentAccent.primary,
                  selectedTextColor: currentAccent.primary,
                  mutedTextColor: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                  indicatorShadowColor: currentAccent.primary.withValues(alpha: 0.15),
                  items: const [
                    SlidingSegmentedItem<ThemeMode>(
                      value: ThemeMode.light,
                      label: 'Giao diện Sáng',
                      icon: Icons.wb_sunny_rounded,
                    ),
                    SlidingSegmentedItem<ThemeMode>(
                      value: ThemeMode.dark,
                      label: 'Giao diện Tối',
                      icon: Icons.nightlight_round,
                    ),
                  ],
                  onValueChanged: (mode) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  },
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    _buildStickerPaletteCard(
                      preset: AppAccentPreset.grass,
                      stickerEmoji: '🌿',
                      title: 'Cỏ',
                      color: const Color(0xFF10B981),
                      isSelected: currentAccent == AppAccentPreset.grass,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(accentPresetProvider.notifier).setAccent(AppAccentPreset.grass);
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildStickerPaletteCard(
                      preset: AppAccentPreset.sun,
                      stickerEmoji: '☀️',
                      title: 'Nắng',
                      color: const Color(0xFFF59E0B),
                      isSelected: currentAccent == AppAccentPreset.sun,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(accentPresetProvider.notifier).setAccent(AppAccentPreset.sun);
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildStickerPaletteCard(
                      preset: AppAccentPreset.sea,
                      stickerEmoji: '🌊',
                      title: 'Biển',
                      color: const Color(0xFF0EA5E9),
                      isSelected: currentAccent == AppAccentPreset.sea,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(accentPresetProvider.notifier).setAccent(AppAccentPreset.sea);
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildStickerPaletteCard(
                      preset: AppAccentPreset.flower,
                      stickerEmoji: '🌸',
                      title: 'Hoa',
                      color: const Color(0xFFF43F5E),
                      isSelected: currentAccent == AppAccentPreset.flower,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(accentPresetProvider.notifier).setAccent(AppAccentPreset.flower);
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildStickerPaletteCard(
                      preset: AppAccentPreset.night,
                      stickerEmoji: '🌙',
                      title: 'Đêm',
                      color: const Color(0xFF6366F1),
                      isSelected: currentAccent == AppAccentPreset.night,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(accentPresetProvider.notifier).setAccent(AppAccentPreset.night);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ===============================================================
                // [KHỐI 4]: KIỂU CHỮ (5 FONT ENGINE PERSISTENT)
                // ===============================================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('KIỂU CHỮ (5)', isDark),
                    Text(
                      'Chạm để thử ngay',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                _buildFontCardsGrid(
                  fontDefs: _fontDefinitions,
                  currentFont: currentFont,
                  accent: currentAccent,
                  isDark: isDark,
                  onSelectFont: (name) {
                    HapticFeedback.selectionClick();
                    ref.read(fontFamilyProvider.notifier).setFontFamily(name);
                  },
                ),
                const SizedBox(height: 24),

                // ===============================================================
                // [KHỐI 5]: QUẢN LÝ DỮ LIỆU & BẢO MẬT KÉT & THÙNG RÁC
                // ===============================================================
                _buildSectionHeader('QUẢN LÝ DỮ LIỆU & BẢO MẬT', isDark),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppTokens.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: currentAccent.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.category_rounded, color: currentAccent.primary, size: 20),
                        ),
                        title: const Text('Quản lý danh mục & Ngân sách', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: const Text('Cấu trúc thu chi 2 cấp, icon và màu sắc'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagerScreen()));
                        },
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),

                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.handshake_rounded, color: Color(0xFF10B981), size: 20),
                        ),
                        title: const Text('Sổ Nợ & Danh Bạ Đối Ứng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: const Text('Quản lý nợ phải thu, phải trả và đối tác'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DebtDashboardScreen()));
                        },
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),

                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.pin_rounded, color: Color(0xFFF59E0B), size: 20),
                        ),
                        title: const Text('Đổi mã PIN Két Tiết Kiệm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: const Text('Chuyển đổi độ dài 4 hoặc 6 số bảo mật'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VaultPinChangeScreen()));
                        },
                      ),
                      Divider(height: 1, indent: 16, endIndent: 16, color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),

                      // 🌟 MỤC THÙNG RÁC & LỊCH SỬ XÓA
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTokens.expense.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: AppTokens.expense, size: 20),
                        ),
                        title: const Text('Thùng rác & Lịch sử xóa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        subtitle: const Text('Khôi phục hoặc xóa hẳn giao dịch trong 30 ngày'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            deletedCountAsync.maybeWhen(
                              data: (count) {
                                if (count <= 0) return const SizedBox.shrink();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: AppTokens.expense.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTokens.expense.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppTokens.expense,
                                    ),
                                  ),
                                );
                              },
                              orElse: () => const SizedBox.shrink(),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecycleBinScreen()));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ===============================================================
                // [KHỐI 6]: DRIFT SQLITE ZERO-LATENCY ENGINE & DỮ LIỆU MẪU
                // ===============================================================
                _buildSectionHeader('LƯU TRỮ CƠ SỞ DỮ LIỆU CỤC BỘ', isDark),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTokens.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTokens.income.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.storage_rounded, size: 20, color: AppTokens.income),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Drift SQLite Engine (Schema v7)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                ),
                                Text(
                                  'pfm_local_vault.sqlite (Bảo mật, Soft-Delete & Thùng rác 30 ngày)',
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
                      const Divider(height: 22),

                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.restore_rounded, color: currentAccent.primary, size: 22),
                        title: Text(
                          'Khôi phục dữ liệu mẫu (Seed Mock Data)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                        subtitle: Text(
                          'Tái tạo 3 ví mặc định, cây danh mục 2 cấp và các giao dịch',
                          style: TextStyle(fontSize: 10, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                        onTap: () async {
                          await DatabaseSeeder.seedInitialData(db);
                          if (!context.mounted) return;
                          AppFeedback.showSuccess(
                            context,
                            'Đã cập nhật dữ liệu khởi đầu SQLite thành công!',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SUB-WIDGETS & HELPERS ---

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
      ),
    );
  }

  Widget _buildStickerPaletteCard({
    required AppAccentPreset preset,
    required String stickerEmoji,
    required String title,
    required Color color,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.14)
                : (isDark ? AppTokens.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Column(
            children: [
              Text(stickerEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : (isDark ? AppTokens.darkText : AppTokens.lightText),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 22,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontCardsGrid({
    required List<FontItemDef> fontDefs,
    required String currentFont,
    required AppAccentPreset accent,
    required bool isDark,
    required ValueChanged<String> onSelectFont,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildSingleFontCard(fontDefs[0], currentFont, accent, isDark, onSelectFont)),
            const SizedBox(width: 8),
            Expanded(child: _buildSingleFontCard(fontDefs[1], currentFont, accent, isDark, onSelectFont)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildSingleFontCard(fontDefs[2], currentFont, accent, isDark, onSelectFont)),
            const SizedBox(width: 8),
            Expanded(child: _buildSingleFontCard(fontDefs[3], currentFont, accent, isDark, onSelectFont)),
          ],
        ),
        const SizedBox(height: 8),
        _buildSingleFontCard(fontDefs[4], currentFont, accent, isDark, onSelectFont),
      ],
    );
  }

  Widget _buildSingleFontCard(
      FontItemDef font,
      String currentFont,
      AppAccentPreset accent,
      bool isDark,
      ValueChanged<String> onSelect,
      ) {
    final isSelected = currentFont == font.name;

    return InkWell(
      onTap: () => onSelect(font.name),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.primary.withValues(alpha: 0.10)
              : (isDark ? AppTokens.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent.primary : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: accent.primary.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    font.badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? accent.primary : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                    ),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? accent.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? accent.primary : (isDark ? Colors.white30 : Colors.black26),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              font.name,
              style: font.fontBuilder(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTokens.darkText : AppTokens.lightText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              font.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mẫu: 1.250.000 ₫ • Cà phê',
              style: font.fontBuilder(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? accent.primary : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
