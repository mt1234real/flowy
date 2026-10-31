import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/services/budget_spending.dart';
import 'package:pfm_app/services/fiscal_day.dart';
import 'package:pfm_app/services/backup_database_normalizer.dart';
import 'package:pfm_app/services/backup_capsule.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  late AppDatabase db;
  test('exclusive period pin sequence survives real SQLite restart', () async {
    final dir = await Directory.systemTemp.createTemp('flowy-pin-');
    final file = File('${dir.path}/pins.sqlite');
    var disk = AppDatabase.forTesting(NativeDatabase(file));
    try {
      for (final id in ['needs', 'wants', 'obligations']) {
        await disk.into(disk.categories).insert(CategoriesCompanion.insert(
            id: id, name: id, type: CategoryType.expense));
        await disk.into(disk.budgets).insert(BudgetsCompanion.insert(
            id: id,
            categoryId: id,
            amount: 600000,
            periodMonth: DateTime(2026, 10)));
      }
      Future<void> pin(String id, bool value) async {
        final budget = await (disk.select(disk.budgets)
              ..where((b) => b.id.equals(id)))
            .getSingle();
        await disk.transaction(() => saveBudgetRhythm(disk, budget,
            rhythm: SpendingRhythm.period,
            weekStart: 1,
            carryRule: 'none',
            pinned: value));
        final rows = await disk.select(disk.budgetRhythms).get();
        expect(rows.where((c) => c.pinned).map((c) => c.budgetId).toList(),
            value ? [id] : isEmpty);
      }

      await pin('obligations', true);
      await pin('obligations', false);
      await pin('needs', true);
      await pin('wants', true);
      await disk.close();
      disk = AppDatabase.forTesting(NativeDatabase(file));
      final rows = await disk.select(disk.budgetRhythms).get();
      expect(rows.where((c) => c.pinned).map((c) => c.budgetId).toList(),
          ['wants']);
      Future<BudgetSpendingOverview> diskOverview() async =>
          deriveBudgetSpending(
              await readBudgetSpendingData(disk),
              DateTime(2026, 10, 28),
              const FiscalDayBoundary(),
              {'default': 1});
      expect(
          (await diskOverview())
              .explicitlyPinned(SpendingRhythm.period)
              ?.budget
              .id,
          'wants');
      await pin('wants', false);
      await disk.close();
      disk = AppDatabase.forTesting(NativeDatabase(file));
      expect((await diskOverview()).explicitlyPinned(SpendingRhythm.period),
          isNull);
      expect((await diskOverview()).pinned(SpendingRhythm.period), isNotNull);
    } finally {
      await disk.close();
      await dir.delete(recursive: true);
    }
  });
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.wallets).insert(WalletsCompanion.insert(
        id: 'w', name: 'Cash', type: 'cash', balance: const Value(2000000)));
    for (final id in ['food', 'fun']) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: id, name: id, type: CategoryType.expense));
    }
  });
  tearDown(() async => db.close());
  Future<Budget> budget(String id, String category, double amount,
      {int month = 10,
      int day = 1,
      String rhythm = 'period',
      String carry = 'none',
      int? uses}) async {
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
        id: id,
        categoryId: category,
        amount: amount,
        periodMonth: DateTime(2026, month),
        cycleStartDay: Value(day)));
    final b = await (db.select(db.budgets)..where((t) => t.id.equals(id)))
        .getSingle();
    await saveBudgetRhythm(db, b,
        rhythm:
            rhythm == 'weekly' ? SpendingRhythm.weekly : SpendingRhythm.period,
        weekStart: 1,
        carryRule: carry,
        remainingUses: uses);
    return b;
  }

  Future<void> spend(String id, String cat, double amount, DateTime date) =>
      db.insertTransactionWithBalanceUpdate(TransactionsCompanion.insert(
          id: id,
          walletId: 'w',
          categoryId: cat,
          amount: amount,
          type: CategoryType.expense,
          date: date));
  Future<BudgetSpendingOverview> overview(DateTime day,
          {FiscalDayBoundary boundary = const FiscalDayBoundary()}) async =>
      deriveBudgetSpending(
          await readBudgetSpendingData(db), day, boundary, {'default': 1});
  test('period 240k less 120k never becomes daily ceiling', () async {
    await budget('b', 'fun', 240000);
    await spend('t', 'fun', 120000, DateTime(2026, 10, 28));
    final b = (await overview(DateTime(2026, 10, 28))).items.single;
    expect(b.remaining, 120000);
    expect(b.dailySuggestion, isNull);
    expect(b.perUseSuggestion, isNull);
    expect(b.remaining >= 0, true);
  });
  for (final amount in [350000.0, 700000.0, 770000.0]) {
    test('weekly remaining/zero/over state $amount and real progress',
        () async {
      await budget('b', 'food', 700000, rhythm: 'weekly');
      await spend('t', 'food', amount, DateTime(2026, 10, 28));
      final b = (await overview(DateTime(2026, 10, 28))).items.single;
      expect(b.start, DateTime(2026, 10, 26));
      expect(b.end,
          DateTime(2026, 11, 1)); // last week clipped to persisted period
      expect(b.remaining, 700000 - amount);
      expect(b.daysLeft, 4);
      expect(b.dailySuggestion, amount < 700000 ? (700000 - amount) / 4 : null);
      expect(b.ratio, amount / 700000);
    });
  }
  test('fiscal boundary assigns early morning to preceding week', () async {
    await budget('b', 'food', 700000, rhythm: 'weekly');
    await spend('t', 'food', 50000, DateTime(2026, 10, 26, 3, 59));
    expect(
        (await overview(DateTime(2026, 10, 26),
                boundary: const FiscalDayBoundary(240)))
            .items
            .single
            .spent,
        0);
    expect(
        (await overview(DateTime(2026, 10, 25),
                boundary: const FiscalDayBoundary(240)))
            .items
            .single
            .spent,
        50000);
  });
  for (final rule in ['none', 'signed']) {
    test('weekly $rule carry recomputes once and retains deficit evidence',
        () async {
      await budget('b', 'food', 100, rhythm: 'weekly', carry: rule);
      await spend('early', 'food', 150, DateTime(2026, 10, 2));
      final b = (await overview(DateTime(2026, 10, 5))).items.single;
      expect(b.previousRemaining, -50);
      expect(b.carry, rule == 'signed' ? -50 : 0);
      expect(b.remaining, rule == 'signed' ? 50 : 100);
      expect((await overview(DateTime(2026, 10, 5))).items.single.remaining,
          b.remaining);
    });
  }
  test('period signed carry follows only contiguous compatible periods',
      () async {
    await budget('sep', 'fun', 240, month: 9);
    await spend('s', 'fun', 300, DateTime(2026, 9, 20));
    await budget('oct', 'fun', 240, carry: 'signed', uses: 3);
    final b = (await overview(DateTime(2026, 10, 28))).items.single;
    expect(b.carry, -60);
    expect(b.remaining, 180);
    expect(b.perUseSuggestion, 60);
    await expectLater(
        saveBudgetRhythm(db, b.budget,
            rhythm: SpendingRhythm.period,
            weekStart: 1,
            carryRule: 'signed',
            remainingUses: 0),
        throwsArgumentError);
  });
  test(
      'nearest budget owns category, excludes vault/project/adjustment/transfer',
      () async {
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'child',
        name: 'Child',
        type: CategoryType.expense,
        parentId: const Value('food')));
    await budget('parent', 'food', 1000);
    await budget('child', 'child', 500);
    await spend('t', 'child', 100, DateTime(2026, 10, 28));
    await db.adjustWalletBalance(
        walletId: 'w', realBalance: 1800000, reason: 'count');
    final v = await overview(DateTime(2026, 10, 28));
    expect(v.items.singleWhere((b) => b.budget.id == 'parent').spent, 0);
    expect(v.items.singleWhere((b) => b.budget.id == 'child').spent, 100);
  });
  test(
      'legacy budget has explicit period evidence, no inferred weekly and stable pins',
      () async {
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
        id: 'legacy',
        categoryId: 'food',
        amount: 1000,
        periodMonth: DateTime(2026, 10),
        cycleStartDay: const Value(1)));
    final b = await budget('other', 'fun', 2000);
    var v = await overview(DateTime(2026, 10, 28));
    expect(v.items.every((b) => b.rhythm == SpendingRhythm.period), true);
    final original = v.pinned(SpendingRhythm.period)!.budget.id;
    expect(v.explicitlyPinned(SpendingRhythm.period), isNull);
    await spend('t', 'fun', 1500, DateTime(2026, 10, 28));
    v = await overview(DateTime(2026, 10, 28));
    expect(v.pinned(SpendingRhythm.period)!.budget.id, original);
    await saveBudgetRhythm(db, b,
        rhythm: SpendingRhythm.period,
        weekStart: 1,
        carryRule: 'none',
        pinned: true);
    expect(
        (await overview(DateTime(2026, 10, 28)))
            .pinned(SpendingRhythm.period)!
            .budget
            .id,
        'other');
    expect(
        (await overview(DateTime(2026, 10, 28)))
            .explicitlyPinned(SpendingRhythm.period)
            ?.budget
            .id,
        'other');
    await saveBudgetRhythm(db, b,
        rhythm: SpendingRhythm.period,
        weekStart: 1,
        carryRule: 'none',
        pinned: false);
    v = await overview(DateTime(2026, 10, 28));
    expect(v.explicitlyPinned(SpendingRhythm.period), isNull);
    expect(v.pinned(SpendingRhythm.period)?.budget.id, original);
  });
  test(
      'configured Sunday week and final fiscal day have valid inclusive day counts',
      () async {
    final b = await budget('sunday', 'food', 700, rhythm: 'weekly');
    await saveBudgetRhythm(db, b,
        rhythm: SpendingRhythm.weekly, weekStart: 7, carryRule: 'none');
    final v = (await overview(DateTime(2026, 10, 31))).items.single;
    expect(v.start, DateTime(2026, 10, 25));
    expect(v.daysLeft, 1);
    expect(v.dailySuggestion, 700);
    expect((await overview(DateTime(2026, 11, 1))).items, isEmpty);
  });
  test(
      'signed weekly positive and zero carry stay configured, never compound on reread',
      () async {
    await budget('food', 'food', 100, rhythm: 'weekly', carry: 'signed');
    await spend('t', 'food', 100, DateTime(2026, 10, 2));
    var v = (await overview(DateTime(2026, 10, 5))).items.single;
    expect(v.carry, 0);
    expect(v.carryEnabled, true);
    await db.softDeleteTransaction('t');
    v = (await overview(DateTime(2026, 10, 5))).items.single;
    expect(v.carry, 100);
    expect(v.remaining, 200);
    expect((await overview(DateTime(2026, 10, 5))).items.single.remaining, 200);
    await db.restoreTransaction('t');
    expect((await overview(DateTime(2026, 10, 5))).items.single.remaining, 100);
  });
  test(
      'monthly cutoff clamps to February and crosses year without changing dates',
      () async {
    final b = await budget('jan', 'fun', 240, month: 1, day: 31);
    final data = await readBudgetSpendingData(db);
    final v = deriveBudgetSpending(data, DateTime(2026, 2, 27),
        const FiscalDayBoundary(), {'default': 31}).items.single;
    expect(v.start, DateTime(2026, 1, 31));
    expect(v.end, DateTime(2026, 2, 28));
    expect(v.dailySuggestion, isNull);
    expect(b.cycleStartDay, 31);
    await budget('dec', 'fun', 240, month: 12, day: 31);
    final nextYear = deriveBudgetSpending(
        await readBudgetSpendingData(db),
        DateTime(2027, 1, 15),
        const FiscalDayBoundary(),
        {'default': 31}).items.single;
    expect(nextYear.start, DateTime(2026, 12, 31));
    expect(nextYear.end, DateTime(2027, 1, 31));
  });
  test('bad budget configuration does not blank valid independent budget',
      () async {
    await budget('good', 'food', 1000);
    await budget('bad', 'fun', 1000);
    await (db.update(db.budgetRhythms)..where((r) => r.budgetId.equals('bad')))
        .write(const BudgetRhythmsCompanion(remainingUses: Value(0)));
    final v = await overview(DateTime(2026, 10, 28));
    expect(v.items.singleWhere((b) => b.budget.id == 'good').error, isNull);
    expect(v.items.singleWhere((b) => b.budget.id == 'bad').error, isNotNull);
  });
  test(
      'v11 real-file upgrade snapshots and preserves all money/history; staged backup normalizes',
      () async {
    final dir =
        await Directory.systemTemp.createTemp('flowy-rhythm-migration-');
    final file = File('${dir.path}/fixture.sqlite');
    var disk = AppDatabase.forTesting(NativeDatabase(file));
    try {
      await disk.into(disk.wallets).insert(WalletsCompanion.insert(
          id: 'w', name: 'Cash', type: 'cash', balance: const Value(1800000)));
      await disk.into(disk.categories).insert(CategoriesCompanion.insert(
          id: 'c', name: 'Food', type: CategoryType.expense));
      await disk.into(disk.budgets).insert(BudgetsCompanion.insert(
          id: 'b',
          categoryId: 'c',
          amount: 240000,
          periodMonth: DateTime(2026, 10)));
      await disk.close();
      final raw = sql.sqlite3.open(file.path);
      raw.execute('DROP TABLE budget_rhythms');
      raw.execute('PRAGMA user_version=11');
      raw.close();
      final before = await file.readAsBytes();
      final prepared = await prepareBackupForInspection(file.path);
      expect(await file.readAsBytes(), before);
      validateBackupDatabase(prepared, 12);
      disk = AppDatabase.forTesting(NativeDatabase(file));
      expect((await disk.select(disk.wallets).getSingle()).balance, 1800000);
      expect((await disk.select(disk.budgets).getSingle()).amount, 240000);
      expect(await disk.select(disk.budgetRhythms).get(), isEmpty);
      final snapshots = dir
          .listSync()
          .where((f) => f.path.contains('pre-budget-rhythm'))
          .toList();
      expect(snapshots, hasLength(1));
      final backup =
          sql.sqlite3.open(snapshots.single.path, mode: sql.OpenMode.readOnly);
      expect(backup.select('PRAGMA user_version').single.values.single, 11);
      backup.close();
      final b = await disk.select(disk.budgets).getSingle();
      await saveBudgetRhythm(disk, b,
          rhythm: SpendingRhythm.period,
          weekStart: 1,
          carryRule: 'signed',
          remainingUses: 2,
          pinned: true);
      final fingerprint = ledgerFingerprint(file.path);
      await disk.close();
      final copy = await prepareBackupForInspection(file.path);
      expect(ledgerFingerprint(copy), fingerprint);
      disk = AppDatabase.forTesting(NativeDatabase(File(copy)));
      final cfg = await disk.select(disk.budgetRhythms).getSingle();
      expect(cfg.pinned, true);
      expect(cfg.remainingUses, 2);
    } finally {
      await disk.close();
      await dir.delete(recursive: true);
    }
  });
}
