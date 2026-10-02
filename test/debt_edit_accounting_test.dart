import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/debt_transaction_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GatedDatabase extends AppDatabase {
  _GatedDatabase() : super.forTesting(NativeDatabase.memory());
  Completer<void>? saveGate;
  bool rejectSave = false;
  int saveCalls = 0;

  @override
  Future<void> updateDebtTransaction({required DebtTransaction newTx}) async {
    saveCalls++;
    if (saveGate != null) await saveGate!.future;
    if (rejectSave) throw StateError('injected failure');
    await super.updateDebtTransaction(newTx: newTx);
  }
}

void main() {
  late _GatedDatabase db;
  const initialWallets = {'a': 10000000.0, 'b': 5000000.0};
  setUp(() async {
    db = _GatedDatabase();
    for (final entry in initialWallets.entries) {
      await db.into(db.wallets).insert(WalletsCompanion.insert(
            id: entry.key,
            name: entry.key,
            type: 'cash',
            balance: Value(entry.value),
          ));
      await db.into(db.debtContacts).insert(DebtContactsCompanion.insert(
            id: entry.key,
            name: entry.key,
          ));
    }
  });
  tearDown(() => db.close());

  Future<DebtTransaction> create([String type = 'LEND']) async {
    await db.createDebtTransaction(
        id: 'debt',
        contactId: 'a',
        walletId: 'a',
        type: type,
        amount: 1000000,
        date: DateTime(2026, 10, 1));
    return db.select(db.debtTransactions).getSingle();
  }

  Future<void> reconcile() async {
    final expectedWallets = Map<String, double>.from(initialWallets);
    final expectedContacts = {'a': 0.0, 'b': 0.0};
    final rows = await (db.select(db.debtTransactions)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    for (final tx in rows) {
      final sign = switch (tx.type) {
        'LEND' => -1,
        'COLLECT' => 1,
        'BORROW' => 1,
        'REPAY' => -1,
        _ => throw StateError('Invalid fixture type'),
      };
      expectedWallets[tx.walletId] =
          expectedWallets[tx.walletId]! + sign * tx.amount;
      expectedContacts[tx.contactId] =
          expectedContacts[tx.contactId]! - sign * tx.amount;
    }
    for (final wallet in await db.select(db.wallets).get()) {
      expect(wallet.balance, closeTo(expectedWallets[wallet.id]!, 0.001));
    }
    for (final contact in await db.select(db.debtContacts).get()) {
      expect(contact.netBalance, closeTo(expectedContacts[contact.id]!, 0.001));
    }
  }

  Future<List<Object>> snapshot() async => [
        await db.select(db.wallets).get(),
        await db.select(db.debtContacts).get(),
        await db.select(db.debtTransactions).get(),
      ];

  Future<void> expectRejected(DebtTransaction requested) async {
    final before = await snapshot();
    await expectLater(
        db.updateDebtTransaction(newTx: requested), throwsStateError);
    expect(await snapshot(), before);
  }

  for (final type in ['LEND', 'COLLECT', 'BORROW', 'REPAY']) {
    test('$type same entities: amount edit uses current ledger', () async {
      final old = await create(type);
      await db.updateDebtTransaction(
          newTx: old.copyWith(
        amount: 1500000,
        isSettled: true,
        createdAt: DateTime(2000),
        deletedAt: Value(DateTime(2000)),
      ));
      final current = await db.select(db.debtTransactions).getSingle();
      expect(current.amount, 1500000);
      expect(current.isSettled, isTrue);
      expect(current.createdAt, old.createdAt);
      expect(current.deletedAt, isNull);
      await reconcile();
      // Reuse the original UI snapshot after the database has changed.
      await db.updateDebtTransaction(newTx: old.copyWith(amount: 2000000));
      await reconcile();
    });
  }

  for (final change in ['wallet', 'contact', 'both']) {
    test('change $change preserves all entity balances', () async {
      final old = await create();
      final request = old.copyWith(
        walletId: change == 'contact' ? 'a' : 'b',
        contactId: change == 'wallet' ? 'a' : 'b',
        amount: change == 'both' ? 2000000 : old.amount,
      );
      await db.updateDebtTransaction(newTx: request);
      expect(await db.select(db.debtTransactions).getSingle(), request);
      await reconcile();
    });
  }

  test('two simultaneous requests from one snapshot reconcile with final row',
      () async {
    final old = await create();
    final first = old.copyWith(amount: 1500000);
    final second = old.copyWith(
        walletId: 'b', contactId: 'b', type: 'BORROW', amount: 2000000);
    await Future.wait([
      db.updateDebtTransaction(newTx: first),
      db.updateDebtTransaction(newTx: second),
    ]);
    expect(
        await db.select(db.debtTransactions).getSingle(), anyOf(first, second));
    await reconcile();
  });

  test('two identical simultaneous submissions apply once', () async {
    final request = (await create()).copyWith(amount: 1500000);
    await Future.wait([
      db.updateDebtTransaction(newTx: request),
      db.updateDebtTransaction(newTx: request),
    ]);
    expect(await db.select(db.debtTransactions).getSingle(), request);
    await reconcile();
  });

  test('deleted after opening editor rejects stale save', () async {
    final old = await create();
    await db.softDeleteDebtTransaction(old.id);
    await expectRejected(old.copyWith(amount: 1500000));
    expect((await db.select(db.debtTransactions).getSingle()).deletedAt,
        isNotNull);
    await reconcile();
  });

  test('missing row rejects without creating a record', () async {
    final old = await create();
    await expectRejected(old.copyWith(id: 'missing'));
    await reconcile();
  });

  for (final entity in ['wallet', 'contact']) {
    for (final which in ['old', 'new']) {
      test('missing $which $entity rejects before mutation', () async {
        final old = await create();
        if (which == 'old') {
          await db.customStatement('PRAGMA foreign_keys = OFF');
          await (db.update(db.debtTransactions)
                ..where((t) => t.id.equals(old.id)))
              .write(
            DebtTransactionsCompanion(
              walletId: entity == 'wallet'
                  ? const Value('missing')
                  : const Value.absent(),
              contactId: entity == 'contact'
                  ? const Value('missing')
                  : const Value.absent(),
            ),
          );
          await db.customStatement('PRAGMA foreign_keys = ON');
        }
        await expectRejected(old.copyWith(
          walletId: which == 'new' && entity == 'wallet' ? 'missing' : 'b',
          contactId: which == 'new' && entity == 'contact' ? 'missing' : 'b',
        ));
      });
    }
  }

  for (final which in ['persisted', 'requested']) {
    test('invalid $which type rejects before mutation', () async {
      final old = await create();
      if (which == 'persisted') {
        await (db.update(db.debtTransactions)
              ..where((t) => t.id.equals(old.id)))
            .write(const DebtTransactionsCompanion(type: Value('UNKNOWN')));
      }
      await expectRejected(
          old.copyWith(type: which == 'requested' ? 'UNKNOWN' : 'LEND'));
    });
  }

  for (final failure in ['IGNORE', "ABORT, 'injected failure'"]) {
    test('debt row write $failure rolls back all balances', () async {
      final old = await create();
      final before = await snapshot();
      await db.customStatement(
          'CREATE TRIGGER fail_write BEFORE UPDATE ON debt_transactions '
          'BEGIN SELECT RAISE($failure); END');
      await expectLater(
          db.updateDebtTransaction(
              newTx: old.copyWith(
            walletId: 'b',
            contactId: 'b',
            amount: 2000000,
          )),
          throwsA(anyOf(isA<StateError>(), isA<Exception>())));
      expect(await snapshot(), before);
      await reconcile();
    });
  }

  for (final reject in [false, true]) {
    testWidgets(
        'edit UI single-submit and ${reject ? 'failure' : 'success'} lifecycle',
        (tester) async {
      final tx = await tester.runAsync(() => create());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
              home: Scaffold(
            body: DebtTransactionDetailSheet(debtTransaction: tx!),
          ))));
      await tester.runAsync(() async {
        await db.select(db.wallets).get();
      });
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chỉnh sửa khoản nợ'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(ElevatedButton, 'LƯU THAY ĐỔI');
      db.saveGate = Completer<void>();
      db.rejectSave = reject;
      // Invoke the same pre-rebuild callback twice, as with rapid taps.
      final onSave = tester.widget<ElevatedButton>(save).onPressed!;
      onSave();
      onSave();
      await tester.pump();
      expect(db.saveCalls, 1);
      expect(tester.widget<ElevatedButton>(save).onPressed, isNull);
      await tester.runAsync(() async {
        db.saveGate!.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      if (reject) {
        expect(save, findsOneWidget);
        expect(tester.widget<ElevatedButton>(save).onPressed, isNotNull);
        expect(find.text('Đã cập nhật khoản nợ và số dư ví.'), findsNothing);
        expect(
            find.text(
                'Chưa thể cập nhật khoản nợ. Hãy đóng và mở lại giao dịch rồi thử lại.'),
            findsOneWidget);
      } else {
        expect(save, findsNothing);
        await tester.runAsync(reconcile);
      }
      // Let the existing feedback banner finish its delayed dismissal.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
