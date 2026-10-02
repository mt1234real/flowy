import '../services/fiscal_day.dart';
import '../widgets/ambient_canvas.dart';
// ==============================================================================
// File: lib/screens/budget_screen.dart
// Architecture: Isolated Monthly Budgets & Reactive Project/Event Budgets (Phase 1B)
// Stack: flutter_riverpod, drift, intl
// Features:
// 1. Đồng Bộ Hai Tầng Overscroll Reload với TwoStageOverscrollHeader & BouncingScrollPhysics.
// 2. Strict Monthly Isolation with Independent Budget Screen Anchor Month State:
//    - budgetAnchorMonthProvider: Decoupled from Ledger/Dashboard
//    - Month navigation (<, >) and period calculations strictly control budget state
// 3. Dedicated Empty State & One-Tap Budget Duplication from previous active month
//    (Responsive: FittedBox single-line label without broken words)
// 4. In-situ Edit & Delete for recurring budgets with dynamic milestone range preview
// 5. Accurate Anti-Double-Counting Engine: Recurring budget calculation completely excludes
//    any transaction linked with projectBudgetId or tagged with active event slugs (#tag)
// 6. Dual Top Tabs: [ 🔁 Định Kỳ Hàng Tháng ] vs [ 🎯 Sự Kiện / Dự Án ]
// 7. Preserved Period Navigation Motion: 80ms exit + 120ms text enter, 220ms data slide,
//    250px/s swipe threshold, vertical-scroll lock and 0.88x chevron press bounce.
// 8. Budget Setup Redesign: Unified Category Selector -> CategoryTreeModal,
//    68px Hero Amount, 44px Numpad keys, preserved Fluid Sheet behavior.
// 9. Project/Event Budgets Tab (Phase 1B):
//    - 3 Status Filter Chips: [ Đang diễn ra (N) ] | [ Sắp tới (N) ] | [ Đã kết thúc / Lưu trữ (N) ]
//    - Interactive Event Cards: Icon/Emoji squircle, title, status badge, 3-dots popup menu (Edit, Archive, Delete)
//    - Dynamic Progress Bar (Green <75%, Amber 75-90%, Rose >90% or overbudget)
//    - Custom _ProjectBudgetEditModal with auto-slug tag suggestion, emoji row, color palette, date range picker & 4x4 Numpad
// ==============================================================================

import 'dart:math' as math;
import 'dart:ui';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../widgets/sliding_segmented_bar.dart';
import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_text.dart';
import '../widgets/category_icon_badge.dart';
import '../widgets/category_tree_modal.dart';
import '../widgets/two_stage_overscroll_header.dart';
import 'ledger_screen.dart'
    show
    cycleStartDaysByMonthProvider,
    computeMonthCycleRange,
    resolveStartDayForMonth,
    MonthCycleRange;

/// StateProvider lưu trữ mốc tháng độc lập hoàn toàn cho màn hình Ngân Sách
final budgetAnchorMonthProvider = StateProvider<DateTime>((ref) {
  final now = ref.read(dayCutoffProvider).date(DateTime.now());
  return DateTime(now.year, now.month, 1);
});

// Enum 2 Top Tabs
enum BudgetTopTab { recurring, event }

final budgetTopTabProvider = StateProvider<BudgetTopTab>((ref) => BudgetTopTab.recurring);

// Filter Tab cho Sự Kiện: Active / Upcoming / Archived
enum ProjectStatusFilter { active, upcoming, archived }

final projectStatusFilterProvider = StateProvider<ProjectStatusFilter>((ref) => ProjectStatusFilter.active);

// StreamProvider lấy danh sách ngân sách định kỳ (Budgets) từ Drift SQLite
final activeBudgetsStreamProvider = StreamProvider.autoDispose<List<Budget>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.budgets).watch();
});

// StreamProvider lấy toàn bộ danh mục để tra cứu quan hệ Cha - Con (Không có isActive)
final allCategoriesStreamProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

// StreamProvider lấy danh sách giao dịch khoản chi
final expenseTransactionsStreamProvider =
    StreamProvider.autoDispose<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactions)
        ..where((t) =>
            t.type.equals(CategoryType.expense.index) &
            t.deletedAt.isNull() &
            t.goalId.isNull() &
            (t.envelopeType.equals('savings').not() | t.envelopeType.isNull())))
      .watch();
});

// StreamProvider theo dõi danh sách ProjectBudgets từ Drift
final projectBudgetsStreamProvider = StreamProvider.autoDispose<List<ProjectBudget>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchProjectBudgets();
});

// Helper model chứa dải ngày đã được tính toán động cho một bản ghi Budget
class ResolvedBudgetWindow {
  final DateTime startDate;
  final DateTime endDate;
  final String label;

  const ResolvedBudgetWindow({
    required this.startDate,
    required this.endDate,
    required this.label,
  });
}

// Helper phân giải dải ngày chu kỳ định kỳ dựa trên periodMonth và cycleStartDay
ResolvedBudgetWindow resolveBudgetWindow(Budget budget, Map<String, int> cycleStore) {
  final anchor = budget.periodMonth;
  final tempStore = Map<String, int>.from(cycleStore);
  final monthKey = DateFormat('yyyy-MM').format(anchor);
  tempStore[monthKey] = budget.cycleStartDay;

  final cycleRange = computeMonthCycleRange(anchor, tempStore);
  return ResolvedBudgetWindow(
    startDate: cycleRange.startDate,
    endDate: cycleRange.endDate,
    label: '${DateFormat('dd/MM').format(cycleRange.startDate)} – ${DateFormat('dd/MM').format(cycleRange.endDate)}',
  );
}

abstract final class BudgetPeriodMotion {
  static const Duration timeline = Duration(milliseconds: 220);
  static const Duration textExit = Duration(milliseconds: 80);
  static const Duration textEnter = Duration(milliseconds: 120);
  static const Duration dataEnter = Duration(milliseconds: 140);

  static const Duration chevronPress = Duration(milliseconds: 60);
  static const Duration chevronRelease = Duration(milliseconds: 90);

  static const double textTravel = 16.0;
  static const double dataTravel = 12.0;
  static const double swipeVelocityThreshold = 250.0;

  static const double swapFraction = 80.0 / 220.0;
  static const double textEndFraction = 200.0 / 220.0;
}

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _periodTimelineController;

  int _periodShiftDelta = 1;
  bool _isPeriodTransitioning = false;
  bool _periodContentSwapped = false;
  bool _isHorizontalPeriodDragActive = false;

  @override
  void initState() {
    super.initState();
    _periodTimelineController = AppAnimationPolicy.createController(
      vsync: this,
      duration: BudgetPeriodMotion.timeline,
      debugLabel: 'Budget.periodTimeline',
    );
  }

  @override
  void dispose() {
    _periodTimelineController.dispose();
    super.dispose();
  }

  double _clamp01(double value) => value.clamp(0.0, 1.0).toDouble();

  double get _periodDirection => _periodShiftDelta > 0 ? 1.0 : -1.0;

  double get _exitProgress {
    if (!_isPeriodTransitioning || _periodContentSwapped) return 0.0;
    final raw = _clamp01(
      _periodTimelineController.value / BudgetPeriodMotion.swapFraction,
    );
    return Curves.easeOutCubic.transform(raw);
  }

  double get _textEnterProgress {
    if (!_isPeriodTransitioning || !_periodContentSwapped) return 1.0;
    final denominator =
        BudgetPeriodMotion.textEndFraction - BudgetPeriodMotion.swapFraction;
    final raw = _clamp01(
      (_periodTimelineController.value - BudgetPeriodMotion.swapFraction) /
          denominator,
    );
    return Curves.easeOutCubic.transform(raw);
  }

  double get _textOpacity {
    if (!_isPeriodTransitioning) return 1.0;
    if (!_periodContentSwapped) {
      final raw = _clamp01(
        _periodTimelineController.value / BudgetPeriodMotion.swapFraction,
      );
      return 1.0 - Curves.easeInOut.transform(raw);
    }

    final denominator =
        BudgetPeriodMotion.textEndFraction - BudgetPeriodMotion.swapFraction;
    final raw = _clamp01(
      (_periodTimelineController.value - BudgetPeriodMotion.swapFraction) /
          denominator,
    );
    return Curves.easeInOut.transform(raw);
  }

  double get _dataEnterProgress {
    if (!_isPeriodTransitioning || !_periodContentSwapped) return 1.0;
    final raw = _clamp01(
      (_periodTimelineController.value - BudgetPeriodMotion.swapFraction) /
          (1.0 - BudgetPeriodMotion.swapFraction),
    );
    return Curves.easeOutCubic.transform(raw);
  }

  double get _progressRevealFactor {
    if (!_isPeriodTransitioning || !_periodContentSwapped) return 1.0;
    return _dataEnterProgress;
  }

  Future<void> _handleBudgetRefresh() async {
    HapticFeedback.lightImpact();
    ref.invalidate(activeBudgetsStreamProvider);
    ref.invalidate(allCategoriesStreamProvider);
    ref.invalidate(expenseTransactionsStreamProvider);
    ref.invalidate(projectBudgetsStreamProvider);
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _shiftMonthAnimated(
      int delta, {
        bool emitHaptic = true,
      }) async {
    if (_isPeriodTransitioning || delta == 0) return;

    if (emitHaptic) {
      HapticFeedback.selectionClick();
    }

    _periodShiftDelta = delta;
    _periodContentSwapped = false;
    _periodTimelineController.value = 0.0;

    if (mounted) {
      setState(() => _isPeriodTransitioning = true);
    }

    try {
      await _periodTimelineController.animateTo(
        BudgetPeriodMotion.swapFraction,
        duration: BudgetPeriodMotion.textExit,
        curve: Curves.linear,
      );
      if (!mounted) return;

      final cur = ref.read(budgetAnchorMonthProvider);
      ref.read(budgetAnchorMonthProvider.notifier).state =
          DateTime(cur.year, cur.month + delta, 1);

      setState(() => _periodContentSwapped = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      await _periodTimelineController.animateTo(
        1.0,
        duration: BudgetPeriodMotion.dataEnter,
        curve: Curves.linear,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPeriodTransitioning = false;
          _periodContentSwapped = false;
        });
        _periodTimelineController.value = 0.0;
      }
    }
  }

  void _onPeriodHorizontalDragStart(DragStartDetails details) {
    if (_isPeriodTransitioning || _isHorizontalPeriodDragActive) return;
    setState(() => _isHorizontalPeriodDragActive = true);
  }

  void _onPeriodHorizontalDragCancel() {
    if (!_isHorizontalPeriodDragActive) return;
    setState(() => _isHorizontalPeriodDragActive = false);
  }

  void _onPeriodHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;

    if (_isHorizontalPeriodDragActive) {
      setState(() => _isHorizontalPeriodDragActive = false);
    }

    if (_isPeriodTransitioning) return;

    if (velocity < -BudgetPeriodMotion.swipeVelocityThreshold) {
      _shiftMonthAnimated(1);
    } else if (velocity > BudgetPeriodMotion.swipeVelocityThreshold) {
      _shiftMonthAnimated(-1);
    }
  }

  Widget _buildPeriodLabelMotion({required Widget child}) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _periodTimelineController,
        child: child,
        builder: (context, child) {
          if (!_isPeriodTransitioning) return child!;

          final offsetX = !_periodContentSwapped
              ? -_periodDirection *
              BudgetPeriodMotion.textTravel *
              _exitProgress
              : _periodDirection *
              BudgetPeriodMotion.textTravel *
              (1.0 - _textEnterProgress);

          return Transform.translate(
            offset: Offset(offsetX, 0.0),
            child: Opacity(
              opacity: _textOpacity,
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodDataMotion({required Widget child}) {
    return AnimatedBuilder(
      animation: _periodTimelineController,
      child: child,
      builder: (context, child) {
        if (!_isPeriodTransitioning) return child!;

        final offsetX = !_periodContentSwapped
            ? -_periodDirection *
            BudgetPeriodMotion.dataTravel *
            _exitProgress
            : _periodDirection *
            BudgetPeriodMotion.dataTravel *
            (1.0 - _dataEnterProgress);

        return Transform.translate(
          offset: Offset(offsetX, 0.0),
          child: child,
        );
      },
    );
  }

  Widget _buildPeriodProgressFill({
    required double targetFactor,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _periodTimelineController,
      child: child,
      builder: (context, child) {
        final widthFactor =
        (targetFactor * _progressRevealFactor).clamp(0.0, 1.0).toDouble();
        return FractionallySizedBox(
          widthFactor: widthFactor,
          child: child,
        );
      },
    );
  }

  Widget _buildBudgetPeriodBar(
      BuildContext context, {
        required DateTime anchorMonth,
        required MonthCycleRange cycleRange,
        required bool isDark,
        required AppAccentPreset accent,
      }) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onPeriodHorizontalDragStart,
      onHorizontalDragEnd: _onPeriodHorizontalDragEnd,
      onHorizontalDragCancel: _onPeriodHorizontalDragCancel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTokens.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
          ),
        ),
        child: Row(
          children: [
            _BudgetChevronButton(
              icon: Icons.chevron_left_rounded,
              onPressed: _isPeriodTransitioning
                  ? null
                  : () => _shiftMonthAnimated(-1, emitHaptic: false),
            ),
            Expanded(
              child: InkWell(
                onTap: _isPeriodTransitioning
                    ? null
                    : () => _openEditMilestoneModal(
                  context,
                  ref,
                  anchorMonth,
                  isDark,
                  accent,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: _buildPeriodLabelMotion(
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Chu kỳ Tháng ${DateFormat('MM/yyyy').format(anchorMonth)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppTokens.darkText
                                      : AppTokens.lightText,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit_calendar_rounded,
                              size: 14,
                              color: accent.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(cycleRange.startDate)} – '
                              '${DateFormat('dd/MM/yyyy').format(cycleRange.endDate)} '
                              '(${cycleRange.daysCount} ngày)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTokens.darkMuted
                                : AppTokens.lightMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _BudgetChevronButton(
              icon: Icons.chevron_right_rounded,
              onPressed: _isPeriodTransitioning
                  ? null
                  : () => _shiftMonthAnimated(1, emitHaptic: false),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount);
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF0EA5E9);
    }
  }

  void _openBudgetSetupSheet(BuildContext context, {Budget? editBudget}) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => _BudgetSetupSheet(editBudget: editBudget),
    );
  }

  void _openProjectBudgetModal(BuildContext context, {ProjectBudget? editProject}) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => _ProjectBudgetEditModal(editProject: editProject),
    );
  }

  Future<void> _copyBudgetFromPreviousMonth(
      BuildContext context,
      WidgetRef ref,
      DateTime currentMonth,
      List<Budget> allBudgets,
      Map<String, int> cycleStore,
      ) async {
    HapticFeedback.mediumImpact();
    final db = ref.read(databaseProvider);
    final curStartDay = resolveStartDayForMonth(currentMonth, cycleStore);
    final curMonthNormalized = DateTime(currentMonth.year, currentMonth.month, 1);
    final curMonthKey = DateFormat('yyyy-MM').format(currentMonth);

    List<Budget> sourceBudgets = [];
    String sourceMonthLabel = '';

    for (int i = 1; i <= 12; i++) {
      final prevDate = DateTime(currentMonth.year, currentMonth.month - i, 1);
      final found = allBudgets.where((b) {
        if (b.id.startsWith('event_')) return false;
        return b.periodMonth.year == prevDate.year && b.periodMonth.month == prevDate.month;
      }).toList();

      if (found.isNotEmpty) {
        sourceBudgets = found;
        sourceMonthLabel = DateFormat('MM/yyyy').format(prevDate);
        break;
      }
    }

    if (sourceBudgets.isEmpty) {
      AppFeedback.showInfo(
        context,
        'Chưa tìm thấy ngân sách của các tháng trước để sao chép!',
        emitHaptic: false,
      );
      return;
    }

    await db.transaction(() async {
      for (final src in sourceBudgets) {
        final newId = 'b_${curMonthKey}_${src.categoryId}';
        await db.into(db.budgets).insertOnConflictUpdate(
          BudgetsCompanion(
            id: drift.Value(newId),
            categoryId: drift.Value(src.categoryId),
            amount: drift.Value(src.amount),
            cycleStartDay: drift.Value(curStartDay),
            periodMonth: drift.Value(curMonthNormalized),
          ),
        );
      }
    });

    if (context.mounted) {
      AppFeedback.showSuccess(
        context,
        'Đã sao chép ${sourceBudgets.length} danh mục từ Tháng $sourceMonthLabel.',
        emitHaptic: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boundary = ref.watch(dayCutoffProvider);
    final accent = ref.watch(accentPresetProvider);

    final currentTopTab = ref.watch(budgetTopTabProvider);
    final anchorMonth = ref.watch(budgetAnchorMonthProvider);
    final cycleStore = ref.watch(cycleStartDaysByMonthProvider);
    final cycleRange = computeMonthCycleRange(anchorMonth, cycleStore);

    final budgetsAsync = ref.watch(activeBudgetsStreamProvider);
    final categoriesAsync = ref.watch(allCategoriesStreamProvider);
    final expensesAsync = ref.watch(expenseTransactionsStreamProvider);
    final projectBudgetsAsync = ref.watch(projectBudgetsStreamProvider);

    return AppFeedbackDismissRegion(
      child: AmbientCanvas(child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: TwoStageOverscrollHeader(
            onRefresh: _handleBudgetRefresh,
            glowColor: accent.primary,
            child: CustomScrollView(
              physics: _isHorizontalPeriodDragActive
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // 1. TOP HEADER & 2 TOP TABS
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.pie_chart_outline_rounded, size: 14, color: accent.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      'PHÂN BỔ HẠN MỨC',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: accent.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Kế Hoạch Tài Chính',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (currentTopTab == BudgetTopTab.recurring) {
                                  _openBudgetSetupSheet(context);
                                } else {
                                  _openProjectBudgetModal(context);
                                }
                              },
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text(
                                currentTopTab == BudgetTopTab.recurring ? 'Đặt hạn mức' : 'Tạo sự kiện',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent.primary,
                                foregroundColor: Colors.white,
                                elevation: 1,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        SlidingSegmentedBar<BudgetTopTab>(
                          selectedValue: currentTopTab,
                          items: [
                            SlidingSegmentedItem<BudgetTopTab>(
                              value: BudgetTopTab.recurring,
                              label: 'Định Kỳ Hàng Tháng',
                              icon: Icons.autorenew_rounded,
                              activeColor: accent.primary,
                              activeBackgroundColor:
                              accent.primary.withValues(alpha: 0.14),
                            ),
                            SlidingSegmentedItem<BudgetTopTab>(
                              value: BudgetTopTab.event,
                              label: 'Sự Kiện / Dự Án',
                              icon: Icons.flag_rounded,
                              activeColor: accent.primary,
                              activeBackgroundColor:
                              accent.primary.withValues(alpha: 0.14),
                            ),
                          ],
                          onValueChanged: (tab) {
                            ref.read(budgetTopTabProvider.notifier).state = tab;
                          },
                        )
                      ],
                    ),
                  ),
                ),

                // ===============================================================
                // TAB 1: NGÂN SÁCH ĐỊNH KỲ (MONTHLY RECURRING)
                // ===============================================================
                if (currentTopTab == BudgetTopTab.recurring) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    sliver: SliverToBoxAdapter(
                      child: _buildBudgetPeriodBar(
                        context,
                        anchorMonth: anchorMonth,
                        cycleRange: cycleRange,
                        isDark: isDark,
                        accent: accent,
                      ),
                    ),
                  ),

                  budgetsAsync.when(
                    data: (budgets) {
                      final allCategories = categoriesAsync.valueOrNull ?? <Category>[];
                      final allExpenses = expensesAsync.valueOrNull ?? <Transaction>[];
                      final allProjects = projectBudgetsAsync.valueOrNull ?? <ProjectBudget>[];
                      final catMap = {for (final c in allCategories) c.id: c};

                      final activeProjectTags = allProjects
                          .where((p) => p.status != 'ARCHIVED')
                          .map((p) => p.tag.toLowerCase().trim())
                          .toSet();

                      final recurringBudgetsForThisMonth = budgets.where((b) {
                        if (b.id.startsWith('event_')) return false;
                        return b.periodMonth.year == anchorMonth.year && b.periodMonth.month == anchorMonth.month;
                      }).toList();

                      final totalBudgetAmount = recurringBudgetsForThisMonth.fold(0.0, (sum, b) => sum + b.amount);

                      double totalSpent = 0.0;
                      for (final b in recurringBudgetsForThisMonth) {
                        final targetCat = catMap[b.categoryId];
                        final isParent = targetCat != null && (targetCat.parentId == null || targetCat.parentId!.isEmpty);

                        final spentForThis = allExpenses.where((t) {
                          if (t.projectBudgetId != null && t.projectBudgetId!.isNotEmpty) return false;
                          final noteLower = t.note?.toLowerCase() ?? '';
                          final merchantLower = t.merchant?.toLowerCase() ?? '';
                          final isEventTx = activeProjectTags.any((tag) => noteLower.contains(tag) || merchantLower.contains(tag));
                          if (isEventTx) return false;

                          if (t.date.isBefore(boundary.start(cycleRange.startDate)) || !t.date.isBefore(boundary.end(cycleRange.endDate))) return false;
                          if (isParent) {
                            if (t.categoryId == b.categoryId) return true;
                            final sub = catMap[t.categoryId];
                            return sub != null && sub.parentId == b.categoryId;
                          } else {
                            return t.categoryId == b.categoryId;
                          }
                        }).fold(0.0, (s, t) => s + t.amount);

                        totalSpent += spentForThis;
                      }

                      final remaining = math.max(0.0, totalBudgetAmount - totalSpent);
                      final spendPct = totalBudgetAmount > 0 ? (totalSpent / totalBudgetAmount).clamp(0.0, 1.0) : 0.0;

                      if (recurringBudgetsForThisMonth.isEmpty) {
                        return const SliverToBoxAdapter(child: SizedBox(height: 6));
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        sliver: SliverToBoxAdapter(
                          child: _buildPeriodDataMotion(
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                      : [accent.primary, accent.primary.withValues(alpha: 0.85)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.primary.withValues(alpha: 0.25),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
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
                                        'TỔNG NGÂN SÁCH THÁNG ${DateFormat('MM/yyyy').format(anchorMonth)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                          color: isDark ? AppTokens.darkMuted : Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        '${recurringBudgetsForThisMonth.length} danh mục phân bổ',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatCurrency(totalBudgetAmount),
                                    style: currencyTextStyle(context, const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    )),
                                  ),
                                  const SizedBox(height: 12),
                                  Stack(
                                    children: [
                                      Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      _buildPeriodProgressFill(
                                        targetFactor: spendPct.toDouble(),
                                        child: Container(
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: spendPct > 0.9
                                                ? const Color(0xFFF87171)
                                                : const Color(0xFF34D399),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      CurrencyText(
                                        'Đã chi: ${_formatCurrency(totalSpent)} (${(spendPct * 100).toStringAsFixed(0)}%)',
                                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                                      ),
                                      CurrencyText(
                                        'Còn lại: ${_formatCurrency(remaining)}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    error: (err, _) => SliverToBoxAdapter(child: Text('Lỗi: $err')),
                  ),

                  budgetsAsync.when(
                    data: (budgets) {
                      final allCategories = categoriesAsync.valueOrNull ?? <Category>[];
                      final allExpenses = expensesAsync.valueOrNull ?? <Transaction>[];
                      final allProjects = projectBudgetsAsync.valueOrNull ?? <ProjectBudget>[];
                      final catMap = {for (final c in allCategories) c.id: c};

                      final activeProjectTags = allProjects
                          .where((p) => p.status != 'ARCHIVED')
                          .map((p) => p.tag.toLowerCase().trim())
                          .toSet();

                      final recurringBudgetsForThisMonth = budgets.where((b) {
                        if (b.id.startsWith('event_')) return false;
                        return b.periodMonth.year == anchorMonth.year && b.periodMonth.month == anchorMonth.month;
                      }).toList();

                      if (recurringBudgetsForThisMonth.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                            child: _buildPeriodDataMotion(
                              child: Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTokens.darkCard : Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: accent.primary.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.edit_note_rounded, size: 36, color: accent.primary),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Chưa có kế hoạch ngân sách cho Chu kỳ Tháng ${DateFormat('MM/yyyy').format(anchorMonth)}',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Ngân sách mỗi tháng hoàn toàn độc lập. Bạn có thể sao chép nhanh danh mục từ tháng trước hoặc tự thiết lập mới.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 46,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _copyBudgetFromPreviousMonth(
                                          context,
                                          ref,
                                          anchorMonth,
                                          budgets,
                                          cycleStore,
                                        ),
                                        icon: const Icon(Icons.content_copy_rounded, size: 17),
                                        label: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Sao chép từ tháng trước',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accent.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 44,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _openBudgetSetupSheet(context),
                                        icon: const Icon(Icons.add_rounded, size: 16),
                                        label: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Thiết lập ngân sách mới',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: accent.primary,
                                          side: BorderSide(color: accent.primary.withValues(alpha: 0.5)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final budget = recurringBudgetsForThisMonth[index];
                              final targetCategory = catMap[budget.categoryId];
                              final isChild = targetCategory != null &&
                                  targetCategory.parentId != null &&
                                  targetCategory.parentId!.isNotEmpty;

                              Category? parentCategory;
                              if (isChild && targetCategory.parentId != null) {
                                parentCategory = catMap[targetCategory.parentId!];
                              }

                              final spent = allExpenses.where((t) {
                                if (t.projectBudgetId != null && t.projectBudgetId!.isNotEmpty) return false;
                                final noteLower = t.note?.toLowerCase() ?? '';
                                final merchantLower = t.merchant?.toLowerCase() ?? '';
                                final isEventTx = activeProjectTags.any((tag) => noteLower.contains(tag) || merchantLower.contains(tag));
                                if (isEventTx) return false;

                                if (t.date.isBefore(boundary.start(cycleRange.startDate)) || !t.date.isBefore(boundary.end(cycleRange.endDate))) return false;
                                if (isChild) {
                                  return t.categoryId == budget.categoryId;
                                } else {
                                  if (t.categoryId == budget.categoryId) return true;
                                  final sub = catMap[t.categoryId];
                                  return sub != null && sub.parentId == budget.categoryId;
                                }
                              }).fold(0.0, (sum, t) => sum + t.amount);

                              final remaining = budget.amount - spent;
                              final isOver = remaining < 0;
                              final ratio = budget.amount > 0 ? (spent / budget.amount).clamp(0.0, 1.0) : 0.0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildPeriodDataMotion(
                                  child: InkWell(
                                    onTap: () => _openBudgetSetupSheet(context, editBudget: budget),
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTokens.darkCard : Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: isOver
                                              ? AppTokens.expense.withValues(alpha: 0.4)
                                              : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CategoryIconBadge(
                                                category: targetCategory,
                                                isExpense: true,
                                                size: 40,
                                                iconSize: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            targetCategory?.name ?? 'Danh mục',
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w800,
                                                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                          decoration: BoxDecoration(
                                                            color: isChild
                                                                ? Colors.indigo.withValues(alpha: 0.15)
                                                                : accent.primary.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            isChild ? 'Mục con' : 'Nhóm cha',
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.bold,
                                                              color: isChild ? Colors.indigoAccent : accent.primary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      isChild && parentCategory != null
                                                          ? 'Thuộc: ${parentCategory.name} • Riêng Tháng ${DateFormat('MM/yyyy').format(anchorMonth)}'
                                                          : 'Riêng Tháng ${DateFormat('MM/yyyy').format(anchorMonth)} • Kế thừa ngày ${budget.cycleStartDay}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 18),
                                                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                                onPressed: () => _openBudgetSetupSheet(context, editBudget: budget),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              CurrencyText(
                                                '${_formatCurrency(spent)} / ${_formatCurrency(budget.amount)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                                ),
                                              ),
                                              CurrencyText(
                                                isOver
                                                    ? 'Vượt ${_formatCurrency(remaining.abs())}'
                                                    : 'Còn ${_formatCurrency(remaining)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: isOver ? AppTokens.expense : const Color(0xFF10B981),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Stack(
                                            children: [
                                              Container(
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: isDark ? Colors.white10 : Colors.black12,
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                              ),
                                              _buildPeriodProgressFill(
                                                targetFactor: ratio.toDouble(),
                                                child: Container(
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: isOver
                                                        ? AppTokens.expense
                                                        : (ratio > 0.8
                                                        ? AppTokens.warning
                                                        : const Color(0xFF10B981)),
                                                    borderRadius: BorderRadius.circular(3),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: recurringBudgetsForThisMonth.length,
                          ),
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                    error: (err, _) => SliverToBoxAdapter(child: Text('Lỗi: $err')),
                  ),
                ],

                // ===============================================================
                // TAB 2: NGÂN SÁCH SỰ KIỆN / DỰ ÁN
                // ===============================================================
                if (currentTopTab == BudgetTopTab.event) ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    sliver: SliverToBoxAdapter(
                      child: projectBudgetsAsync.maybeWhen(
                        data: (allProjects) {
                          final now = DateTime.now();
                          final activeCount = allProjects.where((p) {
                            if (p.status == 'ARCHIVED') return false;
                            return !now.isBefore(p.startDate) && !now.isAfter(p.endDate);
                          }).length;

                          final upcomingCount = allProjects.where((p) {
                            if (p.status == 'ARCHIVED') return false;
                            return now.isBefore(p.startDate);
                          }).length;

                          final archivedCount = allProjects.where((p) {
                            return p.status == 'ARCHIVED' || now.isAfter(p.endDate);
                          }).length;

                          final currentFilter = ref.watch(projectStatusFilterProvider);

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: SizedBox(
                                width: 560,
                                child: SlidingSegmentedBar<ProjectStatusFilter>(
                                  selectedValue: currentFilter,
                                  items: [
                                    SlidingSegmentedItem<ProjectStatusFilter>(
                                      value: ProjectStatusFilter.active,
                                      label: 'Đang diễn ra ($activeCount)',
                                      activeColor: accent.primary,
                                      activeBackgroundColor: accent.primary,
                                    ),
                                    SlidingSegmentedItem<ProjectStatusFilter>(
                                      value: ProjectStatusFilter.upcoming,
                                      label: 'Sắp tới ($upcomingCount)',
                                      activeColor: accent.primary,
                                      activeBackgroundColor: accent.primary,
                                    ),
                                    SlidingSegmentedItem<ProjectStatusFilter>(
                                      value: ProjectStatusFilter.archived,
                                      label: 'Đã kết thúc / Lưu trữ ($archivedCount)',
                                      activeColor: accent.primary,
                                      activeBackgroundColor: accent.primary,
                                    ),
                                  ],
                                  onValueChanged: (filter) {
                                    ref.read(projectStatusFilterProvider.notifier).state = filter;
                                  },
                                )
                            ),
                          );
                        },
                        orElse: () => const SizedBox(),
                      ),
                    ),
                  ),

                  projectBudgetsAsync.when(
                    data: (allProjects) {
                      final allExpenses = expensesAsync.valueOrNull ?? <Transaction>[];
                      final currentFilter = ref.watch(projectStatusFilterProvider);
                      final now = DateTime.now();

                      final filteredProjects = allProjects.where((p) {
                        final isPast = now.isAfter(p.endDate);
                        final isFuture = now.isBefore(p.startDate);
                        final isArchived = p.status == 'ARCHIVED' || isPast;

                        if (currentFilter == ProjectStatusFilter.active) {
                          return p.status != 'ARCHIVED' && !isFuture && !isPast;
                        } else if (currentFilter == ProjectStatusFilter.upcoming) {
                          return p.status != 'ARCHIVED' && isFuture;
                        } else if (currentFilter == ProjectStatusFilter.archived) {
                          return isArchived;
                        }
                        return true;
                      }).toList();

                      if (filteredProjects.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                            child: Center(
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: accent.primary.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.flight_takeoff_rounded, size: 40, color: accent.primary),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    'Chưa có sự kiện nào trong mục này',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tạo một chuyến du lịch, dự án sắm Tết hoặc mục tiêu mua sắm lớn ngay!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton.icon(
                                    onPressed: () => _openProjectBudgetModal(context),
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('+ Tạo Ngân Sách Sự Kiện Mới'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accent.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final p = filteredProjects[index];
                              final color = _parseColor(p.colorHex);

                              final isPast = now.isAfter(p.endDate);
                              final isFuture = now.isBefore(p.startDate);
                              final isArchived = p.status == 'ARCHIVED' || isPast;

                              String statusText = 'Đang diễn ra';
                              Color statusColor = const Color(0xFF10B981);
                              if (isFuture && p.status != 'ARCHIVED') {
                                statusText = 'Sắp tới';
                                statusColor = const Color(0xFFF59E0B);
                              } else if (isArchived) {
                                statusText = 'Đã kết thúc';
                                statusColor = isDark ? AppTokens.darkMuted : Colors.grey;
                              }

                              int daysCount = 0;
                              if (isFuture) {
                                daysCount = p.startDate.difference(now).inDays;
                              } else if (!isPast) {
                                daysCount = p.endDate.difference(now).inDays;
                              }

                              final tagLower = p.tag.toLowerCase().trim();
                              final spent = allExpenses.where((t) {
                                if (t.projectBudgetId == p.id) return true;
                                final noteLower = t.note?.toLowerCase() ?? '';
                                final merchantLower = t.merchant?.toLowerCase() ?? '';
                                return noteLower.contains(tagLower) || merchantLower.contains(tagLower);
                              }).fold(0.0, (sum, t) => sum + t.amount);

                              final remaining = p.targetAmount - spent;
                              final isOver = remaining < 0;
                              final ratio = p.targetAmount > 0 ? (spent / p.targetAmount).clamp(0.0, 1.0) : 0.0;

                              Color progressColor = const Color(0xFF10B981);
                              if (isOver || ratio > 0.90) {
                                progressColor = const Color(0xFFF43F5E);
                              } else if (ratio >= 0.75) {
                                progressColor = const Color(0xFFF59E0B);
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      AppFeedback.showInfo(
                                        context,
                                        'Sự kiện: ${p.title} (${p.tag})',
                                        emitHaptic: false,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTokens.darkCard : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isOver
                                              ? AppTokens.expense.withValues(alpha: 0.4)
                                              : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.16),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: color.withValues(alpha: 0.4)),
                                                ),
                                                child: Center(
                                                  child: Text(p.icon, style: const TextStyle(fontSize: 22)),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            p.title,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.w800,
                                                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: statusColor.withValues(alpha: 0.15),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Text(
                                                            statusText,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold,
                                                              color: statusColor,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Gắn tag ${p.tag} hoặc chọn dự án khi chi',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: color,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                icon: Icon(
                                                  Icons.more_vert_rounded,
                                                  size: 20,
                                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                                ),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                onSelected: (val) async {
                                                  HapticFeedback.selectionClick();
                                                  final db = ref.read(databaseProvider);
                                                  if (val == 'edit') {
                                                    _openProjectBudgetModal(context, editProject: p);
                                                  } else if (val == 'archive') {
                                                    await db.archiveProjectBudget(p.id);
                                                    if (!context.mounted) return;
                                                    AppFeedback.showSuccess(
                                                      context,
                                                      'Đã đóng / chốt sổ sự kiện "${p.title}".',
                                                    );
                                                  } else if (val == 'delete') {
                                                    final confirm = await showDialog<bool>(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: const Text('Xác nhận xóa sự kiện'),
                                                        content: Text('Xóa sự kiện "${p.title}"? Các giao dịch chi tiêu liên quan sẽ được giữ lại nguyên vẹn.'),
                                                        actions: [
                                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY')),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(backgroundColor: AppTokens.expense, foregroundColor: Colors.white),
                                                            onPressed: () => Navigator.pop(ctx, true),
                                                            child: const Text('XÓA'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm == true) {
                                                      await db.deleteProjectBudget(p.id);
                                                    }
                                                  }
                                                },
                                                itemBuilder: (_) => [
                                                  const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.edit_outlined, size: 18),
                                                        SizedBox(width: 8),
                                                        Text('✏️ Chỉnh sửa thông tin'),
                                                      ],
                                                    ),
                                                  ),
                                                  if (!isArchived)
                                                    const PopupMenuItem(
                                                      value: 'archive',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.archive_outlined, size: 18),
                                                          SizedBox(width: 8),
                                                          Text('📥 Đóng / Chốt sổ'),
                                                        ],
                                                      ),
                                                    ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.delete_outline, size: 18, color: AppTokens.expense),
                                                        SizedBox(width: 8),
                                                        Text('🗑️ Xóa sự kiện', style: TextStyle(color: AppTokens.expense)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),

                                          Row(
                                            children: [
                                              Icon(Icons.calendar_month_outlined, size: 14, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                                              const SizedBox(width: 6),
                                              Text(
                                                '📅 ${DateFormat('dd/MM/yyyy').format(p.startDate)} → ${DateFormat('dd/MM/yyyy').format(p.endDate)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              if (!isArchived && !isPast)
                                                Text(
                                                  isFuture ? '(Bắt đầu sau $daysCount ngày)' : '(Còn $daysCount ngày)',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: color,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              CurrencyText(
                                                '${_formatCurrency(spent)} / ${_formatCurrency(p.targetAmount)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                                ),
                                              ),
                                              CurrencyText(
                                                isOver
                                                    ? 'Vượt ${_formatCurrency(remaining.abs())}'
                                                    : 'Còn ${_formatCurrency(remaining)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: isOver ? AppTokens.expense : const Color(0xFF10B981),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Stack(
                                            children: [
                                              Container(
                                                height: 7,
                                                decoration: BoxDecoration(
                                                  color: isDark ? Colors.white10 : Colors.black12,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                              FractionallySizedBox(
                                                widthFactor: ratio,
                                                child: Container(
                                                  height: 7,
                                                  decoration: BoxDecoration(
                                                    color: progressColor,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: filteredProjects.length,
                          ),
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                    error: (err, _) => SliverToBoxAdapter(child: Text('Lỗi: $err')),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          ),
        ),
      )),
    );
  }

  void _openEditMilestoneModal(
      BuildContext context,
      WidgetRef ref,
      DateTime anchorMonth,
      bool isDark,
      AppAccentPreset accent,
      ) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => _MonthlyMilestonePickerModal(
        anchorMonth: anchorMonth,
        isDark: isDark,
        accent: accent,
      ),
    );
  }
}

class _BudgetChevronButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _BudgetChevronButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  State<_BudgetChevronButton> createState() => _BudgetChevronButtonState();
}

class _BudgetChevronButtonState extends State<_BudgetChevronButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _pressController = AppAnimationPolicy.createController(
      vsync: this,
      duration: BudgetPeriodMotion.chevronPress,
      reverseDuration: BudgetPeriodMotion.chevronRelease,
      debugLabel: 'Budget.chevronPress',
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    HapticFeedback.selectionClick();
    _pressController.animateTo(
      1.0,
      duration: BudgetPeriodMotion.chevronPress,
      curve: Curves.easeOutCubic,
    );
  }

  void _release() {
    if (widget.onPressed == null) return;
    _pressController.animateBack(
      0.0,
      duration: BudgetPeriodMotion.chevronRelease,
      curve: Curves.easeOutBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final muted = Theme.of(context).disabledColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onTapDown: enabled ? _handleTapDown : null,
        onTapUp: enabled ? (_) => _release() : null,
        onTapCancel: enabled ? _release : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedBuilder(
              animation: _pressController,
              builder: (context, child) {
                final scale = 1.0 - (0.12 * _pressController.value);
                return Transform.scale(scale: scale, child: child);
              },
              child: Icon(
                widget.icon,
                size: 24,
                color: enabled ? null : muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 🌟 MODAL: CHỌN MỐC NGÀY CHU KỲ THEO THÁNG (CHAINED MILESTONES)
// ==============================================================================

class _MonthlyMilestonePickerModal extends ConsumerStatefulWidget {
  final DateTime anchorMonth;
  final bool isDark;
  final AppAccentPreset accent;

  const _MonthlyMilestonePickerModal({
    required this.anchorMonth,
    required this.isDark,
    required this.accent,
  });

  @override
  ConsumerState<_MonthlyMilestonePickerModal> createState() => _MonthlyMilestonePickerModalState();
}

class _MonthlyMilestonePickerModalState extends ConsumerState<_MonthlyMilestonePickerModal> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    final store = ref.read(cycleStartDaysByMonthProvider);
    _selectedDay = resolveStartDayForMonth(widget.anchorMonth, store);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(cycleStartDaysByMonthProvider);
    final monthKey = DateFormat('yyyy-MM').format(widget.anchorMonth);
    final tempStore = Map<String, int>.from(store)..[monthKey] = _selectedDay;
    final previewRange = computeMonthCycleRange(widget.anchorMonth, tempStore);
    final daysInCurMonth = DateTime(widget.anchorMonth.year, widget.anchorMonth.month + 1, 0).day;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF151C28).withValues(alpha: 0.96)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: widget.isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
          ),
          child: SafeArea(
            top: false,
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
                Text(
                  'Mốc Chu Kỳ Tháng ${DateFormat('MM/yyyy').format(widget.anchorMonth)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? AppTokens.darkText : AppTokens.lightText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Chọn ngày nhận lương. Các tháng tiếp theo sẽ tự động kế thừa mốc này.',
                  style: TextStyle(fontSize: 11, color: widget.isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [1, 5, 10, 15, 20, 25].map((day) {
                      final isSelected = _selectedDay == day;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedDay = day);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? widget.accent.primary : (widget.isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? widget.accent.primary : (widget.isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                              ),
                            ),
                            child: Text(
                              'Ngày ${day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : (widget.isDark ? AppTokens.darkText : AppTokens.lightText),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.accent.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: widget.accent.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, color: widget.accent.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chu kỳ dự kiến áp dụng:',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.accent.primary),
                            ),
                            Text(
                              previewRange.subRange,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: widget.isDark ? AppTokens.darkText : AppTokens.lightText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: widget.accent.primary,
                    thumbColor: widget.accent.primary,
                    overlayColor: widget.accent.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _selectedDay.toDouble().clamp(1.0, daysInCurMonth.toDouble()),
                    min: 1.0,
                    max: daysInCurMonth.toDouble(),
                    divisions: daysInCurMonth - 1,
                    label: 'Ngày $_selectedDay',
                    onChanged: (val) => setState(() => _selectedDay = val.round()),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accent.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(cycleStartDaysByMonthProvider.notifier).update((state) {
                        return Map<String, int>.from(state)..[monthKey] = _selectedDay;
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text('✓ LƯU MỐC CHU KỲ NÀY', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 🌟 MODAL: TẠO MỚI / CHỈNH SỬA NGÂN SÁCH SỰ KIỆN (_ProjectBudgetEditModal)
// ==============================================================================

class _ProjectBudgetEditModal extends ConsumerStatefulWidget {
  final ProjectBudget? editProject;

  const _ProjectBudgetEditModal({this.editProject});

  @override
  ConsumerState<_ProjectBudgetEditModal> createState() => _ProjectBudgetEditModalState();
}

class _ProjectBudgetEditModalState extends ConsumerState<_ProjectBudgetEditModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _tagController;

  late DateTime _startDate;
  late DateTime _endDate;
  late String _amountBuffer;
  late String _selectedEmoji;
  late String _selectedColorHex;
  bool _isSaving = false;

  final AppValidationFeedbackController _titleFeedback =
  AppValidationFeedbackController();
  final AppValidationFeedbackController _amountFeedback =
  AppValidationFeedbackController();

  final List<String> _presetEmojis = ['🌴', '✈️', '💻', '🧧', '🏠', '💍', '🚗', '🛍️', '🎓', '🎉'];
  final List<String> _presetColors = ['#0EA5E9', '#10B981', '#F59E0B', '#F43F5E', '#8B5CF6', '#3B82F6', '#64748B'];

  @override
  void initState() {
    super.initState();
    final p = widget.editProject;
    _titleController = TextEditingController(text: p?.title ?? '');
    _tagController = TextEditingController(text: p?.tag ?? '');

    _startDate = p?.startDate ?? DateTime.now();
    _endDate = p?.endDate ?? DateTime.now().add(const Duration(days: 7));
    _amountBuffer = p != null ? p.targetAmount.toInt().toString() : '5000000';
    _selectedEmoji = p?.icon ?? '🌴';
    _selectedColorHex = p?.colorHex ?? '#0EA5E9';

    _titleController.addListener(() {
      final title = _titleController.text.trim();
      if (title.isNotEmpty) {
        _titleFeedback.clear();
      }

      if (widget.editProject == null && mounted) {
        if (title.isNotEmpty) {
          final slug = title
              .toLowerCase()
              .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
              .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
              .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
              .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
              .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
              .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
              .replaceAll(RegExp(r'đ'), 'd')
              .replaceAll(RegExp(r'[^a-z0-9]'), '');
          _tagController.text = '#$slug';
        }
      }
    });
  }

  @override
  void dispose() {
    _titleFeedback.dispose();
    _amountFeedback.dispose();
    _titleController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount);
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF0EA5E9);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _onKeyPress(String val) {
    HapticFeedback.selectionClick();
    setState(() {
      if (val == 'C') {
        _amountBuffer = '0';
      } else if (val == 'BACK') {
        if (_amountBuffer.length > 1) {
          _amountBuffer = _amountBuffer.substring(0, _amountBuffer.length - 1);
        } else {
          _amountBuffer = '0';
        }
      } else if (val == '000') {
        if (_amountBuffer != '0' && _amountBuffer.length <= 9) {
          _amountBuffer += '000';
        }
      } else {
        if (_amountBuffer == '0') {
          _amountBuffer = val;
        } else if (_amountBuffer.length <= 11) {
          _amountBuffer += val;
        }
      }
    });

    if ((double.tryParse(_amountBuffer) ?? 0.0) > 0) {
      _amountFeedback.clear();
    }
  }

  Future<void> _saveProjectBudget() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountBuffer) ?? 0.0;

    final titleInvalid = title.isEmpty;
    final amountInvalid = amount <= 0;

    if (titleInvalid || amountInvalid) {
      HapticFeedback.heavyImpact();
      if (titleInvalid) {
        _titleFeedback.reject(emitHaptic: false);
      }
      if (amountInvalid) {
        _amountFeedback.reject(emitHaptic: false);
      }
      return;
    }

    var tag = _tagController.text.trim();
    if (!tag.startsWith('#')) tag = '#$tag';

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);

    try {
      final isEdit = widget.editProject != null;
      if (isEdit) {
        await db.updateProjectBudget(
          id: widget.editProject!.id,
          title: title,
          tag: tag,
          icon: _selectedEmoji,
          colorHex: _selectedColorHex,
          targetAmount: amount,
          startDate: _startDate,
          endDate: _endDate,
        );
      } else {
        final newId = 'project_${DateTime.now().millisecondsSinceEpoch}';
        await db.createProjectBudget(
          id: newId,
          title: title,
          tag: tag,
          icon: _selectedEmoji,
          colorHex: _selectedColorHex,
          targetAmount: amount,
          startDate: _startDate,
          endDate: _endDate,
          status: 'ACTIVE',
        );
      }

      HapticFeedback.mediumImpact();
      if (!mounted) return;

      AppFeedback.showSuccess(
        context,
        isEdit
            ? 'Đã cập nhật sự kiện "$title".'
            : 'Đã tạo ngân sách sự kiện "$title" ($tag).',
        emitHaptic: false,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(
        context,
        'Lỗi lưu sự kiện: $e',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _parseColor(_selectedColorHex);
    final displayAmount = double.tryParse(_amountBuffer) ?? 0.0;
    final isEdit = widget.editProject != null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151C28).withValues(alpha: 0.98) : Colors.white.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Chỉnh Sửa Ngân Sách Sự Kiện' : 'Tạo Ngân Sách Sự Kiện / Dự Án',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  AppValidationFeedback(
                    controller: _titleFeedback,
                    builder: (context, visual) {
                      final restingBorder = isDark
                          ? AppTokens.darkBorder
                          : AppTokens.lightBorder;

                      return TextField(
                        controller: _titleController,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppTokens.darkText
                              : AppTokens.lightText,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Tên sự kiện / Dự án *',
                          hintText: 'Ví dụ: Du lịch Đà Lạt, Mua MacBook...',
                          prefixIcon: const Icon(
                            Icons.flight_takeoff_rounded,
                            size: 20,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: visual.borderColor(restingBorder),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: visual.isInvalid
                                  ? visual.borderColor(restingBorder)
                                  : primaryColor,
                              width: 1.6,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _tagController,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Mã Tag nhận diện chi tiêu',
                      hintText: 'Ví dụ: #dalat, #macbook...',
                      prefixIcon: Icon(Icons.tag_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _presetEmojis.map((em) {
                        final isSel = _selectedEmoji == em;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => setState(() => _selectedEmoji = em),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSel ? primaryColor.withValues(alpha: 0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSel ? Border.all(color: primaryColor, width: 1.5) : null,
                              ),
                              child: Text(em, style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: _presetColors.map((hex) {
                      final isSel = _selectedColorHex == hex;
                      final col = _parseColor(hex);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _selectedColorHex = hex),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: col,
                              shape: BoxShape.circle,
                              border: isSel ? Border.all(color: Colors.white, width: 2.5) : null,
                              boxShadow: isSel ? [BoxShadow(color: col.withValues(alpha: 0.5), blurRadius: 6)] : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.date_range_rounded, color: primaryColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Thời gian: ${DateFormat('dd/MM/yyyy').format(_startDate)} → ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                              ),
                            ),
                          ),
                          const Icon(Icons.edit_calendar_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  AppValidationFeedback(
                    controller: _amountFeedback,
                    builder: (context, visual) {
                      final restingBorder =
                      primaryColor.withValues(alpha: 0.30);

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppTokens.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: visual.borderColor(restingBorder),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'HẠN MỨC SỰ KIỆN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppTokens.darkMuted
                                    : AppTokens.lightMuted,
                              ),
                            ),
                            Text(
                              _formatCurrency(displayAmount),
                              style: currencyTextStyle(context, TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: primaryColor,
                              )),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  _buildNumpadGrid(isDark, (k) => _onKeyPress(k)),
                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isSaving ? null : _saveProjectBudget,
                      child: Text(
                        isEdit ? '✓ CẬP NHẬT SỰ KIỆN' : '✓ LƯU SỰ KIỆN / DỰ ÁN',
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
    );
  }
}

// ==============================================================================
// 🌟 BOTTOM SHEET: THIẾT LẬP HẠN MỨC ĐỊNH KỲ RIÊNG CHO THÁNG HIỆN TẠI
// ==============================================================================

Future<void> showInsightsBudgetEditor(BuildContext context, {required Category category, required DateTime anchor, Budget? budget}) {
  return AppAnimationPolicy.showFluidSheet<void>(context: context, mode: FluidSheetMode.nestedScrollable,
    builder: (_, __) => _BudgetSetupSheet(editBudget: budget, initialCategory: category, initialAnchor: anchor));
}

class _BudgetSetupSheet extends ConsumerStatefulWidget {
  final Budget? editBudget;
  final Category? initialCategory;
  final DateTime? initialAnchor;

  const _BudgetSetupSheet({
    super.key,
    this.editBudget,
    this.initialCategory,
    this.initialAnchor,
  });

  @override
  ConsumerState<_BudgetSetupSheet> createState() => _BudgetSetupSheetState();
}

class _BudgetSetupSheetState extends ConsumerState<_BudgetSetupSheet> {
  String? _selectedCategoryId;
  Category? _selectedCategoryObject;

  late int _cycleStartDay;
  String _amountBuffer = '1000000';

  final AppValidationFeedbackController _categoryFeedback =
  AppValidationFeedbackController();
  final AppValidationFeedbackController _amountFeedback =
  AppValidationFeedbackController();

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  void initState() {
    super.initState();
    final DateTime anchorMonth = widget.initialAnchor ?? ref.read(budgetAnchorMonthProvider);
    final cycleStore = ref.read(cycleStartDaysByMonthProvider);
    final cycleRange = computeMonthCycleRange(anchorMonth, cycleStore);

    if (widget.editBudget != null) {
      final b = widget.editBudget!;
      _selectedCategoryId = b.categoryId;
      _cycleStartDay = b.cycleStartDay;
      _amountBuffer = b.amount.toStringAsFixed(0);
    } else {
      _selectedCategoryId = widget.initialCategory?.id;
      _selectedCategoryObject = widget.initialCategory;
      _cycleStartDay = cycleRange.startDay;
    }
  }

  @override
  void dispose() {
    _categoryFeedback.dispose();
    _amountFeedback.dispose();
    super.dispose();
  }

  void _onKeyPress(String val) {
    HapticFeedback.selectionClick();
    setState(() {
      if (val == 'C') {
        _amountBuffer = '0';
      } else if (val == 'BACK') {
        if (_amountBuffer.length > 1) {
          _amountBuffer =
              _amountBuffer.substring(0, _amountBuffer.length - 1);
        } else {
          _amountBuffer = '0';
        }
      } else if (val == '000') {
        if (_amountBuffer != '0' && _amountBuffer.length <= 9) {
          _amountBuffer += '000';
        }
      } else {
        if (_amountBuffer == '0') {
          _amountBuffer = val;
        } else if (_amountBuffer.length <= 11) {
          _amountBuffer += val;
        }
      }
    });

    if ((double.tryParse(_amountBuffer) ?? 0.0) > 0) {
      _amountFeedback.clear();
    }
  }

  Future<void> _openUnifiedCategorySelector() async {
    final chosen = await CategoryTreeModal.show(
      context,
      initialType: CategoryType.expense,
      allowSelectParent: true,
      selectedCategoryId: _selectedCategoryId,
      title: 'Chọn Danh Mục Ngân Sách',
    );

    if (!mounted || chosen == null) return;

    setState(() {
      _selectedCategoryId = chosen.id;
      _selectedCategoryObject = chosen;
    });
    _categoryFeedback.clear();
  }

  Future<void> _saveBudget() async {
    final amount = double.tryParse(_amountBuffer) ?? 0.0;
    final categoryInvalid = _selectedCategoryId == null;
    final amountInvalid = amount <= 0;

    if (categoryInvalid || amountInvalid) {
      HapticFeedback.heavyImpact();
      if (categoryInvalid) {
        _categoryFeedback.reject(emitHaptic: false);
      }
      if (amountInvalid) {
        _amountFeedback.reject(emitHaptic: false);
      }
      return;
    }

    final db = ref.read(databaseProvider);
    final DateTime anchorMonth = widget.initialAnchor ?? ref.read(budgetAnchorMonthProvider);
    final monthKey = DateFormat('yyyy-MM').format(anchorMonth);

    final budgetId =
        widget.editBudget?.id ?? 'b_${monthKey}_$_selectedCategoryId';

    await db.into(db.budgets).insertOnConflictUpdate(
      BudgetsCompanion(
        id: drift.Value(budgetId),
        categoryId: drift.Value(_selectedCategoryId!),
        amount: drift.Value(amount),
        cycleStartDay: drift.Value(_cycleStartDay),
        periodMonth:
        drift.Value(DateTime(anchorMonth.year, anchorMonth.month, 1)),
      ),
    );

    HapticFeedback.mediumImpact();

    if (!mounted) return;

    AppFeedback.showSuccess(
      context,
      'Đã lưu hạn mức ${_formatCurrency(amount)} cho Tháng ${DateFormat('MM/yyyy').format(anchorMonth)}.',
      emitHaptic: false,
    );
    Navigator.of(context).pop();
  }

  Future<void> _deleteBudget() async {
    if (widget.editBudget == null) return;
    final DateTime anchorMonth = widget.initialAnchor ?? ref.read(budgetAnchorMonthProvider);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa hạn mức'),
        content: Text(
          'Xóa hạn mức danh mục này khỏi kế hoạch '
              'Tháng ${DateFormat('MM/yyyy').format(anchorMonth)}? '
              'Các tháng khác sẽ không bị ảnh hưởng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa',
              style: TextStyle(color: AppTokens.expense),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final db = ref.read(databaseProvider);
    await (db.delete(db.budgets)
      ..where((b) => b.id.equals(widget.editBudget!.id)))
        .go();

    HapticFeedback.mediumImpact();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Category? _findCategoryById(List<Category> categories, String? id) {
    if (id == null || id.isEmpty) return null;

    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  String _hierarchyBadgeLabel(
      Category category,
      List<Category> allCategories,
      ) {
    final parentId = category.parentId;
    if (parentId == null || parentId.isEmpty) {
      return 'Nhóm cha';
    }

    final parent = _findCategoryById(allCategories, parentId);
    if (parent == null) {
      return 'Mục con';
    }

    return 'Mục con • ${parent.name}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final DateTime anchorMonth = widget.initialAnchor ?? ref.watch(budgetAnchorMonthProvider);
    final allCategories =
        ref.watch(allCategoriesStreamProvider).valueOrNull ?? <Category>[];

    if (_selectedCategoryId != null && _selectedCategoryObject == null) {
      _selectedCategoryObject =
          _findCategoryById(allCategories, _selectedCategoryId);
    }

    final selectedCategory = _selectedCategoryObject;
    final displayAmount = double.tryParse(_amountBuffer) ?? 0.0;

    final sheetColor = isDark
        ? const Color(0xFF151C28).withValues(alpha: 0.98)
        : Colors.white.withValues(alpha: 0.98);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
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
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ============================================================
                // HEADER
                // ============================================================
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.editBudget != null
                                ? 'Chỉnh Sửa Hạn Mức'
                                : 'Thiết Lập Hạn Mức',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppTokens.darkText
                                  : AppTokens.lightText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Áp dụng cho Chu kỳ Tháng '
                                '${DateFormat('MM/yyyy').format(anchorMonth)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppTokens.darkMuted
                                  : AppTokens.lightMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.editBudget != null) ...[
                      IconButton(
                        tooltip: 'Xóa hạn mức',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppTokens.expense,
                          size: 20,
                        ),
                        onPressed: _deleteBudget,
                      ),
                      const SizedBox(width: 2),
                    ],
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: const Text(
                        'Đóng',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ============================================================
                // 1. UNIFIED CATEGORY SELECTOR
                // ============================================================
                AppValidationFeedback(
                  controller: _categoryFeedback,
                  builder: (context, visual) {
                    final restingBorder = selectedCategory != null
                        ? accent.primary.withValues(alpha: 0.55)
                        : (isDark
                        ? AppTokens.darkBorder
                        : AppTokens.lightBorder);

                    return InkWell(
                      onTap: _openUnifiedCategorySelector,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppTokens.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: visual.borderColor(restingBorder),
                            width: visual.isInvalid
                                ? 1.6
                                : (selectedCategory != null ? 1.35 : 1.0),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (selectedCategory != null)
                              CategoryIconBadge(
                                category: selectedCategory,
                                size: 32,
                                iconSize: 17,
                              )
                            else
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: accent.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.folder_open_rounded,
                                  size: 18,
                                  color: accent.primary,
                                ),
                              ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: selectedCategory != null
                                  ? Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      selectedCategory.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? AppTokens.darkText
                                            : AppTokens.lightText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent.primary
                                            .withValues(alpha: 0.11),
                                        borderRadius:
                                        BorderRadius.circular(999),
                                        border: Border.all(
                                          color: accent.primary
                                              .withValues(alpha: 0.24),
                                        ),
                                      ),
                                      child: Text(
                                        _hierarchyBadgeLabel(
                                          selectedCategory,
                                          allCategories,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: accent.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                                  : Text(
                                'Chọn danh mục ngân sách...',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppTokens.darkMuted
                                      : AppTokens.lightMuted,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: selectedCategory != null
                                  ? accent.primary
                                  : (isDark
                                  ? AppTokens.darkMuted
                                  : AppTokens.lightMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                // ============================================================
                // 2. HERO AMOUNT DISPLAY
                // ============================================================
                AppValidationFeedback(
                  controller: _amountFeedback,
                  builder: (context, visual) {
                    final restingBorder =
                    accent.primary.withValues(alpha: 0.30);

                    return Container(
                      width: double.infinity,
                      height: 68,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppTokens.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: visual.borderColor(restingBorder),
                          width: visual.isInvalid ? 1.6 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HẠN MỨC THÁNG',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.35,
                              color: isDark
                                  ? AppTokens.darkMuted
                                  : AppTokens.lightMuted,
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatCurrency(displayAmount),
                                  maxLines: 1,
                                  style: currencyTextStyle(context, TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                    color: accent.primary,
                                  )),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // ============================================================
                // 3. FREED-UP NUMPAD — 44PX KEYS
                // ============================================================
                _buildNumpadGrid(
                  isDark,
                  _onKeyPress,
                  keyHeight: 44,
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent.primary,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _saveBudget,
                    child: Text(
                      widget.editBudget != null
                          ? '✓ CẬP NHẬT HẠN MỨC THÁNG NÀY'
                          : '✓ LƯU HẠN MỨC CHO THÁNG NÀY',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.25,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// HELPER: 4x4 NUMPAD KEYPAD REUSABLE
// ==============================================================================
Widget _buildNumpadGrid(
    bool isDark,
    Function(String) onKey, {
      double keyHeight = 42,
    }) {
  final keys = [
    ['1', '2', '3', 'BACK'],
    ['4', '5', '6', 'C'],
    ['7', '8', '9', '000'],
    ['', '0', '', ''],
  ];

  return Column(
    children: keys.map((row) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: row.map((k) {
            if (k.isEmpty) return const Expanded(child: SizedBox());
            final isSpecial = k == 'BACK' || k == 'C';
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => onKey(k),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: keyHeight,
                    decoration: BoxDecoration(
                      color: isDark ? AppTokens.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                    ),
                    child: Center(
                      child: isSpecial
                          ? (k == 'BACK'
                          ? const Icon(Icons.backspace_outlined, size: 16)
                          : const Text('C', style: TextStyle(fontWeight: FontWeight.bold)))
                          : Text(k, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }).toList(),
  );
}
