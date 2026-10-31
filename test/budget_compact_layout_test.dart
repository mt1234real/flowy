import 'package:pfm_app/features/insights/spending_insights_screen.dart';
import 'package:pfm_app/features/insights/insights_data.dart';
import 'package:pfm_app/widgets/budget_insights_navigation.dart';
import 'package:pfm_app/features/insights/insights_donut.dart';
import 'dart:io';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/services/budget_spending_provider.dart';
import 'package:pfm_app/services/budget_spending.dart';
import 'package:pfm_app/widgets/pre_purchase_advisor_sheet.dart';
import 'package:pfm_app/screens/dashboard_screen.dart';
import 'package:pfm_app/widgets/category_icon_badge.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/dashboard_hero_card.dart';
import 'package:pfm_app/widgets/safe_to_spend_breakdown_sheet.dart';
import 'support/budget_ui_fixture.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late ValueNotifier<bool> visibleState;
  bool containerDisposed = false;
  final selectedDate = StateProvider<DateTime>((ref) => DateTime(2026, 10, 28));
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final family in [
      'PlusJakartaSans',
      'Lora',
      'BeVietnamPro',
      'Nunito',
      'Comfortaa'
    ]) {
      for (final v in [
        ('regular', 'Regular'),
        ('500', 'Medium'),
        ('600', 'SemiBold'),
        ('700', 'Bold')
      ]) {
        final loader = FontLoader('${family}_${v.$1}');
        loader.addFont(
            rootBundle.load('assets/google_fonts/$family-${v.$2}.ttf'));
        await loader.load();
      }
    }
  });
  tearDown(() async {
    visibleState.dispose();
    if (!containerDisposed) container.dispose();
    await db.close();
  });
  Future<void> mount(WidgetTester t,
      {bool fullDashboard = false,
      bool pinScenario = false,
      bool loadedInsights = false,
      bool weekly = false,
      bool period = true,
      bool visible = false,
      double width = 390,
      double scale = 1,
      bool dark = false,
      String font = 'Plus Jakarta Sans',
      double safeTop = 44,
      double keyboard = 0,
      AppAccentPreset accent = AppAccentPreset.grass,
      bool safeAncestor = false,
      bool loading = false,
      VoidCallback? vaultTap}) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    containerDisposed = false;
    SharedPreferences.setMockInitialValues({kPrefKeyAccentPreset: accent.name});
    visibleState = ValueNotifier(visible);
    db = await budgetUiDatabase(weekly: weekly, period: period);
    if (pinScenario) {
      for (final id in ['aa-needs', 'zz-obligations']) {
        await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: id, name: id, type: CategoryType.expense));
        final b = await db.into(db.budgets).insertReturning(
            BudgetsCompanion.insert(
                id: id,
                categoryId: id,
                amount: 600000,
                periodMonth: DateTime(2026, 10),
                cycleStartDay: const Value(1)));
        await saveBudgetRhythm(db, b,
            rhythm: SpendingRhythm.period,
            weekStart: 1,
            carryRule: 'none',
            pinned: id == 'zz-obligations');
      }
      final dashboard = db.watchDashboardFinancialSnapshot(
          DateTime(2026, 10), DateTime(2026, 11));
      final subscription = dashboard.listen((_) {});
      addTearDown(subscription.cancel);
      await dashboard.first;
    }
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      insightsDataProvider.overrideWith((ref) async {
        if (!loadedInsights) throw StateError('fixture offline');
        final d = await readBudgetSpendingData(db);
        return InsightsData(d.expenses, d.categories, d.wallets, d.budgets);
      }),
      sharedPreferencesProvider
          .overrideWithValue(await SharedPreferences.getInstance()),
      budgetSpendingDateProvider.overrideWith((ref) => ref.watch(selectedDate)),
      if (loading)
        budgetSpendingDataProvider
            .overrideWith((ref) => const Stream<BudgetSpendingData>.empty())
    ]);
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 844);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final page = Scaffold(
        body: SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 70, 18, 16),
                child: RepaintBoundary(
                    key: const ValueKey('capture'),
                    child: ValueListenableBuilder<bool>(
                        valueListenable: visibleState,
                        builder: (context, visible, _) => (safeAncestor
                            ? SafeArea(
                                child: DashboardHeroCard(
                                    isVisible: visible, onVaultTap: vaultTap))
                            : DashboardHeroCard(
                                isVisible: visible, onVaultTap: vaultTap)))))));
    final app = MaterialApp(
        theme: AppTheme.buildTheme(
            isDark: dark,
            accent: accent,
            fontName: fullDashboard ? 'Lora' : font,
            currencyFont:
                fullDashboard || loadedInsights ? 'Lora' : 'Be Vietnam Pro'),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: EdgeInsets.only(
                    top: safeTop, bottom: keyboard > 0 ? 0 : 24),
                viewPadding: EdgeInsets.only(top: safeTop, bottom: 24),
                viewInsets: EdgeInsets.only(bottom: keyboard)),
            child: child!),
        home: fullDashboard ? const DashboardScreen() : page);
    await t.pumpWidget(RepaintBoundary(
        key: const ValueKey('screen-capture'),
        child: UncontrolledProviderScope(container: container, child: app)));
    await t.pumpAndSettle();
  }

  Future<void> until(
      WidgetTester t, bool Function(BudgetSpendingOverview) ready) async {
    // Drift invalidation and Riverpod notifications originate in the test zone;
    // keep pumping that zone instead of awaiting its work inside runAsync.
    for (var frame = 0; frame < 100; frame++) {
      await t.pump(const Duration(milliseconds: 16));
      final current =
          container.read(budgetSpendingOverviewProvider).valueOrNull;
      if (current != null && ready(current)) {
        await t.pumpAndSettle();
        return;
      }
      await t.runAsync(() async {});
    }
    fail('Committed budget state did not reach the expected presentation');
  }

  Future<void> picture(WidgetTester t, String name,
      {bool screen = false}) async {
    final out = Platform.environment['FLOWY_UI_EVIDENCE'];
    if (out == null) return;
    // A nested boundary capture can dirty its ancestor's composited layer.
    // Flush that paint before a second, full-screen evidence capture.
    await t.pump(Duration.zero);
    final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(ValueKey(screen ? 'screen-capture' : 'capture')));
    await t.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await File('$out/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      img.dispose();
    });
  }

  for (final visible in [false, true]) {
    testWidgets('compact footer reports layout with visible=$visible',
        (t) async {
      await mount(t, visible: visible);
      await t.tap(find.text('Xem tất cả ngân sách'));
      await t.pumpAndSettle();
      final row = find.byKey(const ValueKey('budget-row-qa-period'));
      final summary =
          find.descendant(of: row, matching: find.byType(BudgetSummaryTile));
      final divider = find.descendant(of: row, matching: find.byType(Divider));
      final caption = find.descendant(of: summary, matching: find.byType(Wrap));
      final progress =
          find.byKey(const ValueKey('budget-summary-progress-qa-period'));
      final pin = find.descendant(of: row, matching: find.byType(IconButton));
      final analysis =
          find.descendant(of: row, matching: find.byType(TextButton));
      final cardRect = t.getRect(row), dividerRect = t.getRect(divider);
      final footerHeight = cardRect.bottom - dividerRect.top;
      final captionGap =
          t.getTopLeft(caption).dy - t.getBottomLeft(progress).dy;
      final dividerGap = dividerRect.top - t.getBottomLeft(caption).dy;
      final identity =
          find.descendant(of: summary, matching: find.byType(LayoutBuilder));
      final identityGap =
          t.getTopLeft(progress).dy - t.getBottomLeft(identity).dy;
      expect(identityGap, closeTo(20, .01));
      expect(
          find.descendant(of: summary, matching: find.text('Tiến độ đang ẩn')),
          visible ? findsNothing : findsOneWidget);
      debugPrint(
          'BUDGET_LAYOUT visible=$visible card=${cardRect.height} footer=$footerHeight identityGap=$identityGap captionGap=$captionGap dividerGap=$dividerGap pin=${t.getSize(pin)} analysis=${t.getSize(analysis)}');
      final pinRect = t.getRect(pin), analysisRect = t.getRect(analysis);
      expect(pinRect.overlaps(analysisRect), isFalse);
      expect(pinRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(pinRect.right, lessThanOrEqualTo(cardRect.right));
      expect(pinRect.bottom, lessThanOrEqualTo(cardRect.bottom));
      expect(pinRect.height, inInclusiveRange(32, 40));
      await picture(t, 'compact-card-$visible', screen: true);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(footerHeight, lessThanOrEqualTo(35),
          reason: 'Footer must shrink in layout, not just its painted icon');
      expect(captionGap, inInclusiveRange(7, 9));
      expect(dividerGap, inInclusiveRange(3, 5));
    });
  }

  testWidgets('single budget is secondary to the actual primary Dashboard card',
      (t) async {
    await mount(t, fullDashboard: true, accent: AppAccentPreset.sun);
    await t.pump(const Duration(seconds: 1));
    final hero = find.byType(DashboardHeroCard);
    expect(t.getSize(hero).height, lessThan(196));
    debugPrint('HERO_NORMAL_HEIGHT=${t.getSize(hero).height}');
    await picture(t, 'dashboard-actual', screen: true);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump();
    container.dispose();
    containerDisposed = true;
    await t.pump(Duration.zero);
    await t.runAsync(() async {});
    await t.pump(Duration.zero);
  }, skip: Platform.environment['FLOWY_DASHBOARD_VISUAL'] != '1');
  testWidgets(
      'single summary restores category badge and compact advisor visual',
      (t) async {
    await mount(t, visible: true);
    expect(t.getSize(find.byType(DashboardHeroCard)).height, lessThan(196));
    expect(find.byType(CategoryIconBadge), findsOneWidget);
    final advisor = find.ancestor(
        of: find.text('Có nên mua?'), matching: find.byType(TextButton));
    expect(t.getSize(advisor).height, greaterThanOrEqualTo(48));
    expect(t.getSize(find.text('Có nên mua?')).height, lessThan(28));
    expect(find.text('Trong kỳ này'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'category identities and progress survive privacy without revealing usage',
      (t) async {
    await mount(t, weekly: true, visible: true, accent: AppAccentPreset.sun);
    await picture(t, 'two-rhythms-visible');
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    final bar = find.byKey(const ValueKey('budget-summary-progress-qa-period'));
    final fill =
        find.descendant(of: bar, matching: find.byType(FractionallySizedBox));
    expect(t.widget<FractionallySizedBox>(fill).widthFactor, .5);
    final badges = t
        .widgetList<CategoryIconBadge>(find.byType(CategoryIconBadge))
        .toList();
    expect(badges.map((b) => b.category?.color).toSet().length, 2);
    await picture(t, 'sheet-visible-gradient', screen: true);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'approved targets keep right-hand money, real overspend, grouped dues and tiny savings',
      (t) async {
    await mount(t,
        visible: true,
        font: 'Lora',
        accent: AppAccentPreset.sun,
        vaultTap: () {});
    await db.updateTransactionAtomically(
        transactionId: 'qa-spend',
        walletId: 'qa-wallet',
        categoryId: 'qa-period',
        amount: 276000,
        type: CategoryType.expense,
        date: DateTime(2026, 10, 28, 12));
    await until(t, (o) => o.items.single.remaining == -36000);
    final title = find.text('Wants · Kỳ');
    final money = find.byWidgetPredicate(
        (w) => w is BudgetMoneyText && w.data == budgetMoney(36000));
    expect(t.getCenter(money).dx, greaterThan(t.getCenter(title).dx));
    expect(find.text('Theo từng ngân sách'), findsNothing);
    expect(
        t
            .widget<BudgetUsageProgress>(
                find.byKey(const ValueKey('hero-progress-qa-period')))
            .value,
        1);
    expect(find.text('Đã dùng 115% hạn mức'), findsOneWidget);
    expect(t.getCenter(find.text('Tạo ngân sách tuần')).dx,
        greaterThan(t.getCenter(find.text('Xem tất cả ngân sách')).dx));
    await picture(t, 'approved-H1');
    await seedFrostedLedgerData(db);
    await (db.update(db.savingsGoals)..where((g) => g.id.equals('qa-goal')))
        .write(const SavingsGoalsCompanion(
            currentAmount: Value(456812), targetAmount: Value(25000000000)));
    await until(
        t,
        (o) =>
            o.source.debts.length == 2 &&
            o.source.goals.single.targetAmount == 25000000000);
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    await picture(t, 'approved-S1', screen: true);
    final scroll = find
        .descendant(
            of: find.byType(SafeToSpendBreakdownSheet),
            matching: find.byType(Scrollable))
        .last;
    final due = find.byKey(const ValueKey('due-row-qa-debt-1'));
    await t.scrollUntilVisible(due, 160, scrollable: scroll);
    await t.ensureVisible(due);
    await t.pumpAndSettle();
    await picture(t, 'approved-S2-S3', screen: true);
    final goal = find.byKey(const ValueKey('goal-row-qa-goal'));
    await t.scrollUntilVisible(goal, 160, scrollable: scroll);
    await t.ensureVisible(goal);
    await t.pumpAndSettle();
    expect(find.text('Dưới 0,1% mục tiêu'), findsOneWidget);
    final value = t
        .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('goal-progress-qa-goal')))
        .value!;
    expect(value, closeTo(456812 / 25000000000, .000000001));
    await picture(t, 'approved-S4', screen: true);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'privacy summary is neutral and real/masked text share right anchor',
      (t) async {
    await mount(t, visible: true, font: 'Lora');
    await db.updateTransactionAtomically(
        transactionId: 'qa-spend',
        walletId: 'qa-wallet',
        categoryId: 'qa-period',
        amount: 300000,
        type: CategoryType.expense,
        date: DateTime(2026, 10, 28, 12));
    await until(t, (o) => o.items.single.remaining < 0);
    visibleState.value = false;
    await t.pump();
    final hero = find.byType(DashboardHeroCard);
    expect(find.descendant(of: hero, matching: find.text('Vượt hạn mức')),
        findsNothing);
    expect(find.descendant(of: hero, matching: find.byType(BudgetSummaryTile)),
        findsNothing);
    expect(find.descendant(of: hero, matching: find.byType(CategoryIconBadge)),
        findsNothing);
    expect(find.text('Ngân sách đang ẩn'), findsOneWidget);
    expect(
        t
            .widget<BudgetUsageProgress>(
                find.byKey(const ValueKey('hidden-hero-progress')))
            .value,
        0);
    await picture(t, 'neutral-hero');
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    final row = find.byKey(const ValueKey('budget-row-qa-period'));
    expect(find.descendant(of: row, matching: find.text('Vượt hạn mức')),
        findsNothing);
    expect(
        t
            .widget<BudgetUsageProgress>(
                find.byKey(const ValueKey('budget-summary-progress-qa-period')))
            .value,
        0);
    await picture(t, 'neutral-sheet', screen: true);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'real budget Insights report uses exact owner scope and fiscal weekly range',
      (t) async {
    await mount(t,
        weekly: true, visible: true, font: 'Lora', loadedInsights: true);
    final overview =
        container.read(budgetSpendingOverviewProvider).requireValue;
    final weekly =
        overview.items.firstWhere((b) => b.rhythm == SpendingRhythm.weekly);
    final route = budgetInsightsScreen(weekly, overview, isVisible: false);
    expect(route.customWindow!.start, weekly.start);
    expect(route.customWindow!.end, weekly.end);
    expect(route.categoryIds, contains(weekly.budget.categoryId));
    await t.tap(find.byKey(const ValueKey('budget-tile-period')));
    await t.pumpAndSettle();
    expect(find.byType(SpendingInsightsScreen), findsOneWidget);
    final donut = t.widget<InsightsDonut>(find.byType(InsightsDonut));
    expect(donut.total, 120000);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(DashboardHeroCard), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('one rhythm uses a full-width feature, never a half empty tile',
      (t) async {
    await mount(t, visible: true);
    await picture(t, 'mixed');
    await picture(t, 'after-screen', screen: true);
    expect(find.byKey(const ValueKey('budget-tile-weekly')), findsNothing);
    expect(find.byKey(const ValueKey('budget-tile-period')), findsOneWidget);
    expect(find.text('Tạo ngân sách tuần'), findsOneWidget);
    expect(find.text('Chưa thiết lập'), findsNothing);
    expect(t.getSize(find.byKey(const ValueKey('budget-tile-period'))).width,
        greaterThan(300));
    expect(t.takeException(), isNull);
  });
  testWidgets('detail header avoids native top region with one fluid scroller',
      (t) async {
    await mount(t);
    for (var i = 0; i < 6; i++) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'more-$i', name: 'Ngân sách $i', type: CategoryType.expense));
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
          id: 'more-$i',
          categoryId: 'more-$i',
          amount: 500000,
          periodMonth: DateTime(2026, 10)));
    }
    await t.runAsync(() async {
      await container.read(budgetSpendingDataProvider.future);
    });
    await t.pumpAndSettle();
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    final title = find.text('Khả năng chi tiêu');
    debugPrint('GEOMETRY title=${t.getRect(title)}');
    expect(t.getTopLeft(title).dy, greaterThanOrEqualTo(44));
    expect(
        find.descendant(
            of: find.byType(SafeToSpendBreakdownSheet),
            matching: find.byType(CustomScrollView)),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final size in [320.0, 360.0, 412.0]) {
    testWidgets('normal width $size gives only weekly a full-width feature',
        (t) async {
      await mount(t, weekly: true, period: false, width: size, visible: true);
      expect(find.byKey(const ValueKey('budget-tile-period')), findsNothing);
      expect(find.text('Tạo ngân sách kỳ'), findsOneWidget);
      expect(find.byKey(const ValueKey('budget-tile-weekly')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('both empty remain setup states rather than fake zero balances',
      (t) async {
    await mount(t, period: false, visible: true);
    expect(find.text('Chưa có ngân sách để theo dõi'), findsOneWidget);
    expect(find.text('+ Tạo ngân sách'), findsOneWidget);
    await picture(t, 'empty');
    expect(find.text('Đã dùng hết'), findsNothing);
    expect(t.takeException(), isNull);
  });
  for (final sample in [
    (320.0, 1.3, false, 'Plus Jakarta Sans'),
    (320.0, 2.0, true, 'Lora'),
    (390.0, 1.0, false, 'Lora')
  ]) {
    testWidgets(
        'real app/currency fonts adapt at width ${sample.$1} scale ${sample.$2} ${sample.$4}',
        (t) async {
      await mount(t,
          weekly: true,
          visible: true,
          width: sample.$1,
          scale: sample.$2,
          dark: sample.$3,
          font: sample.$4);
      await db.update(db.categories).replace((await (db.select(db.categories)
                ..where((c) => c.id.equals('qa-period')))
              .getSingle())
          .copyWith(
              name: 'Ngân sách tên rất dài vẫn phải đọc được trong sheet'));
      await until(
          t, (o) => o.items.any((b) => b.name.startsWith('Ngân sách tên')));
      await picture(t, 'font-${sample.$4}-${sample.$2}');
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.text('Xem tất cả ngân sách'));
      await t.tap(find.text('Xem tất cả ngân sách'));
      await t.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(SafeToSpendBreakdownSheet),
              matching: find.textContaining(
                  'Ngân sách tên rất dài vẫn phải đọc được trong sheet')),
          findsOneWidget);
      await picture(t, 'sheet-${sample.$4}-${sample.$2}', screen: true);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
      'privacy hides outgoing money immediately while keeping hero geometry',
      (t) async {
    final semantics = t.ensureSemantics();
    await mount(t, visible: true);
    final size = t.getSize(find.byType(DashboardHeroCard));
    visibleState.value = false;
    await t.pump();
    for (final e in find
        .descendant(
            of: find.byType(DashboardHeroCard), matching: find.byType(RichText))
        .evaluate()) {
      final text = (e.widget as RichText).text.toPlainText();
      if (!text.contains('120.000') && !text.contains('700.000')) continue;
      var opacity = 1.0;
      e.visitAncestorElements((a) {
        final w = a.widget;
        if (w is Opacity) opacity *= w.opacity;
        if (w is FadeTransition) opacity *= w.opacity.value;
        return true;
      });
      expect(opacity, 0,
          reason: 'Real money must not survive as an outgoing painted layer');
    }
    final labels = t
        .binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!
        .toStringDeep();
    expect(labels, isNot(contains('120.000')));
    expect(t.getSize(find.byType(DashboardHeroCard)), size);
    semantics.dispose();
  });
  for (final dark in [false, true]) {
    testWidgets(
        'privacy removes identity and paint immediately, reveal interpolates dark=$dark',
        (t) async {
      final semantics = t.ensureSemantics();
      await mount(t, visible: false, dark: dark);
      final hero = find.byType(DashboardHeroCard);
      List<Color> colors() => t
          .widget<BudgetAmbientSurface>(find.descendant(
              of: hero, matching: find.byType(BudgetAmbientSurface)))
          .colors;
      final theme = Theme.of(t.element(hero)).colorScheme.primary;
      expect(colors(), [theme]);
      final hiddenSize = t.getSize(hero);
      visibleState.value = true;
      await t.pump();
      expect(colors(), [theme]);
      expect(find.text('Wants · Kỳ'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 130));
      final middle = colors().single;
      expect(middle, isNot(theme));
      final category = budgetCategoryColor(
          container
              .read(budgetSpendingOverviewProvider)
              .requireValue
              .source
              .categories
              .firstWhere((c) => c.id == 'qa-period'),
          theme);
      expect(middle, isNot(category));
      await picture(t, 'privacy-reveal-middle-$dark');
      await t.pump(const Duration(milliseconds: 130));
      expect(colors(), [category]);
      expect(t.getSize(hero), hiddenSize);
      await picture(t, 'privacy-visible-$dark');
      // Hide both after completion and while a new reveal is in flight.
      for (var iteration = 0; iteration < 2; iteration++) {
        visibleState.value = false;
        await t.pump();
        for (final elapsed in [0, 16, 130, 300]) {
          await t.pump(Duration(milliseconds: elapsed));
          expect(colors(), [theme]);
          expect(
              find.descendant(
                  of: hero, matching: find.byType(BudgetSummaryTile)),
              findsNothing);
          expect(
              find.descendant(
                  of: hero, matching: find.byType(CategoryIconBadge)),
              findsNothing);
          expect(
              find.descendant(of: hero, matching: find.byType(BudgetMoneyText)),
              findsNothing);
          final tree = t.binding.renderViews.single.owner!.semanticsOwner!
              .rootSemanticsNode!
              .toStringDeep();
          for (final sensitive in [
            'Wants',
            '03/10',
            '01/10',
            '120.000',
            'Trong kỳ',
            'Vượt hạn mức'
          ]) {
            expect(tree, isNot(contains(sensitive)));
          }
          expect(t.getSize(hero), hiddenSize);
        }
        await picture(t, 'privacy-hidden-$dark');
        visibleState.value = true;
        await t.pump();
        await t.pump(const Duration(milliseconds: 90));
      }
      semantics.dispose();
      expect(t.takeException(), isNull);
    });
  }
  for (final sample in [
    (390.0, 1.0, false, 1),
    (320.0, 2.0, true, 1),
    (390.0, 1.0, false, 0),
    (390.0, 1.0, false, 3)
  ]) {
    testWidgets(
        'section count ${sample.$4} reaches card edge ${sample.$1} scale ${sample.$2}',
        (t) async {
      await mount(t,
          width: sample.$1,
          scale: sample.$2,
          dark: sample.$3,
          period: sample.$4 != 0,
          pinScenario: sample.$4 == 3);
      await t.ensureVisible(find.text('Xem tất cả ngân sách'));
      await t.tap(find.text('Xem tất cả ngân sách'));
      await t.pumpAndSettle();
      const label = 'QUỸ CHI THEO KỲ';
      final row =
          t.getRect(find.byKey(const ValueKey('budget-heading-$label')));
      final count =
          t.getRect(find.byKey(const ValueKey('budget-count-$label')));
      final card = sample.$4 == 0
          ? row
          : t.getRect(find.byKey(ValueKey(
              'budget-row-${sample.$4 == 3 ? 'aa-needs' : 'qa-period'}')));
      expect(count.right, closeTo(row.right, .01));
      expect(count.right, closeTo(card.right, 1),
          reason:
              'Card border insets content by .7dp; section uses outer content edge');
      expect(t.takeException(), isNull);
      await picture(t, 'header-${sample.$1}-${sample.$2}', screen: true);
    });
  }
  testWidgets(
      'unpinning sole representative leaves Hero empty and does not revive fallback',
      (t) async {
    await mount(t, visible: true);
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Bỏ ghim ngân sách khỏi Dashboard'));
    await until(t, (o) => o.explicitlyPinned(SpendingRhythm.period) == null);
    expect(
        container
            .read(budgetSpendingOverviewProvider)
            .requireValue
            .pinned(SpendingRhythm.period)
            ?.budget
            .id,
        'qa-period');
    await t.tap(find.byTooltip('Đóng chi tiết ngân sách'));
    await t.pumpAndSettle();
    expect(find.text('Chưa ghim ngân sách để theo dõi'), findsOneWidget);
    expect(find.byType(BudgetSummaryTile), findsNothing);
    await picture(t, 'no-explicit-pin');
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    expect(
        t
            .widget<IconButton>(find.descendant(
                of: find.byKey(const ValueKey('budget-row-qa-period')),
                matching: find.byType(IconButton)))
            .isSelected,
        false);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('advisor action opens only advisor and never parent detail',
      (t) async {
    await mount(t);
    await t.tap(find.text('Có nên mua?'));
    await t.pumpAndSettle();
    expect(find.byType(PrePurchaseAdvisorSheet), findsOneWidget);
    expect(find.byType(SafeToSpendBreakdownSheet), findsNothing);
    expect(await db.select(db.transactions).get(), hasLength(1));
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'open sheet reacts to edit/delete/undo without reset or duplicated spending',
      (t) async {
    await mount(t, weekly: true, visible: true);
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    final element = find.byType(SafeToSpendBreakdownSheet).evaluate().single;
    final scroll = t.widget<CustomScrollView>(find.descendant(
        of: find.byType(SafeToSpendBreakdownSheet),
        matching: find.byType(CustomScrollView)));
    await db.updateTransactionAtomically(
        transactionId: 'qa-spend',
        walletId: 'qa-wallet',
        categoryId: 'qa-period',
        amount: 140000,
        type: CategoryType.expense,
        date: DateTime(2026, 10, 28, 12));
    await until(
        t,
        (o) =>
            o.items.firstWhere((b) => b.budget.id == 'qa-period').remaining ==
            100000);
    expect(find.textContaining('100.000'), findsWidgets);
    expect(find.byType(SafeToSpendBreakdownSheet).evaluate().single,
        same(element));
    await db.softDeleteTransaction('qa-spend');
    await until(
        t,
        (o) =>
            o.items.firstWhere((b) => b.budget.id == 'qa-period').remaining ==
            240000);
    await db.restoreTransaction('qa-spend');
    await until(
        t,
        (o) =>
            o.items.firstWhere((b) => b.budget.id == 'qa-period').remaining ==
            100000);
    expect(scroll.controller!.hasClients, isTrue);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'live Dashboard watcher cannot swallow committed period pin updates',
      (t) async {
    await mount(t, weekly: true, pinScenario: true, visible: true);
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    Future<void> toggle(String id, bool selected, String representative) async {
      final row = find.byKey(ValueKey('budget-row-$id'));
      final scroller = find
          .descendant(
              of: find.byType(SafeToSpendBreakdownSheet),
              matching: find.byType(Scrollable))
          .last;
      t.state<ScrollableState>(scroller).position.jumpTo(0);
      await t.pump();
      await t.scrollUntilVisible(row, 100, scrollable: scroller);
      await t.ensureVisible(row);
      await t.tap(find.descendant(of: row, matching: find.byType(IconButton)));
      await until(
          t,
          (o) =>
              o.items.firstWhere((b) => b.budget.id == id).pinned == selected &&
              o.pinned(SpendingRhythm.period)?.budget.id == representative);
      final configs = await db.select(db.budgetRhythms).get();
      final overview =
          container.read(budgetSpendingOverviewProvider).requireValue;
      expect(configs.firstWhere((c) => c.budgetId == id).pinned, selected);
      for (final b in overview.items) {
        expect(b.pinned,
            configs.firstWhere((c) => c.budgetId == b.budget.id).pinned);
      }
      expect(overview.pinned(SpendingRhythm.weekly)!.budget.id, 'qa-week');
      expect(
          find
              .descendant(of: row, matching: find.byType(IconButton))
              .evaluate()
              .single
              .widget,
          isA<IconButton>().having((b) => b.isSelected, 'selected', selected));
      final hero = find.descendant(
          of: find.byType(DashboardHeroCard),
          matching: find.byType(BudgetSummaryTile));
      expect(
          t
              .widgetList<BudgetSummaryTile>(hero)
              .where((b) => b.budget.rhythm == SpendingRhythm.period)
              .map((b) => b.budget.budget.id)
              .toList(),
          selected ? [id] : isEmpty);
      expect(overview.explicitlyPinned(SpendingRhythm.period)?.budget.id,
          selected ? id : null);
    }

    await toggle('zz-obligations', false, 'aa-needs');
    await toggle('aa-needs', true, 'aa-needs');
    await toggle('qa-period', true, 'qa-period');
    await toggle('qa-period', false, 'aa-needs');
    await toggle('aa-needs', true, 'aa-needs');
    await toggle('aa-needs', false, 'aa-needs');
    await t.tap(find.byTooltip('Đóng chi tiết ngân sách'));
    await t.pumpAndSettle();
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    final pin = t.widget<IconButton>(find.descendant(
        of: find.byKey(const ValueKey('budget-row-aa-needs')),
        matching: find.byType(IconButton)));
    expect(pin.isSelected, false);
    expect(t.takeException(), isNull);
  });
  testWidgets('pin/edit are scoped, persisted and independent between rhythms',
      (t) async {
    await mount(t, weekly: true);
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'extra', name: 'Đi lại', type: CategoryType.expense));
    final b = await db.into(db.budgets).insertReturning(BudgetsCompanion.insert(
        id: 'extra',
        categoryId: 'extra',
        amount: 500000,
        periodMonth: DateTime(2026, 10),
        cycleStartDay: const Value(1)));
    await saveBudgetRhythm(db, b,
        rhythm: SpendingRhythm.weekly, weekStart: 1, carryRule: 'none');
    await until(t, (o) => o.items.length == 3);
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    final pin = find.byTooltip('Ghim ngân sách lên Dashboard');
    await t.ensureVisible(pin);
    await t.tap(pin);
    await until(
        t, (o) => o.pinned(SpendingRhythm.weekly)?.budget.id == 'extra');
    expect(
        container
            .read(budgetSpendingOverviewProvider)
            .requireValue
            .pinned(SpendingRhythm.period)!
            .budget
            .id,
        'qa-period');
    expect(find.byType(SafeToSpendBreakdownSheet), findsOneWidget);
    expect(find.text('Chi tiết ngân sách'), findsNothing);
    await t.tap(find.descendant(
        of: find.byKey(const ValueKey('budget-row-extra')),
        matching: find.byType(BudgetSummaryTile)));
    await t.pumpAndSettle();
    expect(
        t
            .widget<SpendingInsightsScreen>(find.byType(SpendingInsightsScreen))
            .budgetScopeId,
        'extra');
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'window change drops previous budget instead of keeping stale selected money',
      (t) async {
    await mount(t, weekly: true, visible: true);
    container.read(selectedDate.notifier).state = DateTime(2026, 11, 4);
    await t.pumpAndSettle();
    expect(find.text('Chưa có ngân sách để theo dõi'), findsOneWidget);
    expect(find.text('Wants'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'sheet bottom remains reachable above keyboard and navigation inset',
      (t) async {
    await mount(t, keyboard: 200, scale: 1.3);
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    final last = find
        .text('Hạn mức kế hoạch không phải số dư ví hoặc tiền đã dành riêng.');
    await t.scrollUntilVisible(last, 240,
        scrollable: find
            .descendant(
                of: find.byType(SafeToSpendBreakdownSheet),
                matching: find.byType(Scrollable))
            .last);
    await t.ensureVisible(last);
    await t.pumpAndSettle();
    expect(t.getBottomLeft(last).dy, lessThanOrEqualTo(844 - 200));
    expect(t.getTopLeft(find.text('Khả năng chi tiêu')).dy,
        greaterThanOrEqualTo(44));
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'rapid close during sheet entry leaves no disposed controller or orphan',
      (t) async {
    await mount(t, visible: true);
    for (var i = 0; i < 3; i++) {
      await t.tap(find.text('Xem tất cả ngân sách'));
      await t.pump(const Duration(milliseconds: 100));
      Navigator.of(t.element(find.byType(SafeToSpendBreakdownSheet))).pop();
      await t.pumpAndSettle();
      expect(find.byType(SafeToSpendBreakdownSheet), findsNothing);
      expect(t.takeException(), isNull);
    }
  });
  testWidgets(
      'zero and overspent labels remain distinct and detail progress clamps',
      (t) async {
    await mount(t, visible: true);
    await db.updateTransactionAtomically(
        transactionId: 'qa-spend',
        walletId: 'qa-wallet',
        categoryId: 'qa-period',
        amount: 240000,
        type: CategoryType.expense,
        date: DateTime(2026, 10, 28, 12));
    await until(t, (o) => o.items.single.remaining == 0);
    expect(find.text('Đã dùng hết'), findsOneWidget);
    expect(find.text('Vượt'), findsNothing);
    await db.updateTransactionAtomically(
        transactionId: 'qa-spend',
        walletId: 'qa-wallet',
        categoryId: 'qa-period',
        amount: 300000,
        type: CategoryType.expense,
        date: DateTime(2026, 10, 28, 12));
    await until(t, (o) => o.items.single.remaining == -60000);
    expect(find.textContaining('Vượt'), findsWidgets);
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('budget-summary-progress-qa-period')),
        findsOneWidget);
    expect(
        t
            .widget<BudgetUsageProgress>(
                find.byKey(const ValueKey('budget-summary-progress-qa-period')))
            .value,
        1);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'large full currency value grows both tiles without clipping or shrinking',
      (t) async {
    await mount(t, weekly: true, visible: true, width: 320);
    await (db.update(db.budgets)..where((b) => b.id.equals('qa-period')))
        .write(const BudgetsCompanion(amount: Value(99999999999999)));
    await until(
        t,
        (o) =>
            o.items
                .firstWhere((b) => b.budget.id == 'qa-period')
                .budget
                .amount ==
            99999999999999);
    expect(t.getSize(find.byKey(const ValueKey('budget-tile-period'))).height,
        greaterThan(0));
    expect(find.byType(FittedBox), findsNothing);
    expect(t.takeException(), isNull);
    await picture(t, 'large-amount');
  });
  for (final accent in AppAccentPreset.values) {
    testWidgets('compact header preserves dynamic accent ${accent.name}',
        (t) async {
      await mount(t, accent: accent, width: 360);
      final button = t.widget<TextButton>(find.ancestor(
          of: find.text('Có nên mua?'), matching: find.byType(TextButton)));
      expect(
          button.style!.foregroundColor!.resolve({}),
          Theme.of(t.element(find.byType(DashboardHeroCard)))
              .colorScheme
              .onSurface);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
      'sheet uses root safe inset even when launching Hero already consumed it',
      (t) async {
    await mount(t,
        weekly: true, safeAncestor: true, scale: 2, dark: true, font: 'Lora');
    await t.ensureVisible(find.text('Xem tất cả ngân sách'));
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    final title = find.text('Khả năng chi tiêu');
    expect(t.getTopLeft(title).dy, greaterThanOrEqualTo(44));
    await picture(t, 'sheet-root-inset', screen: true);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'loading sheet keeps group structure without showing fake empty or zero',
      (t) async {
    await mount(t, loading: true);
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(SafeToSpendBreakdownSheet),
            matching: find.text('Đang tải ngân sách…')),
        findsOneWidget);
    expect(find.text('NGÂN SÁCH THEO TUẦN'), findsOneWidget);
    expect(find.text('QUỸ CHI THEO KỲ'), findsOneWidget);
    expect(find.text('Chưa có ngân sách theo tuần.'), findsNothing);
    expect(t.takeException(), isNull);
  });
  for (final sample in [
    ('Nunito', 320.0, 1.6, false),
    ('Comfortaa', 360.0, 1.3, false),
    ('Be Vietnam Pro', 412.0, 1.0, true),
    ('Lora', 448.0, 2.0, true),
    ('Plus Jakarta Sans', 390.0, 1.6, false),
  ]) {
    testWidgets(
        'frosted layout uses real ${sample.$1} font at ${sample.$2}/${sample.$3}',
        (t) async {
      await mount(t,
          weekly: true,
          visible: true,
          width: sample.$2,
          scale: sample.$3,
          dark: sample.$4,
          font: sample.$1,
          accent: AppAccentPreset.sun);
      if (sample.$3 >= 1.6) {
        final a = t.getRect(find.byKey(const ValueKey('budget-tile-weekly'))),
            b = t.getRect(find.byKey(const ValueKey('budget-tile-period')));
        expect(a.width, closeTo(b.width, .5));
        expect(a.left, closeTo(b.left, .5));
      }
      await picture(t, 'frosted-${sample.$1}-${sample.$3}');
      await t.ensureVisible(find.text('Xem tất cả ngân sách'));
      await t.tap(find.text('Xem tất cả ngân sách'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const ValueKey('budget-tile-period')).last);
      await t.pumpAndSettle();
      expect(
          t
              .widget<SpendingInsightsScreen>(
                  find.byType(SpendingInsightsScreen))
              .detailCategoryId,
          'qa-period');
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
      'pastel budget cards retain masked progress and separate pin targets',
      (t) async {
    await mount(t, weekly: true);
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(SafeToSpendBreakdownSheet),
            matching: find.byType(BackdropFilter)),
        findsNothing);
    expect(find.byKey(const ValueKey('budget-summary-progress-qa-period')),
        findsOneWidget);
    expect(find.text('•••'), findsNothing);
    final row = find.byKey(const ValueKey('budget-row-qa-period'));
    expect(t.getSize(row).height, inInclusiveRange(120, 140));
    final pin = find.byTooltip('Bỏ ghim ngân sách khỏi Dashboard').first;
    expect(t.getSize(pin).width, greaterThanOrEqualTo(32));
    expect(t.getSize(pin).height, greaterThanOrEqualTo(32));
    await t.tap(pin);
    await t.pumpAndSettle();
    expect(find.text('Chi tiết ngân sách'), findsNothing);
    await picture(t, 'sheet-top', screen: true);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'sheet navigates exact fiscal budget scope then Back returns Dashboard',
      (t) async {
    await mount(t, visible: true);
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('budget-tile-period')).last);
    await t.pumpAndSettle();
    expect(find.byType(SafeToSpendBreakdownSheet), findsNothing);
    final screen =
        t.widget<SpendingInsightsScreen>(find.byType(SpendingInsightsScreen));
    expect(screen.detailCategoryId, 'qa-period');
    expect(screen.budgetScopeId, 'qa-period');
    expect(screen.customWindow!.start, DateTime(2026, 10));
    expect(screen.customWindow!.end, DateTime(2026, 11));
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(DashboardHeroCard), findsOneWidget);
    expect(find.byType(SafeToSpendBreakdownSheet), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'failed pin persistence never fabricates selected state or opens detail',
      (t) async {
    await mount(t, weekly: true);
    await db.customStatement(
        "CREATE TRIGGER qa_fail_pin BEFORE INSERT ON budget_rhythms BEGIN SELECT RAISE(ABORT, 'fixture'); END");
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    final row = find.byKey(const ValueKey('budget-row-qa-period'));
    final pin = find.descendant(
        of: row, matching: find.byTooltip('Bỏ ghim ngân sách khỏi Dashboard'));
    await t.tap(pin);
    await t.pumpAndSettle();
    expect(
        (await (db.select(db.budgetRhythms)
                  ..where((c) => c.budgetId.equals('qa-period')))
                .getSingle())
            .pinned,
        isTrue);
    expect(find.descendant(of: row, matching: find.byIcon(Icons.push_pin)),
        findsOneWidget);
    expect(find.text('Chi tiết ngân sách'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'due records are distinct rows with unknown allocation; goals mask progress',
      (t) async {
    await mount(t, visible: false);
    await seedFrostedLedgerData(db);
    await until(t, (o) => o.source.debts.length == 2);
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    final scroll = find
        .descendant(
            of: find.byType(SafeToSpendBreakdownSheet),
            matching: find.byType(Scrollable))
        .last;
    for (var i = 1; i <= 2; i++) {
      final row = find.byKey(ValueKey('due-row-qa-debt-$i'));
      await t.scrollUntilVisible(row, 180, scrollable: scroll);
      await t.ensureVisible(row);
      expect(find.descendant(of: row, matching: find.text('Xem sổ nợ')),
          findsOneWidget);
      expect(
          find.descendant(
              of: row,
              matching: find.text('Chưa xác định số tiền đã dành riêng')),
          findsOneWidget);
    }
    final goal = find.byKey(const ValueKey('goal-row-qa-goal'));
    await t.scrollUntilVisible(goal, 180, scrollable: scroll);
    await t.ensureVisible(goal);
    await t.pumpAndSettle();
    expect(
        t
            .widget<LinearProgressIndicator>(
                find.byKey(const ValueKey('goal-progress-qa-goal')))
            .value,
        0);
    expect(find.text('30% mục tiêu'), findsNothing);
    await picture(t, 'sheet-bottom-hidden', screen: true);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'privacy change in open local sheet preserves scroll and eliminates old paint/semantics',
      (t) async {
    await mount(t, weekly: true, visible: true);
    await seedFrostedLedgerData(db);
    await until(t, (o) => o.source.debts.length == 2);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.buildTheme(
                isDark: false,
                accent: AppAccentPreset.sun,
                fontName: 'Lora',
                currencyFont: 'Be Vietnam Pro'),
            home: Scaffold(
                body: ValueListenableBuilder<bool>(
                    valueListenable: visibleState,
                    builder: (context, visible, _) => SafeToSpendBreakdownSheet(
                        controller: null, isVisible: visible))))));
    await t.pumpAndSettle();
    final scroller = find
        .descendant(
            of: find.byType(SafeToSpendBreakdownSheet),
            matching: find.byType(Scrollable))
        .last;
    await t.drag(find.byType(CustomScrollView), const Offset(0, -100));
    await t.pumpAndSettle();
    final position = t.state<ScrollableState>(scroller).position;
    expect(position.maxScrollExtent, greaterThan(100));
    position.jumpTo(120);
    await t.pump();
    final before = position.pixels;
    final element = find.byType(SafeToSpendBreakdownSheet).evaluate().single;
    final semantics = t.ensureSemantics();
    visibleState.value = false;
    await t.pump();
    expect(find.byType(SafeToSpendBreakdownSheet).evaluate().single,
        same(element));
    expect(position.pixels, closeTo(before, .5));
    final labels = t
        .binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!
        .toStringDeep();
    expect(labels, isNot(contains('120.000')));
    for (final e in find
        .descendant(
            of: find.byType(SafeToSpendBreakdownSheet),
            matching: find.byType(RichText))
        .evaluate()) {
      if (!(e.widget as RichText).text.toPlainText().contains('120.000')) {
        continue;
      }
      var opacity = 1.0;
      e.visitAncestorElements((a) {
        if (a.widget is Opacity) opacity *= (a.widget as Opacity).opacity;
        return true;
      });
      expect(opacity, 0);
    }
    semantics.dispose();
    expect(t.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    testWidgets('composited glass contrast dark=$dark', (t) async {
      await mount(t,
          weekly: true, visible: true, dark: dark, accent: AppAccentPreset.sun);
      final context = t.element(find.byType(DashboardHeroCard));
      final s = BudgetLedgerStyle(context);
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return (x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05));
      }

      final glass = Color.alphaBlend(
          s.surface.withValues(alpha: dark ? .85 : .90), s.canvas);
      final content =
          Color.alphaBlend(s.subtle.withValues(alpha: dark ? .65 : .60), glass);
      for (final fg in [s.ink, s.muted, s.readable(AppTokens.expense)]) {
        expect(contrast(fg, content), greaterThanOrEqualTo(4.5));
      }
      debugPrint(
          'CONTRAST dark=$dark ink=${s.ink.toARGB32().toRadixString(16)} mutedInk=${s.muted.toARGB32().toRadixString(16)} deficitInk=${s.readable(AppTokens.expense).toARGB32().toRadixString(16)} bg=${content.toARGB32().toRadixString(16)} glass=$glass content=$content muted=${contrast(s.muted, content)} deficit=${contrast(s.readable(AppTokens.expense), content)}');
    });
  }
  testWidgets('hidden Hero opens overview without revealing selected category',
      (t) async {
    await mount(t);
    expect(find.textContaining('Wants'), findsNothing);
    await t.tap(find.byKey(const ValueKey('hidden-hero-budget')));
    await t.pumpAndSettle();
    expect(find.byType(SafeToSpendBreakdownSheet), findsOneWidget);
    expect(find.byType(SpendingInsightsScreen), findsNothing);
    expect(find.text('Wants · Kỳ'), findsOneWidget);
    await t.tap(find.byTooltip('Đóng chi tiết ngân sách'));
    await t.pumpAndSettle();
    expect(find.text('Ngân sách đang ẩn'), findsOneWidget);
    await t.pump(Duration.zero);
    await t.pumpWidget(const SizedBox());
    await t.pump();
    await t.runAsync(() async {
      container.dispose();
    });
    containerDisposed = true;
    await t.pump();
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'goal progress uses real balances and delegates to the existing secure Vault launcher',
      (t) async {
    var launches = 0;
    await mount(t, visible: true, vaultTap: () => launches++);
    await seedFrostedLedgerData(db);
    await until(t, (o) => o.source.goals.isNotEmpty);
    await t.tap(find.text('Xem tất cả ngân sách'));
    await t.pumpAndSettle();
    final scroll = find
        .descendant(
            of: find.byType(SafeToSpendBreakdownSheet),
            matching: find.byType(Scrollable))
        .last;
    final goal = find.byKey(const ValueKey('goal-row-qa-goal'));
    await t.scrollUntilVisible(goal, 200, scrollable: scroll);
    await t.ensureVisible(goal);
    await t.pumpAndSettle();
    expect(
        t
            .widget<LinearProgressIndicator>(
                find.byKey(const ValueKey('goal-progress-qa-goal')))
            .value,
        .3);
    expect(find.text('30% mục tiêu'), findsOneWidget);
    await (db.update(db.savingsGoals)..where((g) => g.id.equals('qa-goal')))
        .write(const SavingsGoalsCompanion(targetAmount: Value(0)));
    await until(t, (o) => o.source.goals.single.targetAmount == 0);
    expect(
        t
            .widget<LinearProgressIndicator>(
                find.byKey(const ValueKey('goal-progress-qa-goal')))
            .value,
        0);
    expect(find.text('Chưa có mục tiêu hợp lệ'), findsOneWidget);
    final action = find.descendant(of: goal, matching: find.text('Mở Két'));
    await t.ensureVisible(action);
    await t.tap(action);
    await t.pumpAndSettle();
    await t.pump(Duration
        .zero); // Complete the metadata subscription's disposal in fake async.
    expect(launches, 1);
    expect(find.byType(SafeToSpendBreakdownSheet), findsNothing);
    expect(t.takeException(), isNull);
  });
}
