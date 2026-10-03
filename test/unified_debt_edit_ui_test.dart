import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/services/backup_change_observer.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/currency_text.dart';
import 'package:pfm_app/widgets/quick_entry_sheet.dart';
import 'package:pfm_app/widgets/sliding_segmented_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Gate a real entity query without changing any production API or DAO behavior.
class _EntityLoadGate extends QueryInterceptor {
  Completer<void>? release;
  final entered = Completer<void>();

  @override
  Future<List<Map<String, Object?>>> runSelect(
      QueryExecutor executor, String statement, List<Object?> args) async {
    if (release != null &&
        statement.contains('debt_contacts') &&
        statement.contains('WHERE')) {
      if (!entered.isCompleted) entered.complete();
      await release!.future;
    }
    return executor.runSelect(statement, args);
  }
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late _EntityLoadGate gate;
  late DebtTransaction debt;
  const updateLabel = '✓ CẬP NHẬT GIAO DỊCH';
  const createDebtLabel = '✓ XÁC NHẬN GIAO DỊCH VAY NỢ';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    gate = _EntityLoadGate();
    db = AppDatabase.forTesting(NativeDatabase.memory().interceptWith(gate));
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: 'wallet',
          name: 'Selected wallet',
          type: 'cash',
          balance: const Value(10000000),
        ));
    await db.into(db.debtContacts).insert(DebtContactsCompanion.insert(
          id: 'contact',
          name: 'Selected partner',
        ));
    for (final type in [CategoryType.expense, CategoryType.income]) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: type.name,
            name: type.name,
            type: type,
          ));
    }
    await db.createDebtTransaction(
      id: 'debt',
      contactId: 'contact',
      walletId: 'wallet',
      type: 'BORROW',
      amount: 200000,
      date: DateTime(2026, 8, 12, 15, 37),
      dueDate: DateTime(2026, 9, 2),
      note: 'Prefilled debt note',
    );
    debt = await db.select(db.debtTransactions).getSingle();
  });
  tearDown(() => db.close());

  Future<void> open(
    WidgetTester tester, {
    DebtTransaction? initialDebt,
    Transaction? initialNormal,
    bool newDebt = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => QuickEntrySheet.show(
                            context,
                            initialDebtTransaction: initialDebt,
                            initialTransaction: initialNormal,
                            prefilledDebtType: newDebt ? 'LEND' : null,
                            prefilledAmount: newDebt ? 200000 : null,
                          ),
                      child: const Text('Open entry'))))),
    ));
    await tester.tap(find.text('Open entry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  ElevatedButton submit(WidgetTester tester, String label) =>
      tester.widget<ElevatedButton>(find.ancestor(
          of: find.text(label), matching: find.byType(ElevatedButton)));

  testWidgets('new debt retains create label without edit header or delete',
      (tester) async {
    await open(tester, newDebt: true);
    expect(find.text(createDebtLabel), findsOneWidget);
    expect(find.text(updateLabel), findsNothing);
    expect(find.text('Chỉnh sửa giao dịch'), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    await close(tester);
  });

  testWidgets('editing debt uses update label header and delete action',
      (tester) async {
    await open(tester, initialDebt: debt);
    expect(find.text(updateLabel), findsOneWidget);
    expect(find.text(createDebtLabel), findsNothing);
    expect(find.text('Chỉnh sửa giao dịch'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    await close(tester);
  });

  for (final type in [CategoryType.expense, CategoryType.income]) {
    testWidgets('editing ${type.name} retains update label across debt tab',
        (tester) async {
      await tester.runAsync(() =>
          db.insertTransactionWithBalanceUpdate(TransactionsCompanion.insert(
            id: 'normal',
            walletId: 'wallet',
            categoryId: type.name,
            amount: 200000,
            type: type,
            date: DateTime(2026, 8, 12),
            note: const Value('#amortized'),
          )));
      final normal =
          await tester.runAsync(() => db.select(db.transactions).getSingle());
      await open(tester, initialNormal: normal!);
      expect(find.text(updateLabel), findsOneWidget);
      final tabs = tester.widget<SlidingSegmentedBar<CategoryType>>(
          find.byType(SlidingSegmentedBar<CategoryType>));
      tabs.onValueChanged(CategoryType.debt);
      await tester.pumpAndSettle();
      expect(find.text(updateLabel), findsOneWidget);
      expect(find.text(createDebtLabel), findsNothing);
      await close(tester);
    });
  }

  testWidgets('debt prefill preserves all fields and blocks save during load',
      (tester) async {
    gate.release = Completer<void>();
    await open(tester, initialDebt: debt, settle: false);
    expect(gate.entered.isCompleted, isTrue);
    expect(submit(tester, updateLabel).onPressed, isNull);
    expect(
        tester
            .widget<SlidingSegmentedBar<CategoryType>>(
                find.byType(SlidingSegmentedBar<CategoryType>))
            .selectedValue,
        CategoryType.debt);
    expect(
        tester
            .widget<SlidingSegmentedBar<String>>(
                find.byType(SlidingSegmentedBar<String>))
            .selectedValue,
        'BORROW');
    expect(find.text('12/08/2026'), findsOneWidget);
    expect(find.text('15:37'), findsOneWidget);
    expect(find.text('02/09'), findsOneWidget);
    expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .any((field) => field.controller?.text == 'Prefilled debt note'),
        isTrue);
    expect(find.textContaining('200.000'), findsWidgets);
    gate.release!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Selected partner'), findsOneWidget);
    expect(find.text('Selected wallet'), findsWidgets);
    expect(submit(tester, updateLabel).onPressed, isNotNull);
    expect(
        tester
            .widgetList<CurrencyText>(find.byType(CurrencyText))
            .any((text) => text.data.contains('200.000')),
        isTrue);
    await close(tester);
  });

  test('debt delete uses DB observer without a second manual dirty call',
      () async {
    // Architectural contract: the UI delegates accounting to this DAO, and
    // must not add an independent dirty path on top of its table observer.
    final source =
        await File('lib/widgets/quick_entry_sheet.dart').readAsString();
    final deleteHandler = source.substring(
        source.indexOf('Future<void> _confirmDeleteTransaction()'),
        source.indexOf('Future<void> _submitTransaction()'));
    expect(deleteHandler,
        contains('await db.deleteDebtTransactionWithSafetyCheck(debtTx.id)'));
    for (final manualApi in [
      'notifyDataChanged(',
      'markBackupDirty(',
      'markDirty('
    ]) {
      expect(deleteHandler, isNot(contains(manualApi)));
    }
    final observed = Completer<void>();
    final observer = observeBackupDatabaseChanges(db, () {
      if (!observed.isCompleted) observed.complete();
    });
    try {
      await db.deleteDebtTransactionWithSafetyCheck(debt.id);
      await observed.future.timeout(const Duration(seconds: 5));
      expect((await db.select(db.debtTransactions).getSingle()).deletedAt,
          isNotNull);
      expect((await db.select(db.wallets).getSingle()).balance, 10000000);
      expect((await db.select(db.debtContacts).getSingle()).netBalance, 0);
    } finally {
      await observer.cancel();
    }
  });
}
