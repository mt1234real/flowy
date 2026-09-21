// ==============================================================================
// File: lib/widgets/cycle_settings_modal.dart
// Architecture: Financial Cycle Configuration Modal with Live Dynamic Preview
// Stack: flutter_riverpod, intl
// Features: Salary Day Quick-Chips, 1-31 Interactive Slider, Real-time Cycle
//           Recalculation, Days Remaining Counter, Dual-Mode Contrast & Haptics
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/animation/app_animation_policy.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedStartDay = ref.read(financialCycleStartDayProvider);
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

                  // 2. Modal Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cài đặt Chu kỳ Tài chính',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chọn ngày nhận lương / ngày bắt đầu chu kỳ',
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

                  // 3. Salary Quick-Preset Chips (Ngày 01, 05, 10, 15, 20, 25)
                  Text(
                    'GỢI Ý NGÀY NHẬN LƯƠNG TIÊU CHUẨN',
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

                  // 4. Center Day Display & Interactive Slider (1 - 31)
                  Center(
                    child: Column(
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                            ),
                            children: [
                              const TextSpan(text: 'Bắt đầu vào '),
                              TextSpan(
                                text: 'Ngày ${_selectedStartDay.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  color: accent.primary,
                                ),
                              ),
                              const TextSpan(text: ' hàng tháng'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: accent.primary,
                            inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                            thumbColor: accent.primary,
                            overlayColor: accent.primary.withValues(alpha: 0.2),
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: _selectedStartDay.toDouble(),
                            min: 1,
                            max: 31,
                            divisions: 30,
                            label: 'Ngày $_selectedStartDay',
                            onChanged: (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedStartDay = val.round());
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
                            fontFamily: 'monospace',
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

                  // 6. Persistence & Action CTA Button
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

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppTokens.income,
                            content: Text(
                              'Đã áp dụng chu kỳ tài chính từ Ngày ${_selectedStartDay.toString().padLeft(2, '0')} hàng tháng',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        );
                      },
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '✓ Áp Dụng Chu Kỳ Này',
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