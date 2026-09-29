import 'dart:async';
import '../../services/fiscal_day.dart';
import 'dart:convert';
import '../../widgets/backup_progress_curtain.dart';
import '../../services/cloud_backup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../screens/ledger_screen.dart' show cycleStartDaysByMonthProvider;
import 'notification_service.dart';
import 'notification_preferences.dart';
import 'notification_routes.dart';
import 'notification_background.dart';
import '../../theme/app_theme.dart';

final notificationCoordinatorProvider =
    Provider((ref) => NotificationCoordinator(ref.watch(databaseProvider)));
final notificationDailySnapshotProvider =
    StateProvider<({double safe, double spent, DateTime day})?>((ref) => null);

class NotificationHost extends ConsumerStatefulWidget {
  final Widget child;
  const NotificationHost({super.key, required this.child});
  @override
  ConsumerState<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends ConsumerState<NotificationHost>
    with WidgetsBindingObserver {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Timer? _timer, _debounce;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(startNotificationBackgroundRefresh().catchError(
        (Object e) => debugPrint('Background reminders unavailable: $e')));
    final db = ref.read(databaseProvider);
    for (final stream in <Stream<dynamic>>[
      db.watchAllTransactions(),
      db.select(db.debtTransactions).watch(),
      db.select(db.budgets).watch(),
      db.select(db.debtContacts).watch()
    ]) {
      var first = true;
      _subscriptions.add(stream.listen((_) {
        _queue();
        if (!first && ref.read(backupOperationProvider) == null) {
          unawaited(ref
              .read(cloudBackupServiceProvider)
              .notifyDataChanged()
              .catchError(
                  (Object e) => debugPrint('Backup scheduling failed: $e')));
        }
        first = false;
      }));
    }
    _subscriptions.add(NotificationPlatform.instance.taps.stream
        .listen((_) => _openPending()));
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _queue());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _queue() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _refresh);
  }

  Future<void> _refresh() async {
    if (!mounted || ref.read(backupOperationProvider) != null) return;
    final coordinator = ref.read(notificationCoordinatorProvider);
    try {
      await ref.read(sharedPreferencesProvider).setString(
          'notification_cycle_snapshot',
          jsonEncode(ref.read(cycleStartDaysByMonthProvider)));
      if (!mounted) return;
      await coordinator.refresh(ref.read(notificationPreferencesProvider),
            ref.read(cycleStartDaysByMonthProvider),
            boundary: ref.read(dayCutoffProvider));
      if (!mounted) return;
      ref.invalidate(unreadNotificationCountProvider);
      ref.invalidate(notificationListProvider);
      await _openPending();
      if (coordinator.takeRerun()) _queue();
    } catch (e, stack) {
      debugPrint('Notification refresh failed: $e\n$stack');
    }
  }

  Future<void> _openPending() async {
    final platform = NotificationPlatform.instance;
    final value = platform.pendingTap;
    if (!mounted ||
        _opening ||
        value == null ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _opening = true;
    try {
      final payload = jsonDecode(value) as Map;
      final id = payload['notificationId'] as String?;
      final db = ref.read(databaseProvider);
      final items = await db.select(db.appNotifications).get();
      final item = items.where((n) => n.id == id && !n.isDismissed).firstOrNull;
      platform.pendingTap = null;
      if (item != null && mounted) await openNotification(context, db, item);
    } catch (e) {
      debugPrint('Notification link failed: $e');
    } finally {
      _opening = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _queue();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(backupOperationProvider, (_, value) {
      if (value == null) _queue();
    });
    ref.listen(notificationPreferencesProvider, (_, __) => _queue());
    ref.listen(dayCutoffProvider, (_, __) => _queue());
    ref.listen(fiscalTodayProvider, (_, __) => _queue());
    ref.listen(cycleStartDaysByMonthProvider, (_, __) => _queue());
    ref.listen(notificationDailySnapshotProvider, (_, value) {
        if (value == null || ref.read(backupOperationProvider) != null) return;
        if (value.day != ref.read(fiscalTodayProvider)) return;
      unawaited(ref
          .read(notificationCoordinatorProvider)
          .dailyLimit(
              safe: value.safe,
              spent: value.spent,
                prefs: ref.read(notificationPreferencesProvider),
                boundary: ref.read(dayCutoffProvider))
          .catchError(
              (Object e) => debugPrint('Daily notification failed: $e')));
    });
    return widget.child;
  }
}
