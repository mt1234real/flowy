import '../../widgets/preserved_balance_tumbler.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/animation/app_animation_policy.dart';
import '../../theme/app_theme.dart';
import 'insights_data.dart';
import 'insights_surfaces.dart';

class InsightsDonut extends StatefulWidget {
  final List<InsightsBucket> slices;
  final double total;
  final double diameter;
  final String? selected;
  final String amount, label, supporting;
  final bool isVisible;
  final ValueChanged<String?> onSelect;
  const InsightsDonut(
      {super.key,
      this.diameter = 220,
      required this.slices,
      required this.total,
      required this.selected,
      required this.amount,
      required this.isVisible,
      required this.label,
      required this.supporting,
      required this.onSelect});
  @override
  State<InsightsDonut> createState() => _InsightsDonutState();
}

class _InsightsDonutState extends State<InsightsDonut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  @override
  void initState() {
    super.initState();
    _motion = AppAnimationPolicy.createController(
        vsync: this,
        duration: const Duration(milliseconds: 250),
        debugLabel: 'Insights.donut')
      ..forward();
  }

  @override
  void didUpdateWidget(covariant InsightsDonut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _motion.duration = const Duration(milliseconds: 200);
      _motion.forward(from: 0);
    } else if (oldWidget.total != widget.total ||
        oldWidget.slices.map((b) => b.id).join() !=
            widget.slices.map((b) => b.id).join()) {
      _motion.duration = const Duration(milliseconds: 250);
      _motion.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _select(Offset position) {
    final offset = position - Offset(widget.diameter / 2, widget.diameter / 2);
    if (offset.distance < widget.diameter * .27 - 5 ||
        offset.distance > widget.diameter / 2 ||
        widget.total <= 0) {
      return;
    }
    final angle =
        (math.atan2(offset.dy, offset.dx) + math.pi / 2 + math.pi * 2) %
            (math.pi * 2);
    var sum = 0.0;
    for (final slice in widget.slices) {
      sum += slice.amount / widget.total * math.pi * 2;
      if (angle < sum) {
        HapticFeedback.selectionClick();
        widget.onSelect(widget.selected == slice.id ? null : slice.id);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => Center(
          child: SizedBox(
        width: widget.diameter,
        height: widget.diameter,
        child: GestureDetector(
          onTapUp: (event) => _select(event.localPosition),
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, child) => CustomPaint(
                painter: _DonutPainter(
                    widget.slices,
                    [
                      for (final slice in widget.slices)
                        insightsGradient(
                            slice.id, slice.name, widget.slices.indexOf(slice))
                    ],
                    Theme.of(context).colorScheme.primary,
                    widget.total,
                    widget.selected,
                    Curves.easeOutCubic.transform(_motion.value)),
                child: Opacity(
                    opacity:
                        .7 + .3 * Curves.easeOutCubic.transform(_motion.value),
                    child: child)),
            child: Center(
              // Keep the complete text block inside an inscribed rectangle.
              child: SizedBox(
                width: (widget.diameter * .54 - 10) * .8,
                height: (widget.diameter * .54 - 10) * .56,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: (widget.diameter * .54 - 10) * .8,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10.5,
                              letterSpacing: .3,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          child: PreservedBalanceTumbler(
                              isVisible: widget.isVisible,
                              realValue: widget.amount,
                              height: 26,
                              alignment: Alignment.center,
                              style: currencyTextStyle(
                                  context,
                                  const TextStyle(
                                      fontSize: 18.5,
                                      fontWeight: FontWeight.w900)))),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(widget.supporting,
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w500)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
}

class _DonutPainter extends CustomPainter {
  final List<InsightsBucket> slices;
  final double total, progress;
  final List<List<Color>> colors;
  final Color accent;
  final String? selected;
  _DonutPainter(this.slices, this.colors, this.accent, this.total,
      this.selected, this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 5;
    final thickness = size.shortestSide * .23;
    final inner = radius - thickness;
    final outerRect = Rect.fromCircle(center: center, radius: radius);
    final innerRect = Rect.fromCircle(center: center, radius: inner);
    if (total <= 0) return;
    var start = -math.pi / 2;
    final visible = slices.where((s) => s.amount > 0).toList();
    for (final slice in visible) {
      final angle = slice.amount / total * math.pi * 2;
      final gap =
          visible.length == 1 ? 0.0 : math.min(2.8 / inner, angle * .25);
      final a = start + gap / 2;
      final sweep = angle - gap;
      final path = Path()
        ..moveTo(
            center.dx + radius * math.cos(a), center.dy + radius * math.sin(a))
        ..arcTo(outerRect, a, sweep, false)
        ..lineTo(center.dx + inner * math.cos(a + sweep),
            center.dy + inner * math.sin(a + sweep))
        ..arcTo(innerRect, a + sweep, -sweep, false)
        ..close();
      final opacity = selected != null && selected != slice.id ? .5 : 1.0;
      if (slice.id == selected) {
        canvas.drawPath(
            path,
            Paint()
              ..color = accent.withValues(alpha: .3 * progress)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      }
      canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors[slices.indexOf(slice)]
                        .map((c) => c.withValues(alpha: opacity))
                        .toList())
                .createShader(outerRect));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8
            ..color = Colors.white.withValues(alpha: .45));
      // Tiny shares stay in the legend rather than colliding with nearby labels.
      if (angle >= .23) {
        final mid = start + angle / 2;
        final pos = center +
            Offset(math.cos(mid), math.sin(mid)) * (radius - thickness / 2);
        final label = TextPainter(
            textDirection: TextDirection.ltr,
            text: TextSpan(
                text: '${(slice.amount / total * 100).round()}%',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color:
                        colors[slices.indexOf(slice)].first.computeLuminance() >
                                .5
                            ? const Color(0xFF0F172A)
                            : Colors.white)))
          ..layout();
        label.paint(canvas, pos - Offset(label.width / 2, label.height / 2));
      }
      start += angle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

/// Preserved, small fade/slide for report changes and calm loading placeholders.
class InsightsReveal extends StatefulWidget {
  final Widget child;
  final bool pulse;
  const InsightsReveal({super.key, required this.child, this.pulse = false});
  @override
  State<InsightsReveal> createState() => _InsightsRevealState();
}

class _InsightsRevealState extends State<InsightsReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AppAnimationPolicy.createController(
        vsync: this,
        duration: Duration(milliseconds: widget.pulse ? 1400 : 250),
        debugLabel: 'Insights.reportTransition');
    if (widget.pulse) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
            opacity: widget.pulse ? .5 + t * .5 : .6 + t * .4,
            child: Transform.translate(
                offset: Offset(0, widget.pulse ? 0 : (1 - t) * 4),
                child: child));
      });
}

/// Keeps the expansion motion when system animation scaling is disabled.
class InsightsAccordion extends StatefulWidget {
  final bool expanded;
  final Widget child;
  const InsightsAccordion(
      {super.key, required this.expanded, required this.child});
  @override
  State<InsightsAccordion> createState() => _InsightsAccordionState();
}

class _InsightsAccordionState extends State<InsightsAccordion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AppAnimationPolicy.createController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
        debugLabel: 'Insights.otherGroups')
      ..value = widget.expanded ? 1 : 0;
  }

  @override
  void didUpdateWidget(covariant InsightsAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != widget.expanded) {
      widget.expanded ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ClipRect(
          child: Align(
              alignment: Alignment.topCenter,
              heightFactor: Curves.easeOutCubic.transform(_controller.value),
              child: IgnorePointer(
                  ignoring: !widget.expanded,
                  child: ExcludeSemantics(
                      excluding: !widget.expanded,
                      child: Opacity(
                          opacity: _controller.value, child: child))))));
}
