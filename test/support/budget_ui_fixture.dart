// Synthetic, in-memory UI fixture. Never opens the app's persistent database.
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/services/budget_spending.dart';
import 'package:pfm_app/services/budget_spending_provider.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/dashboard_hero_card.dart';

Future<AppDatabase> budgetUiDatabase(
    {bool weekly = true, bool period = true}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.into(db.wallets).insert(WalletsCompanion.insert(
      id: 'qa-wallet',
      name: 'Ví fixture',
      type: 'cash',
      balance: const Value(2000000)));
  for (final entry in [
    ('qa-week', 'Ăn uống', 700000.0, weekly),
    ('qa-period', 'Wants', 240000.0, period)
  ]) {
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: entry.$1,
        name: entry.$2,
        type: CategoryType.expense,
        icon: Value(entry.$1 == 'qa-week' ? 'restaurant' : 'movie'),
        color: Value(entry.$1 == 'qa-week' ? '#10B981' : '#F43F5E')));
    if (!entry.$4) continue;
    final budget = await db.into(db.budgets).insertReturning(
        BudgetsCompanion.insert(
            id: entry.$1,
            categoryId: entry.$1,
            amount: entry.$3,
            periodMonth: DateTime(2026, 10),
            cycleStartDay: const Value(1)));
    await saveBudgetRhythm(db, budget,
        rhythm: entry.$1 == 'qa-week'
            ? SpendingRhythm.weekly
            : SpendingRhythm.period,
        weekStart: 1,
        carryRule: 'none',
        pinned: true);
  }
  if (period) {
    await db.insertTransactionWithBalanceUpdate(TransactionsCompanion.insert(
        id: 'qa-spend',
        walletId: 'qa-wallet',
        categoryId: 'qa-period',
        type: CategoryType.expense,
        amount: 120000,
        date: DateTime(2026, 10, 28, 12)));
  }
  return db;
}

// Additional records are synthetic and only inserted by the explicit QA entrypoint/tests.
Future<void> seedFrostedLedgerData(AppDatabase db) async {
  for (final entry in [
    ('qa-travel', 'Déplacements · Déplacements quotidiens'),
    ('qa-home', 'Nhà cửa & sinh hoạt')
  ]) {
    await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: entry.$1, name: entry.$2, type: CategoryType.expense));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
        id: entry.$1,
        categoryId: entry.$1,
        amount: 900000,
        periodMonth: DateTime(2026, 10)));
  }
  for (var i = 1; i <= 2; i++) {
    await db.into(db.debtContacts).insert(DebtContactsCompanion.insert(
        id: 'qa-contact-$i', name: 'Đối tác fixture $i'));
    await db.createDebtTransaction(
        id: 'qa-debt-$i',
        contactId: 'qa-contact-$i',
        walletId: 'qa-wallet',
        type: 'BORROW',
        amount: 250000 * i.toDouble(),
        date: DateTime(2026, 10, 25),
        dueDate: DateTime(2026, 11, 6 + i));
  }
  await db.into(db.savingsGoals).insert(SavingsGoalsCompanion.insert(
      id: 'qa-goal',
      title: 'Quỹ dự phòng',
      targetAmount: 2000000,
      currentAmount: const Value(600000)));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  final db = await budgetUiDatabase(weekly: false);
  await seedFrostedLedgerData(db);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [
    databaseProvider.overrideWithValue(db),
    sharedPreferencesProvider.overrideWithValue(prefs),
    budgetSpendingDateProvider.overrideWithValue(DateTime(2026, 10, 28))
  ], child: const BudgetUiFixtureApp()));
}

class BudgetUiFixtureApp extends ConsumerStatefulWidget {
  const BudgetUiFixtureApp({super.key});
  @override
  ConsumerState<BudgetUiFixtureApp> createState() => _BudgetUiFixtureAppState();
}

class _BudgetUiFixtureAppState extends ConsumerState<BudgetUiFixtureApp> {
  bool _visible = false, _dark = false, _serif = false;
  double _scale = 1;
  AppAccentPreset _accent = AppAccentPreset.sun;
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.buildTheme(
            isDark: _dark,
            accent: _accent,
            fontName: _serif ? 'Lora' : 'Plus Jakarta Sans',
            currencyFont: 'Be Vietnam Pro'),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(_scale)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                  appBar: AppBar(
                      title: const Text('Flowy · UI fixture',
                          style: TextStyle(fontSize: 16))),
                  body: SafeArea(
                      child: SingleChildScrollView(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(spacing: 8, children: [
                              TextButton(
                                  onPressed: () =>
                                      setState(() => _visible = !_visible),
                                  child: const Text('Privacy')),
                              TextButton(
                                  onPressed: () =>
                                      setState(() => _dark = !_dark),
                                  child: const Text('Light / Dark')),
                              TextButton(
                                  onPressed: () => setState(() => _accent =
                                      AppAccentPreset.values[
                                          (_accent.index + 1) %
                                              AppAccentPreset.values.length]),
                                  child: const Text('Accent')),
                              TextButton(
                                  onPressed: () =>
                                      setState(() => _serif = !_serif),
                                  child: const Text('Font')),
                              TextButton(
                                  onPressed: () => setState(
                                      () => _scale = _scale == 1 ? 2 : 1),
                                  child: const Text('Text scale')),
                              TextButton(
                                  onPressed: () async {
                                    final db = ref.read(databaseProvider);
                                    await db.transaction(() async {
                                      await db.delete(db.budgetRhythms).go();
                                      await db.delete(db.budgets).go();
                                    });
                                  },
                                  child: const Text('No budgets')),
                              TextButton(
                                  onPressed: () async {
                                    final db = ref.read(databaseProvider);
                                    if (await (db.select(db.budgets)
                                              ..where((b) =>
                                                  b.id.equals('qa-week')))
                                            .getSingleOrNull() !=
                                        null) {
                                      return;
                                    }
                                    final b = await db
                                        .into(db.budgets)
                                        .insertReturning(
                                            BudgetsCompanion.insert(
                                                id: 'qa-week',
                                                categoryId: 'qa-week',
                                                amount: 700000,
                                                periodMonth: DateTime(2026, 10),
                                                cycleStartDay: const Value(1)));
                                    await saveBudgetRhythm(db, b,
                                        rhythm: SpendingRhythm.weekly,
                                        weekStart: 1,
                                        carryRule: 'none',
                                        pinned: true);
                                  },
                                  child: const Text('Two budgets')),
                            ])),
                        const Padding(
                            padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
                            child: Text('DASHBOARD · DỮ LIỆU TEST',
                                style: TextStyle(fontSize: 11))),
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: DashboardHeroCard(isVisible: _visible)),
                        const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                                'Fixture chỉ dùng database trong bộ nhớ. Các widget Hero, sheet, pin/edit và Advisor là source production hiện tại.',
                                style: TextStyle(fontSize: 12))),
                      ]))),
                )),
      );
}
