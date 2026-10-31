import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../data/daos/debt_dao.dart' show debtContactsStreamProvider;
import '../screens/budget_screen.dart' show showInsightsBudgetEditor;
import '../screens/contact_ledger_screen.dart';
import '../services/budget_spending.dart';
import '../services/budget_spending_provider.dart';
import '../services/fiscal_day.dart';
import '../theme/app_theme.dart';
import 'currency_text.dart';
import 'budget_insights_navigation.dart';
import 'dashboard_hero_card.dart'
    show
        budgetMoney,
        budgetDateLabel,
        budgetRemainingLabel,
        BudgetMoneyText,
        BudgetLedgerStyle,
        BudgetSummaryTile,
        BudgetAmbientSurface,
        budgetCategoryColor;

class SafeToSpendBreakdownSheet extends ConsumerStatefulWidget {
  const SafeToSpendBreakdownSheet(
      {super.key,
      required this.controller,
      required this.isVisible,
      this.initialBudgetId,
      this.initialRhythm,
      this.onVaultTap});
  final ScrollController? controller;
  final bool isVisible;
  final String? initialBudgetId;
  final SpendingRhythm? initialRhythm;
  final VoidCallback? onVaultTap;
  static Future<void> show(BuildContext context,
      {required bool isVisible,
      String? initialBudgetId,
      SpendingRhythm? initialRhythm,
      VoidCallback? onVaultTap}) async {
    // The root still owns native insets even if the caller is below SafeArea.
    // Capture it BEFORE ModalBottomSheetRoute removes its top padding.
    // Only this sheet is bounded; FluidSheet's gesture/physics remain owners.
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final safeTop = MediaQuery.viewPaddingOf(rootContext).top;
    final selected = await AppAnimationPolicy.showFluidSheet<BudgetSpending>(
      context: context,
      mode: FluidSheetMode.scrollable,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
      builder: (sheetContext, controller) =>
          LayoutBuilder(builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final viewport = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : media.size.height;
        final keyboard = media.viewInsets.bottom;
        return Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: math.max(0, viewport - safeTop - 12 - keyboard)),
              child: SafeToSpendBreakdownSheet(
                  controller: controller,
                  isVisible: isVisible,
                  initialBudgetId: initialBudgetId,
                  initialRhythm: initialRhythm,
                  onVaultTap: onVaultTap),
            ));
      }),
    );
    if (selected != null && context.mounted) {
      final overview = ProviderScope.containerOf(context)
          .read(budgetSpendingOverviewProvider)
          .valueOrNull;
      if (overview != null) {
        await openBudgetInsights(context, selected, overview,
            isVisible: isVisible);
      }
    }
  }

  @override
  ConsumerState<SafeToSpendBreakdownSheet> createState() =>
      _BudgetDetailsState();
}

class _BudgetDetailsState extends ConsumerState<SafeToSpendBreakdownSheet> {
  String? _selectedId;
  bool _allTransactions = false;
  final double _overviewOffset = 0;
  bool _openingInsights = false;
  void _openAnalysis(BudgetSpending b) {
    if (_openingInsights) return;
    _openingInsights = true;
    Navigator.of(context).pop(b);
  }

  int _viewGeneration = 0;
  final Set<SpendingRhythm> _saving = {};
  final _pinConfirmations = <Completer<bool>>{};
  @override
  void dispose() {
    for (final confirmation in _pinConfirmations) {
      if (!confirmation.isCompleted) confirmation.complete(false);
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialBudgetId;
  }

  BudgetLedgerStyle get _style => BudgetLedgerStyle(context);
  void _scrollAfterLayout(double offset) {
    final generation = ++_viewGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _viewGeneration) return;
      final c = widget.controller;
      if (c != null && c.hasClients) {
        c.jumpTo(offset.clamp(0, c.position.maxScrollExtent));
      }
    });
  }

  void _backToOverview() {
    setState(() {
      _selectedId = null;
      _allTransactions = false;
    });
    _scrollAfterLayout(_overviewOffset);
  }

  Future<void> _edit(BudgetSpending? b, {SpendingRhythm? rhythm}) async {
    final overview = ref.read(budgetSpendingOverviewProvider).valueOrNull;
    final cat = b == null
        ? null
        : overview?.source.categories
            .where((c) => c.id == b.budget.categoryId)
            .firstOrNull;
    await showInsightsBudgetEditor(context,
        category: cat,
        anchor: b?.budget.periodMonth ?? ref.read(budgetSpendingDateProvider),
        budget: b?.budget,
        enableBlur: false,
        initialRhythm: b?.rhythm ?? rhythm);
  }

  Future<void> _pin(BudgetSpending b) async {
    if (_saving.contains(b.rhythm)) return;
    setState(() => _saving.add(b.rhythm));
    final confirmed = Completer<bool>();
    _pinConfirmations.add(confirmed);
    bool? expected;
    bool matches(BudgetSpendingOverview? o) =>
        expected != null &&
        o != null &&
        o.source.rhythms
            .any((c) => c.budgetId == b.budget.id && c.pinned == expected) &&
        (expected == false ||
            o.source.rhythms
                    .where((c) => c.rhythm == b.rhythm.name && c.pinned)
                    .length ==
                1);
    final subscription =
        ref.listenManual(budgetSpendingOverviewProvider, (_, value) {
      if (!confirmed.isCompleted) {
        if (value.hasError) {
          confirmed.complete(false);
        } else if (matches(value.valueOrNull)) {
          confirmed.complete(true);
        }
      }
    });
    try {
      final db = ref.read(databaseProvider);
      final pinned = await db.transaction(() async {
        // Toggle persisted state, not the last asynchronously delivered UI snapshot.
        final config = await (db.select(db.budgetRhythms)
              ..where((r) => r.budgetId.equals(b.budget.id)))
            .getSingleOrNull();
        final next = !(config?.pinned ?? false);
        expected = next;
        await saveBudgetRhythm(db, b.budget,
            rhythm: b.rhythm,
            weekStart: config?.weekStart ?? 1,
            carryRule: config?.carryRule ?? 'none',
            remainingUses: config?.remainingUses,
            pinned: next);
        return next;
      });
      if (!mounted) return;
      if (!confirmed.isCompleted &&
          matches(ref.read(budgetSpendingOverviewProvider).valueOrNull)) {
        confirmed.complete(true);
      }
      if (!await confirmed.future) {
        throw StateError('Không xác nhận được trạng thái ghim');
      }
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        HapticFeedback.selectionClick();
        AppFeedback.showInfo(
            context,
            pinned
                ? 'Đã ghim ${b.name} lên Dashboard'
                : 'Đã bỏ ghim ${b.name}. Ngân sách này không còn được chọn trên Dashboard.');
      }
    } catch (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        AppFeedback.showError(context, 'Không lưu được lựa chọn ghim.');
      }
    } finally {
      subscription.close();
      _pinConfirmations.remove(confirmed);
      if (mounted) setState(() => _saving.remove(b.rhythm));
    }
  }

  Widget _action(String label, VoidCallback? onTap, {Key? key}) => TextButton(
      key: key,
      onPressed: onTap,
      style:
          TextButton.styleFrom(foregroundColor: _style.readable(_style.accent)),
      child: Text(label));
  Widget _heading(String label, {int? count}) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: LayoutBuilder(builder: (context, box) {
        final countStyle = TextStyle(fontSize: 11, color: _style.muted);
        final measurement = TextPainter(
            text: TextSpan(
                text: count == null ? '' : '$count',
                style: DefaultTextStyle.of(context).style.merge(countStyle)),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context))
          ..layout();
        final countWidth = measurement.width;
        measurement.dispose();
        // The label keeps its intrinsic width. A loose Flexible used to reserve
        // half the row even when its text was much shorter, stranding the count.
        final labelWidth = math.max(
            0.0,
            box.maxWidth -
                countWidth -
                (count == null ? 10 : 20) -
                box.maxWidth * .05);
        return Row(key: ValueKey('budget-heading-$label'), children: [
          ConstrainedBox(
              constraints: BoxConstraints(maxWidth: labelWidth),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      letterSpacing: .5,
                      fontWeight: FontWeight.w700,
                      color: _style.muted))),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: _style.border, thickness: .6)),
          if (count != null) ...[
            const SizedBox(width: 10),
            Text('$count',
                key: ValueKey('budget-count-$label'), style: countStyle),
          ],
        ]);
      }));
  BoxDecoration get _sectionDecoration => BoxDecoration(
      color: _style.subtle.withValues(alpha: _style.dark ? .65 : .55),
      borderRadius: BorderRadius.circular(20),
      border:
          Border.all(color: _style.border.withValues(alpha: .6), width: .7));
  Widget _surface(Widget child) =>
      Container(decoration: _sectionDecoration, child: child);
  Widget _section(
          String label, List<String> identities, Widget Function(int) row,
          {Widget? empty, bool grouped = false, bool dashed = false}) =>
      SliverMainAxisGroup(slivers: [
        SliverToBoxAdapter(child: _heading(label, count: identities.length)),
        if (identities.isEmpty)
          SliverToBoxAdapter(
              child: dashed
                  ? CustomPaint(
                      foregroundPainter: _DashedBudgetBorder(_style.border),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 2),
                          child: empty))
                  : _surface(Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: empty)))
        else if (grouped)
          DecoratedSliver(
              decoration: _sectionDecoration.copyWith(color: _style.surface),
              sliver: SliverList.separated(
                  itemCount: identities.length,
                  findItemIndexCallback: (key) =>
                      key is ValueKey<String> && identities.contains(key.value)
                          ? identities.indexOf(key.value)
                          : null,
                  itemBuilder: (_, i) =>
                      KeyedSubtree(key: ValueKey(identities[i]), child: row(i)),
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, thickness: .6, color: _style.border)))
        else
          SliverList.separated(
              itemCount: identities.length,
              findItemIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                final index = identities.indexOf(key.value);
                return index < 0 ? null : index;
              },
              itemBuilder: (_, i) => KeyedSubtree(
                  key: ValueKey(identities[i]),
                  child: Container(
                      decoration: _sectionDecoration
                          .copyWith(color: _style.surface, boxShadow: [
                        BoxShadow(
                            color: Colors.black
                                .withValues(alpha: _style.dark ? .10 : .025),
                            blurRadius: 10,
                            offset: const Offset(0, 3))
                      ]),
                      child: row(i))),
              separatorBuilder: (_, __) => const SizedBox(height: 10)),
      ]);
  Widget _budgetRow(BudgetSpending b) {
    final overview = ref.watch(budgetSpendingOverviewProvider).requireValue;
    final category = overview.source.categories
        .where((c) => c.id == b.budget.categoryId)
        .firstOrNull;
    return BudgetAmbientSurface(
        colors: [budgetCategoryColor(category, _style.accent)],
        child: Padding(
            key: ValueKey('budget-row-${b.budget.id}'),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BudgetSummaryTile(
                      progressGap: 20,
                      captionGap: 8,
                      progressKey:
                          ValueKey('budget-summary-progress-${b.budget.id}'),
                      budget: b,
                      category: category,
                      isVisible: widget.isVisible,
                      featured: true,
                      onTap: () => _openAnalysis(b)),
                  const SizedBox(height: 2),
                  Divider(height: 1, thickness: .6, color: _style.border),
                  Row(children: [
                    Expanded(
                        child: TextButton(
                            onPressed: () => _openAnalysis(b),
                            style: TextButton.styleFrom(
                                minimumSize: const Size(32, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                                foregroundColor:
                                    _style.readable(_style.accent)),
                            child: const Text('Xem phân tích chi tiêu ›',
                                style: TextStyle(fontSize: 11)))),
                    IconButton(
                        isSelected: b.pinned,
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                            minimumSize: const Size(32, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        tooltip: b.pinned
                            ? 'Bỏ ghim ngân sách khỏi Dashboard'
                            : 'Ghim ngân sách lên Dashboard',
                        onPressed:
                            _saving.contains(b.rhythm) ? null : () => _pin(b),
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: _saving.contains(b.rhythm)
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: MediaQuery.disableAnimationsOf(context)
                                    ? const Icon(Icons.more_horiz, size: 16)
                                    : const CircularProgressIndicator(
                                        strokeWidth: 1.8))
                            : Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    color: b.pinned
                                        ? _style.accent.withValues(alpha: .08)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Icon(
                                    b.pinned
                                        ? Icons.push_pin
                                        : Icons.push_pin_outlined,
                                    size: 14,
                                    color: b.pinned
                                        ? _style.readable(_style.accent)
                                        : _style.muted))),
                  ]),
                ])));
  }

  Future<void> _debt(DebtTransaction d) async {
    final db = ref.read(databaseProvider);
    final contact = await (db.select(db.debtContacts)
          ..where((c) => c.id.equals(d.contactId)))
        .getSingleOrNull();
    if (!mounted ||
        contact == null ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(PreservedMaterialPageRoute<void>(
        builder: (_) => ContactLedgerScreen(contact: contact)));
  }

  void _vault() {
    Navigator.of(context).pop();
    widget.onVaultTap
        ?.call(); // Existing secure launcher retains PIN/biometric ownership.
  }

  Widget _dueRow(DebtTransaction d, int index, String? contactName) => Padding(
      key: ValueKey('due-row-${d.id}'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: _style.muted.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(12)),
            child:
                Icon(Icons.event_note_rounded, size: 19, color: _style.muted)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              contactName?.isNotEmpty == true
                  ? 'Khoản vay · $contactName'
                  : 'Khoản vay ${index + 1}',
              style: const TextStyle(
                  fontSize: 14, height: 1.35, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: AppTokens.warning.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('Hạn ${DateFormat('dd/MM/yyyy').format(d.dueDate!)}',
                  style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color: _style.readable(AppTokens.warning)))),
          const SizedBox(height: 8),
          Text('Chưa xác định số tiền đã dành riêng',
              style: TextStyle(fontSize: 11, height: 1.4, color: _style.muted)),
          _action('Xem sổ nợ', () => _debt(d)),
        ])),
      ]));
  Widget _goalRow(SavingsGoal g) {
    final valid = g.targetAmount.isFinite &&
        g.targetAmount > 0 &&
        g.currentAmount.isFinite;
    final progress =
        valid ? (g.currentAmount / g.targetAmount).clamp(0.0, 1.0) : 0.0;
    return Padding(
        key: ValueKey('goal-row-${g.id}'),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppTokens.income.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.savings_outlined,
                    size: 20, color: _style.readable(AppTokens.income))),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(g.title,
                      style: const TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w600)),
                  Text('Quỹ tiết kiệm riêng',
                      style: TextStyle(
                          fontSize: 11, height: 1.4, color: _style.muted))
                ]))
          ]),
          const SizedBox(height: 9),
          BudgetMoneyText(
              '${budgetMoney(g.currentAmount)} / ${budgetMoney(g.targetAmount)}',
              style: const TextStyle(
                  fontSize: 16, height: 1.4, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ExcludeSemantics(
              child: LinearProgressIndicator(
                  key: ValueKey('goal-progress-${g.id}'),
                  value: widget.isVisible && valid ? progress : 0,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(99),
                  color: _style.readable(AppTokens.income),
                  backgroundColor: _style.border)),
          const SizedBox(height: 5),
          LayoutBuilder(builder: (context, box) {
            final caption = Text(
                !valid
                    ? 'Chưa có mục tiêu hợp lệ'
                    : widget.isVisible
                        ? g.currentAmount > 0 &&
                                g.currentAmount / g.targetAmount < .001
                            ? 'Dưới 0,1% mục tiêu'
                            : '${g.currentAmount > 0 && g.currentAmount / g.targetAmount < .01 ? '<1' : (g.currentAmount / g.targetAmount * 100).toStringAsFixed(0)}% mục tiêu'
                        : 'Số tiền đang ẩn',
                style:
                    TextStyle(fontSize: 12, height: 1.4, color: _style.muted));
            final action = widget.onVaultTap == null
                ? const SizedBox.shrink()
                : _action('Mở Két', _vault);
            return box.maxWidth >= 280 &&
                    MediaQuery.textScalerOf(context).scale(12) <= 16
                ? Row(children: [Expanded(child: caption), action])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        caption,
                        Align(alignment: Alignment.centerRight, child: action)
                      ]);
          }),
        ]));
  }

  List<Widget> _overview(
      BudgetSpendingOverview overview, List<DebtContact>? contacts) {
    final data = overview.source;
    final due = data.debts
        .where((d) => d.type == 'BORROW' && d.dueDate != null && !d.isSettled)
        .toList()
      ..sort((a, b) {
        final time = a.dueDate!.compareTo(b.dueDate!);
        return time != 0 ? time : a.id.compareTo(b.id);
      });
    return [
      for (final r in [SpendingRhythm.period, SpendingRhythm.weekly])
        _section(
            r == SpendingRhythm.period
                ? 'QUỸ CHI THEO KỲ'
                : 'NGÂN SÁCH THEO TUẦN',
            overview.items
                .where((b) => b.rhythm == r)
                .map((b) => b.budget.id)
                .toList(),
            (i) => _budgetRow(
                overview.items.where((b) => b.rhythm == r).elementAt(i)),
            dashed: true,
            empty: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                children: [
                  Text(
                      r == SpendingRhythm.period
                          ? 'Chưa có ngân sách kỳ'
                          : 'Chưa có ngân sách tuần',
                      style: TextStyle(fontSize: 13, color: _style.muted)),
                  _action('+ Thiết lập', () => _edit(null, rhythm: r)),
                ])),
      _section(
          'KHOẢN CẦN GIỮ ĐẾN HẠN',
          due.map((d) => d.id).toList(),
          (i) => _dueRow(
              due[i],
              i,
              contacts
                  ?.where((c) => c.id == due[i].contactId)
                  .firstOrNull
                  ?.name),
          grouped: true,
          empty: Text('Chưa có khoản vay có ngày đến hạn trong sổ nợ.',
              style:
                  TextStyle(fontSize: 13, height: 1.4, color: _style.muted))),
      _section('QUỸ TÍCH LŨY', data.goals.map((g) => g.id).toList(),
          (i) => _goalRow(data.goals[i]),
          empty:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Chưa có mục tiêu trong Két.',
                style: TextStyle(fontSize: 13, color: _style.muted)),
            if (widget.onVaultTap != null) _action('Mở Két', _vault),
          ])),
      SliverToBoxAdapter(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: Text(
                'Hạn mức kế hoạch không phải số dư ví hoặc tiền đã dành riêng.',
                style:
                    TextStyle(fontSize: 12, height: 1.4, color: _style.muted))),
      ])),
    ];
  }

  List<Widget> _detailBody(BudgetSpendingOverview overview) {
    final b =
        overview.items.where((b) => b.budget.id == _selectedId).firstOrNull;
    if (b == null) {
      return [
        SliverToBoxAdapter(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ngân sách không còn trong khoảng áp dụng này.'),
          _action('Về danh sách', _backToOverview),
        ]))
      ];
    }
    final boundary = ref.watch(dayCutoffProvider);
    final history = overview.source.expenses
        .where((t) =>
            overview.ownerByTransactionId[t.id] == b.budget.id &&
            !t.date.isBefore(boundary.start(b.start)) &&
            t.date.isBefore(boundary.start(b.end)))
        .toList()
      ..sort((a, z) {
        final date = z.date.compareTo(a.date);
        return date == 0 ? a.id.compareTo(z.id) : date;
      });
    final count =
        _allTransactions ? history.length : math.min(5, history.length);
    final ratio =
        b.ratio.isFinite ? b.ratio.clamp(0.0, 1.0) : (b.spent > 0 ? 1.0 : 0.0);
    return [
      SliverToBoxAdapter(
          child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _surface(Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name,
                            style: const TextStyle(
                                fontSize: 19,
                                height: 1.35,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 5),
                        Text(
                            '${b.rhythm == SpendingRhythm.weekly ? 'Theo tuần' : 'Theo kỳ'} · ${budgetDateLabel(b)}',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: _style.muted)),
                        const SizedBox(height: 16),
                        if (b.error != null)
                          Text(b.error!,
                              style:
                                  TextStyle(fontSize: 14, color: _style.muted))
                        else ...[
                          BudgetMoneyText(budgetRemainingLabel(b),
                              style: TextStyle(
                                  fontSize: 22,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: _style.amount(b))),
                          const SizedBox(height: 10),
                          BudgetMoneyText(
                              'Đã chi ${budgetMoney(b.spent)} / hạn mức ${budgetMoney(b.available)}',
                              style:
                                  const TextStyle(fontSize: 13, height: 1.45)),
                          const SizedBox(height: 12),
                          ExcludeSemantics(
                              child: LinearProgressIndicator(
                                  value: widget.isVisible ? ratio : 0,
                                  minHeight: 3,
                                  borderRadius: BorderRadius.circular(99),
                                  color: _style.amount(b),
                                  backgroundColor: _style.border)),
                          const SizedBox(height: 6),
                          Text(
                              widget.isVisible
                                  ? (b.ratio.isFinite
                                      ? '${(b.ratio * 100).toStringAsFixed(0)}%'
                                      : 'Vượt hạn mức')
                                  : 'Số tiền đang ẩn',
                              style:
                                  TextStyle(fontSize: 12, color: _style.muted)),
                          if (b.carryEnabled)
                            BudgetMoneyText(
                                'Chuyển dư có dấu: ${budgetMoney(b.carry)}',
                                style:
                                    const TextStyle(fontSize: 13, height: 1.5)),
                          if (b.previousRemaining != null && !b.carryEnabled)
                            BudgetMoneyText(
                                'Kỳ trước ${b.previousRemaining! < 0 ? 'vượt' : 'còn'} ${budgetMoney(b.previousRemaining!.abs())} · Không chuyển dư',
                                style:
                                    const TextStyle(fontSize: 13, height: 1.5)),
                          if (b.dailySuggestion != null)
                            BudgetMoneyText(
                                'Gợi ý ~${budgetMoney(b.dailySuggestion!)}/ngày · không phải giới hạn',
                                style:
                                    const TextStyle(fontSize: 13, height: 1.5)),
                          if (b.perUseSuggestion != null)
                            BudgetMoneyText(
                                'Gợi ý ~${budgetMoney(b.perUseSuggestion!)}/lần · ${b.remainingUses} lần còn lại',
                                style:
                                    const TextStyle(fontSize: 13, height: 1.5)),
                        ],
                        const SizedBox(height: 10),
                        _action('Điều chỉnh ngân sách', () => _edit(b)),
                      ]))))),
      SliverToBoxAdapter(
          child: _heading(
              _allTransactions
                  ? 'GIAO DỊCH TRONG KHOẢNG ÁP DỤNG'
                  : 'GIAO DỊCH GẦN ĐÂY',
              count: history.length)),
      if (history.isEmpty)
        SliverToBoxAdapter(
            child: Text('Chưa có chi tiêu thuộc ngân sách trong khoảng này.',
                style:
                    TextStyle(fontSize: 13, height: 1.4, color: _style.muted)))
      else
        DecoratedSliver(
            decoration: _sectionDecoration,
            sliver: SliverList.separated(
                itemCount: count,
                itemBuilder: (_, i) {
                  final tx = history[i];
                  final wallet = overview.source.wallets
                      .where((w) => w.id == tx.walletId)
                      .firstOrNull;
                  return Padding(
                      key: ValueKey('budget-history-${tx.id}'),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                tx.merchant?.isNotEmpty == true
                                    ? tx.merchant!
                                    : tx.note?.isNotEmpty == true
                                        ? tx.note!
                                        : b.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 3),
                            Text(
                                '${DateFormat('dd/MM/yyyy HH:mm').format(tx.date)}${wallet == null ? '' : ' · ${wallet.name}'}',
                                style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: _style.muted)),
                            const SizedBox(height: 7),
                            BudgetMoneyText('Chi ${budgetMoney(tx.amount)}',
                                style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600)),
                          ]));
                },
                separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: _style.border,
                    indent: 14,
                    endIndent: 14))),
      if (!_allTransactions && history.isNotEmpty)
        SliverToBoxAdapter(
            child: _action('Xem giao dịch',
                () => setState(() => _allTransactions = true))),
      SliverToBoxAdapter(
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                  'Hạn mức kế hoạch không phải số dư ví hoặc tiền đã dành riêng.',
                  style: TextStyle(
                      fontSize: 12, height: 1.4, color: _style.muted)))),
    ];
  }

  List<Widget> _loading() => [
        const SliverToBoxAdapter(child: Text('Đang tải ngân sách…')),
        for (final label in [
          'QUỸ CHI THEO KỲ',
          'NGÂN SÁCH THEO TUẦN',
          'KHOẢN CẦN GIỮ ĐẾN HẠN',
          'QUỸ TÍCH LŨY'
        ]) ...[
          SliverToBoxAdapter(child: _heading(label)),
          SliverToBoxAdapter(
              child: ExcludeSemantics(
                  child: _surface(const SizedBox(height: 76)))),
        ],
      ];
  @override
  Widget build(BuildContext context) {
    final value = ref.watch(budgetSpendingOverviewProvider);
    // One metadata subscription for this sheet, retained across local detail/Back.
    final contacts = ref.watch(debtContactsStreamProvider).valueOrNull;
    final s = _style;
    final shell = AppGlassmorphism.heroGlassDecoration(
            isDark: s.dark, accentColor: s.accent, borderRadius: 28)
        .copyWith(color: s.surface.withValues(alpha: s.dark ? .96 : .93));
    return PopScope(
        canPop: _selectedId == null,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _selectedId != null) _backToOverview();
        },
        child: BalancePrivacyScope(
            visible: widget.isVisible,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: shell.boxShadow),
                child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    child: Material(
                        type: MaterialType.transparency,
                        child: Container(
                            decoration: shell.copyWith(
                                boxShadow: [],
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(28))),
                            child: DefaultTextStyle.merge(
                                style: TextStyle(
                                    fontSize: 13, height: 1.4, color: s.ink),
                                child: TextButtonTheme(
                                    data: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                            foregroundColor: s.ink,
                                            minimumSize: const Size(48, 48),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 8),
                                            textStyle: Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.merge(s.action))),
                                    child: SafeArea(
                                        top: false,
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 10, bottom: 14),
                                                  child: ExcludeSemantics(
                                                      child: Container(
                                                          width: 36,
                                                          height: 4,
                                                          decoration: BoxDecoration(
                                                              color: s.muted
                                                                  .withValues(
                                                                      alpha:
                                                                          .30),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          99))))),
                                              Container(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          20, 0, 12, 16),
                                                  child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        if (_selectedId != null)
                                                          IconButton(
                                                              tooltip:
                                                                  'Về danh sách ngân sách',
                                                              onPressed:
                                                                  _backToOverview,
                                                              constraints:
                                                                  const BoxConstraints(
                                                                      minWidth:
                                                                          48,
                                                                      minHeight:
                                                                          48),
                                                              icon: const Icon(
                                                                  Icons
                                                                      .arrow_back_rounded,
                                                                  size: 20)),
                                                        Expanded(
                                                            child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                              Text(
                                                                  _selectedId ==
                                                                          null
                                                                      ? 'Khả năng chi tiêu'
                                                                      : 'Chi tiết ngân sách',
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          20,
                                                                      height:
                                                                          1.3,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600)),
                                                              const SizedBox(
                                                                  height: 4),
                                                              Text(
                                                                  'Mỗi ngân sách được tính riêng',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      height:
                                                                          1.4,
                                                                      color: s
                                                                          .muted)),
                                                            ])),
                                                        IconButton(
                                                            tooltip:
                                                                'Đóng chi tiết ngân sách',
                                                            constraints:
                                                                const BoxConstraints(
                                                                    minWidth:
                                                                        48,
                                                                    minHeight:
                                                                        48),
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                        context)
                                                                    .pop(),
                                                            icon: const Icon(
                                                                Icons
                                                                    .close_rounded,
                                                                size: 20)),
                                                      ])),
                                              Flexible(
                                                  child: CustomScrollView(
                                                      key: const PageStorageKey(
                                                          'budget-ledger-scroll'),
                                                      controller:
                                                          widget.controller,
                                                      physics:
                                                          const ClampingScrollPhysics(),
                                                      slivers: [
                                                    SliverPadding(
                                                        padding:
                                                            const EdgeInsets
                                                                .fromLTRB(
                                                                20, 0, 20, 16),
                                                        sliver: SliverMainAxisGroup(
                                                            slivers: value.when(
                                                                loading: _loading,
                                                                error: (_, __) => [
                                                                      SliverToBoxAdapter(
                                                                          child: Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              children: [
                                                                            const Text('Chưa tải được ngân sách'),
                                                                            _action('Thử lại',
                                                                                () => ref.invalidate(budgetSpendingDataProvider)),
                                                                          ]))
                                                                    ],
                                                                data: (o) => _selectedId == null ? _overview(o, contacts) : _detailBody(o))))
                                                  ])),
                                            ]))))))))));
  }
}

class _DashedBudgetBorder extends CustomPainter {
  _DashedBudgetBorder(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(16)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 7) {
        canvas.drawPath(
            metric.extractPath(start, math.min(start + 3, metric.length)),
            paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBudgetBorder oldDelegate) =>
      color != oldDelegate.color;
}
