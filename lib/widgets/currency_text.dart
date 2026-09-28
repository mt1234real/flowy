import 'package:flutter/material.dart';
import 'local_balance_peek.dart';
import '../core/animation/app_animation_policy.dart';
import '../theme/app_theme.dart';

/// Keeps descriptive copy in the app font and styles only embedded amounts.
class CurrencyText extends StatelessWidget {
  const CurrencyText(this.data,
      {super.key,
      this.style,
      this.respectPrivacy = true,
      this.isVisible,
      this.textAlign,
      this.maxLines,
      this.overflow,
      this.softWrap,
      this.textScaler});
  final String data;
  final bool respectPrivacy;
  final bool? isVisible;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextScaler? textScaler;

  static final _amount =
      RegExp(r'[+−-]?(?:[0-9][0-9.,\s]*[KMBTkmbt]?|[•●]+)\s*[₫đ]');

  @override
  Widget build(BuildContext context) {
    final visible = !respectPrivacy ||
        (isVisible ?? BalancePrivacyScope.isVisibleOf(context));
    if (!_amount.hasMatch(data) || !respectPrivacy) return _text(context, data);
    return LocalBalancePeek(
        visible: visible,
        valueKey: data,
        builder: (show) {
          final masked = data.replaceAll(_amount, '•••••• ₫');
          final displayed = show ? data : masked;
          return _CurrencyMotion(
            value: displayed,
            sizing: ExcludeSemantics(
                child: Opacity(
                    opacity: 0,
                    child: Stack(children: [
                      _text(context, data),
                      _text(context, masked),
                    ]))),
            child: _text(context, displayed),
          );
        });
  }

  Widget _text(BuildContext context, String data) {
    final base = DefaultTextStyle.of(context).style.merge(style);
    final money = currencyTextStyle(context, base);
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in _amount.allMatches(data)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: data.substring(offset, match.start)));
      }
      spans.add(TextSpan(text: match.group(0), style: money));
      offset = match.end;
    }
    if (offset < data.length) spans.add(TextSpan(text: data.substring(offset)));
    return Text.rich(TextSpan(children: spans),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
        textScaler: textScaler);
  }
}

/// Visibility belongs to this screen subtree, never to the app or other routes.
class BalancePrivacyScope extends InheritedWidget {
  const BalancePrivacyScope(
      {super.key, required this.visible, required super.child});
  final bool visible;

  static bool isVisibleOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BalancePrivacyScope>()
          ?.visible ??
      true;

  @override
  bool updateShouldNotify(BalancePrivacyScope oldWidget) =>
      visible != oldWidget.visible;
}

/// Preserved two-layer transition, with a reserved real/masked text footprint.
class _CurrencyMotion extends StatefulWidget {
  const _CurrencyMotion(
      {required this.value, required this.child, required this.sizing});
  final String value;
  final Widget child, sizing;
  @override
  State<_CurrencyMotion> createState() => _CurrencyMotionState();
}

class _CurrencyMotionState extends State<_CurrencyMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      debugLabel: 'Currency.visibility');
  Widget? _outgoing;
  @override
  void didUpdateWidget(covariant _CurrencyMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _outgoing = oldWidget.child;
      _motion.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
          child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final t = _outgoing == null
              ? 1.0
              : Curves.easeOutCubic.transform(_motion.value);
          return Stack(children: [
            widget.sizing,
            if (_outgoing != null && t < 1)
              Positioned.fill(
                  child: ExcludeSemantics(
                      child: Opacity(
                          opacity: 1 - t,
                          child: Transform.translate(
                              offset: Offset(0, -4 * t), child: _outgoing)))),
            Positioned.fill(
                child: Opacity(
                    opacity: t,
                    child: Transform.translate(
                        offset: Offset(0, 4 * (1 - t)), child: widget.child))),
          ]);
        },
      ));
}
