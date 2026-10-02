import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/features/notifications/notification_preferences.dart';
import 'package:pfm_app/features/notifications/notification_service.dart';
import 'package:pfm_app/screens/budget_screen.dart';
import 'package:pfm_app/services/fiscal_day.dart';

class _ObservedDatabase extends AppDatabase {
  _ObservedDatabase() : super.forTesting(NativeDatabase.memory());
  final notificationSpent = <double>[];

  @override
  Future<double> calculateRecurringSpentForCategory({
    required String categoryId,
    required DateTime startDate,
    required DateTime endDate,
    bool isParentCategory = false,
  }) async {
    final spent = await super.calculateRecurringSpentForCategory(
        categoryId: categoryId,
        startDate: startDate,
        endDate: endDate,
        isParentCategory: isParentCategory);
    notificationSpent.add(spent);
    return spent;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ObservedDatabase db;
  late ProviderContainer container;
  late DateTime today;
  const prefs = NotificationPreferences({
    'evening': false,
    'midday': false,
    'digest': false,
    'debts': false,
    'dailyLimit': false,
    'budget80': true,
    'budget100': true,
  });

  setUp(() async {
    db = _ObservedDatabase();
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    for (final entry in [
      ('food', null),
      ('restaurants', 'food'),
      ('cafe', 'restaurants'),
      ('other', null),
    ]) {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: entry.$1,
          name: entry.$1,
          type: CategoryType.expense,
          parentId: Value(entry.$2)));
    }
    await db.into(db.wallets).insert(
        WalletsCompanion.insert(id: 'wallet', name: 'Wallet', type: 'cash'));
    await db.into(db.savingsGoals).insert(SavingsGoalsCompanion.insert(
        id: 'goal', title: 'Goal', targetAmount: 10000000));
    for (final entry in [
      ('active', '#trip', 'ACTIVE'),
      ('archived', '#old', 'ARCHIVED'),
    ]) {
      await db.createProjectBudget(
          id: entry.$1,
          title: entry.$1,
          tag: entry.$2,
          status: entry.$3,
          targetAmount: 5000000,
          // Status, rather than the project's dates, defines active tags.
          startDate: today.subtract(const Duration(days: 90)),
          endDate: today.subtract(const Duration(days: 60)));
    }
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Budget> budget(
      {String category = 'food',
      int cycleDay = 1,
      FiscalDayBoundary boundary = const FiscalDayBoundary()}) async {
    final fiscalToday = boundary.date(DateTime.now());
    final anchor = DateTime(fiscalToday.year,
        fiscalToday.month - (fiscalToday.day < cycleDay ? 1 : 0));
    await db.into(db.budgets).insert(BudgetsCompanion.insert(
        id: 'budget',
        categoryId: category,
        amount: 10000000,
        cycleStartDay: Value(cycleDay),
        periodMonth: anchor));
    return (await db.select(db.budgets).get()).single;
  }

  Future<void> insert(String id, double amount,
      {String category = 'food',
      CategoryType type = CategoryType.expense,
      String? project,
      String? note,
      String? merchant,
      String? goal,
      String? envelope,
      DateTime? date,
      DateTime? deletedAt}) async {
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: id,
        walletId: 'wallet',
        categoryId: category,
        amount: amount,
        type: type,
        date: date ?? today.add(const Duration(hours: 12)),
        projectBudgetId: Value(project),
        note: Value(note),
        merchant: Value(merchant),
        goalId: Value(goal),
        envelopeType: Value(envelope),
        deletedAt: Value(deletedAt)));
  }

  Future<void> reconcile(Budget budget, double expected, int threshold,
      {Map<String, int> cycles = const {'default': 1},
      FiscalDayBoundary boundary = const FiscalDayBoundary()}) async {
    final window = resolveBudgetWindow(budget, cycles);
    final categories = await db.select(db.categories).get();
    final catMap = {for (final c in categories) c.id: c};
    final activeTags = (await db.select(db.projectBudgets).get())
        .where((p) => p.status != 'ARCHIVED')
        .map((p) => p.tag.toLowerCase().trim())
        .toSet();
    final subscription =
        container.listen(expenseTransactionsStreamProvider.future, (_, __) {});
    final rows = await container.read(expenseTransactionsStreamProvider.future);
    subscription.close();
    final parentId = catMap[budget.categoryId]?.parentId;
    final isParent = parentId == null || parentId.isEmpty;
    // Mirror the recurring UI's fold over its actual expense provider. In
    // particular, the UI includes direct children only, not all descendants.
    final uiSpent = rows.where((t) {
      if (t.projectBudgetId != null && t.projectBudgetId!.isNotEmpty) {
        return false;
      }
      if (activeTags.any((tag) =>
          (t.note?.toLowerCase() ?? '').contains(tag) ||
          (t.merchant?.toLowerCase() ?? '').contains(tag))) {
        return false;
      }
      if (t.date.isBefore(boundary.start(window.startDate)) ||
          !t.date.isBefore(boundary.end(window.endDate))) {
        return false;
      }
      return t.categoryId == budget.categoryId ||
          (isParent && catMap[t.categoryId]?.parentId == budget.categoryId);
    }).fold(0.0, (sum, t) => sum + t.amount);
    expect(uiSpent, expected);
    expect(
        await db.calculateRecurringSpentForCategory(
            categoryId: budget.categoryId,
            startDate: boundary.start(window.startDate),
            endDate: boundary
                .end(window.endDate)
                .subtract(const Duration(microseconds: 1)),
            isParentCategory: isParent),
        uiSpent);

    db.notificationSpent.clear();
    final coordinator = NotificationCoordinator(db);
    await coordinator.refresh(prefs, cycles, boundary: boundary);
    expect(db.notificationSpent, [uiSpent]);
    final notices = (await db.select(db.appNotifications).get())
        .where((n) => n.type == 'budget')
        .toList();
    if (threshold == 0) {
      expect(notices, isEmpty);
    } else {
      final notice = notices.single;
      final money =
          NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
      final percent = (uiSpent / budget.amount * 100).toStringAsFixed(0);
      expect(
          notice.body,
          startsWith(
              'Đã dùng $percent%: ${money.format(uiSpent)} / ${money.format(budget.amount)}.'));
      expect(notice.dedupKey, endsWith(':$threshold'));
      await coordinator.refresh(prefs, cycles, boundary: boundary);
      expect((await db.select(db.appNotifications).get()).length, 1);
    }
  }

  for (final scenario in [
    (name: 'below80', recurring: 7000000.0, project: 2000000.0, threshold: 0),
    (name: 'real80', recurring: 8200000.0, project: 5000000.0, threshold: 80),
    (
      name: 'real100',
      recurring: 10100000.0,
      project: 3000000.0,
      threshold: 100
    ),
  ]) {
    test('budgetNotification_matchesRecurringUi_${scenario.name}', () async {
      final b = await budget();
      await insert('normal_needs', scenario.recurring - 2000000,
          envelope: 'needs');
      await insert('child_wants', 2000000,
          category: 'restaurants', envelope: 'wants');
      await insert('event_id', scenario.project / 2, project: 'active');
      await insert('event_note', scenario.project / 4, note: 'Dinner #TRIP');
      await insert('event_merchant', scenario.project / 4, merchant: '#Trip');
      await insert('new_savings', 2000000, goal: 'goal', envelope: 'savings');
      await insert('legacy_goal', 3000000, goal: 'goal');
      await insert('legacy_envelope', 4000000, envelope: 'savings');
      await insert('deleted', 5000000, deletedAt: DateTime.now());
      await insert('income', 6000000, type: CategoryType.income);
      await insert('transfer', 7000000, type: CategoryType.transfer);
      await insert('other_category', 8000000, category: 'other');
      // Source currently supports a two-tier category tree.
      await insert('deeper_descendant', 9000000, category: 'cafe');
      await reconcile(b, scenario.recurring, scenario.threshold);
    });
  }

  test('budgetNotification_archivedTagsMatchUi_butLinkedIdsStayExcluded',
      () async {
    final b = await budget();
    await insert('normal', 7000000);
    await insert('archived_note', 600000, note: '#OLD');
    await insert('archived_merchant', 600000, merchant: '#old');
    await insert('archived_id', 3000000, project: 'archived');
    await insert('expired_active_tag', 4000000, note: '#trip');
    await reconcile(b, 8200000, 80);
  });

  test('budgetNotification_childBudgetCountsOnlyItsOwnCategory', () async {
    final b = await budget(category: 'restaurants');
    await insert('child', 8200000, category: 'restaurants');
    await insert('parent', 5000000);
    await insert('grandchild', 6000000, category: 'cafe');
    await insert('child_event', 7000000,
        category: 'restaurants', note: '#trip');
    await reconcile(b, 8200000, 80);
  });

  test('budgetNotification_preservesCycleAndFiscalWindowEdges', () async {
    const boundary = FiscalDayBoundary(4 * 60);
    const cycles = {'default': 10};
    final b = await budget(cycleDay: 10, boundary: boundary);
    final window = resolveBudgetWindow(b, cycles);
    final start = boundary.start(window.startDate);
    final end = boundary.end(window.endDate);
    await insert('at_start', 4000000, date: start);
    await insert('last_second', 4200000,
        date: end.subtract(const Duration(seconds: 1)));
    await insert('before_start', 6000000,
        date: start.subtract(const Duration(seconds: 1)));
    await insert('at_exclusive_end', 7000000, date: end);
    await reconcile(b, 8200000, 80, cycles: cycles, boundary: boundary);
  });
}
