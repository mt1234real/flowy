import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

class CurrencyFontGallery extends ConsumerWidget {
  const CurrencyFontGallery({super.key});

  static const _captions = {
    kCurrencyFontFollowApp: 'Đồng bộ với giao diện',
    'Plus Jakarta Sans': 'Gọn gàng, hiện đại',
    'Be Vietnam Pro': 'Rõ nét, dễ đọc',
    'Nunito': 'Mềm mại, bo tròn',
    'Comfortaa': 'Tối giản, hình học',
    'Lora': 'Cổ điển, thanh lịch',
    'monospace': 'Đều cột, dễ đối chiếu',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(currencyFontProvider);
    final accent = ref.watch(accentPresetProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ink = isDark ? AppTokens.darkText : AppTokens.lightText;
    // Darker accent keeps the specimen legible on pale selected cards.
    final selectedInk = isDark ? accent.primary : accent.darkVariant;
    Widget card(String family) {
      final active = selected == family;
      final label = family == kCurrencyFontFollowApp
          ? 'Theo font ứng dụng'
          : family == 'monospace'
              ? 'Monospace'
              : family;
      return Semantics(
        button: true,
        selected: active,
        label: '$label. ${_captions[family]}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(currencyFontProvider.notifier).setFont(family);
            },
            child: Ink(
              decoration: BoxDecoration(
                color: active
                    ? null
                    : Colors.white.withValues(alpha: isDark ? .05 : .88),
                gradient: active
                    ? LinearGradient(colors: [
                        accent.primary.withValues(alpha: .10),
                        accent.primary.withValues(alpha: .08)
                      ])
                    : null,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: active
                        ? accent.primary
                        : (isDark
                            ? AppTokens.darkBorder
                            : AppTokens.lightBorder),
                    width: active ? 1.4 : .8),
                boxShadow: active
                    ? [
                        BoxShadow(
                            color: accent.primary.withValues(alpha: .08),
                            blurRadius: 8)
                      ]
                    : null,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 94),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Text(label,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: ink))),
                              const SizedBox(width: 4),
                              SizedBox(
                                  width: 14,
                                  height: 16,
                                  child: active
                                      ? Icon(Icons.check_circle_rounded,
                                          size: 14, color: accent.primary)
                                      : null),
                            ]),
                        const SizedBox(height: 3),
                        Text(_captions[family]!,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 7),
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('12.345.678 ₫',
                                maxLines: 1,
                                style: currencyTextStyle(
                                    context,
                                    theme.textTheme.bodyMedium!.copyWith(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                        color: active ? selectedInk : ink),
                                    family: family))),
                      ]),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      // Preserve readable labels for accessibility and very narrow windows.
      final columns = constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(12.5) > 20
          ? 1
          : 2;
      return Column(children: [
        for (var i = 0; i < kCurrencyFontChoices.length; i += columns)
          Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Expanded(child: card(kCurrencyFontChoices[i])),
                    if (columns == 2) ...[
                      const SizedBox(width: 10),
                      Expanded(
                          child: i + 1 < kCurrencyFontChoices.length
                              ? card(kCurrencyFontChoices[i + 1])
                              : const SizedBox.shrink()),
                    ],
                  ]))),
      ]);
    });
  }
}
