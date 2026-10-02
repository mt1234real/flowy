import 'dart:async';

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/features/insights/insights_data.dart';
import 'package:pfm_app/screens/dashboard_screen.dart';
import 'package:pfm_app/screens/ledger_screen.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/spending_trend_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late DateTime today;
  late InsightsWindow current;
  late InsightsWindow previous;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day, 12);
    current = InsightsWindow(
        DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
    previous = InsightsWindow(DateTime(now.year, now.month - 1), current.start);
    for (final id in ['food', 'transport', 'salary']) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: id,
          name: id,
          type: id == 'salary' ? CategoryType.income : CategoryType.expense));
    }
    for (final id in ['bank', 'cash']) {
      await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: id, name: id, type: id, balance: const Value(10000000)));
    }
    await db.into(db.savingsGoals).insert(SavingsGoalsCompanion.insert(
        id: 'goal', title: 'Savings', targetAmount: 10000000));
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> insert(String id, double amount,
      {CategoryType type = CategoryType.expense,
      String category = 'food',
      String wallet = 'bank',
      String? goal,
      String? envelope,
      DateTime? date,
      DateTime? deletedAt}) async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: id,
        walletId: wallet,
        categoryId: category,
        amount: amount,
        type: type,
        date: date ?? today,
        goalId: Value(goal),
        envelopeType: Value(envelope),
        deletedAt: Value(deletedAt)));
  }

  Future<T> read<T>(ProviderListenable<Future<T>> provider) async {
    final subscription = container.listen(provider, (_, next) {});
    try {
      return await container.read(provider);
    } finally {
      subscription.close();
    }
  }

  Future<List<Transaction>> periodRows() =>
      read(dashboardPeriodTransactionsProvider(
              DateTimeRange(start: current.start, end: current.end))
          .future);
  double sum(Iterable<Transaction> rows) =>
      rows.fold(0.0, (total, tx) => total + tx.amount);

  Future<InsightsReport> report(List<Transaction> rows,
      {CategoryType type = CategoryType.expense,
      InsightsWindow? window,
      bool byWallet = false,
      bool byNature = false,
      ClassificationScheme? scheme,
      Set<String> wallets = const {},
      Set<String>? categoryIds}) async {
    return buildInsightsReport(
        transactions: rows,
        categories: await db.select(db.categories).get(),
        walletRecords: await db.select(db.wallets).get(),
        window: window ?? current,
        previousWindow: previous,
        type: type,
        groupByWallet: byWallet,
        groupByNature: byNature,
        scheme: scheme,
        wallets: wallets,
        categoryIds: categoryIds);
  }

  test('Dashboard excludes new and legacy Savings, retaining normal types',
      () async {
    await insert('salary', 20000000,
        type: CategoryType.income, category: 'salary');
    await insert('food', 2000000);
    await insert('deposit', 5000000, goal: 'goal', envelope: 'savings');
    await insert('withdraw', 1000000,
        type: CategoryType.income, goal: 'goal', envelope: 'savings');
    await insert('legacy_goal', 3000000, goal: 'goal');
    await insert('legacy_envelope', 4000000, envelope: 'savings');
    await insert('needs', 100000, envelope: 'needs');
    await insert('wants', 200000, envelope: 'wants');
    await insert('transfer', 500000, type: CategoryType.transfer);
    await insert('deleted', 900000, deletedAt: DateTime.now());
    await insert('outside', 700000, date: current.end);
    final rows = await periodRows();
    expect(rows.map((t) => t.id),
        unorderedEquals(['salary', 'food', 'needs', 'wants', 'transfer']));
    expect(sum(rows.where((t) => t.type == CategoryType.income)), 20000000);
    expect(sum(rows.where((t) => t.type == CategoryType.expense)), 2300000);
  });

  test('Dashboard filters Savings before the recent LIMIT 15', () async {
    for (var i = 0; i < 20; i++) {
      await insert('normal_$i', 10000,
          date: today.subtract(Duration(minutes: i * 2)));
      if (i < 5) {
        await insert('savings_$i', 500000,
            goal: i.isEven ? 'goal' : null,
            envelope: i.isEven ? null : 'savings',
            date: today.subtract(Duration(minutes: i * 2 - 1)));
      }
    }
    final rows = await read(recentTransactionsStreamProvider.future);
    expect(rows.map((t) => t.id),
        orderedEquals(List.generate(15, (i) => 'normal_$i')));
  });

  test(
      'Chart excludes all Savings markers and reconciles with Insights windows',
      () async {
    await insert('food', 300000);
    await insert('deposit', 2000000, goal: 'goal', envelope: 'savings');
    await insert('legacy_goal', 4000000, goal: 'goal');
    await insert('legacy_envelope', 5000000, envelope: 'savings');
    await insert('withdraw', 1000000,
        type: CategoryType.income, goal: 'goal', envelope: 'savings');
    await insert('deleted', 700000, deletedAt: DateTime.now());
    await insert('old', 900000,
        date: today.subtract(const Duration(days: 400)));
    final chart = await read(chartExpensesStreamProvider.future);
    expect(chart.map((t) => t.id), ['food']);
    expect(sum(chart), 300000);
    final insights = await read(insightsTransactionsProvider.future);
    for (final period in [
      InsightsPeriod.days7,
      InsightsPeriod.month,
      InsightsPeriod.quarter,
      InsightsPeriod.year
    ]) {
      final window = insightsWindow(period, today, const {});
      final expected = sum(chart.where((t) => window.contains(t.date)));
      expect(expected, 300000);
      expect((await report(insights, window: window)).total, expected);
    }
  });

  test(
      'Insights excludes Savings before every lens and current/previous totals',
      () async {
    await insert('food', 1000000, envelope: 'needs');
    await insert('transport', 500000,
        category: 'transport', wallet: 'cash', envelope: 'wants');
    await insert('deposit', 3000000, goal: 'goal', envelope: 'savings');
    await insert('legacy_goal', 4000000, goal: 'goal');
    await insert('legacy_envelope', 5000000, envelope: 'savings');
    await insert('previous_food', 1000000, date: previous.start);
    await insert('previous_deposit', 8000000,
        goal: 'goal', envelope: 'savings', date: previous.start);
    await insert('previous_legacy_goal', 6000000,
        goal: 'goal', date: previous.start);
    await insert('previous_legacy_envelope', 7000000,
        envelope: 'savings', date: previous.start);
    final sqlRows = await read(insightsTransactionsProvider.future);
    expect(sqlRows.map((t) => t.id),
        unorderedEquals(['food', 'transport', 'previous_food']));
    // Public report builder also accepts unfiltered rows independently of Riverpod.
    final raw = await db.select(db.transactions).get();
    final categoryReport = await report(raw);
    expect(categoryReport.total, 1500000);
    expect(categoryReport.previousTotal, 1000000);
    expect(categoryReport.current.length, 2);
    expect(categoryReport.previous.length, 1);
    expect(categoryReport.buckets.length, 2);
    expect(categoryReport.buckets.first.amount / categoryReport.total * 100,
        closeTo(66.6667, .0001));
    expect(categoryReport.buckets.last.amount / categoryReport.total * 100,
        closeTo(33.3333, .0001));
    expect(categoryReport.total / current.days, 1500000 / current.days);
    const scheme = ClassificationScheme(
        id: 'custom',
        name: 'Custom',
        groups: [ClassificationGroup('living', 'Living', 0xFF10B981)],
        assignments: {'food': 'living', 'transport': 'living'});
    for (final result in [
      await report(raw, byWallet: true),
      await report(raw, byNature: true),
      await report(raw, scheme: scheme),
    ]) {
      expect(result.total, 1500000);
      expect(result.previousTotal, 1000000);
      expect(result.buckets.expand((b) => b.transactions).map((t) => t.id),
          unorderedEquals(['food', 'transport']));
    }
    final scoped = await report(raw, wallets: {'bank'}, categoryIds: {'food'});
    expect(scoped.total, 1000000);
    expect(scoped.current.map((t) => t.id), ['food']);
  });

  test('Income Insights excludes withdrawals with either Savings marker',
      () async {
    await insert('salary', 20000000,
        type: CategoryType.income, category: 'salary');
    await insert('withdraw', 1000000,
        type: CategoryType.income, goal: 'goal', envelope: 'savings');
    await insert('legacy_goal', 2000000,
        type: CategoryType.income, goal: 'goal');
    await insert('refund', 3000000,
        type: CategoryType.income, envelope: 'savings');
    final rows = await read(insightsTransactionsProvider.future);
    expect(rows.map((t) => t.id), ['salary']);
    final result = await report(await db.select(db.transactions).get(),
        type: CategoryType.income);
    expect(result.total, 20000000);
    expect(result.current.length, 1);
  });

  test('Reporting streams update after insert, soft-delete and restore',
      () async {
    await insert('food', 300000);
    final period = dashboardPeriodTransactionsProvider(
        DateTimeRange(start: current.start, end: current.end));
    final providers = [
      period,
      chartExpensesStreamProvider,
      insightsTransactionsProvider
    ];
    final subscriptions = providers
        .map((provider) => container.listen(provider, (_, next) {}))
        .toList();
    Future<void> expectRows(List<String> ids) async {
      for (final provider in providers) {
        final done = Completer<void>();
        final sub = container.listen(provider, (_, next) {
          final rows = next.asData?.value;
          if (rows != null &&
              rows.length == ids.length &&
              rows.every((t) => ids.contains(t.id)) &&
              !done.isCompleted) {
            done.complete();
          }
        }, fireImmediately: true);
        try {
          await done.future.timeout(const Duration(seconds: 5));
        } finally {
          sub.close();
        }
      }
    }

    try {
      await expectRows(['food']);
      await insert('deposit', 2000000, goal: 'goal', envelope: 'savings');
      await insert('transport', 100000, category: 'transport');
      await expectRows(['food', 'transport']);
      await (db.update(db.transactions)..where((t) => t.id.equals('food')))
          .write(TransactionsCompanion(deletedAt: Value(DateTime.now())));
      await expectRows(['transport']);
      await (db.update(db.transactions)..where((t) => t.id.equals('food')))
          .write(const TransactionsCompanion(deletedAt: Value(null)));
      await expectRows(['food', 'transport']);
    } finally {
      for (final sub in subscriptions) {
        sub.close();
      }
    }
  });

  test('Reporting reads preserve Ledger, Vault, raw records and balances',
      () async {
    await insert('food', 300000);
    await db.depositToGoal(
        goalId: 'goal', walletId: 'bank', amount: 2000000, date: today);
    await db.withdrawFromGoal(
        goalId: 'goal', walletId: 'bank', amount: 1000000, date: today);
    container.read(cycleModeProvider.notifier).state = CycleMode.calendar;
    container.read(currentAnchorMonthProvider.notifier).state = current.start;
    Future<List<Object>> snapshot() async => [
          await db.select(db.transactions).get(),
          await db.select(db.wallets).get(),
          await db.select(db.savingsGoals).get(),
        ];
    final before = await snapshot();
    final ledgerBefore = await read(unifiedLedgerStreamProvider.future);
    expect(ledgerBefore.map((t) => t.id), ['food']);
    final vaultBefore = await db.watchAllVaultTransactions().first;
    expect(vaultBefore.length, 2);
    expect((await db.watchVaultTransactionsByGoal('goal').first).length, 2);
    expect((await db.watchAllTransactions().first).length, 3);
    expect((await periodRows()).map((t) => t.id), ['food']);
    expect((await read(recentTransactionsStreamProvider.future)).length, 1);
    expect(sum(await read(chartExpensesStreamProvider.future)), 300000);
    expect(
        (await report(await read(insightsTransactionsProvider.future))).total,
        300000);
    expect((await read(unifiedLedgerStreamProvider.future)).map((t) => t.id),
        ledgerBefore.map((t) => t.id));
    expect(
        (await db.watchAllVaultTransactions().first).map((t) => t.transaction),
        vaultBefore.map((t) => t.transaction));
    expect(await snapshot(), before);
    final bank = await (db.select(db.wallets)
          ..where((w) => w.id.equals('bank')))
        .getSingle();
    expect(bank.balance, 9000000);
    expect(
        (await db.select(db.savingsGoals).getSingle()).currentAmount, 1000000);
  });

  test('Actual goal settlement refund without goalId remains unreported',
      () async {
    await db.depositToGoal(
        goalId: 'goal', walletId: 'bank', amount: 2000000, date: today);
    await db.deleteGoalWithBalanceResolution(
        goalId: 'goal', refundWalletId: 'bank');
    final raw = await db.select(db.transactions).get();
    expect(raw.length, 1);
    expect(raw.single.goalId, isNull);
    expect(raw.single.envelopeType, 'savings');
    expect(raw.single.type, CategoryType.income);
    expect(await periodRows(), isEmpty);
    expect(await read(recentTransactionsStreamProvider.future), isEmpty);
    expect(await read(chartExpensesStreamProvider.future), isEmpty);
    expect(await read(insightsTransactionsProvider.future), isEmpty);
    expect((await report(raw, type: CategoryType.income)).total, 0);
    expect((await db.watchAllTransactions().first).length, 1);
    final bank = await (db.select(db.wallets)
          ..where((w) => w.id.equals('bank')))
        .getSingle();
    expect(bank.balance, 10000000);
  });
}
