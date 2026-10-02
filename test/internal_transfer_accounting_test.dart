import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'category', name: 'General', type: CategoryType.expense));
    for (final entry in {'a': 10000.0, 'b': 2000.0}.entries) {
      await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: entry.key,
          name: entry.key,
          type: 'cash',
          balance: Value(entry.value)));
    }
  });
  tearDown(() => db.close());

  Future<void> expectBalances(double a, double b) async {
    final wallets = await db.select(db.wallets).get();
    expect(wallets.singleWhere((w) => w.id == 'a').balance, closeTo(a, 1e-8));
    expect(wallets.singleWhere((w) => w.id == 'b').balance, closeTo(b, 1e-8));
    expect(wallets.fold<double>(0, (sum, w) => sum + w.balance),
        closeTo(a + b, 1e-8));
  }

  Future<Transaction> createTransfer({double fee = 0}) async {
    await db.executeInternalTransfer(
        fromWalletId: 'a',
        toWalletId: 'b',
        amount: 3000,
        fee: fee,
        date: DateTime.now());
    return (db.select(db.transactions)
          ..where((t) => t.type.equals(CategoryType.transfer.index)))
        .getSingle();
  }

  Future<Transaction> readTransfer(String id) =>
      (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

  for (final scenario in [
    (
      name: 'no fee',
      amount: 3000.0,
      fee: 0.0,
      reverse: false,
      archived: '',
      credit: ''
    ),
    (
      name: 'separate fee',
      amount: 3000.0,
      fee: 100.0,
      reverse: false,
      archived: '',
      credit: ''
    ),
    (
      name: 'reverse direction',
      amount: 1000.0,
      fee: 0.0,
      reverse: true,
      archived: '',
      credit: ''
    ),
    (
      name: 'archived source',
      amount: 3000.0,
      fee: 0.0,
      reverse: false,
      archived: 'a',
      credit: ''
    ),
    (
      name: 'archived destination',
      amount: 3000.0,
      fee: 0.0,
      reverse: false,
      archived: 'b',
      credit: ''
    ),
    (
      name: 'credit source',
      amount: 12000.0,
      fee: 0.0,
      reverse: false,
      archived: '',
      credit: 'a'
    ),
    (
      name: 'credit destination',
      amount: 3000.0,
      fee: 0.0,
      reverse: false,
      archived: '',
      credit: 'b'
    ),
    (
      name: 'decimal amount and fee',
      amount: 1234.56,
      fee: 7.89,
      reverse: false,
      archived: '',
      credit: ''
    ),
  ]) {
    test('transfer exact inverse and idempotency: ${scenario.name}', () async {
      if (scenario.credit.isNotEmpty) {
        await (db.update(db.wallets)
              ..where((w) => w.id.equals(scenario.credit)))
            .write(const WalletsCompanion(type: Value('credit')));
      }
      await db.executeInternalTransfer(
        fromWalletId: scenario.reverse ? 'b' : 'a',
        toWalletId: scenario.reverse ? 'a' : 'b',
        amount: scenario.amount,
        fee: scenario.fee,
        date: DateTime.now(),
      );
      final tx = await (db.select(db.transactions)
            ..where((t) => t.type.equals(CategoryType.transfer.index)))
          .getSingle();
      final activeA = 10000 +
          (scenario.reverse
              ? scenario.amount
              : -scenario.amount - scenario.fee);
      final activeB = 2000 +
          (scenario.reverse
              ? -scenario.amount - scenario.fee
              : scenario.amount);
      final deletedA = 10000 - (scenario.reverse ? 0.0 : scenario.fee);
      final deletedB = 2000 - (scenario.reverse ? scenario.fee : 0.0);
      await expectBalances(activeA, activeB);
      if (scenario.archived.isNotEmpty) {
        // Model an existing archived wallet without changing its accounting state.
        await (db.update(db.wallets)
              ..where((w) => w.id.equals(scenario.archived)))
            .write(const WalletsCompanion(isArchived: Value(true)));
      }
      await db.deleteTransactionWithBalanceReversal(tx.id);
      await expectBalances(deletedA, deletedB);
      final deletedAt = (await readTransfer(tx.id)).deletedAt;
      expect(deletedAt, isNotNull);
      await db.softDeleteTransaction(tx.id);
      await expectBalances(deletedA, deletedB);
      expect((await readTransfer(tx.id)).deletedAt, deletedAt);
      await db.restoreTransaction(tx.id);
      await expectBalances(activeA, activeB);
      expect((await readTransfer(tx.id)).deletedAt, isNull);
      await db.restoreTransaction(tx.id);
      await expectBalances(activeA, activeB);
      await db.softDeleteTransaction(tx.id);
      await expectBalances(deletedA, deletedB);
      expect(await db.select(db.transactions).get(),
          hasLength(scenario.fee > 0 ? 2 : 1));
    });
  }

  test('main transfer and separate fee reverse independently', () async {
    final tx = await createTransfer(fee: 100);
    final fee = await (db.select(db.transactions)
          ..where((t) => t.type.equals(CategoryType.expense.index)))
        .getSingle();
    await db.softDeleteTransaction(tx.id);
    await expectBalances(9900, 2000);
    expect((await readTransfer(fee.id)).deletedAt, isNull);
    await db.softDeleteTransaction(fee.id);
    await expectBalances(10000, 2000);
    await db.restoreTransaction(fee.id);
    await expectBalances(9900, 2000);
    await db.restoreTransaction(tx.id);
    await expectBalances(6900, 5000);
    await db.softDeleteTransaction(fee.id);
    await expectBalances(7000, 5000);
    await db.restoreTransaction(fee.id);
    await expectBalances(6900, 5000);
  });

  for (final restore in [false, true]) {
    for (final broken in [
      'null destination',
      'missing source',
      'missing destination',
      'same wallet'
    ]) {
      test('${restore ? 'restore' : 'delete'} rejects $broken atomically',
          () async {
        final tx = await createTransfer();
        if (restore) await db.softDeleteTransaction(tx.id);
        final deletedAt = (await readTransfer(tx.id)).deletedAt;
        // Corrupt only the fixture to cover imported/orphaned records.
        await db.customStatement('PRAGMA foreign_keys = OFF');
        await (db.update(db.transactions)..where((t) => t.id.equals(tx.id)))
            .write(
          TransactionsCompanion(
            walletId: broken == 'missing source'
                ? const Value('missing')
                : const Value.absent(),
            toWalletId: switch (broken) {
              'null destination' => const Value(null),
              'missing destination' => const Value('missing'),
              'same wallet' => const Value('a'),
              _ => const Value.absent(),
            },
          ),
        );
        await db.customStatement('PRAGMA foreign_keys = ON');
        await expectLater(
            restore
                ? db.restoreTransaction(tx.id)
                : db.softDeleteTransaction(tx.id),
            throwsStateError);
        await expectBalances(restore ? 10000 : 7000, restore ? 2000 : 5000);
        expect((await readTransfer(tx.id)).deletedAt, deletedAt);
      });
    }
    for (final failAt in ['destination', 'deletedAt']) {
      test(
          '${restore ? 'restore' : 'delete'} rolls back if $failAt write fails',
          () async {
        final tx = await createTransfer();
        if (restore) await db.softDeleteTransaction(tx.id);
        final deletedAt = (await readTransfer(tx.id)).deletedAt;
        await db.customStatement(failAt == 'destination'
            ? "CREATE TRIGGER fail_write BEFORE UPDATE OF balance ON wallets WHEN OLD.id = 'b' BEGIN SELECT RAISE(ABORT, 'injected failure'); END"
            : "CREATE TRIGGER fail_write BEFORE UPDATE OF deleted_at ON transactions BEGIN SELECT RAISE(ABORT, 'injected failure'); END");
        await expectLater(
            restore
                ? db.restoreTransaction(tx.id)
                : db.softDeleteTransaction(tx.id),
            throwsA(isA<Exception>()));
        await expectBalances(restore ? 10000 : 7000, restore ? 2000 : 5000);
        expect((await readTransfer(tx.id)).deletedAt, deletedAt);
      });
    }
  }

  test('income delete and restore behavior is unchanged', () async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'income',
          walletId: 'a',
          categoryId: 'category',
          amount: 500,
          type: CategoryType.income,
          date: DateTime.now(),
        ));
    await (db.update(db.wallets)..where((w) => w.id.equals('a')))
        .write(const WalletsCompanion(balance: Value(10500)));
    await db.softDeleteTransaction('income');
    await expectBalances(10000, 2000);
    await db.restoreTransaction('income');
    await expectBalances(10500, 2000);
  });
}
