import 'dart:convert';
import '../../services/fiscal_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../theme/app_theme.dart';
import '../../screens/ledger_screen.dart' show computeMonthCycleRange;

final insightsTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>(
        (ref) => ref.watch(databaseProvider).watchAllTransactions());
final insightsCategoriesProvider =
    StreamProvider.autoDispose<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});
final insightsWalletsProvider = StreamProvider.autoDispose<List<Wallet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.wallets).watch();
});
final insightsBudgetsProvider = StreamProvider.autoDispose<List<Budget>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.budgets).watch();
});

enum InsightsPeriod { cycle, month, days7, quarter, year, custom }

// End is exclusive everywhere, including comparisons across month boundaries.
class InsightsWindow {
  final DateTime start, end;
  const InsightsWindow(this.start, this.end);
  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
  int get days => DateTime.utc(end.year, end.month, end.day)
      .difference(DateTime.utc(start.year, start.month, start.day))
      .inDays;
}

InsightsWindow insightsWindow(
    InsightsPeriod period, DateTime anchor, Map<String, int> cycles,
    {InsightsWindow? custom, bool previous = false}) {
  DateTime start, end;
  switch (period) {
    case InsightsPeriod.cycle:
      var month = DateTime(anchor.year, anchor.month);
      if (anchor.isBefore(computeMonthCycleRange(month, cycles).startDate)) {
        month = DateTime(month.year, month.month - 1);
      }
      if (previous) month = DateTime(month.year, month.month - 1);
      final range = computeMonthCycleRange(month, cycles);
      return InsightsWindow(
          range.startDate, range.endDate.add(const Duration(seconds: 1)));
    case InsightsPeriod.month:
      start = DateTime(anchor.year, anchor.month - (previous ? 1 : 0));
      end = DateTime(start.year, start.month + 1);
    case InsightsPeriod.quarter:
      start = DateTime(
          anchor.year, ((anchor.month - 1) ~/ 3) * 3 + 1 - (previous ? 3 : 0));
      end = DateTime(start.year, start.month + 3);
    case InsightsPeriod.year:
      start = DateTime(anchor.year - (previous ? 1 : 0));
      end = DateTime(start.year + 1);
    case InsightsPeriod.days7:
      end = DateTime(
          anchor.year, anchor.month, anchor.day + 1 - (previous ? 7 : 0));
      start = DateTime(end.year, end.month, end.day - 7);
    case InsightsPeriod.custom:
      final range = custom ??
          InsightsWindow(DateTime(anchor.year, anchor.month),
              DateTime(anchor.year, anchor.month, anchor.day + 1));
      return previous
          ? InsightsWindow(
              DateTime(range.start.year, range.start.month,
                  range.start.day - range.days),
              range.start)
          : range;
  }
  return InsightsWindow(start, end);
}

const insightsColors = [
  0xFF10B981,
  0xFFF59E0B,
  0xFF6366F1,
  0xFFF43F5E,
  0xFF0EA5E9,
  0xFFA855F7,
  0xFF14B8A6
];
Color stableInsightsColor(String id, [String? hex]) {
  final parsed = int.tryParse((hex ?? '').replaceAll('#', ''), radix: 16);
  if (parsed != null) return Color(parsed | 0xFF000000);
  final hash = id.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
  return Color(insightsColors[hash % insightsColors.length]);
}

class ClassificationGroup {
  final String id, name;
  final int color;
  const ClassificationGroup(this.id, this.name, this.color);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};
  factory ClassificationGroup.fromJson(Map<String, dynamic> json) =>
      ClassificationGroup(
          json['id'] as String, json['name'] as String, json['color'] as int);
}

class ClassificationScheme {
  final String id, name;
  final bool isSystemPreset;
  final List<ClassificationGroup> groups;
  // Each category has at most one group in this scheme. Missing means unclassified.
  final Map<String, String> assignments;
  const ClassificationScheme(
      {required this.id,
      required this.name,
      required this.groups,
      this.assignments = const {},
      this.isSystemPreset = false});
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'preset': isSystemPreset,
        'groups': groups.map((g) => g.toJson()).toList(),
        'assignments': assignments
      };
  factory ClassificationScheme.fromJson(Map<String, dynamic> json) =>
      ClassificationScheme(
          id: json['id'] as String,
          name: json['name'] as String,
          isSystemPreset: json['preset'] == true,
          groups: (json['groups'] as List)
              .map((g) => ClassificationGroup.fromJson(
                  Map<String, dynamic>.from(g as Map)))
              .toList(),
          assignments: Map<String, String>.from(json['assignments'] as Map));
}

// Classification is presentation configuration; transactions and category records
// remain untouched. One versioned preferences document makes each save atomic.
final classificationSchemesProvider =
    StateNotifierProvider<ClassificationSchemes, List<ClassificationScheme>>(
        (ref) => ClassificationSchemes(ref));

class ClassificationSchemes extends StateNotifier<List<ClassificationScheme>> {
  final Ref ref;
  static const storageKey = 'flowy_classification_schemes_v1';
  ClassificationSchemes(this.ref) : super(const []) {
    final raw = ref.read(sharedPreferencesProvider).getString(storageKey);
    if (raw != null) {
      try {
        state = (jsonDecode(raw) as List)
            .map((j) => ClassificationScheme.fromJson(
                Map<String, dynamic>.from(j as Map)))
            .toList();
      } catch (error) {
        debugPrint('Classification preferences could not be decoded: $error');
      }
    }
  }
  Future<void> save(ClassificationScheme scheme) async {
    final next = [...state.where((s) => s.id != scheme.id), scheme];
    await _persist(next);
  }

  Future<void> remove(String id) =>
      _persist(state.where((s) => s.id != id).toList());
  Future<void> _persist(List<ClassificationScheme> next) async {
    final saved = await ref.read(sharedPreferencesProvider).setString(
        storageKey, jsonEncode(next.map((s) => s.toJson()).toList()));
    if (!saved) throw StateError('Unable to save classification preferences');
    state = next;
  }
}

class InsightsBucket {
  final String id, name;
  final Color color;
  final Set<String> categoryIds;
  final List<Transaction> transactions;
  final double previous;
  const InsightsBucket(
      {required this.id,
      required this.name,
      required this.color,
      required this.categoryIds,
      required this.transactions,
      required this.previous});
  double get amount => transactions.fold(0, (sum, t) => sum + t.amount);
}

class InsightsReport {
  final List<Transaction> current, previous;
  final List<InsightsBucket> buckets;
  const InsightsReport(this.current, this.previous, this.buckets);
  double get total => current.fold(0, (sum, t) => sum + t.amount);
  double get previousTotal => previous.fold(0, (sum, t) => sum + t.amount);
  List<InsightsBucket> get slices {
    final positive = buckets.where((b) => b.amount > 0).toList();
    if (positive.length <= 5) return positive;
    final tail = positive.skip(5);
    return [
      ...positive.take(5),
      InsightsBucket(
          id: '__other',
          name: 'Khác',
          color: const Color(0xFF94A3B8),
          categoryIds: tail.expand((b) => b.categoryIds).toSet(),
          transactions: tail.expand((b) => b.transactions).toList(),
          previous: tail.fold(0, (sum, b) => sum + b.previous))
    ];
  }
}

String insightsClassification(
    Transaction transaction, ClassificationScheme? scheme) {
  if (scheme != null) {
    final group = scheme.groups
        .where((g) => g.id == scheme.assignments[transaction.categoryId])
        .firstOrNull;
    return group?.name == 'Thiết yếu'
        ? 'needs'
        : group?.name == 'Tùy ý'
            ? 'wants'
            : 'unknown';
  }
  return transaction.envelopeType == 'needs'
      ? 'needs'
      : transaction.envelopeType == 'wants'
          ? 'wants'
          : 'unknown';
}

InsightsReport buildInsightsReport(
    {required List<Transaction> transactions,
    required List<Category> categories,
    required InsightsWindow window,
    required InsightsWindow previousWindow,
    required CategoryType type,
    FiscalDayBoundary boundary = const FiscalDayBoundary(),
    Set<String> wallets = const {},
    ClassificationScheme? scheme,
    Set<String>? categoryIds,
    bool groupByLeaf = false,
    bool groupByWallet = false,
    bool groupByNature = false,
    ClassificationScheme? natureScheme,
    List<Wallet> walletRecords = const []}) {
  final byId = {for (final c in categories) c.id: c};
  String rootId(String id) {
    final seen = <String>{};
    while (byId[id]?.parentId != null && seen.add(id)) {
      id = byId[id]!.parentId!;
    }
    return id;
  }

  final eligible = transactions.where((t) =>
      t.deletedAt == null &&
      t.type == type &&
      t.amount.isFinite &&
      t.amount > 0 &&
      (wallets.isEmpty || wallets.contains(t.walletId)) &&
      (categoryIds == null || categoryIds.contains(t.categoryId)));
  final current = eligible.where((t) => window.contains(boundary.date(t.date))).toList();
  final previous =
      eligible.where((t) => previousWindow.contains(boundary.date(t.date))).toList();
  final groups = {
    for (final g in scheme?.groups ?? <ClassificationGroup>[]) g.id: g
  };
  String categoryKey(String categoryId) {
    if (scheme != null) {
      final group = scheme.assignments[categoryId];
      return groups.containsKey(group) ? group! : '__unclassified';
    }
    if (!byId.containsKey(categoryId)) return '__unknown';
    return groupByLeaf ? categoryId : rootId(categoryId);
  }

  String key(Transaction t) => groupByNature
      ? 'nature:${insightsClassification(t, natureScheme)}'
      : groupByWallet
          ? 'wallet:${t.walletId}'
          : categoryKey(t.categoryId);
  final keys = {...current.map(key), ...previous.map(key)};
  final buckets = keys.map((id) {
    final cat = byId[id];
    final group = groups[id];
    return InsightsBucket(
        id: id,
        name: groupByNature
            ? (id == 'nature:needs'
                ? 'Thiết yếu'
                : id == 'nature:wants'
                    ? 'Tùy ý'
                    : 'Chưa phân loại')
            : groupByWallet
                ? (walletRecords
                        .where((w) => 'wallet:${w.id}' == id)
                        .firstOrNull
                        ?.name ??
                    'Ví không xác định')
                : scheme == null
                    ? (cat?.name ?? 'Không xác định')
                    : (group?.name ?? 'Chưa phân loại'),
        color: id.startsWith('__')
            ? const Color(0xFF94A3B8)
            : (group != null
                ? Color(group.color)
                : stableInsightsColor(id, cat?.color)),
        categoryIds: {
          ...categories
              .where((c) =>
                  categoryKey(c.id) == id &&
                  (categoryIds == null || categoryIds.contains(c.id)))
              .map((c) => c.id),
          ...current.where((t) => key(t) == id).map((t) => t.categoryId),
          ...previous.where((t) => key(t) == id).map((t) => t.categoryId)
        },
        transactions: current.where((t) => key(t) == id).toList(),
        previous: previous
            .where((t) => key(t) == id)
            .fold(0, (sum, t) => sum + t.amount));
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return InsightsReport(current, previous, buckets);
}

class InsightsData {
  final List<Transaction> transactions;
  final List<Category> categories;
  final List<Wallet> wallets;
  final List<Budget> budgets;
  const InsightsData(
      this.transactions, this.categories, this.wallets, this.budgets);
}

final insightsDataProvider =
    FutureProvider.autoDispose<InsightsData>((ref) async {
  final transactions = ref.watch(insightsTransactionsProvider.future);
  final categories = ref.watch(insightsCategoriesProvider.future);
  final wallets = ref.watch(insightsWalletsProvider.future);
  final budgets = ref.watch(insightsBudgetsProvider.future);
  return InsightsData(
      await transactions, await categories, await wallets, await budgets);
});
