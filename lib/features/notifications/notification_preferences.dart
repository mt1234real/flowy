import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../data/database.dart';

class NotificationPreferences {
  final Map<String, dynamic> values;
  const NotificationPreferences([this.values = const {}]);
  bool flag(String key, [bool fallback = true]) =>
      values[key] as bool? ?? fallback;
  int number(String key, int fallback) => values[key] as int? ?? fallback;
  List<int> get weekdays =>
      (values['weekdays'] as List?)?.cast<int>() ?? [1, 2, 3, 4, 5, 6, 7];
  NotificationPreferences withValue(String key, dynamic value) =>
      NotificationPreferences({...values, key: value});
}

class NotificationPreferencesNotifier
    extends StateNotifier<NotificationPreferences> {
  final SharedPreferences prefs;
  NotificationPreferencesNotifier(this.prefs) : super(_load(prefs));
  static NotificationPreferences _load(SharedPreferences prefs) {
    try {
      return NotificationPreferences(Map<String, dynamic>.from(
          jsonDecode(prefs.getString('notification_preferences_v1') ?? '{}')
              as Map));
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  Future<void> save(NotificationPreferences next) async {
    await prefs.setString(
        'notification_preferences_v1', jsonEncode(next.values));
    state = next;
  }
}

final notificationPreferencesProvider = StateNotifierProvider<
        NotificationPreferencesNotifier, NotificationPreferences>(
    (ref) =>
        NotificationPreferencesNotifier(ref.watch(sharedPreferencesProvider)));
final unreadNotificationCountProvider = StreamProvider<int>(
    (ref) => ref.watch(databaseProvider).watchUnreadNotificationCount());
final notificationListProvider =
    StreamProvider.family<List<AppNotification>, String?>((ref, type) =>
        ref.watch(databaseProvider).watchNotifications(filterType: type));
