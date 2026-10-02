import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/screens/budget_screen.dart';
import 'package:pfm_app/screens/project_budget_detail_screen.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/currency_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Read the real DAO/card provider before pumping the UI. The snapshot overrides
// keep SQLite scheduling out of the widget test's fake clock.
Future<
    ({
      ProjectBudget project,
      List<Transaction> history,
      List<Category> categories,
      List<Wallet> wallets,
      double cardSpent,
      double daoSpent,
    })> _fixture({bool expenses = true, bool savings = false}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final container = ProviderContainer(overrides: [
    databaseProvider.overrideWithValue(db),
  ]);
  final subscription =
      container.listen(expenseTransactionsStreamProvider.future, (_, __) {});
  try {
    final now = DateTime.now();
    await db.createProjectBudget(
      id: 'project',
      title: 'Trip',
      tag: '#trip',
      targetAmount: 5000000,
      startDate: now.subtract(const Duration(days: 1)),
      endDate: now.add(const Duration(days: 40)),
    );
    for (final entry in [
      ('food', CategoryType.expense),
      ('transport', CategoryType.expense),
      ('income', CategoryType.income),
      ('transfer', CategoryType.transfer),
    ]) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: entry.$1, name: entry.$1, type: entry.$2));
    }
    await db.into(db.wallets).insert(
        WalletsCompanion.insert(id: 'wallet', name: 'Wallet', type: 'cash'));
    await db.into(db.savingsGoals).insert(SavingsGoalsCompanion.insert(
        id: 'goal', title: 'Goal', targetAmount: 10000000));

    Future<void> insert(String id, String category, double amount,
        {CategoryType type = CategoryType.expense,
        String? project = 'project',
        String? note,
        String? merchant,
        String? goal,
        String? envelope,
        DateTime? deletedAt}) async {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: id,
          walletId: 'wallet',
          categoryId: category,
          amount: amount,
          type: type,
          date: now,
          projectBudgetId: Value(project),
          note: Value(note),
          merchant: Value(merchant),
          goalId: Value(goal),
          envelopeType: Value(envelope),
          deletedAt: Value(deletedAt)));
    }

    if (expenses) {
      await insert('food', 'food', 400000, envelope: 'needs');
      await insert('transport', 'transport', 200000,
          project: null, note: 'Taxi #trip', envelope: 'wants');
    }
    await insert('income', 'income', 700000, type: CategoryType.income);
    await insert('transfer', 'transfer', 400000, type: CategoryType.transfer);
    if (savings) {
      // Null-envelope expenses remain reportable, including merchant matches.
      await insert('normal_null', 'food', 100000,
          project: null, merchant: '#trip');
      await insert('deposit', 'food', 2000000,
          goal: 'goal', envelope: 'savings');
      await insert('legacy_goal', 'food', 3000000,
          project: null, note: '#trip', goal: 'goal');
      await insert('legacy_envelope', 'food', 4000000,
          project: null, merchant: '#trip', envelope: 'savings');
      await insert('deleted', 'food', 5000000, deletedAt: now);
      await insert('unrelated', 'food', 6000000, project: null);
    }

    final project = (await db.select(db.projectBudgets).get()).single;
    final history =
        await db.watchTransactionsForProject(project.id, project.tag).first;
    final cardRows =
        await container.read(expenseTransactionsStreamProvider.future);
    final tag = project.tag.toLowerCase().trim();
    final cardSpent = cardRows
        .where((t) =>
            t.projectBudgetId == project.id ||
            (t.note?.toLowerCase() ?? '').contains(tag) ||
            (t.merchant?.toLowerCase() ?? '').contains(tag))
        .fold(0.0, (sum, t) => sum + t.amount);
    return (
      project: project,
      history: history,
      categories: await db.select(db.categories).get(),
      wallets: await db.select(db.wallets).get(),
      cardSpent: cardSpent,
      daoSpent: await db.calculateProjectSpent(project.id, project.tag),
    );
  } finally {
    subscription.close();
    container.dispose();
    await db.close();
  }
}

String _money(double amount) =>
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(amount);

void main() {
  for (final scenario in [
    (
      name: 'countsOnlyExpenses_andBreakdownExcludesIncomeAndTransfer',
      expenses: true,
      savings: false,
      spent: 600000.0,
      history: 4,
      shares: [2 / 3, 1 / 3]
    ),
    (
      name: 'excludesSavingsAndDeleted_includesNeedsWantsAndNullEnvelope',
      expenses: true,
      savings: true,
      spent: 700000.0,
      history: 5,
      shares: [5 / 7, 2 / 7]
    ),
    (
      name: 'nonExpenseHistory_doesNotConsumeBudgetOrCreateBreakdown',
      expenses: false,
      savings: false,
      spent: 0.0,
      history: 2,
      shares: <double>[]
    ),
  ]) {
    testWidgets('projectBudgetSpent_${scenario.name}', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final data = (await tester.runAsync(() =>
          _fixture(expenses: scenario.expenses, savings: scenario.savings)))!;
      expect(data.cardSpent, scenario.spent);
      expect(data.daoSpent, data.cardSpent);
      expect(data.history.length, scenario.history);
      expect(
          data.history.map((t) => t.id), containsAll(['income', 'transfer']));

      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          projectDetailStreamProvider('project')
              .overrideWith((ref) => Stream.value(data.project)),
          projectTransactionsStreamProvider('project')
              .overrideWith((ref) => Stream.value(data.history)),
          projectCategoriesStreamProvider
              .overrideWith((ref) => Stream.value(data.categories)),
          projectWalletsStreamProvider
              .overrideWith((ref) => Stream.value(data.wallets)),
        ],
        child: const MaterialApp(
            home: ProjectBudgetDetailScreen(projectId: 'project')),
      ));
      await tester.pumpAndSettle();
      final ratio = scenario.spent / data.project.targetAmount;
      final remaining = data.project.targetAmount - scenario.spent;
      final amounts = tester
          .widgetList<CurrencyText>(find.byType(CurrencyText))
          .map((w) => w.data)
          .toList();
      expect(
          amounts,
          contains(
              'Đã chi: ${_money(scenario.spent)} (${(ratio * 100).toStringAsFixed(0)}%)'));
      expect(amounts, contains('Còn: ${_money(remaining)}'));
      final days = data.project.endDate.difference(DateTime.now()).inDays + 1;
      expect(find.text('${_money((remaining / days).floorToDouble())}/ngày'),
          findsOneWidget);
      expect(
          tester
              .widgetList<FractionallySizedBox>(
                  find.byType(FractionallySizedBox))
              .map((w) => w.widthFactor),
          contains(ratio));
      final bars = tester
          .widgetList<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator))
          .toList();
      expect(bars.length, scenario.shares.length);
      for (var i = 0; i < bars.length; i++) {
        expect(bars[i].value, closeTo(scenario.shares[i], 0.000001));
      }
      if (scenario.expenses) {
        expect(
            amounts,
            contains(
                '${_money(scenario.savings ? 500000 : 400000)} (${(scenario.shares[0] * 100).toStringAsFixed(0)}%)'));
        expect(
            amounts,
            contains(
                '${_money(200000)} (${(scenario.shares[1] * 100).toStringAsFixed(0)}%)'));
      } else {
        expect(find.text('Cơ cấu phân bổ chi phí'), findsNothing);
      }
      await tester
          .ensureVisible(find.text('Nhật ký chi tiêu (${scenario.history})'));
      expect(
          find.text('Nhật ký chi tiêu (${scenario.history})'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
