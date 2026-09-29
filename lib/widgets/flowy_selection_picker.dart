import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/animation/app_animation_policy.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
import 'currency_text.dart';
import '../theme/app_icons.dart';

/// A single Fluid surface for value selection. Action menus remain separate.
Future<Set<T>?> showFlowyPicker<T>({
  required BuildContext context,
  required String title,
  required List<DropdownMenuItem<T>> items,
  Set<T> selected = const {},
  Stream<List<DropdownMenuItem<T>>>? itemsStream,
  bool multiple = false,
}) {
  if (ModalRoute.of(context)?.isCurrent == false) return Future.value(null);
  FocusScope.of(context).unfocus();
  final nested =
      context.getInheritedWidgetOfExactType<FluidSheetScope>() != null;
  final draft = {...selected};
  var closing = false;
  HapticFeedback.selectionClick();
  return AppAnimationPolicy.showFluidSheet<Set<T>>(
    context: context,
    mode: FluidSheetMode.scrollable,
    enableBlur: !nested,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
    backgroundColor: Colors.transparent,
    builder: (sheetContext, scroll) => StatefulBuilder(builder: (ctx, update) {
      final theme = Theme.of(ctx);
      final accent = theme.colorScheme.primary;
      final dark = theme.brightness == Brightness.dark;
      void close(Set<T>? value) {
        if (closing || ModalRoute.of(ctx)?.isCurrent != true) return;
        closing = true;
        Navigator.of(ctx).pop(value);
      }

      return Material(
        color: theme.colorScheme.surface.withValues(alpha: .97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * .55),
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800))),
                      IconButton(
                          tooltip: 'Đóng',
                          onPressed: () => close(null),
                          icon: const Icon(Icons.close_rounded))
                    ]),
                    const SizedBox(height: 8),
                    Flexible(
                        child: StreamBuilder<List<DropdownMenuItem<T>>>(
                            stream: itemsStream,
                            initialData: items,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                        'Chưa tải được danh sách. Vui lòng mở lại.'));
                              }
                              final options = snapshot.data ?? items;
                              if (options.isEmpty) {
                                return const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('Chưa có lựa chọn phù hợp.'));
                              }
                              return ListView.separated(
                                  controller: scroll,
                                  shrinkWrap: true,
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: options.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final item = options[index];
                                    final active = draft.contains(item.value);
                                    return Semantics(
                                        selected: active,
                                        child: Material(
                                            elevation: active ? 1 : 0,
                                            shadowColor:
                                                accent.withValues(alpha: .15),
                                            color: active
                                                ? accent.withValues(alpha: .08)
                                                : (dark
                                                    ? theme.colorScheme
                                                        .surfaceContainer
                                                    : Colors.white),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                side: BorderSide(
                                                    color: accent.withValues(
                                                        alpha: active
                                                            ? 1
                                                            : dark
                                                                ? .25
                                                                : .18),
                                                    width: active ? 1.3 : .8)),
                                            child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                onTap: !item.enabled ||
                                                        item.value == null ||
                                                        closing
                                                    ? null
                                                    : () {
                                                        HapticFeedback
                                                            .selectionClick();
                                                        final value =
                                                            item.value as T;
                                                        update(() {
                                                          if (!multiple) {
                                                            draft.clear();
                                                          }
                                                          if (!draft
                                                              .add(value)) {
                                                            draft.remove(value);
                                                          }
                                                        });
                                                        if (!multiple) {
                                                          close({value});
                                                        }
                                                      },
                                                child: ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                            minHeight: 56),
                                                    child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 12,
                                                                vertical: 10),
                                                        child: Row(children: [
                                                          Expanded(
                                                              child:
                                                                  item.child),
                                                          const SizedBox(
                                                              width: 8),
                                                          Icon(
                                                              active
                                                                  ? Icons
                                                                      .check_circle_rounded
                                                                  : Icons
                                                                      .circle_outlined,
                                                              size: 20,
                                                              color: accent
                                                                  .withValues(
                                                                      alpha: active
                                                                          ? 1
                                                                          : .3))
                                                        ]))))));
                                  });
                            })),
                    if (multiple)
                      Row(children: [
                        TextButton(
                            onPressed: () => update(draft.clear),
                            child: const Text('Tất cả ví')),
                        const Spacer(),
                        FilledButton(
                            onPressed: () => close({...draft}),
                            child: const Text('Áp dụng'))
                      ]),
                  ])),
            )),
      );
    }),
  );
}

class FlowyDropdown<T> extends StatelessWidget {
  const FlowyDropdown(
      {super.key,
      this.value,
      this.initialValue,
      required this.items,
      required this.onChanged,
      this.title = 'Chọn mục',
      this.minHeight = 52,
      this.hint,
      this.icon,
      this.isExpanded = true,
      this.isDense = false,
      this.dropdownColor,
      this.borderRadius,
      this.decoration,
      this.itemsStream,
      this.style});
  final double minHeight;
  final T? value, initialValue;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final String title;
  final Widget? hint, icon;
  final bool isExpanded, isDense;
  final Color? dropdownColor;
  final BorderRadius? borderRadius;
  final InputDecoration? decoration;
  final TextStyle? style;
  final Stream<List<DropdownMenuItem<T>>>? itemsStream;
  @override
  Widget build(BuildContext context) {
    final current = value ?? initialValue;
    final choices = items ?? [];
    final match = choices.where((item) => item.value == current).firstOrNull;
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Material(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainer
            : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            side: BorderSide(color: accent.withValues(alpha: .22), width: .8)),
        child: InkWell(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            onTap: onChanged == null
                ? null
                : () async {
                    final result = await showFlowyPicker<T>(
                        context: context,
                        title: decoration?.labelText ?? title,
                        items: choices,
                        selected: current == null ? <T>{} : {current},
                        itemsStream: itemsStream);
                    if (context.mounted &&
                        result != null &&
                        result.isNotEmpty) {
                      onChanged?.call(result.first);
                    }
                  },
            child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(children: [
                      if (decoration?.prefixIcon != null) ...[
                        decoration!.prefixIcon!,
                        const SizedBox(width: 10)
                      ],
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            if (decoration?.labelText != null)
                              Text(decoration!.labelText!,
                                  style: theme.textTheme.labelSmall),
                            DefaultTextStyle.merge(
                                style: style ??
                                    const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                child: match?.child ?? hint ?? Text(title)),
                          ])),
                      const SizedBox(width: 8),
                      Icon(Icons.expand_more_rounded, size: 20, color: accent)
                    ])))));
  }
}

class FlowySelectionMenu<T> extends StatelessWidget {
  const FlowySelectionMenu(
      {super.key,
      this.tooltip,
      this.initialValue,
      required this.onSelected,
      required this.itemBuilder,
      this.child,
      this.icon});
  final String? tooltip;
  final T? initialValue;
  final ValueChanged<T> onSelected;
  final PopupMenuItemBuilder<T> itemBuilder;
  final Widget? child, icon;
  @override
  Widget build(BuildContext context) => InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        final choices = itemBuilder(context)
            .whereType<PopupMenuItem<T>>()
            .map((item) => DropdownMenuItem<T>(
                value: item.value,
                enabled: item.enabled,
                child: item.child ?? const SizedBox.shrink()))
            .toList();
        final result = await showFlowyPicker<T>(
            context: context,
            title: tooltip ?? 'Chọn mục',
            items: choices,
            selected: initialValue == null ? <T>{} : {initialValue as T});
        if (context.mounted && result != null && result.isNotEmpty) {
          onSelected(result.first);
        }
      },
      child: child ??
          Padding(
              padding: const EdgeInsets.all(12),
              child: icon ?? const Icon(Icons.expand_more_rounded)));
}

Widget walletPickerLabel(Wallet wallet) {
  final icon = AppIcons.resolve(wallet.icon);
  return LayoutBuilder(builder: (context, constraints) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final wide = constraints.maxWidth >= 280;
    final money = CurrencyText(
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
            .format(wallet.balance),
        respectPrivacy: false,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: wallet.balance < 0
                ? AppTokens.expense
                : theme.colorScheme.onSurfaceVariant));
    return Row(children: [
      Container(
          width: wide ? 36 : 32,
          height: wide ? 36 : 32,
          decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: accent, size: 19)),
      const SizedBox(width: 10),
      Expanded(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(wallet.name,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            if (wallet.isArchived)
              Text('Đã lưu trữ', style: theme.textTheme.labelSmall),
            if (!wide) ...[
              Text('Khả dụng', style: theme.textTheme.labelSmall),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: money)
            ],
          ])),
      if (wide) ...[
        const SizedBox(width: 10),
        Flexible(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
              Text('Khả dụng', style: theme.textTheme.labelSmall),
              FittedBox(fit: BoxFit.scaleDown, child: money),
            ]))
      ],
    ]);
  });
}

List<DropdownMenuItem<String>> walletPickerItems(List<Wallet> wallets) => [
      for (final wallet in wallets)
        DropdownMenuItem(value: wallet.id, child: walletPickerLabel(wallet)),
    ];
Future<String?> showFlowyWalletPicker(
    BuildContext context, AppDatabase db, List<Wallet> wallets,
    {required String title, String? selected}) async {
  final result = await showFlowyPicker<String>(
      context: context,
      title: title,
      items: walletPickerItems(wallets),
      selected: selected == null ? {} : {selected},
      itemsStream:
          db.watchAllWallets(includeArchived: false).map(walletPickerItems));
  return result?.firstOrNull;
}

class FlowyPickerTrigger extends StatelessWidget {
  const FlowyPickerTrigger(
      {super.key,
      required this.onTap,
      required this.child,
      this.minHeight = 52});
  final VoidCallback onTap;
  final double minHeight;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Material(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainer
            : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accent.withValues(alpha: .22), width: .8)),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(children: [
                      Expanded(child: child),
                      const SizedBox(width: 6),
                      Icon(Icons.expand_more_rounded, size: 18, color: accent)
                    ])))));
  }
}
