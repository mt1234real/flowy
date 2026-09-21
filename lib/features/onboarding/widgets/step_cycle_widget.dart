// ==============================================================================
// File: lib/features/onboarding/widgets/step_cycle_widget.dart
// Architecture: Onboarding Step 2 - Financial Rhythm & Payday Milestone Setup
// Stack: flutter, flutter_riverpod, intl
// Features:
// 1. Thanh tiến trình phân đoạn: "TIẾN TRÌNH 2/3".
// 2. Tiêu đề & phụ đề định hướng hành vi tài chính:
//    - "Chu kỳ chi tiêu bắt đầu vào ngày nào?"
//    - "Thường là ngày bạn nhận lương hoặc ngày đầu tháng để app phân bổ ngân sách chính xác."
// 3. Thẻ Hero Day Badge trực quan:
//    - Khung hiển thị nổi bật "Ngày [ X ] hàng tháng".
//    - Dải ngày chu kỳ động tính toán tức thì theo thời gian thực (vd: 10/09 – 09/10, còn Y ngày).
// 4. Thanh trượt Slider mượt mà (1.0 -> 31.0, 30 divisions, step = 1):
//    - Rung nhẹ HapticFeedback.selectionClick() khi thay đổi giá trị.
//    - Cập nhật tức thì vào OnboardingController.
//    - Dải mốc số hướng dẫn trực quan: 1, 5, 10, 15, 20, 25, 31.
// 5. Cặp nút hành động:
//    - [ Tiếp tục ❯ ]: Lưu state và trượt sang Bước 3.
//    - [ Mặc định: ngày 1 ]: Gán nhanh giá trị 1 và chuyển tiếp.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../controllers/onboarding_controller.dart';

class StepCycleWidget extends ConsumerWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const StepCycleWidget({
    super.key,
    required this.onNext,
    required this.onSkip,
  });

  /// Tính toán dải ngày chu kỳ hiện tại dựa trên mốc ngày bắt đầu
  String _computeCycleRangeString(int startDay) {
    final now = DateTime.now();
    DateTime cycleStart;
    DateTime cycleEnd;

    if (startDay == 1) {
      cycleStart = DateTime(now.year, now.month, 1);
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      cycleEnd = nextMonth.subtract(const Duration(days: 1));
    } else {
      if (now.day >= startDay) {
        cycleStart = DateTime(now.year, now.month, startDay);
        cycleEnd = DateTime(now.year, now.month + 1, startDay).subtract(const Duration(days: 1));
      } else {
        cycleStart = DateTime(now.year, now.month - 1, startDay);
        cycleEnd = DateTime(now.year, now.month, startDay).subtract(const Duration(days: 1));
      }
    }

    final int daysRemaining = cycleEnd.difference(now).inDays + 1;
    final formatter = DateFormat('dd/MM');

    return 'Chu kỳ hiện tại: ${formatter.format(cycleStart)} – ${formatter.format(cycleEnd)} (còn $daysRemaining ngày)';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    final currentDay = state.cycleStartDay;
    final cycleInfoText = _computeCycleRangeString(currentDay);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Segment bước 2/3
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'TIẾN TRÌNH 2/3',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: accent.primary,
                  ),
                ),
              ),
              Text(
                'Nhịp lương & Chu kỳ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'Chu kỳ chi tiêu\nbắt đầu vào ngày nào?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.25,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            'Thường là ngày bạn nhận lương hoặc ngày đầu tháng để app phân bổ ngân sách chính xác.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
            ),
          ),
          const SizedBox(height: 24),

          // THẺ HERO DAY BADGE (Khung hiển thị ngày trung tâm)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            decoration: BoxDecoration(
              color: isDark ? AppTokens.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accent.primary.withValues(alpha: isDark ? 0.4 : 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.primary.withValues(alpha: isDark ? 0.18 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🗓️', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        'MỐC BẮT ĐẦU CHU KỲ',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: accent.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Hiển thị số ngày to bản nổi bật
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Ngày ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Text(
                        '$currentDay',
                        key: ValueKey<int>(currentDay),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          color: accent.primary,
                        ),
                      ),
                    ),
                    Text(
                      ' hàng tháng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Dải ngày chu kỳ động
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cycleInfoText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // KHỐI THANH TRƯỢT SLIDER
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent.primary,
              inactiveTrackColor: isDark ? AppTokens.darkCardSubtle : Colors.black12,
              trackHeight: 6.0,
              thumbColor: accent.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0, elevation: 3.0),
              overlayColor: accent.primary.withValues(alpha: 0.18),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 22.0),
              valueIndicatorColor: accent.primary,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            child: Slider(
              value: currentDay.toDouble(),
              min: 1.0,
              max: 31.0,
              divisions: 30,
              label: 'Ngày $currentDay',
              onChanged: (val) {
                final selected = val.round();
                if (selected != currentDay) {
                  HapticFeedback.selectionClick();
                  ref.read(onboardingControllerProvider.notifier).updateCycleStartDay(selected);
                }
              },
            ),
          ),

          // Dải mốc số trực quan bên dưới slider: 1, 5, 10, 15, 20, 25, 31
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [1, 5, 10, 15, 20, 25, 31].map((milestone) {
                final isCurrent = currentDay == milestone;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(onboardingControllerProvider.notifier).updateCycleStartDay(milestone);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? accent.primary.withValues(alpha: isDark ? 0.25 : 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$milestone',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                        color: isCurrent
                            ? accent.primary
                            : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),

          // Cụm Nút Hành Động
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                onNext();
              },
              child: const Text(
                'Tiếp tục ❯',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Center(
            child: TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.read(onboardingControllerProvider.notifier).updateCycleStartDay(1);
                onNext();
              },
              child: Text(
                'Mặc định: ngày 1 đầu tháng',
                style: TextStyle(
                  fontSize: 13,
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
}