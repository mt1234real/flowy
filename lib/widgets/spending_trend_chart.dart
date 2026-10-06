import '../services/fiscal_day.dart';
import 'currency_text.dart';
// ==============================================================================
// File: lib/widgets/spending_trend_chart.dart
// Architecture: 100% Real-Data Interactive Spending Trend Bar Chart with Drift SQLite
// Stack: flutter_riverpod, drift, intl
// Features: Real-time Expense Aggregation (7 Ngày, Tháng, Quý, Năm),
//           On-Tap Dynamic Tooltip Header, Luminous Bar Highlight, Empty Tracks,
//           Preserved Motion Hardening (Bảo toàn hoạt ảnh nảy cột trên Xiaomi/HyperOS)
// ==============================================================================

import 'dart:math' as math;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/animation/app_animation_policy.dart';
import '../core/animation/flowy_navigation_motion.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
import '../features/insights/spending_insights_screen.dart';
import 'sliding_segmented_bar.dart';

enum ChartPeriod { days7, month, quarter, year }

class _ChartBucket {
  final String label;
  final String fullDateLabel;
  final double amount;
  final DateTime startDate;
  final DateTime endDate;

  _ChartBucket({
    required this.label,
    required this.fullDateLabel,
    required this.amount,
    required this.startDate,
    required this.endDate,
  });
}

// Provider truy vấn giao dịch khoản chi trong 365 ngày qua để tính toán cho mọi bộ lọc
final chartExpensesStreamProvider =
    StreamProvider.autoDispose<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final oneYearAgo = DateTime.now().subtract(const Duration(days: 366));

  return (db.select(db.transactions)
        ..where((t) =>
            t.deletedAt.isNull() &
            t.goalId.isNull() &
            (t.envelopeType.equals('savings').not() | t.envelopeType.isNull()) &
            t.type.equals(CategoryType.expense.index) &
            t.date.isBiggerOrEqualValue(oneYearAgo))
        ..orderBy([(t) => drift.OrderingTerm.asc(t.date)]))
      .watch();
});

class SpendingTrendChart extends ConsumerStatefulWidget {
  const SpendingTrendChart({super.key, this.isVisible = true});

  final bool isVisible;

  @override
  ConsumerState<SpendingTrendChart> createState() => _SpendingTrendChartState();
}

class _SpendingTrendChartState extends ConsumerState<SpendingTrendChart>
    with SingleTickerProviderStateMixin {
  ChartPeriod _selectedPeriod = ChartPeriod.days7;
  int? _selectedBucketIndex;

  late final AnimationController _barAnimController;
  late final Animation<double> _barCurveAnimation;

  @override
  void initState() {
    super.initState();
    // 🌟 KHỞI TẠO CONTROLLER BẢO TOÀN THỜI LƯỢNG NẨY CỘT TỪ APP ANIMATION POLICY
    _barAnimController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      debugLabel: 'SpendingTrendChartBarAnim',
    );

    _barCurveAnimation = CurvedAnimation(
      parent: _barAnimController,
      curve: Curves.easeOutBack,
    );

    _barAnimController.forward();
  }

  @override
  void dispose() {
    _barAnimController.dispose();
    super.dispose();
  }

  void _triggerBarAnimation() {
    _barAnimController.reset();
    _barAnimController.forward();
  }

  void _selectBar(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedBucketIndex = index);
  }

  void _openInsights() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(flowySurfaceRoute<void>(
        builder: (_) => const SpendingInsightsScreen()));
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(amount);
  }

  List<_ChartBucket> _buildBuckets(
      List<Transaction> allExpenses, ChartPeriod period) {
    final now = ref.watch(fiscalTodayProvider);
    final boundary = ref.watch(dayCutoffProvider);
    final List<_ChartBucket> buckets = [];

    switch (period) {
      case ChartPeriod.days7:
        // 7 ngày gần nhất (từ 6 ngày trước đến hôm nay)
        for (int i = 6; i >= 0; i--) {
          final targetDay = DateTime(now.year, now.month, now.day - i);
          final start =
              DateTime(targetDay.year, targetDay.month, targetDay.day, 0, 0, 0);
          final end = DateTime(
              targetDay.year, targetDay.month, targetDay.day, 23, 59, 59);

          final daySum = allExpenses
              .where((t) =>
                  !t.date.isBefore(boundary.start(start)) &&
                  t.date.isBefore(boundary.end(end)))
              .fold(0.0, (sum, t) => sum + t.amount);

          final weekdayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
          final label = i == 0 ? 'H.nay' : weekdayNames[targetDay.weekday - 1];
          final fullLabel = DateFormat('dd/MM/yyyy').format(targetDay);

          buckets.add(_ChartBucket(
            label: label,
            fullDateLabel: '$label ($fullLabel)',
            amount: daySum,
            startDate: start,
            endDate: end,
          ));
        }
        break;

      case ChartPeriod.month:
        // 4 Tuần của tháng hiện tại
        final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
        final weekRanges = [
          [1, 7],
          [8, 14],
          [15, 21],
          [22, daysInMonth],
        ];

        for (int i = 0; i < weekRanges.length; i++) {
          final startDay = weekRanges[i][0];
          final endDay = weekRanges[i][1];
          final start = DateTime(now.year, now.month, startDay, 0, 0, 0);
          final end = DateTime(now.year, now.month, endDay, 23, 59, 59);

          final weekSum = allExpenses
              .where((t) =>
                  !t.date.isBefore(boundary.start(start)) &&
                  t.date.isBefore(boundary.end(end)))
              .fold(0.0, (sum, t) => sum + t.amount);

          buckets.add(_ChartBucket(
            label: 'Tuần ${i + 1}',
            fullDateLabel:
                'Tuần ${i + 1} ($startDay/T${now.month} - $endDay/T${now.month})',
            amount: weekSum,
            startDate: start,
            endDate: end,
          ));
        }
        break;

      case ChartPeriod.quarter:
        // 3 Tháng của Quý hiện tại
        final currentQuarter = ((now.month - 1) ~/ 3) + 1;
        final quarterStartMonth = (currentQuarter - 1) * 3 + 1;

        for (int i = 0; i < 3; i++) {
          final m = quarterStartMonth + i;
          final start = DateTime(now.year, m, 1, 0, 0, 0);
          final end = DateTime(now.year, m + 1, 0, 23, 59, 59);

          final mSum = allExpenses
              .where((t) =>
                  !t.date.isBefore(boundary.start(start)) &&
                  t.date.isBefore(boundary.end(end)))
              .fold(0.0, (sum, t) => sum + t.amount);

          buckets.add(_ChartBucket(
            label: 'T$m',
            fullDateLabel: 'Tháng $m/${now.year}',
            amount: mSum,
            startDate: start,
            endDate: end,
          ));
        }
        break;

      case ChartPeriod.year:
        // 12 Tháng của năm hiện tại
        for (int m = 1; m <= 12; m++) {
          final start = DateTime(now.year, m, 1, 0, 0, 0);
          final end = DateTime(now.year, m + 1, 0, 23, 59, 59);

          final mSum = allExpenses
              .where((t) =>
                  !t.date.isBefore(boundary.start(start)) &&
                  t.date.isBefore(boundary.end(end)))
              .fold(0.0, (sum, t) => sum + t.amount);

          buckets.add(_ChartBucket(
            label: 'T$m',
            fullDateLabel: 'Tháng $m/${now.year}',
            amount: mSum,
            startDate: start,
            endDate: end,
          ));
        }
        break;
    }

    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final expensesAsync = ref.watch(chartExpensesStreamProvider);

    return expensesAsync.when(
      data: (allExpenses) {
        final buckets = _buildBuckets(
            allExpenses
                .where((t) => t.amount.isFinite && t.amount > 0)
                .toList(),
            _selectedPeriod);
        final totalPeriodExpense =
            buckets.fold(0.0, (sum, b) => sum + b.amount);
        final maxAmount = buckets.map((b) => b.amount).fold(0.0, math.max);

        // Header thông tin động theo mốc chạm vào
        String infoTitle;
        String infoAmount;
        if (_selectedBucketIndex != null &&
            _selectedBucketIndex! < buckets.length) {
          final selectedBucket = buckets[_selectedBucketIndex!];
          infoTitle = selectedBucket.fullDateLabel;
          infoAmount = _formatCurrency(selectedBucket.amount);
        } else {
          infoTitle = _selectedPeriod == ChartPeriod.days7
              ? 'Tổng chi 7 ngày qua'
              : 'Tổng chi (${_getPeriodLabel(_selectedPeriod)})';
          infoAmount = _formatCurrency(totalPeriodExpense);
        }

        return SizedBox(
            height: 258 + (MediaQuery.textScalerOf(context).scale(12) - 12) * 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(
                        child: Text('XU HƯỚNG CHI TIÊU',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800))),
                    TextButton(
                        onPressed: _openInsights,
                        child: Container(
                            constraints: const BoxConstraints(minHeight: 28),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: accent.primary.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(14)),
                            child: const Text('Phân tích nhóm ❯',
                                style: TextStyle(fontSize: 11)))),
                  ]),
                  SlidingSegmentedBar<ChartPeriod>(
                    height: 32,
                    fontSize: 10,
                    debugLabel: 'SpendingTrend.period',
                    selectedValue: _selectedPeriod,
                    trackColor: Colors.transparent,
                    trackBorderColor: Colors.transparent,
                    indicatorColor: accent.primary,
                    indicatorBorderColor: Colors.transparent,
                    indicatorShadowColor: Colors.transparent,
                    selectedTextColor: Colors.white,
                    mutedTextColor:
                        isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                    items: [
                      for (final period in ChartPeriod.values)
                        SlidingSegmentedItem(
                          value: period,
                          label: _getPeriodLabel(period),
                        ),
                    ],
                    onValueChanged: (period) {
                      setState(() {
                        _selectedPeriod = period;
                        _selectedBucketIndex = null;
                      });
                      _triggerBarAnimation();
                    },
                  ),
                  const SizedBox(height: 6),

                  // 2. Interactive Tooltip Row (Hiển thị chi tiết mốc được chọn)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedBucketIndex != null
                            ? accent.primary.withValues(alpha: 0.4)
                            : (isDark
                                ? AppTokens.darkBorder
                                : AppTokens.lightBorder),
                      ),
                    ),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _selectedBucketIndex != null
                                      ? Icons.touch_app_rounded
                                      : Icons.analytics_outlined,
                                  size: 16,
                                  color: accent.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  infoTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppTokens.darkText
                                        : AppTokens.lightText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            CurrencyText(
                              infoAmount,
                              isVisible: widget.isVisible,
                              style: currencyTextStyle(
                                  context,
                                  TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? AppTokens.darkText
                                        : AppTokens.lightText,
                                  )),
                            ),
                          ],
                        )),
                  ),

                  const SizedBox(height: 6),

                  // 3. 100% Real-Data Interactive Bar Visualizer có Spring Scale Hardening
                  AnimatedBuilder(
                    animation: _barCurveAnimation,
                    builder: (context, child) {
                      return SizedBox(
                        height: 96 +
                            (MediaQuery.textScalerOf(context).scale(10) - 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(buckets.length, (index) {
                            final bucket = buckets[index];
                            final isSelected = _selectedBucketIndex == index;

                            // Tính tỷ lệ chiều cao cột cơ sở
                            final double targetRatio = maxAmount > 0
                                ? (bucket.amount / maxAmount).clamp(0.06, 1.0)
                                : 0.06;

                            // Chiều cao nhân với tiến trình nảy của Controller bảo toàn
                            final double currentHeight =
                                (64 * targetRatio * _barCurveAnimation.value)
                                    .clamp(4.0, 64.0);

                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _selectBar(index),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Indicator chấm phát sáng phía trên cột được chọn
                                    Opacity(
                                      opacity: isSelected ? 1.0 : 0.0,
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        margin:
                                            const EdgeInsets.only(bottom: 4),
                                        decoration: BoxDecoration(
                                          color: accent.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: accent.primary
                                                  .withValues(alpha: 0.8),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Cột Bar Chart nảy mượt mà
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      height:
                                          widget.isVisible ? currentHeight : 4,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isSelected
                                              ? [
                                                  accent.primary,
                                                  accent.primary
                                                      .withValues(alpha: 0.7)
                                                ]
                                              : (widget.isVisible &&
                                                      bucket.amount > 0
                                                  ? [
                                                      AppTokens.expense
                                                          .withValues(
                                                              alpha: 0.85),
                                                      AppTokens.expense
                                                          .withValues(
                                                              alpha: 0.4),
                                                    ]
                                                  : [
                                                      isDark
                                                          ? Colors.white10
                                                          : Colors.black12,
                                                      isDark
                                                          ? Colors.white10
                                                          : Colors.black12,
                                                    ]),
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white
                                              : (widget.isVisible &&
                                                      bucket.amount > 0
                                                  ? AppTokens.expense
                                                      .withValues(alpha: 0.3)
                                                  : Colors.transparent),
                                          width: isSelected ? 1.5 : 0.6,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: accent.primary
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Nhãn tên cột dưới chân
                                    Text(
                                      bucket.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSelected
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? accent.primary
                                            : (isDark
                                                ? AppTokens.darkMuted
                                                : AppTokens.lightMuted),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ));
      },
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, _) => const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Không thể tải biểu đồ. Vui lòng thử lại.',
            style: TextStyle(color: AppTokens.expense)),
      ),
    );
  }

  String _getPeriodLabel(ChartPeriod p) {
    switch (p) {
      case ChartPeriod.days7:
        return '7 ngày';
      case ChartPeriod.month:
        return 'Tháng này';
      case ChartPeriod.quarter:
        return 'Quý này';
      case ChartPeriod.year:
        return 'Năm nay';
    }
  }
}
