// ==============================================================================
// File: lib/widgets/preserved_balance_tumbler.dart
// Architecture: Zero-Layout-Shift Preserved Motion Tumbler for Masked Metrics
// Stack: flutter, intl
// ==============================================================================

import 'package:flutter/material.dart';

import '../core/animation/app_animation_policy.dart';
import '../theme/app_theme.dart';

class PreservedBalanceTumbler extends StatefulWidget {
  final bool isVisible;
  final String realValue;
  final String maskedValue;
  final TextStyle style;
  final bool isCurrency;
  final double height;
  final Alignment alignment;
  final double travelPx;
  final Duration duration;
  final String debugLabel;

  const PreservedBalanceTumbler({
    super.key,
    required this.isVisible,
    required this.realValue,
    this.maskedValue = '•••••• ₫',
    required this.style,
    this.isCurrency = true,
    this.height = 40.0,
    this.alignment = Alignment.centerLeft,
    this.travelPx = 4.0,
    this.duration = const Duration(milliseconds: 180),
    this.debugLabel = 'PreservedBalanceTumbler',
  });

  @override
  State<PreservedBalanceTumbler> createState() =>
      _PreservedBalanceTumblerState();
}

class _PreservedBalanceTumblerState extends State<PreservedBalanceTumbler>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late bool _currentVisible;
  bool? _previousVisible;

  @override
  void initState() {
    super.initState();
    _currentVisible = widget.isVisible;
    _controller = AppAnimationPolicy.createController(
      vsync: this,
      duration: widget.duration,
      debugLabel: widget.debugLabel,
    );
  }

  @override
  void didUpdateWidget(covariant PreservedBalanceTumbler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      _previousVisible = oldWidget.isVisible;
      _currentVisible = widget.isVisible;
      _controller.forward(from: 0.0).then((_) {
        if (mounted) setState(() => _previousVisible = null);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildText(bool visible) {
    final text = visible ? widget.realValue : widget.maskedValue;
    final baseSpacing = widget.style.letterSpacing ?? 0.0;
    final resolvedSpacing = visible ? baseSpacing : 2.0;

    return Align(
      alignment: widget.alignment,
      child: Text(
        text,
        maxLines: 1,
        style: (widget.isCurrency
                ? currencyTextStyle(context, widget.style)
                : widget.style)
            .copyWith(letterSpacing: resolvedSpacing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_previousVisible == null) {
      return SizedBox(
        height: widget.height,
        child: _buildText(_currentVisible),
      );
    }

    return SizedBox(
      height: widget.height,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final raw = _controller.value;
            final slideT = Curves.easeOutCubic.transform(raw);

            return Stack(
              alignment: widget.alignment,
              children: [
                // Giá trị cũ trượt lên trên (-travelPx) và mờ dần
                Opacity(
                  opacity: (1.0 - raw).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -widget.travelPx * slideT),
                    child: _buildText(_previousVisible!),
                  ),
                ),
                // Giá trị mới trượt từ dưới (+travelPx) lên và hiện dần
                Opacity(
                  opacity: raw.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, widget.travelPx * (1.0 - slideT)),
                    child: _buildText(_currentVisible),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
