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
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../services/auth_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_customization_sheet.dart';
import '../widgets/category_icon_badge.dart';
import '../widgets/category_tree_modal.dart';
import '../widgets/dashboard_hero_card.dart';
import '../widgets/overrun_resolution_sheet.dart';
import '../widgets/preserved_balance_tumbler.dart';
import '../widgets/quick_entry_sheet.dart';
import '../widgets/safe_to_spend_breakdown_sheet.dart';
import '../widgets/spending_trend_chart.dart';
import '../widgets/two_stage_overscroll_header.dart';
import 'ledger_screen.dart'
    show
    cycleStartDaysByMonthProvider,
    computeMonthCycleRange,
    showEditCycleMilestoneSheet,
    CycleMode;
import 'main_scaffold.dart' show bottomNavIndexProvider;
import 'vault_auth_screen.dart';
import 'wallet_manager_screen.dart';

/// 🌟 ROUTE TRANSITION TRƯỢT TRẦN ÉP GIỮ NGUYÊN HOẠT ẢNH BẤT CHẤP HỆ ĐIỀU HÀNH
class PreservedPageRouteBuilder<T> extends PageRouteBuilder<T> {
  PreservedPageRouteBuilder({
    super.settings,
    required super.pageBuilder,
    super.transitionsBuilder,
    super.transitionDuration = const Duration(milliseconds: 300),
    super.reverseTransitionDuration = const Duration(milliseconds: 300),
    super.opaque = true,
    super.barrierDismissible = false,
    super.barrierColor,
    super.barrierLabel,
    super.maintainState = true,
    super.fullscreenDialog = false,
    super.allowSnapshotting = true,
  });

  @override
  AnimationController createAnimationController() {
    return AnimationController(
      vsync: navigator!,
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration,
      animationBehavior: AnimationBehavior.preserve,
    );
  }
}

// 🌟 Provider chế độ chu kỳ chỉ áp dụng riêng cho DashboardScreen
final dashboardCycleModeProvider = StateProvider<CycleMode>((ref) => CycleMode.customCycle);

// StreamProvider lấy các giao dịch gần đây nhất (tối đa 15 giao dịch)
final recentTransactionsStreamProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactions)
    ..where((t) => t.deletedAt.isNull())
    ..orderBy([(t) => drift.OrderingTerm.desc(t.date)])
    ..limit(15))
      .watch();
});

// StreamProvider lấy danh sách ví
final dashboardWalletsStreamProvider = StreamProvider.autoDispose<List<Wallet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.wallets).watch();
});

// StreamProvider lấy danh sách ngân sách
final dashboardBudgetsStreamProvider = StreamProvider.autoDispose<List<Budget>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.budgets).watch();
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with TickerProviderStateMixin {
  // =========================================================================
  // 🔒 GRANULAR PRIVACY MASKING STATE (Mặc định ẩn toàn bộ = false khi mở app)
  // =========================================================================
  bool _isTotalBalanceVisible = false;
  bool _isDailySafeVisible = false;
  bool _isIncomeVisible = false;
  bool _isExpenseVisible = false;
  bool _isSpeedVisible = false;

  bool get _isAnyVisible =>
      _isTotalBalanceVisible ||
          _isDailySafeVisible ||
          _isIncomeVisible ||
          _isExpenseVisible ||
          _isSpeedVisible;

  void _toggleAllVisibility() {
    HapticFeedback.selectionClick();
    setState(() {
      final targetState = !_isAnyVisible;
      _isTotalBalanceVisible = targetState;
      _isDailySafeVisible = targetState;
      _isIncomeVisible = targetState;
      _isExpenseVisible = targetState;
      _isSpeedVisible = targetState;
    });
  }

  String _formatCurrency(double amount, [String currency = '₫']) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: currency, decimalDigits: 0);
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
        pageBuilder: (context, animation, secondaryAnimation) => const VaultAuthScreen(),
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
  void _openQuickEntrySheet(BuildContext context, {Transaction? tx, double? dailySafe}) {
    QuickEntrySheet.show(
      context,
      initialTransaction: tx,
      prefilledDailySafe: dailySafe,
    );
  }

  /// 🌟 MỞ BOTTOM SHEET MỐC CHU KỲ — Dùng chung với Ledger (Haptic Wheel)
  void _openCycleMilestoneModal(
      BuildContext context,
      DateTime currentMonth,
      bool isDark,
      AppAccentPreset accent,
      ) {
    HapticFeedback.selectionClick();
    showEditCycleMilestoneSheet(
      context: context,
      anchorMonth: currentMonth,
      isDark: isDark,
      accent: accent,
    );
  }

  bool _isBillCategory(Category? cat) {
    if (cat == null) return false;
    final nameLower = cat.name.toLowerCase();
    final billKeywords = [
      'bill',
      'hóa đơn',
      'hoa don',
      'điện',
      'nước',
      'internet',
      'wifi',
      'tiền nhà',
      'tiền trọ',
      'thuê nhà',
      'trả góp',
      'vay',
      'nợ',
      'bảo hiểm',
      'học phí',
      'phí quản lý',
    ];
    for (final kw in billKeywords) {
      if (nameLower.contains(kw)) return true;
    }
    return false;
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
            errorBuilder: (_, __, ___) => _buildFallbackInitialText(profile, avatarColor),
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
            errorBuilder: (_, __, ___) => _buildFallbackInitialText(profile, avatarColor),
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
          width: 42,
          height: 42,
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
          fontFamily: 'monospace',
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

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month, 1);

    final dashboardMode = ref.watch(dashboardCycleModeProvider);
    final cycleStore = ref.watch(cycleStartDaysByMonthProvider);
    final cycleRange = computeMonthCycleRange(currentMonth, cycleStore);

    final txsAsync = ref.watch(recentTransactionsStreamProvider);
    final walletsAsync = ref.watch(dashboardWalletsStreamProvider);
    final categoriesAsync = ref.watch(categoriesTreeStreamProvider);
    final budgetsAsync = ref.watch(dashboardBudgetsStreamProvider);

    final fastRecoveryTotalDays = ref.watch(fastRecoveryTotalDaysProvider);
    final fastRecoveryDaysRemaining = ref.watch(fastRecoveryDaysRemainingProvider);
    final fastRecoveryLimit = ref.watch(fastRecoveryDailyLimitProvider);
    final amortizedDeduction = ref.watch(amortizedDailyDeductionProvider);

    final Map<String, Category> categoriesMap = {
      for (final c in categoriesAsync.valueOrNull ?? <Category>[]) c.id: c,
    };

    final Map<String, Wallet> walletsMap = {
      for (final w in walletsAsync.valueOrNull ?? <Wallet>[]) w.id: w,
    };

    final allRecentTxs = txsAsync.valueOrNull ?? <Transaction>[];

    final totalWalletBalance = (walletsAsync.valueOrNull ?? <Wallet>[])
        .where((w) => !w.isExcludedFromTotal)
        .fold(0.0, (sum, w) => sum + w.balance);

    final cycleTxs = allRecentTxs.where((t) {
      if (dashboardMode == CycleMode.calendar) {
        return t.date.year == currentMonth.year && t.date.month == currentMonth.month;
      } else {
        return t.date.isAfter(cycleRange.startDate.subtract(const Duration(seconds: 1))) &&
            t.date.isBefore(cycleRange.endDate.add(const Duration(seconds: 1)));
      }
    }).toList();

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

    final cycleEndDate = dashboardMode == CycleMode.customCycle
        ? cycleRange.endDate
        : DateTime(currentMonth.year, currentMonth.month + 1, 0, 23, 59, 59);

    final totalCycleDays = dashboardMode == CycleMode.customCycle
        ? cycleRange.daysCount
        : DateTime(currentMonth.year, currentMonth.month + 1, 0).day;

    final int daysElapsed = math.max(1, now.difference(cycleStartDate).inDays + 1);
    final int daysRemaining = math.max(1, cycleEndDate.difference(now).inDays + 1);

    final allBudgets = budgetsAsync.valueOrNull ?? <Budget>[];
    final recurringBudgetsForThisPeriod = allBudgets.where((b) {
      if (b.id.startsWith('event_')) return false;
      return b.periodMonth.year == currentMonth.year && b.periodMonth.month == currentMonth.month;
    }).toList();

    final totalRecurringBudget = recurringBudgetsForThisPeriod.fold(0.0, (sum, b) => sum + b.amount);
    final hasRecurringBudget = recurringBudgetsForThisPeriod.isNotEmpty;

    final List<UnpaidBillItem> unpaidBillItems = [];
    double unpaidBillsTotal = 0.0;

    for (final b in recurringBudgetsForThisPeriod) {
      final cat = categoriesMap[b.categoryId];
      if (_isBillCategory(cat)) {
        final isParent = cat != null && (cat.parentId == null || cat.parentId!.isEmpty);
        final spentForCat = cycleTxs.where((t) {
          if (t.type != CategoryType.expense) return false;
          if (isParent) {
            if (t.categoryId == b.categoryId) return true;
            final sub = categoriesMap[t.categoryId];
            return sub != null && sub.parentId == b.categoryId;
          } else {
            return t.categoryId == b.categoryId;
          }
        }).fold(0.0, (s, t) => s + t.amount);

        final remainingDue = math.max(0.0, b.amount - spentForCat);
        if (remainingDue > 0) {
          unpaidBillsTotal += remainingDue;
          unpaidBillItems.add(
            UnpaidBillItem(
              categoryName: cat?.name ?? 'Hóa đơn',
              budgetAmount: b.amount,
              spentAmount: spentForCat,
              remainingDue: remainingDue,
            ),
          );
        }
      }
    }

    final double freeBudgetRemaining;
    if (hasRecurringBudget) {
      final rawFree = totalRecurringBudget - totalExpense - unpaidBillsTotal;
      freeBudgetRemaining = math.max(0.0, math.min(rawFree, totalWalletBalance));
    } else {
      final rawLiquidity = totalWalletBalance - unpaidBillsTotal;
      freeBudgetRemaining = math.max(0.0, rawLiquidity);
    }

    final double todaySpent = cycleTxs.where((t) {
      return t.type == CategoryType.expense &&
          t.date.year == now.year &&
          t.date.month == now.month &&
          t.date.day == now.day;
    }).fold(0.0, (sum, t) => sum + t.amount);

    final double originalBaseLimit = daysRemaining > 0
        ? ((freeBudgetRemaining + todaySpent) / daysRemaining).floorToDouble()
        : 150000.0;

    final bool isOverSpentToday = todaySpent > originalBaseLimit;
    final double overAmount = math.max(0.0, todaySpent - originalBaseLimit);

    if (!isOverSpentToday &&
        (fastRecoveryDaysRemaining > 0 || fastRecoveryTotalDays > 0 || amortizedDeduction > 0)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(fastRecoveryDaysRemainingProvider) > 0 || ref.read(fastRecoveryTotalDaysProvider) > 0) {
          ref.read(fastRecoveryTotalDaysProvider.notifier).state = 0;
          ref.read(fastRecoveryDaysRemainingProvider.notifier).state = 0;
          ref.read(fastRecoveryDailyLimitProvider.notifier).state = 0.0;
        }
        if (ref.read(amortizedDailyDeductionProvider) > 0) {
          ref.read(amortizedDailyDeductionProvider.notifier).state = 0.0;
        }
      });
    }

    double effectiveDailyLimit = originalBaseLimit;
    if (isOverSpentToday) {
      if (fastRecoveryDaysRemaining > 0) {
        effectiveDailyLimit = fastRecoveryLimit;
      } else if (amortizedDeduction > 0) {
        effectiveDailyLimit = math.max(0.0, originalBaseLimit - amortizedDeduction);
      }
    }

    final double safeToSpendToday = math.max(0.0, effectiveDailyLimit - todaySpent);
    final double dailyProgressRatio = effectiveDailyLimit > 0
        ? (todaySpent / effectiveDailyLimit).clamp(0.0, 1.0)
        : 1.0;

    Color activeColor;
    final bool isAlarmRed = totalWalletBalance <= 0 ||
        (freeBudgetRemaining <= (totalRecurringBudget * 0.05) && totalRecurringBudget > 0);

    if (isAlarmRed) {
      activeColor = const Color(0xFFEF4444);
    } else if (isOverSpentToday) {
      activeColor = const Color(0xFFF59E0B);
    } else {
      activeColor = const Color(0xFF10B981);
    }

    final safeToSpendBreakdown = SafeToSpendBreakdown(
      totalBudget: hasRecurringBudget ? totalRecurringBudget : totalWalletBalance,
      totalSpent: totalExpense,
      unpaidBills: unpaidBillsTotal,
      unpaidBillItems: unpaidBillItems,
      freeBudgetRemaining: freeBudgetRemaining,
      daysRemaining: daysRemaining,
      safeToSpendDaily: safeToSpendToday,
      hasRecurringBudget: hasRecurringBudget,
      totalWalletBalance: totalWalletBalance,
    );

    final baseBudgetForBurnRate = hasRecurringBudget
        ? totalRecurringBudget
        : (totalIncome > 0 ? totalIncome : math.max(1.0, totalExpense));

    final budgetConsumedPct = (totalExpense / baseBudgetForBurnRate).clamp(0.0, 1.0);
    final timeElapsedPct = (daysElapsed / totalCycleDays).clamp(0.0, 1.0);
    final isOverspending = (budgetConsumedPct > timeElapsedPct + 0.1);

    return AppFeedbackDismissRegion(
      child: Scaffold(
        backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
        body: SafeArea(
          child: TwoStageOverscrollHeader(
            onRefresh: _handleRefreshDashboard,
            onSecretVaultTrigger: _openSecretVaultWithSlideDownTransition,
            glowColor: accent.primary,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                // ===============================================================
                // [KHỐI 1]: HEADER (AVATAR ĐỘNG + LỜI CHÀO + NÚT GHI CHÉP)
                // ===============================================================
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => AvatarCustomizationSheet.show(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                children: [
                                  _buildProfileAvatar(userProfile, isDark),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Xin chào,',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                userProfile.displayName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.3,
                                                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.expand_more_rounded,
                                              size: 16,
                                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
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
                            InkWell(
                              onTap: _toggleAllVisibility,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                                  ),
                                ),
                                child: Icon(
                                  _isAnyVisible
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  size: 16,
                                  color: _isAnyVisible
                                      ? accent.primary
                                      : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _openQuickEntrySheet(context, dailySafe: effectiveDailyLimit),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: accent.primary,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.primary.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ghi chép',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  sliver: SliverToBoxAdapter(
                    child: SlidingSegmentedBar<CycleMode>(
                      height: 42,
                      duration: const Duration(milliseconds: 185),
                      overshootPx: 1.8,
                      debugLabel: 'Dashboard.cycleMode',
                      selectedValue: dashboardMode,
                      trackColor: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                      trackBorderColor: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                      indicatorColor: isDark ? AppTokens.darkCardSubtle : Colors.white,
                      indicatorBorderColor: Colors.transparent,
                      mutedTextColor: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      indicatorShadowColor: Colors.black.withValues(alpha: 0.05),
                      fontSize: 11,
                      items: [
                        SlidingSegmentedItem<CycleMode>(
                          value: CycleMode.calendar,
                          label: 'Tháng ${now.month} (01 - ${DateTime(now.year, now.month + 1, 0).day}/${now.month.toString().padLeft(2, '0')})',
                          activeColor: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                        SlidingSegmentedItem<CycleMode>(
                          value: CycleMode.customCycle,
                          label:
                          'Chu kỳ (${DateFormat('dd/MM').format(cycleRange.startDate)} – ${DateFormat('dd/MM').format(cycleRange.endDate)})',
                          leadingText: '',
                          activeColor: accent.primary,
                          trailing: dashboardMode == CycleMode.customCycle
                              ? InkWell(
                            onTap: () => _openCycleMilestoneModal(
                              context,
                              currentMonth,
                              isDark,
                              accent,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
                                Icons.edit_calendar_rounded,
                                size: 14,
                                color: accent.primary,
                              ),
                            ),
                          )
                              : null,
                        ),
                      ],
                      onValueChanged: (mode) {
                        ref.read(dashboardCycleModeProvider.notifier).state = mode;
                      },
                    ),
                  ),
                ),

                // ===============================================================
                // [KHỐI 2]: THẺ TỔNG SỐ DƯ KHẢ DỤNG (FULL-WIDTH CARD VỚI TUMBLER)
                // ===============================================================
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                            color: accent.primary.withValues(alpha: isDark ? 0.15 : 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
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
                                'Tổng số dư khả dụng',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: isDark ? AppTokens.darkMuted : Colors.white70,
                                ),
                              ),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _isTotalBalanceVisible = !_isTotalBalanceVisible;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        _isTotalBalanceVisible
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const WalletManagerScreen()),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white24, width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.account_balance_wallet_outlined, size: 12, color: Colors.white),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${walletsMap.length} ví ❯',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          PreservedBalanceTumbler(
                            isVisible: _isTotalBalanceVisible,
                            realValue: _formatCurrency(totalWalletBalance),
                            maskedValue: '•••••••• ₫',
                            height: 40,
                            alignment: Alignment.centerLeft,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.savings_outlined, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Dòng tiền chu kỳ:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppTokens.darkMuted : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: PreservedBalanceTumbler(
                                    isVisible: _isTotalBalanceVisible,
                                    realValue: '${netSavings >= 0 ? '+' : ''}${_formatCurrency(netSavings)}',
                                    maskedValue: '•••••• ₫',
                                    height: 18,
                                    alignment: Alignment.centerRight,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      fontFamily: 'monospace',
                                      letterSpacing: -0.3,
                                      color: netSavings >= 0
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFFF87171),
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
                ),

                // ===============================================================
                // [KHỐI 3]: HERO CARD: "AN TOÀN HÔM NAY" (100% THỜI GIAN THỰC)
                // ===============================================================
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  sliver: SliverToBoxAdapter(
                    child: DashboardHeroCard(
                      breakdown: safeToSpendBreakdown,
                      safeToSpendToday: safeToSpendToday,
                      effectiveDailyLimit: effectiveDailyLimit,
                      todaySpent: todaySpent,
                      dailyProgressRatio: dailyProgressRatio,
                      activeColor: activeColor,
                      daysRemaining: daysRemaining,
                      anchorMonth: currentMonth,
                      isVisible: _isDailySafeVisible,
                      onToggleVisibility: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isDailySafeVisible = !_isDailySafeVisible;
                        });
                      },
                      isOverSpentToday: isOverSpentToday,
                      overAmount: overAmount,
                      baseDailyLimit: originalBaseLimit,
                      freeBudgetRemaining: freeBudgetRemaining,
                      fastRecoveryTotalDays: fastRecoveryTotalDays,
                      fastRecoveryDaysRemaining: fastRecoveryDaysRemaining,
                      fastRecoveryDailyLimit: fastRecoveryLimit,
                      amortizedDailyDeduction: amortizedDeduction,
                    ),
                  ),
                ),

                // ===============================================================
                // [KHỐI 4]: HÀNG THỐNG KÊ PHỤ 3 CỘT (SUB-METRICS VỚI TUMBLER ĐỒNG BỘ)
                // ===============================================================
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  sliver: SliverToBoxAdapter(
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Cột 1: Thu Nhập
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isIncomeVisible = !_isIncomeVisible;
                                });
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTokens.darkCard : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: AppTokens.income.withValues(alpha: 0.13),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.arrow_upward_rounded,
                                            color: AppTokens.income,
                                            size: 14,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          _isIncomeVisible
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          size: 14,
                                          color: _isIncomeVisible
                                              ? AppTokens.income
                                              : (isDark ? Colors.white30 : Colors.black26),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Thu nhập',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.22,
                                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: PreservedBalanceTumbler(
                                        isVisible: _isIncomeVisible,
                                        realValue: '+${_formatCurrency(totalIncome)}',
                                        maskedValue: '+•••••• ₫',
                                        height: 20,
                                        alignment: Alignment.centerLeft,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'monospace',
                                          letterSpacing: -0.3,
                                          color: AppTokens.income,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Cột 2: Đã Chi
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isExpenseVisible = !_isExpenseVisible;
                                });
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTokens.darkCard : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: AppTokens.expense.withValues(alpha: 0.13),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.arrow_downward_rounded,
                                            color: AppTokens.expense,
                                            size: 14,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          _isExpenseVisible
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          size: 14,
                                          color: _isExpenseVisible
                                              ? AppTokens.expense
                                              : (isDark ? Colors.white30 : Colors.black26),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Đã chi',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.22,
                                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: PreservedBalanceTumbler(
                                        isVisible: _isExpenseVisible,
                                        realValue: '-${_formatCurrency(totalExpense)}',
                                        maskedValue: '-•••••• ₫',
                                        height: 20,
                                        alignment: Alignment.centerLeft,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'monospace',
                                          letterSpacing: -0.3,
                                          color: AppTokens.expense,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Cột 3: Tốc độ tiêu dùng (Burn-Rate) - TÁCH ĐỀU 2 BÊN VỚI TUMBLER ĐỒNG BỘ
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isSpeedVisible = !_isSpeedVisible;
                                });
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTokens.darkCard : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: (isOverspending ? AppTokens.expense : accent.primary)
                                                .withValues(alpha: 0.13),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.bolt_rounded,
                                            color: isOverspending ? AppTokens.expense : accent.primary,
                                            size: 14,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(
                                          _isSpeedVisible
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          size: 14,
                                          color: _isSpeedVisible
                                              ? (isOverspending ? AppTokens.expense : accent.primary)
                                              : (isDark ? Colors.white30 : Colors.black26),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tốc độ tiêu',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.22,
                                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: PreservedBalanceTumbler(
                                        isVisible: _isSpeedVisible,
                                        realValue: '${(budgetConsumedPct * 100).toStringAsFixed(0)}%',
                                        maskedValue: '•••• %',
                                        height: 20,
                                        alignment: Alignment.centerLeft,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'monospace',
                                          letterSpacing: -0.3,
                                          color: isOverspending
                                              ? AppTokens.expense
                                              : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ===============================================================
                // [KHỐI 5]: THẺ XU HƯỚNG CHI TIÊU (SPENDING TREND CHART)
                // ===============================================================
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTokens.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                        ),
                      ),
                      child: const SpendingTrendChart(),
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
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(bottomNavIndexProvider.notifier).state = 1;
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                                Icon(Icons.chevron_right_rounded, size: 16, color: accent.primary),
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
                          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 44,
                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Chưa có giao dịch nào được ghi chép',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
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
                            final isExpense = tx.type == CategoryType.expense;
                            final wallet = walletsMap[tx.walletId];
                            final category = categoriesMap[tx.categoryId];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _openQuickEntrySheet(context, tx: tx, dailySafe: effectiveDailyLimit),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTokens.darkCard : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
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
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      tx.note ??
                                                          tx.merchant ??
                                                          category?.name ??
                                                          'Giao dịch',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: isDark
                                                            ? AppTokens.darkText
                                                            : AppTokens.lightText,
                                                      ),
                                                    ),
                                                  ),
                                                  if (tx.isAiParsed == true) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1.5,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: accent.primary.withValues(alpha: 0.16),
                                                        borderRadius: BorderRadius.circular(5),
                                                      ),
                                                      child: Text(
                                                        'AI',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w900,
                                                          color: accent.primary,
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
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark
                                                      ? AppTokens.darkMuted
                                                      : AppTokens.lightMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${isExpense ? '-' : '+'}${_formatCurrency(tx.amount)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: 'monospace',
                                            color: isExpense ? AppTokens.expense : AppTokens.income,
                                          ),
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
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
    );
  }
}
