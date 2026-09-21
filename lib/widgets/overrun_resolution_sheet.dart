// ==============================================================================
// File: lib/widgets/overrun_resolution_sheet.dart
// Architecture: Instant Overrun Compensation & Rebalancing Flow (Behavioral UX Phase 2)
// Stack: flutter_riverpod, intl
// Features:
// 1. Triggered automatically when today's unamortized spend exceeds originalDailySafe
// 2. Calming, non-judgmental tone focused entirely on solution-oriented financial agency
// 3. Scenario A: Smooth Amortization across all remaining cycle days (FIXED: Non-Double-Deduction Engine)
//    - newSafeDaily = freeBudgetRemaining > 0 ? (freeBudgetRemaining / futureDays).floorToDouble() : 0.0
//    - dailyDeduction = max(0.0, originalDailySafe - newSafeDaily)
//    - Mutually Exclusive: clears fastRecoveryTotalDays = 0, fastRecoveryDays = 0, fastRecoveryDailyLimit = 0.0
// 4. Scenario B: Dynamic Fast Recovery Discipline (K Days Customization) (FIXED: Deficit Drift Bug)
//    - Behavioral Autonomy: User can choose K days [1, 2, 3, 5, Stepper] from 1 to min(7, daysRemaining - 1)
//    - recoveryLimit = max(15000.0, ((originalDailySafe * kDays - overAmount) / kDays).floorToDouble())
//    - realisticRecoveredLimit = remainingAfterK / daysAfterK (phân bổ đúng lượng tiền thật sự còn lại)
//    - Floor warning hint when recoveryLimit touches 15.000 ₫/day baseline
//    - Deficit warning hint when realisticRecoveredLimit <= recoveryLimit do khoản chi vượt quá lớn
//    - Mutually Exclusive: clears amortizedDailyDeduction = 0.0
// ==============================================================================

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../core/feedback/app_feedback.dart';

// State lưu trữ tổng số ngày bù nhanh đã chọn (K)
final fastRecoveryTotalDaysProvider = StateProvider<int>((ref) => 0);

// State lưu trữ số ngày còn lại đang kích hoạt chế độ "Bù nhanh"
final fastRecoveryDaysRemainingProvider = StateProvider<int>((ref) => 0);

// State lưu trữ hạn mức ghim áp dụng cho những ngày bù nhanh
final fastRecoveryDailyLimitProvider = StateProvider<double>((ref) => 0.0);

// State lưu trữ mức khấu trừ mỗi ngày khi người dùng chọn Phương án A (Dàn đều)
final amortizedDailyDeductionProvider = StateProvider<double>((ref) => 0.0);

enum OverrunStrategy { amortizeCycle, fastCustomDays }

class OverrunResolutionSheet extends ConsumerStatefulWidget {
  final double overAmount; // Số tiền thực tế đã vượt hôm nay: max(0.0, todaySpent - originalDailySafe)
  final double originalDailySafe; // Hạn mức an toàn ban đầu trước khi phát sinh khoản chi hôm nay
  final int daysRemaining; // Số ngày còn lại của chu kỳ (kể cả hôm nay)
  final double freeBudgetRemaining; // Ngân sách tự do thực tế còn lại của chu kỳ (sau khi đã trừ khoản chi hôm nay)
  final ScrollController? scrollController;

  const OverrunResolutionSheet({
    super.key,
    required this.overAmount,
    required this.originalDailySafe,
    required this.daysRemaining,
    required this.freeBudgetRemaining,
    this.scrollController,
  });

  @override
  ConsumerState<OverrunResolutionSheet> createState() => _OverrunResolutionSheetState();
}

class _OverrunResolutionSheetState extends ConsumerState<OverrunResolutionSheet> {
  OverrunStrategy _selectedStrategy = OverrunStrategy.amortizeCycle;
  late int _kDays;

  @override
  void initState() {
    super.initState();
    final int maxDaysAllowed = math.max(1, math.min(7, widget.daysRemaining - 1));
    _kDays = math.min(2, maxDaysAllowed);
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount);
  }

  void _confirmResolution(double dailyDeduction, double newSafeDaily, double recoveryLimit, int remainingDaysAfterToday) {
    HapticFeedback.mediumImpact();

    if (_selectedStrategy == OverrunStrategy.amortizeCycle) {
      // 🌟 PHƯƠNG ÁN A: DÀN ĐỀU CHO CẢ KỲ (MUTUAL EXCLUSIVITY: TRIỆT TIÊU TOÀN BỘ BÙ NHANH)
      ref.read(amortizedDailyDeductionProvider.notifier).state = dailyDeduction;
      ref.read(fastRecoveryTotalDaysProvider.notifier).state = 0;
      ref.read(fastRecoveryDaysRemainingProvider.notifier).state = 0;
      ref.read(fastRecoveryDailyLimitProvider.notifier).state = 0.0;

      AppFeedback.showSuccess(
        context,
        'Đã dàn đều khoản vượt. $remainingDaysAfterToday ngày tới: ${_formatCurrency(newSafeDaily)}/ngày.',
        emitHaptic: false,
      );
      Navigator.of(context).pop();
    } else {
      // 🌟 PHƯƠNG ÁN B: BÙ NHANH TRONG K NGÀY (MUTUAL EXCLUSIVITY: TRIỆT TIÊU TOÀN BỘ DÀN ĐỀU)
      ref.read(fastRecoveryTotalDaysProvider.notifier).state = _kDays;
      ref.read(fastRecoveryDaysRemainingProvider.notifier).state = _kDays;
      ref.read(fastRecoveryDailyLimitProvider.notifier).state = recoveryLimit;
      ref.read(amortizedDailyDeductionProvider.notifier).state = 0.0;

      AppFeedback.showInfo(
        context,
        '🎯 Bù nhanh $_kDays ngày: tối đa ${_formatCurrency(recoveryLimit)}/ngày.',
        emitHaptic: false,
        icon: Icons.bolt_rounded,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    final int remainingDaysAfterToday = math.max(1, widget.daysRemaining - 1);
    final int maxDaysAllowed = math.max(1, math.min(7, remainingDaysAfterToday));

    if (_kDays > maxDaysAllowed) {
      _kDays = maxDaysAllowed;
    }

    // =========================================================================
    // 🌟 CÔNG THỨC CHUẨN XÁC: PHƯƠNG ÁN A (DÀN ĐỀU CHO CẢ KỲ)
    // =========================================================================
    final int futureDays = remainingDaysAfterToday;
    final double newSafeDaily = widget.freeBudgetRemaining > 0
        ? (widget.freeBudgetRemaining / futureDays).floorToDouble()
        : 0.0;
    final double dailyDeduction = math.max(0.0, widget.originalDailySafe - newSafeDaily);

    // =========================================================================
    // 🌟 CÔNG THỨC CHUẨN XÁC: PHƯƠNG ÁN B (BÙ NHANH TRONG K NGÀY - FIX DEFICIT DRIFT)
    // =========================================================================
    final double rawTotalKBudget = (widget.originalDailySafe * _kDays) - widget.overAmount;
    final double recoveryLimit = math.max(15000.0, (rawTotalKBudget / _kDays).floorToDouble());
    final bool isAtFloorLimit = recoveryLimit <= 15000.0;

    // Tính toán hạn mức hồi phục thực tế từ ngày (K+1) trở đi
    final int clampedK = math.min(_kDays, math.max(1, futureDays - 1));
    final double spentDuringK = clampedK * recoveryLimit;
    final double remainingAfterK = math.max(0.0, widget.freeBudgetRemaining - spentDuringK);
    final int daysAfterK = math.max(1, futureDays - clampedK);
    final double realisticRecoveredLimit = remainingAfterK > 0
        ? (remainingAfterK / daysAfterK).floorToDouble()
        : 0.0;
    final bool isSevereDeficit = realisticRecoveredLimit <= recoveryLimit;

    final availablePresets = [1, 2, 3, 5].where((d) => d <= maxDaysAllowed).toList();
    if (!availablePresets.contains(maxDaysAllowed) && maxDaysAllowed > 0) {
      availablePresets.add(maxDaysAllowed);
      availablePresets.sort();
    }

    return AppFeedbackDismissRegion(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151C28).withValues(alpha: 0.98) : Colors.white.withValues(alpha: 0.98),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                controller: widget.scrollController,
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

                    // Header Cảnh báo nhẹ nhàng
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.tune_rounded, color: Color(0xFFF59E0B), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'HÔM NAY ĐÃ CHI VƯỢT MỨC: +${_formatCurrency(widget.overAmount)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFF59E0B),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Text(
                                'Bạn muốn cân đối lại ngân sách thế nào?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Đừng lo lắng! Khoản chi ngoài kế hoạch là hoàn toàn bình thường. Hãy chọn 1 phương án điều phối dưới đây để bảo toàn mục tiêu cuối kỳ.',
                      style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                    ),
                    const SizedBox(height: 16),

                    // ===========================================================
                    // LỰA CHỌN 1: PHƯƠNG ÁN A (DÀN ĐỀU CHO CẢ KỲ - KHUYÊN DÙNG)
                    // ===========================================================
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedStrategy = OverrunStrategy.amortizeCycle);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedStrategy == OverrunStrategy.amortizeCycle
                              ? accent.primary.withValues(alpha: 0.12)
                              : (isDark ? AppTokens.darkCard : Colors.white),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _selectedStrategy == OverrunStrategy.amortizeCycle
                                ? accent.primary
                                : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                            width: _selectedStrategy == OverrunStrategy.amortizeCycle ? 1.8 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _selectedStrategy == OverrunStrategy.amortizeCycle
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: _selectedStrategy == OverrunStrategy.amortizeCycle
                                      ? accent.primary
                                      : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'PHƯƠNG ÁN A: DÀN ĐỀU CHO CẢ KỲ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _selectedStrategy == OverrunStrategy.amortizeCycle
                                          ? accent.primary
                                          : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accent.primary.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Khuyên dùng',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: accent.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Phân bổ lại ngân sách tự do còn lại (${_formatCurrency(widget.freeBudgetRemaining)}) đều cho $remainingDaysAfterToday ngày còn lại.',
                              style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Text('👉 ', style: TextStyle(fontSize: 12)),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkText : AppTokens.lightText),
                                        children: [
                                          const TextSpan(text: 'Mỗi ngày tới giảm: '),
                                          TextSpan(
                                            text: '-${_formatCurrency(dailyDeduction)}/ngày\n',
                                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFF59E0B)),
                                          ),
                                          const TextSpan(text: '(Hạn mức an toàn mới: '),
                                          TextSpan(
                                            text: '${_formatCurrency(newSafeDaily)}/ngày',
                                            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                                          ),
                                          const TextSpan(text: ')'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ===========================================================
                    // LỰA CHỌN 2: PHƯƠNG ÁN B (BÙ NHANH TÙY BIẾN K NGÀY)
                    // ===========================================================
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedStrategy = OverrunStrategy.fastCustomDays);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _selectedStrategy == OverrunStrategy.fastCustomDays
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                              : (isDark ? AppTokens.darkCard : Colors.white),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _selectedStrategy == OverrunStrategy.fastCustomDays
                                ? const Color(0xFFF59E0B)
                                : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                            width: _selectedStrategy == OverrunStrategy.fastCustomDays ? 1.8 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _selectedStrategy == OverrunStrategy.fastCustomDays
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  color: _selectedStrategy == OverrunStrategy.fastCustomDays
                                      ? const Color(0xFFF59E0B)
                                      : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'PHƯƠNG ÁN B: BÙ NHANH TRONG $_kDays NGÀY',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _selectedStrategy == OverrunStrategy.fastCustomDays
                                          ? const Color(0xFFF59E0B)
                                          : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Kỷ luật thép',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Thắt chặt chi tiêu trong $_kDays ngày để đưa ngân sách về mức chuẩn nhanh nhất.',
                              style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                            ),
                            const SizedBox(height: 10),

                            // DÃY CHỌN SỐ NGÀY BÙ K VÀ STEPPER
                            Row(
                              children: [
                                Text(
                                  'Số ngày bù:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: availablePresets.map((days) {
                                        final isSelected = _kDays == days;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 6.0),
                                          child: InkWell(
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                _selectedStrategy = OverrunStrategy.fastCustomDays;
                                                _kDays = days;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(10),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 140),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFFF59E0B)
                                                    : (isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? const Color(0xFFF59E0B)
                                                      : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                                                ),
                                              ),
                                              child: Text(
                                                '$days ngày',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),

                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: _kDays > 1
                                          ? () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _selectedStrategy = OverrunStrategy.fastCustomDays;
                                          _kDays--;
                                        });
                                      }
                                          : null,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.remove_rounded,
                                          size: 16,
                                          color: _kDays > 1
                                              ? (isDark ? AppTokens.darkText : AppTokens.lightText)
                                              : Colors.grey.withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text(
                                        '$_kDays',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'monospace',
                                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _kDays < maxDaysAllowed
                                          ? () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          _selectedStrategy = OverrunStrategy.fastCustomDays;
                                          _kDays++;
                                        });
                                      }
                                          : null,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.add_rounded,
                                          size: 16,
                                          color: _kDays < maxDaysAllowed
                                              ? (isDark ? AppTokens.darkText : AppTokens.lightText)
                                              : Colors.grey.withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text('👉 ', style: TextStyle(fontSize: 12)),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkText : AppTokens.lightText),
                                            children: [
                                              TextSpan(text: 'Trong $_kDays ngày tới tiêu tối đa: '),
                                              TextSpan(
                                                text: '${_formatCurrency(recoveryLimit)}/ngày\n',
                                                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFF43F5E)),
                                              ),
                                              TextSpan(text: '(Sau $_kDays ngày sẽ hồi phục về: '),
                                              TextSpan(
                                                text: '${_formatCurrency(realisticRecoveredLimit)}/ngày',
                                                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                                              ),
                                              const TextSpan(text: ')'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isAtFloorLimit) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFFF59E0B)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Hạn mức đang ở mức sàn sinh hoạt, bạn có thể tăng thêm số ngày bù để thở dễ hơn.',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.amber.shade300 : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (isSevereDeficit) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFEF4444)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Khoản chi vượt khá lớn, sau $_kDays ngày hạn mức vẫn sẽ ở mức thắt chặt (~${_formatCurrency(realisticRecoveredLimit)}/ngày). Hãy cân nhắc tăng số ngày bù hoặc nạp thêm ngân sách.',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedStrategy == OverrunStrategy.amortizeCycle
                              ? accent.primary
                              : const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _confirmResolution(
                          dailyDeduction,
                          newSafeDaily,
                          recoveryLimit,
                          remainingDaysAfterToday,
                        ),
                        child: Text(
                          _selectedStrategy == OverrunStrategy.amortizeCycle
                              ? '✓ XÁC NHẬN DÀN ĐỀU'
                              : '✓ XÁC NHẬN BÙ TRONG $_kDays NGÀY',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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
}