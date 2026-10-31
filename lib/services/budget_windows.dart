import '../data/database.dart';

class ResolvedBudgetWindow {
  const ResolvedBudgetWindow(
      {required this.startDate, required this.endDate, required this.label});
  final DateTime startDate, endDate;
  final String label;
}

// Same clamping and inherited next-month cutoff as the existing ledger cycle.
ResolvedBudgetWindow resolveBudgetWindow(
    Budget budget, Map<String, int> cycleStore) {
  final m = budget.periodMonth;
  final store = Map<String, int>.from(cycleStore);
  String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  store[key(m)] = budget.cycleStartDay;
  int day(DateTime d) {
    for (var i = 0; i <= 12; i++) {
      final v = store[key(DateTime(d.year, d.month - i))];
      if (v != null) return v;
    }
    return store['default'] ?? 10;
  }

  final next = DateTime(m.year, m.month + 1);
  final start = DateTime(m.year, m.month,
      budget.cycleStartDay.clamp(1, DateTime(m.year, m.month + 1, 0).day));
  final end = DateTime(next.year, next.month,
          day(next).clamp(1, DateTime(next.year, next.month + 1, 0).day))
      .subtract(const Duration(seconds: 1));
  String short(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  return ResolvedBudgetWindow(
      startDate: start, endDate: end, label: '${short(start)} – ${short(end)}');
}
