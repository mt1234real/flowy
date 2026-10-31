import 'dart:async';
import '../../services/fiscal_day.dart';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../data/database.dart';
import '../../services/budget_windows.dart';
import '../../services/budget_spending.dart';
import 'notification_preferences.dart';

class NotificationPlatform {
  static final instance = NotificationPlatform();
  final plugin = FlutterLocalNotificationsPlugin();
  final taps = StreamController<String>.broadcast();
  String? pendingTap;
  bool ready = false;
  Future<void>? _initializing;
  Future<void> initialize() async {
    if (ready) return;
    final attempt = _initializing ??= _initialize();
    try {
      await attempt;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    tz_data.initializeTimeZones();
    await updateTimezone();
    await plugin.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings('ic_notification'),
            iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false)),
        onDidReceiveNotificationResponse: (response) {
      final value = response.payload;
      if (value != null) {
        pendingTap = value;
        taps.add(value);
      }
    });
    pendingTap = (await plugin.getNotificationAppLaunchDetails())
        ?.notificationResponse
        ?.payload;
    ready = true;
  }

  Future<void> updateTimezone() async {
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<bool> enabled() async {
    await initialize();
    if (!ready) return false;
    if (Platform.isAndroid) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (Platform.isIOS) {
      final permissions = await plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return permissions?.isEnabled ?? false;
    }
    return false;
  }

  Future<void> requestExactPermission() async {
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  static int osId(String id) {
    var hash = 2166136261;
    for (final code in id.codeUnits) {
      hash = ((hash ^ code) * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  Future<void> cancel(String id) async {
    if (ready) await plugin.cancel(osId(id));
  }

  String privateBody(String type) => switch (type) {
        'budget' =>
          'Có cập nhật về hạn mức chi tiêu. Mở Flowy để xem chi tiết.',
        'debt' =>
          'Bạn có một khoản hẹn tài chính cần đối soát. Mở Flowy để xem.',
        'digest' => 'Bản tổng kết tuần đã sẵn sàng. Mở Flowy để xem.',
        _ => 'Dành một chút thời gian điểm lại ghi chép hôm nay cùng Flowy.',
      };
  Future<void> deliver(AppNotification item, NotificationPreferences prefs,
      {required bool schedule}) async {
    if (!ready || item.isDismissed) return;
    final hidden = prefs.flag('private');
    final details = NotificationDetails(
        android: AndroidNotificationDetails('flowy_calm_v1', 'Nhắc nhở Flowy',
            channelDescription: 'Ghi chép, hạn mức và các khoản hẹn tài chính',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            visibility: hidden
                ? NotificationVisibility.private
                : NotificationVisibility.public,
            onlyAlertOnce: true,
            icon: 'ic_notification'),
        iOS: const DarwinNotificationDetails(
            presentAlert: true, presentSound: true));
    final payload = jsonEncode({'notificationId': item.id});
    final body = hidden ? privateBody(item.type) : item.body;
    final title = hidden
        ? switch (item.type) {
            'budget' => 'Cập nhật hạn mức',
            'debt' => 'Khoản hẹn tài chính',
            'digest' => 'Tổng kết tuần',
            _ => 'Điểm lại hôm nay'
          }
        : item.title;
    if (schedule) {
      final exact = await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.canScheduleExactNotifications() ??
          false;
      await plugin.zonedSchedule(osId(item.id), title, body,
          tz.TZDateTime.from(item.createdAt, tz.local), details,
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload);
    } else {
      await plugin.show(osId(item.id), title, body, details, payload: payload);
    }
  }
}

class _Notice {
  final String key, title, body, type;
  final Map<String, dynamic> target;
  final DateTime at;
  final String? entity;
  const _Notice(
      this.key, this.title, this.body, this.type, this.target, this.at,
      [this.entity]);
}

class NotificationCoordinator {
  final AppDatabase db;
  NotificationCoordinator(this.db);
  final platform = NotificationPlatform.instance;
  Future<void>? _running;
  bool _rerun = false;
  bool? _lastPrivate;
  final _scheduledSignatures = <int, String>{};
  Future<void> refresh(
      NotificationPreferences prefs, Map<String, int> cycles,
      {FiscalDayBoundary boundary = const FiscalDayBoundary()}) async {
    if (_running != null) {
      _rerun = true;
      await _running;
      return;
    }
    _running = _refresh(prefs, cycles, boundary);
    try {
      await _running;
    } finally {
      _running = null;
    }
  }

  bool takeRerun() {
    final value = _rerun;
    _rerun = false;
    return value;
  }

  String _money(double n) =>
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
          .format(n);
  Future<void> _refresh(
      NotificationPreferences prefs, Map<String, int> cycles,
      FiscalDayBoundary boundary) async {
    await platform.initialize();
    if (platform.ready) await platform.updateTimezone();
    if (platform.ready && prefs.flag('private') && _lastPrivate != true) {
      for (final active in await platform.plugin.getActiveNotifications()) {
        if (active.id != null) await platform.plugin.cancel(active.id!);
      }
    }
    _lastPrivate = prefs.flag('private');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fiscalToday = boundary.date(now);
    final txs = await (db.select(db.transactions)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    // Reminders count all activity; financial summaries exclude Vault movements.
    final reportableTxs = txs
        .where((t) => t.goalId == null && t.envelopeType != 'savings')
        .toList();
    final debts = await (db.select(db.debtTransactions)
          ..where((d) => d.deletedAt.isNull()))
        .get();
    final categories = await db.select(db.categories).get();
    final contacts = await db.select(db.debtContacts).get();
    final plan = <_Notice>[];
    String day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
    for (var offset = 0; offset < 14; offset++) {
      final date = DateTime(fiscalToday.year, fiscalToday.month, fiscalToday.day + offset);
      final end = DateTime(date.year, date.month, date.day + 1);
      final count = txs
              .where((t) => boundary.contains(t.date, date))
              .length +
          debts
              .where((t) => boundary.contains(t.date, date))
              .length;
      void reminder(String slot, int fallback) {
        if (!prefs.flag(slot, slot == 'evening') ||
            !prefs.weekdays.contains(date.weekday)) {
          return;
        }
        if (slot == 'evening' && prefs.flag('onlyEmpty', false) && count > 0) {
          return;
        }
        final minute = prefs.number('${slot}Minute', fallback).clamp(0, 1439);
        final at = boundary.reminderAt(date, minute);
        final body = count == 0
            ? 'Hôm nay bạn chưa có ghi chép. Dành một chút thời gian điểm lại các khoản thu chi nhé.'
            : 'Hôm nay bạn đã ghi $count giao dịch. Bạn có muốn kiểm tra lại các khoản vừa ghi?';
        plan.add(_Notice(
            '$slot:${day(date)}',
            slot == 'midday' ? 'Điểm lại buổi trưa' : 'Điểm lại hôm nay',
            body,
            'reminder',
            {'target': 'quick_entry'},
            at));
      }

      reminder('evening', 21 * 60 + 30);
      reminder('midday', 12 * 60 + 30);
      if (date.weekday == DateTime.sunday && prefs.flag('digest')) {
        final start = date.subtract(const Duration(days: 6));
        final week = reportableTxs.where((t) =>
            !t.date.isBefore(boundary.start(start)) &&
            t.date.isBefore(boundary.start(end)));
        final expense = week
            .where((t) => t.type == CategoryType.expense)
            .fold(0.0, (s, t) => s + t.amount);
        final income = week
            .where((t) => t.type == CategoryType.income)
            .fold(0.0, (s, t) => s + t.amount);
        plan.add(_Notice(
            'week:${day(date)}',
            'Điểm lại tuần qua',
            'Đã ghi ${week.length} giao dịch: thu ${_money(income)}, chi ${_money(expense)}.',
            'digest',
            {
              'target': 'budget_insights',
              'start': start.toIso8601String(),
              'end': end.toIso8601String()
            },
            DateTime(date.year, date.month, date.day, 20)));
      }
    }
    if (prefs.flag('debts')) {
      for (final debt in debts.where((d) =>
          d.dueDate != null &&
          !d.isSettled &&
          ['LEND', 'BORROW'].contains(d.type))) {
        final date = debt.dueDate!;
        final contact =
            contacts.where((c) => c.id == debt.contactId).firstOrNull;
        for (final advance in [
          if (prefs.flag('debtBefore')) 1,
          if (prefs.flag('debtOnDay')) 0
        ]) {
          final at = DateTime(date.year, date.month, date.day - advance, 8, 30);
          if (at.isBefore(today) ||
              at.isAfter(today.add(const Duration(days: 30)))) {
            continue;
          }
          plan.add(_Notice(
              'debt:${debt.id}:${day(date)}:$advance',
              advance == 0 ? 'Khoản vay đến hẹn' : 'Khoản vay sắp đến hẹn',
              '${debt.type == 'LEND' ? 'Khoản cho vay' : 'Khoản vay'} với ${contact?.name ?? 'đối tác'}: ${_money(debt.amount)}, hẹn ${DateFormat('dd/MM').format(date)}.',
              'debt',
              {
                'target': 'debt_detail',
                'id': debt.id,
                'contactId': debt.contactId
              },
              at,
              debt.id));
        }
      }
    }
    if (prefs.flag('budget80') || prefs.flag('budget100')) {
      final overview=deriveBudgetSpending(await readBudgetSpendingData(db),fiscalToday,boundary,cycles);
      for (final item in overview.items) {
        if(item.error!=null)continue;
        final budget=item.budget;
        if (budget.amount <= 0) continue;
        final window = ResolvedBudgetWindow(startDate:item.start,endDate:item.end.subtract(const Duration(seconds:1)),label:'');
        if (now.isBefore(boundary.start(window.startDate)) || !now.isBefore(boundary.end(window.endDate))) {
          continue;
        }
        final ids = <String>{budget.categoryId};
        var changed = true;
        while (changed) {
          final before = ids.length;
          ids.addAll(categories
              .where((c) => ids.contains(c.parentId))
              .map((c) => c.id));
          changed = ids.length != before;
        }
        final spent = item.spent;
        final threshold = spent >= item.available
            ? 100
            : spent >= item.available * .8
                ? 80
                : 0;
        if (threshold == 0 || !prefs.flag('budget$threshold')) continue;
        final name = categories
                .where((c) => c.id == budget.categoryId)
                .firstOrNull
                ?.name ??
            'Danh mục';
        final remaining = DateTime.utc(window.endDate.year, window.endDate.month, window.endDate.day)
            .difference(DateTime.utc(fiscalToday.year, fiscalToday.month, fiscalToday.day)).inDays + 1;
        plan.add(_Notice(
            'budget:${budget.id}:${day(window.startDate)}:$threshold',
            threshold == 100
                ? '$name đã chạm hạn mức'
                : '$name gần chạm hạn mức',
            'Đã dùng ${item.available>0?(spent/item.available*100).toStringAsFixed(0):'—'}%: ${_money(spent)} / ${_money(item.available)}. Còn $remaining ngày trong ${item.rhythm==SpendingRhythm.weekly?'tuần':'kỳ'}; đây là kế hoạch, không xác nhận tiền dành riêng.',
            'budget',
            {
              'target': 'budget_insights',
              'id': budget.categoryId,
              'categoryIds': ids.toList(),
              'start': window.startDate.toIso8601String(),
              'end': window.endDate
                  .add(const Duration(seconds: 1))
                  .toIso8601String()
            },
            now,
            budget.id));
      }
    }
    // Cancel stale future events when time, days, due dates or switches change.
    final desired = plan.map((n) => n.key).toSet();
    final existing = await db.select(db.appNotifications).get();
    for (final item in existing) {
      final debtGone = item.type == 'debt' &&
          !debts.any((d) => d.id == item.relatedEntityId && !d.isSettled);
      if (debtGone ||
          (item.createdAt.isAfter(now) && !desired.contains(item.dedupKey))) {
        await platform.cancel(item.id);
        if (item.createdAt.isAfter(now)) {
          await (db.delete(db.appNotifications)
                ..where((n) => n.id.equals(item.id)))
              .go();
        } else {
          await db.deleteNotification(item.id);
        }
      } else if (item.isDismissed) {
        await platform.cancel(item.id);
      }
    }
    final pending = <AppNotification>[];
    for (final notice in plan) {
      final inserted = await db.createNotificationIfNotExists(
          dedupKey: notice.key,
          title: notice.title,
          body: notice.body,
          type: notice.type,
          payload: jsonEncode(notice.target),
          relatedEntityId: notice.entity,
          createdAt: notice.at);
      var item = inserted ??
          await (db.select(db.appNotifications)
                ..where((n) => n.dedupKey.equals(notice.key)))
              .getSingleOrNull();
      if (item == null || item.isDismissed) continue;
      if (item.createdAt.isAfter(now)) {
        if (item.title != notice.title ||
            item.body != notice.body ||
            item.createdAt != notice.at ||
            item.payload != jsonEncode(notice.target)) {
          await (db.update(db.appNotifications)
                ..where((n) => n.id.equals(item!.id)))
              .write(AppNotificationsCompanion(
                  title: Value(notice.title),
                  body: Value(notice.body),
                  createdAt: Value(notice.at),
                  payload: Value(jsonEncode(notice.target))));
        }
        item = item.copyWith(
            title: notice.title, body: notice.body, createdAt: notice.at);
        if (item.createdAt.isAfter(now)) pending.add(item);
      } else if (inserted != null &&
          now.difference(notice.at) < const Duration(minutes: 15)) {
        await platform.deliver(item, prefs, schedule: false);
      }
    }
    pending.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    // Keep below iOS's pending-notification cap and common Android OEM limits.
    final selected = pending.take(60).toList();
    if (platform.ready) {
      final wanted =
          selected.map((n) => NotificationPlatform.osId(n.id)).toSet();
      final requests = await platform.plugin.pendingNotificationRequests();
      final installed = requests.map((r) => r.id).toSet();
      for (final request in requests) {
        if (!wanted.contains(request.id)) {
          await platform.plugin.cancel(request.id);
          _scheduledSignatures.remove(request.id);
        }
      }
      for (final item in selected) {
        final id = NotificationPlatform.osId(item.id);
        final signature =
            '${item.createdAt.toIso8601String()}|${item.title}|${item.body}|${prefs.flag('private')}';
        if (!installed.contains(id) || _scheduledSignatures[id] != signature) {
          await platform.deliver(item, prefs, schedule: true);
          _scheduledSignatures[id] = signature;
        }
      }
    }
    await db.purgeOldNotifications();
  }

  Future<void> dailyLimit(
      {required double safe,
      required double spent,
      required NotificationPreferences prefs,
      FiscalDayBoundary boundary = const FiscalDayBoundary()}) async {
    if (!prefs.flag('dailyLimit') || safe > 0 || spent <= 0) return;
    await platform.initialize();
    final now = boundary.date(DateTime.now());
    final item = await db.createNotificationIfNotExists(
        dedupKey: 'safe:${DateFormat('yyyy-MM-dd').format(now)}',
        title: 'Hạn mức hôm nay đã dùng hết',
        body:
            'Đã chi ${_money(spent)} hôm nay. Bạn có thể xem lại các khoản chi trước khi quyết định khoản tiếp theo.',
        type: 'budget',
        payload: jsonEncode({
          'target': 'budget_insights',
          'start': DateTime(now.year, now.month, now.day).toIso8601String(),
          'end': DateTime(now.year, now.month, now.day + 1).toIso8601String()
        }));
    if (item != null) await platform.deliver(item, prefs, schedule: false);
  }
}
