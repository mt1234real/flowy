import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/services/budget_spending.dart';
import 'package:pfm_app/services/budget_spending_provider.dart';
import 'package:pfm_app/services/fiscal_day.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/dashboard_hero_card.dart';
import 'package:pfm_app/widgets/pre_purchase_advisor_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('FlowyWidgetTest');
    fonts.addFont(
        rootBundle.load('assets/google_fonts/PlusJakartaSans-Regular.ttf'));
    await fonts.load();
  });
  late AppDatabase db;
  late ProviderContainer c;
  late BudgetSpendingOverview overview;
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.wallets).insert(WalletsCompanion.insert(
        id: 'w', name: 'Cash', type: 'cash', balance: const Value(1800000)));
    for (final item in [
      ('food', 'Ăn uống', 700000.0),
      ('fun', 'Đi chơi', 240000.0)
    ]) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: item.$1, name: item.$2, type: CategoryType.expense));
      await db.into(db.budgets).insert(BudgetsCompanion.insert(
          id: item.$1,
          categoryId: item.$1,
          amount: item.$3,
          periodMonth: DateTime(2026, 10),
          cycleStartDay: const Value(1)));
    }
    final food = await (db.select(db.budgets)
          ..where((b) => b.id.equals('food')))
        .getSingle();
    await saveBudgetRhythm(db, food,
        rhythm: SpendingRhythm.weekly,
        weekStart: 1,
        carryRule: 'none',
        pinned: true);
    final fun = await (db.select(db.budgets)..where((b) => b.id.equals('fun')))
        .getSingle();
    await saveBudgetRhythm(db, fun,
        rhythm: SpendingRhythm.period,
        weekStart: 1,
        carryRule: 'none',
        pinned: true);
    await db.insertTransactionWithBalanceUpdate(TransactionsCompanion.insert(
        id: 't',
        walletId: 'w',
        categoryId: 'fun',
        amount: 120000,
        type: CategoryType.expense,
        date: DateTime(2026, 10, 28)));
    overview = deriveBudgetSpending(await readBudgetSpendingData(db),
        DateTime(2026, 10, 28), const FiscalDayBoundary(), {'default': 1});
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider
          .overrideWithValue(await SharedPreferences.getInstance()),
      budgetSpendingOverviewProvider.overrideWithValue(AsyncData(overview))
    ]);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<void> show(WidgetTester t,
      {double width = 390,
      double scale = 1,
      bool visible = true,
      bool reduced = false,
      Brightness brightness = Brightness.light}) async {
    t.view.physicalSize = Size(width, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: ThemeData(
                brightness: brightness, fontFamily: 'FlowyWidgetTest'),
            home: MediaQuery(
                data: MediaQueryData(
                    size: Size(width, 900),
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: reduced),
                child: Scaffold(
                    body: SingleChildScrollView(
                        child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: DashboardHeroCard(isVisible: visible))))))));
    await t.pumpAndSettle();
  }

  testWidgets(
      'two independent low tiles with advisor and bottom entry; no aggregate daily hero',
      (t) async {
    await show(t);
    expect(find.text('AN TOÀN CHI TIÊU'), findsOneWidget);
    expect(find.text('Theo từng ngân sách'), findsNothing);
    expect(find.textContaining('Ăn uống'), findsOneWidget);
    expect(find.textContaining('Đi chơi'), findsOneWidget);
    expect(find.text('Có nên mua?'), findsOneWidget);
    expect(find.text('Xem tất cả ngân sách'), findsOneWidget);
    final a = t.getRect(find.byKey(const ValueKey('budget-tile-weekly'))),
        b = t.getRect(find.byKey(const ValueKey('budget-tile-period')));
    expect(a.top, b.top);
    expect(a.height, greaterThanOrEqualTo(100));
    expect(b.height, greaterThanOrEqualTo(100));
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('loading to data preserves compact hero footprint', (t) async {
    c.dispose();
    final state = StateProvider<AsyncValue<BudgetSpendingOverview>>(
        (ref) => const AsyncLoading());
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider
          .overrideWithValue(await SharedPreferences.getInstance()),
      budgetSpendingOverviewProvider.overrideWith((ref) => ref.watch(state))
    ]);
    await show(t);
    final loadingRect = t.getRect(find.byType(DashboardHeroCard));
    expect(find.text('Đang tải ngân sách…'), findsOneWidget);
    expect(find.text('Thiết lập ngân sách'), findsNothing);
    c.read(state.notifier).state = AsyncData(overview);
    await t.pumpAndSettle();
    final loadedRect = t.getRect(find.byType(DashboardHeroCard));
    expect(loadedRect.width, loadingRect.width);
    expect(loadedRect.height, greaterThan(0));
    expect(find.textContaining('Đi chơi'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'narrow large text theme $brightness scale $scale no overflow and money semantics hidden',
          (t) async {
        final semantics = t.ensureSemantics();

        await show(t,
            width: 320, scale: scale, visible: false, brightness: brightness);
        expect(t.takeException(), isNull);
        final labels = t.binding.renderViews.single.owner!.semanticsOwner!
            .rootSemanticsNode!
            .toStringDeep();
        expect(labels, isNot(contains('120.000')));
        expect(labels, isNot(contains('700.000')));
        await t.ensureVisible(find.text('Xem tất cả ngân sách'));
        await t.tap(find.text('Xem tất cả ngân sách'));
        await t.pumpAndSettle();
        expect(find.text('Khả năng chi tiêu'), findsOneWidget);
        expect(find.text('QUỸ CHI THEO KỲ'), findsOneWidget);
        expect(find.text('KHOẢN CẦN GIỮ ĐẾN HẠN'), findsOneWidget);
        expect(find.text('QUỸ TÍCH LŨY'), findsOneWidget);
        expect(t.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
  testWidgets(
      'failed source shows retry not zero, and retry recovers actual budgets',
      (t) async {
    c.dispose();
    var attempt = 0;
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider
          .overrideWithValue(await SharedPreferences.getInstance()),
      budgetSpendingDateProvider.overrideWithValue(DateTime(2026, 10, 28)),
      budgetSpendingDataProvider.overrideWith((ref) => attempt++ == 0
          ? Stream.error(StateError('fixture failure'))
          : Stream.value(overview.source))
    ]);
    await show(t, width: 320, scale: 2, visible: false);
    expect(find.text('Chưa tải được ngân sách'), findsOneWidget);
    expect(find.text('Chưa thiết lập'), findsNothing);
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.text('Thử lại'));
    await t.tap(find.text('Thử lại'));
    await t.pumpAndSettle();
    expect(find.text('Ngân sách đang ẩn'), findsOneWidget);
    expect(attempt, 2);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'reduced motion keeps masking and uses no decorative numeric fades',
      (t) async {
    await show(t, visible: false, reduced: true);
    expect(
        find.descendant(
            of: find.byType(DashboardHeroCard),
            matching: find.byType(FadeTransition)),
        findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('reduced motion reveals category paint without a transition',
      (t) async {
    await show(t, visible: false, reduced: true);
    await show(t, visible: true, reduced: true);
    final ambient =
        t.widget<BudgetAmbientSurface>(find.byType(BudgetAmbientSurface));
    final theme =
        Theme.of(t.element(find.byType(DashboardHeroCard))).colorScheme.primary;
    expect(ambient.colors, [
      for (final r in SpendingRhythm.values)
        if (overview.explicitlyPinned(r) case final BudgetSpending b)
          budgetCategoryColor(
              overview.source.categories
                  .firstWhere((c) => c.id == b.budget.categoryId),
              theme)
    ]);
    expect(t.binding.transientCallbackCount, 0);
    expect(t.takeException(), isNull);
  });
  testWidgets('tap period focuses actual budget rather than first section',
      (t) async {
    await show(t);
    await t.tap(find.byKey(const ValueKey('budget-tile-period')));
    await t.pumpAndSettle();
    await t.pump();
    final title = find.textContaining('Đi chơi');
    expect(title, findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'Advisor keeps both input modes and forecasts selected budget without writes',
      (t) async {
    await show(t);
    await t.tap(find.text('Có nên mua?'));
    await t.pumpAndSettle();
    expect(find.byType(PrePurchaseAdvisorSheet), findsOneWidget);
    expect(find.text('1 món đồ'), findsOneWidget);
    expect(find.text('So sánh 2 món'), findsOneWidget);
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Đi chơi · Kỳ').last);
    await t.pumpAndSettle();
    expect(find.textContaining('Còn trước'), findsWidgets);
    expect(find.textContaining('Chưa xác minh'), findsWidgets);
    expect(await db.select(db.transactions).get(), hasLength(1));
    expect(t.takeException(), isNull);
  });
}
