// ==============================================================================
// File: lib/widgets/dashboard_hero_card.dart
// Architecture: Executive Hero Card "AN TOÀN HÔM NAY" with Bounded Layout & Preserved Motion
// Stack: flutter_riverpod, intl
// ==============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/animation/app_animation_policy.dart';
import '../theme/app_theme.dart';
import 'overrun_resolution_sheet.dart';
import 'pre_purchase_advisor_sheet.dart';
import 'preserved_balance_tumbler.dart';
import 'safe_to_spend_breakdown_sheet.dart';

// ==============================================================================
// 🌟 TOKEN CHUYỂN ĐỘNG NỘI BỘ CHO PRIVACY MASKING
// ==============================================================================

abstract final class _HeroPrivacyMotion {
  static const eyeDuration = Duration(milliseconds: 150);
}

// ==============================================================================
// 🌟 COMPONENT: ICON MẮT BẢO TOÀN CHUYỂN ĐỘNG (_PreservedPrivacyEye)
// ==============================================================================

class _PreservedPrivacyEye extends StatefulWidget {
  final bool isVisible;
  final Color activeColor;
  final Color mutedColor;
  final VoidCallback? onToggle;

  const _PreservedPrivacyEye({
    required this.isVisible,
    required this.activeColor,
    required this.mutedColor,
    this.onToggle,
  });

  @override
  State<_PreservedPrivacyEye> createState() => _PreservedPrivacyEyeState();
}

class _PreservedPrivacyEyeState extends State<_PreservedPrivacyEye>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late bool _visualVisible;
  bool? _previousVisible;

  @override
  void initState() {
    super.initState();
    _visualVisible = widget.isVisible;
    _controller = AnimationController(
      vsync: this,
      duration: _HeroPrivacyMotion.eyeDuration,
      animationBehavior: AnimationBehavior.preserve,
    );
  }

  @override
  void didUpdateWidget(covariant _PreservedPrivacyEye oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible && widget.isVisible != _visualVisible) {
      _previousVisible = _visualVisible;
      _visualVisible = widget.isVisible;
      _controller.forward(from: 0.0).then((_) {
        if (mounted) setState(() => _previousVisible = null);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    _previousVisible = _visualVisible;
    setState(() {
      _visualVisible = !_visualVisible;
    });
    _controller.forward(from: 0.0).then((_) {
      if (mounted) setState(() => _previousVisible = null);
    });
    widget.onToggle?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(22),
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                if (_previousVisible == null) {
                  return Icon(
                    _visualVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 15,
                    color: _visualVisible ? widget.activeColor : widget.mutedColor,
                  );
                }

                final raw = _controller.value;
                final flash = 4.0 * raw * (1.0 - raw);
                final curColor = Color.lerp(
                  _visualVisible ? widget.mutedColor : widget.activeColor,
                  _visualVisible ? widget.activeColor : widget.mutedColor,
                  raw,
                )!;
                final blendedColor = Color.lerp(curColor, widget.activeColor, flash * 0.45)!;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: (1.0 - raw).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 1.0 - (0.15 * raw),
                        child: Icon(
                          _previousVisible! ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          size: 15,
                          color: blendedColor,
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: raw.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.85 + (0.15 * raw),
                        child: Icon(
                          _visualVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          size: 15,
                          color: blendedColor,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 🌟 THẺ HERO CARD "AN TOÀN HÔM NAY" CHÍNH
// ==============================================================================

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
  final VoidCallback? onToggleVisibility;
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
    this.onToggleVisibility,
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
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount);
  }

  Future<void> _showExitFastRecoveryDialog(BuildContext context, WidgetRef ref) async {
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ĐỒNG Ý', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

    final int totalKDays = (fastRecoveryTotalDays ?? ref.watch(fastRecoveryTotalDaysProvider)) ?? 0;
    final int remainingKDays = (fastRecoveryDaysRemaining ?? ref.watch(fastRecoveryDaysRemainingProvider)) ?? 0;
    final double recoveryLimit = (fastRecoveryDailyLimit ?? ref.watch(fastRecoveryDailyLimitProvider)) ?? 0.0;
    final double amortizedDeduction = (amortizedDailyDeduction ?? ref.watch(amortizedDailyDeductionProvider)) ?? 0.0;

    final int totalK = totalKDays > 0 ? totalKDays : remainingKDays;
    final int currentDayIndex = totalK > 0
        ? (totalK - remainingKDays + 1).clamp(1, totalK)
        : 1;

    final resolvedBaseLimit = baseDailyLimit ??
        (breakdown != null && daysRemaining > 0
            ? (breakdown!.freeBudgetRemaining / daysRemaining).floorToDouble()
            : effectiveDailyLimit);

    final resolvedIsOverSpent = isOverSpentToday ?? (todaySpent > resolvedBaseLimit);
    final resolvedOverAmount = overAmount ?? math.max(0.0, todaySpent - resolvedBaseLimit);
    final resolvedFreeBudget = freeBudgetRemaining ?? (breakdown?.freeBudgetRemaining ?? 0.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: activeColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: isDark ? 0.08 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===================================================================
          // HÀNG CHÍNH: CỤM THÔNG TIN BÊN TRÁI & NÚT HÀNH ĐỘNG BÊN PHẢI
          // ===================================================================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (onCardTap != null) {
                      onCardTap!();
                    } else if (breakdown != null) {
                      SafeToSpendBreakdownSheet.show(
                        context,
                        breakdown: breakdown!,
                        isDark: isDark,
                        accent: accent,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shield_rounded, size: 15, color: activeColor),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'An toàn hôm nay',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: activeColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 2),
                          _PreservedPrivacyEye(
                            isVisible: isVisible,
                            activeColor: activeColor,
                            mutedColor: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            onToggle: onToggleVisibility,
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.info_outline_rounded,
                            size: 13,
                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      PreservedBalanceTumbler(
                        isVisible: isVisible,
                        realValue: _formatCurrency(safeToSpendToday),
                        height: 40,
                        alignment: Alignment.centerLeft,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: activeColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),

                      if (resolvedIsOverSpent && remainingKDays > 0)
                        InkWell(
                          onTap: () => _showExitFastRecoveryDialog(context, ref),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: PreservedBalanceTumbler(
                                    isVisible: isVisible,
                                    realValue:
                                    '🎯 Chế độ Bù nhanh (Ngày $currentDayIndex/$totalK: tối đa ${_formatCurrency(recoveryLimit)}/ngày)',
                                    maskedValue:
                                    '🎯 Chế độ Bù nhanh (Ngày $currentDayIndex/$totalK: tối đa ••• ₫/ngày)',
                                    height: 18.0,
                                    alignment: Alignment.centerLeft,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.cancel_outlined, size: 13, color: Color(0xFFF59E0B)),
                              ],
                            ),
                          ),
                        )
                      else if (resolvedIsOverSpent && amortizedDeduction > 0)
                        PreservedBalanceTumbler(
                          isVisible: isVisible,
                          realValue:
                          'Đã dàn đều -${_formatCurrency(amortizedDeduction)}/ngày cho $daysRemaining ngày tới',
                          maskedValue:
                          'Đã dàn đều -••• ₫/ngày cho $daysRemaining ngày tới',
                          height: 18.0,
                          alignment: Alignment.centerLeft,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : AppTokens.lightMuted,
                          ),
                        )
                      else
                        Text(
                          'Chu kỳ tháng ${DateFormat('MM').format(anchorMonth)} • còn $daysRemaining ngày',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : AppTokens.lightMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Flexible(
                flex: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (resolvedIsOverSpent) ...[
                      InkWell(
                        onTap: () {
                          if (onOverrunTap != null) {
                            onOverrunTap!();
                          } else {
                            HapticFeedback.selectionClick();
                            AppAnimationPolicy.showFluidSheet(
                              context: context,
                              mode: FluidSheetMode.scrollable,
                              backgroundColor: Colors.transparent,
                              builder: (_, scrollController) => OverrunResolutionSheet(
                                overAmount: resolvedOverAmount,
                                originalDailySafe: resolvedBaseLimit,
                                daysRemaining: daysRemaining,
                                freeBudgetRemaining: resolvedFreeBudget,
                                scrollController: scrollController,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                              width: 1.0,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('⚠️', style: TextStyle(fontSize: 10)),
                              SizedBox(width: 4),
                              Text(
                                'Cần bù trừ ❯',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    InkWell(
                      onTap: () {
                        if (onAdvisorTap != null) {
                          onAdvisorTap!();
                        } else {
                          HapticFeedback.selectionClick();
                          AppAnimationPolicy.showFluidSheet(
                            context: context,
                            mode: FluidSheetMode.scrollable,
                            backgroundColor: Colors.transparent,
                            builder: (_, scrollController) => PrePurchaseAdvisorSheet(
                              dailySafe: safeToSpendToday,
                              daysRemaining: daysRemaining,
                              freeBudgetRemaining: resolvedFreeBudget,
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: activeColor.withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚖️', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Text(
                              'Có nên mua? ❯',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: activeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: dailyProgressRatio,
              minHeight: 4,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(activeColor),
            ),
          ),
          const SizedBox(height: 6),

          // 🌟 HÀNG NHÃN ĐÁY: CHIA ĐỀU 2 NỬA CỐ ĐỊNH TỌA ĐỘ VÀ SỐ DÍNH LIỀN BÊN CẠNH
          Row(
            children: [
              // Nửa trái: Đã tiêu
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Đã tiêu: ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : AppTokens.lightMuted,
                      ),
                    ),
                    PreservedBalanceTumbler(
                      isVisible: isVisible,
                      realValue: _formatCurrency(todaySpent),
                      maskedValue: '••• ₫',
                      height: 16,
                      alignment: Alignment.centerLeft,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white70 : AppTokens.lightText,
                      ),
                    ),
                  ],
                ),
              ),

              // Nửa phải: Hạn mức (chữ giữ nguyên tọa độ, số đi liền ngay bên cạnh)
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Hạn mức: ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : AppTokens.lightMuted,
                      ),
                    ),
                    PreservedBalanceTumbler(
                      isVisible: isVisible,
                      realValue: _formatCurrency(effectiveDailyLimit),
                      maskedValue: '••• ₫',
                      height: 16,
                      alignment: Alignment.centerLeft,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white70 : AppTokens.lightText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}