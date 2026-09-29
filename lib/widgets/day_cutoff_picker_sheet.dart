import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../services/fiscal_day.dart';
import '../features/notifications/notification_preferences.dart';

class DayCutoffPickerSheet extends ConsumerStatefulWidget {
  const DayCutoffPickerSheet({super.key, this.scrollController});
  final ScrollController? scrollController;
  static Future<void> show(BuildContext context) =>
      AppAnimationPolicy.showFluidSheet<void>(
          context: context,
          mode: FluidSheetMode.scrollable,
          enableBlur:
              context.getInheritedWidgetOfExactType<FluidSheetScope>() == null,
          builder: (_, controller) =>
              DayCutoffPickerSheet(scrollController: controller));
  @override
  ConsumerState<DayCutoffPickerSheet> createState() =>
      _DayCutoffPickerSheetState();
}

class _DayCutoffPickerSheetState extends ConsumerState<DayCutoffPickerSheet> {
  late int _minutes;
  bool _custom = false, _saving = false;
  @override
  void initState() {
    super.initState();
    _minutes = ref.read(dayCutoffProvider).minutes;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(dayCutoffProvider.notifier).setMinutes(_minutes);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      AppFeedback.showSuccess(context, 'Đã cập nhật mốc bắt đầu ngày mới');
      if (ModalRoute.of(context)?.isCurrent == true) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(
          context, 'Chưa lưu được mốc giờ. Vui lòng thử lại.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final valid = _minutes <= 360;
    final boundary = FiscalDayBoundary(_minutes.clamp(0, 360));
    final prefs = ref.watch(notificationPreferencesProvider);
    final warning = prefs.flag('evening')
        ? boundary.eveningWarning(prefs.number('eveningMinute', 1290))
        : null;
    return SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Material(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
                top: false,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                      child: Row(children: [
                        const Expanded(
                            child: Text('Mốc bắt đầu ngày mới',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800))),
                        IconButton(
                            tooltip: 'Đóng',
                            onPressed:
                                _saving ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded)),
                      ])),
                  Expanded(
                      child: ListView(
                          controller: widget.scrollController,
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                        const Text(
                            'Chi tiêu trước mốc này tính vào ngày hôm trước. Giờ giao dịch gốc vẫn được giữ nguyên.',
                            style: TextStyle(fontSize: 12, height: 1.4)),
                        const SizedBox(height: 12),
                        for (final minute in const [0, 180, 240, 300])
                          Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                  color: _minutes == minute
                                      ? accent.withValues(alpha: .10)
                                      : theme.colorScheme.surfaceContainer,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                          color: _minutes == minute
                                              ? accent
                                              : theme
                                                  .colorScheme.outlineVariant,
                                          width: .8)),
                                  child: ListTile(
                                      onTap: _saving
                                          ? null
                                          : () {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                _minutes = minute;
                                                _custom = false;
                                              });
                                            },
                                      title: Text(
                                          '${FiscalDayBoundary(minute).label}${minute == 0 ? ' · Mặc định' : ''}'),
                                      subtitle: Text(minute == 0
                                          ? 'Bắt đầu ngày mới từ nửa đêm'
                                          : 'Chi trước ${FiscalDayBoundary(minute).label} tính vào hôm trước'),
                                      trailing: _minutes == minute
                                          ? Icon(Icons.check_circle_rounded,
                                              color: accent)
                                          : null))),
                        TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _custom = !_custom),
                            child: const Text('Tùy chỉnh giờ khác')),
                        if (_custom)
                          LayoutBuilder(
                              builder: (context, constraints) => FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: CupertinoTimerPicker(
                                      mode: CupertinoTimerPickerMode.hm,
                                      initialTimerDuration:
                                          Duration(minutes: _minutes),
                                      onTimerDurationChanged: (value) {
                                        if (!_saving) {
                                          setState(
                                              () => _minutes = value.inMinutes);
                                        }
                                      }))),
                        Text(
                            valid
                                ? 'Chọn mốc trong khoảng 00:00–06:00.'
                                : 'Mốc giờ tối đa là 06:00. Vui lòng chọn lại.',
                            style: TextStyle(
                                fontSize: 12,
                                color: valid
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.error)),
                        if (warning != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(warning,
                                  style: const TextStyle(
                                      fontSize: 12, height: 1.4))),
                        const SizedBox(height: 16),
                      ])),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              onPressed: !valid || _saving ? null : _save,
                              child: Text(
                                  _saving ? 'Đang lưu…' : 'Lưu mốc giờ')))),
                ]))));
  }
}
