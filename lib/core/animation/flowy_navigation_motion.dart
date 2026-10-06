import 'package:flutter/material.dart';

import 'app_animation_policy.dart';

/// Navigation tokens. Container motion is reserved for a later migration.
abstract final class FlowyNavigationMotion {
  static const tabSwitch = Duration(milliseconds: 240);
  static const surfaceEnter = Duration(milliseconds: 280);
  static const surfaceExit = Duration(milliseconds: 240);
  static const containerEnter = Duration(milliseconds: 340);
  static const containerExit = Duration(milliseconds: 300);
  static const navSelect = Duration(milliseconds: 200);
  static const navDeselect = Duration(milliseconds: 160);
  static const curve = Curves.easeOutCubic;
  static const tabScale = 0.985;
  static const iconLift = -3.0;
  static const iconScale = 1.045;
  static const haloAlpha = 0.12;
  static const surfaceDissolveTravelPx = 12.0;
  static const surfaceWashPeakAlphaLight = 0.90;
  static const surfaceWashPeakAlphaDark = 0.85;
}

/// Reveals a child surface over a stationary workspace. Secondary animation
/// deliberately does not move the previous route or its dock/FAB.
PreservedPageRouteBuilder<T> flowySurfaceRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool maintainState = true,
}) =>
    PreservedPageRouteBuilder<T>(
      settings: settings,
      maintainState: maintainState,
      transitionDuration: FlowyNavigationMotion.surfaceEnter,
      reverseTransitionDuration: FlowyNavigationMotion.surfaceExit,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          _SurfaceTransition(animation: animation, child: child),
    );

class _SurfaceTransition extends StatelessWidget {
  const _SurfaceTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  static const _washIn = Interval(0, .38, curve: Curves.easeOutCubic);
  static const _washOut = Interval(.46, .82, curve: Curves.easeInOutCubic);
  static const _childIn = Interval(.40, 1, curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = theme.brightness == Brightness.dark
        ? FlowyNavigationMotion.surfaceWashPeakAlphaDark
        : FlowyNavigationMotion.surfaceWashPeakAlphaLight;
    final washColor = Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: .02),
      theme.scaffoldBackgroundColor,
    );
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        // Intervals use the raw Navigator clock. Reversing retraces the same
        // presentation without changing curves mid-flight or sequencing timers.
        final t = animation.value;
        final wash = _washIn.transform(t) * (1 - _washOut.transform(t));
        final incoming = _childIn.transform(t);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Paint alpha into the color, without fading the parent subtree.
              IgnorePointer(
                child: ExcludeSemantics(
                  child: ColoredBox(
                    color: washColor.withValues(alpha: peak * wash),
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(
                  FlowyNavigationMotion.surfaceDissolveTravelPx *
                      (1 - incoming),
                  0,
                ),
                // One intentional page fade; no opacity wrapper on the wash.
                child: Opacity(opacity: incoming, child: child),
              ),
            ],
          ),
        );
      },
    );
  }
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
