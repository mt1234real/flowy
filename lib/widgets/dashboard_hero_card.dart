import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../core/animation/app_animation_policy.dart';
import '../services/budget_spending.dart';
import '../services/budget_spending_provider.dart';
import '../theme/app_theme.dart';
import '../screens/budget_screen.dart' show showInsightsBudgetEditor;
import 'currency_text.dart';
import 'category_icon_badge.dart';
import 'budget_insights_navigation.dart';
import '../data/database.dart' show Category;
import 'pre_purchase_advisor_sheet.dart';
import 'safe_to_spend_breakdown_sheet.dart';

String budgetMoney(double amount) =>
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(amount);
String budgetRemainingLabel(BudgetSpending b) => b.remaining == 0
    ? 'Đã dùng hết'
    : '${b.remaining < 0 ? 'Vượt' : 'Còn'} ${budgetMoney(b.remaining.abs())}';
String budgetDateLabel(BudgetSpending b) =>
    '${DateFormat('dd/MM').format(b.start)} – ${DateFormat('dd/MM').format(b.end.subtract(const Duration(days: 1)))}';

class BudgetMoneyText extends StatelessWidget {
  const BudgetMoneyText(this.data,
      {super.key, this.isVisible, this.style, this.textAlign});
  final String data;
  final bool? isVisible;
  final TextStyle? style;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) {
    final visible = isVisible ?? BalancePrivacyScope.isVisibleOf(context);
    if (!MediaQuery.disableAnimationsOf(context)) {
      // Keep number retargeting for data changes, but never retain visible
      // outgoing text after the owner switches privacy off.
      return CurrencyText(data,
          key: ValueKey(visible),
          isVisible: visible,
          style: style,
          textAlign: textAlign);
    }
    final displayed = visible
        ? data
        : data.replaceAll(
            RegExp(r'[+−-]?(?:[0-9][0-9.,\s]*|[•●]+)\s*[₫đ]'), '•••••• ₫');
    return CurrencyText(displayed,
        respectPrivacy: false, style: style, textAlign: textAlign);
  }
}

/// Presentation roles scoped to the budget surfaces, never a global accent change.
class BudgetLedgerStyle {
  BudgetLedgerStyle(BuildContext context)
      : dark = Theme.of(context).brightness == Brightness.dark,
        ink = Theme.of(context).colorScheme.onSurface,
        accent = Theme.of(context).colorScheme.primary;
  final bool dark;
  final Color ink, accent;
  Color get canvas => dark ? AppTokens.darkBg : AppTokens.lightBg;
  Color get surface => dark ? AppTokens.darkCard : AppTokens.lightCard;
  Color get subtle =>
      dark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle;
  Color get border => dark ? AppTokens.darkBorder : AppTokens.lightBorder;
  Color get muted =>
      readable(dark ? AppTokens.darkMuted : AppTokens.lightMuted);
  Color readable(Color color, {Color? on}) {
    final bg = on ?? subtle;
    double contrast(Color c) {
      final a = c.computeLuminance(), b = bg.computeLuminance();
      return (math.max(a, b) + .05) / (math.min(a, b) + .05);
    }

    for (var step = 0; step <= 10; step++) {
      final candidate = Color.lerp(color, ink, step / 10)!;
      if (contrast(candidate) >= 4.5) return candidate;
    }
    return ink;
  }

  Color amount(BudgetSpending b) =>
      b.remaining < 0 ? readable(AppTokens.expense) : ink;
  TextStyle get action => TextStyle(
      fontSize: 12, height: 1.35, fontWeight: FontWeight.w600, color: ink);
}

class DashboardHeroCard extends ConsumerWidget {
  const DashboardHeroCard({super.key, this.isVisible = false, this.onVaultTap});
  final bool isVisible;
  final VoidCallback? onVaultTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetSpendingOverviewProvider);
    final style = BudgetLedgerStyle(context);
    void open({String? id, SpendingRhythm? rhythm}) {
      HapticFeedback.selectionClick();
      SafeToSpendBreakdownSheet.show(context,
          isVisible: isVisible,
          initialBudgetId: id,
          initialRhythm: rhythm,
          onVaultTap: onVaultTap);
    }

    void create(SpendingRhythm? rhythm) {
      HapticFeedback.selectionClick();
      showInsightsBudgetEditor(context,
          anchor: ref.read(budgetSpendingDateProvider), initialRhythm: rhythm);
    }

    TextButton action(String label, VoidCallback? onTap,
            {bool tonal = false}) =>
        TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
                foregroundColor: style.ink,
                backgroundColor: null,
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.symmetric(horizontal: tonal ? 12 : 0),
                textStyle: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.merge(style.action.copyWith(fontSize: 11)),
                shape: const StadiumBorder()),
            child: tonal
                ? Container(
                    constraints: const BoxConstraints(minHeight: 28),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: style.accent.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14)),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 11, color: style.readable(style.accent))))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(label),
                    const Icon(Icons.chevron_right_rounded, size: 14)
                  ]));
    final advisor = action(
        'Có nên mua?',
        state.hasValue
            ? () {
                HapticFeedback.selectionClick();
                AppAnimationPolicy.showFluidSheet<void>(
                    context: context,
                    mode: FluidSheetMode.scrollable,
                    builder: (_, controller) => BalancePrivacyScope(
                        visible: isVisible,
                        child: PrePurchaseAdvisorSheet(
                            scrollController: controller)));
              }
            : null,
        tonal: true);
    Widget budgets(BudgetSpendingOverview overview) {
      final weekly = overview.explicitlyPinned(SpendingRhythm.weekly);
      final period = overview.explicitlyPinned(SpendingRhythm.period);
      if (!isVisible) return _HiddenHeroBudget(onTap: () => open());
      final items = [if (weekly != null) weekly, if (period != null) period];
      if (items.isEmpty) {
        return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
                key: const ValueKey('budget-empty'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      overview.items.isEmpty
                          ? 'Chưa có ngân sách để theo dõi'
                          : 'Chưa ghim ngân sách để theo dõi',
                      style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: style.ink)),
                  const SizedBox(height: 5),
                  Text(
                      overview.items.isEmpty
                          ? 'Thiết lập ngân sách đầu tiên của bạn'
                          : 'Mở danh sách để chọn ngân sách theo dõi',
                      style: TextStyle(
                          fontSize: 12, height: 1.4, color: style.muted)),
                  if (overview.items.isEmpty)
                    action('+ Tạo ngân sách', () => create(null)),
                ]));
      }
      if (items.length == 1) {
        final b = items.single;
        return SizedBox(
            width: double.infinity,
            child: BudgetSummaryTile(
                budget: b,
                isVisible: isVisible,
                category: overview.source.categories
                    .where((c) => c.id == b.budget.categoryId)
                    .firstOrNull,
                featured: true,
                onTap: () => openBudgetInsights(context, b, overview,
                    isVisible: isVisible)));
      }
      return LayoutBuilder(builder: (context, box) {
        final stacked = MediaQuery.textScalerOf(context).scale(12) > 17;

        Widget tile(BudgetSpending b) => BudgetSummaryTile(
            budget: b,
            isVisible: isVisible,
            category: overview.source.categories
                .where((c) => c.id == b.budget.categoryId)
                .firstOrNull,
            onTap: () =>
                openBudgetInsights(context, b, overview, isVisible: isVisible));
        return stacked
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                tile(weekly!),
                const SizedBox(height: 10),
                tile(period!)
              ])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: tile(weekly!)),
                const SizedBox(width: 10),
                Expanded(child: tile(period!))
              ]);
      });
    }

    final overview = state.valueOrNull;
    final ambientColors = [
      if (isVisible)
        for (final rhythm in SpendingRhythm.values)
          if (overview?.explicitlyPinned(rhythm) case final BudgetSpending b)
            budgetCategoryColor(
                overview!.source.categories
                    .where((c) => c.id == b.budget.categoryId)
                    .firstOrNull,
                style.accent),
    ];
    final decoration = AppGlassmorphism.heroGlassDecoration(
        isDark: style.dark, accentColor: style.accent, borderRadius: 20);
    // The reusable frosted card supplies one bounded blur. Shadow is outside its clip.
    return DecoratedBox(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: decoration.boxShadow),
        child: AppGlassmorphism.glassCard(
            context: context,
            isDark: style.dark,
            blur: 14,
            borderRadius: 20,
            padding: EdgeInsets.zero,
            child: _HeroAmbientTransition(
                colors: ambientColors,
                visible: isVisible,
                themeColor: style.accent,
                stacked: MediaQuery.textScalerOf(context).scale(12) > 17,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LayoutBuilder(builder: (context, box) {
                            final heading = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('AN TOÀN CHI TIÊU',
                                      style: TextStyle(
                                          fontSize: 13,
                                          height: 1.35,
                                          fontWeight: FontWeight.w700,
                                          color: style.ink)),
                                ]);
                            return MediaQuery.textScalerOf(context).scale(12) >
                                        17 ||
                                    box.maxWidth < 290
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                        heading,
                                        Align(
                                            alignment: Alignment.centerRight,
                                            child: advisor)
                                      ])
                                : Row(children: [
                                    Expanded(child: heading),
                                    const SizedBox(width: 8),
                                    advisor
                                  ]);
                          }),
                          const SizedBox(height: 2),
                          state.when(
                              data: budgets,
                              loading: () => Semantics(
                                  label: 'Đang tải ngân sách',
                                  child: Container(
                                      constraints:
                                          const BoxConstraints(minHeight: 120),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                          color: style.subtle
                                              .withValues(alpha: .5),
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                      child: Text('Đang tải ngân sách…',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: style.muted)))),
                              error: (_, __) => Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Chưa tải được ngân sách',
                                            style: TextStyle(fontSize: 13)),
                                        action(
                                            'Thử lại',
                                            () => ref.invalidate(
                                                budgetSpendingDataProvider))
                                      ])),
                          const SizedBox(height: 4),
                          Divider(
                              height: 1, thickness: .6, color: style.border),
                          LayoutBuilder(builder: (context, box) {
                            final actions = <Widget>[
                              action('Xem tất cả ngân sách', () => open()),
                              if (state.valueOrNull?.pinned(SpendingRhythm.weekly) ==
                                      null &&
                                  state.valueOrNull?.pinned(SpendingRhythm.period) !=
                                      null)
                                TextButton(
                                    onPressed: () =>
                                        create(SpendingRhythm.weekly),
                                    style: TextButton.styleFrom(
                                        foregroundColor:
                                            style.readable(style.accent),
                                        minimumSize: const Size(48, 48),
                                        padding: EdgeInsets.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.merge(style.action
                                                .copyWith(fontSize: 11))),
                                    child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add, size: 12),
                                          SizedBox(width: 2),
                                          Text('Tạo ngân sách tuần')
                                        ])),
                              if (state.valueOrNull?.pinned(SpendingRhythm.period) ==
                                      null &&
                                  state.valueOrNull?.pinned(SpendingRhythm.weekly) !=
                                      null)
                                TextButton(
                                    onPressed: () =>
                                        create(SpendingRhythm.period),
                                    style: TextButton.styleFrom(
                                        foregroundColor:
                                            style.readable(style.accent),
                                        minimumSize: const Size(48, 48),
                                        padding: EdgeInsets.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.merge(style.action
                                                .copyWith(fontSize: 11))),
                                    child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add, size: 12),
                                          SizedBox(width: 2),
                                          Text('Tạo ngân sách kỳ')
                                        ])),
                            ];
                            return box.maxWidth < 310 ||
                                    MediaQuery.textScalerOf(context).scale(12) >
                                        15
                                ? Wrap(spacing: 14, children: actions)
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: actions);
                          }),
                        ])))));
  }
}

/// Never constructs a real category, money widget or category semantics.
class _HiddenHeroBudget extends StatelessWidget {
  const _HiddenHeroBudget({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = BudgetLedgerStyle(context);
    final scaler = MediaQuery.textScalerOf(context);
    return Material(
        color: Colors.transparent,
        child: InkWell(
            key: const ValueKey('hidden-hero-budget'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                          constraints: BoxConstraints(
                              minHeight: (scaler.scale(16) * 1.3 +
                                      scaler.scale(10) * 1.4)
                                  .ceilToDouble()),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ngân sách đang ẩn',
                                    style: TextStyle(
                                        fontSize: 13,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600,
                                        color: s.ink)),
                                const SizedBox(height: 2),
                                Text('Bật hiển thị để xem ngân sách theo dõi',
                                    style: TextStyle(
                                        fontSize: 10,
                                        height: 1.35,
                                        color: s.muted)),
                              ])),
                      const SizedBox(height: 6),
                      BudgetUsageProgress(
                          key: const ValueKey('hidden-hero-progress'),
                          value: 0,
                          color: s.border,
                          track: s.border),
                      const SizedBox(height: 5),
                      Text('Tiến độ đang ẩn',
                          style: TextStyle(
                              fontSize: 10, height: 1.4, color: s.muted)),
                    ]))));
  }
}

/// Only the decoration interpolates; privacy removal is synchronous and one-way.
class _HeroAmbientTransition extends StatefulWidget {
  const _HeroAmbientTransition(
      {required this.colors,
      required this.themeColor,
      required this.visible,
      required this.stacked,
      required this.child});
  final List<Color> colors;
  final Color themeColor;
  final bool visible, stacked;
  final Widget child;
  @override
  State<_HeroAmbientTransition> createState() => _HeroAmbientTransitionState();
}

class _HeroAmbientTransitionState extends State<_HeroAmbientTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AppAnimationPolicy.createController(
      vsync: this,
      duration: AppAnimationPolicy.dialogDuration,
      debugLabel: 'BudgetHero.ambient')
    ..value = 1;
  late List<Color> _from = _target;
  late List<Color> _to = _target;
  List<Color> get _target => widget.visible && widget.colors.isNotEmpty
      ? widget.colors
      : [widget.themeColor];
  List<Color> get _colors => List.generate(
      _to.length,
      (i) => Color.lerp(i < _from.length ? _from[i] : widget.themeColor, _to[i],
          Curves.easeInOut.transform(_motion.value))!);
  @override
  void didUpdateWidget(covariant _HeroAmbientTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible) {
      _motion.stop();
      _from = _to = [widget.themeColor];
      _motion.value = 1;
    } else if (!oldWidget.visible || !listEquals(_to, _target)) {
      _from = oldWidget.visible ? _colors : [widget.themeColor];
      _to = _target;
      if (MediaQuery.disableAnimationsOf(context)) {
        _motion.value = 1;
      } else {
        _motion.forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = 1;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _motion,
      child: widget.child,
      builder: (context, child) => BudgetAmbientSurface(
          // OFF never samples an outgoing category color, even mid-animation.
          colors: widget.visible ? _colors : [widget.themeColor],
          hero: true,
          stacked: widget.visible && widget.stacked,
          child: child!));
}

/// A single finite-usage presentation shared by Hero and Sheet. Hidden is a
/// neutral static track, never indeterminate progress or a second privacy source.
class BudgetUsageProgress extends StatelessWidget {
  const BudgetUsageProgress(
      {super.key,
      required this.value,
      required this.color,
      required this.track});
  final double value;
  final Color color, track;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: SizedBox(
          height: 5,
          child: DecoratedBox(
              decoration: BoxDecoration(
                  color: track, borderRadius: BorderRadius.circular(99)),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                      widthFactor: value.clamp(0.0, 1.0),
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Color.lerp(color, Colors.white, .22)!,
                                color
                              ]),
                              borderRadius: BorderRadius.circular(99)),
                          child: const SizedBox.expand()))))));
}

String budgetUsageLabel(BudgetSpending b) =>
    b.error != null || b.available <= 0 || !b.ratio.isFinite
        ? 'Chưa có tỷ lệ hợp lệ'
        : '${(b.ratio * 100).toStringAsFixed(0)}%';
Color budgetCategoryColor(Category? category, Color fallback) => Color(
    int.tryParse('FF${category?.color.replaceAll('#', '') ?? ''}', radix: 16) ??
        fallback.toARGB32());

/// A low-strength, horizontally stretched category wash under the whole card.
/// Only its shader is stretched: content, layout and hit regions stay unchanged.
class BudgetAmbientSurface extends StatelessWidget {
  const BudgetAmbientSurface(
      {super.key,
      required this.colors,
      required this.child,
      this.hero = false,
      this.stacked = false});
  final List<Color> colors;
  final Widget child;
  final bool hero, stacked;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) return child;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final alpha = hero ? (dark ? .15 : .13) : (dark ? .14 : .12);
    return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(children: [
          Positioned.fill(child:
              IgnorePointer(child: LayoutBuilder(builder: (context, box) {
            final size = box.biggest;
            if (size.isEmpty) return const SizedBox.shrink();
            Widget wash(int i) {
              final x =
                  18 + (stacked ? 0 : i * (size.width - 18) / colors.length);
              final y = (hero ? 24.0 : 18.0) +
                  (stacked
                      ? i * math.max(0, size.height - 125) / colors.length
                      : 0);
              final center = FractionalOffset(x / size.width, y / size.height);
              return DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: RadialGradient(
                center: center,
                // A broader top-anchored field diffuses across the identity
                // area; its tail reaches zero before the compact footer.
                radius: math.min(size.width * .28, hero ? 104.0 : 96.0) /
                    size.shortestSide,
                transform: _HorizontalBudgetWash(center),
                stops: const [0, 1],
                colors: [
                  colors[i].withValues(alpha: alpha),
                  colors[i].withValues(alpha: 0)
                ],
              )));
            }

            return Stack(fit: StackFit.expand, children: [
              for (var i = 0; i < colors.length; i++) wash(i),
            ]);
          }))),
          child,
        ]));
  }
}

class _HorizontalBudgetWash extends GradientTransform {
  const _HorizontalBudgetWash(this.center);
  final AlignmentGeometry center;
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final anchor = center.resolve(textDirection).withinRect(bounds);
    return Matrix4.diagonal3Values(2.4, 1, 1)
      ..setTranslationRaw(-1.4 * anchor.dx, 0, 0);
  }
}

class BudgetSummaryTile extends StatelessWidget {
  const BudgetSummaryTile(
      {super.key,
      required this.budget,
      required this.isVisible,
      required this.onTap,
      this.category,
      this.featured = false,
      this.progressKey,
      this.progressGap = 6,
      this.captionGap = 5});
  final BudgetSpending budget;
  final Category? category;
  final bool isVisible, featured;
  final Key? progressKey;
  final double progressGap, captionGap;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = BudgetLedgerStyle(context), b = budget;
    final tone = budgetCategoryColor(category, s.accent);
    final valid = b.error == null && b.available > 0 && b.ratio.isFinite;
    final identity =
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      ExcludeSemantics(
          child: CategoryIconBadge(category: category, size: 34, iconSize: 18)),
      const SizedBox(width: 8),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${b.name} · ${b.rhythm == SpendingRhythm.weekly ? 'Tuần' : 'Kỳ'}',
            style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: s.ink)),
        const SizedBox(height: 2),
        Text(budgetDateLabel(b),
            style: TextStyle(fontSize: 10, height: 1.35, color: s.muted)),
      ])),
    ]);
    final amount = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (b.error != null)
            Text('Cần kiểm tra', style: TextStyle(fontSize: 13, color: s.muted))
          else
            ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: featured
                        ? 0
                        : MediaQuery.textScalerOf(context).scale(16) * 1.7),
                child: IgnorePointer(
                    child: BudgetMoneyText(budgetMoney(b.remaining.abs()),
                        isVisible: isVisible,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 16,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: isVisible ? s.amount(b) : s.ink)))),
          Text(
              !isVisible
                  ? 'Số tiền đang ẩn'
                  : b.error != null
                      ? 'Kiểm tra cấu hình'
                      : b.remaining < 0
                          ? 'Vượt hạn mức'
                          : b.remaining == 0
                              ? 'Đã dùng hết'
                              : 'Còn trong hạn mức',
              style: TextStyle(
                  fontSize: 10,
                  height: 1.4,
                  color: isVisible && b.remaining < 0 ? s.amount(b) : s.muted)),
        ]);
    return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
            key: ValueKey('budget-tile-${b.rhythm.name}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
                padding: EdgeInsets.symmetric(
                    vertical: 2, horizontal: featured ? 0 : 8),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(builder: (context, box) {
                        final horizontal = box.maxWidth >= 300 &&
                            MediaQuery.textScalerOf(context).scale(12) <= 16;
                        return horizontal
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                    Expanded(flex: 6, child: identity),
                                    const SizedBox(width: 8),
                                    Expanded(flex: 5, child: amount)
                                  ])
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    identity,
                                    const SizedBox(height: 6),
                                    Align(
                                        alignment: Alignment.centerRight,
                                        child: amount)
                                  ]);
                      }),
                      SizedBox(height: progressGap),
                      BudgetUsageProgress(
                          key: progressKey ??
                              ValueKey('hero-progress-${b.budget.id}'),
                          value:
                              isVisible && valid ? b.ratio.clamp(0.0, 1.0) : 0,
                          color:
                              isVisible && b.remaining < 0 ? s.amount(b) : tone,
                          track: s.border),
                      SizedBox(height: captionGap),
                      ConstrainedBox(
                          constraints: BoxConstraints(
                              minWidth: double.infinity,
                              minHeight: featured
                                  ? 0
                                  : MediaQuery.textScalerOf(context).scale(10) *
                                          2.8 +
                                      2),
                          child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 8,
                              runSpacing: 2,
                              children: [
                                Text(
                                    !isVisible
                                        ? 'Tiến độ đang ẩn'
                                        : valid
                                            ? 'Đã dùng ${budgetUsageLabel(b)} hạn mức'
                                            : budgetUsageLabel(b),
                                    style: TextStyle(
                                        fontSize: 10,
                                        height: 1.4,
                                        color: s.muted)),
                                Text(
                                    b.rhythm == SpendingRhythm.weekly
                                        ? 'Trong tuần'
                                        : 'Trong kỳ',
                                    style: TextStyle(
                                        fontSize: 10,
                                        height: 1.4,
                                        color: s.muted)),
                              ])),
                    ]))));
  }
}
