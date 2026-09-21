// ==============================================================================
// File: lib/widgets/safe_to_spend_breakdown_sheet.dart
// Architecture: Safe-to-Spend 5-Step Staggered Financial Funnel Breakdown Sheet
// Stack: flutter, intl
// Features:
// 1. Staggered Funnel Financial Transparency:
//    - Dẫn dắt dòng tiền 5 bước so le (Interval 35ms, Curves.easeOutCubic, 400ms).
//    - Mỗi bước trượt nhẹ (Y: +8px -> 0px) kết hợp Fade In (0.0 -> 1.0).
// 2. Bước 3 & Hiệu Ứng Ổ Khóa An Toàn:
//    - Danh sách hóa đơn mở rộng mượt qua AnimatedSize (180ms).
//    - Icon ổ khóa 🔒 nảy nhẹ 1.15x báo hiệu tiền đã được khóa an toàn.
// 3. Target Result Box:
//    - Nảy nhẹ 0.96x -> 1.0x qua Curves.easeOutBack (220ms).
//    - Nhảy số tự nhiên từ 0 -> safeToSpendDaily kèm định dạng tiền tệ.
// 4. HyperOS Hardening:
//    - Toàn bộ controller tạo qua AppAnimationPolicy.createController (preserve).
//    - Mở sheet qua AppAnimationPolicy.showFluidSheet (300ms vào / 250ms ra).
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/animation/app_animation_policy.dart';
import '../theme/app_theme.dart';

// Model DTO phục vụ phân tích bóc tách dòng tiền Safe-to-Spend
class SafeToSpendBreakdown {
  final double totalBudget;
  final double totalSpent;
  final double unpaidBills;
  final List<UnpaidBillItem> unpaidBillItems;
  final double freeBudgetRemaining;
  final int daysRemaining;
  final double safeToSpendDaily;
  final bool hasRecurringBudget;
  final double totalWalletBalance;

  const SafeToSpendBreakdown({
    required this.totalBudget,
    required this.totalSpent,
    required this.unpaidBills,
    required this.unpaidBillItems,
    required this.freeBudgetRemaining,
    required this.daysRemaining,
    required this.safeToSpendDaily,
    required this.hasRecurringBudget,
    required this.totalWalletBalance,
  });
}

class UnpaidBillItem {
  final String categoryName;
  final double budgetAmount;
  final double spentAmount;
  final double remainingDue;

  const UnpaidBillItem({
    required this.categoryName,
    required this.budgetAmount,
    required this.spentAmount,
    required this.remainingDue,
  });
}

class SafeToSpendBreakdownSheet extends StatefulWidget {
  final SafeToSpendBreakdown breakdown;
  final bool isDark;
  final AppAccentPreset accent;
  final ScrollController? scrollController;

  const SafeToSpendBreakdownSheet({
    super.key,
    required this.breakdown,
    required this.isDark,
    required this.accent,
    this.scrollController,
  });

  /// Hàm tiện ích tĩnh mở BottomSheet phân tích dòng tiền bảo toàn hoạt ảnh HyperOS
  static void show(
      BuildContext context, {
        required SafeToSpendBreakdown breakdown,
        required bool isDark,
        required AppAccentPreset accent,
      }) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.scrollable,
      isDismissible: true,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
      builder: (_, scrollController) => SafeToSpendBreakdownSheet(
        breakdown: breakdown,
        isDark: isDark,
        accent: accent,
        scrollController: scrollController,
      ),
    );
  }

  @override
  State<SafeToSpendBreakdownSheet> createState() => _SafeToSpendBreakdownSheetState();
}

class _SafeToSpendBreakdownSheetState extends State<SafeToSpendBreakdownSheet>
    with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  late final AnimationController _resultScaleController;

  late final Animation<double> _step1Animation;
  late final Animation<double> _step2Animation;
  late final Animation<double> _step3Animation;
  late final Animation<double> _step4Animation;
  late final Animation<double> _step5Animation;

  late final Animation<double> _lockPulseAnimation;
  late final Animation<double> _resultScaleAnimation;
  late final Animation<double> _numberAnimation;

  @override
  void initState() {
    super.initState();

    _staggerController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      debugLabel: 'Breakdown.stagger',
    );

    _resultScaleController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      debugLabel: 'Breakdown.resultScale',
    );

    // Xây dựng 5 khoảng thời gian so le
    _step1Animation = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.00, 0.40, curve: Curves.easeOutCubic),
    );
    _step2Animation = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.12, 0.52, curve: Curves.easeOutCubic),
    );
    _step3Animation = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.24, 0.64, curve: Curves.easeOutCubic),
    );
    _step4Animation = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.36, 0.76, curve: Curves.easeOutCubic),
    );
    _step5Animation = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.48, 0.88, curve: Curves.easeOutCubic),
    );

    // Hiệu ứng ổ khóa nảy 1.15x tại bước 3
    _lockPulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.28, 0.64, curve: Curves.easeInOut),
      ),
    );

    // Hộp kết quả nảy nhẹ 0.96x -> 1.0x bằng Curves.easeOutBack
    _resultScaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _resultScaleController,
        curve: Curves.easeOutBack,
      ),
    );

    // Nhảy số mượt mà từ 0 -> giá trị thực tế
    _numberAnimation = Tween<double>(
      begin: 0.0,
      end: widget.breakdown.safeToSpendDaily,
    ).animate(
      CurvedAnimation(
        parent: _resultScaleController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Chạy chuỗi hoạt ảnh so le sau khi render frame đầu tiên
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _staggerController.forward(from: 0.0).then((_) {
        if (mounted) {
          _resultScaleController.forward(from: 0.0);
        }
      });
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _resultScaleController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount);
  }

  Widget _buildStaggeredStep({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = animation.value;
        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 8.0 * (1.0 - progress)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildStepRow({
    required String stepNumber,
    required String label,
    required String amount,
    required String prefix,
    bool isPositive = false,
    bool isExpense = false,
    bool isWarning = false,
    bool isHighlight = false,
  }) {
    Color textColor = widget.isDark ? AppTokens.darkText : AppTokens.lightText;
    if (isPositive) textColor = AppTokens.income;
    if (isExpense) textColor = AppTokens.expense;
    if (isWarning) textColor = AppTokens.warning;
    if (isHighlight) textColor = widget.accent.primary;

    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white12 : Colors.black12,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? AppTokens.darkText : AppTokens.lightText,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: widget.isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$prefix $amount',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            color: textColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF151C28).withValues(alpha: 0.98)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: widget.isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
            ),
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
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Bóc Tách An Toàn Mỗi Ngày',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: widget.isDark ? AppTokens.darkText : AppTokens.lightText,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Công thức tài chính bảo lưu các hóa đơn bắt buộc chưa thanh toán trước khi chia đều cho số ngày còn lại.',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // BƯỚC 1: Tổng ngân sách / Số dư
                  _buildStaggeredStep(
                    animation: _step1Animation,
                    child: _buildStepRow(
                      stepNumber: '1',
                      label: widget.breakdown.hasRecurringBudget
                          ? 'Tổng ngân sách định kỳ chu kỳ này'
                          : 'Tổng số dư khả dụng thực tế trong ví',
                      amount: _formatCurrency(widget.breakdown.totalBudget),
                      isPositive: true,
                      prefix: '+',
                    ),
                  ),
                  const SizedBox(height: 10),

                  // BƯỚC 2: Đã chi tiêu thực tế
                  _buildStaggeredStep(
                    animation: _step2Animation,
                    child: _buildStepRow(
                      stepNumber: '2',
                      label: 'Đã chi tiêu thực tế đến hôm nay',
                      amount: _formatCurrency(widget.breakdown.totalSpent),
                      isExpense: true,
                      prefix: '-',
                    ),
                  ),
                  const SizedBox(height: 10),

                  // BƯỚC 3: Dự trù hóa đơn bắt buộc chưa trả & Ổ khóa
                  _buildStaggeredStep(
                    animation: _step3Animation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepRow(
                          stepNumber: '3',
                          label: 'Dự trù hóa đơn bắt buộc chưa trả',
                          amount: _formatCurrency(widget.breakdown.unpaidBills),
                          isWarning: widget.breakdown.unpaidBills > 0,
                          prefix: '-',
                        ),
                        if (widget.breakdown.unpaidBillItems.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: widget.isDark
                                    ? AppTokens.darkCardSubtle
                                    : AppTokens.lightCardSubtle,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: widget.isDark
                                      ? AppTokens.darkBorder
                                      : AppTokens.lightBorder,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      ScaleTransition(
                                        scale: _lockPulseAnimation,
                                        child: const Icon(
                                          Icons.lock_clock_outlined,
                                          size: 14,
                                          color: AppTokens.warning,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Các khoản bắt buộc đang giữ lại để thanh toán:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: widget.isDark
                                              ? AppTokens.darkText
                                              : AppTokens.lightText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...widget.breakdown.unpaidBillItems.map((item) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '• ${item.categoryName}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: widget.isDark
                                                  ? AppTokens.darkMuted
                                                  : AppTokens.lightMuted,
                                            ),
                                          ),
                                          Text(
                                            _formatCurrency(item.remainingDue),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // BƯỚC 4: Ngân sách tự do khả chi còn lại
                  _buildStaggeredStep(
                    animation: _step4Animation,
                    child: _buildStepRow(
                      stepNumber: '4',
                      label: 'Ngân sách tự do khả chi còn lại',
                      amount: _formatCurrency(widget.breakdown.freeBudgetRemaining),
                      isHighlight: true,
                      prefix: '=',
                    ),
                  ),
                  const SizedBox(height: 10),

                  // BƯỚC 5: Số ngày còn lại trong chu kỳ
                  _buildStaggeredStep(
                    animation: _step5Animation,
                    child: _buildStepRow(
                      stepNumber: '5',
                      label: 'Số ngày còn lại trong chu kỳ',
                      amount: '${widget.breakdown.daysRemaining} ngày',
                      prefix: '÷',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // HỘP KẾT QUẢ AN TOÀN MỖI NGÀY Ở ĐÁY
                  AnimatedBuilder(
                    animation: _resultScaleController,
                    builder: (context, _) {
                      return ScaleTransition(
                        scale: _resultScaleAnimation,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: widget.breakdown.safeToSpendDaily > 0
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : AppTokens.expense.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: widget.breakdown.safeToSpendDaily > 0
                                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                  : AppTokens.expense.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'MỨC CHI TIÊU AN TOÀN MỖI NGÀY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: widget.breakdown.safeToSpendDaily > 0
                                      ? const Color(0xFF10B981)
                                      : AppTokens.expense,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_formatCurrency(_numberAnimation.value)} / ngày',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  color: widget.breakdown.safeToSpendDaily > 0
                                      ? const Color(0xFF10B981)
                                      : AppTokens.expense,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.breakdown.safeToSpendDaily > 0
                                    ? 'Chi tiêu dưới mức này sẽ đảm bảo bạn không bị thâm hụt tiền trả hóa đơn và hoàn thành mục tiêu chu kỳ.'
                                    : 'Cảnh báo: Bạn cần thắt chặt chi tiêu để bảo đảm đủ tiền thanh toán các hóa đơn bắt buộc còn nợ!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: widget.isDark
                                      ? AppTokens.darkText
                                      : AppTokens.lightText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accent.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'ĐÃ HIỂU',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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