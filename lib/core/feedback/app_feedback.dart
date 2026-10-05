// ==============================================================================
// File: lib/core/feedback/app_feedback.dart
// Architecture: Unified Feedback & Notification Architecture (Refined Layout & Typography)
// Stack: dart:async, dart:math, dart:ui, flutter/material.dart, flutter/services.dart
//
// 3-Tier Feedback Matrix:
// 1. Safe-Area Top Banner Pill  -> success / info / background status
// 2. In-Situ Validation         -> shake + border pulse, no overlay
// 3. Dynamic Bottom Undo Dock   -> destructive soft-delete undo only
// ==============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../animation/app_animation_policy.dart';

// ==============================================================================
// 1. TOKENS
// ==============================================================================

abstract final class AppFeedbackTokens {
  // ---------------------------------------------------------------------------
  // Channel 1: Safe-Area Top Banner Pill
  // ---------------------------------------------------------------------------
  static const Duration topBannerEnterDuration = Duration(milliseconds: 500);
  static const Duration topBannerSuccessHoldDuration =
      Duration(milliseconds: 2000);
  static const Duration topBannerHoldDuration = Duration(milliseconds: 1800);
  static const Duration topBannerExitDuration = Duration(milliseconds: 270);

  static const double topBannerSafeGap = 12.0;
  static const double topBannerEnterTravel = 16.0;
  static const double topBannerExitTravel = 8.0;
  static const double topBannerHeight = 42.0;
  static const double topBannerRadius = 999.0;
  static const double topBannerHorizontalScreenMargin = 16.0;
  static const double topBannerMaxWidth = 520.0;
  static const double topBannerBlurSigma = 16.0;
  static const double topBannerBorderWidth = 0.8;

  // Theme-adaptive glass colors
  static const Color darkGlassBackground = Color(0xEB1E2430); // ~92%
  static const Color darkGlassBorder = Color(0xFF2E384D);
  static const Color lightGlassBackground = Color(0xF20F172A); // ~95%
  static const Color lightGlassBorder = Color(0xFF334155);

  // ---------------------------------------------------------------------------
  // Channel 2: In-Situ Validation
  // ---------------------------------------------------------------------------
  static const Duration validationShakeDuration = Duration(milliseconds: 180);
  static const Duration validationBorderPulseDuration = Duration(milliseconds: 200);

  static const double validationShakeDistance = 4.0;
  static const double validationPersistentWarningStrength = 0.28;

  // ---------------------------------------------------------------------------
  // Channel 3: Dynamic Bottom Undo Dock
  // ---------------------------------------------------------------------------
  static const Duration undoDuration = Duration(seconds: 3);
  static const Duration undoEnterDuration = Duration(milliseconds: 180);
  static const Duration undoExitDuration = Duration(milliseconds: 150);
  static const Duration undoGestureExitDuration = Duration(milliseconds: 120);
  static const Duration undoSnapBackDuration = Duration(milliseconds: 120);
  static const Duration undoAnchorLowerDuration = Duration(milliseconds: 260);
  static const Duration undoAnchorRaiseDuration = Duration(milliseconds: 240);

  static const double undoNavigationGap = 12.0;
  static const double undoDetailSafeGap = 12.0;
  static const double undoHorizontalMargin = 16.0;
  static const double undoMaxWidth = 560.0;
  static const double undoRadius = 16.0;
  static const double undoDockHeight = 52.0;
  static const double undoEnterTravel = 18.0;
  static const double undoExitTravel = 18.0;
  static const double undoProgressHeight = 1.5;
  static const double undoAnchorRaiseOvershoot = 1.5;

  static const double undoPrimaryFallbackObstruction = 110.0;

  static const double undoSwipeHorizontalDistance = 44.0;
  static const double undoSwipeDownDistance = 24.0;
  static const double undoSwipeHorizontalVelocity = 500.0;
  static const double undoSwipeDownVelocity = 450.0;
}

// ==============================================================================
// 2. PUBLIC MODELS
// ==============================================================================

enum AppTopFeedbackTone {
  info,
  success,
  error,
}

enum AppLiveFeedbackPresentation { standard, ambientBackup }

/// One latest live status, separate from the single transient feedback slot.
@immutable
class AppLiveFeedback {
  final String id, message;
  final IconData icon;
  final AppTopFeedbackTone tone;
  final bool terminal, spinning, reduceMotion;
  final AppLiveFeedbackPresentation presentation;
  final VoidCallback? onPresented;
  const AppLiveFeedback(
      {required this.id,
      required this.message,
      required this.icon,
      this.tone = AppTopFeedbackTone.info,
      this.terminal = false,
      this.spinning = false,
      this.reduceMotion = false,
      this.presentation = AppLiveFeedbackPresentation.standard,
      this.onPresented});
}

class AppValidationFeedbackController extends ChangeNotifier {
  int _pulseSerial = 0;
  bool _isInvalid = false;

  int get pulseSerial => _pulseSerial;
  bool get isInvalid => _isInvalid;

  void reject({bool emitHaptic = true}) {
    _isInvalid = true;
    _pulseSerial += 1;

    if (emitHaptic) {
      HapticFeedback.heavyImpact();
    }

    notifyListeners();
  }

  void clear() {
    if (!_isInvalid) return;
    _isInvalid = false;
    notifyListeners();
  }
}

@immutable
class AppValidationVisualState {
  final double shakeX;
  final double borderStrength;
  final bool isInvalid;

  const AppValidationVisualState({
    required this.shakeX,
    required this.borderStrength,
    required this.isInvalid,
  });

  Color borderColor(Color restingColor) {
    return Color.lerp(
      restingColor,
      AppTokens.expense,
      borderStrength.clamp(0.0, 1.0),
    ) ?? restingColor;
  }
}

typedef AppValidationFeedbackBuilder = Widget Function(
    BuildContext context,
    AppValidationVisualState visual,
    );

// ==============================================================================
// 3. CHANNEL 2 WIDGET: IN-SITU SHAKE & BORDER PULSE
// ==============================================================================

class AppValidationFeedback extends StatefulWidget {
  final AppValidationFeedbackController controller;
  final AppValidationFeedbackBuilder builder;

  const AppValidationFeedback({
    super.key,
    required this.controller,
    required this.builder,
  });

  @override
  State<AppValidationFeedback> createState() => _AppValidationFeedbackState();
}

class _AppValidationFeedbackState extends State<AppValidationFeedback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _lastPulseSerial;

  @override
  void initState() {
    super.initState();
    _lastPulseSerial = widget.controller.pulseSerial;

    _controller = AnimationController(
      vsync: this,
      duration: AppFeedbackTokens.validationBorderPulseDuration,
      value: 1.0,
      animationBehavior: AnimationBehavior.preserve,
      debugLabel: 'AppFeedback.validation',
    );

    widget.controller.addListener(_handleFeedbackChanged);
  }

  @override
  void didUpdateWidget(covariant AppValidationFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;

    oldWidget.controller.removeListener(_handleFeedbackChanged);
    _lastPulseSerial = widget.controller.pulseSerial;
    widget.controller.addListener(_handleFeedbackChanged);
  }

  void _handleFeedbackChanged() {
    final serialChanged = widget.controller.pulseSerial != _lastPulseSerial;

    if (serialChanged) {
      _lastPulseSerial = widget.controller.pulseSerial;
      _controller.forward(from: 0.0);
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleFeedbackChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _controller,
        widget.controller,
      ]),
      builder: (context, _) {
        final raw = _controller.value.clamp(0.0, 1.0);

        final shakeFraction =
            AppFeedbackTokens.validationShakeDuration.inMicroseconds /
                AppFeedbackTokens.validationBorderPulseDuration.inMicroseconds;

        final shakeT = (raw / shakeFraction).clamp(0.0, 1.0).toDouble();

        // Exactly 3 decaying oscillation cycles.
        final shakeX = math.sin(shakeT * math.pi * 6.0) *
            AppFeedbackTokens.validationShakeDistance *
            (1.0 - shakeT);

        final pulse = 1.0 - Curves.easeOutCubic.transform(raw);

        final persistent = widget.controller.isInvalid
            ? AppFeedbackTokens.validationPersistentWarningStrength
            : 0.0;

        final borderStrength = widget.controller.isInvalid
            ? math.max(persistent, pulse).toDouble()
            : 0.0;

        final visual = AppValidationVisualState(
          shakeX: shakeX,
          borderStrength: borderStrength,
          isInvalid: widget.controller.isInvalid,
        );

        return Transform.translate(
          offset: Offset(shakeX, 0),
          child: widget.builder(context, visual),
        );
      },
    );
  }
}

// ==============================================================================
// 4. GLOBAL FEEDBACK SERVICE
// ==============================================================================

// Insertion and mounting are different OverlayEntry lifecycle states.
// Only this owner removes/disposes a successfully inserted Channel 1 entry.
class _TopPillOwnership {
  _TopPillOwnership(this.overlay, this.entry, this.key);

  final OverlayState overlay;
  final OverlayEntry entry;
  final GlobalKey<_TopBannerOverlayState> key;
  bool inserted = false;

  void remove() {
    if (!inserted) return;
    key.currentState?.cancelImmediately();
    entry.remove();
    inserted = false;
    entry.dispose();
  }
}

abstract final class AppFeedback {
  static _TopPresentation? _topPresentation;
  static _TopPillOwnership? _topOwner;
  static OverlayEntry? get _topEntry => _topOwner?.entry;
  static GlobalKey<_TopBannerOverlayState>? get _topKey => _topOwner?.key;

  static AppLiveFeedback? _live;
  static bool _topIsLive = false;
  static bool _livePresented = false;
  static bool _transientPending = false;

  static void showLive(AppLiveFeedback feedback) {
    final owner = _topOwner;
    if (owner != null && !owner.overlay.mounted) _removeTop(owner);
    final previous = _live;
    if (previous?.id == feedback.id &&
        previous?.message == feedback.message &&
        previous?.spinning == feedback.spinning &&
        previous?.reduceMotion == feedback.reduceMotion &&
        previous?.presentation == feedback.presentation &&
        previous?.tone == feedback.tone &&
        previous?.icon == feedback.icon &&
        previous?.terminal == feedback.terminal) {
      _resumeLive();
      return;
    }
    if (previous?.id != feedback.id ||
        previous?.message != feedback.message ||
        previous?.tone != feedback.tone ||
        previous?.terminal != feedback.terminal) {
      _livePresented = false;
    }
    _live = feedback;
    if (_topIsLive && _topOwner != null) {
      _publishTop(_TopPresentation.fromLive(feedback));
    } else {
      _topEntry?.markNeedsBuild();
      _resumeLive();
    }
  }

  static void _presentLive(AppLiveFeedback feedback) {
    if (_livePresented ||
        _live?.id != feedback.id ||
        _live?.message != feedback.message ||
        _live?.terminal != true) {
      return;
    }
    _livePresented = true;
    if (feedback.tone == AppTopFeedbackTone.success) {
      HapticFeedback.mediumImpact();
    }
    feedback.onPresented?.call();
  }

  static void dismissLive(String id) {
    if (_live?.id != id) return;
    _live = null;
    if (_topIsLive) unawaited(_dismissTop(immediate: true));
  }

  static void _resumeLive() {
    final owner = _topOwner;
    if (owner != null && !owner.overlay.mounted) {
      _removeTop(owner);
    }
    final live = _live;
    final overlay = _resolveCachedOverlay();
    if (live == null ||
        overlay == null ||
        _topEntry != null ||
        _transientPending ||
        _undoEntry != null) {
      return;
    }
    _insertTop(overlay,
        message: live.message, tone: live.tone, icon: live.icon, live: live);
  }

  static void _publishTop(_TopPresentation presentation) {
    _topPresentation = presentation;
    _topIsLive = presentation.live != null;
    final state = _topKey?.currentState;
    if (state != null) {
      state.present(presentation);
    } else {
      // The owner survives pre-mount swaps; its builder reads the latest model.
      _topEntry?.markNeedsBuild();
    }
  }

  static void _finishTopPresentation(_TopBannerOverlayState state) {
    if (!identical(_topKey?.currentState, state)) return;
    if (_topIsLive) {
      if (identical(_live, state._presentation.live)) _live = null;
    } else if (_live != null && _undoEntry == null) {
      // No exit/re-entry between transient hold and the latest live state.
      _publishTop(_TopPresentation.fromLive(_live!));
      return;
    }
    unawaited(state.dismiss());
  }

  static OverlayEntry? _undoEntry;
  static GlobalKey<_UndoDockOverlayState>? _undoKey;

  static OverlayState? _cachedRootOverlay;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static double _cachedPrimaryBottomObstruction = 0.0;
  static bool _primaryNavigationSeen = false;
  static int _requestEpoch = 0;

  static void attachNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay != null && overlay.mounted) {
      _cachedRootOverlay = overlay;
    }
  }

  static void capture(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay != null && overlay.mounted) {
      _cachedRootOverlay = overlay;
    }

    final hasPrimaryNavigation = _hasPrimaryNavigationAncestor(context);
    if (hasPrimaryNavigation) {
      _primaryNavigationSeen = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final route = ModalRoute.of(context);
      final isCurrentVisualRoute = route == null || route.isCurrent;
      if (!isCurrentVisualRoute) return;

      double sampledObstruction = 0.0;
      if (hasPrimaryNavigation) {
        sampledObstruction = _resolveBottomObstruction(context);
        if (sampledObstruction > 0.0) {
          _rememberPrimaryObstruction(sampledObstruction);
        }
      }

      final undoState = _undoKey?.currentState;
      if (undoState != null) {
        undoState._onVisualContextCaptured(
          hasPrimaryNavigation: hasPrimaryNavigation,
          sampledObstruction: sampledObstruction,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Channel 1: Top Banner API
  // ---------------------------------------------------------------------------

  static void showInfo(
      BuildContext context,
      String message, {
        bool emitHaptic = true,
        IconData icon = Icons.info_outline_rounded,
      }) {
    _showTopFromContext(
      context,
      message: message,
      tone: AppTopFeedbackTone.info,
      icon: icon,
      emitHaptic: emitHaptic,
    );
  }

  static void showSuccess(
      BuildContext context,
      String message, {
        bool emitHaptic = true,
        IconData icon = Icons.check_circle_rounded,
      }) {
    _showTopFromContext(
      context,
      message: message,
      tone: AppTopFeedbackTone.success,
      icon: icon,
      emitHaptic: emitHaptic,
    );
  }

  static void showError(
      BuildContext context,
      String message, {
        bool emitHaptic = true,
        IconData icon = Icons.error_outline_rounded,
      }) {
    _showTopFromContext(
      context,
      message: message,
      tone: AppTopFeedbackTone.error,
      icon: icon,
      emitHaptic: emitHaptic,
    );
  }

  static void showInfoWithMessenger(
      ScaffoldMessengerState messenger,
      String message, {
        bool emitHaptic = true,
        IconData icon = Icons.info_outline_rounded,
      }) {
    _showTopFromCachedOverlay(
      messenger,
      message: message,
      tone: AppTopFeedbackTone.info,
      icon: icon,
      emitHaptic: emitHaptic,
    );
  }

  static void showSuccessWithMessenger(
      ScaffoldMessengerState messenger,
      String message, {
        bool emitHaptic = true,
        IconData icon = Icons.check_circle_rounded,
      }) {
    _showTopFromCachedOverlay(
      messenger,
      message: message,
      tone: AppTopFeedbackTone.success,
      icon: icon,
      emitHaptic: emitHaptic,
    );
  }

  static void showErrorWithMessenger(
      ScaffoldMessengerState messenger,
      String message, {
        bool emitHaptic = true,
        IconData icon = Icons.error_outline_rounded,
      }) {
    _showTopFromCachedOverlay(
      messenger,
      message: message,
      tone: AppTopFeedbackTone.error,
      icon: icon,
      emitHaptic: emitHaptic,
    );
  }

  // ---------------------------------------------------------------------------
  // Channel 3: Undo Dock API
  // ---------------------------------------------------------------------------

  static void showUndo(
      BuildContext context, {
        required String message,
        required FutureOr<void> Function() onUndo,
        Color? actionColor,
        double? bottomObstruction,
      }) {
    capture(context);

    final overlay = _resolveOverlay(context);
    if (overlay == null) {
      debugPrint('AppFeedback.showUndo: no root Overlay found.');
      return;
    }

    final hasPrimaryNavigation = _hasPrimaryNavigationAncestor(context);
    var inferredObstruction = bottomObstruction ?? _resolveBottomObstruction(context);

    if (hasPrimaryNavigation) {
      _primaryNavigationSeen = true;
      if (inferredObstruction <= 0.0) {
        inferredObstruction = _preferredPrimaryObstruction();
      }
      if (inferredObstruction > 0.0) {
        _rememberPrimaryObstruction(inferredObstruction);
      }
    }

    _scheduleUndo(
      overlay,
      message: message,
      onUndo: onUndo,
      actionColor: actionColor,
      bottomObstruction: inferredObstruction,
      anchorContext: context,
      anchorRoute: ModalRoute.of(context),
      sourceHasPrimaryNavigation: hasPrimaryNavigation,
    );
  }

  static void showUndoWithMessenger(
      ScaffoldMessengerState messenger, {
        required String message,
        required FutureOr<void> Function() onUndo,
        Color? actionColor,
        double bottomObstruction = 0.0,
      }) {
    final overlay = _resolveOverlayFromMessenger(messenger);
    if (overlay == null) {
      debugPrint('AppFeedback.showUndoWithMessenger: no root Overlay found.');
      return;
    }

    final hasPrimaryNavigation =
        bottomObstruction > 0.0 || _hasPrimaryNavigationAncestor(messenger.context);
    var resolvedObstruction = bottomObstruction;

    if (hasPrimaryNavigation) {
      _primaryNavigationSeen = true;
      if (resolvedObstruction <= 0.0) {
        resolvedObstruction = _preferredPrimaryObstruction();
      }
      if (resolvedObstruction > 0.0) {
        _rememberPrimaryObstruction(resolvedObstruction);
      }
    }

    _scheduleUndo(
      overlay,
      message: message,
      onUndo: onUndo,
      actionColor: actionColor,
      bottomObstruction: resolvedObstruction,
      anchorContext: messenger.context,
      anchorRoute: ModalRoute.of(messenger.context),
      sourceHasPrimaryNavigation: hasPrimaryNavigation,
    );
  }

  // ---------------------------------------------------------------------------
  // Dismiss API
  // ---------------------------------------------------------------------------

  static void dismissCurrent(BuildContext context) {
    capture(context);
    _requestEpoch += 1;
    _transientPending = false;
    unawaited(_dismissForInteraction());
  }

  static void dismissCurrentWithMessenger(ScaffoldMessengerState messenger) {
    _resolveOverlayFromMessenger(messenger);
    _requestEpoch += 1;
    _transientPending = false;
    unawaited(_dismissForInteraction());
  }

  static void dismissImmediately() {
    _live = null;
    _transientPending = false;
    _requestEpoch += 1;
    unawaited(_dismissActiveOverlays(immediate: true));
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  static Future<void> _dismissForInteraction() async {
    final top = _topIsLive
        ? Future<void>.value()
        : _live != null && _topKey?.currentState != null
        ? Future<void>.sync(
            () => _finishTopPresentation(_topKey!.currentState!),
          )
        : _dismissTop();
    await Future.wait([top, _dismissUndo()]);
    _resumeLive();
  }

  static void _showTopFromContext(
    BuildContext context, {
    required String message,
    required AppTopFeedbackTone tone,
    required IconData icon,
    required bool emitHaptic,
  }) {
    capture(context);
    final overlay = _resolveOverlay(context);
    if (overlay == null) return;

    _scheduleTop(
      overlay,
      message: message,
      tone: tone,
      icon: icon,
      emitHaptic: emitHaptic,
    );
  }

  static void _showTopFromCachedOverlay(
    ScaffoldMessengerState messenger, {
    required String message,
    required AppTopFeedbackTone tone,
    required IconData icon,
    required bool emitHaptic,
  }) {
    final overlay = _resolveOverlayFromMessenger(messenger);
    if (overlay == null) return;

    _scheduleTop(overlay,
        message: message, tone: tone, icon: icon, emitHaptic: emitHaptic);
  }

  static void _scheduleTop(
    OverlayState overlay, {
    required String message,
    required AppTopFeedbackTone tone,
    required IconData icon,
    required bool emitHaptic,
  }) {
    final request = ++_requestEpoch;
    _transientPending = true;
    unawaited(() async {
      // Undo keeps its existing destructive replacement semantics. Channel 1
      // itself swaps models without releasing ownership or replaying entry.
      await _dismissUndo();
      if (request != _requestEpoch) return;
      _transientPending = false;
      if (!overlay.mounted) return;
      final presentation = _TopPresentation(
        message,
        tone,
        icon,
        emitHaptic: emitHaptic,
      );
      if (_topOwner?.overlay == overlay && _topOwner!.inserted) {
        _publishTop(presentation);
      } else {
        _insertTop(
          overlay,
          message: message,
          tone: tone,
          icon: icon,
          presentation: presentation,
        );
      }
    }());
  }

  static void _removeTop(_TopPillOwnership owner) {
    owner.remove();
    if (!identical(_topOwner, owner)) return;
    _topOwner = null;
    _topPresentation = null;
    _topIsLive = false;
  }

  static void _insertTop(
    OverlayState overlay, {
    required String message,
    required AppTopFeedbackTone tone,
    required IconData icon,
    AppLiveFeedback? live,
    _TopPresentation? presentation,
  }) {
    if (!overlay.mounted) return;
    final prior = _topOwner;
    if (prior != null) _removeTop(prior);
    final key = GlobalKey<_TopBannerOverlayState>();
    _topPresentation =
        presentation ??
        (live != null
            ? _TopPresentation.fromLive(live)
            : _TopPresentation(message, tone, icon));
    late final _TopPillOwnership owner;
    final entry = OverlayEntry(
      builder: (_) => _TopBannerOverlay(
        key: key,
        presentation: _topPresentation!,
        onClosed: () {
          // A replaced entry must never clear/resume the current entry's state.
          if (!identical(_topOwner, owner) || !owner.inserted) return;
          final completedLive =
              _topIsLive &&
              _live?.terminal == true &&
              identical(_live, key.currentState?._presentation.live) &&
              key.currentState?.completedHold == true;
          _removeTop(owner);
          if (completedLive) _live = null;
          _resumeLive();
        },
      ),
    );
    owner = _TopPillOwnership(overlay, entry, key);
    // Publish ownership only after insert succeeds. An unavailable overlay or
    // failed insertion must not lead to remove() on an uninserted entry.
    try {
      overlay.insert(entry);
    } on FlutterError {
      return;
    }
    owner.inserted = true;
    _topOwner = owner;
    _topIsLive = live != null;
  }

  static void _scheduleUndo(
    OverlayState overlay, {
    required String message,
    required FutureOr<void> Function() onUndo,
    required Color? actionColor,
    required double bottomObstruction,
    required BuildContext? anchorContext,
    required ModalRoute<dynamic>? anchorRoute,
    required bool sourceHasPrimaryNavigation,
  }) {
    final request = ++_requestEpoch;
    _transientPending = true;

    unawaited(() async {
      await _dismissActiveOverlays(immediate: true);
      if (request != _requestEpoch || !overlay.mounted) return;
      _transientPending = false;

      _insertUndo(
        overlay,
        message: message,
        onUndo: onUndo,
        actionColor: actionColor,
        bottomObstruction: bottomObstruction,
        anchorContext: anchorContext,
        anchorRoute: anchorRoute,
        sourceHasPrimaryNavigation: sourceHasPrimaryNavigation,
      );
    }());
  }

  static void _insertUndo(
    OverlayState overlay, {
    required String message,
    required FutureOr<void> Function() onUndo,
    required Color? actionColor,
    required double bottomObstruction,
    required BuildContext? anchorContext,
    required ModalRoute<dynamic>? anchorRoute,
    required bool sourceHasPrimaryNavigation,
  }) {
    final key = GlobalKey<_UndoDockOverlayState>();
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _UndoDockOverlay(
        key: key,
        message: message,
        onUndo: onUndo,
        actionColor: actionColor,
        bottomObstruction: bottomObstruction,
        anchorContext: anchorContext,
        anchorRoute: anchorRoute,
        sourceHasPrimaryNavigation: sourceHasPrimaryNavigation,
        onClosed: () {
          if (entry.mounted) entry.remove();
          if (identical(_undoEntry, entry)) {
            _undoEntry = null;
            _undoKey = null;
            _resumeLive();
          }
        },
      ),
    );

    _undoEntry = entry;
    _undoKey = key;
    overlay.insert(entry);
  }

  static Future<void> _dismissActiveOverlays({bool immediate = false}) async {
    final topFuture = _dismissTop(immediate: immediate);
    final undoFuture = _dismissUndo(immediate: immediate);
    await Future.wait([topFuture, undoFuture]);
  }

  static Future<void> _dismissTop({bool immediate = false}) async {
    final owner = _topOwner;
    if (owner == null) return;
    final state = owner.key.currentState;
    if (immediate || state == null) {
      _removeTop(owner);
      return;
    }
    await state.dismiss();
  }

  static Future<void> _dismissUndo({bool immediate = false}) async {
    final entry = _undoEntry;
    final state = _undoKey?.currentState;
    if (entry == null) return;

    if (immediate || state == null) {
      if (entry.mounted) entry.remove();
      if (identical(_undoEntry, entry)) {
        _undoEntry = null;
        _undoKey = null;
      }
      return;
    }
    await state.dismiss();
  }

  static OverlayState? _resolveOverlay(BuildContext context) {
    final direct = Overlay.maybeOf(context, rootOverlay: true);
    if (direct != null && direct.mounted) {
      _cachedRootOverlay = direct;
      return direct;
    }
    return _resolveCachedOverlay();
  }

  static OverlayState? _resolveOverlayFromMessenger(ScaffoldMessengerState messenger) {
    final direct = Overlay.maybeOf(messenger.context, rootOverlay: true);
    if (direct != null && direct.mounted) {
      _cachedRootOverlay = direct;
      return direct;
    }
    return _resolveCachedOverlay();
  }

  static OverlayState? _resolveCachedOverlay() {
    final navigatorOverlay = _navigatorKey?.currentState?.overlay;
    if (navigatorOverlay != null && navigatorOverlay.mounted) {
      _cachedRootOverlay = navigatorOverlay;
      return navigatorOverlay;
    }

    final cached = _cachedRootOverlay;
    if (cached != null && cached.mounted) {
      return cached;
    }

    _cachedRootOverlay = null;
    return null;
  }

  static bool _hasPrimaryNavigationAncestor(BuildContext context) {
    var found = false;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is Scaffold &&
          (widget.bottomNavigationBar != null || widget.floatingActionButton != null)) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  static void _rememberPrimaryObstruction(double obstruction) {
    if (!obstruction.isFinite || obstruction <= 0.0) return;
    _primaryNavigationSeen = true;
    _cachedPrimaryBottomObstruction = obstruction;

    final state = _undoKey?.currentState;
    if (state != null) {
      state._onPrimaryObstructionRefreshed(obstruction);
    }
  }

  static double _preferredPrimaryObstruction() {
    if (_cachedPrimaryBottomObstruction > 0.0) {
      return _cachedPrimaryBottomObstruction;
    }
    if (_primaryNavigationSeen) {
      return AppFeedbackTokens.undoPrimaryFallbackObstruction;
    }
    return 0.0;
  }

  static double _resolveBottomObstruction(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return 0.0;

    final scaffoldState = Scaffold.maybeOf(context);
    if (scaffoldState == null) return 0.0;

    try {
      final geometry = Scaffold.geometryOf(context).value;
      final localTopCandidates = <double>[];

      final navTop = geometry.bottomNavigationBarTop;
      if (navTop != null && navTop.isFinite) {
        localTopCandidates.add(navTop);
      }

      final fabArea = geometry.floatingActionButtonArea;
      if (fabArea != null && !fabArea.isEmpty && fabArea.top.isFinite) {
        localTopCandidates.add(fabArea.top);
      }

      if (localTopCandidates.isEmpty) return 0.0;

      final scaffoldBox = scaffoldState.context.findRenderObject() as RenderBox?;
      final rootOverlay = Overlay.maybeOf(context, rootOverlay: true);
      final overlayBox = rootOverlay?.context.findRenderObject() as RenderBox?;

      if (scaffoldBox == null ||
          overlayBox == null ||
          !scaffoldBox.hasSize ||
          !overlayBox.hasSize) {
        final highestLocalTop = localTopCandidates.reduce(math.min);
        return math.max(0.0, media.size.height - highestLocalTop).toDouble();
      }

      final overlayGlobalOrigin = overlayBox.localToGlobal(Offset.zero);
      double highestOverlayTop = double.infinity;

      for (final localTop in localTopCandidates) {
        final globalPoint = scaffoldBox.localToGlobal(Offset(0, localTop));
        final overlayY = globalPoint.dy - overlayGlobalOrigin.dy;
        highestOverlayTop = math.min(highestOverlayTop, overlayY);
      }

      if (!highestOverlayTop.isFinite) return 0.0;
      return math.max(0.0, overlayBox.size.height - highestOverlayTop).toDouble();
    } catch (_) {
      return 0.0;
    }
  }
}

// ==============================================================================
// 5. OPTIONAL SCREEN WRAPPER
// ==============================================================================

class AppFeedbackDismissRegion extends StatelessWidget {
  final Widget child;

  const AppFeedbackDismissRegion({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    AppFeedback.capture(context);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => AppFeedback.dismissCurrent(context),
      child: child,
    );
  }
}

// ==============================================================================
// 6. CHANNEL 1 OVERLAY (SAFE-AREA TOP BANNER PILL)
// ==============================================================================

@immutable
class _TopPresentation {
  const _TopPresentation(
    this.message,
    this.tone,
    this.icon, {
    this.live,
    this.emitHaptic = true,
  });
  factory _TopPresentation.fromLive(AppLiveFeedback live) =>
      _TopPresentation(live.message, live.tone, live.icon, live: live);
  final String message;
  final AppTopFeedbackTone tone;
  final IconData icon;
  final AppLiveFeedback? live;
  final bool emitHaptic;
  String get category =>
      live?.presentation == AppLiveFeedbackPresentation.ambientBackup
      ? 'ĐỒNG BỘ CLOUD'
      : switch (tone) {
          AppTopFeedbackTone.success => 'THÀNH CÔNG',
          AppTopFeedbackTone.info => 'THÔNG BÁO',
          AppTopFeedbackTone.error => 'CẦN CHÚ Ý',
        };
  bool get persistent => live != null && !live!.terminal;
}

class _TopBannerOverlay extends StatefulWidget {
  const _TopBannerOverlay({
    super.key,
    required this.presentation,
    required this.onClosed,
  });
  final _TopPresentation presentation;
  final VoidCallback onClosed;
  @override
  State<_TopBannerOverlay> createState() => _TopBannerOverlayState();
}

enum _TopMotionPhase {
  drop,
  expand,
  resting,
  contentMorph,
  collapse,
  anticipate,
  launch,
}

typedef _TopPose = ({double y, double sx, double sy, double opacity});

class _TopBannerOverlayState extends State<_TopBannerOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entryController,
      _morphController,
      _exitController;
  late _TopPresentation _presentation;
  Timer? _holdTimer, _readyTimer, _exitTimer;
  bool completedHold = false;
  bool _shown = false, _entered = false, _closing = false, _closed = false;
  bool _ready = true, _impactDelivered = false, _exitImpactDelivered = false;
  bool _successPending = false,
      _selectionPending = false,
      _mediaReduced = false;
  int _generation = 0;
  double _targetWidth = 42, _maxWidth = 520, _hudHeight = 42;
  double _labelHeight = 12,
      _statusHeight = 15,
      _morphFrom = 42,
      _exitWidth = 42,
      _exitHeight = 42;
  _TopPose? _recoveryFrom, _exitOrigin;
  Completer<void>? _dismissCompleter;
  String? get liveId => _presentation.live?.id;
  bool get _reduced =>
      _mediaReduced || (_presentation.live?.reduceMotion ?? false);
  double get _circleWidth => math.min(42, _maxWidth);
  double get _minimumWidth => math.min(84, _maxWidth);
  double _ms(AnimationController controller, int duration) =>
      (controller.value * duration * 1000).round() / 1000;
  double _mix(double a, double b, double t) => a + (b - a) * t;
  double _clampWidth(double width) =>
      width.clamp(_circleWidth, _maxWidth).toDouble();
  _TopMotionPhase get _phase {
    if (_closing) {
      final ms = _ms(_exitController, 270);
      return ms <= 110
          ? _TopMotionPhase.collapse
          : ms <= 160
          ? _TopMotionPhase.anticipate
          : _TopMotionPhase.launch;
    }
    if (!_entered) {
      return _ms(_entryController, 500) <= 240
          ? _TopMotionPhase.drop
          : _TopMotionPhase.expand;
    }
    return _morphController.isAnimating
        ? _TopMotionPhase.contentMorph
        : _TopMotionPhase.resting;
  }

  @override
  void initState() {
    super.initState();
    _presentation = widget.presentation;
    _successPending = _presentation.tone == AppTopFeedbackTone.success;
    _entryController =
        AppAnimationPolicy.createController(
            vsync: this,
            duration: AppFeedbackTokens.topBannerEnterDuration,
            debugLabel: 'TopPill.circleDropExpand',
          )
          ..addListener(() {
            if (!_closed &&
                !_closing &&
                !_reduced &&
                !_impactDelivered &&
                _ms(_entryController, 500) >= 130) {
              _impactDelivered = true;
              if (_presentation.emitHaptic) HapticFeedback.lightImpact();
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _finishEntry();
          });
    _morphController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      debugLabel: 'TopPill.elasticWidth',
    );
    _exitController =
        AppAnimationPolicy.createController(
          vsync: this,
          duration: AppFeedbackTokens.topBannerExitDuration,
          debugLabel: 'TopPill.collapseSquashLaunch',
        )..addListener(() {
          if (_closing &&
              !_closed &&
              !_reduced &&
              !_exitImpactDelivered &&
              _ms(_exitController, 270) >= 160) {
            _exitImpactDelivered = true;
            if (_presentation.emitHaptic) HapticFeedback.lightImpact();
          }
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _closed || _closing) return;
      _shown = true;
      if (_reduced) {
        _finishEntry();
      } else {
        _entryController.forward();
      }
    });
  }

  ({TextStyle label, TextStyle status}) _styles() {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium ?? const TextStyle();
    return (
      label: base.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: .5,
        height: 1.2,
        color: theme.brightness == Brightness.dark
            ? Colors.white70
            : theme.colorScheme.onSurfaceVariant,
        decoration: TextDecoration.none,
      ),
      status: base.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        letterSpacing: .12,
        height: 1.2,
        color: theme.colorScheme.onSurface,
        decoration: TextDecoration.none,
      ),
    );
  }

  // Cached once per presentation/dependency change. Ticker frames interpolate
  // numeric geometry only; no intrinsic/offstage tree or TextPainter loop.
  void _measure() {
    final media = MediaQuery.of(context);
    _maxWidth = math.max(
      0,
      math.min(
        AppFeedbackTokens.topBannerMaxWidth,
        media.size.width -
            AppFeedbackTokens.topBannerHorizontalScreenMargin * 2,
      ),
    );
    final styles = _styles();
    double width(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: media.textScaler,
        locale: Localizations.maybeLocaleOf(context),
        maxLines: 1,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    _labelHeight = media.textScaler.scale(10) * 1.2;
    _statusHeight = media.textScaler.scale(12.5) * 1.2;
    _hudHeight = math.max(42, 8 + _labelHeight + _statusHeight);
    _targetWidth =
        (60 +
                math.max(
                  width(_presentation.category, styles.label),
                  width(_presentation.message, styles.status),
                ))
            .clamp(_minimumWidth, _maxWidth)
            .toDouble();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mediaReduced = MediaQuery.disableAnimationsOf(context);
    _measure();
    if (_reduced && !_closing) {
      _entryController.stop();
      _morphController.stop();
      _finishEntry();
    }
  }

  void _finishEntry() {
    if (!mounted || _closed || _closing || !_shown || _entered) return;
    _entered = true;
    if (_reduced) {
      _impactDelivered = true;
      _entryController.value = 1;
    }
    _settledPresentation();
  }

  bool _sameVisual(_TopPresentation a, _TopPresentation b) =>
      a.message == b.message &&
      a.category == b.category &&
      a.tone == b.tone &&
      a.icon == b.icon &&
      a.live?.spinning == b.live?.spinning &&
      a.live?.terminal == b.live?.terminal &&
      a.live?.id == b.live?.id &&
      a.live?.reduceMotion == b.live?.reduceMotion;

  void present(_TopPresentation value) {
    if (!mounted ||
        _closed ||
        (!_closing && _sameVisual(_presentation, value))) {
      return;
    }
    final old = _presentation;
    final targetY = MediaQuery.paddingOf(context).top + 12;
    final currentWidth = _width;
    final currentPose = _pose(targetY);
    final epoch = ++_generation;
    _holdTimer?.cancel();
    _readyTimer?.cancel();
    _exitTimer?.cancel();
    completedHold = false;
    if (_closing) {
      _exitController.stop();
      _closing = false;
      _shown = _entered = true;
      _impactDelivered = true;
      _entryController.value = 1;
      // Even after launch starts, recover the same owned entry from its current
      // pose. No second shell, screen drop replay, or stale removal/haptic.
      _recoveryFrom = currentPose;
      final completer = _dismissCompleter;
      _dismissCompleter = null;
      if (completer != null && !completer.isCompleted) completer.complete();
    } else {
      _recoveryFrom = null;
    }
    if (!_entered && _ms(_entryController, 500) > 240) {
      // Retarget an expansion from its actual shell width instead of jumping
      // to a newly measured keyframe. The already-settled drop is not replayed.
      _entered = true;
      _entryController.stop();
      _entryController.value = 1;
    }
    _successPending =
        value.tone == AppTopFeedbackTone.success &&
        old.tone != AppTopFeedbackTone.success;
    _selectionPending =
        value.tone == AppTopFeedbackTone.info &&
        !(value.live?.terminal ?? false);
    setState(() {
      _presentation = value;
      _ready = _reduced;
    });
    _measure();
    _morphFrom = currentWidth;
    if (_reduced) {
      _entryController.stop();
      _morphController.stop();
      _morphController.value = 1;
      _finishEntry();
      _settledPresentation();
    } else {
      if (_entered) _morphController.forward(from: 0);
      _readyTimer = Timer(const Duration(milliseconds: 240), () {
        if (!mounted || _closed || _closing || epoch != _generation) return;
        _ready = true;
        _settledPresentation();
      });
    }
  }

  void _settledPresentation() {
    if (!_entered || !_ready || _closed || _closing) return;
    final live = _presentation.live;
    if (live?.terminal == true) {
      AppFeedback._presentLive(live!);
    } else if (_successPending && _presentation.emitHaptic) {
      HapticFeedback.mediumImpact();
    } else if (_selectionPending && !_reduced && _presentation.emitHaptic) {
      HapticFeedback.selectionClick();
    }
    _successPending = _selectionPending = false;
    if (_presentation.persistent) return;
    _holdTimer?.cancel();
    final epoch = _generation;
    _holdTimer = Timer(
      _presentation.tone == AppTopFeedbackTone.success
          ? AppFeedbackTokens.topBannerSuccessHoldDuration
          : AppFeedbackTokens.topBannerHoldDuration,
      () {
        if (_closed || _closing || epoch != _generation) return;
        completedHold = true;
        AppFeedback._finishTopPresentation(this);
      },
    );
  }

  double get _width {
    if (_reduced) return _closing ? _circleWidth : _targetWidth;
    if (_closing) {
      return _clampWidth(
        _mix(
          _exitWidth,
          _circleWidth,
          Curves.easeInOutCubic.transform(
            (_ms(_exitController, 270) / 110).clamp(0, 1),
          ),
        ),
      );
    }
    if (!_entered) {
      final ms = _ms(_entryController, 500) - 240;
      if (ms <= 0) return _circleWidth;
      if (ms <= 150) {
        return _clampWidth(
          _mix(
            _circleWidth,
            math.min(_targetWidth + 18, _maxWidth),
            Curves.easeOutCubic.transform(ms / 150),
          ),
        );
      }
      if (ms <= 220) {
        return _clampWidth(
          _mix(
            math.min(_targetWidth + 18, _maxWidth),
            math.max(_minimumWidth, _targetWidth - 4),
            Curves.easeInOutCubic.transform((ms - 150) / 70),
          ),
        );
      }
      return _clampWidth(
        _mix(
          math.max(_minimumWidth, _targetWidth - 4),
          _targetWidth,
          Curves.easeOutCubic.transform((ms - 220) / 40),
        ),
      );
    }
    if (_morphController.isAnimating ||
        _morphController.value < 1 && _ready == false) {
      final ms = _ms(_morphController, 240);
      final peak = _targetWidth > _morphFrom
          ? math.min(_targetWidth + 10, _maxWidth)
          : _targetWidth < _morphFrom
          ? math.max(_targetWidth - 8, _minimumWidth)
          : _targetWidth;
      return _clampWidth(
        ms <= 140
            ? _mix(_morphFrom, peak, Curves.easeOutQuad.transform(ms / 140))
            : _mix(
                peak,
                _targetWidth,
                Curves.easeInOutCubic.transform((ms - 140) / 100),
              ),
      );
    }
    return _targetWidth;
  }

  double get _reveal {
    if (_reduced) return _closing ? 0 : 1;
    if (_closing) return 1 - (_ms(_exitController, 270) / 60).clamp(0, 1);
    if (!_entered) {
      return Curves.easeOutQuad.transform(
        ((_ms(_entryController, 500) - 360) / 140).clamp(0, 1),
      );
    }
    if (_recoveryFrom != null) {
      return Curves.easeOutQuad.transform(_morphController.value);
    }
    return 1;
  }

  double get _height {
    if (_closing) {
      return _mix(
        _exitHeight,
        42,
        (_ms(_exitController, 270) / 110).clamp(0, 1),
      );
    }
    if (!_entered && !_reduced) {
      return _mix(
        42,
        _hudHeight,
        ((_ms(_entryController, 500) - 240) / 260).clamp(0, 1),
      );
    }
    return _hudHeight;
  }

  _TopPose _pose(double target) {
    if (_reduced) return (y: target, sx: 1, sy: 1, opacity: 1);
    if (_closing) {
      final ms = _ms(_exitController, 270);
      if (ms <= 110) {
        final t = Curves.easeInOutCubic.transform(ms / 110);
        final origin = _exitOrigin!;
        return (
          y: _mix(origin.y, target, t),
          sx: _mix(origin.sx, 1, t),
          sy: _mix(origin.sy, 1, t),
          opacity: origin.opacity,
        );
      }
      if (ms <= 160) {
        final t = Curves.easeInQuad.transform((ms - 110) / 50);
        return (
          y: target + 3 * t,
          sx: _mix(1, 46 / 42, t),
          sy: _mix(1, 36 / 42, t),
          opacity: 1,
        );
      }
      final t = Curves.fastOutSlowIn.transform((ms - 160) / 110);
      return (
        y: _mix(target + 3, -60, t),
        sx: _mix(46 / 42, 38 / 42, t),
        sy: _mix(36 / 42, 46 / 42, t),
        opacity: 1 - t,
      );
    }
    if (_recoveryFrom != null) {
      final origin = _recoveryFrom!;
      final t = Curves.easeOutCubic.transform(_morphController.value);
      return (
        y: _mix(origin.y, target, t),
        sx: _mix(origin.sx, 1, t),
        sy: _mix(origin.sy, 1, t),
        opacity: _mix(origin.opacity, 1, t),
      );
    }
    final ms = _ms(_entryController, 500);
    if (_entered || ms >= 240) return (y: target, sx: 1, sy: 1, opacity: 1);
    if (ms <= 130) {
      final t = Curves.easeInQuad.transform(ms / 130);
      return (
        y: _mix(-30, target + 12, t),
        sx: 1,
        sy: _mix(1, 1.05, t),
        opacity: 1,
      );
    }
    if (ms <= 190) {
      final t = Curves.easeOutCubic.transform((ms - 130) / 60);
      return (
        y: _mix(target + 12, target - 3, t),
        sx: 1,
        sy: _mix(1.05, .96, t),
        opacity: 1,
      );
    }
    final t = Curves.easeInOutSine.transform((ms - 190) / 50);
    return (
      y: _mix(target - 3, target, t),
      sx: 1,
      sy: _mix(.96, 1, t),
      opacity: 1,
    );
  }

  Future<void> dismiss() {
    if (_closed) return Future.value();
    if (_dismissCompleter != null) return _dismissCompleter!.future;
    final completer = Completer<void>();
    _dismissCompleter = completer;
    final epoch = ++_generation;
    _holdTimer?.cancel();
    _readyTimer?.cancel();
    _exitWidth = _width;
    _exitHeight = _height;
    _exitOrigin = _pose(MediaQuery.paddingOf(context).top + 12);
    _entryController.stop();
    _morphController.stop();
    _exitImpactDelivered = false;
    setState(() => _closing = true);
    if (!_reduced) _exitController.forward(from: 0);
    _exitTimer = Timer(
      _reduced ? Duration.zero : AppFeedbackTokens.topBannerExitDuration,
      () {
        if (_closed || !_closing || epoch != _generation) return;
        _closed = true;
        widget.onClosed();
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  void cancelImmediately() {
    _closed = _closing = true;
    _generation++;
    _holdTimer?.cancel();
    _readyTimer?.cancel();
    _exitTimer?.cancel();
    _entryController.stop();
    _morphController.stop();
    _exitController.stop();
    if (!(_dismissCompleter?.isCompleted ?? true)) {
      _dismissCompleter?.complete();
    }
  }

  @override
  void dispose() {
    cancelImmediately();
    _entryController.dispose();
    _morphController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  Widget _indicator(Color foreground, Color muted) {
    if (_presentation.live?.spinning == true) {
      return SizedBox(
        width: 13,
        height: 13,
        child: CircularProgressIndicator(
          strokeWidth: 1.8,
          color: foreground,
          value: _reduced ? .75 : null,
        ),
      );
    }
    final tone = _presentation.tone;
    final icon = Icon(
      _presentation.icon,
      size: tone == AppTopFeedbackTone.info ? 14 : 15,
      color: tone == AppTopFeedbackTone.success
          ? const Color(0xFF34D399)
          : tone == AppTopFeedbackTone.error
          ? AppTokens.expense
          : muted,
    );
    return tone == AppTopFeedbackTone.success && !_reduced
        ? _TopSuccessGlyph(child: icon)
        : icon;
  }

  Widget _content(
    double physicalWidth,
    TextStyle labelStyle,
    TextStyle statusStyle,
    Color foreground,
    Color muted,
  ) {
    // One HUD tree at its measured target width. Only the shell width changes;
    // type stays unscaled. Text is invisible until expansion has room for it.
    final width = math.max(_targetWidth, physicalWidth);
    final identity = ValueKey((
      _presentation.message,
      _presentation.icon,
      _presentation.tone,
      _presentation.live?.spinning,
    ));
    final circle = _phase == _TopMotionPhase.drop;
    final progress = circle
        ? 0.0
        : _closing
        ? (1 - (_ms(_exitController, 270) / 110).clamp(0, 1))
        : !_entered
        ? ((_ms(_entryController, 500) - 240) / 150).clamp(0, 1)
        : 1.0;
    final glyphLeft = _mix((physicalWidth - 24) / 2, 14, progress.toDouble());
    final unit = SizedBox(
      key: identity,
      width: width,
      height: _hudHeight - 8,
      child: Stack(
        children: [
          Positioned(
            left: glyphLeft,
            top: (_hudHeight - 8 - 24) / 2,
            width: 24,
            height: 24,
            child: Center(child: _indicator(foreground, muted)),
          ),
          Positioned(
            left: 46,
            right: 14,
            top:
                (_hudHeight - 8 - _labelHeight - _statusHeight) / 2 +
                _labelHeight,
            child: Opacity(
              opacity: _reveal,
              child: Text(
                _presentation.message,
                style: statusStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
    final reel = _reduced
        ? unit
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 130),
            reverseDuration: const Duration(milliseconds: 90),
            switchInCurve: Curves.easeOutQuad,
            switchOutCurve: Curves.linear,
            layoutBuilder: (current, old) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                for (final previous in old)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: previous,
                    ),
                  ),
                if (current != null) current,
              ],
            ),
            transitionBuilder: (child, animation) {
              final incoming = child.key == identity;
              // Delay the incoming fade until outgoing text is no longer readable.
              final fade = animation.drive(
                CurveTween(
                  curve: incoming
                      ? const Interval(.9, 1)
                      : const Interval(.25, 1),
                ),
              );
              return FadeTransition(
                opacity: fade,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(0, incoming ? .8 : -.8),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: unit,
          );
    return OverflowBox(
      alignment: Alignment.centerLeft,
      minWidth: width,
      maxWidth: width,
      minHeight: _hudHeight,
      maxHeight: _hudHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Positioned(
              left: 46,
              right: 14,
              top: (_hudHeight - 8 - _labelHeight - _statusHeight) / 2,
              child: Opacity(
                opacity: _reveal,
                child: Text(
                  _presentation.category,
                  key: const ValueKey('top.category'),
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            reel,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final styles = _styles();
    final radius = BorderRadius.circular(999);
    return AnimatedBuilder(
      animation: Listenable.merge([
        _entryController,
        _morphController,
        _exitController,
      ]),
      builder: (context, child) {
        final pose = _pose(media.padding.top + 12);
        final width = _width;
        final glass = DecoratedBox(
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xE01A2620)
                : Colors.white.withValues(alpha: .88),
            borderRadius: radius,
            border: Border.all(
              width: .8,
              color: dark
                  ? Colors.white.withValues(alpha: .12)
                  : Colors.black.withValues(alpha: .06),
            ),
          ),
          child: _content(
            width,
            styles.label,
            styles.status,
            theme.colorScheme.onSurface,
            dark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
          ),
        );
        final surface = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? .35 : .08),
                blurRadius: dark ? 20 : 18,
                offset: Offset(0, dark ? 8 : 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: glass,
            ),
          ),
        );
        final capsule = IgnorePointer(
          ignoring: true,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: _height,
              child: Material(
                type: MaterialType.transparency,
                child: Semantics(
                  liveRegion: true,
                  label: '${_presentation.category}. ${_presentation.message}',
                  child: ExcludeSemantics(child: surface),
                ),
              ),
            ),
          ),
        );
        return Positioned(
          top: pose.y,
          left: AppFeedbackTokens.topBannerHorizontalScreenMargin,
          right: AppFeedbackTokens.topBannerHorizontalScreenMargin,
          child: Opacity(
            opacity: pose.opacity,
            child: Transform.scale(
              scaleX: pose.sx,
              scaleY: pose.sy,
              alignment: Alignment.center,
              child: capsule,
            ),
          ),
        );
      },
    );
  }
}
class _TopSuccessGlyph extends StatefulWidget {
  const _TopSuccessGlyph({required this.child});
  final Widget child;
  @override
  State<_TopSuccessGlyph> createState() => _TopSuccessGlyphState();
}

class _TopSuccessGlyphState extends State<_TopSuccessGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      debugLabel: 'TopPill.successGlyph',
    )..forward();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (_, child) {
      final value = _controller.value;
      final scale = value <= .5
          ? .85 + .25 * Curves.easeOutQuad.transform(value * 2)
          : 1.1 - .1 * Curves.easeOutCubic.transform((value - .5) * 2);
      return Transform.scale(scale: scale, child: child);
    },
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
// ==============================================================================
// 7. CHANNEL 3 OVERLAY (DYNAMIC BOTTOM UNDO DOCK)
// ==============================================================================

class _UndoDockOverlay extends StatefulWidget {
  final String message;
  final FutureOr<void> Function() onUndo;
  final Color? actionColor;
  final double bottomObstruction;
  final BuildContext? anchorContext;
  final ModalRoute<dynamic>? anchorRoute;
  final bool sourceHasPrimaryNavigation;
  final VoidCallback onClosed;

  const _UndoDockOverlay({
    super.key,
    required this.message,
    required this.onUndo,
    required this.actionColor,
    required this.bottomObstruction,
    required this.anchorContext,
    required this.anchorRoute,
    required this.sourceHasPrimaryNavigation,
    required this.onClosed,
  });

  @override
  State<_UndoDockOverlay> createState() => _UndoDockOverlayState();
}

class _UndoDockOverlayState extends State<_UndoDockOverlay> with TickerProviderStateMixin {
  late final AnimationController _lifecycleController;
  late final AnimationController _countdownController;
  late final AnimationController _anchorController;

  bool _closing = false;
  bool _exiting = false;
  bool _closed = false;
  bool _dragging = false;

  Offset _dragOffset = Offset.zero;
  double _exitStartOpacity = 1.0;
  Offset _exitStartOffset = Offset.zero;
  Offset _exitTargetOffset = const Offset(0, AppFeedbackTokens.undoExitTravel);

  double _anchorFromFraction = 0.0;
  double _anchorToFraction = 0.0;
  bool _anchorRaising = false;
  bool _wantsPrimaryAnchor = false;
  double _primaryBottomObstruction = 0.0;

  Animation<double>? _sourceRouteAnimation;
  Animation<double>? _sourceSecondaryAnimation;
  Completer<void>? _dismissCompleter;

  @override
  void initState() {
    super.initState();

    _lifecycleController = AnimationController(
      vsync: this,
      duration: AppFeedbackTokens.undoEnterDuration,
      animationBehavior: AnimationBehavior.preserve,
      debugLabel: 'AppFeedback.undoDock.lifecycle',
    );

    _countdownController = AnimationController(
      vsync: this,
      duration: AppFeedbackTokens.undoDuration,
      animationBehavior: AnimationBehavior.preserve,
      debugLabel: 'AppFeedback.undoDock.countdown',
    );

    _anchorController = AnimationController(
      vsync: this,
      duration: AppFeedbackTokens.undoAnchorRaiseDuration,
      value: 1.0,
      animationBehavior: AnimationBehavior.preserve,
      debugLabel: 'AppFeedback.undoDock.anchor',
    );

    _wantsPrimaryAnchor = widget.sourceHasPrimaryNavigation;
    _anchorFromFraction = _wantsPrimaryAnchor ? 1.0 : 0.0;
    _anchorToFraction = _anchorFromFraction;
    _primaryBottomObstruction = widget.bottomObstruction > 0.0
        ? widget.bottomObstruction
        : AppFeedback._preferredPrimaryObstruction();

    _attachRouteListeners();
    unawaited(_runLifecycle());
  }

  void _attachRouteListeners() {
    final route = widget.anchorRoute;
    if (route == null) return;

    _sourceRouteAnimation = route.animation;
    _sourceSecondaryAnimation = route.secondaryAnimation;

    _sourceRouteAnimation?.addStatusListener(_handleRouteAnimationStatus);
    _sourceSecondaryAnimation?.addStatusListener(_handleSecondaryAnimationStatus);
  }

  void _detachRouteListeners() {
    _sourceRouteAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _sourceSecondaryAnimation?.removeStatusListener(_handleSecondaryAnimationStatus);
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    if (_closing) return;
    if (!widget.sourceHasPrimaryNavigation && status == AnimationStatus.reverse) {
      final primary = AppFeedback._preferredPrimaryObstruction();
      if (primary > 0.0) {
        _primaryBottomObstruction = primary;
        _setPrimaryAnchorVisible(true);
      }
    }
  }

  void _handleSecondaryAnimationStatus(AnimationStatus status) {
    if (_closing || !widget.sourceHasPrimaryNavigation) return;

    if (status == AnimationStatus.forward || status == AnimationStatus.completed) {
      _setPrimaryAnchorVisible(false);
      return;
    }

    if (status == AnimationStatus.reverse || status == AnimationStatus.dismissed) {
      final live = _resolveLivePrimaryObstruction();
      if (live > 0.0) {
        _primaryBottomObstruction = live;
        AppFeedback._rememberPrimaryObstruction(live);
      }
      _setPrimaryAnchorVisible(true);
    }
  }

  double _resolveLivePrimaryObstruction() {
    final source = widget.anchorContext;
    if (source == null || !source.mounted) {
      return AppFeedback._preferredPrimaryObstruction();
    }
    final resolved = AppFeedback._resolveBottomObstruction(source);
    if (resolved > 0.0) return resolved;
    return AppFeedback._preferredPrimaryObstruction();
  }

  void _onVisualContextCaptured({
    required bool hasPrimaryNavigation,
    required double sampledObstruction,
  }) {
    if (!mounted || _closing) return;

    if (hasPrimaryNavigation) {
      if (sampledObstruction > 0.0) {
        _primaryBottomObstruction = sampledObstruction;
      } else {
        final fallback = AppFeedback._preferredPrimaryObstruction();
        if (fallback > 0.0) {
          _primaryBottomObstruction = fallback;
        }
      }
    }

    _setPrimaryAnchorVisible(hasPrimaryNavigation);
  }

  void _onPrimaryObstructionRefreshed(double obstruction) {
    if (!mounted || _closing || obstruction <= 0.0) return;
    _primaryBottomObstruction = obstruction;
    if (_wantsPrimaryAnchor) {
      setState(() {});
    }
  }

  double get _currentAnchorFraction {
    if (!_anchorController.isAnimating) return _anchorToFraction;

    final t = _anchorController.value.clamp(0.0, 1.0);
    final transformed = _anchorRaising
        ? Curves.easeOutBack.transform(t)
        : Curves.easeOutCubic.transform(t);

    return lerpDouble(_anchorFromFraction, _anchorToFraction, transformed) ?? _anchorToFraction;
  }

  void _setPrimaryAnchorVisible(bool visible) {
    if (!mounted || _closing) return;

    final target = visible ? 1.0 : 0.0;
    if ((target - _anchorToFraction).abs() < 0.0001) {
      _wantsPrimaryAnchor = visible;
      return;
    }

    final current = _currentAnchorFraction.clamp(0.0, 1.0).toDouble();
    _wantsPrimaryAnchor = visible;
    _anchorFromFraction = current;
    _anchorToFraction = target;
    _anchorRaising = target > current;

    _anchorController
      ..stop()
      ..value = 0.0;

    unawaited(
      _anchorController.animateTo(
        1.0,
        duration: _anchorRaising
            ? AppFeedbackTokens.undoAnchorRaiseDuration
            : AppFeedbackTokens.undoAnchorLowerDuration,
        curve: Curves.linear,
      ),
    );
  }

  Future<void> _runLifecycle() async {
    unawaited(
      _lifecycleController.animateTo(
        1.0,
        duration: AppFeedbackTokens.undoEnterDuration,
        curve: Curves.linear,
      ),
    );
    unawaited(_countdownController.forward(from: 0.0));

    await Future<void>.delayed(AppFeedbackTokens.undoDuration);
    if (!mounted || _closing) return;
    await dismiss();
  }

  Future<void> dismiss({
    Offset exitTarget = const Offset(0, AppFeedbackTokens.undoExitTravel),
    Duration duration = AppFeedbackTokens.undoExitDuration,
  }) {
    if (_closed) return Future.value();

    final existing = _dismissCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _dismissCompleter = completer;

    final enterT = _lifecycleController.value.clamp(0.0, 1.0);
    _closing = true;
    _exiting = true;
    _dragging = false;

    _countdownController.stop();
    _anchorController.stop();

    _exitStartOpacity = enterT;
    _exitStartOffset = Offset(
      _dragOffset.dx,
      _dragOffset.dy + AppFeedbackTokens.undoEnterTravel * (1.0 - enterT),
    );
    _exitTargetOffset = exitTarget;

    _lifecycleController
      ..stop()
      ..value = 0.0;

    if (mounted) setState(() {});

    unawaited(() async {
      await _lifecycleController.animateTo(
        1.0,
        duration: duration,
        curve: Curves.easeInCubic,
      );

      if (!_closed) {
        _closed = true;
        widget.onClosed();
      }

      if (!completer.isCompleted) {
        completer.complete();
      }
    }());

    return completer.future;
  }

  void _handleUndo() {
    if (_closing) return;
    HapticFeedback.mediumImpact();

    unawaited(
      Future<void>.sync(() async {
        await widget.onUndo();
      }),
    );

    unawaited(
      dismiss(
        exitTarget: const Offset(0, AppFeedbackTokens.undoExitTravel),
        duration: AppFeedbackTokens.undoExitDuration,
      ),
    );
  }

  void _startDrag() {
    if (_closing) return;
    setState(() => _dragging = true);
  }

  void _updateHorizontalDrag(DragUpdateDetails details) {
    if (_closing) return;
    setState(() {
      _dragOffset = Offset(_dragOffset.dx + details.delta.dx, _dragOffset.dy);
    });
  }

  void _endHorizontalDrag(DragEndDetails details) {
    if (_closing) return;
    final vx = details.velocity.pixelsPerSecond.dx;

    final shouldDismiss = _dragOffset.dx.abs() >= AppFeedbackTokens.undoSwipeHorizontalDistance ||
        vx.abs() >= AppFeedbackTokens.undoSwipeHorizontalVelocity;

    if (shouldDismiss) {
      final direction = _dragOffset.dx != 0 ? _dragOffset.dx.sign : vx.sign;
      unawaited(
        dismiss(
          exitTarget: Offset(direction * 56.0, 0),
          duration: AppFeedbackTokens.undoGestureExitDuration,
        ),
      );
      return;
    }

    _snapBack();
  }

  void _updateVerticalDrag(DragUpdateDetails details) {
    if (_closing) return;
    setState(() {
      _dragOffset = Offset(
        _dragOffset.dx,
        math.max(0.0, _dragOffset.dy + details.delta.dy).toDouble(),
      );
    });
  }

  void _endVerticalDrag(DragEndDetails details) {
    if (_closing) return;
    final vy = details.velocity.pixelsPerSecond.dy;

    final shouldDismiss = _dragOffset.dy >= AppFeedbackTokens.undoSwipeDownDistance ||
        vy >= AppFeedbackTokens.undoSwipeDownVelocity;

    if (shouldDismiss) {
      unawaited(
        dismiss(
          exitTarget: const Offset(0, 36),
          duration: AppFeedbackTokens.undoGestureExitDuration,
        ),
      );
      return;
    }

    _snapBack();
  }

  void _snapBack() {
    if (!mounted || _closing) return;
    setState(() {
      _dragging = false;
      _dragOffset = Offset.zero;
    });
  }

  @override
  void dispose() {
    _detachRouteListeners();
    if (!(_dismissCompleter?.isCompleted ?? true)) {
      _dismissCompleter?.complete();
    }
    _lifecycleController.dispose();
    _countdownController.dispose();
    _anchorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final detailBottom = safeBottom + AppFeedbackTokens.undoDetailSafeGap;

    var primaryObstruction = _primaryBottomObstruction;
    if (primaryObstruction <= 0.0) {
      primaryObstruction = AppFeedback._preferredPrimaryObstruction();
    }

    final primaryBottom = primaryObstruction > 0.0
        ? math.max(detailBottom, primaryObstruction + AppFeedbackTokens.undoNavigationGap).toDouble()
        : detailBottom;

    final anchorFraction = _currentAnchorFraction;
    var bottom = lerpDouble(detailBottom, primaryBottom, anchorFraction) ?? detailBottom;

    if (_anchorRaising && bottom > primaryBottom) {
      bottom = math.min(
        primaryBottom + AppFeedbackTokens.undoAnchorRaiseOvershoot,
        bottom,
      ).toDouble();
    }

    final backgroundColor = isDark
        ? AppFeedbackTokens.darkGlassBackground
        : AppFeedbackTokens.lightGlassBackground;
    final borderColor = isDark
        ? AppFeedbackTokens.darkGlassBorder
        : AppFeedbackTokens.lightGlassBorder;
    final accentColor = widget.actionColor ?? theme.colorScheme.primary;

    // Chuẩn hóa typography: font size 13px, height 1.22
    final inheritedTextStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 13,
      height: 1.22,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      decoration: TextDecoration.none,
    ) ?? const TextStyle(
      fontSize: 13,
      height: 1.22,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      decoration: TextDecoration.none,
    );

    return Positioned(
      left: AppFeedbackTokens.undoHorizontalMargin,
      right: AppFeedbackTokens.undoHorizontalMargin,
      bottom: bottom,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppFeedbackTokens.undoMaxWidth,
          ),
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _lifecycleController,
              _countdownController,
              _anchorController,
            ]),
            builder: (context, _) {
              final t = _lifecycleController.value.clamp(0.0, 1.0);
              final enterProgress = Curves.easeOutBack.transform(t);

              final opacity = _exiting ? (_exitStartOpacity * (1.0 - t)).clamp(0.0, 1.0) : t;
              final lifecycleOffset = _exiting
                  ? Offset.lerp(_exitStartOffset, _exitTargetOffset, t) ?? _exitTargetOffset
                  : Offset(0, AppFeedbackTokens.undoEnterTravel * (1.0 - enterProgress));

              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: lifecycleOffset,
                  child: Material(
                    type: MaterialType.transparency,
                    child: DefaultTextStyle.merge(
                      style: inheritedTextStyle,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (_) => _startDrag(),
                        onHorizontalDragUpdate: _updateHorizontalDrag,
                        onHorizontalDragEnd: _endHorizontalDrag,
                        onHorizontalDragCancel: _snapBack,
                        onVerticalDragStart: (_) => _startDrag(),
                        onVerticalDragUpdate: _updateVerticalDrag,
                        onVerticalDragEnd: _endVerticalDrag,
                        onVerticalDragCancel: _snapBack,
                        child: AnimatedContainer(
                          duration: _dragging
                              ? Duration.zero
                              : AppFeedbackTokens.undoSnapBackDuration,
                          curve: Curves.easeOutBack,
                          transform: Matrix4.translationValues(
                            _exiting ? 0.0 : _dragOffset.dx,
                            _exiting ? 0.0 : _dragOffset.dy,
                            0.0,
                          ),
                          transformAlignment: Alignment.center,
                          height: AppFeedbackTokens.undoDockHeight,
                          decoration: BoxDecoration(
                            color: backgroundColor,
                            borderRadius: BorderRadius.circular(AppFeedbackTokens.undoRadius),
                            border: Border.all(color: borderColor, width: 0.8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.20),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppFeedbackTokens.undoRadius),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 16, right: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Dùng Expanded thay vì Flexible(loose) + Spacer()
                                        // Giải phóng 100% khoảng trống cho dòng text
                                        Expanded(
                                          child: Text(
                                            widget.message,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: inheritedTextStyle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minWidth: 44,
                                            minHeight: 44,
                                          ),
                                          child: TextButton(
                                            onPressed: _closing ? null : _handleUndo,
                                            style: TextButton.styleFrom(
                                              foregroundColor: accentColor,
                                              minimumSize: const Size(44, 44),
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              tapTargetSize: MaterialTapTargetSize.padded,
                                              textStyle: theme.textTheme.labelLarge?.copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                            child: const Text('HOÀN TÁC'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: AppFeedbackTokens.undoProgressHeight,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: (1.0 - _countdownController.value).clamp(0.0, 1.0),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(alpha: 0.88),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
