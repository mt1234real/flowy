import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_animation_policy.dart';

/// Tab motion and the scoped hierarchical navigation pilot are independent.
abstract final class FlowyNavigationMotion {
  static const tabSwitch = Duration(milliseconds: 240);
  // Reference-informed candidate, not a measured hardware performance claim.
  static const hierarchy = Duration(milliseconds: 380);
  static const navSelect = Duration(milliseconds: 200);
  static const navDeselect = Duration(milliseconds: 160);
  static const curve = Curves.easeOutCubic;
  static const tabScale = 0.985;
  static const iconLift = -3.0;
  static const iconScale = 1.045;
  static const haloAlpha = 0.12;
}

/// Only Trend -> Insights -> Bucket opts into the reference-motion pilot.
/// Navigator owns normal, predictive, cancel and commit progress throughout.
PreservedMaterialPageRoute<T> flowyReferenceRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool maintainState = true,
}) =>
    _FlowyReferenceRoute<T>(
      builder: builder,
      settings: settings,
      maintainState: maintainState,
    );

class _FlowyReferenceRoute<T> extends PreservedMaterialPageRoute<T> {
  _FlowyReferenceRoute({
    required super.builder,
    super.settings,
    super.maintainState,
  });

  // Preserve N4.2b ownership: Navigator's flag alone includes covered routes.
  bool _ownsBackGesture = false;

  @override
  bool get popGestureInProgress =>
      _ownsBackGesture && super.popGestureInProgress;

  @override
  void install() {
    super.install();
    navigator!.userGestureInProgressNotifier.addListener(_gestureChanged);
  }

  void _gestureChanged() {
    if (!navigator!.userGestureInProgress) _ownsBackGesture = false;
  }

  @override
  void handleStartBackGesture({double progress = 0.0}) {
    _ownsBackGesture = true;
    super.handleStartBackGesture(progress: progress);
  }

  @override
  void dispose() {
    navigator?.userGestureInProgressNotifier.removeListener(_gestureChanged);
    super.dispose();
  }

  @override
  Duration get transitionDuration => FlowyNavigationMotion.hierarchy;

  @override
  Duration get reverseTransitionDuration => FlowyNavigationMotion.hierarchy;

  @override
  DelegatedTransitionBuilder get delegatedTransition => _previousPilotPage;

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is _FlowyReferenceRoute;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final normal = _ReferencePrimaryTransition(
      animation: animation,
      child: _ReferenceSecondaryTransition(
        animation: secondaryAnimation,
        child: child,
      ),
    );
    if (Theme.of(context).platform != TargetPlatform.android) return normal;
    return _ReferenceBackGesture(
      route: this,
      animation: animation,
      normal: normal,
      child: child,
    );
  }

  // Stable identity: nested pilot pages apply their secondary motion once;
  // Material/root pages receive this instead of their theme's secondary effect.
  static Widget? _previousPilotPage(
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          bool allowSnapshotting,
          Widget? child) =>
      _ReferenceSecondaryTransition(
          animation: secondaryAnimation, child: child);
}

class _ReferenceContentMotion extends StatelessWidget {
  const _ReferenceContentMotion(
      {required this.animation,
      required this.incoming,
      required this.direction,
      required this.child});

  final Animation<double> animation;
  final bool incoming;
  final double direction;
  final Widget? child;

  // A brief overlap is intentional. Unlike N4.2a, there is no zero/zero
  // handoff; unlike a full-duration crossfade, two pages are never both clear.
  static final _inAlpha = CurveTween(
    curve: const Interval(.18, .90, curve: Curves.easeOutQuad),
  );
  static final _outAlpha = Tween<double>(begin: 1, end: 0).chain(
    CurveTween(curve: const Interval(0, .33, curve: Curves.easeInQuad)),
  );
  static const _inTravel = Interval(.12, 1, curve: Curves.easeOutCubic);
  static final _inRight =
      Tween<Offset>(begin: const Offset(.30, 0), end: Offset.zero)
          .chain(CurveTween(curve: _inTravel));
  static final _inLeft =
      Tween<Offset>(begin: const Offset(-.30, 0), end: Offset.zero)
          .chain(CurveTween(curve: _inTravel));
  static final _outLeft =
      Tween<Offset>(begin: Offset.zero, end: const Offset(-.13, 0)).chain(
          CurveTween(
              curve: const Interval(0, .43, curve: Curves.easeInOutCubic)));
  static final _outRight =
      Tween<Offset>(begin: Offset.zero, end: const Offset(.13, 0)).chain(
          CurveTween(
              curve: const Interval(0, .43, curve: Curves.easeInOutCubic)));

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: (incoming ? _inAlpha : _outAlpha).animate(animation),
        child: SlideTransition(
          position: (incoming
                  ? (direction > 0 ? _inRight : _inLeft)
                  : (direction > 0 ? _outRight : _outLeft))
              .animate(animation),
          child: child,
        ),
      );
}

class _ReferencePrimaryTransition extends StatelessWidget {
  const _ReferencePrimaryTransition(
      {required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;
  @override
  Widget build(BuildContext context) => DualTransitionBuilder(
        animation: animation,
        forwardBuilder: (context, progress, child) => _ReferenceContentMotion(
            animation: progress, incoming: true, direction: 1, child: child),
        reverseBuilder: (context, progress, child) => _ReferenceContentMotion(
            animation: progress, incoming: false, direction: 1, child: child),
        child: child,
      );
}

class _ReferenceSecondaryTransition extends StatelessWidget {
  const _ReferenceSecondaryTransition(
      {required this.animation, required this.child});
  final Animation<double> animation;
  final Widget? child;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Navigator.of(context).userGestureInProgressNotifier,
        builder: (context, _) {
          // Predictive preview/settlement owns only the accepting foreground page.
          if (Navigator.of(context).userGestureInProgress) {
            return child ?? const SizedBox.shrink();
          }
          return ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: DualTransitionBuilder(
              animation: ReverseAnimation(animation),
              forwardBuilder: (context, progress, child) =>
                  _ReferenceContentMotion(
                      animation: progress,
                      incoming: true,
                      direction: -1,
                      child: child),
              reverseBuilder: (context, progress, child) =>
                  _ReferenceContentMotion(
                      animation: progress,
                      incoming: false,
                      direction: -1,
                      child: child),
              child: child,
            ),
          );
        },
      );
}

enum _BackPhase { preview, cancel, commit }

/// Platform event adapter only. No ticker/controller: public PageRoute gesture
/// methods seek and settle the Navigator-owned animation, including PopScope.
class _ReferenceBackGesture extends StatefulWidget {
  const _ReferenceBackGesture(
      {required this.route,
      required this.animation,
      required this.normal,
      required this.child});
  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Widget normal;
  final Widget child;
  @override
  State<_ReferenceBackGesture> createState() => _ReferenceBackGestureState();
}

class _ReferenceBackGestureState extends State<_ReferenceBackGesture>
    with WidgetsBindingObserver {
  _BackPhase _phase = _BackPhase.preview;
  PredictiveBackEvent? _start;
  PredictiveBackEvent? _latest;
  double _releaseProgress = 0;
  double _releaseDy = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent event) {
    if (event.isButtonEvent ||
        !widget.route.isCurrent ||
        !widget.route.popGestureEnabled) {
      return false;
    }
    setState(() {
      _phase = _BackPhase.preview;
      _start = _latest = event;
    });
    widget.route.handleStartBackGesture(progress: 1 - event.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent event) {
    if (!widget.route.isCurrent || !widget.route.popGestureInProgress) return;
    setState(() => _latest = event);
    widget.route.handleUpdateBackGestureProgress(progress: 1 - event.progress);
  }

  double get _fingerDy =>
      ((_latest?.touchOffset?.dy ?? 0) - (_start?.touchOffset?.dy ?? 0)) * .1;

  void _release(_BackPhase phase) {
    // Capture before Flutter's commit resets its route clock to 1. Cancellation
    // also retains vertical finger displacement rather than clearing its pose.
    setState(() {
      _releaseProgress = 1 - widget.animation.value;
      _releaseDy = _fingerDy;
      _phase = phase;
    });
  }

  @override
  void handleCancelBackGesture() {
    _release(_BackPhase.cancel);
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    _release(_BackPhase.commit);
    widget.route.handleCommitBackGesture();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([
          widget.animation,
          widget.route.navigator!.userGestureInProgressNotifier,
        ]),
        builder: (context, _) {
          if (!widget.route.popGestureInProgress) return widget.normal;
          return LayoutBuilder(builder: (context, constraints) {
            final size = constraints.biggest;
            final direction = _start?.swipeEdge == SwipeEdge.right ? -1.0 : 1.0;
            final commit = _phase == _BackPhase.commit;
            final progress =
                commit ? _releaseProgress : 1 - widget.animation.value;
            final dy = _phase == _BackPhase.preview
                ? _fingerDy
                : _phase == _BackPhase.cancel && _releaseProgress > 0
                    ? _releaseDy * (progress / _releaseProgress).clamp(0.0, 1.0)
                    : _releaseDy;
            final settle = commit
                ? Curves.easeOutCubic.transform(1 - widget.animation.value)
                : 0.0;
            final alpha = commit
                ? 1 -
                    const Interval(0, .65, curve: Curves.easeInQuad)
                        .transform(1 - widget.animation.value)
                : 1.0;
            final x = (size.width * .05 - 8) * progress * direction;
            final y = dy.clamp(-size.height * .1, size.height * .1);
            final corners = MediaQuery.displayCornerRadiiOf(context) ??
                BorderRadius.circular(32);
            final radius =
                BorderRadius.lerp(BorderRadius.zero, corners, progress)!;
            final wash = commit
                ? .9 *
                    Curves.easeOutQuad.transform(alpha) *
                    const Interval(0, .12, curve: Curves.easeOutCubic)
                        .transform(1 - widget.animation.value)
                : 0.0;
            return Stack(fit: StackFit.expand, children: [
              // Full-viewport painted color also attenuates the exposed margins.
              // It starts transparent at release, then resolves as the old content
              // disappears. This attenuates covered content without transforming its route.
              ColoredBox(
                  color: Theme.of(context)
                      .scaffoldBackgroundColor
                      .withValues(alpha: wash)),
              Transform.translate(
                offset: Offset(x + (direction * size.width * .13 - x) * settle,
                    y * (1 - settle)),
                child: Transform.scale(
                  scale: 1 - .1 * progress * (1 - settle),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.lerp(radius, BorderRadius.zero, settle)!,
                    child: FadeTransition(
                        opacity: AlwaysStoppedAnimation(alpha),
                        child: widget.child),
                  ),
                ),
              ),
            ]);
          });
        },
      );
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
