// ==============================================================================
// File: lib/widgets/dashboard_hero_card.dart
// Architecture: Executive Hero Card "AN TOÀN HÔM NAY" with Bounded Layout & Preserved Motion
// Stack: flutter_riverpod, intl
// ==============================================================================

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/animation/app_animation_policy.dart';
import '../theme/app_theme.dart';
import 'overrun_resolution_sheet.dart';
import 'pre_purchase_advisor_sheet.dart';
import 'preserved_balance_tumbler.dart';
import 'currency_text.dart';
import 'safe_to_spend_breakdown_sheet.dart';

class DashboardHeroCard extends ConsumerWidget {
  final SafeToSpendBreakdown? breakdown;
  final double safeToSpendToday;
  final double effectiveDailyLimit;
  final double todaySpent;
  final double dailyProgressRatio;
  final Color activeColor;
  final int daysRemaining;
  final DateTime anchorMonth;
  final bool isVisible;
  final bool? isOverSpentToday;
  final double? overAmount;
  final double? baseDailyLimit;
  final double? freeBudgetRemaining;

  final int? fastRecoveryTotalDays;
  final int? fastRecoveryDaysRemaining;
  final double? fastRecoveryDailyLimit;
  final double? amortizedDailyDeduction;

  final VoidCallback? onCardTap;
  final VoidCallback? onAdvisorTap;
  final VoidCallback? onOverrunTap;
  final VoidCallback? onExitFastRecoveryTap;

  const DashboardHeroCard({
    super.key,
    this.breakdown,
    required this.safeToSpendToday,
    required this.effectiveDailyLimit,
    required this.todaySpent,
    required this.dailyProgressRatio,
    required this.activeColor,
    required this.daysRemaining,
    required this.anchorMonth,
    this.isVisible = false,
    this.isOverSpentToday,
    this.overAmount,
    this.baseDailyLimit,
    this.freeBudgetRemaining,
    this.fastRecoveryTotalDays,
    this.fastRecoveryDaysRemaining,
    this.fastRecoveryDailyLimit,
    this.amortizedDailyDeduction,
    this.onCardTap,
    this.onAdvisorTap,
    this.onOverrunTap,
    this.onExitFastRecoveryTap,
  });

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(amount);
  }

  Future<void> _showExitFastRecoveryDialog(
      BuildContext context, WidgetRef ref) async {
    if (onExitFastRecoveryTap != null) {
      onExitFastRecoveryTap!();
      return;
    }

    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thoát chế độ Bù nhanh?'),
        content: const Text(
          'Bạn có muốn kết thúc sớm chế độ Bù nhanh và đưa hạn mức về bình thường không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('GIỮ LẠI'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ĐỒNG Ý',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(fastRecoveryTotalDaysProvider.notifier).state = 0;
      ref.read(fastRecoveryDaysRemainingProvider.notifier).state = 0;
      ref.read(fastRecoveryDailyLimitProvider.notifier).state = 0.0;
      HapticFeedback.mediumImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(0xFF10B981),
            content: Text('✓ Đã khôi phục hạn mức chi tiêu về mức tiêu chuẩn.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    final int totalKDays =
        (fastRecoveryTotalDays ?? ref.watch(fastRecoveryTotalDaysProvider)) ??
            0;
    final int remainingKDays = (fastRecoveryDaysRemaining ??
            ref.watch(fastRecoveryDaysRemainingProvider)) ??
        0;
    final double recoveryLimit =
        (fastRecoveryDailyLimit ?? ref.watch(fastRecoveryDailyLimitProvider)) ??
            0.0;
    final double amortizedDeduction = (amortizedDailyDeduction ??
            ref.watch(amortizedDailyDeductionProvider)) ??
        0.0;

    final resolvedBaseLimit = baseDailyLimit ??
        (breakdown != null && daysRemaining > 0
            ? (breakdown!.freeBudgetRemaining / daysRemaining).floorToDouble()
            : effectiveDailyLimit);

    final resolvedIsOverSpent =
        isOverSpentToday ?? (todaySpent > resolvedBaseLimit);
    final resolvedOverAmount =
        overAmount ?? math.max(0.0, todaySpent - resolvedBaseLimit);
    final resolvedFreeBudget =
        freeBudgetRemaining ?? (breakdown?.freeBudgetRemaining ?? 0.0);

    final isOverLimit = todaySpent > effectiveDailyLimit && todaySpent > 0;
    final spendingColor = effectiveDailyLimit <= 0
        ? (isDark ? Colors.white38 : Colors.black26)
        : isOverLimit
            ? AppTokens.expense
            : todaySpent / effectiveDailyLimit >= 0.8
                ? AppTokens.warning
                : AppTokens.income;
    final inkColor = isDark ? Colors.white : AppTokens.lightText;
    final muted = isDark ? AppTokens.darkMuted : AppTokens.lightMuted;

    void openBreakdown() {
      if (onCardTap != null) {
        onCardTap!();
      } else if (breakdown != null) {
        SafeToSpendBreakdownSheet.show(context,
            breakdown: breakdown!, isDark: isDark, accent: accent);
      }
    }

    void openOverrun() {
      if (onOverrunTap != null) {
        onOverrunTap!();
      } else {
        AppAnimationPolicy.showFluidSheet(
          context: context,
          mode: FluidSheetMode.scrollable,
          builder: (_, controller) => OverrunResolutionSheet(
              overAmount: resolvedOverAmount,
              originalDailySafe: resolvedBaseLimit,
              daysRemaining: daysRemaining,
              freeBudgetRemaining: resolvedFreeBudget,
              scrollController: controller),
        );
      }
    }

    String compact(double value) =>
        NumberFormat.compact(locale: 'en').format(value);
    final cycleLabel = remainingKDays > 0
        ? 'Bù nhanh: còn $remainingKDays/$totalKDays ngày • ${_formatCurrency(recoveryLimit)}/ngày'
        : amortizedDeduction > 0
            ? 'Đã dàn đều ${_formatCurrency(amortizedDeduction)}/ngày'
            : 'Theo Chu kỳ Tháng ${DateFormat('MM').format(anchorMonth)} (còn $daysRemaining ngày)';

    return SizedBox(
      height: 138,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isDark ? AppTokens.darkBorder : Colors.white,
                  width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 30,
                  child: Row(children: [
                    Expanded(
                        child: InkWell(
                      onTap: openBreakdown,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.shield_outlined,
                              size: 14, color: spendingColor),
                          const SizedBox(width: 4),
                          Text('AN TOÀN HÔM NAY',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: inkColor)),
                          const SizedBox(width: 4),
                          Icon(Icons.info_outline, size: 14, color: muted),
                        ]),
                      ),
                    )),
                    if (resolvedIsOverSpent)
                      InkWell(
                          onTap: openOverrun,
                          child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.tune_rounded,
                                  size: 16, color: spendingColor))),
                    const SizedBox(width: 6),
                    Expanded(
                        child: InkWell(
                      onTap: () {
                        if (onAdvisorTap != null) {
                          onAdvisorTap!();
                          return;
                        }
                        HapticFeedback.selectionClick();
                        AppAnimationPolicy.showFluidSheet(
                          context: context,
                          mode: FluidSheetMode.scrollable,
                          backgroundColor: Colors.transparent,
                          builder: (_, controller) => PrePurchaseAdvisorSheet(
                              dailySafe: safeToSpendToday,
                              daysRemaining: daysRemaining,
                              freeBudgetRemaining: resolvedFreeBudget,
                              scrollController: controller),
                        );
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                            color: accent.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(15)),
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Có nên mua? ❯',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: accent.primary))),
                      ),
                    )),
                  ]),
                ),
                SizedBox(
                    height: 30,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: PreservedBalanceTumbler(
                        isVisible: isVisible,
                        realValue: _formatCurrency(safeToSpendToday),
                        height: 30,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: safeToSpendToday < 0
                                ? AppTokens.expense
                                : inkColor),
                      ),
                    )),
                SizedBox(
                    height: 16,
                    child: InkWell(
                      onTap: remainingKDays > 0
                          ? () => _showExitFastRecoveryDialog(context, ref)
                          : null,
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: CurrencyText(cycleLabel,
                              isVisible: isVisible,
                              style: TextStyle(fontSize: 11, color: muted))),
                    )),
                const Spacer(),
                ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                        value: dailyProgressRatio,
                        minHeight: 4,
                        backgroundColor:
                            isDark ? Colors.white10 : Colors.black12,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(spendingColor))),
                const SizedBox(height: 4),
                SizedBox(
                    height: 16,
                    child: Row(children: [
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: CurrencyText(
                                  'Đã tiêu: ${compact(todaySpent)} ₫',
                                  style:
                                      TextStyle(fontSize: 11, color: muted)))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: CurrencyText(
                                  'Hạn mức: ${compact(effectiveDailyLimit)} ₫',
                                  style:
                                      TextStyle(fontSize: 11, color: muted)))),
                    ])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
