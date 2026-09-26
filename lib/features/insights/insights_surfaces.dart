import 'dart:ui';
import 'package:flutter/material.dart';
import '../../widgets/currency_text.dart';
import '../../theme/app_theme.dart';

Color insightsTone(BuildContext context, Color source) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final hsl = HSLColor.fromColor(source);
  return hsl
      .withSaturation(hsl.saturation.clamp(0, dark ? .48 : .58))
      .withLightness(dark ? .64 : .48)
      .toColor();
}

class InsightsGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? tint;
  const InsightsGlass(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.tint});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = tint ?? theme.colorScheme.primary;
    return Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: [
          BoxShadow(
              color:
                  theme.colorScheme.shadow.withValues(alpha: dark ? .08 : .035),
              blurRadius: 22,
              offset: const Offset(0, 8))
        ]),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                    padding: padding,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color.alphaBlend(
                                  accent.withValues(
                                      alpha: tint == null
                                          ? .025
                                          : dark
                                              ? .12
                                              : .08),
                                  (dark
                                          ? theme.colorScheme.surface
                                          : Colors.white)
                                      .withValues(alpha: .90)),
                              theme.colorScheme.surface.withValues(alpha: .88)
                            ]),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            width: .8,
                            color: (dark
                                    ? theme.colorScheme.onSurface
                                    : Colors.white)
                                .withValues(alpha: dark ? .08 : .85))),
                    child: child))));
  }
}

List<Color> insightsGradient(String id, String name, int rank) {
  if (id.startsWith('__') || name == 'Chưa phân loại') {
    return const [Color(0xFF94A3B8), Color(0xFF64748B)];
  }
  if (name == 'Thiết yếu') return const [Color(0xFF10B981), Color(0xFF06B6D4)];
  if (name == 'Tùy ý') return const [Color(0xFFFF6B8B), Color(0xFFFF8E53)];
  const palette = [
    [Color(0xFFFF6B8B), Color(0xFFFF8E53)],
    [Color(0xFF10B981), Color(0xFF06B6D4)],
    [Color(0xFF38BDF8), Color(0xFF3B82F6)],
    [Color(0xFFC084FC), Color(0xFF8B5CF6)],
    [Color(0xFFFDE68A), Color(0xFFFBBF24)],
  ];
  return palette[rank.clamp(0, 4)];
}

class InsightsTrendRibbon extends StatelessWidget {
  final String text, details;
  final String amount;
  final double delta;
  final bool expense;
  const InsightsTrendRibbon(
      {super.key,
      required this.text,
      required this.delta,
      required this.details,
      required this.amount,
      this.expense = true});
  @override
  Widget build(BuildContext context) {
    final warning = expense ? delta > 0 : delta < 0;
    final tone =
        warning ? AppTokens.expense : Theme.of(context).colorScheme.primary;
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Tooltip(
            message: details,
            triggerMode: TooltipTriggerMode.tap,
            child: Container(
                constraints: const BoxConstraints(minHeight: 74),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: tone.withValues(alpha: .075),
                    borderRadius: BorderRadius.circular(18)),
                child: Stack(children: [
                  Positioned(
                      right: 0,
                      bottom: 0,
                      width: 96,
                      height: 48,
                      child: IgnorePointer(
                          child: CustomPaint(painter: _RibbonWave(tone)))),
                  Row(children: [
                    Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: tone.withValues(alpha: .12),
                            shape: BoxShape.circle),
                        child: Icon(
                            delta == 0
                                ? Icons.trending_flat
                                : warning
                                    ? Icons.trending_up
                                    : Icons.spa_outlined,
                            size: 20,
                            color: tone)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(text,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 5),
                          CurrencyText(amount,
                              style: TextStyle(fontSize: 12.5, color: tone)),
                        ])),
                  ])
                ]))));
  }
}

class _RibbonWave extends CustomPainter {
  final Color color;
  const _RibbonWave(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final line = Path()
      ..moveTo(0, size.height * .9)
      ..cubicTo(size.width * .25, size.height * .9, size.width * .3,
          size.height * .2, size.width * .5, size.height * .5)
      ..cubicTo(size.width * .72, size.height * .8, size.width * .72, 0,
          size.width, size.height * .15);
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: .35));
  }

  @override
  bool shouldRepaint(covariant _RibbonWave old) => old.color != color;
}
