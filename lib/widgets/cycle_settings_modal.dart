// ==============================================================================
// File: lib/widgets/cycle_settings_modal.dart
// Architecture: Financial Cycle Configuration Modal with Drum Wheel Picker
// Stack: flutter_riverpod, intl
// Features: Salary Day Quick-Chips, Drum Wheel 1-31, Real-time Cycle Preview,
//           Days Remaining Counter, Haptic per tick, System Font Inheritance
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../theme/app_theme.dart';

// StateProvider quản lý ngày bắt đầu chu kỳ tài chính mỗi tháng (Mặc định: ngày 10)
final financialCycleStartDayProvider = StateProvider<int>((ref) => 10);

class CycleRangeResult {
  final DateTime startDate;
  final DateTime endDate;
  final int daysRemaining;
  final int totalDays;

  CycleRangeResult({
    required this.startDate,
    required this.endDate,
    required this.daysRemaining,
    required this.totalDays,
  });
}

class CycleSettingsModal extends ConsumerStatefulWidget {
  const CycleSettingsModal({super.key});

  static Future<void> show(BuildContext context) {
    return AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => const CycleSettingsModal(),
    );
  }

  @override
  ConsumerState<CycleSettingsModal> createState() => _CycleSettingsModalState();
}

class _CycleSettingsModalState extends ConsumerState<CycleSettingsModal> {
  late int _selectedStartDay;
  late FixedExtentScrollController _wheelController;

  @override
  void initState() {
    super.initState();
    _selectedStartDay = ref.read(financialCycleStartDayProvider);
    _wheelController = FixedExtentScrollController(
      initialItem: _selectedStartDay - 1, // 0-indexed
    );
  }

  @override
  void dispose() {
    _wheelController.dispose();
    super.dispose();
  }

  // Thuật toán tính toán chu kỳ tài chính thực tế theo ngày bắt đầu
  CycleRangeResult _calculateCycleRange(int startDay) {
    final now = DateTime(2026, 9, 9, 23, 59, 59); // Mốc thời gian tham chiếu của ứng dụng

    DateTime startDate;
    DateTime endDate;

    if (now.day >= startDay) {
      // Đang trong chu kỳ bắt đầu từ tháng này
      startDate = DateTime(now.year, now.month, startDay);
      // Kết thúc vào ngày (startDay - 1) của tháng sau
      endDate = (now.month == 12)
          ? DateTime(now.year + 1, 1, startDay).subtract(const Duration(seconds: 1))
          : DateTime(now.year, now.month + 1, startDay).subtract(const Duration(seconds: 1));
    } else {
      // Đang trong chu kỳ bắt đầu từ tháng trước
      startDate = (now.month == 1)
          ? DateTime(now.year - 1, 12, startDay)
          : DateTime(now.year, now.month - 1, startDay);
      // Kết thúc vào ngày (startDay - 1) của tháng này
      endDate = DateTime(now.year, now.month, startDay).subtract(const Duration(seconds: 1));
    }

    final totalDays = endDate.difference(startDate).inDays + 1;
    final daysRemaining = (endDate.difference(now).inHours / 24).ceil().clamp(1, totalDays);

    return CycleRangeResult(
      startDate: startDate,
      endDate: endDate,
      daysRemaining: daysRemaining,
      totalDays: totalDays,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final cycleResult = _calculateCycleRange(_selectedStartDay);
    // Kế thừa fontFamily từ Theme hệ thống
    final systemFont = Theme.of(context).textTheme.bodyMedium?.fontFamily;

    final dateFormat = DateFormat('dd/MM/yyyy');
    final formattedRange =
        '${dateFormat.format(cycleResult.startDate)} → ${dateFormat.format(cycleResult.endDate)}';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF151C28).withValues(alpha: 0.96)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
              width: 1,
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Centered Drag Handle
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

                  // 2. Modal Header — microcopy cập nhật
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mốc chu kỳ tài chính',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chọn ngày bắt đầu chu kỳ hàng tháng',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 3. Salary Quick-Preset Chips — microcopy cập nhật
                  Text(
                    'NGÀY BẮT ĐẦU PHỔ BIẾN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1, 5, 10, 15, 20, 25].map((day) {
                      final isSelected = _selectedStartDay == day;
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedStartDay = day);
                          _wheelController.animateToItem(
                            day - 1,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accent.primary.withValues(alpha: 0.16)
                                : (isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? accent.primary
                                  : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                              width: isSelected ? 1.6 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                              BoxShadow(
                                color: accent.primary.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                                : null,
                          ),
                          child: Text(
                            'Ngày ${day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected
                                  ? accent.primary
                                  : (isDark ? AppTokens.darkText : AppTokens.lightText),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // 4. Drum Wheel Picker 1-31 — thay Slider cũ
                  Center(
                    child: Text(
                      'Bắt đầu vào Ngày ${_selectedStartDay.toString().padLeft(2, '0')} hàng tháng',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Drum wheel container với khung kính giữa
                  SizedBox(
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Khung kính nổi bật item đang chọn
                        Container(
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          decoration: BoxDecoration(
                            color: accent.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: accent.primary.withValues(alpha: 0.40),
                              width: 1.4,
                            ),
                          ),
                        ),
                        // Fade mask top & bottom
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  (isDark ? const Color(0xFF151C28) : Colors.white).withValues(alpha: 0.82),
                                  Colors.transparent,
                                  Colors.transparent,
                                  (isDark ? const Color(0xFF151C28) : Colors.white).withValues(alpha: 0.82),
                                ],
                                stops: const [0.0, 0.28, 0.72, 1.0],
                              ),
                            ),
                          ),
                        ),
                        // ListWheelScrollView
                        ListWheelScrollView.useDelegate(
                          controller: _wheelController,
                          itemExtent: 52,
                          diameterRatio: 1.6,
                          perspective: 0.003,
                          physics: const FixedExtentScrollPhysics(),
                          onSelectedItemChanged: (index) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedStartDay = index + 1);
                          },
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: 31,
                            builder: (context, index) {
                              final day = index + 1;
                              final isSelected = _selectedStartDay == day;
                              final distance = (day - _selectedStartDay).abs();
                              final opacity = isSelected
                                  ? 1.0
                                  : (distance == 1 ? 0.55 : 0.28);

                              return Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 140),
                                  style: TextStyle(
                                    fontFamily: systemFont,
                                    fontSize: isSelected ? 34 : 18,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                    color: isSelected
                                        ? accent.primary
                                        : (isDark ? AppTokens.darkText : AppTokens.lightText)
                                            .withValues(alpha: opacity),
                                    letterSpacing: isSelected ? -0.5 : 0,
                                  ),
                                  child: Text(day.toString().padLeft(2, '0')),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 5. Dynamic Live Cycle Preview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CHU KỲ TÍNH TOÁN ÁP DỤNG',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTokens.income.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Còn ${cycleResult.daysRemaining} ngày',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTokens.income,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formattedRange,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            fontFamily: systemFont,
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tổng thời gian chu kỳ: ${cycleResult.totalDays} ngày',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 6. Persistence & Action CTA Button — microcopy cập nhật
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent.primary,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        // Persist into Riverpod StateProvider
                        ref.read(financialCycleStartDayProvider.notifier).state = _selectedStartDay;

                        Navigator.of(context).pop();

                        // AppFeedback thay vì ScaffoldMessenger.showSnackBar
                        AppFeedback.showSuccess(
                          context,
                          'Đã áp dụng chu kỳ từ Ngày ${_selectedStartDay.toString().padLeft(2, '0')} hàng tháng',
                          emitHaptic: false,
                          icon: Icons.check_circle_outline_rounded,
                        );
                      },
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '✓  Áp dụng chu kỳ này',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}