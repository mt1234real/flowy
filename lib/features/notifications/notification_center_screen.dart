import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/database.dart';
import '../../theme/app_theme.dart';
import '../../core/animation/app_animation_policy.dart';
import '../../core/feedback/app_feedback.dart';
import '../../widgets/sliding_segmented_bar.dart';
import '../../widgets/preserved_sleek_dismissible.dart';
import 'notification_preferences.dart';
import 'notification_routes.dart';
import 'notification_service.dart';
import 'notification_settings_sheet.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
        message: count == 0 ? 'Thông báo' : '$count thông báo chưa đọc',
        child: Semantics(
            button: true,
            label: 'Thông báo, $count chưa đọc',
            child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Navigator.of(context).push(
                    PreservedMaterialPageRoute(
                        builder: (_) => const NotificationCenterScreen())),
                child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: dark ? .08 : .85),
                        borderRadius: BorderRadius.circular(10)),
                    child: Stack(children: [
                      const Center(
                          child:
                              Icon(Icons.notifications_none_rounded, size: 20)),
                      if (count > 0)
                        Positioned(
                            top: 3,
                            right: 3,
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                    color: AppTokens.expense,
                                    borderRadius: BorderRadius.circular(999)),
                                child: Text(count > 9 ? '9+' : '$count',
                                    style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white))))
                    ])))));
  }
}

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});
  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  String _filter = 'all';
  bool _opening = false;
  String _group(DateTime date) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    return days == 0
        ? 'Hôm nay'
        : days == 1
            ? 'Hôm qua'
            : DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _open(AppNotification item) async {
    if (_opening) return;
    _opening = true;
    try {
      await openNotification(context, ref.read(databaseProvider), item);
    } catch (_) {
      if (mounted) {
        AppFeedback.showError(
            context, 'Chưa mở được nội dung. Vui lòng thử lại.');
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items =
        ref.watch(notificationListProvider(_filter == 'all' ? null : _filter));
    final theme = Theme.of(context);
    final db = ref.read(databaseProvider);
    return Scaffold(
        appBar: AppBar(
            title: const Text('Thông báo & Nhắc nhở',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            actions: [
              PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'read') await db.markAllAsRead();
                    if (value == 'settings' && context.mounted) {
                      await NotificationSettingsSheet.show(context);
                    }
                    if (value == 'purge') await db.purgeOldNotifications();
                  },
                  itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'read',
                            child: Text('Đánh dấu đã đọc tất cả')),
                        PopupMenuItem(
                            value: 'settings', child: Text('Cài đặt nhắc nhở')),
                        PopupMenuItem(
                            value: 'purge',
                            child: Text('Xóa thông báo quá 30 ngày'))
                      ])
            ]),
        body: SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: SlidingSegmentedBar<String>(
                  height: 36,
                  fontSize: 11,
                  selectedValue: _filter,
                  onValueChanged: (v) => setState(() => _filter = v),
                  items: const [
                    SlidingSegmentedItem(value: 'all', label: 'Tất cả'),
                    SlidingSegmentedItem(value: 'budget', label: 'Hạn mức'),
                    SlidingSegmentedItem(value: 'debt', label: 'Vay nợ'),
                    SlidingSegmentedItem(value: 'reminder', label: 'Nhắc nhở')
                  ])),
          FutureBuilder<bool>(
              future: NotificationPlatform.instance.enabled(),
              builder: (context, state) => state.data == false
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton(
                          onPressed: () =>
                              NotificationSettingsSheet.show(context),
                          child: const Text(
                              'Bật thông báo trên thiết bị để nhận lời nhắc khi đóng app')))
                  : const SizedBox.shrink()),
          Expanded(
              child: items.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      const Center(child: Text('Chưa tải được thông báo.')),
                  data: (list) {
                    if (list.isEmpty) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                  'Chưa có thông báo\nCác lời nhắc và cập nhật sẽ xuất hiện ở đây.',
                                  textAlign: TextAlign.center)));
                    }
                    return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final item = list[index];
                          final heading = _group(item.createdAt);
                          final icon = switch (item.type) {
                            'budget' => Icons.pie_chart_rounded,
                            'debt' => Icons.handshake_rounded,
                            'system' => Icons.cloud_done_rounded,
                            _ => Icons.spa_rounded
                          };
                          final color = switch (item.type) {
                            'budget' => Colors.deepOrange,
                            'debt' => Colors.teal,
                            'system' => Colors.blue,
                            _ => Colors.indigo
                          };
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (index == 0 ||
                                    _group(list[index - 1].createdAt) !=
                                        heading)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Text(heading,
                                          style: theme.textTheme.labelLarge)),
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: PreservedSleekDismissible(
                                        key: ValueKey(item.id),
                                        onDismissed: () async {
                                          await db.deleteNotification(item.id);
                                          await NotificationPlatform.instance
                                              .cancel(item.id);
                                          if (context.mounted) {
                                            AppFeedback.showUndo(context,
                                                message: 'Đã xóa thông báo',
                                                onUndo: () =>
                                                    db.restoreNotification(
                                                        item.id));
                                          }
                                        },
                                        child: Material(
                                            color: theme.colorScheme.surface.withValues(
                                                alpha: item.isRead ? .70 : .95),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                onTap: () => _open(item),
                                                child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            14),
                                                    decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                20),
                                                        border: Border.all(
                                                            color: theme
                                                                .colorScheme
                                                                .primary
                                                                .withValues(
                                                                    alpha: item
                                                                            .isRead
                                                                        ? .06
                                                                        : .18))),
                                                    child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Container(
                                                              width: 40,
                                                              height: 40,
                                                              decoration: BoxDecoration(
                                                                  color: color
                                                                      .withValues(
                                                                          alpha:
                                                                              .12),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              12)),
                                                              child: Icon(icon,
                                                                  size: 20,
                                                                  color:
                                                                      color)),
                                                          const SizedBox(
                                                              width: 10),
                                                          Expanded(
                                                              child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                Row(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Expanded(
                                                                          child: Text(
                                                                              item.title,
                                                                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: item.isRead ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface))),
                                                                      const SizedBox(
                                                                          width:
                                                                              6),
                                                                      Text(
                                                                          DateFormat('HH:mm').format(item
                                                                              .createdAt),
                                                                          style: TextStyle(
                                                                              fontSize: 11,
                                                                              color: theme.colorScheme.onSurfaceVariant)),
                                                                      SizedBox(
                                                                          width:
                                                                              28,
                                                                          height:
                                                                              28,
                                                                          child:
                                                                              PopupMenuButton<String>(
                                                                            padding:
                                                                                EdgeInsets.zero,
                                                                            tooltip:
                                                                                'Tùy chọn thông báo',
                                                                            icon:
                                                                                const Icon(Icons.more_horiz_rounded, size: 18),
                                                                            onSelected: (_) =>
                                                                                db.markAsRead(item.id, isRead: !item.isRead),
                                                                            itemBuilder: (_) =>
                                                                                [
                                                                              PopupMenuItem(value: 'read', child: Text(item.isRead ? 'Đánh dấu chưa đọc' : 'Đánh dấu đã đọc'))
                                                                            ],
                                                                          )),
                                                                      if (!item
                                                                          .isRead)
                                                                        Padding(
                                                                            padding:
                                                                                const EdgeInsets.only(left: 4, top: 4),
                                                                            child: Container(width: 5, height: 5, decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle)))
                                                                    ]),
                                                                const SizedBox(
                                                                    height: 6),
                                                                Text(item.body,
                                                                    maxLines: 2,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        color: theme
                                                                            .colorScheme
                                                                            .onSurfaceVariant)),
                                                                if (item.payload !=
                                                                    null)
                                                                  Padding(
                                                                      padding: const EdgeInsets
                                                                          .only(
                                                                          top:
                                                                              8),
                                                                      child: Text(
                                                                          item.type == 'budget'
                                                                              ? 'Xem hạn mức ›'
                                                                              : item.type == 'debt'
                                                                                  ? 'Đối soát khoản vay ›'
                                                                                  : item.type == 'reminder'
                                                                                      ? 'Ghi giao dịch ›'
                                                                                      : 'Xem chi tiết ›',
                                                                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: theme.colorScheme.primary))),
                                                              ])),
                                                        ])))))),
                              ]);
                        });
                  })),
        ])));
  }
}
