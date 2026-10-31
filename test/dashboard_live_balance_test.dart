import 'package:pfm_app/services/budget_spending.dart';
import 'package:pfm_app/services/budget_spending_provider.dart';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/screens/dashboard_screen.dart';
import 'package:pfm_app/screens/ledger_screen.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pfm_app/widgets/quick_entry_sheet.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer c;
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs)
    ]);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  testWidgets(
      'Dashboard follows per-budget add edit delete undo; audit changes wallet only',
      (tester) async {
    c.read(dashboardCycleModeProvider.notifier).state = CycleMode.calendar;
    final now = DateTime.now();
    await tester.runAsync(() async {
      await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: 'w', name: 'Cash', type: 'cash', balance: const Value(2000000)));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'food', name: 'Food', type: CategoryType.expense));
      await db.into(db.budgets).insert(BudgetsCompanion.insert(id:'food-budget',categoryId:'food',amount:1000000,periodMonth:DateTime(now.year,now.month),cycleStartDay:const Value(1)));
    });
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c, child: const MaterialApp(home: DashboardScreen())));
    Future<void> mutate(Future<void> Function() action) async {
      Object? error;
      var done = false;
      action().then((_) {
        done = true;
      }, onError: (Object e) {
        error = e;
        done = true;
      });
      for (var i = 0; i < 100 && !done; i++) {
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      expect(done, true, reason: 'Committed database mutation completed');
      if (error != null) throw error!;
    }

    Future<void> flush() async {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump();
      await tester.pump();
    }

    await flush();
    BudgetSpending hero() => c.read(budgetSpendingOverviewProvider).requireValue.items.single;
    final initial = hero().remaining;
    expect(initial, greaterThan(0));
    final element = tester.element(find.byType(DashboardScreen));
    await mutate(() => db.insertTransactionWithBalanceUpdate(
        TransactionsCompanion.insert(
            id: 't',
            walletId: 'w',
            categoryId: 'food',
            amount: 10000,
            type: CategoryType.expense,
            date: now)));
    await flush();
    expect(hero().remaining, lessThan(initial));
    await mutate(() => db.updateTransactionAtomically(
        transactionId: 't',
        walletId: 'w',
        categoryId: 'food',
        amount: 20000,
        type: CategoryType.expense,
        date: now));
    await flush();
    final edited = hero().remaining;
    expect(edited, initial - 20000);
    await mutate(() => db.softDeleteTransaction('t'));
    await flush();
    expect(hero().remaining, initial);
    await mutate(() => db.restoreTransaction('t'));
    await flush();
    expect(hero().remaining, edited);
    // An audit changes actual liquidity, never plan allowance/spending.
    final spentBeforeAudit = hero().spent;
    await mutate(() => db.adjustWalletBalance(
        walletId: 'w', realBalance: 1800000, reason: 'Counted cash'));
    await flush();
    expect(hero().spent, spentBeforeAudit);
    expect(c.read(budgetSpendingOverviewProvider).requireValue.source.wallets.single.balance, 1800000);
    expect(hero().remaining, edited);
    final afterAudit = hero().remaining;
    await mutate(() => db.adjustWalletBalance(
        walletId: 'w', realBalance: 2200000, reason: 'Counted cash'));
    await flush();
    expect(hero().spent, spentBeforeAudit);
    expect(c.read(budgetSpendingOverviewProvider).requireValue.source.wallets.single.balance, 2200000);
    expect(hero().remaining, afterAudit);
    expect(tester.element(find.byType(DashboardScreen)), same(element));
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await tester.pumpAndSettle();
    await tester.runAsync(db.close);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'adjustment-only day stays visible and opens read-only audit detail',
      (tester) async {
    c.read(cycleModeProvider.notifier).state = CycleMode.calendar;
    await tester.runAsync(() async {
      await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: 'w', name: 'Cash', type: 'cash', balance: const Value(2000000)));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'food', name: 'Food', type: CategoryType.expense));
      await db.adjustWalletBalance(
          walletId: 'w', realBalance: 1800000, reason: 'Counted cash');
    });
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: c, child: const MaterialApp(home: LedgerScreen())));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final row = find.text('Kiểm kê ví · Điều chỉnh số dư');
    expect(row, findsOneWidget);
    expect(find.textContaining('Chưa có giao dịch nào'), findsNothing);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(
        find.text(
            'Điều chỉnh số dư không tính vào thu nhập, chi tiêu hoặc ngân sách danh mục.'),
        findsOneWidget);
    expect(find.textContaining('Counted cash'), findsOneWidget);
    expect(find.byType(QuickEntrySheet), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    await tester.pumpAndSettle();
    await tester.runAsync(db.close);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
