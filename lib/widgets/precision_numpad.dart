// ==============================================================================
// File: lib/widgets/precision_numpad.dart
// Architecture: Unified Fintech Keypad Design System
// Features:
// - App-font numeric typography (28px / configurable weight)
// - 72px tactile glass discs
// - 50ms compression to 0.92x + 100ms release
// - Glass alpha 0.06 to 0.32
// - One selectionClick per key activation
// - Shared 16px PIN dots with 20px pop and 120ms ripple
// ==============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../core/animation/app_animation_policy.dart';
import '../theme/app_theme.dart';

@immutable
class PrecisionNumpadAction {
  final String? label;
  final IconData? icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final Color? color;
  final String? semanticLabel;

  const PrecisionNumpadAction({
    this.label,
    this.icon,
    required this.onPressed,
    this.onLongPress,
    this.color,
    this.semanticLabel,
  }) : assert(label != null || icon != null);
}

/// Unified 3x4 fintech keypad.
///
/// Numeric keys always inherit the app's current font from Theme.of(context)
/// rather than forcing monospace / a platform fallback.
class PrecisionNumpad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBackspaceLongPress;
  final PrecisionNumpadAction? leadingAction;
  final PrecisionNumpadAction? trailingAction;
  final Color digitColor;
  final FontWeight digitFontWeight;
  final Color actionColor;
  final double horizontalPadding;
  final double rowSpacing;

  const PrecisionNumpad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBackspaceLongPress,
    this.leadingAction,
    this.trailingAction,
    this.digitColor = Colors.white,
    this.digitFontWeight = FontWeight.w600,
    this.actionColor = Colors.white70,
    this.horizontalPadding = 18,
    this.rowSpacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTrailing = trailingAction ??
        PrecisionNumpadAction(
          icon: Icons.backspace_outlined,
          onPressed: onBackspace,
          onLongPress: onBackspaceLongPress,
          color: actionColor,
          semanticLabel: 'Xóa',
        );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(['1', '2', '3']),
          SizedBox(height: rowSpacing),
          _row(['4', '5', '6']),
          SizedBox(height: rowSpacing),
          _row(['7', '8', '9']),
          SizedBox(height: rowSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              if (leadingAction != null)
                PrecisionNumpadKey.action(leadingAction!)
              else
                const SizedBox(width: 72, height: 72),
              PrecisionNumpadKey.number(
                number: '0',
                onPressed: () => onDigit('0'),
                color: digitColor,
                fontWeight: digitFontWeight,
              ),
              PrecisionNumpadKey.action(resolvedTrailing),
            ].map((key) => Expanded(child: Center(child: key))).toList(),
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> values) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: values
          .map(
            (value) => PrecisionNumpadKey.number(
              number: value,
              onPressed: () => onDigit(value),
              color: digitColor,
              fontWeight: digitFontWeight,
            ),
          )
          .map((key) => Expanded(child: Center(child: key)))
          .toList(growable: false),
    );
  }
}

/// One physical keypad key.
///
/// Preserved compression, luminous type and a fading glass disc.
class PrecisionNumpadKey extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final String? semanticLabel;
  final bool isNumber;

  const PrecisionNumpadKey._({
    super.key,
    this.isNumber = false,
    this.label,
    this.icon,
    required this.onPressed,
    this.onLongPress,
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    this.semanticLabel,
  }) : assert(label != null || icon != null);

  factory PrecisionNumpadKey.number({
    Key? key,
    required String number,
    required VoidCallback onPressed,
    Color color = Colors.white,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return PrecisionNumpadKey._(
      key: key,
      label: number,
      isNumber: true,
      onPressed: onPressed,
      color: color,
      fontSize: 28,
      fontWeight: fontWeight,
      semanticLabel: number,
    );
  }

  factory PrecisionNumpadKey.action(PrecisionNumpadAction action) {
    return PrecisionNumpadKey._(
      label: action.label,
      icon: action.icon,
      onPressed: action.onPressed,
      onLongPress: action.onLongPress,
      color: action.color ?? Colors.white70,
      fontSize: 19,
      fontWeight: FontWeight.w700,
      semanticLabel: action.semanticLabel ?? action.label,
    );
  }

  @override
  State<PrecisionNumpadKey> createState() => _PrecisionNumpadKeyState();
}

class _PrecisionNumpadKeyState extends State<PrecisionNumpadKey>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  bool _down = false;
  @override
  void initState() {
    super.initState();
    _press = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
      reverseDuration: const Duration(milliseconds: 100),
      debugLabel: 'PrecisionNumpadKey.glassPress',
    );
  }

  void _pressDown() {
    _down = true;
    HapticFeedback.selectionClick();
    _press.forward(from: 0);
  }

  void _release() {
    if (!_down) return;
    _down = false;
    // Complete compression even for a tap shorter than one frame.
    _press.value = 1;
    _press.reverse();
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style =
        (Theme.of(context).textTheme.headlineSmall ?? const TextStyle())
            .copyWith(
      fontSize: widget.fontSize,
      fontWeight: widget.fontWeight,
      color: widget.color,
      height: 1,
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: 0,
    );
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      onTap: widget.onPressed,
      onLongPress: widget.onLongPress,
      child: Listener(
        onPointerDown: (_) => _pressDown(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          gestures: {
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(),
              (recognizer) => recognizer
                ..onTap = widget.onPressed
                ..onTapCancel = _release,
            ),
            if (widget.onLongPress != null)
              LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(
                    duration: const Duration(milliseconds: 350)),
                (recognizer) => recognizer
                  ..onLongPress = () {
                    HapticFeedback.lightImpact();
                    widget.onLongPress?.call();
                  },
              ),
          },
          child: AnimatedBuilder(
            animation: _press,
            builder: (context, _) {
              final t = _press.value;
              final scale = _press.status == AnimationStatus.reverse
                  ? 0.92 + 0.08 * Curves.easeOutBack.transform(1 - t)
                  : 1 - 0.08 * Curves.easeOutCubic.transform(t);
              return SizedBox(
                width: 72,
                height: 72,
                child: Transform.scale(
                  scale: scale,
                  child: ClipOval(
                    // A painted translucent disc avoids ten backdrop passes
                    // while the keypad moves with its route or bottom sheet.
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isNumber
                            ? Colors.white.withValues(
                                alpha: _down ? 0.32 : 0.06 + 0.26 * t)
                            : Colors.transparent,
                        border: widget.isNumber
                            ? Border.all(
                                width: 0.8,
                                color: Colors.white.withValues(alpha: 0.14))
                            : null,
                      ),
                      child: Center(
                          child: widget.label != null
                              ? Text(widget.label!, style: style)
                              : Icon(widget.icon,
                                  size: widget.icon == Icons.backspace_outlined
                                      ? 22
                                      : 26,
                                  color: widget.color)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Shared mechanical PIN dots used by unlock and setup/change flows.
class VaultPinDots extends StatelessWidget {
  final int length;
  final int enteredLength;
  final Color accentColor;
  final bool isError;
  final double shakeProgress;

  const VaultPinDots({
    super.key,
    required this.length,
    required this.enteredLength,
    required this.accentColor,
    this.isError = false,
    this.shakeProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final t = shakeProgress.clamp(0.0, 1.0);
    final shakeX = math.sin(t * math.pi * 6.0) * 6.0 * (1.0 - t);

    return Transform.translate(
      offset: Offset(shakeX, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(length, (index) {
          final isFilled = index < enteredLength;
          final color = isError ? AppTokens.expense : accentColor;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _KineticPinDot(
                filled: isFilled, isError: isError, color: color),
          );
        }),
      ),
    );
  }
}

class _KineticPinDot extends StatefulWidget {
  final bool filled;
  final bool isError;
  final Color color;
  const _KineticPinDot(
      {required this.filled, required this.isError, required this.color});
  @override
  State<_KineticPinDot> createState() => _KineticPinDotState();
}

class _KineticPinDotState extends State<_KineticPinDot>
    with TickerProviderStateMixin {
  late final AnimationController _pop;
  late final AnimationController _ripple;
  late final AnimationController _erase;
  @override
  void initState() {
    super.initState();
    _pop = AppAnimationPolicy.createController(
        vsync: this,
        duration: const Duration(milliseconds: 60),
        debugLabel: 'VaultPinDot.pop');
    _ripple = AppAnimationPolicy.createController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
        debugLabel: 'VaultPinDot.ripple');
    _erase = AppAnimationPolicy.createController(
        vsync: this,
        duration: const Duration(milliseconds: 90),
        debugLabel: 'VaultPinDot.erase');
    _pop.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pop.animateBack(0,
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOutBack);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _KineticPinDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isError) {
      _erase.reset();
      _pop.reset();
      _ripple.reset();
    } else if (!widget.filled && oldWidget.filled) {
      _pop.reset();
      _ripple.reset();
      _erase.forward(from: 0);
    } else if (widget.filled && !oldWidget.filled) {
      _erase.reset();
      _pop.forward(from: 0);
      _ripple.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _ripple.dispose();
    _erase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([_pop, _ripple, _erase]),
        builder: (context, _) {
          final active = widget.filled || widget.isError;
          return SizedBox(
              width: 16,
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (_ripple.isAnimating && !widget.isError)
                    Positioned(
                        width: 48,
                        height: 48,
                        child: Transform.scale(
                          scale: 0.3 +
                              0.7 *
                                  Curves.easeOutCubic.transform(_ripple.value),
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                width: 0.7,
                                color: widget.color.withValues(
                                    alpha: 0.55 * (1 - _ripple.value))),
                          )),
                        )),
                  Transform.scale(
                      scale: _erase.isAnimating
                          ? 1 -
                              0.25 *
                                  math.sin(math.pi *
                                      Curves.easeInCubic
                                          .transform(_erase.value))
                          : 1 + 0.25 * _pop.value,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? widget.color : Colors.transparent,
                          border: Border.all(
                              color: active
                                  ? widget.color
                                  : const Color(0xFF475569),
                              width: 1.8),
                          boxShadow: widget.filled && !widget.isError
                              ? [
                                  BoxShadow(
                                      color:
                                          widget.color.withValues(alpha: 0.42),
                                      blurRadius: 12,
                                      spreadRadius: 1)
                                ]
                              : null,
                        ),
                      )),
                ],
              ));
        },
      );
}
