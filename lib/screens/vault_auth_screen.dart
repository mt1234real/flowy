// ==============================================================================
// File: lib/screens/vault_auth_screen.dart
// Architecture: Digital Swiss Vault Authentication Surface
// Stack: flutter, flutter_riverpod, local_auth
// Features: Dynamic 4/6 Digit PIN, Biometrics, Preserved Error Shake,
//           Precision 64px Numpad, Root-Route Unlock Compatibility
// ==============================================================================

import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../core/animation/app_animation_policy.dart';
import '../services/vault_security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/precision_numpad.dart';
import '../widgets/vault_security_surface.dart';
import 'savings_vault_screen.dart';

// Session-scoped attempt history survives closing/reopening the PIN route.
// No PIN or financial data is stored here.
class _PinAttemptWindow {
  int failedAttempts = 0;
  DateTime? lockedUntil;
}

final _pinAttemptWindowProvider = Provider((ref) => _PinAttemptWindow());

class VaultAuthScreen extends ConsumerStatefulWidget {
  final String? customPin;

  /// true when this screen is only used to unlock an already-open SavingsVault.
  /// In this mode success returns `true` instead of pushing another vault screen.
  final bool unlockOnly;

  /// Dashboard entry keeps the current auto-biometric behavior. The privacy
  /// shield route can use the same behavior while still keeping the PIN pad live.
  final bool autoStartBiometrics;

  const VaultAuthScreen({
    super.key,
    this.customPin,
    this.unlockOnly = false,
    this.autoStartBiometrics = true,
  });

  @override
  ConsumerState<VaultAuthScreen> createState() => _VaultAuthScreenState();
}

class _VaultAuthScreenState extends ConsumerState<VaultAuthScreen>
    with TickerProviderStateMixin {
  final LocalAuthentication _localAuth = LocalAuthentication();

  late final AnimationController _pinRejectController;
  late final AnimationController _unlockController;
  bool _isUnlocking = false;

  int _failedAttempts = 0;
  Timer? _lockoutTimer;
  bool _isLockedOut = false;
  int _lockoutSeconds = 0;
  late final _PinAttemptWindow _attemptWindow;
  String _enteredPin = '';
  bool _isAuthenticatingBiometrics = false;
  bool _isRejectingPin = false;
  bool _pinErrorActive = false;
  bool _preferFaceIcon = false;

  @override
  void initState() {
    super.initState();
    _attemptWindow = ref.read(_pinAttemptWindowProvider);
    _failedAttempts = _attemptWindow.failedAttempts;
    if (_attemptWindow.lockedUntil != null) {
      _resumeLockout();
    }

    _pinRejectController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      debugLabel: 'VaultAuth.pinReject',
    );
    _unlockController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      debugLabel: 'VaultAuth.unlockFlash',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.autoStartBiometrics) {
        _authenticateWithBiometrics();
      }
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _pinRejectController.dispose();
    _unlockController.dispose();
    super.dispose();
  }

  void _resumeLockout() {
    final deadline = _attemptWindow.lockedUntil!;
    _lockoutSeconds = math.max(
        0, (deadline.difference(DateTime.now()).inMilliseconds / 1000).ceil());
    if (_lockoutSeconds == 0) {
      _resetAttempts();
      return;
    }
    _isLockedOut = true;
    final initialSeconds = _lockoutSeconds;
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      // Use the deadline to catch up after background suspension, and timer.tick
      // so a delayed callback cannot extend the active countdown.
      final byDeadline =
          (deadline.difference(DateTime.now()).inMilliseconds / 1000).ceil();
      setState(() {
        _lockoutSeconds =
            math.max(0, math.min(byDeadline, initialSeconds - timer.tick));
        if (_lockoutSeconds == 0) {
          _resetAttempts();
          _enteredPin = '';
          _pinErrorActive = false;
        }
      });
    });
  }

  void _resetAttempts() {
    _lockoutTimer?.cancel();
    _lockoutTimer = null;
    _attemptWindow.failedAttempts = 0;
    _attemptWindow.lockedUntil = null;
    _failedAttempts = 0;
    _lockoutSeconds = 0;
    _isLockedOut = false;
  }

  Future<void> _authenticateWithBiometrics() async {
    if (!ref.read(vaultBiometricsProvider)) return;
    if (_isLockedOut ||
        _isUnlocking ||
        _isAuthenticatingBiometrics ||
        _isRejectingPin) {
      return;
    }

    setState(() {
      _isAuthenticatingBiometrics = true;
      _pinErrorActive = false;
    });

    try {
      final available = await _localAuth.getAvailableBiometrics();
      if (mounted) {
        setState(() {
          _preferFaceIcon = available.contains(BiometricType.face);
        });
      }

      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (canCheck || isSupported) {
        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Xác thực để vào két',
        );

        if (didAuthenticate && mounted) {
          _onSuccess();
          return;
        }
      }
    } catch (e) {
      debugPrint('VaultAuth biometrics unavailable/cancelled: $e');
    } finally {
      if (mounted) {
        setState(() => _isAuthenticatingBiometrics = false);
      }
    }
  }

  void _onKeyPress(String digit, int pinLength) {
    if (_isLockedOut ||
        _isUnlocking ||
        _isRejectingPin ||
        _isAuthenticatingBiometrics ||
        _enteredPin.length >= pinLength) {
      return;
    }

    setState(() {
      _pinErrorActive = false;
      _enteredPin += digit;
    });

    if (_enteredPin.length == pinLength) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_isLockedOut ||
        _isUnlocking ||
        _isRejectingPin ||
        _isAuthenticatingBiometrics) {
      return;
    }
    if (_enteredPin.isEmpty) return;

    setState(() {
      _pinErrorActive = false;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _clearPin() {
    if (_isLockedOut ||
        _isUnlocking ||
        _isRejectingPin ||
        _isAuthenticatingBiometrics) {
      return;
    }
    if (_enteredPin.isEmpty) return;

    setState(() {
      _pinErrorActive = false;
      _enteredPin = '';
    });
  }

  Future<void> _verifyPin() async {
    final expectedPin = widget.customPin ?? ref.read(vaultPinProvider);

    if (_enteredPin == expectedPin) {
      _onSuccess();
      return;
    }

    _failedAttempts++;
    _attemptWindow.failedAttempts = _failedAttempts;
    if (_failedAttempts >= 3) {
      _attemptWindow.lockedUntil =
          DateTime.now().add(const Duration(seconds: 30));
      _resumeLockout();
    }
    HapticFeedback.heavyImpact();

    setState(() {
      _isRejectingPin = true;
      _pinErrorActive = true;
    });

    await _pinRejectController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );

    if (!mounted) return;

    _pinRejectController.value = 0.0;
    setState(() {
      _enteredPin = '';
      _pinErrorActive = false;
      _isRejectingPin = false;
    });
  }

  Future<void> _onSuccess() async {
    if (!mounted ||
        _isLockedOut ||
        _isUnlocking ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

    _resetAttempts();
    setState(() => _isUnlocking = true);

    HapticFeedback.lightImpact();
    try {
      await _unlockController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    if (widget.unlockOnly) {
      Navigator.of(context).pop(true);
      return;
    }

    Navigator.of(context).pushReplacement(
      PreservedPageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SavingsVaultScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  void _close() {
    if (_isUnlocking || ModalRoute.of(context)?.isCurrent != true) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final pinLength = ref.watch(vaultPinLengthProvider);
    final accent = ref.watch(accentPresetProvider);
    final theme = Theme.of(context);
    final accentColor = accent.primary;

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: Colors.white,
        ) ??
        const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: Colors.white,
        );

    return Scaffold(
      backgroundColor: const Color(0xFF080B11),
      body: VaultSecuritySurface(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    tooltip: 'Đóng',
                    onPressed: _close,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VaultBreathingShield(accent: accentColor),
                      const SizedBox(height: 18),
                      Text('Nhập mã PIN', style: titleStyle),
                      const SizedBox(height: 7),
                      Text(
                        'Nhập 4 số bảo mật để mở',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 28),
                      AnimatedBuilder(
                        animation: Listenable.merge(
                            [_pinRejectController, _unlockController]),
                        builder: (context, _) => Transform.scale(
                          scale: 1 +
                              0.08 *
                                  math.sin(math.pi * _unlockController.value),
                          child: VaultPinDots(
                            length: pinLength,
                            enteredLength:
                                _isUnlocking ? pinLength : _enteredPin.length,
                            accentColor: _isUnlocking
                                ? Color.lerp(
                                    const Color(0xFF10B981),
                                    const Color(0xFFD1FAE5),
                                    math.sin(
                                        math.pi * _unlockController.value))!
                                : accentColor,
                            isError: _pinErrorActive,
                            shakeProgress: _pinRejectController.value,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _isLockedOut
                              ? 'Đã nhập sai 3 lần. Tạm khóa sau $_lockoutSeconds giây'
                              : _pinErrorActive
                                  ? 'Mã PIN không chính xác'
                                  : '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTokens.expense, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: _isLockedOut || _isRejectingPin || _isUnlocking,
                child: PrecisionNumpad(
                  onDigit: (digit) => _onKeyPress(digit, pinLength),
                  onBackspace: _onBackspace,
                  onBackspaceLongPress: _clearPin,
                  leadingAction: !ref.watch(vaultBiometricsProvider)
                      ? null
                      : PrecisionNumpadAction(
                          icon: _preferFaceIcon
                              ? Icons.face_retouching_natural_rounded
                              : Icons.fingerprint_rounded,
                          onPressed: _authenticateWithBiometrics,
                          color: accentColor,
                          semanticLabel: 'Sinh trắc học',
                        ),
                  digitColor: Colors.white,
                  actionColor: accentColor,
                  horizontalPadding: 18,
                  rowSpacing: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
