import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';

void main() {
  late AppDatabase db;
  var depositSequence = 0;
  const tolerance = 0.001;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    depositSequence = 0;
    await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'category',
          name: 'General',
          type: CategoryType.expense,
        ));
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: 'wallet',
          name: 'Wallet',
          type: 'cash',
          balance: const Value(10000000),
        ));
    await db.into(db.savingsGoals).insert(SavingsGoalsCompanion.insert(
          id: 'goal',
          title: 'Goal',
          targetAmount: 5000000,
        ));
  });
  tearDown(() => db.close());

  Future<String> deposit(double amount) async {
    await db.depositToGoal(goalId: 'goal', walletId: 'wallet', amount: amount);
    final tx = await (db.select(db.transactions)
          ..where((t) => t.id.like('tx_sav_dep_%')))
        .getSingle();
    expect(tx.type, CategoryType.expense);
    expect(tx.envelopeType, 'savings');
    // Isolate accounting tests from the existing millisecond-based ID generator.
    final id = 'deposit_${depositSequence++}';
    await (db.update(db.transactions)..where((t) => t.id.equals(tx.id)))
        .write(TransactionsCompanion(id: Value(id)));
    return id;
  }

  Future<String> withdraw(double amount) async {
    await db.withdrawFromGoal(
        goalId: 'goal', walletId: 'wallet', amount: amount);
    final tx = await (db.select(db.transactions)
          ..where((t) => t.type.equals(CategoryType.income.index)))
        .getSingle();
    expect(tx.envelopeType, 'savings');
    return tx.id;
  }

  Future<void> expectBalances(double wallet, double goal) async {
    final actualWallet = (await db.select(db.wallets).getSingle()).balance;
    final actualGoal =
        (await db.select(db.savingsGoals).getSingle()).currentAmount;
    expect(actualWallet, closeTo(wallet, tolerance));
    expect(actualGoal, closeTo(goal, tolerance));
    expect(actualWallet + actualGoal, closeTo(wallet + goal, tolerance));
  }

  Future<double> total() async =>
      (await db.select(db.wallets).getSingle()).balance +
      (await db.select(db.savingsGoals).getSingle()).currentAmount;

  Future<List<Object>> snapshot() async => [
        await db.select(db.wallets).get(),
        await db.select(db.savingsGoals).get(),
        await db.select(db.transactions).get(),
      ];

  Future<void> expectRejected(String id) async {
    final before = await snapshot();
    final beforeTotal = await total();
    await expectLater(db.deleteVaultTransactionAtomically(id),
        throwsA(isA<VaultTransactionDeletionException>()));
    expect(await snapshot(), before);
    expect(await total(), beforeTotal);
  }

  test('deposit deletion reverses both sides at exact balance', () async {
    final id = await deposit(1000000);
    await expectBalances(9000000, 1000000);
    final beforeTotal = await total();
    await db.deleteVaultTransactionAtomically(id);
    await expectBalances(10000000, 0);
    expect(await total(), beforeTotal);
    expect(await db.select(db.transactions).get(), isEmpty);
    await expectRejected(id);
  });

  for (final amount in [800000.0, 1000000.0]) {
    test('reject old deposit after withdrawing $amount', () async {
      final id = await deposit(1000000);
      final withdrawalId = await withdraw(amount);
      await expectRejected(id);
      await expectBalances(9000000 + amount, 1000000 - amount);
      final ids = (await db.select(db.transactions).get()).map((t) => t.id);
      expect(ids, unorderedEquals([id, withdrawalId]));
    });
  }

  test('multiple deposits preserve other records and total', () async {
    final first = await deposit(1000000);
    final second = await deposit(2000000);
    final beforeTotal = await total();
    await db.deleteVaultTransactionAtomically(first);
    await expectBalances(8000000, 2000000);
    expect((await db.select(db.transactions).getSingle()).id, second);
    expect(await total(), beforeTotal);
  });

  test('tiny negative floating point remainder normalizes to zero', () async {
    final id = await deposit(1234.56);
    await (db.update(db.savingsGoals)..where((g) => g.id.equals('goal'))).write(
        const SavingsGoalsCompanion(currentAmount: Value(1234.56 - 1e-9)));
    final beforeTotal = await total();
    await db.deleteVaultTransactionAtomically(id);
    await expectBalances(10000000, 0);
    expect(await total(), closeTo(beforeTotal, tolerance));
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  test('real deficit is not absorbed by tolerance', () async {
    final id = await deposit(1000);
    await withdraw(0.01);
    await expectRejected(id);
  });

  for (final withdrawal in [false, true]) {
    for (final missing in ['goal', 'wallet']) {
      test('${withdrawal ? 'withdrawal' : 'deposit'} missing $missing rejects',
          () async {
        final depositId = await deposit(1000000);
        final id = withdrawal ? await withdraw(800000) : depositId;
        await db.customStatement('PRAGMA foreign_keys = OFF');
        await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
          TransactionsCompanion(
            goalId: missing == 'goal'
                ? const Value('missing')
                : const Value.absent(),
            walletId: missing == 'wallet'
                ? const Value('missing')
                : const Value.absent(),
          ),
        );
        await db.customStatement('PRAGMA foreign_keys = ON');
        await expectRejected(id);
      });
    }
  }

  for (final type in [CategoryType.transfer, CategoryType.debt]) {
    test('unsupported $type rejects without mutation', () async {
      final id = await deposit(1000000);
      await (db.update(db.transactions)..where((t) => t.id.equals(id)))
          .write(TransactionsCompanion(type: Value(type)));
      await expectRejected(id);
    });
  }

  test('already soft-deleted record cannot reverse twice', () async {
    final id = await deposit(1000000);
    await (db.update(db.transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(deletedAt: Value(DateTime.now())));
    await expectRejected(id);
  });

  test('withdrawal delete keeps existing negative-wallet behavior', () async {
    await deposit(1000000);
    final id = await withdraw(800000);
    await (db.update(db.wallets)..where((w) => w.id.equals('wallet')))
        .write(const WalletsCompanion(balance: Value(0)));
    final beforeTotal = await total();
    await db.deleteVaultTransactionAtomically(id);
    await expectBalances(-800000, 1000000);
    expect(await total(), beforeTotal);
    expect((await db.select(db.transactions).get()).any((t) => t.id == id),
        isFalse);
  });

  for (final target in ['goal', 'wallet', 'delete']) {
    for (final failure in ['IGNORE', "ABORT, 'injected failure'"]) {
      test('rollback on $target $failure', () async {
        final id = await deposit(1000000);
        final before = await snapshot();
        final beforeTotal = await total();
        final event = switch (target) {
          'goal' => 'UPDATE OF current_amount ON savings_goals',
          'wallet' => 'UPDATE OF balance ON wallets',
          _ => 'DELETE ON transactions',
        };
        await db.customStatement('CREATE TRIGGER fail_write BEFORE $event '
            'BEGIN SELECT RAISE($failure); END');
        await expectLater(db.deleteVaultTransactionAtomically(id),
            throwsA(anyOf(isA<StateError>(), isA<Exception>())));
        expect(await snapshot(), before);
        expect(await total(), beforeTotal);
      });
    }
  }
}
