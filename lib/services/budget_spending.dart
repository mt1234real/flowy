import 'dart:math' as math;
import 'package:drift/drift.dart';
import '../data/database.dart';
import 'budget_windows.dart';
import 'fiscal_day.dart';

enum SpendingRhythm { weekly, period }

class BudgetSpendingData {
  const BudgetSpendingData(this.budgets, this.rhythms, this.categories,
      this.expenses, this.projects, this.goals, this.debts, this.wallets);
  final List<Budget> budgets;
  final List<BudgetRhythm> rhythms;
  final List<Category> categories;
  final List<Transaction> expenses;
  final List<ProjectBudget> projects;
  final List<SavingsGoal> goals;
  final List<DebtTransaction> debts;
  final List<Wallet> wallets;
}

Future<BudgetSpendingData> readBudgetSpendingData(AppDatabase db) =>
    db.transaction(() async => BudgetSpendingData(
        await db.select(db.budgets).get(),
        await db.select(db.budgetRhythms).get(),
        await db.select(db.categories).get(),
        await (db.select(db.transactions)
              ..where((t) =>
                  t.deletedAt.isNull() &
                  t.type.equals(CategoryType.expense.index)))
            .get(),
        await db.select(db.projectBudgets).get(),
        await db.select(db.savingsGoals).get(),
        await (db.select(db.debtTransactions)
              ..where((t) => t.deletedAt.isNull()))
            .get(),
        await db.select(db.wallets).get()));

Stream<BudgetSpendingData> watchBudgetSpendingData(AppDatabase db) => db
    // Drift caches streams by SQL + variables, not readsFrom. Keep this
    // invalidation signal distinct from Dashboard's SELECT 1 watcher.
    .customSelect('SELECT 1 AS budget_spending_revision', readsFrom: {
      db.budgets,
      db.budgetRhythms,
      db.categories,
      db.transactions,
      db.projectBudgets,
      db.savingsGoals,
      db.debtTransactions,
      db.wallets
    })
    .watch()
    .asyncMap((_) => readBudgetSpendingData(db));

class BudgetSpending {
  const BudgetSpending(
      {required this.budget,
      required this.name,
      required this.rhythm,
      required this.start,
      required this.end,
      required this.spent,
      required this.carry,
      required this.previousRemaining,
      required this.daysLeft,
      required this.pinned,
      required this.remainingUses,
      this.carryEnabled = false,
      this.error});
  final Budget budget;
  final String name;
  final SpendingRhythm rhythm;
  final DateTime start, end; // fiscal labels; end exclusive
  final double spent, carry;
  final double? previousRemaining;
  final int daysLeft;
  final bool pinned;
  final bool carryEnabled;
  final int? remainingUses;
  final String? error;
  double get available => budget.amount + carry;
  double get remaining => available - spent;
  double? get dailySuggestion =>
      rhythm == SpendingRhythm.weekly && remaining > 0 && daysLeft > 0
          ? remaining / daysLeft
          : null;
  double? get perUseSuggestion => rhythm == SpendingRhythm.period &&
          remaining > 0 &&
          (remainingUses ?? 0) > 0
      ? remaining / remainingUses!
      : null;
  double get ratio =>
      available > 0 ? spent / available : (spent > 0 ? double.infinity : 0);
}

class BudgetSpendingOverview {
  const BudgetSpendingOverview(this.items, this.source,
      {this.ownerByTransactionId = const {}});
  final List<BudgetSpending> items;
  final BudgetSpendingData source;
  final Map<String, String> ownerByTransactionId;

  /// User-selected representative; absence must remain absence on Dashboard.
  BudgetSpending? explicitlyPinned(SpendingRhythm r) {
    final selected = items.where((b) => b.rhythm == r && b.pinned).toList()
      ..sort((a, b) => a.budget.id.compareTo(b.budget.id));
    return selected.firstOrNull;
  }

  BudgetSpending? pinned(SpendingRhythm r) {
    final list = items.where((b) => b.rhythm == r).toList()
      ..sort((a, b) => a.budget.id.compareTo(b.budget.id));
    // Persisted explicit selection wins; fallback is stable ID, never spend order.
    return list.where((b) => b.pinned).firstOrNull ?? list.firstOrNull;
  }
}

BudgetSpendingOverview deriveBudgetSpending(BudgetSpendingData data,
    DateTime today, FiscalDayBoundary boundary, Map<String, int> cycles) {
  final byId = {for (final c in data.categories) c.id: c};
  final configs = {for (final c in data.rhythms) c.budgetId: c};
  final windows = {
    for (final b in data.budgets) b.id: resolveBudgetWindow(b, cycles)
  };
  final tags = data.projects
      .where((p) => p.status != 'ARCHIVED')
      .map((p) => p.tag.toLowerCase().trim())
      .where((t) => t.isNotEmpty)
      .toSet();
  bool eligible(Transaction t) =>
      t.type == CategoryType.expense &&
      t.deletedAt == null &&
      t.goalId == null &&
      t.envelopeType != 'savings' &&
      (t.projectBudgetId == null || t.projectBudgetId!.isEmpty) &&
      !tags.any((tag) =>
          (t.note ?? '').toLowerCase().contains(tag) ||
          (t.merchant ?? '').toLowerCase().contains(tag));
  bool active(Budget b, DateTime day) {
    final w = windows[b.id]!;
    return !day.isBefore(w.startDate) &&
        day.isBefore(
            DateTime(w.endDate.year, w.endDate.month, w.endDate.day + 1));
  }

  // Closest budgeted category owns an expense. A child's own budget is never
  // also spent against its parent's independent allowance.
  final candidates = <String, List<Budget>>{};
  for (final b in data.budgets.where((b) => !b.id.startsWith('event_'))) {
    candidates.putIfAbsent(b.categoryId, () => []).add(b);
  }
  final owned = <String, List<Transaction>>{};
  for (final t in data.expenses.where(eligible)) {
    final day = boundary.date(t.date);
    String? id = t.categoryId;
    final visited = <String>{};
    while (id != null && visited.add(id)) {
      final owners =
          (candidates[id] ?? <Budget>[]).where((b) => active(b, day)).toList();
      if (owners.isNotEmpty) {
        if (owners.length == 1) {
          owned.putIfAbsent(owners.single.id, () => []).add(t);
        }
        break;
      }
      final parent = byId[byId[id]?.parentId];
      id = parent != null &&
              (parent.parentId == null || parent.parentId!.isEmpty)
          ? parent.id
          : null;
    }
  }
  double spent(Budget b, DateTime start, DateTime end) =>
      (owned[b.id] ?? <Transaction>[])
          .where((t) =>
              !t.date.isBefore(boundary.start(start)) &&
              t.date.isBefore(boundary.start(end)))
          .fold(0.0, (sum, t) => sum + t.amount);
  DateTime week(DateTime d, int day) =>
      DateTime(d.year, d.month, d.day - (d.weekday - day + 7) % 7);
  final result = <BudgetSpending>[];
  for (final b in data.budgets
      .where((b) => !b.id.startsWith('event_') && active(b, today))) {
    final cfg = configs[b.id];
    final weekly = cfg?.rhythm == 'weekly';
    final w = windows[b.id]!;
    final first = weekly
        ? week(w.startDate, (cfg?.weekStart ?? 1).clamp(1, 7))
        : w.startDate;
    final start =
        weekly ? week(today, (cfg?.weekStart ?? 1).clamp(1, 7)) : w.startDate;
    final end = weekly
        ? DateTime(start.year, start.month, start.day + 7)
        : DateTime(w.endDate.year, w.endDate.month, w.endDate.day + 1);
    // Clip the first/last week to the persisted budget's own window. Each
    // calendar week receives this budget's configured weekly amount once.
    final effectiveStart = start.isBefore(w.startDate) ? w.startDate : start;
    final windowEnd =
        DateTime(w.endDate.year, w.endDate.month, w.endDate.day + 1);
    final effectiveEnd = end.isAfter(windowEnd) ? windowEnd : end;
    double carry = 0;
    double? previous;
    if (weekly && start.isAfter(first)) {
      final count = DateTime.utc(start.year, start.month, start.day)
              .difference(DateTime.utc(first.year, first.month, first.day))
              .inDays ~/
          7;
      final prevStart = DateTime(start.year, start.month, start.day - 7);
      previous = b.amount -
          spent(b, prevStart.isBefore(w.startDate) ? w.startDate : prevStart,
              start);
      if (cfg?.carryRule == 'signed') {
        carry = count * b.amount - spent(b, w.startDate, start);
      }
    } else if (!weekly) {
      var cursor = w.startDate;
      final seen = <String>{b.id};
      var takeCarry = cfg?.carryRule == 'signed';
      while (true) {
        final prev = data.budgets
            .where((v) =>
                v.categoryId == b.categoryId &&
                !seen.contains(v.id) &&
                (configs[v.id] == null || configs[v.id]!.rhythm == 'period') &&
                DateTime(
                        windows[v.id]!.endDate.year,
                        windows[v.id]!.endDate.month,
                        windows[v.id]!.endDate.day + 1) ==
                    cursor)
            .toList();
        if (prev.length != 1) break;
        final p = prev.single;
        seen.add(p.id);
        final pw = windows[p.id]!;
        final value = p.amount - spent(p, pw.startDate, cursor);
        previous ??= value;
        if (!takeCarry) break;
        carry += value;
        cursor = pw.startDate;
        takeCarry = configs[p.id]?.carryRule == 'signed';
        if (!takeCarry) break;
      }
    }
    final duplicate = data.budgets
            .where((v) =>
                v.categoryId == b.categoryId &&
                active(v, today) &&
                !v.id.startsWith('event_'))
            .length >
        1;
    final error = cfg != null &&
            (cfg.weekStart < 1 ||
                cfg.weekStart > 7 ||
                !['none', 'signed'].contains(cfg.carryRule) ||
                (cfg.remainingUses != null && cfg.remainingUses! <= 0))
        ? 'Cấu hình nhịp chưa hợp lệ'
        : !b.amount.isFinite || b.amount <= 0
            ? 'Hạn mức chưa hợp lệ'
            : duplicate
                ? 'Có ngân sách trùng danh mục và kỳ; cần chỉnh cấu hình'
                : cfg != null && !['weekly', 'period'].contains(cfg.rhythm)
                    ? 'Chưa xác định nhịp quản lý'
                    : null;
    final days =
        DateTime.utc(effectiveEnd.year, effectiveEnd.month, effectiveEnd.day)
            .difference(DateTime.utc(today.year, today.month, today.day))
            .inDays;
    result.add(BudgetSpending(
        budget: b,
        name: byId[b.categoryId]?.name ?? 'Danh mục chưa xác định',
        rhythm: weekly ? SpendingRhythm.weekly : SpendingRhythm.period,
        start: effectiveStart,
        end: effectiveEnd,
        spent: spent(b, effectiveStart, effectiveEnd),
        carry: carry,
        previousRemaining: previous,
        daysLeft: math.max(0, days),
        pinned: cfg?.pinned ?? false,
        remainingUses: cfg?.remainingUses,
        carryEnabled: cfg?.carryRule == 'signed',
        error: error));
  }
  result.sort((a, b) => a.budget.id.compareTo(b.budget.id));
  return BudgetSpendingOverview(List.unmodifiable(result), data,
      ownerByTransactionId: Map.unmodifiable({
        for (final entry in owned.entries)
          for (final tx in entry.value) tx.id: entry.key
      }));
}

Future<void> saveBudgetRhythm(AppDatabase db, Budget budget,
    {required SpendingRhythm rhythm,
    required int weekStart,
    required String carryRule,
    int? remainingUses,
    bool pinned = false}) async {
  if (!budget.amount.isFinite ||
      budget.amount <= 0 ||
      weekStart < 1 ||
      weekStart > 7 ||
      !['none', 'signed'].contains(carryRule) ||
      (remainingUses != null && remainingUses <= 0)) {
    throw ArgumentError('Cấu hình ngân sách không hợp lệ');
  }
  await db.transaction(() async {
    if (pinned) {
      await (db.update(db.budgetRhythms)
            ..where((r) => r.rhythm.equals(rhythm.name)))
          .write(const BudgetRhythmsCompanion(pinned: Value(false)));
    }
    await db.into(db.budgetRhythms).insertOnConflictUpdate(
        BudgetRhythmsCompanion.insert(
            budgetId: budget.id,
            rhythm: rhythm.name,
            weekStart: Value(weekStart),
            carryRule: Value(carryRule),
            remainingUses:
                Value(rhythm == SpendingRhythm.period ? remainingUses : null),
            pinned: Value(pinned)));
  });
}
