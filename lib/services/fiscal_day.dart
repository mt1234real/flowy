import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

const dayCutoffHourKey = 'flowy_day_cutoff_hour';
const dayCutoffMinuteKey = 'flowy_day_cutoff_minute';

/// Calendar labels are never written back into a transaction's actual timestamp.
class FiscalDayBoundary {
  const FiscalDayBoundary([this.minutes = 0])
      : assert(minutes >= 0 && minutes <= 360);
  final int minutes;
  factory FiscalDayBoundary.fromPreferences(SharedPreferences prefs) {
    final hour = (prefs.getInt(dayCutoffHourKey) ?? 0).clamp(0, 6);
    final minute = (prefs.getInt(dayCutoffMinuteKey) ?? 0).clamp(0, 59);
    return FiscalDayBoundary((hour * 60 + minute).clamp(0, 360));
  }
  String get label =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  DateTime start(DateTime day) =>
      DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  DateTime end(DateTime day) =>
      start(DateTime(day.year, day.month, day.day + 1));
  DateTime date(DateTime actual) {
    final local = actual.toLocal();
    return DateTime(local.year, local.month,
        local.day - (local.isBefore(start(local)) ? 1 : 0));
  }

  bool contains(DateTime actual, DateTime day) =>
      !actual.isBefore(start(day)) && actual.isBefore(end(day));
  // A reminder at 01:00 for a 04:00 boundary belongs to the previous label.
  DateTime reminderAt(DateTime day, int minute) => DateTime(day.year, day.month,
      day.day + (minute < minutes ? 1 : 0), minute ~/ 60, minute % 60);
  String? eveningWarning(int minute) => minute >= minutes && minute < 12 * 60
      ? 'Giờ nhắc này nằm sau mốc $label và đã sang ngày tài chính mới. Chọn trước mốc này nếu muốn điểm lại ngày hôm trước.'
      : null;
}

DateTime getFiscalDate(DateTime actualDateTime, int cutoffHour,
        {int cutoffMinute = 0}) =>
    FiscalDayBoundary((cutoffHour * 60 + cutoffMinute).clamp(0, 360))
        .date(actualDateTime);

class DayCutoffNotifier extends StateNotifier<FiscalDayBoundary> {
  DayCutoffNotifier(this._prefs)
      : super(FiscalDayBoundary.fromPreferences(_prefs));
  final SharedPreferences _prefs;
  Future<void> setMinutes(int minutes) async {
    final value = minutes.clamp(0, 360);
    final old = state;
    try {
      if (!await _prefs.setInt(dayCutoffHourKey, value ~/ 60) ||
          !await _prefs.setInt(dayCutoffMinuteKey, value % 60)) {
        throw StateError('Không lưu được mốc giờ');
      }
      state = FiscalDayBoundary(value);
    } catch (_) {
      await _prefs.setInt(dayCutoffHourKey, old.minutes ~/ 60);
      await _prefs.setInt(dayCutoffMinuteKey, old.minutes % 60);
      rethrow;
    }
  }
}

final dayCutoffProvider =
    StateNotifierProvider<DayCutoffNotifier, FiscalDayBoundary>(
        (ref) => DayCutoffNotifier(ref.watch(sharedPreferencesProvider)));

class _FiscalClock extends StateNotifier<DateTime> with WidgetsBindingObserver {
  _FiscalClock(this.boundary) : super(boundary.date(DateTime.now())) {
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }
  final FiscalDayBoundary boundary;
  Timer? _timer;
  void _refresh() {
    _timer?.cancel();
    final now = DateTime.now();
    final day = boundary.date(now);
    if (state != day) state = day;
    _timer = Timer(
        boundary.end(day).difference(now) + const Duration(milliseconds: 20),
        _refresh);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final fiscalTodayProvider =
    StateNotifierProvider.autoDispose<_FiscalClock, DateTime>(
        (ref) => _FiscalClock(ref.watch(dayCutoffProvider)));
