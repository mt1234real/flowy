import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../features/insights/insights_data.dart';
import '../features/notifications/notification_preferences.dart';
import '../screens/ledger_screen.dart' show cycleStartDaysByMonthProvider;
import '../theme/app_theme.dart';
import 'backup_schedule.dart';
import 'fiscal_day.dart';
import 'vault_security_service.dart';

/// Drift table notifications cover all write APIs, including direct companions.
/// Drift also emits after rollback; conservatively dirtying is safe in that case.
/// Notifications/receipts are intentionally excluded: automated reminder writes
/// must not cause a perpetual backup loop.
StreamSubscription<Set<TableUpdate>> observeBackupDatabaseChanges(
        AppDatabase db, void Function() changed) =>
    db
        .tableUpdates(TableUpdateQuery.onAllTables([
          db.transactions,
          db.wallets,
          db.categories,
          db.budgets,
          db.projectBudgets,
          db.savingsGoals,
          db.debtContacts,
          db.debtTransactions,
          db.entityArchives,
        ]))
        .listen((_) => changed());

final backupChangeObserverProvider = Provider<void>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  void changed() =>
      unawaited(markBackupDirty(prefs).catchError((Object error) =>
          debugPrint('Backup dirty state could not be persisted')));
  final subscription =
      observeBackupDatabaseChanges(ref.watch(databaseProvider), changed);
  ref.onDispose(subscription.cancel);

  ref.listen(themeModeProvider, (_, __) => changed());
  ref.listen(accentPresetProvider, (_, __) => changed());
  ref.listen(fontFamilyProvider, (_, __) => changed());
  ref.listen(currencyFontProvider, (_, __) => changed());
  ref.listen(classificationSchemesProvider, (_, __) => changed());
  ref.listen(notificationPreferencesProvider, (_, __) => changed());
  ref.listen(dayCutoffProvider, (_, __) => changed());
  ref.listen(vaultBiometricsProvider, (_, __) => changed());
  ref.listen(cycleStartDaysByMonthProvider, (before, after) {
    if (mapEquals(before, after)) return;
    // Persist the cycle snapshot before scheduling, rather than waiting for
    // the notification refresh debounce to persist it.
    Future<void> persistCycle() async {
      await prefs.setString('notification_cycle_snapshot', jsonEncode(after));
      await markBackupDirty(prefs);
    }

    unawaited(persistCycle().catchError((Object error) =>
        debugPrint('Backup cycle state could not be persisted')));
  });
});
