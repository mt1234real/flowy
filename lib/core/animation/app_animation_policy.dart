// ==============================================================================
// File: lib/core/animation/app_animation_policy.dart
// Architecture: Universal Animation Hardening, Preserved Routes & Fluid Sheet Engine
// Stack: flutter/material.dart, flutter/services.dart, flutter/gestures.dart
// Features:
// 1. AnimationBehavior.preserve Enforcement:
//    - Bảo đảm mọi AnimationController không bị triệt tiêu duration về 0ms khi hệ điều hành
//      tắt animator scale hoặc bật chế độ tiết kiệm pin / trợ năng.
// 2. FluidSheetMotion Tokens:
//    - Quản lý tập trung các thông số vật lý cử chỉ vuốt kéo đóng sheet (dismissFraction: 0.25,
//      dismissVelocity: 700.0, enterDuration: 300ms, dismissDuration: 220ms, snapBackDuration: 220ms).
// 3. FluidDismissibleSheet với tùy chọn enableBlur:
//    - Mặc định true cho modal độc lập; đặt false khi mở modal lồng nhau để chống mờ kép và nhẹ GPU.
// 4. PreservedModalBottomSheetRoute, PreservedMaterialPageRoute, PreservedDialogRoute.
// ==============================================================================

import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// 1. FLUID SHEET MOTION TOKENS
// ============================================================================

abstract final class FluidSheetMotion {
  static const double dismissFraction = 0.25;
  static const double dismissVelocity = 700.0;
  static const Duration enterDuration = Duration(milliseconds: 300);
  static const Duration dismissDuration = Duration(milliseconds: 220);
  static const Duration snapBackDuration = Duration(milliseconds: 220);
  static const double blurSigma = 18.0;
}

// ============================================================================
// 2. FLUID SHEET SCOPE & SCROLL PHYSICS
// ============================================================================

class FluidSheetScope extends InheritedWidget {
  final ScrollController? scrollController;
  final Animation<double> progress;
  final bool isDragging;
  final bool Function() canDismiss;

  const FluidSheetScope({
    super.key,
    this.scrollController,
    required this.progress,
    required this.isDragging,
    required this.canDismiss,
    required super.child,
  });

  static FluidSheetScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FluidSheetScope>();
  }

  @override
  bool updateShouldNotify(FluidSheetScope oldWidget) {
    return scrollController != oldWidget.scrollController ||
        progress != oldWidget.progress ||
        isDragging != oldWidget.isDragging;
  }
}

class FluidSheetScrollPhysics extends ClampingScrollPhysics {
  final bool Function() sheetDisplaced;

  const FluidSheetScrollPhysics({
    required this.sheetDisplaced,
    super.parent,
  });

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (sheetDisplaced()) return 0.0;
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  FluidSheetScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FluidSheetScrollPhysics(
      sheetDisplaced: sheetDisplaced,
      parent: buildParent(ancestor),
    );
  }
}

// ============================================================================
// 3. FLUID DISMISSIBLE SHEET WIDGET
// ============================================================================

class FluidDismissibleSheet extends StatefulWidget {
  final AnimationController routeController;
  final ScrollController? scrollController;
  final FluidSheetMode mode;
  final bool isDismissible;
  final bool Function()? canDismiss;
  final bool enableBlur;
  final Widget child;

  const FluidDismissibleSheet({
    super.key,
    required this.routeController,
    this.scrollController,
    this.mode = FluidSheetMode.fixed,
    this.isDismissible = true,
    this.canDismiss,
    this.enableBlur = true,
    required this.child,
  });

  @override
  State<FluidDismissibleSheet> createState() => _FluidDismissibleSheetState();
}

class _FluidDismissibleSheetState extends State<FluidDismissibleSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _microLiftController;
  late final Animation<double> _microLiftAnimation;

  VelocityTracker? _velocityTracker;
  int? _activePointer;
  double _lastY = 0.0;
  double _sheetHeight = 1.0;
  bool _draggingSheet = false;
  bool _hapticFired = false;
  bool _closing = false;
  double _nestedScrollPixels = 0.0;

  @override
  void initState() {
    super.initState();
    _microLiftController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 40),
      debugLabel: 'FluidDismissibleSheet.microLift',
    );

    _microLiftAnimation = Tween<double>(begin: -2.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _microLiftController,
        curve: Curves.easeOutQuad,
      ),
    );
  }

  @override
  void dispose() {
    _microLiftController.dispose();
    super.dispose();
  }

  bool _checkCanDismiss() {
    if (!widget.isDismissible) return false;
    return widget.canDismiss?.call() ?? true;
  }

  bool get _routeIsClosing =>
      _closing || widget.routeController.status == AnimationStatus.reverse;

  bool _isVerticalScrollAtTop() {
    final scroll = widget.scrollController;
    if (scroll != null && scroll.hasClients) {
      return scroll.position.pixels <= 0.5;
    }
    if (widget.mode == FluidSheetMode.nestedScrollable) {
      return _nestedScrollPixels <= 0.5;
    }
    return true;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (widget.mode != FluidSheetMode.nestedScrollable) return false;
    if (notification.metrics.axis == Axis.vertical) {
      _nestedScrollPixels = notification.metrics.pixels;
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_routeIsClosing || _activePointer != null) return;
    _activePointer = event.pointer;
    _lastY = event.position.dy;
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker?.addPosition(event.timeStamp, event.position);

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      _sheetHeight = renderBox.size.height > 0 ? renderBox.size.height : 1.0;
    }
    _draggingSheet = false;
    _hapticFired = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _routeIsClosing) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);

    final currentY = event.position.dy;
    final dy = currentY - _lastY;
    _lastY = currentY;

    if (!_draggingSheet) {
      final atTop = _isVerticalScrollAtTop();

      if (atTop && dy > 0 && _checkCanDismiss()) {
        _draggingSheet = true;
        setState(() {});
      }
    }

    if (_draggingSheet) {
      final deltaProgress = dy / _sheetHeight;
      final currentVal = widget.routeController.value;
      final nextVal = (currentVal - deltaProgress).clamp(0.0, 1.0);
      widget.routeController.value = nextVal;

      final pulledDownFraction = 1.0 - nextVal;
      if (pulledDownFraction >= FluidSheetMotion.dismissFraction && !_hapticFired) {
        _hapticFired = true;
        HapticFeedback.lightImpact();
      }
    }
  }

  Future<void> _onPointerUp(PointerUpEvent event) async {
    if (event.pointer != _activePointer || _routeIsClosing) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);

    final velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;
    final velocityY = velocity.pixelsPerSecond.dy;
    final pulledDownFraction = 1.0 - widget.routeController.value;

    final shouldDismiss = _draggingSheet &&
        _checkCanDismiss() &&
        (pulledDownFraction >= FluidSheetMotion.dismissFraction ||
            velocityY >= FluidSheetMotion.dismissVelocity);

    _activePointer = null;
    _velocityTracker = null;

    if (shouldDismiss) {
      _closing = true;

      if (!_hapticFired) {
        _hapticFired = true;
        HapticFeedback.lightImpact();
      }

      FocusManager.instance.primaryFocus?.unfocus();

      await widget.routeController.animateBack(
        0.0,
        duration: FluidSheetMotion.dismissDuration,
        curve: Curves.easeInCubic,
      );

      if (!mounted) return;

      final route = ModalRoute.of(context);
      if (route?.isCurrent ?? false) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (_draggingSheet) {
      setState(() {
        _draggingSheet = false;
      });

      await widget.routeController.animateTo(
        1.0,
        duration: FluidSheetMotion.snapBackDuration,
        curve: Curves.easeOutCubic,
      );

      if (mounted) {
        _microLiftController.forward(from: 0.0);
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer || _routeIsClosing) return;
    _activePointer = null;
    _velocityTracker = null;

    if (_draggingSheet) {
      setState(() {
        _draggingSheet = false;
      });

      widget.routeController.animateTo(
        1.0,
        duration: FluidSheetMotion.snapBackDuration,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FluidSheetScope(
      scrollController: widget.scrollController,
      progress: widget.routeController,
      isDragging: _draggingSheet,
      canDismiss: _checkCanDismiss,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              widget.routeController,
              _microLiftAnimation,
            ]),
            builder: (context, child) {
              final content = Transform.translate(
                offset: Offset(0, _microLiftAnimation.value),
                child: child,
              );

              if (!widget.enableBlur) {
                return content;
              }

              final blurVal = (FluidSheetMotion.blurSigma * widget.routeController.value)
                  .clamp(0.001, FluidSheetMotion.blurSigma);

              return BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurVal, sigmaY: blurVal),
                child: content,
              );
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. MAIN APP ANIMATION POLICY API
// ============================================================================

enum FluidSheetMode { fixed, scrollable, nestedScrollable }

typedef FluidSheetBuilder = Widget Function(
    BuildContext context, ScrollController? scrollController);

abstract final class AppAnimationPolicy {
  static const Duration defaultDuration = Duration(milliseconds: 320);
  static const Duration defaultReverseDuration = Duration(milliseconds: 260);

  static const Duration dialogDuration = Duration(milliseconds: 260);
  static const Duration dialogReverseDuration = Duration(milliseconds: 220);

  static const AnimationStyle snackBarAnimationStyle = AnimationStyle(
    duration: Duration(milliseconds: 250),
    reverseDuration: Duration(milliseconds: 200),
  );

  static AnimationController createController({
    required TickerProvider vsync,
    required Duration duration,
    Duration? reverseDuration,
    String? debugLabel,
  }) {
    return AnimationController(
      vsync: vsync,
      duration: duration,
      reverseDuration: reverseDuration,
      debugLabel: debugLabel,
      animationBehavior: AnimationBehavior.preserve,
    );
  }

  static Future<T?> showFluidSheet<T>({
    required BuildContext context,
    required FluidSheetBuilder builder,
    FluidSheetMode mode = FluidSheetMode.scrollable,
    Duration duration = FluidSheetMotion.enterDuration,
    Duration reverseDuration = FluidSheetMotion.dismissDuration,
    bool useRootNavigator = true,
    bool isDismissible = true,
    bool enableBlur = true,
    bool Function()? canDismiss,
    Color? backgroundColor = Colors.transparent,
    ShapeBorder? shape,
  }) async {
    final NavigatorState navigator =
    Navigator.of(context, rootNavigator: useRootNavigator);

    final AnimationController routeController = AnimationController(
      vsync: navigator,
      duration: duration,
      reverseDuration: reverseDuration,
      animationBehavior: AnimationBehavior.preserve,
      debugLabel: 'AppAnimationPolicy.showFluidSheet',
    );

    final ScrollController? scrollController =
    mode == FluidSheetMode.scrollable ? ScrollController() : null;

    final route = PreservedModalBottomSheetRoute<T>(
      builder: (sheetContext) => FluidDismissibleSheet(
        routeController: routeController,
        scrollController: scrollController,
        mode: mode,
        isDismissible: isDismissible,
        canDismiss: canDismiss,
        enableBlur: enableBlur,
        child: builder(sheetContext, scrollController),
      ),
      transitionAnimationController: routeController,
      isScrollControlled: true,
      enableDrag: false,
      showDragHandle: false,
      isDismissible: isDismissible,
      useSafeArea: false,
      backgroundColor: backgroundColor,
      shape: shape,
      transitionDuration: duration,
      reverseDuration: reverseDuration,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
    );

    try {
      final result = await navigator.push<T>(route);

      // Navigator.push() resolves as soon as the route is popped. At that
      // moment the reverse transition / modal barrier may still be alive.
      // Keep both controllers alive until Flutter removes all overlay entries.
      await route.completed;

      return result;
    } finally {
      scrollController?.dispose();
      routeController.dispose();
    }
  }

  static Future<T?> showPreservedSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    TickerProvider? vsync,
    Duration duration = defaultDuration,
    Duration reverseDuration = defaultReverseDuration,
    bool isScrollControlled = true,
    bool enableDrag = true,
    bool showDragHandle = false,
    bool isDismissible = true,
    bool useSafeArea = false,
    bool useRootNavigator = true,
    Color? backgroundColor = Colors.transparent,
    ShapeBorder? shape,
  }) {
    final NavigatorState navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    return navigator.push<T>(
      PreservedModalBottomSheetRoute<T>(
        builder: builder,
        isScrollControlled: isScrollControlled,
        enableDrag: enableDrag,
        showDragHandle: showDragHandle,
        isDismissible: isDismissible,
        useSafeArea: useSafeArea,
        backgroundColor: backgroundColor,
        shape: shape,
        transitionDuration: duration,
        reverseDuration: reverseDuration,
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
      ),
    );
  }

  static Future<T?> showPreservedDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String? barrierLabel,
    Color? barrierColor,
  }) {
    return Navigator.of(context).push<T>(
      PreservedDialogRoute<T>(
        builder: builder,
        barrierDismissible: barrierDismissible,
        barrierLabel: barrierLabel,
        barrierColor: barrierColor,
        transitionDuration: dialogDuration,
        reverseDuration: dialogReverseDuration,
      ),
    );
  }
}

// ============================================================================
// 5. PRESERVED MODAL BOTTOM SHEET ROUTE
// ============================================================================

class PreservedModalBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  PreservedModalBottomSheetRoute({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.backgroundColor,
    super.elevation,
    super.shape,
    super.clipBehavior,
    super.constraints,
    super.modalBarrierColor,
    super.isDismissible = true,
    super.enableDrag = true,
    super.showDragHandle = false,
    required super.isScrollControlled,
    super.scrollControlDisabledMaxHeightRatio = 9.0 / 16.0,
    super.settings,
    super.anchorPoint,
    super.useSafeArea = false,
    super.transitionAnimationController,
    Duration transitionDuration = AppAnimationPolicy.defaultDuration,
    Duration reverseDuration = AppAnimationPolicy.defaultReverseDuration,
  })  : _sheetDuration = transitionDuration,
        _sheetReverseDuration = reverseDuration;

  final Duration _sheetDuration;
  final Duration _sheetReverseDuration;

  @override
  Duration get transitionDuration => _sheetDuration;

  @override
  Duration get reverseTransitionDuration => _sheetReverseDuration;

  @override
  AnimationController createAnimationController() {
    final externalController = transitionAnimationController;

    if (externalController != null) {
      // This is the inherited TransitionRoute ownership flag.
      // Do NOT replace it with a private bool; Flutter reads this property
      // when deciding whether the route may dispose the controller.
      willDisposeAnimationController = false;
      return externalController;
    }

    assert(navigator != null);

    willDisposeAnimationController = true;
    return AnimationController(
      vsync: navigator!,
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration,
      animationBehavior: AnimationBehavior.preserve,
      debugLabel: 'AppAnimationPolicy.PreservedModalBottomSheetRoute',
    );
  }
}

// ============================================================================
// 6. PRESERVED MATERIAL PAGE ROUTE
// ============================================================================

class PreservedMaterialPageRoute<T> extends MaterialPageRoute<T> {
  PreservedMaterialPageRoute({
    required super.builder,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
    super.allowSnapshotting = true,
  });

  @override
  AnimationController createAnimationController() {
    return AnimationController(
      vsync: navigator!,
      duration: transitionDuration,
      reverseDuration: transitionDuration,
      animationBehavior: AnimationBehavior.preserve,
      debugLabel: 'AppAnimationPolicy.MaterialPageRoute',
    );
  }
}

// ============================================================================
// 7. PRESERVED PAGE ROUTE BUILDER
// ============================================================================

class PreservedPageRouteBuilder<T> extends PageRouteBuilder<T> {
  PreservedPageRouteBuilder({
    super.settings,
    required super.pageBuilder,
    super.transitionsBuilder,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Duration reverseTransitionDuration = const Duration(milliseconds: 300),
    super.opaque = true,
    super.barrierDismissible = false,
    super.barrierColor,
    super.barrierLabel,
    super.maintainState = true,
    super.fullscreenDialog = false,
    super.allowSnapshotting = true,
  })  : _appTransitionDuration = transitionDuration,
        _appReverseTransitionDuration = reverseTransitionDuration,
        super(
        transitionDuration: transitionDuration,
        reverseTransitionDuration: reverseTransitionDuration,
      );

  final Duration _appTransitionDuration;
  final Duration _appReverseTransitionDuration;

  @override
  AnimationController createAnimationController() {
    return AnimationController(
      vsync: navigator!,
      duration: _appTransitionDuration,
      reverseDuration: _appReverseTransitionDuration,
      animationBehavior: AnimationBehavior.preserve,
      debugLabel: 'AppAnimationPolicy.PageRouteBuilder',
    );
  }
}

// ============================================================================
// 8. PRESERVED DIALOG ROUTE
// ============================================================================

class PreservedDialogRoute<T> extends RawDialogRoute<T> {
  PreservedDialogRoute({
    required WidgetBuilder builder,
    required bool barrierDismissible,
    String? barrierLabel,
    Color? barrierColor,
    Duration transitionDuration = const Duration(milliseconds: 260),
    Duration reverseDuration = const Duration(milliseconds: 220),
  })  : _appTransitionDuration = transitionDuration,
        _appReverseTransitionDuration = reverseDuration,
        super(
        pageBuilder: (context, animation, secondaryAnimation) => builder(context),
        barrierDismissible: barrierDismissible,
        barrierLabel: barrierLabel,
        barrierColor: barrierColor,
        transitionDuration: transitionDuration,
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      );

  final Duration _appTransitionDuration;
  final Duration _appReverseTransitionDuration;

  @override
  Duration get reverseTransitionDuration => _appReverseTransitionDuration;

  @override
  AnimationController createAnimationController() {
    return AnimationController(
      vsync: navigator!,
      duration: _appTransitionDuration,
      reverseDuration: _appReverseTransitionDuration,
      animationBehavior: AnimationBehavior.preserve,
      debugLabel: 'AppAnimationPolicy.DialogRoute',
    );
  }
}