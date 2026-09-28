// ==============================================================================
// File: lib/widgets/preserved_sleek_dismissible.dart
// Architecture: Custom Physics-Based Dismissible with Progressive Underlay Reveal & Guaranteed Lifecycle
// ==============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../core/animation/app_animation_policy.dart';
import '../theme/app_theme.dart';

class PreservedSleekDismissible extends StatefulWidget {
  final Widget child;
  final FutureOr<void> Function() onDismissed;
  final Color backgroundColor;
  final bool animateIn;
  final FutureOr<bool?> Function()? confirmDismiss;
  final String label;
  final IconData icon;
  final double borderRadius;
  final VoidCallback? onInsertAnimationCompleted;

  const PreservedSleekDismissible({
    super.key,
    required this.child,
    required this.onDismissed,
    this.backgroundColor = AppTokens.expense,
    this.animateIn = false,
    this.confirmDismiss,
    this.label = 'Xóa',
    this.icon = Icons.delete_outline_rounded,
    this.borderRadius = 20,
    this.onInsertAnimationCompleted,
  });

  @override
  State<PreservedSleekDismissible> createState() =>
      _PreservedSleekDismissibleState();
}

class _PreservedSleekDismissibleState extends State<PreservedSleekDismissible>
    with TickerProviderStateMixin {
  static const double _dismissThreshold = 0.40;
  static const double _iconRevealStart = 0.15;
  static const Duration _returnDuration = Duration(milliseconds: 160);
  static const Duration _exitSlideDuration = Duration(milliseconds: 100);
  static const Duration _collapseDuration = Duration(milliseconds: 200);
  static const Duration _insertDuration = Duration(milliseconds: 180);

  late final AnimationController _horizontalController;
  late final AnimationController _collapseController;

  Animation<double>? _returnAnimation;
  Animation<double>? _exitAnimation;

  double _dragOffset = 0.0;
  double _itemWidth = 0.0;
  bool _isThresholdReached = false;
  bool _isDismissing = false;
  bool _isReturning = false;

  @override
  void initState() {
    super.initState();

    _horizontalController = AppAnimationPolicy.createController(
      vsync: this,
      duration: _returnDuration,
      debugLabel: 'PreservedSleekDismissible.horizontal',
    );

    _collapseController = AppAnimationPolicy.createController(
      vsync: this,
      duration: _collapseDuration,
      debugLabel: 'PreservedSleekDismissible.collapse',
    );

    if (widget.animateIn) {
      _collapseController.value = 1.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _collapseController
            .animateBack(0.0,
                duration: _insertDuration, curve: Curves.easeOutCubic)
            .then((_) {
          if (mounted) {
            widget.onInsertAnimationCompleted?.call();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _collapseController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isDismissing || _isReturning || _itemWidth <= 0) return;

    final dx = details.primaryDelta ?? 0.0;
    final nextOffset = (_dragOffset + dx).clamp(-_itemWidth, 0.0);
    final progress = (nextOffset.abs() / _itemWidth).clamp(0.0, 1.0);

    if (progress >= _dismissThreshold && !_isThresholdReached) {
      _isThresholdReached = true;
      // Exactly one readiness haptic when crossing the 40% delete threshold.
      HapticFeedback.mediumImpact();
    } else if (progress < _dismissThreshold && _isThresholdReached) {
      _isThresholdReached = false;
    }

    setState(() {
      _dragOffset = nextOffset;
    });
  }

  Future<void> _onHorizontalDragEnd(DragEndDetails details) async {
    if (_isDismissing || _isReturning || _itemWidth <= 0) return;

    final progress = (-_dragOffset / _itemWidth).clamp(0.0, 1.0);
    final velocity = details.primaryVelocity ?? 0.0;

    if (progress >= _dismissThreshold ||
        (velocity < -500 && _dragOffset < -20)) {
      _returnAnimation = null;
      _isReturning = true;
      bool allowed;
      try {
        allowed = widget.confirmDismiss == null ||
            await widget.confirmDismiss!.call() == true;
      } catch (_) {
        allowed = false;
      }
      if (!mounted) return;
      _isReturning = false;
      if (!allowed) {
        await _returnToRest();
        return;
      }
      _isDismissing = true;

      _exitAnimation =
          Tween<double>(begin: _dragOffset, end: -_itemWidth).animate(
        CurvedAnimation(
            parent: _horizontalController, curve: Curves.easeOutCubic),
      );
      _horizontalController.duration = _exitSlideDuration;
      _horizontalController.forward(from: 0.0);

      _collapseController.duration = _collapseDuration;
      await _collapseController.forward(from: 0.0);

      try {
        await widget.onDismissed();
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDismissing = false;
            _isThresholdReached = false;
            _dragOffset = 0.0;
          });
          _collapseController.reverse();
        }
      }
    } else {
      await _returnToRest();
    }
  }

  Future<void> _returnToRest() async {
    if (_dragOffset == 0 || !mounted) return;
    _isReturning = true;
    _returnAnimation = Tween<double>(begin: _dragOffset, end: 0).animate(
        CurvedAnimation(
            parent: _horizontalController, curve: Curves.easeOutCubic));
    _horizontalController.duration = _returnDuration;
    await _horizontalController.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _dragOffset = 0;
      _isThresholdReached = false;
      _isReturning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _itemWidth = constraints.maxWidth;

        return AnimatedBuilder(
          animation: Listenable.merge([
            _horizontalController,
            _collapseController,
          ]),
          builder: (context, child) {
            double currentOffset = _dragOffset;
            if (_isDismissing && _exitAnimation != null) {
              currentOffset = _exitAnimation!.value;
            } else if (_isReturning && _returnAnimation != null) {
              currentOffset = _returnAnimation!.value;
            }

            final double heightFactor =
                (1.0 - _collapseController.value).clamp(0.0, 1.0);
            if (heightFactor <= 0.0001 && !_isDismissing) {
              return const SizedBox.shrink();
            }

            final double dragProgress = _itemWidth > 0
                ? (currentOffset.abs() / _itemWidth).clamp(0.0, 1.0)
                : 0.0;

            // Progressive underlay:
            // - 0% drag: absolutely invisible.
            // - Background gradually reaches full visibility at the 40% threshold.
            // - Trash icon only starts revealing after 15%, scaling 0.8 -> 1.0.
            final underlayProgress =
                (dragProgress / _dismissThreshold).clamp(0.0, 1.0).toDouble();
            final underlayOpacity =
                Curves.easeOutCubic.transform(underlayProgress);

            final iconProgress = ((dragProgress - _iconRevealStart) /
                    (_dismissThreshold - _iconRevealStart))
                .clamp(0.0, 1.0)
                .toDouble();
            final iconOpacity = Curves.easeOutCubic.transform(iconProgress);
            final iconScale = 0.8 + (0.2 * iconOpacity);

            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: heightFactor,
                child: Opacity(
                  opacity: heightFactor,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: underlayOpacity,
                            child: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: widget.backgroundColor,
                                borderRadius:
                                    BorderRadius.circular(widget.borderRadius),
                              ),
                              child: Opacity(
                                opacity: iconOpacity,
                                child: Transform.scale(
                                  scale: iconScale,
                                  alignment: Alignment.center,
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(widget.icon,
                                            color: Colors.white, size: 20),
                                        const SizedBox(width: 6),
                                        Text(widget.label,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800)),
                                      ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(currentOffset, 0),
                        child: RawGestureDetector(
                          behavior: HitTestBehavior.opaque,
                          gestures: {
                            _InteriorHorizontalDrag:
                                GestureRecognizerFactoryWithHandlers<
                                    _InteriorHorizontalDrag>(
                              () => _InteriorHorizontalDrag(),
                              (recognizer) => recognizer
                                ..edgeInset =
                                    MediaQuery.paddingOf(context).left + 24
                                ..onUpdate = _onHorizontalDragUpdate
                                ..onEnd = _onHorizontalDragEnd
                                ..onCancel = () {
                                  if (!_isDismissing && !_isReturning) {
                                    _returnToRest();
                                  }
                                },
                            ),
                          },
                          child: widget.child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Leave the system back-swipe edge out of this recognizer's gesture arena.
class _InteriorHorizontalDrag extends HorizontalDragGestureRecognizer {
  double edgeInset = 24;
  @override
  bool isPointerAllowed(PointerEvent event) =>
      event.position.dx > edgeInset && super.isPointerAllowed(event);
}
