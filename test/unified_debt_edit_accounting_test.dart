import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';

void main() {
  late AppDatabase db;
  final date = DateTime(2026, 10, 1, 15, 37);
  const debtTypes = ['LEND', 'COLLECT', 'BORROW', 'REPAY'];
  const walletSign = {'LEND': -1, 'COLLECT': 1, 'BORROW': 1, 'REPAY': -1};

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final entry in {'a': 10000000.0, 'b': 5000000.0}.entries) {
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
    for (final type in [CategoryType.expense, CategoryType.income]) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: type.name,
            name: type.name,
            type: type,
          ));
    }
  });
  tearDown(() => db.close());

  Future<DebtTransaction> createDebt(String type) async {
    await db.createDebtTransaction(
      id: 'entry',
      contactId: 'a',
      walletId: 'a',
      type: type,
      amount: 1000000,
      date: date,
      note: 'Original note',
      dueDate: DateTime(2026, 11, 1),
    );
    return db.select(db.debtTransactions).getSingle();
  }

  Future<void> createNormal(CategoryType type) =>
      db.insertTransactionWithBalanceUpdate(TransactionsCompanion.insert(
        id: 'entry',
        walletId: 'a',
        categoryId: type.name,
        type: type,
        amount: 1000000,
        date: date,
      ));

  Future<void> expectBalances({
    double a = 10000000,
    double b = 5000000,
    double contactA = 0,
    double contactB = 0,
  }) async {
    final wallets = await db.select(db.wallets).get();
    final contacts = await db.select(db.debtContacts).get();
    expect({for (final w in wallets) w.id: w.balance}, {'a': a, 'b': b});
    expect({for (final c in contacts) c.id: c.netBalance},
        {'a': contactA, 'b': contactB});
  }

  Future<List<Object>> snapshot() async => [
        await db.select(db.wallets).get(),
        await db.select(db.debtContacts).get(),
        await db.select(db.debtTransactions).get(),
        await db.select(db.transactions).get(),
      ];

  for (final type in debtTypes) {
    test('debtEdit_${type.toLowerCase()}AmountChange', () async {
      final old = await createDebt(type);
      await db.updateDebtTransaction(newTx: old.copyWith(amount: 1500000));
      final delta = walletSign[type]! * 1500000.0;
      await expectBalances(a: 10000000 + delta, contactA: -delta);
      final edited = await db.select(db.debtTransactions).getSingle();
      expect(edited.id, old.id);
      expect(edited.createdAt, old.createdAt);
      expect(edited.amount, 1500000);
      expect(edited.deletedAt, isNull);
    });

    test('delete$type reverses balances and repeated restore has no drift',
        () async {
      await createDebt(type);
      final delta = walletSign[type]! * 1000000.0;
      for (var cycle = 0; cycle < 3; cycle++) {
        await db.deleteDebtTransactionWithSafetyCheck('entry');
        await db.deleteDebtTransactionWithSafetyCheck('entry');
        await expectBalances();
        expect((await db.select(db.debtTransactions).getSingle()).deletedAt,
            isNotNull);
        await db.restoreDebtTransaction('entry');
        await db.restoreDebtTransaction('entry');
        await expectBalances(a: 10000000 + delta, contactA: -delta);
        expect((await db.select(db.debtTransactions).getSingle()).deletedAt,
            isNull);
      }
    });

    for (final nextType in debtTypes.where((t) => t != type)) {
      test('debtEdit_${type}To$nextType', () async {
        final old = await createDebt(type);
        await db.updateDebtTransaction(
            newTx: old.copyWith(type: nextType, amount: 1500000));
        final delta = walletSign[nextType]! * 1500000.0;
        await expectBalances(a: 10000000 + delta, contactA: -delta);
        expect(
            (await db.select(db.debtTransactions).getSingle()).type, nextType);
      });
    }

    for (final normalType in [CategoryType.expense, CategoryType.income]) {
      for (final targetWallet in ['a', 'b']) {
        test('debtTo${normalType.name}_${type}_wallet$targetWallet atomic',
            () async {
          final old = await createDebt(type);
          await db.convertDebtToTransactionAtomically(
            debtTransactionId: old.id,
            walletId: targetWallet,
            categoryId: normalType.name,
            type: normalType,
            amount: 1500000,
            date: date.add(const Duration(days: 1)),
            note: 'Converted note',
          );
          final delta =
              normalType == CategoryType.income ? 1500000.0 : -1500000.0;
          await expectBalances(
            a: 10000000 + (targetWallet == 'a' ? delta : 0),
            b: 5000000 + (targetWallet == 'b' ? delta : 0),
          );
          expect(await db.select(db.debtTransactions).get(), isEmpty);
          final normal = await db.select(db.transactions).getSingle();
          expect(normal.id, old.id);
          expect(normal.createdAt, old.createdAt);
          expect(normal.type, normalType);
          expect(normal.categoryId, normalType.name);
          expect(normal.walletId, targetWallet);
          expect(normal.amount, 1500000);
          expect(normal.note, 'Converted note');
          expect(normal.deletedAt, isNull);
        });
      }

      test('${normalType.name}ToDebt_$type atomic', () async {
        await createNormal(normalType);
        final original = await db.select(db.transactions).getSingle();
        await db.convertTransactionToDebtAtomically(
          transactionId: original.id,
          contactId: 'b',
          walletId: 'b',
          debtType: type,
          amount: 1500000,
          date: date,
          note: 'New debt note',
          dueDate: DateTime(2026, 12, 1),
        );
        final delta = walletSign[type]! * 1500000.0;
        await expectBalances(b: 5000000 + delta, contactB: -delta);
        expect(await db.select(db.transactions).get(), isEmpty);
        final debt = await db.select(db.debtTransactions).getSingle();
        expect(debt.id, original.id);
        expect(debt.createdAt, original.createdAt);
        expect(debt.type, type);
        expect(debt.walletId, 'b');
        expect(debt.contactId, 'b');
        expect(debt.amount, 1500000);
        expect(debt.note, 'New debt note');
        expect(debt.dueDate, DateTime(2026, 12, 1));
      });
    }
  }

  for (final change in ['wallet', 'contact', 'both']) {
    test('debtEdit_$change change reverses old and applies new', () async {
      final old = await createDebt('LEND');
      final wallet = change == 'contact' ? 'a' : 'b';
      final contact = change == 'wallet' ? 'a' : 'b';
      await db.updateDebtTransaction(
          newTx: old.copyWith(
              walletId: wallet, contactId: contact, amount: 1500000));
      await expectBalances(
        a: wallet == 'a' ? 8500000 : 10000000,
        b: wallet == 'b' ? 3500000 : 5000000,
        contactA: contact == 'a' ? 1500000 : 0,
        contactB: contact == 'b' ? 1500000 : 0,
      );
    });
  }

  for (final field in ['note', 'dueDate', 'date']) {
    test('debtEdit_${field}Only does not change balances', () async {
      final old = await createDebt('BORROW');
      final changed = switch (field) {
        'note' => old.copyWith(note: const Value('Edited note')),
        'dueDate' => old.copyWith(dueDate: Value(DateTime(2027, 1, 1))),
        _ => old.copyWith(date: DateTime(2027, 1, 2, 10, 45)),
      };
      await db.updateDebtTransaction(newTx: changed);
      await expectBalances(a: 11000000, contactA: -1000000);
      expect(await db.select(db.debtTransactions).getSingle(), changed);
    });
  }

  for (final operation in ['edit', 'debtToNormal', 'normalToDebt']) {
    test('debtMutation_$operation failure rolls back wallet contact and record',
        () async {
      final old = operation == 'normalToDebt' ? null : await createDebt('LEND');
      if (operation == 'normalToDebt') await createNormal(CategoryType.expense);
      final before = await snapshot();
      // Each trigger fires after the DAO has performed dependent balance writes.
      final statement = switch (operation) {
        'edit' => 'UPDATE ON debt_transactions',
        'debtToNormal' => 'DELETE ON debt_transactions',
        _ => 'DELETE ON transactions',
      };
      await db.customStatement('''
        CREATE TRIGGER reject_final_write BEFORE $statement
        BEGIN SELECT RAISE(ABORT, 'injected final write failure'); END
      ''');
      final mutation = switch (operation) {
        'edit' => db.updateDebtTransaction(
            newTx:
                old!.copyWith(walletId: 'b', contactId: 'b', amount: 1500000)),
        'debtToNormal' => db.convertDebtToTransactionAtomically(
            debtTransactionId: 'entry',
            walletId: 'b',
            categoryId: 'income',
            amount: 1500000,
            type: CategoryType.income,
            date: date),
        _ => db.convertTransactionToDebtAtomically(
            transactionId: 'entry',
            contactId: 'b',
            walletId: 'b',
            debtType: 'BORROW',
            amount: 1500000,
            date: date),
      };
      await expectLater(mutation, throwsA(isA<Exception>()));
      expect(await snapshot(), before);
    });
  }
}
