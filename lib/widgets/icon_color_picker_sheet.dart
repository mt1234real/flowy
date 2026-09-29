import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../theme/app_icons.dart';

class IconColorResult {
  const IconColorResult(
      {required this.iconData,
      required this.iconName,
      required this.color,
      required this.hexColor});
  final IconData iconData;
  final String iconName, hexColor;
  final Color color;
}

class IconColorPickerSheet extends StatefulWidget {
  const IconColorPickerSheet(
      {super.key,
      this.initialIconName,
      this.initialHexColor,
      this.title = 'Chọn biểu tượng',
      this.confirmLabel = 'Áp dụng',
      this.scrollController});
  final String? initialIconName, initialHexColor;
  final String title, confirmLabel;
  final ScrollController? scrollController;

  static Future<IconColorResult?> show(
    BuildContext context, {
    String? initialIconName,
    String? initialHexColor,
    String title = 'Chọn biểu tượng',
    String confirmLabel = 'Áp dụng',
  }) =>
      AppAnimationPolicy.showFluidSheet<IconColorResult>(
          context: context,
          mode: FluidSheetMode.scrollable,
          enableBlur:
              context.getInheritedWidgetOfExactType<FluidSheetScope>() == null,
          backgroundColor: Colors.transparent,
          builder: (_, controller) => IconColorPickerSheet(
              initialIconName: initialIconName,
              initialHexColor: initialHexColor,
              title: title,
              confirmLabel: confirmLabel,
              scrollController: controller));

  @override
  State<IconColorPickerSheet> createState() => _IconColorPickerSheetState();
}

class _IconColorPickerSheetState extends State<IconColorPickerSheet> {
  static const List<Map<String, dynamic>> _colorSwatches = [
    {'name': 'Emerald', 'hex': '#10B981', 'color': Color(0xFF10B981)},
    {'name': 'Amber', 'hex': '#F59E0B', 'color': Color(0xFFF59E0B)},
    {'name': 'Sky Blue', 'hex': '#0EA5E9', 'color': Color(0xFF0EA5E9)},
    {'name': 'Sakura Rose', 'hex': '#EC4899', 'color': Color(0xFFEC4899)},
    {'name': 'Indigo', 'hex': '#6366F1', 'color': Color(0xFF6366F1)},
    {'name': 'Violet', 'hex': '#8B5CF6', 'color': Color(0xFF8B5CF6)},
    {'name': 'Coral', 'hex': '#F43F5E', 'color': Color(0xFFF43F5E)},
    {'name': 'Teal', 'hex': '#14B8A6', 'color': Color(0xFF14B8A6)},
    {'name': 'Crimson', 'hex': '#EF4444', 'color': Color(0xFFEF4444)},
    {'name': 'Gold', 'hex': '#EAB308', 'color': Color(0xFFEAB308)},
    {'name': 'Mint', 'hex': '#34D399', 'color': Color(0xFF34D399)},
    {'name': 'Slate', 'hex': '#64748B', 'color': Color(0xFF64748B)},
  ];

  late AppIconItem _selectedIcon;
  late Color _selectedColor;
  late String _selectedHex;
  String _topic = 'Tất cả';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedColor = AppIcons.parseColor(widget.initialHexColor);
    _selectedHex =
        '#${_selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    final original = widget.initialIconName;
    _selectedIcon = AppIcons.item(original) ??
        AppIconItem(
            key: original?.isNotEmpty == true ? original! : 'category',
            label: 'Biểu tượng hiện tại',
            icon: AppIcons.resolve(original),
            topic: 'Tất cả',
            keywords: const []);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {});
    final scroll = widget.scrollController;
    if (scroll != null && scroll.hasClients) scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final view = View.of(context);
    final top = view.padding.top / view.devicePixelRatio;
    final height = (media.size.height * .88).clamp(
        0.0,
        (media.size.height - top - 12 - media.viewInsets.bottom)
            .clamp(0.0, media.size.height));
    final compact = height < 440;
    final contentColor = AppIcons.foreground(_selectedColor);
    final filtered = AppIcons.search(_search.text, topic: _topic);
    final subtle = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    return AppFeedbackDismissRegion(
        child: Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
          height: height,
          child: Material(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
                top: false,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                      child: Row(children: [
                        Expanded(
                            child: Text(widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800))),
                        IconButton(
                            tooltip: 'Đóng',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 20)),
                      ])),
                  Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      padding: EdgeInsets.all(compact ? 8 : 12),
                      decoration: BoxDecoration(
                          color: subtle,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                              width: .8)),
                      child: Row(children: [
                        Container(
                            width: compact ? 36 : 58,
                            height: compact ? 36 : 58,
                            decoration: BoxDecoration(
                                color: _selectedColor,
                                borderRadius:
                                    BorderRadius.circular(compact ? 12 : 18),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          _selectedColor.withValues(alpha: .22),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3))
                                ]),
                            child: Icon(_selectedIcon.icon,
                                color: contentColor, size: compact ? 24 : 30)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(_selectedIcon.label,
                                  maxLines: compact ? 1 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800)),
                              if (!compact)
                                Text('$_selectedHex • ${_selectedIcon.topic}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: theme
                                            .colorScheme.onSurfaceVariant)),
                            ])),
                      ])),
                  Expanded(
                      child: CustomScrollView(
                          controller: widget.scrollController,
                          physics: const ClampingScrollPhysics(),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          slivers: [
                        SliverToBoxAdapter(
                            child: Column(children: [
                          SizedBox(
                              height: 48,
                              child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 2),
                                  itemCount: _colorSwatches.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final swatch = _colorSwatches[index];
                                    final color = swatch['color'] as Color;
                                    final active =
                                        _selectedHex == swatch['hex'];
                                    return Semantics(
                                        button: true,
                                        selected: active,
                                        label: swatch['name'] as String,
                                        child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setState(() {
                                                _selectedColor = color;
                                                _selectedHex =
                                                    swatch['hex'] as String;
                                              });
                                            },
                                            child: Container(
                                                width: 44,
                                                decoration: BoxDecoration(
                                                    color: color,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    border: active
                                                        ? Border.all(
                                                            color: AppIcons
                                                                .foreground(
                                                                    color),
                                                            width: 2.5)
                                                        : null),
                                                child: active
                                                    ? Icon(
                                                        Icons.check_rounded,
                                                        color:
                                                            AppIcons.foreground(
                                                                color),
                                                        size: 20)
                                                    : null)));
                                  })),
                          Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                              child: TextField(
                                  controller: _search,
                                  onChanged: (_) => _refresh(),
                                  style: const TextStyle(fontSize: 13),
                                  decoration: InputDecoration(
                                      hintText:
                                          'Tìm biểu tượng: cơm, xe, cà phê…',
                                      hintStyle: const TextStyle(fontSize: 12),
                                      prefixIcon: const Icon(
                                          Icons.search_rounded,
                                          size: 20),
                                      suffixIcon: _search.text.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Xóa tìm kiếm',
                                              icon: const Icon(
                                                  Icons.close_rounded,
                                                  size: 18),
                                              onPressed: () {
                                                _search.clear();
                                                _refresh();
                                              }),
                                      filled: true,
                                      fillColor: subtle,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          borderSide: BorderSide.none)))),
                          SizedBox(
                              height:
                                  MediaQuery.textScalerOf(context).scale(11) +
                                      25,
                              child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: AppIcons.topics.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final topic = AppIcons.topics[index];
                                    final active = _topic == topic;
                                    return Semantics(
                                        button: true,
                                        selected: active,
                                        child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              _topic = topic;
                                              _refresh();
                                            },
                                            child: Container(
                                                alignment: Alignment.center,
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 12),
                                                decoration: BoxDecoration(
                                                    color: active
                                                        ? _selectedColor.withValues(
                                                            alpha: .18)
                                                        : subtle,
                                                    borderRadius: BorderRadius.circular(
                                                        12),
                                                    border: Border.all(
                                                        color: active
                                                            ? _selectedColor
                                                            : Colors
                                                                .transparent,
                                                        width: 1.2)),
                                                child: Text(topic,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: active
                                                            ? FontWeight.w800
                                                            : FontWeight.w500,
                                                        color: theme.colorScheme.onSurface)))));
                                  })),
                          const SizedBox(height: 10),
                        ])),
                        if (filtered.isEmpty)
                          const SliverToBoxAdapter(
                              child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                      'Không tìm thấy biểu tượng. Thử từ khóa khác nhé.',
                                      textAlign: TextAlign.center)))
                        else
                          SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              sliver: SliverLayoutBuilder(
                                  builder: (context, constraints) {
                                final columns =
                                    (constraints.crossAxisExtent / 58)
                                        .floor()
                                        .clamp(3, 5);
                                return SliverGrid(
                                    delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                      final item = filtered[index];
                                      final active =
                                          _selectedIcon.key == item.key;
                                      return Semantics(
                                          button: true,
                                          selected: active,
                                          label: item.label,
                                          child: Tooltip(
                                              message: item.label,
                                              child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  onTap: () {
                                                    HapticFeedback
                                                        .selectionClick();
                                                    setState(() =>
                                                        _selectedIcon = item);
                                                  },
                                                  child: Container(
                                                      decoration: BoxDecoration(
                                                          color: active
                                                              ? _selectedColor.withValues(
                                                                  alpha: .18)
                                                              : subtle,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  14),
                                                          border: Border.all(
                                                              color: active
                                                                  ? _selectedColor
                                                                  : Colors
                                                                      .transparent,
                                                              width: 1.8)),
                                                      child: Icon(item.icon,
                                                          size: 24,
                                                          color: active
                                                              ? Color.alphaBlend(
                                                                  _selectedColor.withValues(
                                                                      alpha: .65),
                                                                  theme.colorScheme.onSurface)
                                                              : theme.colorScheme.onSurfaceVariant)))));
                                    }, childCount: filtered.length),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: columns,
                                            crossAxisSpacing: 10,
                                            mainAxisSpacing: 10));
                              })),
                      ])),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  backgroundColor: _selectedColor,
                                  foregroundColor: contentColor,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16))),
                              onPressed: () {
                                if (ModalRoute.of(context)?.isCurrent != true) {
                                  return;
                                }
                                HapticFeedback.mediumImpact();
                                Navigator.pop(
                                    context,
                                    IconColorResult(
                                        iconData: _selectedIcon.icon,
                                        iconName: _selectedIcon.key,
                                        color: _selectedColor,
                                        hexColor: _selectedHex));
                              },
                              child: Text(widget.confirmLabel,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800))))),
                ])),
          )),
    ));
  }
}
