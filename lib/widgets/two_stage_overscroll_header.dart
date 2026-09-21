// ==============================================================================
// File: lib/widgets/two_stage_overscroll_header.dart
// Architecture: Safe-Area Offset Laser, Non-Intrusive Scroll Threshold & Preserved Motion
// Stack: flutter, flutter_riverpod, math
// Features:
// 1. Tách Bạch 3 Tầng Kiến Trúc Không Xung Đột (Triệt tiêu Drop-Frame & Fast-Swipe Glitch):
//    - Pointer Events: Quản lý quãng đường kéo thực tế qua ID con trỏ duy nhất (_activePointer).
//    - ScrollNotification: CHỈ quan sát metrics (atTop = pixels <= 2.0), không can thiệp dập tắt state.
//    - Animation Controllers: Quản lý frame hình độc lập, lắng nghe qua Listenable.merge.
// 2. Logic Phân Định Reload vs Secret Vault Chuẩn Xác (Deterministic Fling Reload):
//    - Kéo vượt 24px luôn kích hoạt reload nếu chưa bước vào pha hiển thị Két Tím (_lockRevealed).
//    - Kéo sâu (> 72px) khi vuốt nhanh (fast-swipe) thả tay ngay vẫn nhận Reload 100%.
// 3. Khóa Cửa Sổ Trình Diễn Tối Thiểu 750ms (Deterministic Hold):
//    - Sóng Shimmer 500ms/sweep (repeat reverse), đảm bảo 750ms quét đúng ~1.5 lượt sóng qua lại.
//    - Chờ đồng thời onRefresh() và minimum 750ms qua Future.wait.
// 4. Tự Động Hít Đầy Viền (Auto-Snap Full Width Khi Fling / Fast-Swipe):
//    - Kéo vượt 24px và nhấc ngón tay -> lập tức bung 100% chiều rộng màn hình.
// 5. Motion Hardening Over HyperOS:
//    - Toàn bộ Controller khởi tạo qua AppAnimationPolicy.createController với cờ:
//      `animationBehavior: AnimationBehavior.preserve`.
// 6. Cổng Két Tím Bí Mật (Quantum Purple Aura & Flick-Up to Cancel):
//    - Kéo sâu >= 72px + giữ tĩnh 2.0s bung mở Két ngầm; hất tay lên tự hủy êm dịu 150ms.
// ==============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/animation/app_animation_policy.dart';
import '../theme/app_theme.dart';

enum _PureBeamStage {
  idle,
  pulling,
  refreshing,
  success,
}

/// 🌟 BỘ BỌC DANH SÁCH CUỘN VỚI STATUS BAR SAFE OFFSET, AUTO-SNAP FULL WIDTH & PRESERVED MOTION
class TwoStageOverscrollHeader extends ConsumerStatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final VoidCallback? onSecretVaultTrigger;
  final Color? glowColor;
  final bool enabled;

  const TwoStageOverscrollHeader({
    super.key,
    required this.child,
    required this.onRefresh,
    this.onSecretVaultTrigger,
    this.glowColor,
    this.enabled = true,
  });

  @override
  ConsumerState<TwoStageOverscrollHeader> createState() =>
      _TwoStageOverscrollHeaderState();
}

class _TwoStageOverscrollHeaderState extends ConsumerState<TwoStageOverscrollHeader>
    with TickerProviderStateMixin {
  // ===========================================================================
  // PULL / OVERSCROLL STATE
  // ===========================================================================

  double _rawDragDistance = 0.0;
  bool _hasTriggeredThresholdHaptic = false;

  // Chỉ là trạng thái quan sát từ Scrollable.
  // NotificationListener KHÔNG được quyền reset animation state.
  bool _isAtScrollTop = true;

  // Một pointer duy nhất được phép điều khiển flow.
  int? _activePointer;

  Offset? _pointerDownPosition;
  double _rawStartY = 0.0;

  double _lastPointerY = 0.0;
  Duration? _lastPointerTimestamp;

  // ===========================================================================
  // CONSTANTS
  // ===========================================================================

  static const double _kTouchSlop = 8.0;

  static const double _kReloadThreshold = 24.0;

  static const double _kVaultDeepThreshold = 72.0;

  static const double _kFlickVelocityThreshold = -350.0;

  static const double _kFlickDeltaThreshold = -18.0;

  static const double _kVaultAbortThreshold = 35.0;

  static const Duration _kVaultHoldDuration = Duration(milliseconds: 1000);

  // 500ms / 1 sweep.
  // 750ms hold => khoảng 1.5 sweep với repeat(reverse: true).
  static const Duration _kShimmerSweepDuration = Duration(milliseconds: 500);

  static const Duration _kRefreshMinimumDuration = Duration(milliseconds: 750);

  static const Duration _kFadeOutDuration = Duration(milliseconds: 250);

  static const Duration _kAbortFadeDuration = Duration(milliseconds: 150);

  // ===========================================================================
  // VAULT STATE
  // ===========================================================================

  bool _vaultArmed = false;
  bool _wasAborted = false;

  _PureBeamStage _stage = _PureBeamStage.idle;

  Timer? _initialHoldTimer;

  bool _lockRevealed = false;
  bool _isReadyToUnlock = false;

  // ===========================================================================
  // ANIMATION CONTROLLERS
  // ===========================================================================

  late final AnimationController _shimmerController;
  late final AnimationController _fadeOutController;
  late final AnimationController _abortFadeController;
  late final AnimationController _unlockController;

  late final Animation<double> _shimmerAnimation;
  late final Animation<double> _fadeOutAnimation;
  late final Animation<double> _abortFadeAnimation;

  // Một listener duy nhất cho toàn bộ visual animation.
  late final Listenable _visualAnimations;

  @override
  void initState() {
    super.initState();

    // =========================================================================
    // SHIMMER
    // =========================================================================

    _shimmerController = AppAnimationPolicy.createController(
      vsync: this,
      duration: _kShimmerSweepDuration,
      debugLabel: 'TwoStageOverscrollHeader.shimmer',
    );

    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOutSine,
    );

    // =========================================================================
    // RELOAD FADE OUT
    // =========================================================================

    _fadeOutController = AppAnimationPolicy.createController(
      vsync: this,
      duration: _kFadeOutDuration,
      debugLabel: 'TwoStageOverscrollHeader.fadeOut',
    );

    _fadeOutAnimation = CurvedAnimation(
      parent: _fadeOutController,
      curve: Curves.easeOutCubic,
    );

    // =========================================================================
    // VAULT ABORT FADE
    // =========================================================================

    _abortFadeController = AppAnimationPolicy.createController(
      vsync: this,
      duration: _kAbortFadeDuration,
      debugLabel: 'TwoStageOverscrollHeader.abortFade',
    );

    _abortFadeAnimation = CurvedAnimation(
      parent: _abortFadeController,
      curve: Curves.easeOutQuad,
    );

    // =========================================================================
    // VAULT UNLOCK
    // =========================================================================

    _unlockController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      debugLabel: 'TwoStageOverscrollHeader.unlock',
    );

    _unlockController.addListener(() {
      if (_unlockController.value >= 1.0 && !_isReadyToUnlock && !_wasAborted) {
        _isReadyToUnlock = true;
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 120), () {
          if (mounted && _isReadyToUnlock && !_wasAborted) {
            HapticFeedback.mediumImpact();
          }
        });
      }
    });

    // =========================================================================
    // LISTENABLE MERGE
    // =========================================================================

    _visualAnimations = Listenable.merge([
      _shimmerController,
      _fadeOutController,
      _abortFadeController,
      _unlockController,
    ]);
  }

  @override
  void dispose() {
    _cancelHoldTimer();

    _shimmerController.dispose();
    _fadeOutController.dispose();
    _abortFadeController.dispose();
    _unlockController.dispose();

    super.dispose();
  }

  void _clearPointerTracking() {
    _pointerDownPosition = null;
    _rawStartY = 0.0;
    _lastPointerTimestamp = null;
  }

  void _cancelHoldTimer() {
    _initialHoldTimer?.cancel();
    _initialHoldTimer = null;
  }

  void _resetVaultState({bool resetArmed = false}) {
    _cancelHoldTimer();

    _unlockController.stop();
    _unlockController.value = 0.0;

    _abortFadeController.stop();
    _abortFadeController.value = 0.0;

    final bool shouldResetState =
        _lockRevealed || _isReadyToUnlock || (resetArmed && _vaultArmed);

    if (resetArmed) {
      _vaultArmed = false;
    }

    if (!mounted) {
      _lockRevealed = false;
      _isReadyToUnlock = false;
      return;
    }

    if (shouldResetState) {
      setState(() {
        _lockRevealed = false;
        _isReadyToUnlock = false;

        if (resetArmed) {
          _vaultArmed = false;
        }
      });
    } else {
      _lockRevealed = false;
      _isReadyToUnlock = false;
    }
  }

  void _startInitialHoldTimer() {
    if (_initialHoldTimer != null || _lockRevealed || _wasAborted) {
      return;
    }

    _initialHoldTimer = Timer(_kVaultHoldDuration, () {
      _initialHoldTimer = null;

      if (!mounted || !_vaultArmed || _wasAborted) {
        return;
      }

      HapticFeedback.mediumImpact();

      setState(() {
        _lockRevealed = true;
      });

      _unlockController.forward(
        from: 0.0,
      );
    });
  }

  Future<void> _startRefreshCycle() async {
    if (!mounted) return;

    if (_stage == _PureBeamStage.refreshing ||
        _stage == _PureBeamStage.success) {
      return;
    }

    // -------------------------------------------------------------------------
    // ENTER REFRESH
    // -------------------------------------------------------------------------

    setState(() {
      _stage = _PureBeamStage.refreshing;

      // Full-width ngay lập tức.
      _rawDragDistance = _kReloadThreshold;
    });

    _shimmerController.stop();
    _shimmerController.value = 0.0;

    _fadeOutController.stop();
    _fadeOutController.value = 0.0;

    _shimmerController.repeat(
      reverse: true,
    );

    try {
      // -----------------------------------------------------------------------
      // CHỜ ĐỒNG THỜI: onRefresh() VÀ TỐI THIỂU 750MS
      // -----------------------------------------------------------------------

      await Future.wait<void>([
        widget.onRefresh(),
        Future<void>.delayed(
          _kRefreshMinimumDuration,
        ),
      ]);
    } catch (_) {
    } finally {
      if (!mounted) return;

      // -----------------------------------------------------------------------
      // STOP SHIMMER
      // -----------------------------------------------------------------------

      _shimmerController.stop();

      // -----------------------------------------------------------------------
      // SUCCESS
      // -----------------------------------------------------------------------

      HapticFeedback.selectionClick();

      _fadeOutController.stop();
      _fadeOutController.value = 0.0;

      setState(() {
        _stage = _PureBeamStage.success;
        _rawDragDistance = _kReloadThreshold;
      });

      // -----------------------------------------------------------------------
      // FADE OUT 250ms
      // -----------------------------------------------------------------------

      await _fadeOutController.forward(
        from: 0.0,
      );

      if (!mounted) return;

      // -----------------------------------------------------------------------
      // RESET
      // -----------------------------------------------------------------------

      _fadeOutController.stop();
      _fadeOutController.value = 0.0;

      setState(() {
        _stage = _PureBeamStage.idle;
        _rawDragDistance = 0.0;
        _hasTriggeredThresholdHaptic = false;
        _wasAborted = false;
      });
    }
  }

  ({Color primary, Color glowNeon}) _resolveAccentGlowColors(AppAccentPreset preset) {
    switch (preset) {
      case AppAccentPreset.grass:
        return (
        primary: const Color(0xFF10B981),
        glowNeon: const Color(0xFF34D399),
        );
      case AppAccentPreset.sun:
        return (
        primary: const Color(0xFFF59E0B),
        glowNeon: const Color(0xFFFBBF24),
        );
      case AppAccentPreset.sea:
        return (
        primary: const Color(0xFF0EA5E9),
        glowNeon: const Color(0xFF38BDF8),
        );
      case AppAccentPreset.flower:
        return (
        primary: const Color(0xFFF43F5E),
        glowNeon: const Color(0xFFFB7185),
        );
      case AppAccentPreset.night:
        return (
        primary: const Color(0xFF6366F1),
        glowNeon: const Color(0xFF818CF8),
        );
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_stage == _PureBeamStage.refreshing ||
        _stage == _PureBeamStage.success) {
      return;
    }

    if (_activePointer != null) {
      return;
    }

    _activePointer = event.pointer;

    _pointerDownPosition = event.position;
    _rawStartY = event.position.dy;

    _lastPointerY = event.position.dy;
    _lastPointerTimestamp = event.timeStamp;

    _rawDragDistance = 0.0;
    _hasTriggeredThresholdHaptic = false;

    _vaultArmed = false;
    _wasAborted = false;

    _cancelHoldTimer();

    _unlockController.stop();
    _unlockController.value = 0.0;

    _abortFadeController.stop();
    _abortFadeController.value = 0.0;

    _lockRevealed = false;
    _isReadyToUnlock = false;

    if (_stage != _PureBeamStage.idle) {
      setState(() {
        _stage = _PureBeamStage.idle;
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }

    if (_stage == _PureBeamStage.refreshing ||
        _stage == _PureBeamStage.success) {
      return;
    }

    if (_pointerDownPosition == null) {
      return;
    }

    if (!_isAtScrollTop) {
      return;
    }

    final deltaYFromLast = event.position.dy - _lastPointerY;

    final deltaTime = event.timeStamp -
        (_lastPointerTimestamp ?? event.timeStamp);

    double velocityY = 0.0;

    if (deltaTime.inMicroseconds > 0) {
      velocityY = (deltaYFromLast / deltaTime.inMicroseconds) * 1000000.0;
    }

    _lastPointerY = event.position.dy;
    _lastPointerTimestamp = event.timeStamp;

    final dx = (event.position.dx - _pointerDownPosition!.dx).abs();
    final dy = event.position.dy - _rawStartY;

    if (dy <= 0) {
      if (_vaultArmed || _lockRevealed || _isReadyToUnlock) {
        _triggerVaultAbortion();
      }
      return;
    }

    if (dy <= dx * 1.5) {
      if (_vaultArmed || _lockRevealed || _isReadyToUnlock) {
        _triggerVaultAbortion();
      }
      return;
    }

    if (_vaultArmed || _lockRevealed || _isReadyToUnlock) {
      final isFlickUpVelocity = velocityY < _kFlickVelocityThreshold;
      final isInstantJumpUp = deltaYFromLast < _kFlickDeltaThreshold;
      final isBelowMinFloor = (dy - _kTouchSlop) < _kVaultAbortThreshold;

      if (isFlickUpVelocity || isInstantJumpUp || isBelowMinFloor) {
        _triggerVaultAbortion();
        return;
      }
    }

    if (dy < _kTouchSlop) {
      return;
    }

    final effectiveDrag = dy - _kTouchSlop;

    setState(() {
      _rawDragDistance = effectiveDrag;
      _stage = _PureBeamStage.pulling;
    });

    if (!_vaultArmed &&
        !_wasAborted &&
        _rawDragDistance >= _kReloadThreshold &&
        !_hasTriggeredThresholdHaptic) {
      HapticFeedback.lightImpact();
      _hasTriggeredThresholdHaptic = true;
    }

    if (!_vaultArmed && _rawDragDistance < _kReloadThreshold) {
      _hasTriggeredThresholdHaptic = false;
    }

    if (!_vaultArmed &&
        !_wasAborted &&
        _rawDragDistance >= _kVaultDeepThreshold) {
      _vaultArmed = true;
      _startInitialHoldTimer();
    }
  }

  void _triggerVaultAbortion() {
    if (_wasAborted) return;

    _cancelHoldTimer();

    _unlockController.stop();
    _unlockController.value = 0.0;

    HapticFeedback.selectionClick();

    _wasAborted = true;
    _vaultArmed = false;
    _lockRevealed = false;
    _isReadyToUnlock = false;

    _abortFadeController.stop();
    _abortFadeController.value = 0.0;

    _abortFadeController.forward(from: 0.0).then((_) {
      if (!mounted || !_wasAborted) {
        return;
      }

      setState(() {
        _rawDragDistance = 0.0;
        _hasTriggeredThresholdHaptic = false;
        _stage = _PureBeamStage.idle;
      });

      _abortFadeController.stop();
      _abortFadeController.value = 0.0;
    });
  }

  Future<void> _handlePointerUp(PointerUpEvent event) async {
    if (_activePointer != event.pointer) {
      return;
    }

    _activePointer = null;

    // Lưu snapshot TRƯỚC khi reset bất cứ state nào
    final double releasedDistance = _rawDragDistance;
    final bool vaultWasVisiblyCommitted = _lockRevealed || _isReadyToUnlock;

    // ===========================================================================
    // 1. GESTURE ĐÃ BỊ ABORT DO FLICK-UP
    // ===========================================================================

    if (_wasAborted) {
      _resetVaultState(resetArmed: true);

      if (mounted) {
        setState(() {
          _rawDragDistance = 0.0;
          _hasTriggeredThresholdHaptic = false;
          _wasAborted = false;
          _stage = _PureBeamStage.idle;
        });
      }

      _clearPointerTracking();
      return;
    }

    // ===========================================================================
    // 2. SECRET VAULT ĐÃ GIỮ ĐỦ 2 GIÂY
    // ===========================================================================

    final canOpenVault = _isReadyToUnlock &&
        releasedDistance >= _kVaultAbortThreshold;

    if (canOpenVault) {
      HapticFeedback.heavyImpact();

      _resetVaultState(resetArmed: true);

      if (mounted) {
        setState(() {
          _rawDragDistance = 0.0;
          _hasTriggeredThresholdHaptic = false;
          _wasAborted = false;
          _stage = _PureBeamStage.idle;
        });
      }

      _clearPointerTracking();

      widget.onSecretVaultTrigger?.call();
      return;
    }

    // ===========================================================================
    // 3. RELOAD
    //
    // QUAN TRỌNG: Không check !_vaultArmed ở đây.
    // Một fast-swipe có thể vượt 72px trong 1 frame nhưng người dùng KHÔNG giữ tĩnh.
    // Reload chỉ bị chặn khi Vault đã thực sự bước sang pha reveal.
    // ===========================================================================

    final bool shouldRefresh = releasedDistance >= _kReloadThreshold &&
        !vaultWasVisiblyCommitted;

    // Pointer đã release => hủy mọi pending Vault timer
    _resetVaultState(resetArmed: true);
    _clearPointerTracking();

    if (shouldRefresh) {
      await _startRefreshCycle();
      return;
    }

    // ===========================================================================
    // 4. KHÔNG ĐỦ NGƯỠNG RELOAD
    // ===========================================================================

    if (!mounted) return;

    setState(() {
      _rawDragDistance = 0.0;
      _hasTriggeredThresholdHaptic = false;
      _wasAborted = false;
      _stage = _PureBeamStage.idle;
    });
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }

    _activePointer = null;

    if (_stage == _PureBeamStage.refreshing ||
        _stage == _PureBeamStage.success) {
      return;
    }

    _resetVaultState(resetArmed: true);

    if (!mounted) return;

    setState(() {
      _rawDragDistance = 0.0;
      _hasTriggeredThresholdHaptic = false;
      _wasAborted = false;
      _stage = _PureBeamStage.idle;
    });

    _clearPointerTracking();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final currentPreset = ref.watch(accentPresetProvider);
    final accentConfig = _resolveAccentGlowColors(currentPreset);
    final primaryColor = widget.glowColor ?? accentConfig.primary;
    final glowNeonColor = accentConfig.glowNeon;

    final double topPadding = MediaQuery.paddingOf(context).top;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0) {
            return false;
          }

          final metrics = notification.metrics;

          _isAtScrollTop = metrics.pixels <= 2.0 ||
              metrics.extentBefore <= 2.0;

          if (_activePointer != null &&
              _stage == _PureBeamStage.pulling &&
              !_vaultArmed &&
              metrics.pixels > 2.0) {
            if (mounted) {
              setState(() {
                _rawDragDistance = 0.0;
                _hasTriggeredThresholdHaptic = false;
                _stage = _PureBeamStage.idle;
              });
            }
          }

          return false;
        },
        child: AnimatedBuilder(
          animation: _visualAnimations,
          child: widget.child,
          builder: (BuildContext context, Widget? child) {
            return Stack(
              children: [
                child!,

                if (_lockRevealed)
                  Positioned(
                    top: topPadding,
                    left: 0,
                    right: 0,
                    height: 360,
                    child: Opacity(
                      opacity: (1.0 - _abortFadeController.value).clamp(0.0, 1.0),
                      child: _buildSecretPurpleAuraGlow(),
                    ),
                  ),

                Positioned(
                  top: topPadding,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: (1.0 - _abortFadeController.value).clamp(0.0, 1.0),
                    child: _buildPureAccentBeam(
                      primaryColor: primaryColor,
                      glowNeonColor: glowNeonColor,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSecretPurpleAuraGlow() {
    final auraProgress = _unlockController.value;

    if (auraProgress <= 0.0) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Opacity(
        opacity: auraProgress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -1.0),
              radius: 1.0 + (0.25 * auraProgress),
              colors: [
                const Color(0xFFC084FC).withValues(alpha: 0.38 * auraProgress),
                const Color(0xFFA855F7).withValues(alpha: 0.22 * auraProgress),
                const Color(0xFF8B5CF6).withValues(alpha: 0.08 * auraProgress),
                Colors.transparent,
              ],
              stops: const [0.0, 0.30, 0.65, 0.95],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPureAccentBeam({
    required Color primaryColor,
    required Color glowNeonColor,
  }) {
    if (_stage == _PureBeamStage.idle && _rawDragDistance <= 0.0) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;

    double beamWidth = 0.0;
    double beamOpacity = 0.0;

    if (_stage == _PureBeamStage.pulling) {
      final progress = (_rawDragDistance / _kReloadThreshold).clamp(0.0, 1.0);
      beamWidth = screenWidth * progress;
      beamOpacity = 0.35 + (0.65 * progress);
    } else if (_stage == _PureBeamStage.refreshing) {
      beamWidth = screenWidth;
      beamOpacity = 1.0;
    } else if (_stage == _PureBeamStage.success) {
      beamWidth = screenWidth;
      beamOpacity = (1.0 - _fadeOutAnimation.value).clamp(0.0, 1.0);
    }

    if (beamOpacity <= 0.01 || beamWidth <= 0.0) {
      return const SizedBox.shrink();
    }

    final auraT = _lockRevealed ? _unlockController.value : 0.0;
    const secretPurpleDeep = Color(0xFF8B5CF6);
    const secretPurpleLight = Color(0xFFC084FC);

    final effectivePrimary = Color.lerp(
      primaryColor,
      secretPurpleDeep,
      auraT,
    ) ??
        primaryColor;

    final effectiveCenter = Color.lerp(
      glowNeonColor,
      secretPurpleLight,
      auraT,
    ) ??
        glowNeonColor;

    final effectiveGlow = Color.lerp(
      glowNeonColor,
      secretPurpleLight,
      auraT,
    ) ??
        glowNeonColor;

    final shimmerVal = _stage == _PureBeamStage.refreshing
        ? _shimmerAnimation.value
        : 0.5;

    final LinearGradient gradient = _stage == _PureBeamStage.refreshing
        ? LinearGradient(
      colors: [
        effectivePrimary.withValues(alpha: 0.55),
        effectivePrimary,
        effectiveCenter,
        Colors.white,
        effectiveCenter,
        effectivePrimary,
        effectivePrimary.withValues(alpha: 0.55),
      ],
      stops: [
        0.0,
        (shimmerVal - 0.25).clamp(0.0, 1.0),
        (shimmerVal - 0.10).clamp(0.0, 1.0),
        shimmerVal.clamp(0.0, 1.0),
        (shimmerVal + 0.10).clamp(0.0, 1.0),
        (shimmerVal + 0.25).clamp(0.0, 1.0),
        1.0,
      ],
    )
        : LinearGradient(
      colors: [
        effectivePrimary.withValues(alpha: 0.55),
        effectivePrimary,
        effectiveCenter,
        effectivePrimary,
        effectivePrimary.withValues(alpha: 0.55),
      ],
      stops: const [0.0, 0.05, 0.5, 0.95, 1.0],
    );

    final coreAlpha = _stage == _PureBeamStage.refreshing ? 0.82 : 0.74;

    return Align(
      alignment: Alignment.center,
      child: Opacity(
        opacity: beamOpacity,
        child: Container(
          width: beamWidth,
          height: 2.0,
          decoration: BoxDecoration(
            color: effectivePrimary.withValues(alpha: coreAlpha),
            borderRadius: BorderRadius.circular(1.0),
            boxShadow: [
              BoxShadow(
                color: effectiveGlow.withValues(
                  alpha: _stage == _PureBeamStage.refreshing
                      ? 0.50 + (0.30 * shimmerVal)
                      : (_lockRevealed ? 0.60 + (0.35 * auraT) : 0.45),
                ),
                blurRadius: _stage == _PureBeamStage.refreshing
                    ? 6.0 + (4.0 * shimmerVal)
                    : (_lockRevealed ? 8.0 + (8.0 * auraT) : 5.0),
                spreadRadius: _stage == _PureBeamStage.refreshing
                    ? 0.8 + (0.4 * shimmerVal)
                    : (_lockRevealed ? 1.0 + (1.2 * auraT) : 0.6),
                offset: const Offset(0, 1),
              ),
              BoxShadow(
                color: effectivePrimary.withValues(alpha: 0.25),
                blurRadius: 10.0,
                spreadRadius: 1.0,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1.0),
            gradient: gradient,
          ),
        ),
      ),
    );
  }
}

/// 🌟 Alias tương thích ngược cho toàn bộ codebase
typedef LuminescentEdgeScaffoldWrapper = TwoStageOverscrollHeader;