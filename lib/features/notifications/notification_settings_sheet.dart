import 'dart:math' as math;
import '../../services/fiscal_day.dart';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../core/animation/app_animation_policy.dart';
import '../../core/feedback/app_feedback.dart';
import 'notification_preferences.dart';
import 'notification_service.dart';

class NotificationSettingsSheet extends ConsumerStatefulWidget {
  final ScrollController controller;
  const NotificationSettingsSheet({super.key, required this.controller});
  static Future<void> show(BuildContext context) =>
      AppAnimationPolicy.showFluidSheet<void>(
          context: context,
          mode: FluidSheetMode.scrollable,
          builder: (_, controller) =>
              NotificationSettingsSheet(controller: controller!));
  @override
  ConsumerState<NotificationSettingsSheet> createState() =>
      _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState
    extends ConsumerState<NotificationSettingsSheet>
    with WidgetsBindingObserver {
  late NotificationPreferences _draft;
  bool _saving = false, _requesting = false;
  bool? _enabled, _exact;
  String? _permissionError, _editingTime;
  int _permissionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(notificationPreferencesProvider);
    WidgetsBinding.instance.addObserver(this);
    _refreshPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermission();
  }

  Future<void> _refreshPermission() async {
    final generation = ++_permissionGeneration;
    try {
      final platform = NotificationPlatform.instance;
      final enabled = await platform.enabled();
      final exact = !Platform.isAndroid ||
          await platform.plugin
                  .resolvePlatformSpecificImplementation<
                      AndroidFlutterLocalNotificationsPlugin>()
                  ?.canScheduleExactNotifications() ==
              true;
      if (!mounted || generation != _permissionGeneration) return;
      setState(() {
        _enabled = enabled;
        _exact = exact;
        _permissionError = null;
      });
    } catch (_) {
      if (mounted && generation == _permissionGeneration) {
        setState(
            () => _permissionError = 'Chưa kiểm tra được quyền thông báo.');
      }
    }
  }

  Future<void> _requestPermission() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    try {
      final platform = NotificationPlatform.instance;
      await platform.initialize();
      if (_enabled != true) {
        final allowed = await platform.requestPermission();
        if (!allowed && mounted) {
          AppFeedback.showInfo(context,
              'Bạn có thể bật thông báo cho Flowy trong cài đặt hệ thống.');
        }
      } else if (Platform.isAndroid && _exact != true) {
        await platform.requestExactPermission();
      }
      await _refreshPermission();
    } catch (_) {
      if (mounted) {
        AppFeedback.showInfo(
            context, 'Chưa mở được phần cấp quyền. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  void _set(String key, dynamic value) =>
      setState(() => _draft = _draft.withValue(key, value));
  void _close() {
    if (!_saving && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(notificationPreferencesProvider.notifier).save(_draft);
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppFeedback.showError(
            context, 'Chưa lưu được cài đặt. Vui lòng thử lại.');
      }
    }
  }

  Widget _toggle(String key, String title,
          {String? subtitle, bool fallback = true}) =>
      SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: subtitle == null
              ? null
              : Text(subtitle,
                  style: const TextStyle(fontSize: 11, height: 1.4)),
          value: _draft.flag(key, fallback),
          onChanged: _saving ? null : (value) => _set(key, value));
  Widget _card(String title, List<Widget> children) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: dark ? .06 : .85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .5), width: .8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: colors.onSurfaceVariant)),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  Widget _rhythm(String slot, String title, int fallback) {
    final enabled = _draft.flag(slot, slot == 'evening');
    final key = '${slot}Minute';
    final minute = _draft.number(key, fallback).clamp(0, 1439);
    final colors = Theme.of(context).colorScheme;
    final controls = Row(mainAxisSize: MainAxisSize.min, children: [
      TextButton(
          style: TextButton.styleFrom(
              backgroundColor: colors.primary.withValues(alpha: .08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size(64, 32),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          onPressed: enabled && !_saving
              ? () => setState(
                  () => _editingTime = _editingTime == key ? null : key)
              : null,
          child: Text(
              '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}')),
      Switch.adaptive(
          value: enabled, onChanged: _saving ? null : (v) => _set(slot, v)),
    ]);
    return Column(children: [
      LayoutBuilder(builder: (context, constraints) {
        final label = Text(title,
            style:
                const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700));
        if (constraints.maxWidth < 290 ||
            MediaQuery.textScalerOf(context).scale(14.5) > 19) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                Align(alignment: Alignment.centerRight, child: controls)
              ]);
        }
        return Row(children: [Expanded(child: label), controls]);
      }),
      _PreservedReveal(
          visible: enabled && _editingTime == key,
          child: SizedBox(
            height: 160,
            width: double.infinity,
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: CupertinoTimerPicker(
                    key: ValueKey(key),
                    mode: CupertinoTimerPickerMode.hm,
                    initialTimerDuration: Duration(minutes: minute),
                    onTimerDurationChanged: (duration) =>
                        _set(key, duration.inMinutes))),
          )),
    ]);
  }

  Widget _weekdays() => LayoutBuilder(builder: (context, constraints) {
        final colors = Theme.of(context).colorScheme;
        final diameter = math.min(36.0, constraints.maxWidth / 7 - 3);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final selected = _draft.weekdays.contains(i + 1);
                final label = i == 6 ? 'CN' : 'T${i + 2}';
                return Semantics(
                  button: true,
                  selected: selected,
                  label: i == 6 ? 'Chủ nhật' : 'Thứ ${i + 2}',
                  child: SizedBox(
                    width: constraints.maxWidth / 7,
                    height: 44,
                    child: Center(
                        child: InkResponse(
                      onTap: _saving
                          ? null
                          : () {
                              final days = [..._draft.weekdays];
                              if (selected && days.length == 1) {
                                AppFeedback.showInfo(context,
                                    'Giữ ít nhất một ngày nhắc, hoặc tắt lời nhắc.');
                                return;
                              }
                              HapticFeedback.selectionClick();
                              selected ? days.remove(i + 1) : days.add(i + 1);
                              _set('weekdays', days);
                            },
                      child: Container(
                        width: diameter,
                        height: diameter,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? colors.primary
                                : colors.onSurface.withValues(alpha: .05)),
                        alignment: Alignment.center,
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? colors.onPrimary
                                        : colors.onSurfaceVariant))),
                      ),
                    )),
                  ),
                );
              })),
          const SizedBox(height: 4),
          Text('Ngày áp dụng cho lời nhắc cuối ngày và buổi trưa.',
              style: TextStyle(
                  fontSize: 11, height: 1.4, color: colors.onSurfaceVariant)),
        ]);
      });
  Widget _permissionBanner() {
    final colors = Theme.of(context).colorScheme;
    final supported = Platform.isAndroid || Platform.isIOS;
    final complete = _enabled == true && _exact == true;
    final message = !supported
        ? 'Lời nhắc hệ thống được hỗ trợ trên Android và iOS.'
        : _permissionError ??
            (_enabled == null
                ? 'Đang kiểm tra quyền thông báo…'
                : complete
                    ? 'Đã cho phép thông báo và lịch nhắc.'
                    : _enabled == true
                        ? 'Thông báo đã bật. Cho phép nhắc đúng giờ để lịch nhắc chính xác hơn.'
                        : 'Bật thông báo để nhận lời nhắc ngoài ứng dụng.');
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: colors.primary.withValues(alpha: .16), width: .8)),
        child: Row(children: [
          Icon(
              complete
                  ? Icons.check_circle_outline_rounded
                  : Icons.notifications_none_rounded,
              color: colors.primary,
              size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, height: 1.4))),
          if (supported &&
              !complete &&
              (_enabled != null || _permissionError != null)) ...[
            const SizedBox(width: 8),
            TextButton(
                onPressed: _requesting ? null : _requestPermission,
                child: Text(_requesting ? 'Đang mở…' : 'Cấp quyền')),
          ],
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;
    final height = math.max(
        0.0,
        math.min(
            media.size.height * .85,
            media.size.height -
                media.padding.top -
                18 -
                media.viewInsets.bottom));
    return SizedBox(
        height: height,
        child: Material(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
                    child: Row(children: [
                      const Expanded(
                          child: Text('Cài đặt nhắc nhở',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800))),
                      IconButton(
                          tooltip: 'Đóng',
                          onPressed: _saving ? null : _close,
                          style: IconButton.styleFrom(
                              backgroundColor:
                                  colors.onSurface.withValues(alpha: .05)),
                          icon: const Icon(Icons.close_rounded, size: 18)),
                    ]))),
            Expanded(
                child: ListView(
                    controller: widget.controller,
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                  _permissionBanner(),
                  const SizedBox(height: 14),
                  _card('GHI CHÉP HẰNG NGÀY', [
                    _rhythm('evening', 'Điểm lại cuối ngày', 1290),
                    if (_draft.flag('evening') && ref.watch(dayCutoffProvider).eveningWarning(_draft.number('eveningMinute', 1290)) != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Text(ref.watch(dayCutoffProvider).eveningWarning(_draft.number('eveningMinute', 1290))!,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    _PreservedReveal(
                        visible: _draft.flag('evening'),
                        child: _toggle(
                            'onlyEmpty', 'Chỉ nhắc khi chưa có ghi chép',
                            fallback: false,
                            subtitle:
                                'Tắt để luôn nhắc kiểm tra vào giờ đã chọn.')),
                    const Divider(height: 20, thickness: .5),
                    _rhythm('midday', 'Điểm lại buổi trưa', 750),
                    _PreservedReveal(
                        visible: _draft.flag('evening') ||
                            _draft.flag('midday', false),
                        child: _weekdays()),
                  ]),
                  const SizedBox(height: 14),
                  _card('THEO DÕI CHI TIÊU', [
                    _toggle('budget80', 'Danh mục đạt 80% ngân sách'),
                    _toggle('budget100', 'Danh mục dùng hết ngân sách'),
                    _toggle('dailyLimit', 'Dùng hết khoản chi an toàn hôm nay'),
                  ]),
                  const SizedBox(height: 14),
                  _card('KHOẢN HẸN VÀ BẢO MẬT', [
                    _toggle('debts', 'Nhắc khoản vay đến hẹn'),
                    _PreservedReveal(
                        visible: _draft.flag('debts'),
                        child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Column(children: [
                              _toggle('debtBefore', 'Trước ngày hẹn một ngày',
                                  subtitle: '08:30 sáng.'),
                              _toggle('debtOnDay', 'Đúng ngày hẹn',
                                  subtitle: '08:30 sáng.'),
                            ]))),
                    const Divider(height: 20, thickness: .5),
                    _toggle('digest', 'Tổng kết tuần',
                        subtitle: 'Chủ nhật lúc 20:00.'),
                    const Divider(height: 20, thickness: .5),
                    _toggle('private', 'Ẩn thông tin trong thông báo hệ thống',
                        subtitle:
                            'Không hiện số tiền hoặc tên đối tác ngoài ứng dụng, kể cả trên màn hình khóa.'),
                  ]),
                ])),
            Container(
              padding:
                  EdgeInsets.fromLTRB(20, 10, 20, media.padding.bottom + 16),
              decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: .96),
                  border: Border(
                      top: BorderSide(
                          color: colors.outlineVariant.withValues(alpha: .5),
                          width: .5))),
              child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    child: Text(_saving ? 'Đang lưu…' : 'Lưu cài đặt'),
                  )),
            ),
          ]),
        ));
  }
}

class _PreservedReveal extends StatefulWidget {
  final bool visible;
  final Widget child;
  const _PreservedReveal({required this.visible, required this.child});
  @override
  State<_PreservedReveal> createState() => _PreservedRevealState();
}

class _PreservedRevealState extends State<_PreservedReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AppAnimationPolicy.createController(
          vsync: this,
          duration: const Duration(milliseconds: 180),
          debugLabel: 'NotificationSettings.expand')
        ..value = widget.visible ? 1 : 0;
  late final CurvedAnimation _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  @override
  void didUpdateWidget(covariant _PreservedReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      widget.visible ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
      sizeFactor: _curve,
      alignment: Alignment.topCenter,
      child: FadeTransition(
          opacity: _curve,
          child: IgnorePointer(
              ignoring: !widget.visible,
              child: ExcludeSemantics(
                  excluding: !widget.visible, child: widget.child))));
}
