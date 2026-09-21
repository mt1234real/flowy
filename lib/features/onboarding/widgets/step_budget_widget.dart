// ==============================================================================
// File: lib/features/onboarding/widgets/step_budget_widget.dart
// Architecture: Onboarding Step 3 - Target Budget & "Aha Moment" Safe-to-Spend
// Stack: flutter, flutter_riverpod, intl
// Features:
// 1. Thanh tiến trình phân đoạn: "TIẾN TRÌNH 3/3" (Hoàn tất).
// 2. Tiêu đề hướng dẫn tâm lý học ngân sách:
//    - "Hạn mức chi tiêu mong muốn chu kỳ này"
//    - Phụ đề: "Khoản tiền tối đa bạn muốn chi tiêu cho nhu cầu & sở thích cá nhân."
// 3. TextField định dạng tiền tệ thông minh:
//    - Tự động phân tách dấu chấm hàng nghìn chuẩn vi_VN (vd: gõ số tự nhảy 4.500.000 ₫).
//    - Tự động request focus khi vừa bước vào màn hình.
//    - Dải chip chọn nhanh hạn mức thông dụng (5M, 10M, 15M, 20M).
// 4. Thẻ tính toán tức thì "Aha Moment" (Dynamic Safe-Spend Card):
//    - Realtime Reactive: Tính số tiền chi tiêu an toàn mỗi ngày:
//      Daily Safe Spend = (Hạn mức nhập vào) / (Tổng số ngày trong chu kỳ hiện tại).
//    - Thiết kế Frosted Glass với viền phát sáng Accent:
//      Icon 💡 + "Thuật toán Flowy tính toán:"
//      "Mỗi ngày bạn có khoảng ~[Số tiền]/ngày để chi tiêu an toàn mà không bị cạn túi cuối tháng!"
//    - Hiệu ứng nhảy số mượt mà với AnimatedSwitcher.
// 5. Nút bấm hoàn tất trải nghiệm:
//    - [ HOÀN TẤT & KHÁM PHÁ FLOWY 🚀 ]
//    - Gọi completeOnboarding(), ghi SharedPreferences & SQLite rồi chuyển tiếp vào MainScaffold.
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../screens/main_scaffold.dart';
import '../../../theme/app_theme.dart';
import '../controllers/onboarding_controller.dart';

class StepBudgetWidget extends ConsumerStatefulWidget {
  const StepBudgetWidget({super.key});

  @override
  ConsumerState<StepBudgetWidget> createState() => _StepBudgetWidgetState();
}

class _StepBudgetWidgetState extends ConsumerState<StepBudgetWidget> {
  late final TextEditingController _budgetController;
  late final FocusNode _focusNode;

  final NumberFormat _formatter = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    final initialBudget = ref.read(onboardingControllerProvider).monthlyBudget;
    _budgetController = TextEditingController(
      text: initialBudget > 0 ? _formatter.format(initialBudget.round()) : '',
    );
    _focusNode = FocusNode();

    // Tự động focus bàn phím số sau khi render khung nhìn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onBudgetChanged(String val) {
    final cleanDigits = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      ref.read(onboardingControllerProvider.notifier).updateMonthlyBudget(0.0);
      _budgetController.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      return;
    }

    final double amount = double.tryParse(cleanDigits) ?? 0.0;
    ref.read(onboardingControllerProvider.notifier).updateMonthlyBudget(amount);

    final formatted = _formatter.format(amount.round());
    _budgetController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Tính toán số ngày trong chu kỳ hiện tại
  int _calculateDaysInCycle(int startDay) {
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

    final totalDays = cycleEnd.difference(cycleStart).inDays + 1;
    return totalDays > 0 ? totalDays : 30;
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount);
  }

  void _finishAndLaunchApp() async {
    HapticFeedback.heavyImpact();
    await ref.read(onboardingControllerProvider.notifier).completeOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScaffold()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    final int cycleDays = _calculateDaysInCycle(state.cycleStartDay);
    final double dailySafeSpend = state.monthlyBudget > 0 ? (state.monthlyBudget / cycleDays) : 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Segment bước 3/3
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'TIẾN TRÌNH 3/3',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
              Text(
                'Mục tiêu tài chính',
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
            'Hạn mức chi tiêu\nmong muốn chu kỳ này',
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
            'Khoản tiền tối đa bạn muốn chi tiêu cho nhu cầu & sở thích cá nhân.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
            ),
          ),
          const SizedBox(height: 24),

          // KHỐI NHẬP TIỀN HẠN MỨC
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTokens.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hạn mức tháng này',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                    Text(
                      'Chu kỳ $cycleDays ngày',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: accent.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _budgetController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onBudgetChanged,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                  ),
                  decoration: InputDecoration(
                    hintText: '10.000.000',
                    hintStyle: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppTokens.darkMuted.withValues(alpha: 0.4) : AppTokens.lightMuted.withValues(alpha: 0.4),
                    ),
                    suffixText: '₫',
                    suffixStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: accent.primary,
                    ),
                    filled: true,
                    fillColor: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: accent.primary, width: 2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Dải chip chọn nhanh hạn mức
                Wrap(
                  spacing: 8,
                  children: [5000000.0, 10000000.0, 15000000.0, 20000000.0].map((preset) {
                    final isSelected = state.monthlyBudget == preset;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _budgetController.text = _formatter.format(preset.round());
                        ref.read(onboardingControllerProvider.notifier).updateMonthlyBudget(preset);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.primary.withValues(alpha: isDark ? 0.25 : 0.15)
                              : (isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? accent.primary : Colors.transparent,
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          '${(preset / 1000000).toStringAsFixed(0)} Triệu',
                          style: TextStyle(
                            fontSize: 11.5,
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
              ],
            ),
          ),
          const SizedBox(height: 18),

          // THẺ "AHA MOMENT" AN TOÀN MỖI NGÀY (Dynamic Safe-Spend Frosted Glass Card)
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.primary.withValues(alpha: isDark ? 0.18 : 0.08),
                      const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: accent.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accent.primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('💡', style: TextStyle(fontSize: 16)),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Thuật toán Flowy tính toán:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Mỗi ngày bạn có khoảng:',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Hiệu ứng nhảy số mượt mà với AnimatedSwitcher
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _formatCurrency(dailySafeSpend),
                        key: ValueKey<double>(dailySafeSpend),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      'để chi tiêu thảnh thơi mà không bị cạn túi vào cuối tháng! 🎉',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // NÚT BẤM HOÀN TẤT CUỐI CÙNG
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: accent.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: _finishAndLaunchApp,
              child: const Text(
                'HOÀN TẤT & KHÁM PHÁ FLOWY 🚀',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}