import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/screens/ledger_screen.dart';
import 'package:pfm_app/features/insights/insights_data.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:pfm_app/services/backup_capsule.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer c;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs)
    ]);
    c.read(cycleModeProvider.notifier).state = CycleMode.calendar;
    await db.into(db.wallets).insert(WalletsCompanion.insert(
        id: 'w', name: 'Cash', type: 'cash', balance: const Value(2000000)));
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'food', name: 'Food', type: CategoryType.expense));
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });
  Future<double> balance() async =>
      (await db.select(db.wallets).getSingle()).balance;
  Future<List<UnifiedLedgerItem>> history(int count) async {
    final done = Completer<List<UnifiedLedgerItem>>();
    final sub = c.listen(unifiedLedgerStreamProvider, (_, next) {
      next.whenData((rows) {
        if (rows.length == count && !done.isCompleted) done.complete(rows);
      });
    }, fireImmediately: true);
    addTearDown(sub.close);
    return done.future.timeout(const Duration(seconds: 5));
  }

  for (final target in [1800000.0, 2200000.0, 2000000.0]) {
    test('audit $target is neutral in totals/report/budget; history retained',
        () async {
      await db.adjustWalletBalance(
          walletId: 'w', realBalance: target, reason: 'Counted cash');
      expect(await balance(), target);
      final rows = await history(target == 2000000 ? 0 : 1);
      final sum = computeLedgerSummary(rows);
      expect(sum.moneyIn, 0);
      expect(sum.moneyOut, 0);
      final txs = await db.select(db.transactions).get();
      if (txs.isNotEmpty) {
        expect(txs.single.isBalanceAdjustment, true);
        expect(txs.single.signedWalletAdjustment, target - 2000000);
        expect(rows.single.title, contains('Điều chỉnh'));
      }
      final now = DateTime.now();
      final report = buildInsightsReport(
          type: CategoryType.expense,
          transactions: txs,
          categories: await db.select(db.categories).get(),
          walletRecords: await db.select(db.wallets).get(),
          window: InsightsWindow(
              DateTime(now.year, now.month), DateTime(now.year, now.month + 1)),
          previousWindow: InsightsWindow(DateTime(now.year, now.month - 1),
              DateTime(now.year, now.month)));
      expect(report.current, isEmpty);
      expect(
          await db.calculateRecurringSpentForCategory(
              categoryId: 'food',
              startDate: DateTime(now.year, now.month),
              endDate: DateTime(now.year, now.month + 1)),
          0);
      await db.adjustWalletBalance(
          walletId: 'w', realBalance: target, reason: 'Same count');
      expect(await db.select(db.transactions).get(), hasLength(txs.length));
    });
  }
  test(
      'mixed normal cashflow and adjustment; repeated delete/restore exactly once',
      () async {
    await db.adjustWalletBalance(
        walletId: 'w', realBalance: 1800000, reason: 'Count');
    final audit = await db.select(db.transactions).getSingle();
    final date = DateTime.now();
    await db.insertTransactionWithBalanceUpdate(TransactionsCompanion.insert(
        id: 'expense',
        walletId: 'w',
        categoryId: 'food',
        amount: 50000,
        type: CategoryType.expense,
        date: date));
    await db.insertTransactionWithBalanceUpdate(TransactionsCompanion.insert(
        id: 'income',
        walletId: 'w',
        categoryId: 'food',
        amount: 100000,
        type: CategoryType.income,
        date: date));
    final sum = computeLedgerSummary(await history(3));
    expect(sum.moneyIn, 100000);
    expect(sum.moneyOut, 50000);
    expect(await balance(), 1850000);
    await db.softDeleteTransaction(audit.id);
    await db.softDeleteTransaction(audit.id);
    expect(await balance(), 2050000);
    await db.restoreTransaction(audit.id);
    await db.restoreTransaction(audit.id);
    expect(await balance(), 1850000);
    await expectLater(
        db.updateTransactionAtomically(
            transactionId: audit.id,
            walletId: 'w',
            categoryId: 'food',
            amount: 1,
            type: CategoryType.expense,
            date: date),
        throwsStateError);
    expect(await balance(), 1850000);
  });
  test('invalid or failed audit rolls back wallet and history', () async {
    await expectLater(
        db.adjustWalletBalance(
            walletId: 'w', realBalance: double.nan, reason: ''),
        throwsArgumentError);
    await db.customStatement(
        "CREATE TRIGGER fail_audit BEFORE INSERT ON transactions BEGIN SELECT RAISE(ABORT, 'injected'); END");
    await expectLater(
        db.adjustWalletBalance(walletId: 'w', realBalance: 1800000, reason: ''),
        throwsA(anything));
    expect(await balance(), 2000000);
    expect(await db.select(db.transactions).get(), isEmpty);
  });
  test(
      'backdated expense keeps actual date; audit is current and initial balance has no fake income',
      () async {
    final date = DateTime.now().subtract(const Duration(days: 50));
    expect(await db.select(db.transactions).get(), isEmpty);
    await db.insertTransactionWithBalanceUpdate(TransactionsCompanion.insert(
        id: 'old',
        walletId: 'w',
        categoryId: 'food',
        amount: 100000,
        type: CategoryType.expense,
        date: date));
    await db.adjustWalletBalance(
        walletId: 'w', realBalance: 1800000, reason: 'Count');
    final txs = await db.select(db.transactions).get();
    expect(
        txs.singleWhere((t) => t.id == 'old').date.millisecondsSinceEpoch ~/
            1000,
        date.millisecondsSinceEpoch ~/ 1000);
    expect(
        txs.singleWhere((t) => t.isBalanceAdjustment).date.isAfter(date), true);
    await db.softDeleteTransaction('old');
    expect(await balance(), 1900000);
    await db.restoreTransaction('old');
    expect(await balance(), 1800000);
  });
  test(
      'legacy repair is exact-id structural only, amount/date/balance preserved and idempotent',
      () async {
    for (final id in [
      'tx_audit_1720000000000',
      'tx_audit_1720000000001',
      'normal',
      'tx_audit_bad',
      'tx_audit_1720000000002'
    ]) {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: id,
          walletId: 'w',
          categoryId: 'food',
          amount: 200000,
          type: id.endsWith('1') ? CategoryType.income : CategoryType.expense,
          date: DateTime(2025, 3, 4),
          envelopeType: const Value('needs'),
          note: const Value('Kiểm kê số dư ví'),
          isAiParsed: Value(id.endsWith('2'))));
    }
    expect(await db.normalizeLegacyWalletAudits(), 2);
    expect(await db.normalizeLegacyWalletAudits(), 0);
    final rows = await db.select(db.transactions).get();
    expect(rows, hasLength(5));
    expect(rows.where((t) => t.isBalanceAdjustment), hasLength(2));
    expect(
        rows.every((t) => t.amount == 200000 && t.date == DateTime(2025, 3, 4)),
        true);
    expect(await balance(), 2000000);
  });
  test(
      'Dashboard read view never mixes committed wallet and transaction versions',
      () async {
    final now = DateTime.now();
    final seen = <DashboardFinancialSnapshot>[];
    final stream = db.watchDashboardFinancialSnapshot(
        DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
    final sub = stream.listen(seen.add);
    Future<void> version(double wallet, int count) async {
      for (var i = 0; i < 100; i++) {
        if (seen.isNotEmpty &&
            seen.last.wallets.single.balance == wallet &&
            seen.last.transactions.length == count) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('No committed version $wallet/$count');
    }

    try {
      await version(2000000, 0);
      await db.insertTransactionWithBalanceUpdate(TransactionsCompanion.insert(
          id: 'live',
          walletId: 'w',
          categoryId: 'food',
          amount: 10000,
          type: CategoryType.expense,
          date: now));
      await version(1990000, 1);
      await db.updateTransactionAtomically(
          transactionId: 'live',
          walletId: 'w',
          categoryId: 'food',
          amount: 20000,
          type: CategoryType.expense,
          date: now);
      await version(1980000, 1);
      await db.softDeleteTransaction('live');
      await version(2000000, 0);
      await db.restoreTransaction('live');
      await version(1980000, 1);
      await db.customStatement(
          "CREATE TRIGGER deny_delete BEFORE UPDATE OF deleted_at ON transactions BEGIN SELECT RAISE(ABORT, 'injected'); END");
      await expectLater(db.softDeleteTransaction('live'), throwsA(anything));
      expect((await db.select(db.wallets).getSingle()).balance, 1980000);
      expect((await db.select(db.transactions).getSingle()).deletedAt, isNull);
      for (final view in seen) {
        final spent = view.transactions.fold(0.0, (sum, t) => sum + t.amount);
        expect(view.wallets.single.balance, 2000000 - spent);
      }
    } finally {
      await sub.cancel();
    }
  });

  for (final type in [
    CategoryType.balanceAdjustmentIn,
    CategoryType.balanceAdjustmentOut
  ]) {
    test('backup reconciliation reapplies $type once without changing sign',
        () async {
      final folder =
          await Directory.systemTemp.createTemp('flowy-audit-reconcile-');
      final local = File('${folder.path}/local.sqlite'),
          cloud = File('${folder.path}/cloud.sqlite');
      for (final file in [local, cloud]) {
        final disk = AppDatabase.forTesting(NativeDatabase(file));
        await disk.into(disk.wallets).insert(WalletsCompanion.insert(
            id: 'w',
            name: 'Cash',
            type: 'cash',
            balance: const Value(2000000)));
        await disk.into(disk.categories).insert(CategoriesCompanion.insert(
            id: 'food', name: 'Food', type: CategoryType.expense));
        if (file == local) {
          await disk.into(disk.transactions).insert(
              TransactionsCompanion.insert(
                  id: 'audit',
                  walletId: 'w',
                  categoryId: 'food',
                  amount: 200000,
                  type: type,
                  date: DateTime(2025),
                  envelopeType: const Value('needs')));
        }
        await disk.close();
      }
      try {
        final diff = inspectReconciliation(local.path, cloud.path);
        reconcileBackup(cloud.path, diff,
            diff.entries.map((e) => e.key).toSet(), {'w': 'w'});
        final restored =
            sql.sqlite3.open(cloud.path, mode: sql.OpenMode.readOnly);
        try {
          expect(
              restored.select('SELECT balance FROM wallets').single['balance'],
              type == CategoryType.balanceAdjustmentIn ? 2200000 : 1800000);
          expect(
              restored.select('SELECT type FROM transactions').single['type'],
              type.index);
        } finally {
          restored.close();
        }
      } finally {
        await folder.delete(recursive: true);
      }
    });
  }

  test(
      'real file legacy repair snapshots before mutation and reopening does not repeat',
      () async {
    final folder = await Directory.systemTemp.createTemp('flowy-audit-test-');
    final file = File('${folder.path}/fixture.sqlite');
    var disk = AppDatabase.forTesting(NativeDatabase(file));
    try {
      await disk.into(disk.wallets).insert(WalletsCompanion.insert(
          id: 'w', name: 'Cash', type: 'cash', balance: const Value(1800000)));
      await disk.into(disk.categories).insert(CategoriesCompanion.insert(
          id: 'food', name: 'Food', type: CategoryType.expense));
      await disk.into(disk.transactions).insert(TransactionsCompanion.insert(
          id: 'tx_audit_1720000000000',
          walletId: 'w',
          categoryId: 'food',
          amount: 200000,
          type: CategoryType.expense,
          date: DateTime(2025),
          envelopeType: const Value('needs')));
      await disk.close();
      disk = AppDatabase.forTesting(NativeDatabase(file));
      expect((await disk.select(disk.transactions).getSingle()).type,
          CategoryType.balanceAdjustmentOut);
      final backups = folder
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('pre-audit-classification'))
          .toList();
      expect(backups, hasLength(1));
      final snapshot =
          sql.sqlite3.open(backups.single.path, mode: sql.OpenMode.readOnly);
      try {
        expect(snapshot.select('SELECT type FROM transactions').single['type'],
            CategoryType.expense.index);
        expect(snapshot.select('SELECT balance FROM wallets').single['balance'],
            1800000);
      } finally {
        snapshot.close();
      }
      expect((await disk.select(disk.wallets).getSingle()).balance, 1800000);
      await disk.close();
      disk = AppDatabase.forTesting(NativeDatabase(file));
      await disk.select(disk.transactions).get();
      expect(
          folder
              .listSync()
              .whereType<File>()
              .where((f) => f.path.contains('pre-audit-classification')),
          hasLength(1));
    } finally {
      await disk.close();
      await folder.delete(recursive: true);
    }
  });
}
