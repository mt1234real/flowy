import 'package:flutter/material.dart';

import 'app_animation_policy.dart';

/// Navigation tokens. Depth/container motion is reserved for later migrations.
abstract final class FlowyNavigationMotion {
  static const tabSwitch = Duration(milliseconds: 240);
  static const depthEnter = Duration(milliseconds: 280);
  static const depthExit = Duration(milliseconds: 240);
  static const containerEnter = Duration(milliseconds: 340);
  static const containerExit = Duration(milliseconds: 300);
  static const navSelect = Duration(milliseconds: 200);
  static const navDeselect = Duration(milliseconds: 160);
  static const curve = Curves.easeOutCubic;
  static const tabScale = 0.985;
  static const iconLift = -3.0;
  static const iconScale = 1.045;
  static const haloAlpha = 0.12;
}

/// Keeps each tab mounted, with only the outgoing and selected tabs painting.
/// Selection comes from the shell, including provider-driven navigation.
class FlowyTabTransitionStack extends StatefulWidget {
  const FlowyTabTransitionStack({
    super.key,
    required this.index,
    required this.children,
  }) : assert(index >= 0 && index < children.length);

  final int index;
  final List<Widget> children;

  @override
  State<FlowyTabTransitionStack> createState() =>
      _FlowyTabTransitionStackState();
}

class _FlowyTabTransitionStackState extends State<FlowyTabTransitionStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _previous;

  @override
  void initState() {
    super.initState();
    _controller = AppAnimationPolicy.createController(
      vsync: this,
      duration: FlowyNavigationMotion.tabSwitch,
      debugLabel: 'FlowyNavigation.TabSwitch',
    )..value = 1;
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previous != null) {
      setState(() => _previous = null);
    }
  }

  @override
  void didUpdateWidget(covariant FlowyTabTransitionStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == oldWidget.index) return;
    // A rapid selection supersedes the older pair; no queued transitions.
    _previous = oldWidget.index;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final outgoing = const Interval(
          0,
          0.45,
          curve: FlowyNavigationMotion.curve,
        ).transform(_controller.value);
        final incoming = const Interval(
          0.35,
          1,
          curve: FlowyNavigationMotion.curve,
        ).transform(_controller.value);
        return Stack(
          fit: StackFit.expand,
          children: List.generate(widget.children.length, (index) {
            final selected = widget.index == index;
            final leaving = _previous == index;
            final opacity =
                selected ? incoming : (leaving ? 1 - outgoing : 1.0);
            final scale = selected
                ? FlowyNavigationMotion.tabScale +
                    (1 - FlowyNavigationMotion.tabScale) * incoming
                : 1 - (1 - FlowyNavigationMotion.tabScale) * outgoing;
            return Offstage(
              offstage: !selected && !leaving,
              child: IgnorePointer(
                ignoring: !selected,
                child: ExcludeSemantics(
                  excluding: !selected,
                  child: TickerMode(
                    enabled: selected,
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: RepaintBoundary(child: widget.children[index]),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
