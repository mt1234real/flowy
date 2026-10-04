import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/core/feedback/app_feedback.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/screens/budget_screen.dart';
import 'package:pfm_app/screens/ledger_screen.dart'
    show cycleStartDaysByMonthProvider;
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/category_tree_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

final month = DateTime(2026, 10);
Category category(String id, {String? parent, String? name}) => Category(
    id: id,
    parentId: parent,
    name: name ?? id,
    type: CategoryType.expense,
    icon: 'restaurant',
    color: '#009966',
    sortOrder: 0,
    isSystem: false,
    createdAt: month);
Budget budget(String id, String cat, double amount, {DateTime? period}) =>
    Budget(
        id: id,
        categoryId: cat,
        amount: amount,
        cycleStartDay: 1,
        periodMonth: period ?? month,
        createdAt: month);
Transaction expense(String cat, double amount,
        {String? project,
        String? note,
        String? merchant,
        String? goal,
        String? envelope,
        DateTime? date,
        DateTime? deleted,
        CategoryType type = CategoryType.expense}) =>
    Transaction(
        id: '$cat-$amount',
        walletId: 'wallet',
        categoryId: cat,
        amount: amount,
        type: type,
        date: date ?? DateTime(2026, 10, 10),
        createdAt: month,
        isAiParsed: false,
        isCycleStart: false,
        projectBudgetId: project,
        note: note,
        merchant: merchant,
        goalId: goal,
        envelopeType: envelope,
        deletedAt: deleted);
ProjectBudget project(String tag, {String status = 'ACTIVE'}) => ProjectBudget(
    id: 'project',
    title: 'Trip',
    tag: tag,
    icon: 'flag',
    colorHex: '#009966',
    targetAmount: 1000,
    startDate: month,
    endDate: DateTime(2026, 11),
    status: status,
    createdAt: month,
    updatedAt: month);
final cats = [
  category('Food'),
  category('Cafe', parent: 'Food'),
  category('Groceries', parent: 'Food'),
  category('Travel'),
  category('Taxi', parent: 'Travel')
];
final rows = [budget('food', 'Food', 100), budget('cafe', 'Cafe', 50)];
RecurringBudgetSnapshot derive(
        {List<Budget>? budgets,
        List<Category>? categories,
        List<Transaction> expenses = const [],
        List<ProjectBudget> projects = const [],
        DateTime? anchor,
        DateTime? start,
        DateTime? end}) =>
    deriveRecurringBudgetGroups(
        budgets: budgets ?? rows,
        categories: categories ?? cats,
        expenses: expenses,
        projects: projects,
        anchorMonth: anchor ?? month,
        startInclusive: start ?? month,
        endExclusive: end ?? DateTime(2026, 11));

void main() {
  test('parentOnly_limitAndSpent', () {
    final g = derive(
        budgets: [rows.first],
        categories: [cats.first],
        expenses: [expense('Food', 20)]).groups.single;
    expect(g.totalLimit, 100);
    expect(g.totalSpent, 20);
    expect(g.children, isEmpty);
  });
  test('parentPlusChildren_totalLimitEqualsOwnPlusChildren', () {
    final g = derive().groups.single;
    expect(g.parentOwnLimit, 100);
    expect(g.totalLimit, 150);
  });
  test('parentSpent_directPlusChildrenExactlyOnce', () {
    final result = derive(expenses: [expense('Food', 20), expense('Cafe', 30)]);
    expect(result.groups.single.directParentSpent, 20);
    expect(result.groups.single.totalSpent, 50);
    expect(result.totalSpent, 50);
  });
  test('childSpent_countsOnlyExactChildCategory', () {
    expect(
        derive(expenses: [
          expense('Food', 20),
          expense('Cafe', 30),
          expense('Groceries', 40)
        ]).groups.single.children.single.spent,
        30);
  });
  test('parentSpent_includesUnbudgetedDirectChildSpend', () {
    final g = derive(expenses: [expense('Groceries', 40)]).groups.single;
    expect(g.totalSpent, 40);
    expect(g.children.length, 1);
  });
  test('projectLinkedExpense_excluded', () {
    expect(derive(expenses: [expense('Food', 20, project: 'p')]).totalSpent, 0);
  });
  for (final field in ['note', 'merchant']) {
    test('eventTaggedExpense_$field excluded case insensitively', () {
      expect(
          derive(expenses: [
            expense('Food', 20,
                note: field == 'note' ? 'TRIP #Trip' : null,
                merchant: field == 'merchant' ? '#TRIP taxi' : null)
          ], projects: [
            project(' #trip ')
          ]).totalSpent,
          0);
    });
  }
  test('archivedProjectTag_doesNotExclude', () {
    expect(
        derive(
            expenses: [expense('Food', 20, note: '#trip')],
            projects: [project('#trip', status: 'ARCHIVED')]).totalSpent,
        20);
  });
  test('outsideCycleExpense_excluded_endIsExclusive_startIsInclusive', () {
    expect(
        derive(expenses: [
          expense('Food', 1, date: month.subtract(const Duration(seconds: 1))),
          expense('Food', 2, date: month),
          expense('Food', 4, date: DateTime(2026, 11))
        ]).totalSpent,
        2);
  });
  test('fiscalCutoff_usesSuppliedWindow', () {
    expect(
        derive(
            start: DateTime(2026, 10, 1, 4),
            end: DateTime(2026, 11, 1, 4),
            expenses: [
              expense('Food', 1, date: DateTime(2026, 10, 1, 3)),
              expense('Food', 2, date: DateTime(2026, 11, 1, 3))
            ]).totalSpent,
        2);
  });
  test('deletedSavingsAndNonExpense_excluded', () {
    expect(
        derive(expenses: [
          expense('Food', 1, deleted: month),
          expense('Food', 2, goal: 'g'),
          expense('Food', 4, envelope: 'savings'),
          expense('Food', 8, type: CategoryType.income),
          expense('Food', 16, type: CategoryType.transfer),
          expense('Food', 32, envelope: 'needs')
        ]).totalSpent,
        32);
  });
  test('zeroTotalLimit_noNaN', () {
    final g = derive(
        budgets: [budget('zero', 'Food', 0)],
        expenses: [expense('Food', 10)]).groups.single;
    expect(g.ratio, 0);
    expect(g.ratio.isFinite, isTrue);
  });
  test('overBudget_remainingIsNegativeAndReportedAsOver', () {
    final g = derive(expenses: [expense('Food', 200)]).groups.single;
    expect(g.remaining, -50);
    expect(g.ratio, 1);
  });
  test('childEdit_recomputeUpdatesParentTotal_withoutChangingParentRow', () {
    expect(derive().groups.single.totalLimit, 150);
    expect(
        derive(budgets: [rows.first, budget('cafe', 'Cafe', 80)])
            .groups
            .single
            .totalLimit,
        180);
    expect(rows.first.amount, 100);
  });
  test('parentWithoutBudgetRow_stillGroupsExistingChildBudgets', () {
    final g = derive(budgets: [rows.last], expenses: [expense('Food', 10)])
        .groups
        .single;
    expect(g.id, 'Food');
    expect(g.parentBudget, isNull);
    expect(g.parentOwnLimit, 0);
    expect(g.totalLimit, 50);
    expect(g.totalSpent, 10);
  });
  test('orphanBudget_notSilentlyDropped', () {
    final result = derive(budgets: [
      budget('orphan', 'Missing', 30),
      budget('badparent', 'Bad', 40)
    ], categories: [
      category('Bad', parent: 'MissingParent')
    ]);
    expect(result.groups.length, 2);
    expect(result.totalLimit, 70);
    expect(result.groups.every((g) => !g.canAddChild), isTrue);
  });
  test('grandchildren_retainedAsExactCategoryFallback_noRecursiveSpend', () {
    final result = derive(
        categories: [...cats, category('Deep', parent: 'Cafe')],
        budgets: [...rows, budget('deep', 'Deep', 25)],
        expenses: [expense('Deep', 17)]);
    expect(result.groups.length, 2);
    expect(result.groups.first.totalSpent, 0);
    expect(result.groups.last.totalSpent, 17);
    expect(result.totalSpent, 17);
  });
  test('stableParentOrder_firstBudgetEncounter', () {
    expect(
        derive(budgets: [budget('taxi', 'Taxi', 10), ...rows])
            .groups
            .map((g) => g.id),
        ['Travel', 'Food']);
  });
  test('stableChildOrder_preservesBudgetStreamOrder', () {
    expect(
        derive(budgets: [budget('g', 'Groceries', 10), ...rows])
            .groups
            .single
            .children
            .map((c) => c.category.id),
        ['Groceries', 'Cafe']);
  });
  test('monthAndEventFilter_noStaleRows', () {
    expect(
        derive(budgets: [
          ...rows,
          budget('old', 'Travel', 400, period: DateTime(2026, 9)),
          budget('event_x', 'Travel', 500)
        ]).totalLimit,
        150);
  });
  test('duplicateRootRows_retained_summarySpendingNotDuplicated', () {
    final result = derive(
        budgets: [...rows, budget('duplicate', 'Food', 70)],
        expenses: [expense('Food', 30)]);
    expect(result.groups.length, 2);
    expect(result.totalLimit, 220);
    expect(result.totalSpent, 30);
  });

  Future<ProviderContainer> screen(WidgetTester tester,
      {List<Budget>? budgets,
      List<Category>? categories,
      List<Transaction>? expenses,
      Stream<List<Budget>>? updates,
      double width = 430,
      double scale = 1,
      bool reduced = false,
      AppDatabase? db}) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (db != null) databaseProvider.overrideWithValue(db),
          activeBudgetsStreamProvider
              .overrideWith((ref) => updates ?? Stream.value(budgets ?? rows)),
          allCategoriesStreamProvider
              .overrideWith((ref) => Stream.value(categories ?? cats)),
          categoriesTreeStreamProvider
              .overrideWith((ref) => Stream.value(categories ?? cats)),
          expenseTransactionsStreamProvider
              .overrideWith((ref) => Stream.value(expenses ?? [])),
          projectBudgetsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: reduced),
                child: child!),
            home: const BudgetScreen())));
    final context = tester.element(find.byType(BudgetScreen));
    final container = ProviderScope.containerOf(context);
    container.read(budgetAnchorMonthProvider.notifier).state = month;
    container.read(cycleStartDaysByMonthProvider.notifier).state = {};
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    addTearDown(() async {
      AppFeedback.dismissImmediately();
      await tester.pumpWidget(const SizedBox.shrink());
    });
    return container;
  }

  Finder parent(String id) => find.byKey(ValueKey('budget-parent:$id'));
  Finder child(String id) => find.byKey(ValueKey('budget-child:$id'));
  Future<void> toggle(WidgetTester tester, String id) async {
    await tester.ensureVisible(parent(id));
    await tester
        .tap(find.descendant(of: parent(id), matching: find.text(id)).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets('allParentsCollapsedInitially_childNotTopLevelSibling',
      (tester) async {
    await screen(tester);
    expect(parent('Food'), findsOneWidget);
    expect(child('cafe'), findsNothing);
    expect(find.byKey(const ValueKey('budget-parent:Cafe')), findsNothing);
  });
  testWidgets('tapParent_expandsChildrenNestedUnderCorrectParent',
      (tester) async {
    await screen(tester);
    await toggle(tester, 'Food');
    expect(find.descendant(of: parent('Food'), matching: child('cafe')),
        findsOneWidget);
  });
  testWidgets('tapExpandedParent_collapsesChildren', (tester) async {
    await screen(tester);
    await toggle(tester, 'Food');
    await toggle(tester, 'Food');
    expect(child('cafe'), findsNothing);
  });
  testWidgets('expandAnimation_andCaretUse200msEaseInOutCubic', (tester) async {
    await screen(tester);
    await toggle(tester, 'Food');
    final caret = tester.widget<AnimatedRotation>(
        find.byKey(const ValueKey('budget-caret:Food')));
    expect(caret.turns, .5);
    expect(caret.duration, const Duration(milliseconds: 200));
    expect(caret.curve, Curves.easeInOutCubic);
    final size = tester.widget<AnimatedSize>(find.descendant(
        of: parent('Food'), matching: find.byType(AnimatedSize)));
    expect(size.duration, const Duration(milliseconds: 200));
    expect(size.curve, Curves.easeInOutCubic);
  });
  testWidgets('reducedMotion_expansionIsImmediate', (tester) async {
    await screen(tester, reduced: true);
    await toggle(tester, 'Food');
    expect(
        tester
            .widget<AnimatedRotation>(
                find.byKey(const ValueKey('budget-caret:Food')))
            .duration,
        Duration.zero);
  });
  testWidgets('multipleParents_canRemainExpanded', (tester) async {
    await screen(tester, budgets: [...rows, budget('taxi', 'Taxi', 40)]);
    await toggle(tester, 'Food');
    await toggle(tester, 'Travel');
    expect(child('cafe'), findsOneWidget);
    expect(child('taxi'), findsOneWidget);
  });
  testWidgets('noHierarchyBadgesOrBelongsToTextInRecurringCards',
      (tester) async {
    await screen(tester);
    await toggle(tester, 'Food');
    expect(find.text('Nhóm cha'), findsNothing);
    expect(find.text('Mục con'), findsNothing);
    expect(find.textContaining('Thuộc:'), findsNothing);
  });
  testWidgets('parentWithoutBudgetRow_isNotEmpty', (tester) async {
    await screen(tester, budgets: [rows.last]);
    expect(parent('Food'), findsOneWidget);
    await toggle(tester, 'Food');
    expect(child('cafe'), findsOneWidget);
  });
  testWidgets('tapParentEdit_doesNotToggleAccordion', (tester) async {
    await screen(tester);
    await tester.tap(find.byKey(const ValueKey('budget-edit:Food')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(child('cafe'), findsNothing);
    expect(find.text('Chỉnh Sửa Hạn Mức'), findsOneWidget);
    expect(find.text('Nhóm cha'), findsOneWidget);
  });
  testWidgets('tapChildEdit_doesNotCollapseParent', (tester) async {
    await screen(tester);
    await toggle(tester, 'Food');
    await tester.tap(find.byKey(const ValueKey('budget-child-edit:cafe')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(child('cafe'), findsOneWidget);
    expect(find.text('Chỉnh Sửa Hạn Mức'), findsOneWidget);
  });
  testWidgets('parentWithoutBudget_editOpensCreatePreselectedParent',
      (tester) async {
    await screen(tester, budgets: [rows.last]);
    await tester.tap(find.byKey(const ValueKey('budget-edit:Food')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Thiết Lập Hạn Mức'), findsOneWidget);
    expect(find.text('Food'), findsNWidgets(2));
    expect(child('cafe'), findsNothing);
  });
  testWidgets('quickAddChild_opensCreateFlowForParentContext', (tester) async {
    await screen(tester);
    await toggle(tester, 'Food');
    await tester.tap(find.byKey(const ValueKey('budget-add-child:Food')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Thiết Lập Hạn Mức'), findsOneWidget);
    await tester.tap(find.text('Chọn danh mục ngân sách...'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final modal =
        tester.widget<CategoryTreeModal>(find.byType(CategoryTreeModal));
    expect(modal.parentCategoryId, 'Food');
    expect(modal.allowSelectParent, isFalse);
    expect(
        find.descendant(
            of: find.byType(CategoryTreeModal), matching: find.text('Travel')),
        findsNothing);
    expect(
        find.descendant(
            of: find.byType(CategoryTreeModal), matching: find.text('Cafe')),
        findsOneWidget);
  });
  testWidgets('childEdit_streamRecomputeUpdatesAggregate', (tester) async {
    final updates = StreamController<List<Budget>>();
    addTearDown(updates.close);
    await screen(tester, updates: updates.stream);
    updates.add(rows);
    await tester.pump();
    final before = tester.widget(parent('Food'));
    updates.add([rows.first, budget('cafe', 'Cafe', 80)]);
    await tester.pump();
    expect(tester.widget(parent('Food')), isNot(same(before)));
    expect(find.textContaining('180'), findsWidgets);
  });
  testWidgets('monthChange_doesNotShowStaleChildData', (tester) async {
    final container = await screen(tester, budgets: [
      ...rows,
      budget('next', 'Groceries', 80, period: DateTime(2026, 11))
    ]);
    await toggle(tester, 'Food');
    expect(child('cafe'), findsOneWidget);
    container.read(budgetAnchorMonthProvider.notifier).state =
        DateTime(2026, 11);
    await tester.pump();
    expect(child('cafe'), findsNothing);
    expect(child('next'), findsOneWidget);
  });
  testWidgets('narrowLargeText_longNamesLargeCurrencyAndOverBudget_noOverflow',
      (tester) async {
    await screen(tester, width: 320, scale: 1.8, categories: [
      category('Food', name: 'Tên nhóm cha rất dài để kiểm tra hiển thị'),
      category('Cafe',
          parent: 'Food', name: 'Tên mục con dài không bị tràn khỏi thẻ')
    ], budgets: [
      budget('food', 'Food', 1234567890),
      budget('cafe', 'Cafe', 987654321)
    ], expenses: [
      expense('Food', 99999999999)
    ]);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(parent('Food'));
    await tester.tap(find
        .descendant(
            of: parent('Food'), matching: find.textContaining('Tên nhóm cha'))
        .first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(child('cafe'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  Future<AppDatabase> sqlite(WidgetTester tester,
      {bool parentBudget = true}) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.runAsync(() async {
      for (final cat in cats) {
        await db.into(db.categories).insert(cat);
      }
      for (final row in parentBudget ? rows : [rows.last]) {
        await db.into(db.budgets).insert(row);
      }
    });
    addTearDown(() async {
      await tester.runAsync(db.close);
    });
    return db;
  }

  Future<void> save(WidgetTester tester, {bool edit = true}) async {
    final button = find.text(
        edit ? '✓ CẬP NHẬT HẠN MỨC THÁNG NÀY' : '✓ LƯU HẠN MỨC CHO THÁNG NÀY');
    await tester.ensureVisible(button);
    await tester.runAsync(() async {
      await tester.tap(button);
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> enter80(WidgetTester tester) async {
    await tester.tap(find.text('C'));
    await tester.pump();
    await tester.tap(find.text('8'));
    await tester.pump();
    await tester.tap(find.text('0'));
    await tester.pump();
  }

  testWidgets('childEdit_sqliteSaveChangesOnlyChild_neverPersistsAggregate',
      (tester) async {
    final db = await sqlite(tester);
    await screen(tester, db: db);
    await toggle(tester, 'Food');
    await tester.tap(find.byKey(const ValueKey('budget-child-edit:cafe')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await enter80(tester);
    await save(tester);
    final saved = await tester.runAsync(() => db.select(db.budgets).get());
    expect(saved!.singleWhere((b) => b.id == 'food').amount, 100);
    expect(saved.singleWhere((b) => b.id == 'cafe').amount, 80);
    expect(derive(budgets: saved).groups.single.totalLimit, 180);
    expect(child('cafe'), findsOneWidget);
  });
  testWidgets('parentWithoutBudget_createSavePreservesChild', (tester) async {
    final db = await sqlite(tester, parentBudget: false);
    await screen(tester, db: db, budgets: [rows.last]);
    await tester.tap(find.byKey(const ValueKey('budget-edit:Food')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await enter80(tester);
    await save(tester, edit: false);
    final saved = await tester.runAsync(() => db.select(db.budgets).get());
    expect(saved!.length, 2);
    expect(saved.singleWhere((b) => b.categoryId == 'Food').amount, 80);
    expect(saved.singleWhere((b) => b.id == 'cafe').amount, 50);
  });
  testWidgets('quickAddChild_selectAndSaveUsesOnlyDirectChild', (tester) async {
    final db = await sqlite(tester);
    await screen(tester, db: db);
    await toggle(tester, 'Food');
    await tester.tap(find.byKey(const ValueKey('budget-add-child:Food')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Chọn danh mục ngân sách...'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.descendant(
        of: find.byType(CategoryTreeModal), matching: find.text('Groceries')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await enter80(tester);
    await save(tester, edit: false);
    final saved = await tester.runAsync(() => db.select(db.budgets).get());
    expect(saved!.singleWhere((b) => b.categoryId == 'Groceries').amount, 80);
    expect(saved.singleWhere((b) => b.id == 'food').amount, 100);
    expect(saved.length, 3);
  });
  testWidgets('parentExpand_doesNotCreateMissingParentRow', (tester) async {
    final db = await sqlite(tester, parentBudget: false);
    await screen(tester, db: db, budgets: [rows.last]);
    await toggle(tester, 'Food');
    final saved = await tester.runAsync(() => db.select(db.budgets).get());
    expect(saved!.single.id, 'cafe');
  });
  testWidgets('periodChevron_preservesMotionAndRecomputesNextMonth',
      (tester) async {
    final container = await screen(tester, budgets: [
      ...rows,
      budget('next', 'Groceries', 80, period: DateTime(2026, 11))
    ]);
    await toggle(tester, 'Food');
    final chevron = find.byIcon(Icons.chevron_right_rounded).first;
    await tester.ensureVisible(chevron);
    await tester.tap(chevron);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(budgetAnchorMonthProvider), DateTime(2026, 11));
    expect(child('cafe'), findsNothing);
    expect(child('next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
