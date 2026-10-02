import 'dart:convert';

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/features/insights/insights_data.dart';
import 'package:pfm_app/features/notifications/notification_host.dart';
import 'package:pfm_app/features/notifications/notification_preferences.dart';
import 'package:pfm_app/features/notifications/notification_service.dart';
import 'package:pfm_app/screens/budget_screen.dart';
import 'package:pfm_app/screens/dashboard_screen.dart';
import 'package:pfm_app/services/auth_profile_service.dart';
import 'package:pfm_app/services/cloud_backup_service.dart';
import 'package:pfm_app/services/fiscal_day.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoBackup extends Fake implements CloudBackupService {
  @override
  Future<void> notifyDataChanged() async {}
}

class _ObservedCoordinator extends NotificationCoordinator {
  _ObservedCoordinator(super.db);
  final inputs = <({double safe, double spent})>[];
  @override
  Future<void> refresh(NotificationPreferences prefs, Map<String, int> cycles,
      {FiscalDayBoundary boundary = const FiscalDayBoundary()}) async {}

  @override
  Future<void> dailyLimit(
      {required double safe,
      required double spent,
      required NotificationPreferences prefs,
      FiscalDayBoundary boundary = const FiscalDayBoundary()}) async {
    inputs.add((safe: safe, spent: spent));
    await super
        .dailyLimit(safe: safe, spent: spent, prefs: prefs, boundary: boundary);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;
  late _ObservedCoordinator observed;
  late DateTime today, start, end;
  var containerDisposed = false;
  var databaseClosed = false;
  const quiet = NotificationPreferences({
    'evening': false,
    'midday': false,
    'digest': false,
    'debts': false,
    'budget80': false,
    'budget100': false,
    'dailyLimit': true,
  });

  setUp(() async {
    containerDisposed = false;
    databaseClosed = false;
    SharedPreferences.setMockInitialValues({
      'notification_preferences_v1': jsonEncode(quiet.values),
      'flowy_cycle_start_day': 1,
    });
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    observed = _ObservedCoordinator(db);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentUserProfileProvider.overrideWithValue(UserProfile.guest()),
      notificationCoordinatorProvider.overrideWithValue(observed),
      cloudBackupServiceProvider.overrideWithValue(_NoBackup()),
    ]);
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    start = DateTime(now.year, now.month);
    end = DateTime(now.year, now.month + 1);
    for (final id in ['food', 'snack', 'other']) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: id,
          name: id,
          type: CategoryType.expense,
          parentId: Value(id == 'snack' ? 'food' : null)));
    }
    await db.into(db.wallets).insert(WalletsCompanion.insert(
        id: 'bank',
        name: 'Bank',
        type: 'bank',
        balance: const Value(100000000)));
    await db.into(db.savingsGoals).insert(SavingsGoalsCompanion.insert(
        id: 'goal', title: 'Savings', targetAmount: 10000000));
  });
  tearDown(() async {
    if (!containerDisposed) container.dispose();
    if (!databaseClosed) await db.close();
  });

  Future<void> insert(String id, double amount,
      {String category = 'food',
      CategoryType type = CategoryType.expense,
      String? goal,
      String? envelope,
      String? project,
      String? note,
      String? merchant,
      DateTime? date,
      DateTime? deletedAt}) async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: id,
        walletId: 'bank',
        categoryId: category,
        amount: amount,
        type: type,
        date: date ?? today.add(const Duration(hours: 12)),
        goalId: Value(goal),
        envelopeType: Value(envelope),
        projectBudgetId: Value(project),
        note: Value(note),
        merchant: Value(merchant),
        deletedAt: Value(deletedAt)));
  }

  Future<void> budget(double amount) async {
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
        id: 'budget', categoryId: 'food', amount: amount, periodMonth: start));
  }

  Future<void> project() async {
    await db.createProjectBudget(
        id: 'project',
        title: 'Trip',
        tag: '#trip',
        targetAmount: 5000000,
        startDate: start,
        endDate: end);
  }

  Future<double> recurring() => db.calculateRecurringSpentForCategory(
      categoryId: 'food',
      startDate: start,
      endDate: end.subtract(const Duration(seconds: 1)),
      isParentCategory: true);

  Future<T> read<T>(ProviderListenable<Future<T>> provider) async {
    final subscription = container.listen(provider, (_, next) {});
    try {
      return await container.read(provider);
    } finally {
      subscription.close();
    }
  }

  Future<List<AppNotification>> refresh(NotificationPreferences prefs) async {
    await NotificationCoordinator(db).refresh(prefs, const {'default': 1});
    return db.select(db.appNotifications).get();
  }

  test('Recurring DAO and Budget source exclude new/legacy Savings', () async {
    await budget(5000000);
    await insert('food', 2000000);
    await insert('needs', 1000000, category: 'snack', envelope: 'needs');
    await insert('new_deposit', 4000000, goal: 'goal', envelope: 'savings');
    await insert('legacy_goal', 2000000, goal: 'goal');
    await insert('legacy_envelope', 1000000, envelope: 'savings');
    await insert('withdraw', 3000000,
        type: CategoryType.income, goal: 'goal', envelope: 'savings');
    await insert('deleted', 9000000, deletedAt: DateTime.now());
    await insert('outside', 5000000, date: end);
    expect(await recurring(), 3000000);
    final rows = await read(expenseTransactionsStreamProvider.future);
    expect(
        rows.map((t) => t.id), unorderedEquals(['food', 'needs', 'outside']));
    expect(
        rows
            .where((t) => t.date.isBefore(end))
            .fold(0.0, (sum, t) => sum + t.amount),
        3000000);
  });

  test(
      'Needs/Wants stay included; project exclusion in recurring DAO is retained',
      () async {
    await project();
    await insert('needs', 500000, envelope: 'needs');
    await insert('wants', 700000, envelope: 'wants');
    await insert('event_id', 900000, project: 'project');
    await insert('event_tag', 800000, note: '#trip');
    expect(await recurring(), 1200000);
    final rows = await read(expenseTransactionsStreamProvider.future);
    expect(rows.map((t) => t.id),
        unorderedEquals(['needs', 'wants', 'event_id', 'event_tag']));
  });

  test(
      'Project ID/note/merchant matches never admit Savings; normal types remain',
      () async {
    await project();
    await insert('normal_id', 300000, project: 'project');
    await insert('normal_note', 200000, note: 'Hotel #trip', envelope: 'needs');
    await insert('normal_merchant', 100000,
        merchant: '#trip', envelope: 'wants');
    await insert('new_savings', 2000000,
        project: 'project', goal: 'goal', envelope: 'savings');
    await insert('legacy_goal', 3000000, note: '#trip', goal: 'goal');
    await insert('legacy_envelope', 4000000,
        merchant: '#trip', envelope: 'savings');
    await insert('refund', 1000000,
        project: 'project', type: CategoryType.income, envelope: 'savings');
    await insert('income', 500000,
        project: 'project', type: CategoryType.income);
    await insert('transfer', 600000,
        note: '#trip', type: CategoryType.transfer);
    await insert('deleted', 700000,
        project: 'project', deletedAt: DateTime.now());
    await insert('unrelated', 800000);
    final rows = await db.watchTransactionsForProject('project', '#trip').first;
    expect(
        rows.map((t) => t.id),
        unorderedEquals([
          'normal_id',
          'normal_note',
          'normal_merchant',
          'income',
          'transfer'
        ]));
    expect(await db.calculateProjectSpent('project', '#trip'), 600000);
    // Preserve the existing stream type contract; the UI's fold-all bug is separate.
    expect(rows.fold(0.0, (sum, t) => sum + t.amount), 1700000);
  });

  for (final scenario in [
    (spent: 7000000.0, savings: 2000000.0, threshold: 0, percent: 70),
    (spent: 8200000.0, savings: 5000000.0, threshold: 80, percent: 82),
    (spent: 9600000.0, savings: 500000.0, threshold: 80, percent: 96),
    (spent: 10200000.0, savings: 5000000.0, threshold: 100, percent: 102),
  ]) {
    test('Budget alert reflects real ${scenario.percent}%, excluding Savings',
        () async {
      await budget(10000000);
      await insert('real', scenario.spent,
          category: 'snack', envelope: 'needs');
      await insert('deposit', scenario.savings,
          goal: 'goal', envelope: 'savings');
      await insert('legacy_goal', 2000000, goal: 'goal');
      await insert('legacy_envelope', 3000000, envelope: 'savings');
      await insert('deleted', 8000000, deletedAt: DateTime.now());
      final prefs =
          quiet.withValue('budget80', true).withValue('budget100', true);
      final notices =
          (await refresh(prefs)).where((n) => n.type == 'budget').toList();
      final uiRows = await read(expenseTransactionsStreamProvider.future);
      expect(uiRows.fold(0.0, (sum, t) => sum + t.amount), scenario.spent);
      expect(await recurring(), scenario.spent);
      final report = buildInsightsReport(
          transactions: await read(insightsTransactionsProvider.future),
          categories: await db.select(db.categories).get(),
          window: InsightsWindow(start, end),
          previousWindow:
              InsightsWindow(DateTime(start.year, start.month - 1), start),
          type: CategoryType.expense,
          categoryIds: {'food', 'snack'});
      expect(report.total, scenario.spent);
      if (scenario.threshold == 0) {
        expect(notices, isEmpty);
      } else {
        expect(notices.length, 1);
        expect(notices.single.dedupKey, endsWith(':${scenario.threshold}'));
        expect(
            notices.single.body, startsWith('Đã dùng ${scenario.percent}%:'));
      }
      // Refresh is idempotent: no second notice for the same threshold/window.
      expect((await refresh(prefs)).where((n) => n.type == 'budget').length,
          notices.length);
    });
  }

  test('Weekly financial amounts and count exclude deposits/withdrawals',
      () async {
    final sunday = today.add(Duration(days: 7 - today.weekday));
    final monday = sunday.subtract(const Duration(days: 6));
    await insert('salary', 20000000, type: CategoryType.income, date: monday);
    await insert('food', 4000000, date: monday);
    await insert('deposit', 5000000,
        date: monday, goal: 'goal', envelope: 'savings');
    await insert('withdraw', 2000000,
        date: monday,
        type: CategoryType.income,
        goal: 'goal',
        envelope: 'savings');
    await insert('legacy_goal', 3000000, date: monday, goal: 'goal');
    await insert('legacy_envelope', 6000000,
        date: monday, type: CategoryType.income, envelope: 'savings');
    await insert('deleted', 7000000, date: monday, deletedAt: DateTime.now());
    final notices = await refresh(quiet.withValue('digest', true));
    final digest = notices.singleWhere((n) =>
        n.type == 'digest' &&
        n.createdAt.year == sunday.year &&
        n.createdAt.month == sunday.month &&
        n.createdAt.day == sunday.day);
    expect(digest.body, startsWith('Đã ghi 2 giao dịch:'));
    expect(digest.body, contains('thu 20.000.000'));
    expect(digest.body, contains('chi 4.000.000'));
  });

  for (final onlyEmpty in [false, true]) {
    test('Activity reminder keeps Savings; onlyEmpty=$onlyEmpty', () async {
      await insert('deposit', 2000000, goal: 'goal', envelope: 'savings');
      await insert('deleted', 9000000, deletedAt: DateTime.now());
      final notices = await refresh(
          quiet.withValue('evening', true).withValue('onlyEmpty', onlyEmpty));
      final reminders = notices
          .where((n) =>
              n.type == 'reminder' &&
              n.createdAt.year == today.year &&
              n.createdAt.month == today.month &&
              n.createdAt.day == today.day)
          .toList();
      if (onlyEmpty) {
        expect(reminders, isEmpty);
      } else {
        expect(reminders.single.body, contains('đã ghi 1 giao dịch'));
      }
    });
  }

  test('Stale future budget notices are removed; delivered history is retained',
      () async {
    await budget(10000000);
    await insert('food', 7000000);
    await insert('deposit', 2000000, goal: 'goal', envelope: 'savings');
    final future = await db.createNotificationIfNotExists(
        dedupKey: 'budget:stale:80',
        title: 'Old future',
        body: 'Old amount',
        type: 'budget',
        createdAt: today.add(const Duration(days: 2)));
    final past = await db.createNotificationIfNotExists(
        dedupKey: 'budget:past:100',
        title: 'Delivered',
        body: 'History',
        type: 'budget',
        createdAt: today.subtract(const Duration(days: 1)));
    final notices = await refresh(
        quiet.withValue('budget80', true).withValue('budget100', true));
    expect(notices.any((n) => n.id == future!.id), isFalse);
    expect(notices.single.id, past!.id);
    expect(notices.single.isDismissed, isFalse);
  });

  testWidgets('Dashboard -> snapshot -> Host -> dailyLimit uses real spending',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final daysRemaining =
        end.subtract(const Duration(days: 1)).difference(today).inDays + 1;
    await budget(daysRemaining * 500000.0);
    await insert('food', 100000);
    await insert('deposit', 3000000, goal: 'goal', envelope: 'savings');
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
            home: NotificationHost(child: DashboardScreen()))));

    Future<void> waitForSpent(double spent) async {
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 50));
        if (observed.inputs.any((input) => input.spent == spent)) return;
      }
      fail('No Host dailyLimit call for spent=$spent');
    }

    try {
      await waitForSpent(100000);
      final snapshot = container.read(notificationDailySnapshotProvider)!;
      expect(snapshot.spent, 100000);
      expect(snapshot.safe, 400000);
      expect(observed.inputs.last, (safe: 400000.0, spent: 100000.0));
      expect(await tester.runAsync(() => db.select(db.appNotifications).get()),
          isEmpty);
      await tester.runAsync(() async {
        await (db.update(db.transactions)..where((t) => t.id.equals('food')))
            .write(const TransactionsCompanion(amount: Value(600000)));
      });
      await waitForSpent(600000);
      final notices =
          await tester.runAsync(() => db.select(db.appNotifications).get());
      expect(notices!.length, 1);
      expect(notices.single.dedupKey, startsWith('safe:'));
      expect(notices.single.body, contains('600.000'));
      expect(observed.inputs.last.safe, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      containerDisposed = true;
      await tester.pump();
      final closing = db.close().then((_) {
        databaseClosed = true;
      });
      // Drift stream closures belong to the widget test's fake async zone.
      for (var i = 0; i < 30 && !databaseClosed; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
      }
      await closing;
      await tester.pump();
    }
  });
}
