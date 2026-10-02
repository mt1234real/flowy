import 'dart:async';

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/screens/ledger_screen.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late DateTime date;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    container.read(cycleModeProvider.notifier).state = CycleMode.calendar;
    final now = DateTime.now();
    date = DateTime(now.year, now.month, now.day, 12);
    for (final id in ['a', 'b']) {
      await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: id,
          name: id,
          type: 'cash',
          balance: Value(id == 'a' ? 10000000 : 5000000)));
    }
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'food', name: 'Food', type: CategoryType.expense));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Transaction> transfer({double fee = 0}) async {
    await db.executeInternalTransfer(
        fromWalletId: 'a',
        toWalletId: 'b',
        amount: 3000000,
        fee: fee,
        date: date);
    return (db.select(db.transactions)
          ..where((t) => t.type.equals(CategoryType.transfer.index)))
        .getSingle();
  }

  // Keep the real provider alive across soft-delete/restore. Waiting for the
  // expected rows avoids depending on the order of its five initial streams.
  Future<List<UnifiedLedgerItem>> rowsWhere(
      bool Function(List<UnifiedLedgerItem>) predicate) async {
    final completer = Completer<List<UnifiedLedgerItem>>();
    final subscription =
        container.listen(unifiedLedgerStreamProvider, (_, next) {
      next.whenData((rows) {
        if (!completer.isCompleted && predicate(rows)) {
          completer.complete(rows);
        }
      });
      if (next.hasError && !completer.isCompleted) {
        completer.completeError(next.error!, next.stackTrace);
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);
    return completer.future.timeout(const Duration(seconds: 5));
  }

  void scope(String wallet) {
    container.read(ledgerFilterCriteriaProvider.notifier).state =
        LedgerFilterCriteria(walletId: wallet);
  }

  void expectSummary(List<UnifiedLedgerItem> rows,
      {String? wallet, double moneyIn = 0, double moneyOut = 0}) {
    final summary = computeLedgerSummary(rows, walletId: wallet);
    expect(summary.moneyIn, moneyIn);
    expect(summary.moneyOut, moneyOut);
    expect(summary.net, moneyIn - moneyOut);
  }

  test('ledgerAllWallets_transferIsNeutral and history remains visible',
      () async {
    final tx = await transfer();
    final rows = await rowsWhere((rows) => rows.length == 1);
    expect(rows.single.id, tx.id);
    expectSummary(rows);
    final wallets = await db.select(db.wallets).get();
    expect(wallets.singleWhere((w) => w.id == 'a').balance, 7000000);
    expect(wallets.singleWhere((w) => w.id == 'b').balance, 8000000);
  });

  test('ledgerAllWallets_reconcilesIncomeExpenseAndTransfer', () async {
    await transfer();
    await db.createProjectBudget(
        id: 'project',
        title: 'Trip',
        tag: '#trip',
        targetAmount: 5000000,
        startDate: date,
        endDate: date.add(const Duration(days: 2)));
    for (final entry in [
      ('income', 20000000.0, CategoryType.income),
      ('food', 2000000.0, CategoryType.expense),
      ('transport', 1000000.0, CategoryType.expense),
      ('project', 2000000.0, CategoryType.expense),
    ]) {
      await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: entry.$1,
          walletId: 'a',
          categoryId: 'food',
          amount: entry.$2,
          type: entry.$3,
          date: date,
          projectBudgetId: Value(entry.$1 == 'project' ? 'project' : null)));
    }
    final rows = await rowsWhere((rows) => rows.length == 5);
    expectSummary(rows, moneyIn: 20000000, moneyOut: 5000000);
    expect(rows.where((row) => row.standardTx?.type == CategoryType.transfer),
        hasLength(1));
  });

  test('ledgerAllWallets_transferFeeCountsAsExpense once', () async {
    await transfer(fee: 100000);
    final rows = await rowsWhere((rows) => rows.length == 2);
    expectSummary(rows, moneyOut: 100000);
    expect(rows.where((row) => row.standardTx?.type == CategoryType.expense),
        hasLength(1));
  });

  test('ledgerSourceWallet_transferIsOutflow', () async {
    await transfer(fee: 100000);
    scope('a');
    final rows = await rowsWhere((rows) => rows.length == 2);
    expectSummary(rows, wallet: 'a', moneyOut: 3100000);
    expect(rows.every((row) => !row.isMoneyIn), isTrue);
  });

  test('ledgerDestinationWallet_transferIsInflow without source fee', () async {
    final tx = await transfer(fee: 100000);
    scope('b');
    final rows = await rowsWhere((rows) => rows.length == 1);
    expect(rows.single.id, tx.id);
    expect(rows.single.isMoneyIn, isTrue);
    expectSummary(rows, wallet: 'b', moneyIn: 3000000);
    // The reporting direction never rewrites the persisted source wallet.
    expect(rows.single.standardTx!.walletId, 'a');
  });

  test('ledgerTransfer_softDeleteAndRestore update active summary once',
      () async {
    final tx = await transfer();
    scope('a');
    final initial = await rowsWhere((rows) => rows.length == 1);
    expectSummary(initial, wallet: 'a', moneyOut: 3000000);
    await db.softDeleteTransaction(tx.id);
    final deleted = await rowsWhere((rows) => rows.isEmpty);
    expectSummary(deleted, wallet: 'a');
    await db.restoreTransaction(tx.id);
    await db.restoreTransaction(tx.id);
    final restored = await rowsWhere((rows) => rows.length == 1);
    expect(restored.single.id, tx.id);
    expectSummary(restored, wallet: 'a', moneyOut: 3000000);
    expectSummary(restored);
  });

  test('ledgerExpenseTab retains expense fee and excludes transfer history',
      () async {
    await transfer(fee: 100000);
    container.read(ledgerFilterProvider.notifier).state = LedgerFilter.expense;
    final rows = await rowsWhere((rows) => rows.length == 1);
    expect(rows.single.standardTx!.type, CategoryType.expense);
    expectSummary(rows, moneyOut: 100000);
  });

  test('ledgerSummary preserves non-transfer cashflow directions', () {
    final rows = [
      for (final entry in [(true, 500.0), (false, 200.0)])
        UnifiedLedgerItem(
            id: '${entry.$1}',
            date: date,
            amount: entry.$2,
            isMoneyIn: entry.$1,
            title: 'Debt cashflow',
            subtitle: ''),
    ];
    expectSummary(rows, moneyIn: 500, moneyOut: 200);
    expectSummary(rows, wallet: 'a', moneyIn: 500, moneyOut: 200);
  });
}
