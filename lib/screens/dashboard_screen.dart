import '../widgets/ambient_canvas.dart';
import '../services/fiscal_day.dart';
import '../widgets/currency_text.dart';
import '../features/notifications/notification_center_screen.dart';
// ==============================================================================
// File: lib/screens/dashboard_screen.dart
// Architecture: Executive Real-Time Financial Dashboard with Preserved Motion Transitions
// Stack: flutter_riverpod, drift, intl, dart:async, dart:io, dart:ui
// Features:
// 1. Đồng Bộ PreservedBalanceTumbler Toàn Bộ Dashboard (Zero Layout Shift Tumbler 180ms):
//    - [Khối 2] Thẻ Đỏ - Tổng số dư khả dụng: height 40px, font 28, w900, màu trắng, maskedValue '•••••••• ₫'.
//    - [Khối 2] Thẻ Đỏ - Dòng tiền chu kỳ: height 18px, font 12, w800, monospace, letterSpacing: -0.3, maskedValue '•••••• ₫', căn phải.
//    - [Khối 4] Hàng 3 thẻ nhỏ - Thu Nhập: height 20px, font 14, w800, monospace, letterSpacing: -0.3, màu AppTokens.income, maskedValue '+•••••• ₫'.
//    - [Khối 4] Hàng 3 thẻ nhỏ - Đã Chi: height 20px, font 14, w800, monospace, letterSpacing: -0.3, màu AppTokens.expense, maskedValue '-•••••• ₫'.
//    - [Khối 4] Hàng 3 thẻ nhỏ - Tốc độ: Tách đều 2 bên (Trái: Số % tiến độ 14px w800, Phải: Nhãn trạng thái Nhanh/Ổn định 11px w800)
//      cùng chạy Tumbler 180ms đồng điệu, triệt tiêu 100% chớp tắt layout.
// 2. Pure Beam Reload & Secret Vault Trượt Trần (TwoStageOverscrollHeader).
// 3. Granular Privacy Masking (Ẩn/Hiện riêng lẻ hoặc Master Toggle thông minh).
// 4. Khóa Cố Định Chu Kỳ Thời Gian Thực & Đồng Bộ CSDL Drift SQLite.
// 5. Kết Nối Chuẩn Static Launcher QuickEntrySheet.show (Fluid Sheet Engine).
// ==============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../widgets/sliding_segmented_bar.dart';
import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../services/auth_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_customization_sheet.dart';
import '../widgets/category_icon_badge.dart';
import '../widgets/category_tree_modal.dart';
import '../widgets/dashboard_hero_card.dart';
import '../widgets/preserved_balance_tumbler.dart';
import '../widgets/quick_entry_sheet.dart';
import '../widgets/spending_trend_chart.dart';
import '../widgets/two_stage_overscroll_header.dart';
import 'ledger_screen.dart'
    show cycleStartDaysByMonthProvider, computeMonthCycleRange, CycleMode;
import 'main_scaffold.dart' show bottomNavIndexProvider;
import 'vault_auth_screen.dart';
import 'wallet_manager_screen.dart';

// 🌟 Provider chế độ chu kỳ chỉ áp dụng riêng cho DashboardScreen
final dashboardCycleModeProvider =
    StateProvider<CycleMode>((ref) => CycleMode.customCycle);

// StreamProvider lấy các giao dịch gần đây nhất (tối đa 15 giao dịch)
final recentTransactionsStreamProvider =
    StreamProvider.autoDispose<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactions)
        ..where((t) =>
            t.deletedAt.isNull() &
            t.goalId.isNull() &
            (t.envelopeType.equals('savings').not() | t.envelopeType.isNull()))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.date)])
        ..limit(15))
      .watch();
});

// StreamProvider lấy danh sách ví
final dashboardPeriodTransactionsProvider = StreamProvider.autoDispose
    .family<List<Transaction>, DateTimeRange>((ref, range) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactions)
        ..where((t) =>
            t.deletedAt.isNull() &
            t.goalId.isNull() &
            (t.envelopeType.equals('savings').not() | t.envelopeType.isNull()) &
            t.date.isBiggerOrEqualValue(range.start) &
            t.date.isSmallerThanValue(range.end)))
      .watch();
});

// Formula inputs must come from the same committed database snapshot.
final dashboardFinancialSnapshotProvider = StreamProvider.autoDispose
    .family<DashboardFinancialSnapshot, DateTimeRange>((ref, range) =>
        ref.watch(databaseProvider).watchDashboardFinancialSnapshot(
            range.start, range.end));

final dashboardWalletsStreamProvider =
    StreamProvider.autoDispose<List<Wallet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.wallets).watch();
});

// StreamProvider lấy danh sách ngân sách
final dashboardBudgetsStreamProvider =
    StreamProvider.autoDispose<List<Budget>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.budgets).watch();
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  // =========================================================================
  // 🔒 DASHBOARD PRIVACY STATE (Chỉ áp dụng trong màn hình Tổng quan)
  // =========================================================================
  bool _balancesVisible = false;

  void _toggleAllVisibility() {
    HapticFeedback.selectionClick();
    setState(() => _balancesVisible = !_balancesVisible);
  }

  String _formatCurrency(double amount, [String currency = '₫']) {
    final formatter = NumberFormat.currency(
        locale: 'vi_VN', symbol: currency, decimalDigits: 0);
    return formatter.format(amount);
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  /// 🌟 HÀM LÀM MỚI DỮ LIỆU TOÀN DIỆN CHO DASHBOARD
  Future<void> _handleRefreshDashboard() async {
    ref.invalidate(recentTransactionsStreamProvider);
    ref.invalidate(dashboardWalletsStreamProvider);
    ref.invalidate(categoriesTreeStreamProvider);
    ref.invalidate(dashboardBudgetsStreamProvider);

    await Future.delayed(const Duration(milliseconds: 400));
  }

  /// 🔓 ĐIỀU HƯỚNG TRƯỢT TỪ TRẦN MÀN HÌNH XUỐNG VÀO VAULT AUTH SCREEN
  void _openSecretVaultWithSlideDownTransition() {
    Navigator.of(context).push(
      PreservedPageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        barrierDismissible: false,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const VaultAuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.0, -1.0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          );

          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.45, curve: Curves.easeIn),
            ),
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// 🌟 MỞ BOTTOM SHEET GHI CHÉP GIAO DỊCH QUA FLUID SHEET ENGINE
  void _openQuickEntrySheet(BuildContext context,
      {Transaction? tx, double? dailySafe}) {
    QuickEntrySheet.show(
      context,
      initialTransaction: tx,
      prefilledDailySafe: dailySafe,
    );
  }

  Widget _buildProfileAvatar(UserProfile profile, bool isDark) {
    final avatarColor = _parseColor(profile.avatarColorHex);

    Widget avatarContent;
    switch (profile.avatarType) {
      case UserAvatarType.google:
        if (profile.isSignedIn && profile.avatarValue.startsWith('http')) {
          avatarContent = Image.network(
            profile.avatarValue,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _buildFallbackInitialText(profile, avatarColor),
          );
        } else {
          avatarContent = _buildFallbackInitialText(profile, avatarColor);
        }
        break;

      case UserAvatarType.customImage:
        final file = File(profile.avatarValue);
        if (file.existsSync()) {
          avatarContent = Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _buildFallbackInitialText(profile, avatarColor),
          );
        } else {
          avatarContent = _buildFallbackInitialText(profile, avatarColor);
        }
        break;

      case UserAvatarType.emoji:
        avatarContent = Center(
          child: Text(
            profile.avatarValue,
            style: const TextStyle(fontSize: 20),
          ),
        );
        break;

      case UserAvatarType.initials:
        avatarContent = _buildFallbackInitialText(profile, avatarColor);
        break;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: isDark ? 0.22 : 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: avatarColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: avatarColor.withValues(alpha: isDark ? 0.25 : 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.5),
            child: avatarContent,
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: profile.isSignedIn ? const Color(0xFF10B981) : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppTokens.darkBg : Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackInitialText(UserProfile profile, Color color) {
    final initial = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()[0].toUpperCase()
        : 'K';
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final userProfile = ref.watch(currentUserProfileProvider);

    final boundary = ref.watch(dayCutoffProvider);
    final now = ref.watch(fiscalTodayProvider);
    var currentMonth = DateTime(now.year, now.month, 1);

    final dashboardMode = ref.watch(dashboardCycleModeProvider);
    final cycleStore = ref.watch(cycleStartDaysByMonthProvider);
    if (dashboardMode == CycleMode.customCycle &&
        now.isBefore(computeMonthCycleRange(currentMonth, cycleStore).startDate)) {
      currentMonth = DateTime(now.year, now.month - 1, 1);
    }
    final cycleRange = computeMonthCycleRange(currentMonth, cycleStore);
    final periodStart = boundary.start(dashboardMode == CycleMode.customCycle
        ? cycleRange.startDate : DateTime(currentMonth.year, currentMonth.month, 1));
    final periodEnd = dashboardMode == CycleMode.customCycle
        ? boundary.end(cycleRange.endDate)
        : boundary.start(DateTime(currentMonth.year, currentMonth.month + 1, 1));
    final financial = ref.watch(dashboardFinancialSnapshotProvider(
        DateTimeRange(start: periodStart, end: periodEnd)));
    final periodTxsAsync = financial.whenData((data) => data.transactions);

    final txsAsync = ref.watch(recentTransactionsStreamProvider);
    final walletsAsync = financial.whenData((data) => data.wallets);
    final categoriesAsync = financial.whenData((data) => data.categories);
    final budgetsAsync = financial.whenData((data) => data.budgets);

    final Map<String, Category> categoriesMap = {
      for (final c in categoriesAsync.valueOrNull ?? <Category>[]) c.id: c,
    };

    final Map<String, Wallet> walletsMap = {
      for (final w in walletsAsync.valueOrNull ?? <Wallet>[]) w.id: w,
    };


    final totalWalletBalance = (walletsAsync.valueOrNull ?? <Wallet>[])
        .where((w) => !w.isExcludedFromTotal)
        .fold(0.0, (sum, w) => sum + w.balance);

    final cycleTxs = periodTxsAsync.valueOrNull ?? <Transaction>[];

    final totalIncome = cycleTxs
        .where((t) => t.type == CategoryType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final totalExpense = cycleTxs
        .where((t) => t.type == CategoryType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final netSavings = totalIncome - totalExpense;

    final cycleStartDate = dashboardMode == CycleMode.customCycle
        ? cycleRange.startDate
        : DateTime(currentMonth.year, currentMonth.month, 1);


    final totalCycleDays = dashboardMode == CycleMode.customCycle
        ? cycleRange.daysCount
        : DateTime(currentMonth.year, currentMonth.month + 1, 0).day;

    final int daysElapsed =
        math.max(1, now.difference(cycleStartDate).inDays + 1);

    final allBudgets = budgetsAsync.valueOrNull ?? <Budget>[];
    final recurringBudgetsForThisPeriod = allBudgets.where((b) {
      if (b.id.startsWith('event_')) return false;
      return b.periodMonth.year == currentMonth.year &&
          b.periodMonth.month == currentMonth.month;
    }).toList();

    final totalRecurringBudget =
        recurringBudgetsForThisPeriod.fold(0.0, (sum, b) => sum + b.amount);
    final hasRecurringBudget = recurringBudgetsForThisPeriod.isNotEmpty;

    final baseBudgetForBurnRate = hasRecurringBudget
        ? totalRecurringBudget
        : (totalIncome > 0 ? totalIncome : math.max(1.0, totalExpense));

    final budgetConsumedPct =
        (totalExpense / baseBudgetForBurnRate).clamp(0.0, 1.0);
    final timeElapsedPct = (daysElapsed / totalCycleDays).clamp(0.0, 1.0);
    final isOverspending = (budgetConsumedPct > timeElapsedPct + 0.1);

    final cardInk = isDark ? Colors.white : AppTokens.lightText;

    return BalancePrivacyScope(
        visible: _balancesVisible,
        child: AppFeedbackDismissRegion(
          child: AmbientCanvas(
            dashboard: true,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: TwoStageOverscrollHeader(
                  onRefresh: _handleRefreshDashboard,
                  onSecretVaultTrigger: _openSecretVaultWithSlideDownTransition,
                  glowColor: accent.primary,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      // ===============================================================
                      // [KHỐI 1]: HEADER (AVATAR + LỜI CHÀO + GLOBAL PRIVACY)
                      // ===============================================================
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      AvatarCustomizationSheet.show(context),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2.0),
                                    child: Row(
                                      children: [
                                        _buildProfileAvatar(
                                            userProfile, isDark),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Xin chào,',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark
                                                      ? AppTokens.darkMuted
                                                      : AppTokens.lightMuted,
                                                ),
                                              ),
                                              const SizedBox(height: 1),
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      userProfile.displayName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: -0.3,
                                                        color: isDark
                                                            ? AppTokens.darkText
                                                            : AppTokens
                                                                .lightText,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.expand_more_rounded,
                                                    size: 16,
                                                    color: isDark
                                                        ? AppTokens.darkMuted
                                                        : AppTokens.lightMuted,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const NotificationBell(),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: _toggleAllVisibility,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppTokens.darkCard
                                            : AppTokens.lightCardSubtle,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark
                                              ? AppTokens.darkBorder
                                              : AppTokens.lightBorder,
                                        ),
                                      ),
                                      child: Icon(
                                        _balancesVisible
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        size: 16,
                                        color: _balancesVisible
                                            ? accent.primary
                                            : (isDark
                                                ? AppTokens.darkMuted
                                                : AppTokens.lightMuted),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // BỘ CHỌN CHU KỲ THỜI GIAN THỰC — shared preserved sliding engine
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 4),
                        sliver: SliverToBoxAdapter(
                          child: SlidingSegmentedBar<CycleMode>(
                            height: 44,
                            duration: const Duration(milliseconds: 185),
                            overshootPx: 1.8,
                            debugLabel: 'Dashboard.cycleMode',
                            selectedValue: dashboardMode,
                            trackColor: isDark
                                ? AppTokens.darkCard
                                : AppTokens.lightCardSubtle,
                            trackBorderColor: isDark
                                ? AppTokens.darkBorder
                                : AppTokens.lightBorder,
                            indicatorColor: isDark
                                ? AppTokens.darkCardSubtle
                                : Colors.white,
                            indicatorBorderColor: Colors.transparent,
                            mutedTextColor: isDark
                                ? AppTokens.darkMuted
                                : AppTokens.lightMuted,
                            indicatorShadowColor:
                                Colors.black.withValues(alpha: 0.05),
                            fontSize: 11,
                            items: [
                              SlidingSegmentedItem<CycleMode>(
                                value: CycleMode.calendar,
                                icon: Icons.calendar_month_rounded,
                                label:
                                    'Tháng ${now.month} (01 – ${DateTime(now.year, now.month + 1, 0).day}/${now.month.toString().padLeft(2, '0')})',
                                activeColor: isDark
                                    ? AppTokens.darkText
                                    : AppTokens.lightText,
                              ),
                              SlidingSegmentedItem<CycleMode>(
                                value: CycleMode.customCycle,
                                label:
                                    'Chu kỳ (${DateFormat('dd/MM').format(cycleRange.startDate)} – ${DateFormat('dd/MM').format(cycleRange.endDate)})',
                                icon: Icons.autorenew_rounded,
                                activeColor: accent.primary,
                              ),
                            ],
                            onValueChanged: (mode) {
                              ref
                                  .read(dashboardCycleModeProvider.notifier)
                                  .state = mode;
                            },
                          ),
                        ),
                      ),

                      // ===============================================================
                      // [KHỐI 2]: THẺ TỔNG SỐ DƯ KHẢ DỤNG (FULL-WIDTH CARD VỚI TUMBLER)
                      // ===============================================================
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 4),
                        sliver: SliverToBoxAdapter(
                          child: _ThemedAssetCard(
                            accent: accent,
                            visible: _balancesVisible,
                            balance: _formatCurrency(totalWalletBalance),
                            cashflow:
                                '${netSavings >= 0 ? '+' : ''}${_formatCurrency(netSavings)}',
                            walletCount: walletsMap.length,
                            onWalletTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const WalletManagerScreen()));
                            },
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 6),
                        sliver: SliverToBoxAdapter(
                          child: DashboardHeroCard(
                            isVisible: _balancesVisible,
                            onVaultTap: _openSecretVaultWithSlideDownTransition,
                          ),
                        ),
                      ),

                      // ===============================================================
                      // [KHỐI 4]: HÀNG THỐNG KÊ PHỤ 3 CỘT (SUB-METRICS VỚI TUMBLER ĐỒNG BỘ)
                      // ===============================================================
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 4),
                        sliver: SliverToBoxAdapter(
                          child: SizedBox(
                              height: 80,
                              child: IntrinsicHeight(
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                          child: _CompactMetric(
                                              label: 'Thu nhập',
                                              icon: Icons.arrow_upward_rounded,
                                              value:
                                                  '+${NumberFormat.compact(locale: 'en').format(totalIncome)}',
                                              detail:
                                                  'Chưa đủ dữ liệu kỳ trước',
                                              visible: _balancesVisible,
                                              color: totalIncome > 0
                                                  ? accent.primary
                                                  : cardInk,
                                              isDark: isDark)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: _CompactMetric(
                                              label: 'Đã chi',
                                              icon:
                                                  Icons.arrow_downward_rounded,
                                              value:
                                                  '-${NumberFormat.compact(locale: 'en').format(totalExpense)}',
                                              detail:
                                                  'Chưa đủ dữ liệu kỳ trước',
                                              visible: _balancesVisible,
                                              color: totalExpense > 0
                                                  ? AppTokens.expense
                                                  : cardInk,
                                              isDark: isDark)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: _CompactMetric(
                                              label: 'Tốc độ',
                                              icon: Icons.bolt_rounded,
                                              value:
                                                  '${(budgetConsumedPct * 100).toStringAsFixed(0)}%',
                                              detail: isOverspending
                                                  ? 'Nhanh'
                                                  : 'Ổn định',
                                              visible: _balancesVisible,
                                              color: isOverspending &&
                                                      totalExpense > 0
                                                  ? AppTokens.expense
                                                  : cardInk,
                                              isDark: isDark)),
                                    ]),
                              )),
                        ),
                      ),

                      // ===============================================================
                      // [KHỐI 5]: THẺ XU HƯỚNG CHI TIÊU (SPENDING TREND CHART)
                      // ===============================================================
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        sliver: SliverToBoxAdapter(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppTokens.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isDark
                                    ? AppTokens.darkBorder
                                    : AppTokens.lightBorder,
                              ),
                            ),
                            child:
                                SpendingTrendChart(isVisible: _balancesVisible),
                          ),
                        ),
                      ),

                      // ===============================================================
                      // [KHỐI 6]: DANH SÁCH GIAO DỊCH GẦN ĐÂY
                      // ===============================================================
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Giao Dịch Gần Đây',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppTokens.darkText
                                      : AppTokens.lightText,
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(bottomNavIndexProvider.notifier)
                                      .state = 1;
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Xem tất cả',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: accent.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(Icons.chevron_right_rounded,
                                          size: 16, color: accent.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      txsAsync.when(
                        data: (txs) {
                          if (txs.isEmpty) {
                            return SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 36, horizontal: 20),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.receipt_long_rounded,
                                        size: 44,
                                        color: isDark
                                            ? AppTokens.darkMuted
                                            : AppTokens.lightMuted,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Chưa có giao dịch nào được ghi chép',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? AppTokens.darkMuted
                                              : AppTokens.lightMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final tx = txs[index];
                                  final isExpense =
                                      tx.type == CategoryType.expense ||
                                      tx.type == CategoryType.balanceAdjustmentOut;
                                  final wallet = walletsMap[tx.walletId];
                                  final category = categoriesMap[tx.categoryId];

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _openQuickEntrySheet(
                                            context,
                                            tx: tx,
                                            dailySafe: null),
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppTokens.darkCard
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isDark
                                                  ? AppTokens.darkBorder
                                                  : AppTokens.lightBorder,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              CategoryIconBadge(
                                                category: category,
                                                isExpense: isExpense,
                                                size: 38,
                                                iconSize: 18,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            tx.isBalanceAdjustment
                                                                ? 'Kiểm kê ví · Điều chỉnh số dư'
                                                                : tx.note ??
                                                                tx.merchant ??
                                                                category
                                                                    ?.name ??
                                                                'Giao dịch',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: isDark
                                                                  ? AppTokens
                                                                      .darkText
                                                                  : AppTokens
                                                                      .lightText,
                                                            ),
                                                          ),
                                                        ),
                                                        if (tx.isAiParsed ==
                                                            true) ...[
                                                          const SizedBox(
                                                              width: 6),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 5,
                                                              vertical: 1.5,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: accent
                                                                  .primary
                                                                  .withValues(
                                                                      alpha:
                                                                          0.16),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          5),
                                                            ),
                                                            child: Text(
                                                              'AI',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                color: accent
                                                                    .primary,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      '${DateFormat('dd/MM HH:mm').format(tx.date)} • ${wallet?.name ?? 'Ví'} • ${category?.name ?? 'Chung'}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark
                                                            ? AppTokens
                                                                .darkMuted
                                                            : AppTokens
                                                                .lightMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              CurrencyText(
                                                '${isExpense ? '-' : '+'}${_formatCurrency(tx.amount)}',
                                                style: currencyTextStyle(
                                                    context,
                                                    TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: isExpense
                                                          ? AppTokens.expense
                                                          : AppTokens.income,
                                                    )),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                childCount: txs.length,
                              ),
                            ),
                          );
                        },
                        loading: () => const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                        error: (err, _) => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Lỗi tải giao dịch: $err',
                              style: const TextStyle(color: AppTokens.expense),
                            ),
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 96)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
  }
}

class _ThemedAssetCard extends StatelessWidget {
  const _ThemedAssetCard(
      {required this.accent,
      required this.visible,
      required this.balance,
      required this.cashflow,
      required this.walletCount,
      required this.onWalletTap});
  final AppAccentPreset accent;
  final bool visible;
  final String balance;
  final String cashflow;
  final int walletCount;
  final VoidCallback onWalletTap;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 196,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.primary,
              accent.secondary,
              Color.lerp(accent.secondary, Colors.black, 0.15)!
            ]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: accent.primary.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 6))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(children: [
          Positioned(
              right: 12,
              top: 42,
              child: ExcludeSemantics(
                  child: IgnorePointer(
                      child: Transform.rotate(
                          angle: -0.18,
                          child: Icon(Icons.account_balance_wallet_rounded,
                              size: 98,
                              color: accent.secondary.withValues(alpha: 0.75),
                              shadows: [
                                Shadow(
                                    color:
                                        accent.secondary.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(4, 8))
                              ]))))),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text('TỔNG SỐ DƯ KHẢ DỤNG',
                                  style: TextStyle(
                                      fontSize: 11,
                                      letterSpacing: 0.6,
                                      color: Colors.white
                                          .withValues(alpha: 0.8))))),
                      const SizedBox(width: 8),
                      InkWell(
                          onTap: onWalletTap,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.wallet,
                                        size: 12, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text('$walletCount ví ❯',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.white)),
                                  ]))),
                    ]),
                    const Spacer(),
                    FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: PreservedBalanceTumbler(
                            isVisible: visible,
                            realValue: balance,
                            maskedValue: '•••••••• ₫',
                            height: 42,
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.6))),
                    const Spacer(),
                    Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Text('Dòng tiền chu kỳ: ',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.white)),
                          Expanded(
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: PreservedBalanceTumbler(
                                      isVisible: visible,
                                      realValue: cashflow,
                                      height: 18,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white)))),
                        ])),
                  ])),
        ]),
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric(
      {required this.label,
      required this.icon,
      required this.value,
      required this.detail,
      required this.visible,
      required this.color,
      required this.isDark});
  final String label, value, detail;
  final IconData icon;
  final bool visible, isDark;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                width: 0.8)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        shape: BoxShape.circle),
                    child: Icon(icon, size: 13, color: color)),
                const SizedBox(width: 4),
                Expanded(
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.white
                                    : AppTokens.lightText)))),
              ]),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: PreservedBalanceTumbler(
                      isVisible: visible,
                      isCurrency: label != 'Tốc độ',
                      realValue: value,
                      maskedValue: '••••••',
                      height: 20,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: color))),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: CurrencyText(detail,
                      style: TextStyle(
                          fontSize: 9.5,
                          color: isDark
                              ? AppTokens.darkMuted
                              : AppTokens.lightMuted))),
            ]),
      );
}
