import 'restore_diff_modal.dart';
import '../services/backup_schedule.dart';
import 'flowy_selection_picker.dart';
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
  daily, // 🌙 Mỗi ngày (02:00 sáng) - Mặc định
  weekly, // 📅 Mỗi tuần (Tối Chủ Nhật)
  manualOnly, // ✋ Tắt tự động (Chỉ thủ công)
  custom, // ⏱️ Tùy biến (Số lượng + Đơn vị: Giờ/Ngày/Tuần)
}

class CloudCadenceModal extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  const CloudCadenceModal({super.key, this.scrollController});

  /// Static launcher tiện lợi để mở Modal từ bất kỳ màn hình nào
  static Future<void> show(BuildContext context) {
    HapticFeedback.selectionClick();
    return AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.scrollable,
      backgroundColor: Colors.transparent,
      builder: (_, scroll) => CloudCadenceModal(scrollController: scroll),
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
  final TextEditingController _customValueController =
      TextEditingController(text: '6');

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
      final modeIndex =
          prefs.getInt(_prefKeyCadenceMode) ?? BackupCadenceMode.daily.index;
      final customUnit = prefs.getString(_prefKeyCustomUnit) ?? 'hours';
      final customVal = prefs.getInt(_prefKeyCustomValue) ?? 6;
      final wifiOnly = prefs.getBool(_prefKeyWifiOnly) ?? true;
      final batterySafe = prefs.getBool(_prefKeyBatterySafe) ?? true;

      if (mounted) {
        setState(() {
          _selectedCadence = BackupCadenceMode
              .values[modeIndex.clamp(0, BackupCadenceMode.values.length - 1)];
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
    await markBackupDirty(prefs);
    await recoverPendingBackup(prefs);
  }

  String _getCadenceDescription() {
    switch (_selectedCadence) {
      case BackupCadenceMode.afterEachEntry:
        return 'Sau lần ghi cuối khoảng 3 phút';
      case BackupCadenceMode.daily:
        return 'Mỗi ngày lúc 02:00';
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
        return '02:00 (${DateFormat('dd/MM').format(target)})';
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

    final latestBackup =
        backupState.backups.isNotEmpty ? backupState.backups.first : null;

    final media = MediaQuery.of(context);
    final topInset =
        View.of(context).padding.top / View.of(context).devicePixelRatio;
    return AppFeedbackDismissRegion(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: (media.size.height - topInset - 12 - media.viewInsets.bottom)
              .clamp(0.0, media.size.height),
          child: Material(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: .98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
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
                              const Text('Cài đặt sao lưu',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('Đồng bộ dữ liệu an toàn cùng Google Drive',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                            ])),
                        IconButton(
                            tooltip: 'Đóng',
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                                backgroundColor:
                                    accent.primary.withValues(alpha: .08)),
                            icon: const Icon(Icons.close_rounded, size: 18)),
                      ]))),
              Expanded(
                  child: SingleChildScrollView(
                      controller: widget.scrollController,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // =========================================================
                            // KHỐI TÀI KHOẢN GOOGLE
                            // =========================================================
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTokens.darkCard
                                    : AppTokens.lightCardSubtle,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? AppTokens.darkBorder
                                      : AppTokens.lightBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.white,
                                      border: Border.all(
                                        color: isDark
                                            ? AppTokens.darkBorder
                                            : AppTokens.lightBorder,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userProfile.isSignedIn
                                              ? userProfile.displayName
                                              : 'Chưa liên kết',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? AppTokens.darkText
                                                : AppTokens.lightText,
                                          ),
                                        ),
                                        Text(
                                          userProfile.email ??
                                              'Nhấn để kết nối Google Drive',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                                  if (userProfile.isSignedIn)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTokens.expense,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () async {
                                        final confirm = await AppAnimationPolicy
                                            .showPreservedDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title:
                                                const Text('Đăng xuất Google?'),
                                            content: const Text(
                                              'Dữ liệu sổ cái trên máy của bạn sẽ được bảo toàn nguyên vẹn.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx)
                                                        .pop(false),
                                                child: const Text('HỦY'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppTokens.expense,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: const Text('ĐĂNG XUẤT'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true && mounted) {
                                          await ref
                                              .read(userProfileNotifierProvider
                                                  .notifier)
                                              .signOut();
                                        }
                                      },
                                      child: const Text('Đăng xuất',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    )
                                  else
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accent.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      onPressed: () async {
                                        await ref
                                            .read(userProfileNotifierProvider
                                                .notifier)
                                            .signInWithGoogle();
                                        if (!mounted) return;
                                        ref
                                            .read(cloudBackupNotifierProvider
                                                .notifier)
                                            .loadBackups();
                                      },
                                      child: const Text('Đăng nhập',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
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
                                color:
                                    isDark ? AppTokens.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark
                                      ? AppTokens.darkBorder
                                      : AppTokens.lightBorder,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.timer_outlined,
                                          size: 18, color: accent.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _getCadenceDescription(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? AppTokens.darkText
                                                : AppTokens.lightText,
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _isCadenceExpanded =
                                              !_isCadenceExpanded);
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: accent.primary
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _isCadenceExpanded
                                                ? 'Thu gọn'
                                                : 'Đổi ▾',
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
                                      Text('• Lần sao lưu kế tiếp: ',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? AppTokens.darkMuted
                                                  : AppTokens.lightMuted)),
                                      Expanded(
                                        child: Text(
                                          _getNextEstimatedBackupTime(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppTokens.darkText
                                                : AppTokens.lightText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text('• Bản sao lưu gần nhất: ',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? AppTokens.darkMuted
                                                  : AppTokens.lightMuted)),
                                      Expanded(
                                        child: Text(
                                          latestBackup != null
                                              ? '${latestBackup.formattedDate} (${latestBackup.formattedSize})'
                                              : 'Chưa có bản sao lưu nào',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: latestBackup != null
                                                ? accent.primary
                                                : (isDark
                                                    ? AppTokens.darkMuted
                                                    : AppTokens.lightMuted),
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
                                        color: isDark
                                            ? AppTokens.darkMuted
                                            : AppTokens.lightMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildPresetOption(
                                      BackupCadenceMode.afterEachEntry,
                                      'Sau mỗi lần ghi',
                                      'Tự động sao lưu sau 3 phút kể từ lần ghi chép gần nhất',
                                      isDark,
                                      accent,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildPresetOption(
                                      BackupCadenceMode.daily,
                                      'Mỗi ngày lúc 02:00',
                                      'Sao lưu ban đêm khi bạn đang ngủ (Khuyên dùng)',
                                      isDark,
                                      accent,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildPresetOption(
                                      BackupCadenceMode.weekly,
                                      'Mỗi Chủ nhật lúc 23:00',
                                      'Chốt sổ tuần vào lúc 23:00 tối Chủ Nhật',
                                      isDark,
                                      accent,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildPresetOption(
                                      BackupCadenceMode.manualOnly,
                                      'Tắt tự động',
                                      'Chỉ sao lưu khi bạn chủ động nhấn nút bên dưới',
                                      isDark,
                                      accent,
                                    ),
                                    const SizedBox(height: 10),

                                    // Custom Cadence Picker
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppTokens.darkCardSubtle
                                            : AppTokens.lightCardSubtle,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tần suất tùy chỉnh',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? AppTokens.darkText
                                                  : AppTokens.lightText,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          LayoutBuilder(
                                              builder: (context, constraints) {
                                            final tall =
                                                MediaQuery.textScalerOf(context)
                                                        .scale(14) >
                                                    18;
                                            final input = SizedBox(
                                                width: 54,
                                                height: tall ? 54 : 42,
                                                child: TextField(
                                                    controller:
                                                        _customValueController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters: [
                                                      FilteringTextInputFormatter
                                                          .digitsOnly
                                                    ],
                                                    textAlign: TextAlign.center,
                                                    textAlignVertical:
                                                        TextAlignVertical
                                                            .center,
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w800),
                                                    decoration: InputDecoration(
                                                        isDense: true,
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 10),
                                                        border: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10)))));
                                            final unit = FlowyDropdown<String>(
                                                minHeight: 42,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                title: 'Chu kỳ sao lưu',
                                                value: _customUnit,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w700),
                                                items: const [
                                                  DropdownMenuItem(
                                                      value: 'hours',
                                                      child:
                                                          Text('Giờ (4–24)')),
                                                  DropdownMenuItem(
                                                      value: 'days',
                                                      child:
                                                          Text('Ngày (1–7)')),
                                                  DropdownMenuItem(
                                                      value: 'weeks',
                                                      child:
                                                          Text('Tuần (1–2)')),
                                                ],
                                                onChanged: (value) {
                                                  if (value != null) {
                                                    setState(() =>
                                                        _customUnit = value);
                                                  }
                                                });
                                            final apply = SizedBox(
                                                height: tall ? 54 : 42,
                                                child: FilledButton(
                                                    style: FilledButton.styleFrom(
                                                        backgroundColor:
                                                            accent.primary,
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                                horizontal: 12),
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    10))),
                                                    onPressed:
                                                        _validateAndApplyCustomCadence,
                                                    child: const Text('Áp dụng',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700))));
                                            if (constraints.maxWidth < 310 ||
                                                tall) {
                                              return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Row(children: [
                                                      input,
                                                      const SizedBox(width: 8),
                                                      Expanded(child: unit)
                                                    ]),
                                                    const SizedBox(height: 8),
                                                    apply
                                                  ]);
                                            }
                                            return Row(children: [
                                              input,
                                              const SizedBox(width: 8),
                                              Expanded(child: unit),
                                              const SizedBox(width: 8),
                                              apply
                                            ]);
                                          }),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tối thiểu 4 giờ giữa hai lần sao lưu tự động.',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isDark
                                                  ? AppTokens.darkMuted
                                                  : AppTokens.lightMuted,
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
                                color: isDark
                                    ? AppTokens.darkMuted
                                    : AppTokens.lightMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color:
                                    isDark ? AppTokens.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? AppTokens.darkBorder
                                      : AppTokens.lightBorder,
                                ),
                              ),
                              child: Column(
                                children: [
                                  SwitchListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    dense: true,
                                    title: Text(
                                      'Chỉ tự động qua mạng không tính phí',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppTokens.darkText
                                            : AppTokens.lightText,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Tiết kiệm dữ liệu di động',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? AppTokens.darkMuted
                                              : AppTokens.lightMuted),
                                    ),
                                    value: _wifiOnly,
                                    activeThumbColor: accent.primary,
                                    activeTrackColor:
                                        accent.primary.withValues(alpha: .28),
                                    onChanged: (val) {
                                      HapticFeedback.selectionClick();
                                      setState(() => _wifiOnly = val);
                                      _persistPreferences();
                                    },
                                  ),
                                  const Divider(height: 1),
                                  SwitchListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    dense: true,
                                    title: Text(
                                      'Hoãn tự động khi thiết bị báo pin yếu',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppTokens.darkText
                                            : AppTokens.lightText,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Tạm hoãn sao lưu tự động khi pin yếu',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? AppTokens.darkMuted
                                              : AppTokens.lightMuted),
                                    ),
                                    value: _batterySafe,
                                    activeThumbColor: accent.primary,
                                    activeTrackColor:
                                        accent.primary.withValues(alpha: .28),
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

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: accent.primary.withValues(alpha: .06),
                                  border: Border.all(
                                      color:
                                          accent.primary.withValues(alpha: .18),
                                      width: .8),
                                  borderRadius: BorderRadius.circular(18)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('GÓI LƯU TRỮ TOÀN VẸN',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 8),
                                    for (final label in const [
                                      'Giao dịch, ví, công nợ, hũ tiết kiệm và thùng rác',
                                      'Màu giao diện, phông chữ và phông tiền tệ',
                                      'Chu kỳ, lịch nhắc và mã PIN két đã băm',
                                    ])
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(Icons.check_rounded,
                                                    size: 16,
                                                    color: accent.primary),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                    child: Text(label,
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            height: 1.4))),
                                              ])),
                                    const SizedBox(height: 6),
                                    const Text(
                                        'Không sao lưu trạng thái hiện số dư hoặc phiên đăng nhập Google.'),
                                    const SizedBox(height: 6),
                                    const Text(
                                        'Lịch tự động trên Android có thể trễ theo chế độ tiết kiệm pin. Sao lưu ngay không chịu các điều kiện tự động.'),
                                  ]),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                                onPressed: () =>
                                    RestoreDiffModal.showLocalRecovery(context),
                                child: const Text(
                                    'Bản dự phòng trước khôi phục trên máy')),
                            // =========================================================
                            // THANH TIẾN ĐỘ SAO LƯU NẾU ĐANG CHẠY
                            // =========================================================
                            if (backupState.status ==
                                    CloudBackupStatus.checkpointing ||
                                backupState.status ==
                                    CloudBackupStatus.encrypting ||
                                backupState.status ==
                                    CloudBackupStatus.uploading) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: accent.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: accent.primary
                                          .withValues(alpha: 0.3)),
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
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    accent.primary),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            backupState.message ??
                                                'Đang thực hiện sao lưu...',
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
                                      backgroundColor: isDark
                                          ? Colors.white12
                                          : Colors.black12,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          accent.primary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ]))),
              SafeArea(
                  top: false,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent.primary,
                              foregroundColor: Colors.white,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: (!userProfile.isSignedIn ||
                                    backupState.status ==
                                        CloudBackupStatus.checkpointing ||
                                    backupState.status ==
                                        CloudBackupStatus.encrypting ||
                                    backupState.status ==
                                        CloudBackupStatus.uploading)
                                ? null
                                : () async {
                                    HapticFeedback.mediumImpact();
                                    try {
                                      await ref
                                          .read(cloudBackupNotifierProvider
                                              .notifier)
                                          .performBackup();
                                      if (context.mounted) {
                                        AppFeedback.showSuccess(
                                          context,
                                          'Đã sao lưu lên Google Drive.',
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
                            icon: const Icon(Icons.cloud_upload_rounded,
                                size: 18),
                            label: const Text(
                              'Sao lưu ngay bây giờ',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3),
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
                              side: BorderSide(
                                  color: accent.primary.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _showHistory();
                            },
                            icon: const Icon(Icons.history_rounded, size: 18),
                            label: const Text(
                              'Lịch sử và khôi phục',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ]))),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _showHistory() async {
    try {
      final backups = await ref.read(cloudBackupServiceProvider).listBackups();
      if (!mounted) return;
      if (backups.isEmpty) {
        AppFeedback.showInfo(context, 'Chưa có bản sao lưu trên Google Drive.');
        return;
      }
      final selected = await showFlowyPicker<String>(
          context: context,
          title: 'Lịch sử sao lưu',
          items: [
            for (final backup in backups)
              DropdownMenuItem(
                  value: backup.fileId,
                  child:
                      Text('${backup.formattedDate} • ${backup.formattedSize}'))
          ]);
      if (!mounted || selected == null || selected.isEmpty) return;
      await RestoreDiffModal.show(context,
          backupItem: backups.firstWhere((b) => b.fileId == selected.first));
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(context, 'Chưa tải được lịch sử: $error');
      }
    }
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
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 16,
              color: isSelected
                  ? accent.primary
                  : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
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
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? accent.primary
                          : (isDark ? AppTokens.darkText : AppTokens.lightText),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
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
