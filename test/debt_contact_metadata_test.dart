import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/data/daos/debt_dao.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: 'wallet',
          name: 'Tiền mặt',
          type: 'cash',
          balance: const Value(10000000),
        ));
    await db.upsertDebtContact(DebtContactsCompanion(
      id: const Value('an'),
      name: const Value('An'),
      createdAt: Value(DateTime(2026, 1, 1)),
    ));
  });
  tearDown(() => db.close());

  Future<DebtContact> contact() => db.select(db.debtContacts).getSingle();
  Future<double> walletBalance() async =>
      (await db.select(db.wallets).getSingle()).balance;
  Future<void> lend() => db.createDebtTransaction(
        id: 'loan',
        contactId: 'an',
        walletId: 'wallet',
        type: 'LEND',
        amount: 1000000,
        date: DateTime(2026, 10, 1),
      );

  test('New contact uses the zero accounting balance default', () async {
    expect((await contact()).netBalance, 0);
  });

  test('Metadata edit saves name/phone/avatar without changing accounting',
      () async {
    await lend();
    final before = await contact();
    await db.updateDebtContactMetadata(
      id: before.id,
      name: 'Anh An',
      phone: '0901234567',
      avatarUrl: 'INITIALS|#10B981|A',
    );
    final after = await contact();
    expect(after.name, 'Anh An');
    expect(after.phone, '0901234567');
    expect(after.avatarUrl, 'INITIALS|#10B981|A');
    expect(after.netBalance, 1000000);
    expect(after.createdAt, before.createdAt);
    expect(await walletBalance(), 9000000);

    await db.updateDebtContactMetadata(id: before.id, name: 'An');
    expect((await contact()).phone, isNull);
    expect((await contact()).avatarUrl, isNull);
    expect((await contact()).netBalance, 1000000);
  });

  test('Stale metadata edit preserves the latest persisted debt balance',
      () async {
    await lend();
    final stale = await contact();
    final loan = await db.select(db.debtTransactions).getSingle();
    await db.updateDebtTransaction(newTx: loan.copyWith(amount: 1500000));
    expect(stale.netBalance, 1000000);
    expect((await contact()).netBalance, 1500000);

    await db.updateDebtContactMetadata(
      id: stale.id,
      name: 'Anh ${stale.name}',
      phone: '0901234567',
      avatarUrl: 'ICON|#10B981|person',
    );
    final after = await contact();
    expect(after.name, 'Anh An');
    expect(after.phone, '0901234567');
    expect(after.avatarUrl, 'ICON|#10B981|person');
    expect(after.netBalance, 1500000);
    expect(after.createdAt, stale.createdAt);
    expect(await walletBalance(), 8500000);
    expect((await db.select(db.debtTransactions).getSingle()).amount, 1500000);
  });

  test('Accounting create/delete/restore still works after metadata edit',
      () async {
    await db.updateDebtContactMetadata(id: 'an', name: 'Anh An');
    await lend();
    expect((await contact()).netBalance, 1000000);
    expect(await walletBalance(), 9000000);
    await db.softDeleteDebtTransaction('loan');
    await db.softDeleteDebtTransaction('loan');
    expect((await contact()).netBalance, 0);
    expect(await walletBalance(), 10000000);
    await db.restoreDebtTransaction('loan');
    await db.restoreDebtTransaction('loan');
    expect((await contact()).netBalance, 1000000);
    expect((await contact()).name, 'Anh An');
    expect(await walletBalance(), 9000000);
  });

  test('Absent accounting fields survive Drift upsert and repository upsert',
      () async {
    await lend();
    final stale = await contact();
    final loan = await db.select(db.debtTransactions).getSingle();
    await db.updateDebtTransaction(newTx: loan.copyWith(amount: 1500000));
    final metadata = DebtContactsCompanion(
      id: Value(stale.id),
      name: const Value('Anh An'),
    );
    expect(metadata.toColumns(true), isNot(contains('net_balance')));
    await db.upsertDebtContact(metadata);
    expect((await contact()).netBalance, 1500000);
    expect((await contact()).createdAt, stale.createdAt);
    await DebtRepository(db).upsertContact(
      id: stale.id,
      name: 'An mới',
      phone: '0901234567',
      avatarUrl: 'avatar',
    );
    expect((await contact()).name, 'An mới');
    expect((await contact()).netBalance, 1500000);
    expect(await walletBalance(), 8500000);
  });

  test('Editing a missing contact fails without stale reinsertion', () async {
    final stale = await contact();
    await (db.delete(db.debtContacts)..where((c) => c.id.equals(stale.id)))
        .go();
    await expectLater(
      db.updateDebtContactMetadata(id: stale.id, name: 'Anh ${stale.name}'),
      throwsStateError,
    );
    expect(await db.select(db.debtContacts).get(), isEmpty);
    expect(await walletBalance(), 10000000);
  });
}
