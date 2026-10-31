import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../screens/ledger_screen.dart' show cycleStartDaysByMonthProvider;
import 'budget_spending.dart';
import 'fiscal_day.dart';

// One injectable fiscal date for all budget presentations; the production
// clock still owns midnight/resume updates, never the UI or a poll timer.
final budgetSpendingDateProvider =
    Provider.autoDispose<DateTime>((ref) => ref.watch(fiscalTodayProvider));

final budgetSpendingDataProvider =
    StreamProvider.autoDispose<BudgetSpendingData>(
        (ref) => watchBudgetSpendingData(ref.watch(databaseProvider)));
final budgetSpendingOverviewProvider =
    Provider.autoDispose<AsyncValue<BudgetSpendingOverview>>((ref) {
  final data = ref.watch(budgetSpendingDataProvider);
  final today = ref.watch(budgetSpendingDateProvider);
  final boundary = ref.watch(dayCutoffProvider);
  final cycles = ref.watch(cycleStartDaysByMonthProvider);
  return data.whenData((d) => deriveBudgetSpending(d, today, boundary, cycles));
});
