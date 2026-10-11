import 'dart:async';

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/screens/ledger_screen.dart';
import 'package:pfm_app/services/fiscal_day.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Freeze only the clock-facing date; start/end still use real fiscal boundaries.
class _FixedBoundary extends FiscalDayBoundary {
  const _FixedBoundary(this.today, [super.minutes]);
  final DateTime today;

  @override
  DateTime date(DateTime actual) => today;
}

class _TestCutoff extends DayCutoffNotifier {
  _TestCutoff(super.prefs, FiscalDayBoundary boundary) {
    state = boundary;
  }

  void change(FiscalDayBoundary boundary) => state = boundary;
}

void main() {
  for (final scenario in [
    (month: 10, day: 2, startDay: 5, anchor: 9),
    (month: 10, day: 4, startDay: 5, anchor: 9),
    (month: 10, day: 5, startDay: 5, anchor: 10),
    (month: 10, day: 20, startDay: 5, anchor: 10),
    (month: 9, day: 4, startDay: 5, anchor: 8),
    (month: 9, day: 5, startDay: 5, anchor: 9),
    (month: 10, day: 8, startDay: 10, anchor: 9),
    (month: 10, day: 10, startDay: 10, anchor: 10),
    (month: 10, day: 2, startDay: 1, anchor: 10),
    (month: 2, day: 27, startDay: 31, anchor: 1),
    (month: 2, day: 28, startDay: 31, anchor: 2),
    (month: 4, day: 30, startDay: 31, anchor: 4),
  ]) {
    test(
        'ledgerDefaultCycle_${scenario.day}/${scenario.month}_start${scenario.startDay}',
        () {
      final today = DateTime(2026, scenario.month, scenario.day);
      final store = {'default': scenario.startDay};
      final anchor = resolveActiveCycleAnchorMonth(
          fiscalDate: today, mode: CycleMode.customCycle, store: store);
      expect(anchor, DateTime(2026, scenario.anchor));
      final range = computeMonthCycleRange(anchor, store);
      expect(today.isBefore(range.startDate), isFalse);
      expect(today.isAfter(range.endDate), isFalse);
      if (scenario.month == 10 && scenario.startDay == 5) {
        expect(range.startDate, DateTime(2026, scenario.anchor, 5));
        expect(
            range.endDate,
            DateTime(2026, scenario.anchor + 1, 5)
                .subtract(const Duration(seconds: 1)));
      }
    });
  }

  test('ledgerCalendarMode_02Oct_staysOctober', () {
    expect(
        resolveActiveCycleAnchorMonth(
            fiscalDate: DateTime(2026, 10, 2),
            mode: CycleMode.calendar,
            store: const {'default': 5}),
        DateTime(2026, 10));
  });

  test('ledgerDefaultCycle_respectsMonthlyOverridesAndYearRollover', () {
    const store = {'default': 5, '2026-09': 10, '2026-10': 20};
    final anchor = resolveActiveCycleAnchorMonth(
        fiscalDate: DateTime(2026, 10, 15),
        mode: CycleMode.customCycle,
        store: store);
    expect(anchor, DateTime(2026, 9));
    final range = computeMonthCycleRange(anchor, store);
    expect(range.startDate, DateTime(2026, 9, 10));
    expect(range.endDate, DateTime(2026, 10, 19, 23, 59, 59));
    expect(
        resolveActiveCycleAnchorMonth(
            fiscalDate: DateTime(2026, 1, 4),
            mode: CycleMode.customCycle,
            store: const {'default': 5}),
        DateTime(2025, 12));
  });

  test('ledgerDefaultCycle_respectsFiscalDayBoundary', () {
    const boundary = FiscalDayBoundary(4 * 60);
    for (final scenario in [
      (actual: DateTime(2026, 10, 2, 2), day: 1, anchor: 9),
      (actual: DateTime(2026, 10, 5, 2), day: 4, anchor: 9),
      (actual: DateTime(2026, 10, 5, 4), day: 5, anchor: 10),
    ]) {
      final fiscalDate = boundary.date(scenario.actual);
      expect(fiscalDate, DateTime(2026, 10, scenario.day));
      expect(
          resolveActiveCycleAnchorMonth(
              fiscalDate: fiscalDate,
              mode: CycleMode.customCycle,
              store: const {'default': 5}),
          DateTime(2026, scenario.anchor));
    }
  });

  group('Ledger provider and query integration', () {
    late AppDatabase db;
    late ProviderContainer container;
    late _TestCutoff cutoff;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'flowy_cycle_start_day': 5});
      final prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      cutoff = _TestCutoff(prefs, _FixedBoundary(DateTime(2026, 10, 2), 240));
      container = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        dayCutoffProvider.overrideWith((ref) => cutoff),
      ]);
      await db.into(db.wallets).insert(
          WalletsCompanion.insert(id: 'wallet', name: 'Wallet', type: 'cash'));
      await db.into(db.categories).insert(CategoriesCompanion.insert(
          id: 'food', name: 'Food', type: CategoryType.expense));
      for (final entry in [
        ('before', DateTime(2026, 9, 5, 3, 59, 59)),
        ('start', DateTime(2026, 9, 5, 4)),
        ('today', DateTime(2026, 10, 2, 12)),
        ('end', DateTime(2026, 10, 5, 3, 59, 59)),
        ('next', DateTime(2026, 10, 5, 4)),
      ]) {
        await db.into(db.transactions).insert(TransactionsCompanion.insert(
            id: entry.$1,
            walletId: 'wallet',
            categoryId: 'food',
            amount: 100,
            type: CategoryType.expense,
            date: entry.$2,
            note: Value(entry.$1)));
      }
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<List<UnifiedLedgerItem>> rows(Set<String> expected) {
      final completer = Completer<List<UnifiedLedgerItem>>();
      final subscription =
          container.listen(unifiedLedgerStreamProvider, (_, next) {
        next.whenData((items) {
          final ids = items.map((item) => item.id).toSet();
          if (!completer.isCompleted &&
              ids.length == expected.length &&
              ids.containsAll(expected)) {
            completer.complete(items);
          }
        });
        if (next.hasError && !completer.isCompleted) {
          completer.completeError(next.error!, next.stackTrace);
        }
      }, fireImmediately: true);
      addTearDown(subscription.close);
      return completer.future.timeout(const Duration(seconds: 5));
    }

    test('ledgerDefaultCycle_providerMatchesDashboardAndHeaderRange', () async {
      final today = cutoff.state.date(DateTime.now());
      final store = container.read(cycleStartDaysByMonthProvider);
      var dashboardAnchor = DateTime(today.year, today.month);
      if (today
          .isBefore(computeMonthCycleRange(dashboardAnchor, store).startDate)) {
        dashboardAnchor = DateTime(today.year, today.month - 1);
      }
      final anchor = container.read(currentAnchorMonthProvider);
      expect(anchor, dashboardAnchor);
      final range = computeMonthCycleRange(anchor, store);
      expect(range.label, 'Chu kỳ Tháng 09/2026');
      expect(range.subRange, '05/09 – 04/10 (30 ngày)');
      final items = await rows({'start', 'today', 'end'});
      expect(computeLedgerSummary(items).moneyOut, 300);
    });

    test('ledgerDefaultCycle_modeAndSettingsChangesRefreshOnlyDefault', () {
      expect(container.read(currentAnchorMonthProvider), DateTime(2026, 9));
      container.read(cycleModeProvider.notifier).state = CycleMode.calendar;
      expect(container.read(currentAnchorMonthProvider), DateTime(2026, 10));
      container.read(cycleModeProvider.notifier).state = CycleMode.customCycle;
      expect(container.read(currentAnchorMonthProvider), DateTime(2026, 9));
      container.read(cycleStartDaysByMonthProvider.notifier).state = {
        'default': 1
      };
      expect(container.read(currentAnchorMonthProvider), DateTime(2026, 10));
      container.read(cycleStartDaysByMonthProvider.notifier).state = {
        'default': 5
      };
      expect(container.read(currentAnchorMonthProvider), DateTime(2026, 9));
      cutoff.change(_FixedBoundary(DateTime(2026, 10, 5), 0));
      expect(container.read(currentAnchorMonthProvider), DateTime(2026, 10));
    });

    test('ledgerHistoricalAnchor_survivesRebuildModeAndSettingsUntilReset', () {
      final subscription =
          container.listen(currentAnchorMonthProvider, (_, next) {});
      addTearDown(subscription.close);
      container.read(currentAnchorMonthProvider.notifier).state =
          DateTime(2026, 7);
      container.read(cycleModeProvider.notifier).state = CycleMode.calendar;
      container.read(cycleStartDaysByMonthProvider.notifier).state = {
        'default': 1
      };
      cutoff.change(_FixedBoundary(DateTime(2026, 10, 5)));
      expect(container.read(currentAnchorMonthProvider), DateTime(2026, 7));
      container.read(cycleModeProvider.notifier).state = CycleMode.customCycle;
      container.read(cycleStartDaysByMonthProvider.notifier).state = {
        'default': 10
      };
      expect(container.read(currentAnchorMonthProvider), DateTime(2026, 7));
      container.invalidate(currentAnchorMonthProvider);
      expect(container.read(currentAnchorMonthProvider), DateTime(2026, 9));
    });

    test('ledgerCycleQuery_previousNextAndCalendarUseSelectedAnchor', () async {
      expect(container.read(currentAnchorMonthProvider), DateTime(2026, 9));
      container.read(currentAnchorMonthProvider.notifier).state =
          DateTime(2026, 8);
      await rows({'before'});
      container.read(currentAnchorMonthProvider.notifier).state =
          DateTime(2026, 9);
      await rows({'start', 'today', 'end'});
      container.read(currentAnchorMonthProvider.notifier).state =
          DateTime(2026, 10);
      await rows({'next'});
      container.read(cycleModeProvider.notifier).state = CycleMode.calendar;
      await rows({'today', 'end', 'next'});
    });

    test('ledgerCycleQuery_customDatesSearchAndWalletFiltersRemainIndependent',
        () async {
      container.read(ledgerFilterCriteriaProvider.notifier).state =
          LedgerFilterCriteria(
              walletId: 'wallet',
              categoryIds: const {'food'},
              customDateRange: DateTimeRange(
                  start: DateTime(2026, 10, 2), end: DateTime(2026, 10, 2)));
      container.read(ledgerSearchQueryProvider.notifier).state = 'today';
      final items = await rows({'today'});
      expect(computeLedgerSummary(items, walletId: 'wallet').moneyOut, 100);
      expect(container.read(currentAnchorMonthProvider), DateTime(2026, 9));
    });
  });
}
