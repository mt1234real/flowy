import '../../widgets/preserved_balance_tumbler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/animation/app_animation_policy.dart';
import '../../core/feedback/app_feedback.dart';
import '../../data/database.dart';
import '../../screens/ledger_screen.dart' show cycleStartDaysByMonthProvider;
import '../../screens/budget_screen.dart'
    show resolveBudgetWindow, showInsightsBudgetEditor;
import '../../theme/app_theme.dart';
import '../../widgets/currency_text.dart';
import '../../widgets/sliding_segmented_bar.dart';
import '../../screens/category_manager_screen.dart' show resolveAppIcon;
import 'insights_surfaces.dart';
import '../../widgets/quick_entry_sheet.dart';
import 'insights_data.dart';
import 'insights_donut.dart';
import 'scheme_editor_screen.dart';

String _money(double amount) =>
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(amount);
String _dates(InsightsWindow window) =>
    '${DateFormat('dd/MM/yyyy').format(window.start)} – ${DateFormat('dd/MM/yyyy').format(window.end.subtract(const Duration(days: 1)))}';

class SpendingInsightsScreen extends ConsumerStatefulWidget {
  final InsightsPeriod initialPeriod;
  final DateTime? anchor;
  final Set<String> initialWallets;
  final CategoryType initialType;
  final String? schemeId, title, detailCategoryId;
  final Set<String>? categoryIds;
  final InsightsWindow? customWindow;
  final bool leaf;
  final bool revealAmounts;
  final String classification;
  final Color? detailColor;
  const SpendingInsightsScreen(
      {super.key,
      this.initialPeriod = InsightsPeriod.cycle,
      this.anchor,
      this.initialWallets = const {},
      this.initialType = CategoryType.expense,
      this.schemeId,
      this.title,
      this.detailCategoryId,
      this.categoryIds,
      this.customWindow,
      this.leaf = false,
      this.revealAmounts = false,
      this.classification = 'all',
      this.detailColor});
  @override
  ConsumerState<SpendingInsightsScreen> createState() =>
      _SpendingInsightsScreenState();
}

class _SpendingInsightsScreenState
    extends ConsumerState<SpendingInsightsScreen> {
  late InsightsPeriod _period;
  late DateTime _anchor;
  late Set<String> _wallets;
  late CategoryType _type;
  String? _schemeId, _selected;
  InsightsWindow? _custom;
  int _metric = 0;
  int _sort = 0;
  int _periodReset = 0;
  bool _sessionReveal = false;
  String _classification = 'all';
  bool _othersExpanded = false;
  bool get _detail => widget.categoryIds != null;
  @override
  void initState() {
    super.initState();
    _sessionReveal = widget.revealAmounts;
    _period = widget.initialPeriod;
    _anchor = widget.anchor ?? DateTime.now();
    _wallets = {...widget.initialWallets};
    _type = widget.initialType;
    _schemeId = widget.schemeId;
    _custom = widget.customWindow;
  }

  String _display(double amount) => _money(amount);
  String _change(double current, double previous) {
    final difference = current - previous;
    if (difference == 0) return 'Không đổi · ${_display(0)}';
    final percent = previous > 0
        ? '${(difference.abs() / previous * 100).toStringAsFixed(0)}%'
        : 'Mới phát sinh';
    return '${difference > 0 ? '↑' : '↓'} $percent · ${difference > 0 ? '+' : '−'}${_display(difference.abs())}';
  }

  Future<T?> _sheet<T>(String title,
          Widget Function(BuildContext, ScrollController) content) =>
      AppAnimationPolicy.showFluidSheet<T>(
          context: context,
          builder: (sheetContext, controller) => Material(
              color: Theme.of(sheetContext).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                  top: false,
                  child: SizedBox(
                      height: MediaQuery.sizeOf(sheetContext).height * .72,
                      child: Column(children: [
                        Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800))),
                        Expanded(child: content(sheetContext, controller!))
                      ])))));

  Future<void> _chooseWallets(List<Wallet> wallets) async {
    final draft = {..._wallets};
    final result = await _sheet<Set<String>>(
        'Chọn ví',
        (ctx, scroll) => StatefulBuilder(
            builder: (ctx, update) => ListView(
                    controller: scroll,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      CheckboxListTile(
                          title: const Text('Tất cả ví'),
                          value: draft.isEmpty,
                          onChanged: (_) => update(draft.clear)),
                      for (final wallet in wallets)
                        CheckboxListTile(
                            title: Text(wallet.name),
                            subtitle: wallet.isArchived
                                ? const Text('Đã lưu trữ')
                                : null,
                            value: draft.contains(wallet.id),
                            onChanged: (selected) => update(() {
                                  selected == true
                                      ? draft.add(wallet.id)
                                      : draft.remove(wallet.id);
                                })),
                      TextButton(
                          onPressed: () => update(draft.clear),
                          child: const Text('Đặt lại')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, draft),
                          child: const Text('Áp dụng')),
                    ])));
    if (result == null && mounted) setState(() => _periodReset++);
    if (result != null && mounted) {
      HapticFeedback.lightImpact();
      setState(() {
        _wallets = result;
        _selected = null;
      });
    }
  }

  Future<void> _chooseDates() async {
    final result = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        initialDateRange: _custom == null
            ? null
            : DateTimeRange(
                start: _custom!.start,
                end: _custom!.end.subtract(const Duration(days: 1))),
        helpText: 'Chọn khoảng thời gian',
        saveText: 'Áp dụng');
    if (result == null && mounted) setState(() => _periodReset++);
    if (result != null && mounted) {
      HapticFeedback.lightImpact();
      setState(() {
        _custom = InsightsWindow(result.start,
            DateTime(result.end.year, result.end.month, result.end.day + 1));
        _period = InsightsPeriod.custom;
        _selected = null;
      });
    }
  }

  Future<void> _editScheme(List<Category> categories,
      [ClassificationScheme? scheme]) async {
    final id = await Navigator.of(context).push<String>(
        PreservedMaterialPageRoute(
            builder: (_) =>
                SchemeEditorScreen(scheme: scheme, categories: categories)));
    if (id != null && mounted) {
      setState(() {
        _schemeId = id;
        _selected = null;
      });
    }
  }

  Future<void> _chooseScheme(InsightsData data) async {
    final schemes = ref.read(classificationSchemesProvider);
    final choice = await _sheet<String>(
        'Phân tích theo',
        (ctx, scroll) => ListView(
                controller: scroll,
                physics: const ClampingScrollPhysics(),
                children: [
                  ListTile(
                      title: const Text('Danh mục'),
                      trailing:
                          _schemeId == null ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(ctx, 'category')),
                  ListTile(
                      title: const Text('Phân bổ theo ví'),
                      onTap: () => Navigator.pop(ctx, '__wallets')),
                  ListTile(
                      title: const Text('Thiết yếu / Tùy ý'),
                      onTap: () => Navigator.pop(ctx, '__nature')),
                  for (final scheme in schemes)
                    ListTile(
                        title: Text(scheme.name),
                        trailing: _schemeId == scheme.id
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.pop(ctx, scheme.id)),
                  const Divider(),
                  const ListTile(title: Text('Thêm góc nhìn (tùy chọn)')),
                  for (final preset in [
                    'Thiết yếu / Tùy ý',
                    'Cố định / Linh hoạt',
                    'Bills / Daily / Lifestyle'
                  ])
                    ListTile(
                        leading: const Icon(Icons.add),
                        title: Text(preset),
                        onTap: () => Navigator.pop(ctx, 'preset:$preset')),
                  ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Tạo góc nhìn mới'),
                      onTap: () => Navigator.pop(ctx, 'create')),
                ]));
    if (choice == null || !mounted) return;
    HapticFeedback.selectionClick();
    if (choice == 'create') {
      await _editScheme(data.categories);
    } else if (choice.startsWith('preset:')) {
      final name = choice.substring(7);
      final names = name.split(' / ');
      await _editScheme(
          data.categories,
          ClassificationScheme(
              id: 'scheme_${DateTime.now().microsecondsSinceEpoch}',
              name: name,
              isSystemPreset: true,
              groups: [
                for (var i = 0; i < names.length; i++)
                  ClassificationGroup('g$i', names[i], insightsColors[i])
              ]));
    } else {
      setState(() {
        _schemeId = choice == 'category' ? null : choice;
        _selected = null;
      });
    }
  }

  Future<void> _deleteScheme(ClassificationScheme scheme) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Xóa góc nhìn?'),
                content: Text(
                    'Xóa “${scheme.name}”. Các danh mục và giao dịch vẫn được giữ nguyên.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Xóa'))
                ]));
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(classificationSchemesProvider.notifier).remove(scheme.id);
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _schemeId = null;
          _selected = null;
        });
      }
    } catch (error) {
      debugPrint('Scheme delete failed: $error');
      if (mounted) {
        AppFeedback.showError(
            context, 'Chưa xóa được góc nhìn. Vui lòng thử lại.');
      }
    }
  }

  void _openBucket(InsightsBucket bucket, bool fromScheme) {
    Navigator.of(context).push(PreservedMaterialPageRoute(
        builder: (_) => SpendingInsightsScreen(
            initialPeriod: _period,
            anchor: _anchor,
            initialWallets: bucket.id.startsWith('wallet:')
                ? {bucket.id.substring(7)}
                : _wallets,
            initialType: _type,
            customWindow: _custom,
            title: bucket.name,
            detailCategoryId: fromScheme ? null : bucket.id,
            categoryIds: bucket.categoryIds,
            leaf: !fromScheme,
            revealAmounts: _sessionReveal,
            classification: bucket.id.startsWith('nature:')
                ? bucket.id.substring(7)
                : (_classification != 'all'
                    ? _classification
                    : widget.classification),
            detailColor: bucket.color)));
  }

  Widget _card(Widget child) => InsightsGlass(child: child);
  String _walletLabel(List<Wallet> wallets) => _wallets.isEmpty
      ? 'Tất cả ví'
      : _wallets.length > 1
          ? '${_wallets.length} ví'
          : wallets
                  .where((w) => _wallets.contains(w.id))
                  .map((w) => w.name)
                  .firstOrNull ??
              'Ví đã chọn';
  void _retry() {
    ref.invalidate(insightsTransactionsProvider);
    ref.invalidate(insightsCategoriesProvider);
    ref.invalidate(insightsWalletsProvider);
    ref.invalidate(insightsBudgetsProvider);
    ref.invalidate(insightsDataProvider);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(insightsDataProvider);
    final accent = ref.watch(accentPresetProvider);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return BalancePrivacyScope(
        visible: _sessionReveal,
        child: DecoratedBox(
            decoration: BoxDecoration(
                gradient: RadialGradient(
                    center: const Alignment(.6, -.95),
                    radius: 1.2,
                    colors: [
                  Color.alphaBlend(
                      accent.primary.withValues(alpha: dark ? .06 : .065),
                      (dark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF7FAF9))),
                  (dark ? const Color(0xFF0F172A) : const Color(0xFFF7FAF9))
                ])),
            child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    toolbarHeight: 56 +
                        (MediaQuery.textScalerOf(context).scale(20) - 20) * 2,
                    leadingWidth: 62,
                    leading: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Center(
                            child: IconButton.filledTonal(
                                style: IconButton.styleFrom(
                                    backgroundColor: theme.colorScheme.surface
                                        .withValues(alpha: .8)),
                                tooltip: 'Quay lại',
                                onPressed: () => Navigator.maybePop(context),
                                icon: const Icon(Icons.arrow_back_rounded,
                                    size: 21)))),
                    actions: [
                      if (!_detail && data.hasValue)
                        Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: SizedBox(
                                width: 98,
                                child: TextButton(
                                    style: TextButton.styleFrom(
                                        backgroundColor: theme
                                            .colorScheme.surface
                                            .withValues(alpha: .85),
                                        foregroundColor:
                                            theme.colorScheme.onSurface,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        minimumSize: const Size(44, 44),
                                        shape: const StadiumBorder()),
                                    onPressed: () => _chooseWallets(
                                        data.requireValue.wallets),
                                    child: Text(
                                        '${_walletLabel(data.requireValue.wallets)} ▾',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600)))))
                    ],
                    title: Text(widget.title ?? 'Phân tích chi tiêu',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800))),
                body: SafeArea(
                    child: data.when(
                  skipLoadingOnRefresh: true,
                  loading: () => InsightsReveal(
                      pulse: true,
                      child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            for (final height in [
                              44.0,
                              72.0,
                              240.0,
                              72.0,
                              72.0
                            ])
                              Container(
                                  height: height,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: .06),
                                      borderRadius: BorderRadius.circular(22)))
                          ])),
                  error: (error, stack) {
                    debugPrint('Insights query failed: $error');
                    return Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                      'Không thể tải phân tích chi tiêu.\nDữ liệu của bạn vẫn được giữ nguyên.',
                                      textAlign: TextAlign.center),
                                  TextButton(
                                      onPressed: _retry,
                                      child: const Text('Thử lại'))
                                ])));
                  },
                  data: _content,
                )))));
  }

  Widget _content(InsightsData data) {
    final cycles = ref.watch(cycleStartDaysByMonthProvider);
    final window = insightsWindow(_period, _anchor, cycles, custom: _custom);
    final previous = insightsWindow(_period, _anchor, cycles,
        custom: _custom, previous: true);
    final schemes = ref.watch(classificationSchemesProvider);
    final matches = schemes.where((s) => s.id == _schemeId);
    final scheme = matches.isEmpty ? null : matches.first;
    final needsScheme = schemes
        .where((s) =>
            s.groups.any((g) => g.name == 'Thiết yếu') &&
            s.groups.any((g) => g.name == 'Tùy ý'))
        .firstOrNull;
    String classification(Transaction t) =>
        insightsClassification(t, needsScheme);
    final scopedTransactions = widget.classification == 'all'
        ? data.transactions
        : data.transactions
            .where((t) => classification(t) == widget.classification)
            .toList();
    final report = buildInsightsReport(
        transactions: scopedTransactions,
        categories: data.categories,
        window: window,
        previousWindow: previous,
        type: _type,
        wallets: _wallets,
        scheme: scheme,
        categoryIds: widget.categoryIds,
        groupByLeaf: widget.leaf,
        groupByNature: _schemeId == '__nature',
        natureScheme: needsScheme,
        groupByWallet: _schemeId == '__wallets',
        walletRecords: data.wallets);
    final slices = report.slices;
    final selected = slices.where((s) => s.id == _selected);
    final active = selected.isEmpty ? null : selected.first;
    final classificationTotals = <String, double>{
      'needs': 0,
      'wants': 0,
      'unknown': 0
    };
    for (final transaction in report.current) {
      final key = classification(transaction);
      classificationTotals[key] =
          classificationTotals[key]! + transaction.amount;
    }
    final filteredReport = _classification == 'all'
        ? report
        : buildInsightsReport(
            transactions: scopedTransactions
                .where((t) => classification(t) == _classification)
                .toList(),
            categories: data.categories,
            window: window,
            previousWindow: previous,
            type: _type,
            wallets: _wallets,
            scheme: scheme,
            categoryIds: widget.categoryIds,
            groupByLeaf: widget.leaf,
            groupByNature: _schemeId == '__nature',
            natureScheme: needsScheme,
            groupByWallet: _schemeId == '__wallets',
            walletRecords: data.wallets);
    final ranked = filteredReport.buckets.where((b) => b.amount > 0).toList();
    final topIds = report.buckets
        .where((b) => b.amount > 0)
        .take(5)
        .map((b) => b.id)
        .toSet();
    final top = ranked.where((b) => topIds.contains(b.id)).toList();
    final tail = ranked.where((b) => !topIds.contains(b.id)).toList();
    if (_sort == 1) {
      top.sort(
          (a, b) => b.transactions.length.compareTo(a.transactions.length));
    }
    if (_sort == 2) {
      top.sort(
          (a, b) => (b.amount - b.previous).compareTo(a.amount - a.previous));
    }
    final other = InsightsBucket(
        id: '__other',
        name: 'Các nhóm khác',
        color: const Color(0xFF94A3B8),
        categoryIds: tail.expand((b) => b.categoryIds).toSet(),
        transactions: tail.expand((b) => b.transactions).toList(),
        previous: tail.fold(0, (v, b) => v + b.previous));
    final accent = ref.watch(accentPresetProvider).primary;
    final expense = _type == CategoryType.expense;
    final unclassified = report.buckets
        .where((b) => b.id == '__unclassified')
        .fold(0.0, (sum, b) => sum + b.amount);
    final delta = report.total - report.previousTotal;
    final detailCategory = data.categories
        .where((c) => c.id == widget.detailCategoryId)
        .firstOrNull;
    final hasBreakdown = !_detail ||
        !widget.leaf ||
        report.buckets.any((b) => b.id != widget.detailCategoryId);
    final comparison = report.previousTotal == 0
        ? (report.total == 0
            ? 'Chưa có dữ liệu để so sánh'
            : 'Kỳ trước chưa có giao dịch')
        : '${expense ? 'Chi tiêu' : 'Thu nhập'} ${delta == 0 ? 'không đổi' : delta > 0 ? 'tăng' : 'giảm'}${delta == 0 ? '' : ' ${(delta.abs() / report.previousTotal * 100).toStringAsFixed(0)}%'} so với kỳ trước';
    final coverage = report.total <= 0
        ? 1.0
        : 1 -
            (scheme != null ? unclassified : classificationTotals['unknown']!) /
                report.total;
    final showCoverage = scheme != null || _schemeId == '__nature';
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (!_detail) ...[
            _periodControl(),
            const SizedBox(height: 8),
            Row(children: [
              PopupMenuButton<CategoryType>(
                  tooltip: 'Loại dòng tiền',
                  initialValue: _type,
                  onSelected: (value) => setState(() {
                        _type = value;
                        _classification = 'all';
                        _selected = null;
                      }),
                  itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: CategoryType.expense,
                            child: Text('Chi tiêu')),
                        PopupMenuItem(
                            value: CategoryType.income, child: Text('Thu nhập'))
                      ],
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(expense ? 'Chi tiêu' : 'Thu nhập',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const Icon(Icons.expand_more_rounded, size: 18)
                      ]))),
              const Spacer(),
              IconButton(
                  tooltip: _sessionReveal
                      ? 'Ẩn số liệu'
                      : 'Hiện số liệu trong phiên này',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _sessionReveal = !_sessionReveal);
                  },
                  icon: Icon(
                      _sessionReveal
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 19)),
              if (_wallets.isNotEmpty ||
                  _period != widget.initialPeriod ||
                  _custom != widget.customWindow ||
                  _schemeId != null ||
                  _type != widget.initialType ||
                  _classification != 'all')
                TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                    onPressed: () => setState(() {
                          _wallets = {};
                          _period = widget.initialPeriod;
                          _custom = widget.customWindow;
                          _schemeId = null;
                          _type = CategoryType.expense;
                          _selected = null;
                          _classification = 'all';
                          _othersExpanded = false;
                        }),
                    child:
                        const Text('Đặt lại', style: TextStyle(fontSize: 12))),
            ]),
          ],
          if (_period == InsightsPeriod.custom || _detail)
            Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: Text(
                    '${_dates(window)}${_detail ? ' • ${_walletLabel(data.wallets)}' : ''}',
                    style: TextStyle(
                        fontSize: 11.5,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant))),
          InsightsTrendRibbon(
              isVisible: _sessionReveal,
              delta: delta,
              text: comparison,
              amount:
                  '${delta == 0 ? 'Không đổi' : delta > 0 ? 'Nhiều hơn' : 'Ít hơn'} ${_display(delta.abs())}',
              expense: expense,
              details: 'So với ${_dates(previous)}'),
          if (!_detail) ...[
            LayoutBuilder(builder: (context, constraints) {
              final picker = _schemePicker(data, scheme);
              final label = Text('Phân tích theo',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant));
              if (constraints.maxWidth < 280 ||
                  MediaQuery.textScalerOf(context).scale(13) > 17) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [label, const SizedBox(height: 8), picker]);
              }
              return Row(children: [
                label,
                const SizedBox(width: 12),
                Expanded(child: picker)
              ]);
            }),
            const SizedBox(height: 18),
          ],
          if (report.current.isEmpty)
            _card(Column(children: [
              Icon(Icons.spa_outlined,
                  size: 48, color: accent.withValues(alpha: .55)),
              const SizedBox(height: 16),
              Text(expense
                  ? 'Chưa có khoản chi trong khoảng thời gian này.'
                  : 'Chưa có khoản thu trong khoảng thời gian này.'),
              const SizedBox(height: 8),
              const Text(
                  'Khi bạn bắt đầu ghi chép, cơ cấu dòng tiền sẽ xuất hiện tại đây.'),
              TextButton(
                  onPressed: () => QuickEntrySheet.show(context,
                      initialContextDate: window.start),
                  child: const Text('+ Ghi chép giao dịch'))
            ]))
          else
            _donutCard(report, slices, active, expense),
          if (showCoverage && report.total > 0)
            _coverageStatus(
                coverage,
                () => _editScheme(
                    data.categories,
                    scheme ??
                        needsScheme ??
                        ClassificationScheme(
                            id: 'scheme_${DateTime.now().microsecondsSinceEpoch}',
                            name: 'Thiết yếu / Tùy ý',
                            isSystemPreset: true,
                            groups: const [
                              ClassificationGroup(
                                  'needs', 'Thiết yếu', 0xFF10B981),
                              ClassificationGroup('wants', 'Tùy ý', 0xFFFF6B8B)
                            ]))),
          if (_detail && detailCategory != null && expense)
            _detailBudgetCard(
                detailCategory, data, window, cycles, report.total),
          if (hasBreakdown) ...[
            _metricControl(),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: Text(expense ? 'Chi theo nhóm' : 'Thu theo nhóm',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800))),
              PopupMenuButton<int>(
                  tooltip: 'Sắp xếp nhóm',
                  initialValue: _sort,
                  onSelected: (value) => setState(() => _sort = value),
                  itemBuilder: (_) => const [
                        PopupMenuItem(value: 0, child: Text('Chi nhiều nhất')),
                        PopupMenuItem(value: 1, child: Text('Nhiều giao dịch')),
                        PopupMenuItem(value: 2, child: Text('Tăng nhiều nhất'))
                      ],
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 6),
                      child: Text(
                          '${_sort == 0 ? 'Chi nhiều nhất' : _sort == 1 ? 'Nhiều giao dịch' : 'Tăng nhiều nhất'} ⌄',
                          style: const TextStyle(fontSize: 11.5)))),
              if (expense)
                PopupMenuButton<String>(
                    tooltip: 'Lọc phân loại',
                    initialValue: _classification,
                    onSelected: (value) => setState(() {
                          _classification = value;
                          _selected = null;
                        }),
                    itemBuilder: (_) => [
                          for (final entry in const {
                            'all': 'Tất cả',
                            'needs': 'Thiết yếu',
                            'wants': 'Tùy ý',
                            'unknown': 'Chưa phân loại'
                          }.entries)
                            PopupMenuItem(
                                value: entry.key, child: Text(entry.value))
                        ],
                    icon: Icon(Icons.filter_list_rounded,
                        size: 18,
                        color: _classification == 'all'
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : accent)),
            ]),
            const SizedBox(height: 12),
            InsightsReveal(
                key: ValueKey(
                    '$_schemeId/$_period/$_type/$_classification/${_wallets.join()}/${window.start}/${window.end}'),
                child: Column(children: [
                  for (final bucket in top)
                    _bucketTile(
                        bucket,
                        report,
                        data,
                        window,
                        cycles,
                        scheme != null ||
                            _schemeId == '__wallets' ||
                            _schemeId == '__nature',
                        active),
                  if (tail.isNotEmpty) ...[
                    InsightsGlass(
                        padding: const EdgeInsets.all(4),
                        child: ListTile(
                            leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(colors: [
                                      const Color(0xFF94A3B8)
                                          .withValues(alpha: .14),
                                      const Color(0xFF64748B)
                                          .withValues(alpha: .14)
                                    ])),
                                child: const Icon(Icons.more_horiz,
                                    color: Color(0xFF64748B))),
                            title: const Text('Các nhóm khác'),
                            subtitle: CurrencyText(
                                '${_display(other.amount)} • ${report.total > 0 ? (other.amount / report.total * 100).toStringAsFixed(1) : '0'}% • Xem ${tail.length} nhóm',
                                isVisible: _sessionReveal),
                            trailing: Icon(_othersExpanded
                                ? Icons.expand_less
                                : Icons.expand_more),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _othersExpanded = !_othersExpanded;
                                _selected = _othersExpanded ? '__other' : null;
                              });
                            })),
                    InsightsAccordion(
                        expanded: _othersExpanded,
                        child: Column(children: [
                          for (final bucket in tail)
                            _bucketTile(
                                bucket,
                                report,
                                data,
                                window,
                                cycles,
                                scheme != null ||
                                    _schemeId == '__wallets' ||
                                    _schemeId == '__nature',
                                active,
                                drillOnTap: true),
                        ])),
                  ],
                  if (ranked.isEmpty && report.current.isNotEmpty)
                    const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Chưa có giao dịch thuộc nhóm này.')),
                ])),
          ],
          if (!_detail &&
              expense &&
              report.total > 0 &&
              report.buckets.isNotEmpty &&
              report.buckets.first.amount / report.total > .35)
            Builder(builder: (context) {
              final dominant = report.buckets.first;
              final amounts = <String, double>{};
              for (final transaction in dominant.transactions) {
                amounts.update(
                    transaction.categoryId, (v) => v + transaction.amount,
                    ifAbsent: () => transaction.amount);
              }
              final candidates = amounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final category = data.categories
                      .where((c) => c.id == dominant.id)
                      .firstOrNull ??
                  data.categories
                      .where((c) =>
                          candidates.isNotEmpty && c.id == candidates.first.key)
                      .firstOrNull;
              if (category == null) return const SizedBox.shrink();
              final next = DateTime(window.start.year, window.start.month + 1);
              final budget = data.budgets
                  .where((b) =>
                      b.categoryId == category.id &&
                      b.periodMonth.year == next.year &&
                      b.periodMonth.month == next.month)
                  .firstOrNull;
              return _card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${dominant.name} chiếm ${(dominant.amount / report.total * 100).toStringAsFixed(0)}% tổng chi.'),
                    TextButton(
                        onPressed: () => showInsightsBudgetEditor(context,
                            category: category, anchor: next, budget: budget),
                        child:
                            Text('Đặt ngân sách ${category.name} cho kỳ tới')),
                  ]));
            }),
          if (_detail) ...[
            const SizedBox(height: 12),
            const Text('Giao dịch',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            for (final transaction in report.current)
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(transaction.note?.trim().isNotEmpty == true
                      ? transaction.note!
                      : data.categories
                              .where((c) => c.id == transaction.categoryId)
                              .map((c) => c.name)
                              .firstOrNull ??
                          'Giao dịch'),
                  subtitle: Text(DateFormat('dd/MM/yyyy • HH:mm')
                      .format(transaction.date)),
                  trailing: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .38),
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CurrencyText(_display(transaction.amount),
                              isVisible: _sessionReveal,
                              style: currencyTextStyle(
                                  context,
                                  const TextStyle(
                                      fontWeight: FontWeight.w800))))),
                  onTap: () => QuickEntrySheet.show(context,
                      initialTransaction: transaction)),
          ],
        ]);
  }

  Widget _periodControl() {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final labels = <InsightsPeriod, String>{
      InsightsPeriod.cycle: 'Chu kỳ',
      InsightsPeriod.month: 'Tháng',
      InsightsPeriod.days7: '7 ngày qua',
      if (_period == InsightsPeriod.quarter) InsightsPeriod.quarter: 'Quý',
      if (_period == InsightsPeriod.year) InsightsPeriod.year: 'Năm',
      InsightsPeriod.custom: '',
    };
    return LayoutBuilder(builder: (context, constraints) {
      final scaled = MediaQuery.textScalerOf(context).scale(12) / 12;
      final width = (labels.length * 68.0 * scaled)
          .clamp(constraints.maxWidth, double.infinity);
      return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
              width: width,
              child: SlidingSegmentedBar<InsightsPeriod>(
                  key: ValueKey(_periodReset),
                  selectedValue: _period,
                  height: 35,
                  fontSize: 11,
                  duration: const Duration(milliseconds: 200),
                  overshootPx: 0,
                  trackColor: theme.colorScheme.surface.withValues(alpha: .75),
                  trackBorderColor: Colors.transparent,
                  indicatorColor: accent.withValues(alpha: .13),
                  indicatorBorderColor: Colors.transparent,
                  selectedTextColor: accent,
                  mutedTextColor: theme.colorScheme.onSurfaceVariant,
                  items: [
                    for (final entry in labels.entries)
                      SlidingSegmentedItem(
                          value: entry.key,
                          label: entry.value,
                          trailing: entry.key == InsightsPeriod.custom
                              ? IconButton(
                                  tooltip: 'Chọn khoảng ngày',
                                  onPressed: _chooseDates,
                                  icon: const Icon(
                                      Icons.calendar_month_outlined,
                                      size: 15))
                              : null)
                  ],
                  onValueChanged: (period) {
                    if (period == InsightsPeriod.custom) {
                      _chooseDates();
                      return;
                    }
                    setState(() {
                      _period = period;
                      _selected = null;
                    });
                  })));
    });
  }

  Widget _metricControl() {
    final accent = ref.watch(accentPresetProvider).primary;
    return SlidingSegmentedBar<int>(
        selectedValue: _metric,
        height: 40,
        trackColor: Colors.transparent,
        trackBorderColor: Colors.transparent,
        indicatorColor: accent.withValues(alpha: .11),
        indicatorBorderColor: Colors.transparent,
        selectedTextColor: accent,
        fontSize: 11.5,
        overshootPx: 0,
        items: const [
          SlidingSegmentedItem(value: 0, label: 'Số tiền (₫)'),
          SlidingSegmentedItem(value: 1, label: 'Tỷ trọng (%)'),
          SlidingSegmentedItem(value: 2, label: '₫ / ngày')
        ],
        onValueChanged: (value) => setState(() => _metric = value));
  }

  Widget _coverageStatus(double coverage, VoidCallback onClassify) {
    final accent = ref.watch(accentPresetProvider).primary;
    final label =
        'Đã phân loại ${(coverage * 100).toStringAsFixed(0)}% chi tiêu';
    if (coverage >= .8) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            Icon(Icons.circle, size: 6, color: accent),
            const SizedBox(width: 7),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant))),
            IconButton(
                onPressed: onClassify,
                tooltip: 'Phân loại danh mục',
                icon: const Icon(Icons.tune, size: 16))
          ]));
    }
    return InsightsGlass(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const Text('Hoàn tất để hiểu rõ cơ cấu chi tiêu.',
              style: TextStyle(fontSize: 12)),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  onPressed: onClassify, child: const Text('Phân loại ›'))),
        ]));
  }

  Widget _schemePicker(InsightsData data, ClassificationScheme? scheme) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
          child: TextButton(
              style: TextButton.styleFrom(
                  backgroundColor:
                      theme.colorScheme.surface.withValues(alpha: .8),
                  foregroundColor: theme.colorScheme.onSurface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: const StadiumBorder()),
              onPressed: () => _chooseScheme(data),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                    child: Text(
                        scheme?.name ??
                            (_schemeId == '__wallets'
                                ? 'Phân bổ theo ví'
                                : _schemeId == '__nature'
                                    ? 'Thiết yếu / Tùy ý'
                                    : 'Danh mục'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700))),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded, size: 18)
              ]))),
      if (scheme != null)
        PopupMenuButton<String>(
            tooltip: 'Tùy chọn góc nhìn',
            icon: Icon(Icons.more_horiz_rounded,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
            itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'edit', child: Text('Chỉnh sửa góc nhìn')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa góc nhìn'))
                ],
            onSelected: (action) {
              if (action == 'edit') {
                _editScheme(data.categories, scheme);
              } else {
                _deleteScheme(scheme);
              }
            }),
    ]);
  }

  Widget _donutCard(InsightsReport report, List<InsightsBucket> slices,
      InsightsBucket? active, bool expense) {
    final theme = Theme.of(context);
    return InsightsGlass(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 312 &&
              MediaQuery.textScalerOf(context).scale(12) <= 15;
          final diameter =
              (horizontal ? constraints.maxWidth * .55 : constraints.maxWidth)
                  .clamp(0.0, horizontal ? 190.0 : 205.0);
          final chart = InsightsDonut(
              isVisible: _sessionReveal,
              diameter: diameter,
              slices: slices,
              total: report.total,
              selected: active?.id,
              label: active?.name ?? (expense ? 'TỔNG ĐÃ CHI' : 'TỔNG ĐÃ THU'),
              amount: _display(active?.amount ?? report.total),
              supporting: active == null
                  ? '${report.current.length} giao dịch'
                  : '${(active.amount / report.total * 100).toStringAsFixed(1)}% • ${active.transactions.length} giao dịch',
              onSelect: (id) => setState(() => _selected = id));
          final legend = Column(mainAxisSize: MainAxisSize.min, children: [
            for (final slice in slices)
              Semantics(
                  button: true,
                  excludeSemantics: true,
                  selected: active?.id == slice.id,
                  label:
                      '${slice.name}, ${_sessionReveal ? _display(slice.amount) : 'Số tiền đang ẩn'}, ${(slice.amount / report.total * 100).toStringAsFixed(1)} phần trăm',
                  child: Material(
                      color: active?.id == slice.id
                          ? theme.colorScheme.primary.withValues(alpha: .07)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selected =
                                active?.id == slice.id ? null : slice.id);
                          },
                          child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 4),
                              child: Row(children: [
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: insightsGradient(
                                                slice.id,
                                                slice.name,
                                                slices.indexOf(slice))
                                            .first,
                                        borderRadius:
                                            BorderRadius.circular(2.5))),
                                const SizedBox(width: 7),
                                Expanded(
                                    child: Text(slice.name,
                                        style: TextStyle(
                                            fontSize: 12,
                                            height: 1.3,
                                            fontWeight: active?.id == slice.id
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color:
                                                theme.colorScheme.onSurface))),
                                const SizedBox(width: 5),
                                Text(
                                    '${(slice.amount / report.total * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: theme
                                            .colorScheme.onSurfaceVariant)),
                              ]))))),
          ]);
          if (horizontal) {
            return Row(children: [
              chart,
              const SizedBox(width: 8),
              Expanded(child: legend)
            ]);
          }
          return Column(children: [chart, const SizedBox(height: 16), legend]);
        }));
  }

  Widget _detailBudgetCard(Category category, InsightsData data,
      InsightsWindow window, Map<String, int> cycles, double spent) {
    final budget = data.budgets
        .where((b) =>
            b.categoryId == category.id &&
            b.periodMonth.year == window.start.year &&
            b.periodMonth.month == window.start.month)
        .firstOrNull;
    final range = budget == null ? null : resolveBudgetWindow(budget, cycles);
    final matches = range != null &&
        range.startDate == window.start &&
        range.endDate.add(const Duration(seconds: 1)) == window.end &&
        _wallets.isEmpty;
    final limit = budget?.amount ?? 0.0;
    return _card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ngân sách • ${category.name}',
          style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      if (budget == null)
        const Text('Bạn chưa đặt hạn mức cho danh mục này.')
      else ...[
        CurrencyText('Hạn mức: ${_display(limit)}', isVisible: _sessionReveal),
        if (matches && limit > 0) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
              value: (spent / limit).clamp(0, 1), minHeight: 4),
          const SizedBox(height: 8),
          Text('Đã dùng ${(spent / limit * 100).toStringAsFixed(0)}% hạn mức.'),
          CurrencyText(
              '${spent <= limit ? 'Còn' : 'Vượt'} ${_display((limit - spent).abs())}',
              isVisible: _sessionReveal),
        ] else if (range != null)
          Text(
              'Áp dụng ${DateFormat('dd/MM').format(range.startDate)} – ${DateFormat('dd/MM/yyyy').format(range.endDate)} · tất cả ví',
              style: const TextStyle(fontSize: 12)),
      ],
      TextButton(
          onPressed: () => showInsightsBudgetEditor(context,
              category: category, anchor: window.start, budget: budget),
          child: Text(budget == null ? 'Đặt hạn mức' : 'Điều chỉnh ngân sách')),
    ]));
  }

  Widget _bucketTile(
      InsightsBucket bucket,
      InsightsReport report,
      InsightsData data,
      InsightsWindow window,
      Map<String, int> cycles,
      bool grouped,
      InsightsBucket? active,
      {bool drillOnTap = false}) {
    if (drillOnTap) {
      return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          title: Text(bucket.name,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text('${bucket.transactions.length} giao dịch',
              style: const TextStyle(fontSize: 12)),
          trailing: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .36),
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: CurrencyText(_display(bucket.amount),
                      isVisible: _sessionReveal,
                      style: const TextStyle(fontWeight: FontWeight.w700)))),
          onTap: () {
            HapticFeedback.selectionClick();
            _openBucket(bucket, grouped);
          });
    }
    final budgets = data.budgets.where((b) {
      final range = resolveBudgetWindow(b, cycles);
      return (b.categoryId == bucket.id ||
              bucket.categoryIds.contains(b.categoryId)) &&
          range.startDate == window.start &&
          range.endDate.add(const Duration(seconds: 1)) == window.end;
    }).toList();
    // Prefer a parent budget to avoid adding its child limits a second time.
    final parentBudget =
        budgets.where((b) => b.categoryId == bucket.id).firstOrNull;
    final usedIds = bucket.transactions.map((t) => t.categoryId).toSet();
    final covered =
        usedIds.every((id) => budgets.any((b) => b.categoryId == id));
    final directBudgets =
        budgets.where((b) => usedIds.contains(b.categoryId)).toList();
    final hasOverlappingLimits = directBudgets.any((b) => data.categories.any(
        (c) =>
            c.id == b.categoryId &&
            directBudgets.any((parent) => parent.categoryId == c.parentId)));
    final limit = parentBudget?.amount ??
        (covered && !hasOverlappingLimits
            ? directBudgets.fold<double>(0.0, (sum, b) => sum + b.amount)
            : 0.0);
    final budgetVisible = _type == CategoryType.expense &&
        _wallets.isEmpty &&
        _schemeId != '__wallets' &&
        limit > 0;
    final largest = bucket.transactions.isEmpty
        ? null
        : bucket.transactions.reduce((a, b) => a.amount >= b.amount ? a : b);
    final category =
        data.categories.where((c) => c.id == bucket.id).firstOrNull;
    final theme = Theme.of(context);
    final colors = insightsGradient(
        bucket.id, bucket.name, report.buckets.indexOf(bucket));
    final tone = colors.first;
    final metric = _metric == 1
        ? '${report.total > 0 ? (bucket.amount / report.total * 100).toStringAsFixed(1) : '0'}%'
        : _metric == 2
            ? '${_display(bucket.amount / (window.days > 0 ? window.days : 1))} / ngày'
            : _display(bucket.amount);
    final share =
        report.total > 0 ? (bucket.amount / report.total).clamp(0.0, 1.0) : 0.0;
    final percent = '${(share * 100).toStringAsFixed(1)}%';
    final info =
        '${_change(bucket.amount, bucket.previous)}${budgetVisible ? '\n${(bucket.amount / limit * 100).toStringAsFixed(0)}% ngân sách · ${_display(limit)}' : ''}';
    final dark = theme.brightness == Brightness.dark;
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Tooltip(
            message: _sessionReveal ? info : 'Số tiền đang ẩn',
            child: Material(
                color: dark
                    ? const Color(0xFF1E2430).withValues(alpha: .9)
                    : Colors.white.withValues(alpha: .92),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: .045),
                        width: .8)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _openBucket(bucket, grouped);
                    },
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkResponse(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selected =
                                        _selected == bucket.id
                                            ? null
                                            : bucket.id);
                                  },
                                  child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                              colors: colors
                                                  .map((c) =>
                                                      c.withValues(alpha: .18))
                                                  .toList())),
                                      child: Icon(
                                          category == null
                                              ? Icons.donut_small
                                              : resolveAppIcon(category.icon),
                                          color: tone,
                                          size: 23))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    LayoutBuilder(
                                        builder: (context, constraints) {
                                      final title = Text(bucket.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700));
                                      final amount = PreservedBalanceTumbler(
                                          isVisible:
                                              _metric == 1 || _sessionReveal,
                                          realValue: metric,
                                          isCurrency: _metric != 1,
                                          height: 24,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800));
                                      if (constraints.maxWidth < 200 ||
                                          MediaQuery.textScalerOf(context)
                                                  .scale(14) >
                                              18) {
                                        return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              title,
                                              const SizedBox(height: 4),
                                              FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: amount)
                                            ]);
                                      }
                                      return Row(children: [
                                        Expanded(child: title),
                                        const SizedBox(width: 8),
                                        Flexible(
                                            child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: amount)),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right,
                                            size: 16)
                                      ]);
                                    }),
                                    const SizedBox(height: 4),
                                    Text(
                                        '$percent · ${bucket.transactions.length} giao dịch',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: theme
                                                .colorScheme.onSurfaceVariant)),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Expanded(
                                          child: Container(
                                              height: 7,
                                              decoration: BoxDecoration(
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: .07),
                                                  borderRadius:
                                                      BorderRadius.circular(9)),
                                              child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: FractionallySizedBox(
                                                      widthFactor: share,
                                                      child: DecoratedBox(
                                                          decoration: BoxDecoration(
                                                              gradient:
                                                                  LinearGradient(
                                                                      colors:
                                                                          colors),
                                                              borderRadius:
                                                                  BorderRadius.circular(9)),
                                                          child: const SizedBox.expand()))))),
                                      const SizedBox(width: 8),
                                      Text(percent,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme
                                                  .onSurfaceVariant))
                                    ]),
                                    if (largest != null) ...[
                                      const SizedBox(height: 7),
                                      CurrencyText(
                                          'Khoản lớn nhất: ${_display(largest.amount)}${largest.note?.trim().isNotEmpty == true ? ' · ${largest.note}' : ''}',
                                          isVisible: _sessionReveal,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme
                                                  .onSurfaceVariant)),
                                    ],
                                    if (_detail &&
                                        category != null &&
                                        _type == CategoryType.expense)
                                      TextButton(
                                          onPressed: () =>
                                              showInsightsBudgetEditor(context,
                                                  category: category,
                                                  anchor: window.start,
                                                  budget: parentBudget),
                                          child: const Text(
                                              'Điều chỉnh ngân sách')),
                                  ])),
                            ]))))));
  }
}
