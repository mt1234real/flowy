// ==============================================================================
// File: lib/widgets/cloud_cadence_modal.dart
// Architecture: Cloud Backup Cadence & Google Drive Synchronization Modal (Phase 4)
// Stack: flutter, flutter_riverpod, shared_preferences, intl
// Features:
// 1. Executive Google Account Status Header:
//    - Real-time Account Identity (Google G logo, verified email, One-Tap Sign-out)
// 2. Automatic Backup Cadence Card:
//    - Current Cadence Inspection & Expandable Presets Selector
//    - Presets: After Each Entry (3m debounce), Daily at 02:00 AM (Default), Weekly (Sun), Manual Only
// 3. Custom Cadence Picker with Hardware OS Guardrails:
//    - Enforces >= 4 hours minimum for battery optimization (4h-24h, 1d-7d, 1w-2w)
// 4. Safe Execution Constraints:
//    - [✓] Wi-Fi Only constraint toggle
//    - [✓] Battery level >= 20% / Charging constraint toggle
// 5. Dual Bottom Action Buttons:
//    - [ ☁️ Sao lưu ngay bây giờ ]: Instant encrypted backup trigger with live progress bar
//    - [ 📥 Khôi phục dữ liệu từ Cloud ]: Routes to backup history inspection (Phase 5)
// 6. Dart 3 Pattern Matching Exhaustiveness:
//    - Fully compliant switch-case mapping covering all BackupCadenceMode enum values
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../services/auth_profile_service.dart';
import '../services/cloud_backup_service.dart';
import '../theme/app_theme.dart';

/// Enum phân loại các chế độ chu kỳ sao lưu
enum BackupCadenceMode {
  afterEachEntry, // ⚡ Sau mỗi lần ghi (debounce 3 phút)
  daily,          // 🌙 Mỗi ngày (02:00 sáng) - Mặc định
  weekly,         // 📅 Mỗi tuần (Tối Chủ Nhật)
  manualOnly,     // ✋ Tắt tự động (Chỉ thủ công)
  custom,         // ⏱️ Tùy biến (Số lượng + Đơn vị: Giờ/Ngày/Tuần)
}

class CloudCadenceModal extends ConsumerStatefulWidget {
  const CloudCadenceModal({super.key});

  /// Static launcher tiện lợi để mở Modal từ bất kỳ màn hình nào
  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => const CloudCadenceModal(),
    );
  }

  @override
  ConsumerState<CloudCadenceModal> createState() => _CloudCadenceModalState();
}

class _CloudCadenceModalState extends ConsumerState<CloudCadenceModal> {
  // SharedPreferences keys
  static const String _prefKeyCadenceMode = 'pfm_backup_cadence_mode';
  static const String _prefKeyCustomUnit = 'pfm_backup_custom_unit';
  static const String _prefKeyCustomValue = 'pfm_backup_custom_value';
  static const String _prefKeyWifiOnly = 'pfm_backup_wifi_only';
  static const String _prefKeyBatterySafe = 'pfm_backup_battery_safe';

  BackupCadenceMode _selectedCadence = BackupCadenceMode.daily;
  bool _isCadenceExpanded = false;

  // Custom Cadence state
  String _customUnit = 'hours'; // 'hours', 'days', 'weeks'
  final TextEditingController _customValueController = TextEditingController(text: '6');

  // Điều kiện an toàn
  bool _wifiOnly = true;
  bool _batterySafe = true;

  bool _isLoadingPreferences = true;

  @override
  void initState() {
    super.initState();
    _loadStoredPreferences();
  }

  @override
  void dispose() {
    _customValueController.dispose();
    super.dispose();
  }

  Future<void> _loadStoredPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_prefKeyCadenceMode) ?? BackupCadenceMode.daily.index;
      final customUnit = prefs.getString(_prefKeyCustomUnit) ?? 'hours';
      final customVal = prefs.getInt(_prefKeyCustomValue) ?? 6;
      final wifiOnly = prefs.getBool(_prefKeyWifiOnly) ?? true;
      final batterySafe = prefs.getBool(_prefKeyBatterySafe) ?? true;

      if (mounted) {
        setState(() {
          _selectedCadence = BackupCadenceMode.values[modeIndex.clamp(0, BackupCadenceMode.values.length - 1)];
          _customUnit = customUnit;
          _customValueController.text = customVal.toString();
          _wifiOnly = wifiOnly;
          _batterySafe = batterySafe;
          _isLoadingPreferences = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPreferences = false);
      }
    }
  }

  Future<void> _persistPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyCadenceMode, _selectedCadence.index);
    await prefs.setString(_prefKeyCustomUnit, _customUnit);
    final val = int.tryParse(_customValueController.text.trim()) ?? 6;
    await prefs.setInt(_prefKeyCustomValue, val);
    await prefs.setBool(_prefKeyWifiOnly, _wifiOnly);
    await prefs.setBool(_prefKeyBatterySafe, _batterySafe);
  }

  String _getCadenceDescription() {
    switch (_selectedCadence) {
      case BackupCadenceMode.afterEachEntry:
        return 'Sau mỗi lần ghi chép (Debounce 3 phút)';
      case BackupCadenceMode.daily:
        return 'Mỗi ngày (02:00 sáng) ⭐';
      case BackupCadenceMode.weekly:
        return 'Mỗi tuần (23:00 Chủ Nhật)';
      case BackupCadenceMode.manualOnly:
        return 'Tắt tự động (Chỉ sao lưu thủ công)';
      case BackupCadenceMode.custom:
        final val = int.tryParse(_customValueController.text.trim()) ?? 6;
        String unitLabel = 'Giờ';
        if (_customUnit == 'days') unitLabel = 'Ngày';
        if (_customUnit == 'weeks') unitLabel = 'Tuần';
        return 'Tùy chỉnh: Mỗi $val $unitLabel một lần';
    }
  }

  String _getNextEstimatedBackupTime() {
    final now = DateTime.now();
    switch (_selectedCadence) {
      case BackupCadenceMode.manualOnly:
        return 'Không áp dụng (Chế độ thủ công)';
      case BackupCadenceMode.afterEachEntry:
        return 'Ngay sau khi kết thúc phiên ghi chép';
      case BackupCadenceMode.daily:
        DateTime target = DateTime(now.year, now.month, now.day, 2, 0);
        if (now.isAfter(target)) {
          target = target.add(const Duration(days: 1));
        }
        return '02:00 sáng ngày mai (${DateFormat('dd/MM').format(target)})';
      case BackupCadenceMode.weekly:
        int daysUntilSunday = DateTime.sunday - now.weekday;
        if (daysUntilSunday < 0 || (daysUntilSunday == 0 && now.hour >= 23)) {
          daysUntilSunday += 7;
        }
        final sunday = now.add(Duration(days: daysUntilSunday));
        return '23:00 Chủ Nhật (${DateFormat('dd/MM').format(sunday)})';
      case BackupCadenceMode.custom:
        final val = int.tryParse(_customValueController.text.trim()) ?? 6;
        Duration offset = Duration(hours: val);
        if (_customUnit == 'days') offset = Duration(days: val);
        if (_customUnit == 'weeks') offset = Duration(days: val * 7);
        final next = now.add(offset);
        return DateFormat('HH:mm - dd/MM/yyyy').format(next);
    }
  }

  void _validateAndApplyCustomCadence() {
    int val = int.tryParse(_customValueController.text.trim()) ?? 6;
    if (_customUnit == 'hours') {
      // Ràng buộc bảo vệ pin máy: không cho phép dưới 4 giờ
      if (val < 4) val = 4;
      if (val > 24) val = 24;
    } else if (_customUnit == 'days') {
      if (val < 1) val = 1;
      if (val > 7) val = 7;
    } else if (_customUnit == 'weeks') {
      if (val < 1) val = 1;
      if (val > 2) val = 2;
    }

    setState(() {
      _customValueController.text = val.toString();
      _selectedCadence = BackupCadenceMode.custom;
      _isCadenceExpanded = false;
    });
    _persistPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final userProfile = ref.watch(currentUserProfileProvider);
    final backupState = ref.watch(cloudBackupNotifierProvider);

    if (_isLoadingPreferences) {
      return const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final latestBackup = backupState.backups.isNotEmpty ? backupState.backups.first : null;

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
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag indicator
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

                    // Header Modal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0EA5E9).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.cloud_sync_rounded,
                                color: Color(0xFF0EA5E9),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CÀI ĐẶT SAO LƯU CLOUD',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                ),
                                Text(
                                  'Thư mục Google Drive AppData bí mật',
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
                    const SizedBox(height: 16),

                    // =========================================================
                    // KHỐI TÀI KHOẢN GOOGLE
                    // =========================================================
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.white10 : Colors.white,
                              border: Border.all(
                                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'G',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userProfile.isSignedIn ? userProfile.displayName : 'Chưa liên kết',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                ),
                                Text(
                                  userProfile.email ?? 'Nhấn để kết nối Google Drive',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (userProfile.isSignedIn)
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppTokens.expense,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Đăng xuất Google?'),
                                    content: const Text(
                                      'Dữ liệu sổ cái trên máy của bạn sẽ được bảo toàn nguyên vẹn.',
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
                                        child: const Text('ĐĂNG XUẤT'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true && mounted) {
                                  await ref.read(userProfileNotifierProvider.notifier).signOut();
                                }
                              },
                              child: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
                            )
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                await ref.read(userProfileNotifierProvider.notifier).signInWithGoogle();
                                ref.read(cloudBackupNotifierProvider.notifier).loadBackups();
                              },
                              child: const Text('Đăng nhập', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // =========================================================
                    // KHỐI TẦN SUẤT SAO LƯU TỰ ĐỘNG
                    // =========================================================
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTokens.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF10B981)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _getCadenceDescription(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _isCadenceExpanded = !_isCadenceExpanded);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accent.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _isCadenceExpanded ? 'Thu gọn' : 'Đổi ▾',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: accent.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),

                          // Dòng phụ: Dự kiến kế tiếp & Bản gần nhất
                          Row(
                            children: [
                              Text('• Lần sao lưu kế tiếp: ', style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted)),
                              Expanded(
                                child: Text(
                                  _getNextEstimatedBackupTime(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('• Bản sao lưu gần nhất: ', style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted)),
                              Expanded(
                                child: Text(
                                  latestBackup != null
                                      ? '${latestBackup.formattedDate} (${latestBackup.formattedSize})'
                                      : 'Chưa có bản sao lưu nào',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: latestBackup != null ? const Color(0xFF10B981) : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // KHỐI MỞ RỘNG ĐỔI TẦN SUẤT
                          if (_isCadenceExpanded) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Chọn nhịp độ tự động:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPresetOption(
                              BackupCadenceMode.afterEachEntry,
                              '⚡ Sau mỗi lần ghi',
                              'Tự động sao lưu sau 3 phút kể từ lần ghi chép gần nhất',
                              isDark,
                              accent,
                            ),
                            const SizedBox(height: 6),
                            _buildPresetOption(
                              BackupCadenceMode.daily,
                              '🌙 Mỗi ngày (02:00 sáng)',
                              'Sao lưu ban đêm khi bạn đang ngủ (Khuyên dùng)',
                              isDark,
                              accent,
                            ),
                            const SizedBox(height: 6),
                            _buildPresetOption(
                              BackupCadenceMode.weekly,
                              '📅 Mỗi tuần (Tối Chủ Nhật)',
                              'Chốt sổ tuần vào lúc 23:00 tối Chủ Nhật',
                              isDark,
                              accent,
                            ),
                            const SizedBox(height: 6),
                            _buildPresetOption(
                              BackupCadenceMode.manualOnly,
                              '✋ Tắt tự động',
                              'Chỉ sao lưu khi bạn chủ động nhấn nút bên dưới',
                              isDark,
                              accent,
                            ),
                            const SizedBox(height: 10),

                            // Custom Cadence Picker
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '⏱️ Nhịp độ tùy chỉnh:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 65,
                                        height: 38,
                                        child: TextField(
                                          controller: _customValueController,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                          ),
                                          decoration: InputDecoration(
                                            contentPadding: EdgeInsets.zero,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _customUnit,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                            ),
                                            dropdownColor: isDark ? AppTokens.darkCard : Colors.white,
                                            items: const [
                                              DropdownMenuItem(value: 'hours', child: Text('Giờ (4h - 24h)')),
                                              DropdownMenuItem(value: 'days', child: Text('Ngày (1d - 7d)')),
                                              DropdownMenuItem(value: 'weeks', child: Text('Tuần (1w - 2w)')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() => _customUnit = val);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accent.primary,
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: _validateAndApplyCustomCadence,
                                        child: const Text('Áp dụng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '💡 Giới hạn tối thiểu 4 giờ để tối ưu tuổi thọ pin thiết bị.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // =========================================================
                    // KHỐI ĐIỀU KIỆN AN TOÀN
                    // =========================================================
                    Text(
                      'Điều kiện an toàn hệ thống:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTokens.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                            dense: true,
                            title: Text(
                              'Chỉ sao lưu khi kết nối Wi-Fi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                              ),
                            ),
                            subtitle: Text(
                              'Bảo toàn dữ liệu mạng 4G/5G di động của bạn',
                              style: TextStyle(fontSize: 10, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                            ),
                            value: _wifiOnly,
                            activeThumbColor: accent.primary,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _wifiOnly = val);
                              _persistPreferences();
                            },
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                            dense: true,
                            title: Text(
                              'Chỉ sao lưu khi pin trên 20% hoặc đang sạc',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                              ),
                            ),
                            subtitle: Text(
                              'Tránh sập nguồn đột ngột khi nén tệp CSDL',
                              style: TextStyle(fontSize: 10, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                            ),
                            value: _batterySafe,
                            activeThumbColor: accent.primary,
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _batterySafe = val);
                              _persistPreferences();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // =========================================================
                    // THANH TIẾN ĐỘ SAO LƯU NẾU ĐANG CHẠY
                    // =========================================================
                    if (backupState.status == CloudBackupStatus.checkpointing ||
                        backupState.status == CloudBackupStatus.encrypting ||
                        backupState.status == CloudBackupStatus.uploading) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: accent.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(accent.primary),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    backupState.message ?? 'Đang thực hiện sao lưu...',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: accent.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: backupState.progress,
                              minHeight: 4,
                              backgroundColor: isDark ? Colors.white12 : Colors.black12,
                              valueColor: AlwaysStoppedAnimation<Color>(accent.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // =========================================================
                    // NÚT HÀNH ĐỘNG Ở CHÂN MODAL
                    // =========================================================
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent.primary,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: (!userProfile.isSignedIn ||
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
                                '✓ Đã tạo bản sao lưu mã hóa AES-GCM thành công trên Google Drive!',
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
                        icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: const Text(
                          '☁️ SAO LƯU NGAY BÂY GIỜ',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Nút Khôi phục dữ liệu từ Cloud
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent.primary,
                          side: BorderSide(color: accent.primary.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          AppFeedback.showInfo(
                            context,
                            'Đang chuẩn bị màn hình đối soát bản sao lưu (Phase 5)...',
                            emitHaptic: false,
                          );
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text(
                          '📥 Khôi phục dữ liệu từ Cloud (Xem lịch sử)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetOption(
      BackupCadenceMode mode,
      String title,
      String subtitle,
      bool isDark,
      AppAccentPreset accent,
      ) {
    final isSelected = _selectedCadence == mode;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedCadence = mode;
          _isCadenceExpanded = false;
        });
        _persistPreferences();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.primary.withValues(alpha: 0.14)
              : (isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accent.primary : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 16,
              color: isSelected ? accent.primary : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? accent.primary : (isDark ? AppTokens.darkText : AppTokens.lightText),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
