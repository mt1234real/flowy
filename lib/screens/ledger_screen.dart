// ==============================================================================
// File: lib/screens/ledger_screen.dart
// Architecture: Universal Fluid Sheet Engine Integration, Sliding Pill Milestone Physics & Vault Isolation
// Stack: flutter_riverpod, drift, intl, dart:async, dart:math
// Version: Flowy v1.0.0-beta
// Features: Clean & Zen Ledger Principle (100% Vault Transactions Filtered Out),
//           Dual-Mode Period Viewing (Calendar vs Adaptive Cycle),
//           Multi-Dimensional Filter Matrix & Diacritics-Insensitive Search,
//           Smooth Metric Morphing & Reversible Soft-Delete Engine
// ==============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../services/fiscal_day.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_canvas.dart';
import '../widgets/category_icon_badge.dart';
import '../widgets/currency_text.dart';
import '../widgets/preserved_sleek_dismissible.dart';
import '../widgets/quick_entry_sheet.dart';
import '../widgets/sliding_segmented_bar.dart';
import '../widgets/two_stage_overscroll_header.dart';

// ==============================================================================
// 🌟 1. BẢNG TOKEN CHUYỂN ĐỘNG TẬP TRUNG (LEDGER MOTION TOKENS)
// ==============================================================================

abstract final class LedgerMotion {
  static const searchExpand = Duration(milliseconds: 200);
  static const searchCollapse = Duration(milliseconds: 180);
  static const searchOpacity = Duration(milliseconds: 140);
  static const control = Duration(milliseconds: 160);
  static const colorMorph = Duration(milliseconds: 180);

  static const pillSlide = Duration(milliseconds: 190);
  static const pillApproachFraction = 150.0 / 190.0;
  static const double modePillOvershoot = 2.5;
  static const double filterPillOvershoot = 1.25;

  static const periodShift = Duration(milliseconds: 180);
  static const periodHalfShift = Duration(milliseconds: 90);
  static const summary = Duration(milliseconds: 180);

  static const chipIn = Duration(milliseconds: 150);
  static const chipOut = Duration(milliseconds: 120);

  static const dismiss = Duration(milliseconds: 200);
  static const emptyState = Duration(milliseconds: 200);

  static const sheetIn = Duration(milliseconds: 300);
  static const sheetOut = Duration(milliseconds: 250);

  static const controlCurve = Curves.easeOutQuad;
  static const spatialCurve = Curves.easeOutCubic;
  static const resizeCurve = Curves.easeInOutCubic;
}

// ==============================================================================
// 🌟 CHU KỲ, PROVIDER TRẠNG THÁI & HỖ TRỢ DỮ LIỆU SỔ GIAO DỊCH
// ==============================================================================

enum CycleMode { calendar, customCycle }

final cycleModeProvider = StateProvider<CycleMode>((ref) => CycleMode.customCycle);

final currentAnchorMonthProvider = StateProvider<DateTime>((ref) {
  final now = ref.read(dayCutoffProvider).date(DateTime.now());
  return DateTime(now.year, now.month, 1);
});

final cycleStartDaysByMonthProvider = StateProvider<Map<String, int>>((ref) {
  final saved = ref.read(sharedPreferencesProvider).getString('notification_cycle_snapshot');
  if (saved != null) {
    try { return Map<String, int>.from(jsonDecode(saved) as Map); } catch (_) {}
  }
  return {'default': (ref.read(sharedPreferencesProvider).getInt('flowy_cycle_start_day') ?? 10).clamp(1, 31)};
});

class MonthCycleRange {
  final DateTime startDate;
  final DateTime endDate;
  final String label;
  final String subRange;
  final int daysCount;
  final int startDay;

  MonthCycleRange({
    required this.startDate,
    required this.endDate,
    required this.label,
    required this.subRange,
    required this.daysCount,
    required this.startDay,
  });
}

int resolveStartDayForMonth(DateTime targetMonth, Map<String, int> store) {
  final key = DateFormat('yyyy-MM').format(targetMonth);
  if (store.containsKey(key)) return store[key]!;
  for (int i = 1; i <= 12; i++) {
    final prevMonth = DateTime(targetMonth.year, targetMonth.month - i, 1);
    final prevKey = DateFormat('yyyy-MM').format(prevMonth);
    if (store.containsKey(prevKey)) return store[prevKey]!;
  }
  return store['default'] ?? 10;
}

MonthCycleRange computeMonthCycleRange(DateTime anchorMonth, Map<String, int> store) {
  final startDay = resolveStartDayForMonth(anchorMonth, store);
  final daysInCurMonth = DateTime(anchorMonth.year, anchorMonth.month + 1, 0).day;
  final safeStartDay = startDay.clamp(1, daysInCurMonth);
  final startDate = DateTime(anchorMonth.year, anchorMonth.month, safeStartDay, 0, 0, 0);

  final nextMonth = DateTime(anchorMonth.year, anchorMonth.month + 1, 1);
  final nextStartDay = resolveStartDayForMonth(nextMonth, store);
  final daysInNextMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
  final safeNextStartDay = nextStartDay.clamp(1, daysInNextMonth);

  final nextCycleStartDate = DateTime(nextMonth.year, nextMonth.month, safeNextStartDay, 0, 0, 0);
  final endDate = nextCycleStartDate.subtract(const Duration(seconds: 1));
  final daysCount = endDate.difference(startDate).inDays + 1;
  final label = 'Chu kỳ Tháng ${DateFormat('MM/yyyy').format(anchorMonth)}';
  final subRange =
      '${DateFormat('dd/MM').format(startDate)} – ${DateFormat('dd/MM').format(endDate)} ($daysCount ngày)';

  return MonthCycleRange(
    startDate: startDate,
    endDate: endDate,
    label: label,
    subRange: subRange,
    daysCount: daysCount,
    startDay: safeStartDay,
  );
}

enum LedgerFilter { all, expense, income, debt }

final ledgerFilterProvider = StateProvider<LedgerFilter>((ref) => LedgerFilter.all);

class LedgerFilterCriteria {
  final String? walletId;
  final Set<String> categoryIds;
  final double? minAmount;
  final double? maxAmount;
  final DateTimeRange? customDateRange;

  const LedgerFilterCriteria({
    this.walletId,
    this.categoryIds = const {},
    this.minAmount,
    this.maxAmount,
    this.customDateRange,
  });

  bool get isActive =>
      walletId != null ||
          categoryIds.isNotEmpty ||
          minAmount != null ||
          maxAmount != null ||
          customDateRange != null;

  LedgerFilterCriteria copyWith({
    String? Function()? walletId,
    Set<String>? categoryIds,
    double? Function()? minAmount,
    double? Function()? maxAmount,
    DateTimeRange? Function()? customDateRange,
  }) {
    return LedgerFilterCriteria(
      walletId: walletId != null ? walletId() : this.walletId,
      categoryIds: categoryIds ?? this.categoryIds,
      minAmount: minAmount != null ? minAmount() : this.minAmount,
      maxAmount: maxAmount != null ? maxAmount() : this.maxAmount,
      customDateRange: customDateRange != null ? customDateRange() : this.customDateRange,
    );
  }
}

final ledgerFilterCriteriaProvider =
StateProvider<LedgerFilterCriteria>((ref) => const LedgerFilterCriteria());

final ledgerSearchQueryProvider = StateProvider<String>((ref) => '');

String removeDiacritics(String str) {
  var result = str.toLowerCase();
  result = result.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
  result = result.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
  result = result.replaceAll(RegExp(r'[ìíỉĩ]'), 'i');
  result = result.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
  result = result.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
  result = result.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
  result = result.replaceAll(RegExp(r'[đ]'), 'd');
  return result;
}

class UnifiedLedgerItem {
  final String id;
  final DateTime date;
  final double amount;
  final bool isMoneyIn;
  final String title;
  final String subtitle;
  final String? note;
  final String? merchant;
  final String? categoryName;
  final String? categoryId;
  final String? walletId;
  final DateTime? dueDate;
  final Transaction? standardTx;
  final DebtTransaction? debtTx;
  final String? debtType;

  const UnifiedLedgerItem({
    required this.id,
    required this.date,
    required this.amount,
    required this.isMoneyIn,
    required this.title,
    required this.subtitle,
    this.note,
    this.merchant,
    this.categoryName,
    this.categoryId,
    this.walletId,
    this.dueDate,
    this.standardTx,
    this.debtTx,
    this.debtType,
  });

  bool get isDebt => debtTx != null;
}

class LedgerSummary {
  final double moneyIn;
  final double moneyOut;

  const LedgerSummary({required this.moneyIn, required this.moneyOut});

  double get net => moneyIn - moneyOut;
}

// Items are the active, filtered history; transfers only cross a single-wallet
// scope. In the all-wallet scope both sides are internal and contribute zero.
LedgerSummary computeLedgerSummary(
  Iterable<UnifiedLedgerItem> items, {
  String? walletId,
}) {
  var moneyIn = 0.0;
  var moneyOut = 0.0;
  for (final item in items) {
    final tx = item.standardTx;
    if (tx != null && tx.type == CategoryType.transfer) {
      if (walletId == null) {
        continue;
      }
      final sourceInScope = tx.walletId == walletId;
      final destinationInScope = tx.toWalletId == walletId;
      if (sourceInScope == destinationInScope) {
        continue;
      }
      if (destinationInScope) {
        moneyIn += item.amount;
      } else {
        moneyOut += item.amount;
      }
    } else if (item.isMoneyIn) {
      moneyIn += item.amount;
    } else {
      moneyOut += item.amount;
    }
  }
  return LedgerSummary(moneyIn: moneyIn, moneyOut: moneyOut);
}

final unifiedLedgerStreamProvider = StreamProvider.autoDispose<List<UnifiedLedgerItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final mode = ref.watch(cycleModeProvider);
  final tabFilter = ref.watch(ledgerFilterProvider);
  final anchor = ref.watch(currentAnchorMonthProvider);
  final criteria = ref.watch(ledgerFilterCriteriaProvider);
  final searchQuery = ref.watch(ledgerSearchQueryProvider).trim();
  final boundary = ref.watch(dayCutoffProvider);

  DateTime queryStart;
  DateTime queryEnd;

  if (criteria.customDateRange != null) {
    queryStart = DateTime(
      criteria.customDateRange!.start.year,
      criteria.customDateRange!.start.month,
      criteria.customDateRange!.start.day,
      0,
      0,
      0,
    );
    queryEnd = DateTime(
      criteria.customDateRange!.end.year,
      criteria.customDateRange!.end.month,
      criteria.customDateRange!.end.day,
      23,
      59,
      59,
    );
  } else if (mode == CycleMode.calendar) {
    queryStart = DateTime(anchor.year, anchor.month, 1, 0, 0, 0);
    queryEnd = DateTime(anchor.year, anchor.month + 1, 1, 0, 0, 0).subtract(const Duration(seconds: 1));
  } else {
    final store = ref.watch(cycleStartDaysByMonthProvider);
    final range = computeMonthCycleRange(anchor, store);
    queryStart = range.startDate;
    queryEnd = range.endDate;
  }

  queryStart = boundary.start(queryStart);
  queryEnd = boundary.end(queryEnd);

  // 🌟 CLEAN & ZEN LEDGER: Loại trừ 100% dòng tiền nạp/rút Két Tiết Kiệm (goalId != null hoặc envelopeType == 'savings')
  final standardTxStream = (db.select(db.transactions)
    ..where((t) =>
    t.deletedAt.isNull() &
    t.goalId.isNull() &
    (t.envelopeType.equals('savings').not() | t.envelopeType.isNull()) &
    t.date.isBiggerOrEqualValue(queryStart) &
    t.date.isSmallerThanValue(queryEnd)))
      .watch();

  final debtTxStream = (db.select(db.debtTransactions)
    ..where((d) =>
    d.deletedAt.isNull() &
    d.date.isBiggerOrEqualValue(queryStart) &
    d.date.isSmallerThanValue(queryEnd)))
      .watch();

  final walletsStream = db.select(db.wallets).watch();
  final categoriesStream = db.select(db.categories).watch();
  final contactsStream = db.select(db.debtContacts).watch();

  final controller = StreamController<List<UnifiedLedgerItem>>();

  List<Transaction> latestStandardTxs = [];
  List<DebtTransaction> latestDebtTxs = [];
  List<Wallet> latestWallets = [];
  List<Category> latestCategories = [];
  List<DebtContact> latestContacts = [];
  bool hasEmittedInitial = false;

  void recomputeAndEmit() {
    final Map<String, Wallet> walletsMap = {for (final w in latestWallets) w.id: w};
    final Map<String, Category> categoriesMap = {for (final c in latestCategories) c.id: c};
    final Map<String, DebtContact> contactsMap = {for (final c in latestContacts) c.id: c};
    final List<UnifiedLedgerItem> items = [];

    if (tabFilter != LedgerFilter.debt) {
      for (final tx in latestStandardTxs) {
        if (tx.deletedAt != null) continue;
        // Kiểm tra an toàn thêm một lớp nữa đối với giao dịch Két
        if (tx.goalId != null || tx.envelopeType == 'savings') continue;
        if (tabFilter == LedgerFilter.expense && tx.type != CategoryType.expense) continue;
        if (tabFilter == LedgerFilter.income && tx.type != CategoryType.income) continue;
        if (criteria.walletId != null &&
            tx.walletId != criteria.walletId &&
            !(tx.type == CategoryType.transfer &&
                tx.toWalletId == criteria.walletId)) {
          continue;
        }
        if (criteria.categoryIds.isNotEmpty && !criteria.categoryIds.contains(tx.categoryId)) continue;
        if (criteria.minAmount != null && tx.amount < criteria.minAmount!) continue;
        if (criteria.maxAmount != null && tx.amount > criteria.maxAmount!) continue;

        final isIncome = tx.type == CategoryType.income ||
            (tx.type == CategoryType.transfer &&
                criteria.walletId != null &&
                tx.toWalletId == criteria.walletId);
        final wallet = walletsMap[criteria.walletId ?? tx.walletId];
        final category = categoriesMap[tx.categoryId];
        final categoryName = category?.name ?? 'Chung';
        final title = tx.note ?? tx.merchant ?? categoryName;

        if (searchQuery.isNotEmpty) {
          final normalizedQuery = removeDiacritics(searchQuery);
          final matchNote = tx.note != null && removeDiacritics(tx.note!).contains(normalizedQuery);
          final matchMerchant = tx.merchant != null && removeDiacritics(tx.merchant!).contains(normalizedQuery);
          final matchCategory = removeDiacritics(categoryName).contains(normalizedQuery);
          final matchTitle = removeDiacritics(title).contains(normalizedQuery);
          if (!matchNote && !matchMerchant && !matchCategory && !matchTitle) continue;
        }

        items.add(
          UnifiedLedgerItem(
            id: tx.id,
            date: tx.date,
            amount: tx.amount,
            isMoneyIn: isIncome,
            title: title,
            subtitle: '${DateFormat('HH:mm').format(tx.date)} • ${wallet?.name ?? 'Ví'} • $categoryName',
            note: tx.note,
            merchant: tx.merchant,
            categoryName: categoryName,
            categoryId: tx.categoryId,
            walletId: tx.walletId,
            standardTx: tx,
          ),
        );
      }
    }

    if (tabFilter == LedgerFilter.all || tabFilter == LedgerFilter.debt) {
      for (final d in latestDebtTxs) {
        if (d.deletedAt != null) continue;
        if (criteria.walletId != null && d.walletId != criteria.walletId) continue;
        if (criteria.minAmount != null && d.amount < criteria.minAmount!) continue;
        if (criteria.maxAmount != null && d.amount > criteria.maxAmount!) continue;
        if (criteria.categoryIds.isNotEmpty) continue;

        final contact = contactsMap[d.contactId];
        final wallet = walletsMap[d.walletId];
        final contactName = contact?.name ?? 'Đối tác';
        String title = '';
        bool isMoneyIn = false;

        switch (d.type) {
          case 'LEND':
            title = 'Cho $contactName vay';
            isMoneyIn = false;
            break;
          case 'COLLECT':
            title = '$contactName trả nợ';
            isMoneyIn = true;
            break;
          case 'BORROW':
            title = 'Vay từ $contactName';
            isMoneyIn = true;
            break;
          case 'REPAY':
            title = 'Trả nợ cho $contactName';
            isMoneyIn = false;
            break;
          default:
            title = 'Giao dịch nợ với $contactName';
            isMoneyIn = false;
        }

        if (searchQuery.isNotEmpty) {
          final normalizedQuery = removeDiacritics(searchQuery);
          final matchTitle = removeDiacritics(title).contains(normalizedQuery);
          final matchNote = d.note != null && removeDiacritics(d.note!).contains(normalizedQuery);
          final matchContact = removeDiacritics(contactName).contains(normalizedQuery);
          if (!matchTitle && !matchNote && !matchContact) continue;
        }

        items.add(
          UnifiedLedgerItem(
            id: d.id,
            date: d.date,
            amount: d.amount,
            isMoneyIn: isMoneyIn,
            title: title,
            subtitle: '${DateFormat('HH:mm').format(d.date)} • ${wallet?.name ?? 'Ví'}',
            note: d.note,
            walletId: d.walletId,
            dueDate: d.dueDate,
            debtTx: d,
            debtType: d.type,
          ),
        );
      }
    }

    items.sort((a, b) => b.date.compareTo(a.date));

    if (!controller.isClosed) {
      controller.add(items);
      hasEmittedInitial = true;
    }
  }

  final sub1 = standardTxStream.listen((data) {
    latestStandardTxs = data;
    recomputeAndEmit();
  });
  final sub2 = debtTxStream.listen((data) {
    latestDebtTxs = data;
    recomputeAndEmit();
  });
  final sub3 = walletsStream.listen((data) {
    latestWallets = data;
    if (hasEmittedInitial) recomputeAndEmit();
  });
  final sub4 = categoriesStream.listen((data) {
    latestCategories = data;
    if (hasEmittedInitial) recomputeAndEmit();
  });
  final sub5 = contactsStream.listen((data) {
    latestContacts = data;
    if (hasEmittedInitial) recomputeAndEmit();
  });

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    sub3.cancel();
    sub4.cancel();
    sub5.cancel();
    controller.close();
  });

  return controller.stream;
});

final ledgerWalletsStreamProvider = StreamProvider.autoDispose<List<Wallet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.wallets).watch();
});

final ledgerCategoriesStreamProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

// ==============================================================================
// 🌟 2. WIDGET RIÊNG _PreservedMetricSwitcher (HỖ TRỢ animate GUARDRAIL)
// ==============================================================================

class _PreservedMetricSwitcher extends StatefulWidget {
  final String value;
  final TextStyle style;
  final bool animate;

  const _PreservedMetricSwitcher({
    required this.value,
    required this.style,
    this.animate = true,
  });

  @override
  State<_PreservedMetricSwitcher> createState() => _PreservedMetricSwitcherState();
}

class _PreservedMetricSwitcherState extends State<_PreservedMetricSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  String _currentValue = '';
  String? _previousValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _controller = AppAnimationPolicy.createController(
      vsync: this,
      duration: LedgerMotion.summary,
      debugLabel: 'PreservedMetricSwitcher',
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad);
  }

  @override
  void didUpdateWidget(covariant _PreservedMetricSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (!widget.animate) {
        _currentValue = widget.value;
        _previousValue = null;
        return;
      }

      _previousValue = oldWidget.value;
      _currentValue = widget.value;
      _controller.forward(from: 0.0).then((_) {
        if (mounted) setState(() => _previousValue = null);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_previousValue == null) {
      return CurrencyText(_currentValue, style: currencyTextStyle(context, widget.style));
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final progress = _animation.value;
        final oldOpacity = (1.0 - progress).clamp(0.0, 1.0);
        final oldScale = 1.0 - (0.04 * progress);
        final newOpacity = progress.clamp(0.0, 1.0);
        final newScale = 0.94 + (0.06 * progress);

        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            Opacity(
              opacity: oldOpacity,
              child: Transform.scale(
                scale: oldScale,
                alignment: Alignment.centerLeft,
                child: CurrencyText(_previousValue!, style: currencyTextStyle(context, widget.style)),
              ),
            ),
            Opacity(
              opacity: newOpacity,
              child: Transform.scale(
                scale: newScale,
                alignment: Alignment.centerLeft,
                child: CurrencyText(_currentValue, style: currencyTextStyle(context, widget.style)),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==============================================================================
// 🌟 MÀN HÌNH CHÍNH SỔ GIAO DỊCH (LEDGER SCREEN)
// ==============================================================================

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> with TickerProviderStateMixin {
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  final Set<String> _dismissingTxIds = {};
  final Set<String> _restoringTxIds = {};

  late final AnimationController _periodMotionController;
  late final Animation<double> _periodMotionAnimation;
  int _periodShiftDelta = 1;
  bool _isPeriodTransitioning = false;

  late final AnimationController _searchMotionController;
  late final Animation<double> _searchSizeAnimation;
  late final Animation<double> _searchOpacityAnimation;

  late final AnimationController _filterMotionController;
  late final Animation<double> _filterContentAnimation;
  bool _isFilterTransitioning = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _periodMotionController = AppAnimationPolicy.createController(
      vsync: this,
      duration: LedgerMotion.periodHalfShift,
      reverseDuration: LedgerMotion.periodHalfShift,
      debugLabel: 'Ledger.periodShift',
    );
    _periodMotionAnimation = CurvedAnimation(
      parent: _periodMotionController,
      curve: LedgerMotion.controlCurve,
    );

    _searchMotionController = AppAnimationPolicy.createController(
      vsync: this,
      duration: LedgerMotion.searchExpand,
      reverseDuration: LedgerMotion.searchCollapse,
      debugLabel: 'Ledger.search',
    );
    _searchSizeAnimation = CurvedAnimation(
      parent: _searchMotionController,
      curve: Curves.easeInOutCubic,
    );
    _searchOpacityAnimation = CurvedAnimation(
      parent: _searchMotionController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    );

    _filterMotionController = AppAnimationPolicy.createController(
      vsync: this,
      duration: LedgerMotion.periodHalfShift,
      reverseDuration: LedgerMotion.periodHalfShift,
      debugLabel: 'Ledger.filterTransition',
    );
    _filterContentAnimation = CurvedAnimation(
      parent: _filterMotionController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _periodMotionController.dispose();
    _searchMotionController.dispose();
    _filterMotionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(ledgerSearchQueryProvider.notifier).state = val;
      }
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    ref.read(ledgerSearchQueryProvider.notifier).state = '';
  }

  Future<void> _toggleSearch() async {
    HapticFeedback.selectionClick();
    final opening = !_isSearchExpanded;
    if (opening) {
      setState(() => _isSearchExpanded = true);
      await _searchMotionController.forward(from: 0.0);
      if (mounted) _searchFocusNode.requestFocus();
    } else {
      _searchFocusNode.unfocus();
      _clearSearch();
      await _searchMotionController.reverse(from: 1.0);
      if (mounted) setState(() => _isSearchExpanded = false);
    }
  }

  void _resetAllFilters() {
    HapticFeedback.selectionClick();
    _clearSearch();
    ref.read(ledgerFilterCriteriaProvider.notifier).state = const LedgerFilterCriteria();
    if (_isSearchExpanded) {
      _searchFocusNode.unfocus();
      _searchMotionController.reverse(from: 1.0).then((_) {
        if (mounted) setState(() => _isSearchExpanded = false);
      });
    }
  }

  String _formatCurrency(double amount, [String currency = '₫']) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: currency, decimalDigits: 0);
    return formatter.format(amount);
  }

  Map<String, List<UnifiedLedgerItem>> _groupItemsByDate(List<UnifiedLedgerItem> items) {
    final Map<String, List<UnifiedLedgerItem>> grouped = {};
    for (final item in items) {
      final dateStr = DateFormat('dd/MM/yyyy').format(ref.read(dayCutoffProvider).date(item.date));
      grouped.putIfAbsent(dateStr, () => []).add(item);
    }
    return grouped;
  }

  void _openEditTransactionSheet(BuildContext context, Transaction tx) {
    QuickEntrySheet.show(
      context,
      initialTransaction: tx,
    );
  }

  void _openDebtTransactionDetailSheet(BuildContext context, DebtTransaction tx) {
    QuickEntrySheet.show(context, initialDebtTransaction: tx);
  }

  void _openFilterMatrixModal(BuildContext context, bool isDark, AppAccentPreset accent) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.scrollable,
      useRootNavigator: true,
      isDismissible: true,
      builder: (sheetContext, scrollController) => _FilterMatrixModal(
        isDark: isDark,
        accent: accent,
        scrollController: scrollController,
      ),
    );
  }

  Future<void> _openEditMilestoneModal(
      BuildContext context,
      DateTime anchorMonth,
      bool isDark,
      AppAccentPreset accent,
      ) async {
    HapticFeedback.selectionClick();

    final wheelInteraction = ValueNotifier<bool>(false);

    try {
      await AppAnimationPolicy.showFluidSheet(
        context: context,
        mode: FluidSheetMode.fixed,
        useRootNavigator: true,
        isDismissible: true,
        canDismiss: () => !wheelInteraction.value,
        builder: (sheetContext, _) => _EditCycleMilestoneModal(
          anchorMonth: anchorMonth,
          isDark: isDark,
          accent: accent,
          onWheelInteractionChanged: (isInteracting) {
            wheelInteraction.value = isInteracting;
          },
        ),
      );
    } finally {
      wheelInteraction.dispose();
    }
  }

  void _openMonthYearPickerModal(BuildContext context, bool isDark, AppAccentPreset accent) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.fixed,
      useRootNavigator: true,
      isDismissible: true,
      duration: LedgerMotion.sheetIn,
      enableBlur: false,
      builder: (sheetContext, _) => _MonthYearPickerModal(
        isDark: isDark,
        accent: accent,
      ),
    );
  }

  Future<void> _shiftMonthAnimated(int delta) async {
    if (_isPeriodTransitioning) return;
    _isPeriodTransitioning = true;
    HapticFeedback.selectionClick();
    _periodShiftDelta = delta;

    try {
      await _periodMotionController.forward(from: 0.0);
      if (!mounted) return;

      final cur = ref.read(currentAnchorMonthProvider);
      ref.read(currentAnchorMonthProvider.notifier).state = DateTime(cur.year, cur.month + delta, 1);

      await ref.read(unifiedLedgerStreamProvider.future).catchError((_) => <UnifiedLedgerItem>[]);
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;

      await _periodMotionController.reverse(from: 1.0);
    } finally {
      if (mounted) setState(() => _isPeriodTransitioning = false);
    }
  }

  Future<void> _switchLedgerFilter(LedgerFilter target) async {
    final current = ref.read(ledgerFilterProvider);
    if (target == current || _isFilterTransitioning) return;
    _isFilterTransitioning = true;

    try {
      await _filterMotionController.forward(from: 0.0);
      if (!mounted) return;

      ref.read(ledgerFilterProvider.notifier).state = target;

      await ref.read(unifiedLedgerStreamProvider.future).catchError((_) => <UnifiedLedgerItem>[]);
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;

      await _filterMotionController.reverse(from: 1.0);
    } finally {
      if (mounted) setState(() => _isFilterTransitioning = false);
    }
  }

  Future<void> _handleLedgerRefresh() async {
    HapticFeedback.lightImpact();
    ref.invalidate(unifiedLedgerStreamProvider);
    ref.invalidate(ledgerWalletsStreamProvider);
    ref.invalidate(ledgerCategoriesStreamProvider);
    await Future.delayed(const Duration(milliseconds: 400));
  }

  Future<void> _commitDismissedTransaction(
      UnifiedLedgerItem item,
      AppDatabase db,
      AppAccentPreset accent,
      ) async {
    if (mounted) {
      setState(() => _dismissingTxIds.add(item.id));
    }

    try {
      if (item.isDebt) {
        await db.softDeleteDebtTransaction(item.id);
      } else {
        await db.softDeleteTransaction(item.standardTx!.id);
      }

      ref.invalidate(unifiedLedgerStreamProvider);
      if (!mounted) return;

      AppFeedback.showUndo(
        context,
        message: item.isDebt
            ? 'Đã chuyển khoản nợ vào Thùng rác: ${item.title}'
            : 'Đã chuyển vào Thùng rác: ${item.title}',
        actionColor: accent.primary,
        onUndo: () async {
          if (mounted) {
            setState(() => _restoringTxIds.add(item.id));
          }

          if (item.isDebt) {
            await db.restoreDebtTransaction(item.id);
          } else {
            await db.restoreTransaction(item.standardTx!.id);
          }

          _dismissingTxIds.remove(item.id);
          ref.invalidate(unifiedLedgerStreamProvider);

          if (mounted) {
            setState(() {});
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _dismissingTxIds.remove(item.id));
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final db = ref.watch(databaseProvider);

    final currentMode = ref.watch(cycleModeProvider);
    final currentTabFilter = ref.watch(ledgerFilterProvider);
    final anchorMonth = ref.watch(currentAnchorMonthProvider);
    final cycleStore = ref.watch(cycleStartDaysByMonthProvider);
    final criteria = ref.watch(ledgerFilterCriteriaProvider);
    final searchQuery = ref.watch(ledgerSearchQueryProvider);

    final ledgerItemsAsync = ref.watch(unifiedLedgerStreamProvider);
    final categoriesAsync = ref.watch(ledgerCategoriesStreamProvider);
    final walletsAsync = ref.watch(ledgerWalletsStreamProvider);

    final Map<String, Category> categoriesMap = {
      for (final c in categoriesAsync.valueOrNull ?? <Category>[]) c.id: c
    };
    final Map<String, Wallet> walletsMap = {
      for (final w in walletsAsync.valueOrNull ?? <Wallet>[]) w.id: w
    };

    final bool hasActiveFilters = criteria.isActive || searchQuery.isNotEmpty;

    return AppFeedbackDismissRegion(
      child: AmbientCanvas(child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: TwoStageOverscrollHeader(
            onRefresh: _handleLedgerRefresh,
            glowColor: accent.primary,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nhật ký thu chi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                  ),
                                ),
                                Text(
                                  'Sổ Giao Dịch',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: _toggleSearch,
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: LedgerMotion.control,
                                    curve: LedgerMotion.controlCurve,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _isSearchExpanded
                                          ? accent.primary.withValues(alpha: 0.15)
                                          : (isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _isSearchExpanded
                                            ? accent.primary.withValues(alpha: 0.4)
                                            : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.search_rounded,
                                      size: 18,
                                      color: _isSearchExpanded
                                          ? accent.primary
                                          : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _openFilterMatrixModal(context, isDark, accent),
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: LedgerMotion.colorMorph,
                                    curve: LedgerMotion.controlCurve,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: criteria.isActive
                                          ? accent.primary
                                          : (isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: criteria.isActive
                                            ? accent.primary
                                            : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.filter_alt_outlined,
                                          size: 16,
                                          color: criteria.isActive
                                              ? Colors.white
                                              : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Lọc',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: criteria.isActive
                                                ? Colors.white
                                                : (isDark ? AppTokens.darkText : AppTokens.lightText),
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
                      ClipRect(
                        child: AnimatedBuilder(
                          animation: _searchMotionController,
                          builder: (context, child) {
                            final heightFactor = _searchSizeAnimation.value;
                            final opacity = _searchOpacityAnimation.value;
                            if (heightFactor <= 0.001) return const SizedBox.shrink();

                            return Align(
                              alignment: Alignment.topCenter,
                              heightFactor: heightFactor,
                              child: Opacity(
                                opacity: opacity,
                                child: IgnorePointer(
                                  ignoring: heightFactor < 0.95,
                                  child: child,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppTokens.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: accent.primary.withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.primary.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: _onSearchChanged,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Tìm theo ghi chú, tên quán, danh mục...',
                                  hintStyle: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: accent.primary),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: _clearSearch,
                                  )
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // CỤM 1: CHẾ ĐỘ XEM (CYCLE MODE 2 TABS)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: SlidingSegmentedBar<CycleMode>(
                          height: 38,
                          fontSize: 11,
                          debugLabel: 'Ledger.modeSlidingPill',
                          duration: LedgerMotion.pillSlide,
                          overshootPx: LedgerMotion.modePillOvershoot,
                          selectedValue: currentMode,
                          trackColor: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                          trackBorderColor: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                          indicatorColor: isDark ? AppTokens.darkCardSubtle : Colors.white,
                          indicatorBorderColor: Colors.transparent,
                          selectedTextColor: isDark ? AppTokens.darkText : AppTokens.lightText,
                          mutedTextColor: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                          indicatorShadowColor: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
                          items: const [
                            SlidingSegmentedItem<CycleMode>(
                              value: CycleMode.calendar,
                              label: 'Theo Tháng',
                              icon: Icons.calendar_month_rounded,
                            ),
                            SlidingSegmentedItem<CycleMode>(
                              value: CycleMode.customCycle,
                              label: 'Theo Chu Kỳ',
                              icon: Icons.autorenew_rounded,
                            ),
                          ],
                          onValueChanged: (value) {
                            ref.read(cycleModeProvider.notifier).state = value;
                          },
                        ),
                      ),

                      // Adaptive Period Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
                        child: _buildAdaptivePeriodBar(
                          context,
                          currentMode,
                          anchorMonth,
                          cycleStore,
                          isDark,
                          accent,
                        ),
                      ),
                    ],
                  ),
                ),

                // CỤM 2: PHÂN ĐOẠN THU CHI (LEDGER FILTER 4 TABS)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  sliver: SliverToBoxAdapter(
                    child: SlidingSegmentedBar<LedgerFilter>(
                      height: 40,
                      fontSize: 11,
                      debugLabel: 'Ledger.filterSlidingPill',
                      duration: LedgerMotion.pillSlide,
                      overshootPx: LedgerMotion.filterPillOvershoot,
                      selectedValue: currentTabFilter,
                      trackColor: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                      trackBorderColor: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                      indicatorColor: isDark ? AppTokens.darkCardSubtle : Colors.white,
                      indicatorBorderColor: Colors.transparent,
                      selectedTextColor: isDark ? AppTokens.darkText : AppTokens.lightText,
                      mutedTextColor: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      indicatorShadowColor: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
                      items: const [
                        SlidingSegmentedItem<LedgerFilter>(value: LedgerFilter.all, label: 'Tất cả'),
                        SlidingSegmentedItem<LedgerFilter>(value: LedgerFilter.expense, label: 'Khoản chi'),
                        SlidingSegmentedItem<LedgerFilter>(value: LedgerFilter.income, label: 'Khoản thu'),
                        SlidingSegmentedItem<LedgerFilter>(value: LedgerFilter.debt, label: 'Vay / Nợ'),
                      ],
                      onValueChanged: (value) {
                        unawaited(_switchLedgerFilter(value));
                      },
                    ),
                  ),
                ),

                // Active Filter Chips Bar
                if (hasActiveFilters)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    sliver: SliverToBoxAdapter(
                      child: _AnimatedFilterChipStrip(
                        criteria: criteria,
                        searchQuery: searchQuery,
                        walletsMap: walletsMap,
                        categoriesMap: categoriesMap,
                        accent: accent,
                        isDark: isDark,
                        onClearSearch: _clearSearch,
                        onResetAll: _resetAllFilters,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 4)),

                // DỮ LIỆU SỔ & DANH SÁCH GIAO DỊCH
                ledgerItemsAsync.when(
                  data: (rawItems) {
                    final visibleItems = rawItems
                        .where((item) => !_dismissingTxIds.contains(item.id))
                        .toList();

                    return SliverToBoxAdapter(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_periodMotionAnimation, _filterContentAnimation]),
                        builder: (context, child) {
                          final periodProgress = _periodMotionAnimation.value;
                          final filterProgress = _filterContentAnimation.value;
                          final offsetX = periodProgress * 16.0 * (_periodShiftDelta > 0 ? -1 : 1);
                          final offsetY = filterProgress * 12.0;
                          final opacity = ((1.0 - periodProgress) * (1.0 - filterProgress)).clamp(0.0, 1.0);

                          return Transform.translate(
                            offset: Offset(offsetX, offsetY),
                            child: Opacity(opacity: opacity, child: child),
                          );
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              child: _buildSummaryCard(visibleItems, isDark,
                                  walletId: criteria.walletId),
                            ),
                            const SizedBox(height: 6),
                            visibleItems.isEmpty
                                ? _buildSmartEmptyState(
                              isDark: isDark,
                              accent: accent,
                              hasActiveFilters: hasActiveFilters,
                              searchQuery: searchQuery,
                            )
                                : _buildGroupedListView(
                              visibleItems,
                              categoriesMap,
                              db,
                              isDark,
                              accent,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
                  error: (err, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Lỗi tải dữ liệu sổ: $err', style: const TextStyle(color: AppTokens.expense)),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          ),
        ),
      )),
    );
  }

  // ===========================================================================
  // SUB-WIDGETS & UI COMPONENTS
  // ===========================================================================

  Widget _buildSmartEmptyState({
    required bool isDark,
    required AppAccentPreset accent,
    required bool hasActiveFilters,
    required String searchQuery,
  }) {
    if (hasActiveFilters) {
      return Padding(
        key: const ValueKey('smart_empty_filter_state'),
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 36,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Không tìm thấy giao dịch',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                searchQuery.isNotEmpty
                    ? 'Không có mục nào khớp với từ khóa "$searchQuery" và bộ lọc đang chọn.'
                    : 'Không có giao dịch nào thỏa mãn tiêu chí bộ lọc của bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Xóa bộ lọc & Thử lại', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent.primary,
                  side: BorderSide(color: accent.primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _resetAllFilters,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      key: const ValueKey('ledger_empty_state'),
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
            const SizedBox(height: 10),
            Text(
              'Chưa có giao dịch nào\nChạm nút (+) bên dưới để ghi giao dịch',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedListView(
      List<UnifiedLedgerItem> items,
      Map<String, Category> categoriesMap,
      AppDatabase db,
      bool isDark,
      AppAccentPreset accent,
      ) {
    final groupedMap = _groupItemsByDate(items);
    final today = ref.watch(fiscalTodayProvider);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final dateKeys = groupedMap.keys.toList();
    final walletId = ref.watch(ledgerFilterCriteriaProvider).walletId;

    return Padding(
      key: const ValueKey('ledger_list_content'),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: dateKeys.length,
        itemBuilder: (context, index) {
          final dateStr = dateKeys[index];
          final dayItems = groupedMap[dateStr]!;
          final netDaily =
              computeLedgerSummary(dayItems, walletId: walletId).net;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Row(
                      children: [
                        Flexible(child: Text(
                          dateStr == DateFormat('dd/MM/yyyy').format(today)
                              ? 'Hôm nay ($dateStr)'
                              : dateStr == DateFormat('dd/MM/yyyy').format(yesterday)
                              ? 'Hôm qua ($dateStr)' : dateStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                          ),
                        )),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${dayItems.length}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                          ),
                        ),
                      ],
                    )),
                    const SizedBox(width: 8),
                    Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: CurrencyText(
                      '${netDaily >= 0 ? '+' : ''}${_formatCurrency(netDaily)}',
                      style: currencyTextStyle(context, TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: netDaily >= 0 ? AppTokens.income : AppTokens.expense,
                      )),
                    ))),
                  ],
                ),
              ),
              ...dayItems.map((item) {
                return _buildUnifiedItemCard(context, item, categoriesMap, db, isDark, accent);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnifiedItemCard(
      BuildContext context,
      UnifiedLedgerItem item,
      Map<String, Category> categoriesMap,
      AppDatabase db,
      bool isDark,
      AppAccentPreset accent,
      ) {
    final isMoneyIn = item.isMoneyIn;
    final amountColor = isMoneyIn ? AppTokens.income : AppTokens.expense;
    final cardSurfaceColor = isDark ? const Color(0xFF1E2430) : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: PreservedSleekDismissible(
        key: ValueKey('ledger_tx_${item.id}'),
        backgroundColor: AppTokens.expense,
        borderRadius: 16,
        animateIn: _restoringTxIds.contains(item.id),
        onInsertAnimationCompleted: () {
          if (!mounted) return;
          setState(() => _restoringTxIds.remove(item.id));
        },
        onDismissed: () async {
          await _commitDismissedTransaction(item, db, accent);
        },
        child: Material(
          color: cardSurfaceColor,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: item.isDebt
                ? () => _openDebtTransactionDetailSheet(context, item.debtTx!)
                : () => _openEditTransactionSheet(context, item.standardTx!),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cardSurfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (item.isDebt)
                          _buildDebtIconBadge(item.debtType ?? 'LEND')
                        else
                          CategoryIconBadge(
                            category: categoriesMap[item.standardTx!.categoryId],
                            isExpense: item.standardTx!.type == CategoryType.expense,
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
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                      ),
                                    ),
                                  ),
                                  if (item.isDebt) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: _resolveDebtTypeColor(item.debtType).withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        'Vay/Nợ',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: _resolveDebtTypeColor(item.debtType),
                                        ),
                                      ),
                                    ),
                                  ] else if (item.standardTx?.isAiParsed == true) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                      ),
                                    ),
                                  ),
                                  if (item.dueDate != null)
                                    Text(
                                      'Hạn: ${DateFormat('dd/MM').format(item.dueDate!)}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                                      ),
                                    ),
                                ],
                              ),
                              if (item.isDebt && item.note != null && item.note!.trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  item.note!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CurrencyText(
                        '${isMoneyIn ? '+' : '-'}${_formatCurrency(item.amount)}',
                        style: currencyTextStyle(context, TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                        )),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebtIconBadge(String debtType) {
    IconData iconData;
    Color color;

    switch (debtType) {
      case 'LEND':
        iconData = Icons.call_made_rounded;
        color = const Color(0xFF10B981);
        break;
      case 'COLLECT':
        iconData = Icons.call_received_rounded;
        color = const Color(0xFF0EA5E9);
        break;
      case 'BORROW':
        iconData = Icons.south_west_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case 'REPAY':
        iconData = Icons.north_east_rounded;
        color = const Color(0xFFF43F5E);
        break;
      default:
        iconData = Icons.swap_horiz_rounded;
        color = const Color(0xFF10B981);
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: color, size: 18),
    );
  }

  Color _resolveDebtTypeColor(String? debtType) {
    switch (debtType) {
      case 'LEND':
        return const Color(0xFF10B981);
      case 'COLLECT':
        return const Color(0xFF0EA5E9);
      case 'BORROW':
        return const Color(0xFFF59E0B);
      case 'REPAY':
        return const Color(0xFFF43F5E);
      default:
        return const Color(0xFF6366F1);
    }
  }

  Widget _buildAdaptivePeriodBar(
      BuildContext context,
      CycleMode mode,
      DateTime anchorMonth,
      Map<String, int> cycleStore,
      bool isDark,
      AppAccentPreset accent,
      ) {
    if (mode == CycleMode.calendar) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left_rounded, size: 24),
              onPressed: () => _shiftMonthAnimated(-1),
            ),
            InkWell(
              onTap: () => _openMonthYearPickerModal(context, isDark, accent),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tháng ${DateFormat('MM/yyyy').format(anchorMonth)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: accent.primary),
                      ],
                    ),
                    Text(
                      '01/${DateFormat('MM').format(anchorMonth)} – ${DateTime(anchorMonth.year, anchorMonth.month + 1, 0).day}/${DateFormat('MM').format(anchorMonth)}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right_rounded, size: 24),
              onPressed: () => _shiftMonthAnimated(1),
            ),
          ],
        ),
      );
    } else {
      final cycle = computeMonthCycleRange(anchorMonth, cycleStore);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left_rounded, size: 24),
              onPressed: () => _shiftMonthAnimated(-1),
            ),
            InkWell(
              onTap: () => _openEditMilestoneModal(context, anchorMonth, isDark, accent),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cycle.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.tune_rounded, size: 16, color: accent.primary),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cycle.subRange,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_calendar_rounded,
                          size: 11,
                          color: accent.primary.withValues(alpha: 0.8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right_rounded, size: 24),
              onPressed: () => _shiftMonthAnimated(1),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSummaryCard(List<UnifiedLedgerItem> items, bool isDark,
      {String? walletId}) {
    final summary = computeLedgerSummary(items, walletId: walletId);
    final totalIncome = summary.moneyIn;
    final totalExpense = summary.moneyOut;
    final netBalance = summary.net;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C28) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryColumn('Tiền vào', '+${_formatCurrency(totalIncome)}', AppTokens.income, isDark),
          Container(width: 1, height: 26, color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
          _buildSummaryColumn('Tiền ra', '-${_formatCurrency(totalExpense)}', AppTokens.expense, isDark),
          Container(width: 1, height: 26, color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
          _buildSummaryColumn(
            'Chênh lệch',
            '${netBalance >= 0 ? '+' : ''}${_formatCurrency(netBalance)}',
            netBalance >= 0 ? AppTokens.income : AppTokens.expense,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryColumn(String label, String value, Color valueColor, bool isDark) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _PreservedMetricSwitcher(
                value: value,
                animate: !_isPeriodTransitioning,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// 🌟 COMPONENT ACTIVE FILTER CHIPS STRIP (_AnimatedFilterChipStrip)
// ==============================================================================

class _FilterChipSpec {
  final String id;
  final String label;
  final VoidCallback onDeleted;

  const _FilterChipSpec({
    required this.id,
    required this.label,
    required this.onDeleted,
  });
}

class _AnimatedFilterChipStrip extends ConsumerWidget {
  final LedgerFilterCriteria criteria;
  final String searchQuery;
  final Map<String, Wallet> walletsMap;
  final Map<String, Category> categoriesMap;
  final AppAccentPreset accent;
  final bool isDark;
  final VoidCallback onClearSearch;
  final VoidCallback onResetAll;

  const _AnimatedFilterChipStrip({
    required this.criteria,
    required this.searchQuery,
    required this.walletsMap,
    required this.categoriesMap,
    required this.accent,
    required this.isDark,
    required this.onClearSearch,
    required this.onResetAll,
  });

  String _formatCurrency(double amount, [String currency = '₫']) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: currency, decimalDigits: 0);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<_FilterChipSpec> chipSpecs = [];

    if (searchQuery.isNotEmpty) {
      chipSpecs.add(
        _FilterChipSpec(
          id: 'search_query',
          label: '🔍 "$searchQuery"',
          onDeleted: onClearSearch,
        ),
      );
    }

    if (criteria.walletId != null) {
      final wName = walletsMap[criteria.walletId]?.name ?? 'Ví';
      chipSpecs.add(
        _FilterChipSpec(
          id: 'wallet_${criteria.walletId}',
          label: '💳 $wName',
          onDeleted: () {
            ref.read(ledgerFilterCriteriaProvider.notifier).update(
                  (c) => c.copyWith(walletId: () => null),
            );
          },
        ),
      );
    }

    for (final catId in criteria.categoryIds) {
      final catName = categoriesMap[catId]?.name ?? 'Danh mục';
      chipSpecs.add(
        _FilterChipSpec(
          id: 'cat_$catId',
          label: '🏷️ $catName',
          onDeleted: () {
            final nextSet = Set<String>.from(criteria.categoryIds)..remove(catId);
            ref.read(ledgerFilterCriteriaProvider.notifier).update(
                  (c) => c.copyWith(categoryIds: nextSet),
            );
          },
        ),
      );
    }

    if (criteria.minAmount != null || criteria.maxAmount != null) {
      String amountLabel = '💰 ';
      if (criteria.minAmount != null && criteria.maxAmount != null) {
        amountLabel +=
        '${_formatCurrency(criteria.minAmount!)} - ${_formatCurrency(criteria.maxAmount!)}';
      } else if (criteria.minAmount != null) {
        amountLabel += '≥ ${_formatCurrency(criteria.minAmount!)}';
      } else {
        amountLabel += '≤ ${_formatCurrency(criteria.maxAmount!)}';
      }

      chipSpecs.add(
        _FilterChipSpec(
          id: 'amount_range',
          label: amountLabel,
          onDeleted: () {
            ref.read(ledgerFilterCriteriaProvider.notifier).update(
                  (c) => c.copyWith(minAmount: () => null, maxAmount: () => null),
            );
          },
        ),
      );
    }

    if (criteria.customDateRange != null) {
      final dStr =
          '${DateFormat('dd/MM').format(criteria.customDateRange!.start)} - ${DateFormat('dd/MM').format(criteria.customDateRange!.end)}';
      chipSpecs.add(
        _FilterChipSpec(
          id: 'custom_dates',
          label: '📅 $dStr',
          onDeleted: () {
            ref.read(ledgerFilterCriteriaProvider.notifier).update(
                  (c) => c.copyWith(customDateRange: () => null),
            );
          },
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...chipSpecs.map((spec) {
            return Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: AnimatedSwitcher(
                duration: LedgerMotion.chipIn,
                reverseDuration: LedgerMotion.chipOut,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                        CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                      ),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey<String>(spec.id),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.primary.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        spec.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: spec.onDeleted,
                        child: Icon(Icons.close_rounded, size: 14, color: accent.primary),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          InkWell(
            key: const ValueKey('btn_reset_all_chips'),
            onTap: onResetAll,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTokens.expense.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTokens.expense.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.clear_all_rounded, size: 13, color: AppTokens.expense),
                  SizedBox(width: 4),
                  Text(
                    'Xóa hết',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTokens.expense,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==============================================================================
// 🌟 MODAL: MA TRẬN BỘ LỌC ĐA CHIỀU (FLUID DISMISSIBLE INTEGRATION)
// ==============================================================================

class _FilterMatrixModal extends ConsumerStatefulWidget {
  final bool isDark;
  final AppAccentPreset accent;
  final ScrollController? scrollController;

  const _FilterMatrixModal({
    required this.isDark,
    required this.accent,
    this.scrollController,
  });

  @override
  ConsumerState<_FilterMatrixModal> createState() => _FilterMatrixModalState();
}

class _FilterMatrixModalState extends ConsumerState<_FilterMatrixModal> {
  String? _walletId;
  late Set<String> _categoryIds;
  double? _minAmount;
  double? _maxAmount;
  DateTimeRange? _customDateRange;

  final TextEditingController _minAmountCtrl = TextEditingController();
  final TextEditingController _maxAmountCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initCriteria = ref.read(ledgerFilterCriteriaProvider);
    _walletId = initCriteria.walletId;
    _categoryIds = Set<String>.from(initCriteria.categoryIds);
    _minAmount = initCriteria.minAmount;
    _maxAmount = initCriteria.maxAmount;
    _customDateRange = initCriteria.customDateRange;

    if (_minAmount != null) _minAmountCtrl.text = _minAmount!.toInt().toString();
    if (_maxAmount != null) _maxAmountCtrl.text = _maxAmount!.toInt().toString();
  }

  @override
  void dispose() {
    _minAmountCtrl.dispose();
    _maxAmountCtrl.dispose();
    super.dispose();
  }

  void _applyQuickAmount(double? min, double? max) {
    HapticFeedback.selectionClick();
    setState(() {
      _minAmount = min;
      _maxAmount = max;
      _minAmountCtrl.text = min != null ? min.toInt().toString() : '';
      _maxAmountCtrl.text = max != null ? max.toInt().toString() : '';
    });
  }

  void _resetModalFilters() {
    HapticFeedback.selectionClick();
    setState(() {
      _walletId = null;
      _categoryIds.clear();
      _minAmount = null;
      _maxAmount = null;
      _customDateRange = null;
      _minAmountCtrl.clear();
      _maxAmountCtrl.clear();
    });
  }

  void _confirmApply() {
    HapticFeedback.mediumImpact();
    final customMin = double.tryParse(_minAmountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final customMax = double.tryParse(_maxAmountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

    final criteria = LedgerFilterCriteria(
      walletId: _walletId,
      categoryIds: _categoryIds,
      minAmount: customMin ?? _minAmount,
      maxAmount: customMax ?? _maxAmount,
      customDateRange: _customDateRange,
    );

    ref.read(ledgerFilterCriteriaProvider.notifier).state = criteria;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(ledgerWalletsStreamProvider);
    final categoriesAsync = ref.watch(ledgerCategoriesStreamProvider);
    final ledgerItemsAsync = ref.watch(unifiedLedgerStreamProvider);

    final wallets = walletsAsync.valueOrNull ?? <Wallet>[];
    final categories = categoriesAsync.valueOrNull ?? <Category>[];

    final previewCount = ledgerItemsAsync.maybeWhen(
      data: (items) => items.length,
      orElse: () => 0,
    );

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
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
                      Text(
                        'Bộ Lọc Nâng Cao',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: widget.isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      InkWell(
                        onTap: _resetModalFilters,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            'Đặt lại',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: widget.accent.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  controller: widget.scrollController,
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _buildSectionTitle('1. NGUỒN TIỀN (VÍ)'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: 'Tất cả ví',
                          isSelected: _walletId == null,
                          onTap: () => setState(() => _walletId = null),
                        ),
                        ...wallets.map((w) {
                          final isSelected = _walletId == w.id;
                          return _buildFilterChip(
                            label: w.name,
                            isSelected: isSelected,
                            onTap: () => setState(() => _walletId = w.id),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildSectionTitle('2. DANH MỤC (${_categoryIds.length} ĐÃ CHỌN)'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSelected = _categoryIds.contains(cat.id);
                        return _buildFilterChip(
                          label: cat.name,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _categoryIds.remove(cat.id);
                              } else {
                                _categoryIds.add(cat.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionTitle('3. KHOẢNG TIỀN (VNĐ)'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterChip(
                          label: '< 100k',
                          isSelected: _maxAmount == 100000 && _minAmount == null,
                          onTap: () => _applyQuickAmount(null, 100000),
                        ),
                        _buildFilterChip(
                          label: '100k - 1tr',
                          isSelected: _minAmount == 100000 && _maxAmount == 1000000,
                          onTap: () => _applyQuickAmount(100000, 1000000),
                        ),
                        _buildFilterChip(
                          label: '> 1tr',
                          isSelected: _minAmount == 1000000 && _maxAmount == null,
                          onTap: () => _applyQuickAmount(1000000, null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Từ ... ₫',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('➔')),
                        Expanded(
                          child: TextField(
                            controller: _maxAmountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Đến ... ₫',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildSectionTitle('4. KHOẢNG THỜI GIAN'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.date_range_rounded, size: 16),
                            label: Text(
                              _customDateRange != null
                                  ? '${DateFormat('dd/MM').format(_customDateRange!.start)} - ${DateFormat('dd/MM').format(_customDateRange!.end)}'
                                  : 'Tùy chọn ngày cụ thể',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _customDateRange != null
                                  ? widget.accent.primary
                                  : (widget.isDark ? AppTokens.darkText : AppTokens.lightText),
                              side: BorderSide(
                                color: _customDateRange != null
                                    ? widget.accent.primary
                                    : (widget.isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                initialDateRange: _customDateRange,
                              );
                              if (picked != null) {
                                setState(() => _customDateRange = picked);
                              }
                            },
                          ),
                        ),
                        if (_customDateRange != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _customDateRange = null),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accent.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 1,
                  ),
                  onPressed: _confirmApply,
                  child: Text(
                    'ÁP DỤNG BỘ LỌC (TÌM THẤY $previewCount KẾT QUẢ) ❯',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: widget.isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.accent.primary
              : (widget.isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? widget.accent.primary
                : (widget.isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : (widget.isDark ? AppTokens.darkText : AppTokens.lightText),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 🌟 MODAL 1: FINANCIAL CYCLE MILESTONE PICKER — HORIZON + HAPTIC WHEEL
// ==============================================================================

Future<void> showEditCycleMilestoneSheet({
  required BuildContext context,
  required DateTime anchorMonth,
  required bool isDark,
  required AppAccentPreset accent,
}) {
  return AppAnimationPolicy.showFluidSheet(
    context: context,
    mode: FluidSheetMode.nestedScrollable,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 200),
    builder: (_, __) => _EditCycleMilestoneModal(
      anchorMonth: anchorMonth,
      isDark: isDark,
      accent: accent,
    ),
  );
}

class _EditCycleMilestoneModal extends ConsumerStatefulWidget {
  final DateTime anchorMonth;
  final bool isDark;
  final AppAccentPreset accent;
  final ValueChanged<bool>? onWheelInteractionChanged;

  const _EditCycleMilestoneModal({
    required this.anchorMonth,
    required this.isDark,
    required this.accent,
    this.onWheelInteractionChanged,
  });

  @override
  ConsumerState<_EditCycleMilestoneModal> createState() =>
      _EditCycleMilestoneModalState();
}

class _EditCycleMilestoneModalState
    extends ConsumerState<_EditCycleMilestoneModal>
    with SingleTickerProviderStateMixin {
  static const Duration _metricMorphDuration = Duration(milliseconds: 140);
  static const Duration _wheelPresetDuration = Duration(milliseconds: 220);

  late int _selectedDay;
  late int _salaryPresetDay;
  late final FixedExtentScrollController _wheelController;
  late final AnimationController _metricMorphController;

  late MonthCycleRange _previousPreviewRange;
  late MonthCycleRange _currentPreviewRange;

  int get _daysInCurrentMonth =>
      DateTime(widget.anchorMonth.year, widget.anchorMonth.month + 1, 0).day;

  String get _monthKey => DateFormat('yyyy-MM').format(widget.anchorMonth);

  @override
  void initState() {
    super.initState();

    final store = ref.read(cycleStartDaysByMonthProvider);
    final inheritedDay =
    resolveStartDayForMonth(widget.anchorMonth, store)
        .clamp(1, _daysInCurrentMonth)
        .toInt();

    _selectedDay = inheritedDay;
    _salaryPresetDay = inheritedDay;

    _wheelController = FixedExtentScrollController(
      initialItem: _selectedDay - 1,
    );

    _metricMorphController = AppAnimationPolicy.createController(
      vsync: this,
      duration: _metricMorphDuration,
      debugLabel: 'EditMilestone.horizonMorph',
    )..value = 1.0;

    _currentPreviewRange = _computePreviewRange(
      selectedDay: _selectedDay,
      store: store,
    );
    _previousPreviewRange = _currentPreviewRange;
  }

  @override
  void dispose() {
    widget.onWheelInteractionChanged?.call(false);
    _wheelController.dispose();
    _metricMorphController.dispose();
    super.dispose();
  }

  MonthCycleRange _computePreviewRange({
    required int selectedDay,
    required Map<String, int> store,
  }) {
    final tempStore = Map<String, int>.from(store)
      ..[_monthKey] = selectedDay;

    return computeMonthCycleRange(
      widget.anchorMonth,
      tempStore,
    );
  }

  Future<void> _selectPresetDay(int day) async {
    final safeDay = day.clamp(1, _daysInCurrentMonth).toInt();
    if (safeDay == _selectedDay) {
      HapticFeedback.selectionClick();
      return;
    }

    await _wheelController.animateToItem(
      safeDay - 1,
      duration: _wheelPresetDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _onWheelDayChanged(int index) {
    final newDay = (index % _daysInCurrentMonth) + 1;
    if (newDay == _selectedDay) return;

    HapticFeedback.selectionClick();

    final store = ref.read(cycleStartDaysByMonthProvider);
    final nextRange = _computePreviewRange(
      selectedDay: newDay,
      store: store,
    );

    setState(() {
      _previousPreviewRange = _currentPreviewRange;
      _currentPreviewRange = nextRange;
      _selectedDay = newDay;
    });

    _metricMorphController.forward(from: 0.0);
  }

  Widget _buildMorphMetric({
    required String previous,
    required String current,
    required TextStyle style,
    TextAlign textAlign = TextAlign.start,
  }) {
    return AnimatedBuilder(
      animation: _metricMorphController,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(
          _metricMorphController.value.clamp(0.0, 1.0),
        );

        if (previous == current || _metricMorphController.value >= 0.999) {
          return Text(
            current,
            textAlign: textAlign,
            style: style,
          );
        }

        return Stack(
          alignment: textAlign == TextAlign.end
              ? Alignment.centerRight
              : Alignment.centerLeft,
          children: [
            Opacity(
              opacity: (1.0 - t).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0.0, -4.0 * t),
                child: Text(
                  previous,
                  textAlign: textAlign,
                  style: style,
                ),
              ),
            ),
            Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0.0, 4.0 * (1.0 - t)),
                child: Text(
                  current,
                  textAlign: textAlign,
                  style: style,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDottedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dotWidth = 4.0;
        const gap = 4.0;
        final dotCount = math.max(
          1,
          (constraints.maxWidth / (dotWidth + gap)).floor(),
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dotCount,
                (_) => Container(
              width: dotWidth,
              height: 2,
              decoration: BoxDecoration(
                color: widget.accent.primary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCycleHorizonCard() {
    final previousStart =
    DateFormat('dd/MM/yyyy').format(_previousPreviewRange.startDate);
    final currentStart =
    DateFormat('dd/MM/yyyy').format(_currentPreviewRange.startDate);

    final previousEnd =
    DateFormat('dd/MM/yyyy').format(_previousPreviewRange.endDate);
    final currentEnd =
    DateFormat('dd/MM/yyyy').format(_currentPreviewRange.endDate);

    final previousDays = '${_previousPreviewRange.daysCount} ngày';
    final currentDays = '${_currentPreviewRange.daysCount} ngày';

    final primaryText =
    widget.isDark ? AppTokens.darkText : AppTokens.lightText;
    final mutedText =
    widget.isDark ? AppTokens.darkMuted : AppTokens.lightMuted;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.055)
                : Colors.white.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.accent.primary.withValues(alpha: 0.34),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: widget.accent.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'CHU KỲ DỰ KIẾN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.55,
                        color: mutedText,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.accent.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                        widget.accent.primary.withValues(alpha: 0.28),
                      ),
                    ),
                    child: _buildMorphMetric(
                      previous: previousDays,
                      current: currentDays,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: widget.accent.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 18,
                          color: widget.accent.primary,
                        ),
                        const SizedBox(height: 5),
                        _buildMorphMetric(
                          previous: previousStart,
                          current: currentStart,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Bắt đầu chu kỳ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(child: _buildDottedLine()),
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 5),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: widget.accent.primary,
                            ),
                          ),
                          Expanded(child: _buildDottedLine()),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 18,
                          color: widget.accent.primary,
                        ),
                        const SizedBox(height: 5),
                        _buildMorphMetric(
                          previous: previousEnd,
                          current: currentEnd,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Kết thúc chu kỳ',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required int day,
  }) {
    final safeDay = day.clamp(1, _daysInCurrentMonth).toInt();
    final isSelected = _selectedDay == safeDay;

    return Expanded(
      child: InkWell(
        onTap: () => _selectPresetDay(safeDay),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? widget.accent.primary.withValues(alpha: 0.16)
                : (widget.isDark
                ? AppTokens.darkCard
                : AppTokens.lightCardSubtle),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isSelected
                  ? widget.accent.primary
                  : (widget.isDark
                  ? AppTokens.darkBorder
                  : AppTokens.lightBorder),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.15,
                fontWeight: isSelected
                    ? FontWeight.w900
                    : FontWeight.w700,
                color: isSelected
                    ? widget.accent.primary
                    : (widget.isDark
                    ? AppTokens.darkText
                    : AppTokens.lightText),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayWheel() {
    final primaryText =
    widget.isDark ? AppTokens.darkText : AppTokens.lightText;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) =>
          widget.onWheelInteractionChanged?.call(true),
      onPointerUp: (_) =>
          widget.onWheelInteractionChanged?.call(false),
      onPointerCancel: (_) =>
          widget.onWheelInteractionChanged?.call(false),
      child: Container(
        height: 188,
        decoration: BoxDecoration(
          color: widget.isDark
              ? AppTokens.darkCard.withValues(alpha: 0.72)
              : AppTokens.lightCardSubtle.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.isDark
                ? AppTokens.darkBorder
                : AppTokens.lightBorder,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CupertinoPicker(
                scrollController: _wheelController,
                itemExtent: 44,
                diameterRatio: 1.45,
                squeeze: 1.04,
                useMagnifier: false,
                looping: true,
                backgroundColor: Colors.transparent,
                selectionOverlay: const SizedBox.shrink(),
                onSelectedItemChanged: _onWheelDayChanged,
                children: List.generate(
                  _daysInCurrentMonth,
                      (index) {
                    final day = index + 1;
                    final isSelected = day == _selectedDay;
                    final appFontFamily =
                        Theme.of(context).textTheme.bodyMedium?.fontFamily;

                    return Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: isSelected ? 32 : 16,
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w700,
                          fontFamily: appFontFamily,
                          color: isSelected
                              ? widget.accent.primary
                              : primaryText.withValues(alpha: 0.35),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: SizedBox(
                  height: 46,
                  child: Row(
                    children: [
                      const SizedBox(width: 22),
                      Icon(
                        Icons.arrow_right_rounded,
                        size: 24,
                        color: widget.accent.primary
                            .withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: widget.accent.primary
                                  .withValues(alpha: 0.44),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_left_rounded,
                        size: 24,
                        color: widget.accent.primary
                            .withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 22),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveMilestone() {
    ref.read(cycleStartDaysByMonthProvider.notifier).update((state) {
      return Map<String, int>.from(state)
        ..[_monthKey] = _selectedDay;
    });

    AppFeedback.showSuccess(
      context,
      'Chu kỳ tháng ${widget.anchorMonth.month}: bắt đầu ngày $_selectedDay',
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final inheritedLabel =
        'Áp dụng từ tháng '
        '${widget.anchorMonth.month} '
        '• Tự động kế thừa';

    return ClipRRect(
      borderRadius:
      const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF151C28).withValues(alpha: 0.98)
              : Colors.white.withValues(alpha: 0.98),
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: widget.isDark
                ? AppTokens.darkBorder
                : AppTokens.lightBorder,
          ),
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
                    color: widget.isDark
                        ? Colors.white24
                        : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mốc chu kỳ tài chính',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: widget.isDark
                                ? AppTokens.darkText
                                : AppTokens.lightText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          inheritedLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: widget.isDark
                                ? AppTokens.darkMuted
                                : AppTokens.lightMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text(
                      'Đóng',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: widget.isDark
                          ? AppTokens.darkMuted
                          : AppTokens.lightMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 7,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              _buildCycleHorizonCard(),
              const SizedBox(height: 14),

              Row(
                children: [
                  _buildPresetButton(
                    label: 'Đầu tháng\n(Mùng 1)',
                    day: 1,
                  ),
                  const SizedBox(width: 8),
                  _buildPresetButton(
                    label: 'Ngày nhận lương\n(Ngày $_salaryPresetDay)',
                    day: _salaryPresetDay,
                  ),
                  const SizedBox(width: 8),
                  _buildPresetButton(
                    label: 'Giữa tháng\n(Ngày 15)',
                    day: 15,
                  ),
                ],
              ),

              const SizedBox(height: 14),
              _buildDayWheel(),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accent.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 1,
                  ),
                  onPressed: _saveMilestone,
                  child: const Text(
                    'Lưu mốc chu kỳ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 🌟 MODAL 2: 3x4 QUICK MONTH/YEAR PICKER CHO LỊCH DƯƠNG
// ==============================================================================

class _MonthYearPickerModal extends ConsumerStatefulWidget {
  final bool isDark;
  final AppAccentPreset accent;

  const _MonthYearPickerModal({
    required this.isDark,
    required this.accent,
  });

  @override
  ConsumerState<_MonthYearPickerModal> createState() => _MonthYearPickerModalState();
}

class _MonthYearPickerModalState extends ConsumerState<_MonthYearPickerModal> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = ref.read(currentAnchorMonthProvider).year;
  }

  @override
  Widget build(BuildContext context) {
    final activeDate = ref.watch(currentAnchorMonthProvider);
    final now = DateTime.now();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
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
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 28),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedYear--);
                      },
                    ),
                    Text(
                      'Năm $_selectedYear',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: widget.isDark ? AppTokens.darkText : AppTokens.lightText,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 28),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedYear++);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final monthNumber = index + 1;
                    final isSelected = activeDate.year == _selectedYear && activeDate.month == monthNumber;
                    final isCurrentCalendarMonth = now.year == _selectedYear && now.month == monthNumber;

                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(currentAnchorMonthProvider.notifier).state =
                            DateTime(_selectedYear, monthNumber, 1);
                        Navigator.of(context).pop();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: LedgerMotion.control,
                        curve: LedgerMotion.controlCurve,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.accent.primary
                              : (widget.isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? widget.accent.primary
                                : (isCurrentCalendarMonth
                                ? widget.accent.primary.withValues(alpha: 0.5)
                                : (widget.isDark ? AppTokens.darkBorder : AppTokens.lightBorder)),
                            width: isCurrentCalendarMonth ? 1.5 : 1.0,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'T$monthNumber',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : (widget.isDark ? AppTokens.darkText : AppTokens.lightText),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.today_rounded, size: 18),
                    label: const Text('Về tháng hiện tại', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.accent.primary,
                      side: BorderSide(color: widget.accent.primary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      final now = ref.read(dayCutoffProvider).date(DateTime.now());
                      ref.read(currentAnchorMonthProvider.notifier).state = DateTime(now.year, now.month, 1);
                      Navigator.of(context).pop();
                    },
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