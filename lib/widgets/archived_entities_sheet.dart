import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../theme/app_icons.dart';

class _ArchivedItem {
  final String id, name;
  final IconData icon;
  final Color color;
  final DateTime? archivedAt;
  const _ArchivedItem(this.id, this.name, this.icon, this.color,
      [this.archivedAt]);
}

Color _archiveColor(String value) {
  final hex = value.replaceFirst('#', '');
  final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
  return parsed == null ? Colors.teal : Color(parsed);
}

Future<void> showArchivedEntities(
    BuildContext context, AppDatabase db, String type) async {
  final title = switch (type) {
    'category' => 'Danh mục đã lưu trữ',
    'contact' => 'Đối tác nợ đã lưu trữ',
    'wallet' => 'Ví và nguồn tiền đã lưu trữ',
    _ => null,
  };
  if (title == null) return;
  try {
    late final Stream<List<_ArchivedItem>> items;
    if (type == 'wallet') {
      items = (db.select(db.wallets)..where((w) => w.isArchived.equals(true)))
          .watch()
          .map((rows) => rows
              .map((w) => _ArchivedItem(
                  w.id, w.name, AppIcons.resolve(w.icon), _archiveColor(w.color)))
              .toList());
    } else {
      final details = <String, _ArchivedItem>{};
      if (type == 'category') {
        for (final c in await db.select(db.categories).get()) {
          details[c.id] = _ArchivedItem(
              c.id, c.name, AppIcons.resolve(c.icon), _archiveColor(c.color));
        }
      } else {
        for (final c in await db.select(db.debtContacts).get()) {
          final parts = (c.avatarUrl ?? '').split('|');
          final color =
              parts.where((p) => p.startsWith('#')).firstOrNull ?? '#10B981';
          details[c.id] = _ArchivedItem(
              c.id, c.name,
              (c.avatarUrl ?? '').startsWith('icon:')
                  ? AppIcons.resolve(parts.first.substring(5))
                  : Icons.person_rounded,
              _archiveColor(color));
        }
      }
      items = db.watchEntityArchives(type).map((rows) {
        final sorted = [...rows]
          ..sort((a, b) => b.archivedAt.compareTo(a.archivedAt));
        return sorted.map((a) {
          final detail = details[a.entityId];
          return _ArchivedItem(
              a.entityId,
              detail?.name ?? 'Mục đã lưu trữ',
              detail?.icon ?? Icons.inventory_2_outlined,
              detail?.color ?? Colors.teal,
              a.archivedAt);
        }).toList();
      });
    }
    if (!context.mounted) return;
    await AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.scrollable,
      builder: (context, controller) => _ArchiveSheet(
        title: title,
        type: type,
        items: items,
        controller: controller!,
        restore: (id) async {
          if (type == 'wallet') {
            await (db.update(db.wallets)..where((w) => w.id.equals(id))).write(
                WalletsCompanion(
                    isArchived: const Value(false),
                    updatedAt: Value(DateTime.now())));
          } else {
            await db.restoreArchivedEntity(type, id);
          }
        },
      ),
    );
  } catch (_) {
    if (context.mounted) {
      AppFeedback.showError(
          context, 'Chưa mở được kho lưu trữ. Vui lòng thử lại.');
    }
  }
}

class _ArchiveSheet extends StatelessWidget {
  final String title, type;
  final Stream<List<_ArchivedItem>> items;
  final ScrollController controller;
  final Future<void> Function(String) restore;
  const _ArchiveSheet(
      {required this.title,
      required this.type,
      required this.items,
      required this.controller,
      required this.restore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final feedbackContext = context;
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .65),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .16 : .06),
                blurRadius: 24,
                offset: const Offset(0, -4))
          ],
        ),
        child: Material(
          color: colors.surface.withValues(alpha: .92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
              top: false,
              child: StreamBuilder<List<_ArchivedItem>>(
                stream: items,
                builder: (context, snapshot) {
                  final rows = snapshot.data ?? const <_ArchivedItem>[];
                  return ListView.separated(
                    controller: controller,
                    physics: const ClampingScrollPhysics(),
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    itemCount: 1 + (rows.isEmpty ? 1 : rows.length),
                    separatorBuilder: (_, index) =>
                        SizedBox(height: index == 0 ? 16 : 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                                child: Container(
                                    width: 36,
                                    height: 4,
                                    decoration: BoxDecoration(
                                        color: colors.onSurfaceVariant
                                            .withValues(alpha: .25),
                                        borderRadius:
                                            BorderRadius.circular(2)))),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(
                                  child: Text(title,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -.3))),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Đóng',
                                onPressed: () {
                                  if (ModalRoute.of(context)?.isCurrent ==
                                      true) {
                                    Navigator.of(context).pop();
                                  }
                                },
                                style: IconButton.styleFrom(
                                    backgroundColor:
                                        colors.onSurface.withValues(alpha: .05),
                                    minimumSize: const Size(36, 36),
                                    padding: const EdgeInsets.all(6)),
                                icon: const Icon(Icons.close_rounded, size: 20),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            Text(
                                'Các mục được tạm ẩn. Lịch sử giao dịch và báo cáo vẫn được giữ nguyên.',
                                style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: colors.onSurfaceVariant)),
                          ],
                        );
                      }
                      if (snapshot.hasError) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                              'Chưa tải được danh sách lưu trữ. Vui lòng mở lại.'),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()));
                      }
                      if (rows.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(children: [
                            Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                    color:
                                        colors.primary.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(20)),
                                child: Icon(Icons.inventory_2_outlined,
                                    size: 28,
                                    color:
                                        colors.primary.withValues(alpha: .7))),
                            const SizedBox(height: 14),
                            const Text('Kho lưu trữ đang trống',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(
                                switch (type) {
                                  'category' =>
                                    'Không có danh mục nào đang được lưu trữ.',
                                  'contact' =>
                                    'Không có đối tác nào đang được lưu trữ.',
                                  _ => 'Không có ví nào đang được lưu trữ.',
                                },
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: colors.onSurfaceVariant)),
                          ]),
                        );
                      }
                      final item = rows[index - 1];
                      return _ArchivedEntityCard(
                          key: ValueKey(item.id),
                          item: item,
                          restore: restore,
                          feedbackContext: feedbackContext);
                    },
                  );
                },
              )),
        ),
      ),
    );
  }
}

class _ArchivedEntityCard extends StatefulWidget {
  final _ArchivedItem item;
  final BuildContext feedbackContext;
  final Future<void> Function(String) restore;
  const _ArchivedEntityCard(
      {super.key,
      required this.item,
      required this.restore,
      required this.feedbackContext});
  @override
  State<_ArchivedEntityCard> createState() => _ArchivedEntityCardState();
}

class _ArchivedEntityCardState extends State<_ArchivedEntityCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      debugLabel: 'Archive.restore');
  late final Animation<double> _visibility = Tween<double>(begin: 1, end: 0)
      .animate(CurvedAnimation(parent: _motion, curve: Curves.easeInOutCubic));
  bool _restoring = false;

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    HapticFeedback.mediumImpact();
    final name = widget.item.name;
    // Keep a sheet-level context: the row is disposed when the stream removes it.
    final sheetContext = widget.feedbackContext;
    try {
      await _motion.forward().orCancel;
      if (!mounted) return;
      await widget.restore(widget.item.id);
      if (sheetContext.mounted) {
        AppFeedback.showSuccess(sheetContext, 'Đã khôi phục “$name”.');
      }
    } on TickerCanceled {
      // Closing the sheet before the animation completes cancels this intent.
    } catch (_) {
      if (!mounted) return;
      try {
        await _motion.reverse().orCancel;
      } on TickerCanceled {
        return;
      }
      if (!mounted) return;
      setState(() => _restoring = false);
      AppFeedback.showError(
          context, 'Chưa khôi phục được mục này. Vui lòng thử lại.');
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final item = widget.item;
    final button = FilledButton.icon(
      onPressed: _restoring ? null : _restore,
      style: FilledButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.compact,
          backgroundColor: colors.primary.withValues(alpha: .12),
          foregroundColor: colors.primary,
          side: BorderSide(
              color: colors.primary.withValues(alpha: .3), width: .8),
          shape: const StadiumBorder(),
          textStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      icon: const Icon(Icons.settings_backup_restore_rounded, size: 14),
      label: const Text('Khôi phục'),
    );
    return SizeTransition(
      sizeFactor: _visibility,
      alignment: Alignment.topCenter,
      child: FadeTransition(
          opacity: _visibility,
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, child) => Transform.translate(
                offset: Offset(12 * _motion.value, 0), child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: dark ? .06 : .85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: .5),
                      width: .8)),
              child: LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(12) > 16;
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: item.color.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(item.icon,
                              size: 20,
                              color: Color.lerp(item.color, colors.onSurface,
                                  dark ? .25 : .2))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(item.name,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                                item.archivedAt == null
                                    ? 'Đang tạm ẩn'
                                    : 'Đã lưu trữ ${DateFormat('HH:mm • dd/MM').format(item.archivedAt!)}',
                                style: TextStyle(
                                    fontSize: 11,
                                    height: 1.4,
                                    color: colors.onSurfaceVariant)),
                            if (compact)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: button),
                          ])),
                      if (!compact) ...[const SizedBox(width: 8), button],
                    ]);
              }),
            ),
          )),
    );
  }
}
