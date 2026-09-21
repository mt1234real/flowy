// ==============================================================================
// File: lib/screens/vault_auth_screen.dart
// Architecture: Digital Swiss Vault Authentication Surface
// Stack: flutter, flutter_riverpod, local_auth
// Features: Dynamic 4/6 Digit PIN, Biometrics, Preserved Error Shake,
//           Precision 64px Numpad, Root-Route Unlock Compatibility
// ==============================================================================

import 'dart:math' as math;

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

  String _enteredPin = '';
  bool _isAuthenticatingBiometrics = false;
  bool _isRejectingPin = false;
  bool _pinErrorActive = false;
  bool _preferFaceIcon = false;

  @override
  void initState() {
    super.initState();

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
    _pinRejectController.dispose();
    _unlockController.dispose();
    super.dispose();
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isUnlocking || _isAuthenticatingBiometrics || _isRejectingPin) return;

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
          localizedReason: 'Xác thực để mở Két Tiết Kiệm',
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
    if (_isUnlocking ||
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
    if (_isUnlocking || _isRejectingPin || _isAuthenticatingBiometrics) return;
    if (_enteredPin.isEmpty) return;

    setState(() {
      _pinErrorActive = false;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _clearPin() {
    if (_isUnlocking || _isRejectingPin || _isAuthenticatingBiometrics) return;
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
    if (!mounted || _isUnlocking || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }

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
                      Text('MÃ PIN BẢO MẬT', style: titleStyle),
                      const SizedBox(height: 7),
                      Text(
                        'Nhập $pinLength chữ số để giải mã dữ liệu',
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
                    ],
                  ),
                ),
              ),
              PrecisionNumpad(
                onDigit: (digit) => _onKeyPress(digit, pinLength),
                onBackspace: _onBackspace,
                onBackspaceLongPress: _clearPin,
                leadingAction: PrecisionNumpadAction(
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
            ],
          ),
        ),
      ),
    );
  }
}
