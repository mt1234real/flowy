// ==============================================================================
// File: lib/screens/vault_pin_change_screen.dart
// Architecture: Unified Digital Swiss Vault PIN Setup / Change Flow
// Stack: flutter, flutter_riverpod
// Features: Verify Old PIN -> Enter New PIN -> Confirm,
//           Shared PrecisionNumpad, 4/6 Digit Compatibility,
//           Mechanical PIN Dots & AppFeedback Success
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../services/vault_security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/precision_numpad.dart';
import '../widgets/vault_security_surface.dart';

enum PinChangeWorkflowStep {
  verifyOldPin,
  enterNewPin,
  confirmNewPin,
}

class VaultPinChangeScreen extends ConsumerStatefulWidget {
  const VaultPinChangeScreen({super.key});

  @override
  ConsumerState<VaultPinChangeScreen> createState() =>
      _VaultPinChangeScreenState();
}

class _VaultPinChangeScreenState extends ConsumerState<VaultPinChangeScreen>
    with TickerProviderStateMixin {
  late PinChangeWorkflowStep _currentStep;
  late final AnimationController _pinRejectController;
  late final AnimationController _successController;
  bool _isSuccessFeedback = false;

  int _selectedPinLength = 4;
  String _enteredOldPin = '';
  String _enteredNewPin = '';
  String _enteredConfirmPin = '';

  bool _pinErrorActive = false;
  bool _isRejectingPin = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final notifier = ref.read(vaultSecurityNotifierProvider.notifier);
    final currentLength = ref.read(vaultPinLengthProvider);

    // Existing users keep their current length. New/default users naturally
    // start on the mechanical 4-digit standard.
    _selectedPinLength = currentLength;

    _currentStep = notifier.hasCustomPin
        ? PinChangeWorkflowStep.verifyOldPin
        : PinChangeWorkflowStep.enterNewPin;

    _pinRejectController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      debugLabel: 'VaultPinChange.reject',
    );
    _successController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      debugLabel: 'VaultPinChange.success',
    );
  }

  @override
  void dispose() {
    _pinRejectController.dispose();
    _successController.dispose();
    super.dispose();
  }

  int get _targetLength {
    if (_currentStep == PinChangeWorkflowStep.verifyOldPin) {
      return ref.read(vaultPinLengthProvider);
    }
    return _selectedPinLength;
  }

  String get _currentEntered {
    return switch (_currentStep) {
      PinChangeWorkflowStep.verifyOldPin => _enteredOldPin,
      PinChangeWorkflowStep.enterNewPin => _enteredNewPin,
      PinChangeWorkflowStep.confirmNewPin => _enteredConfirmPin,
    };
  }

  void _setCurrentEntered(String value) {
    switch (_currentStep) {
      case PinChangeWorkflowStep.verifyOldPin:
        _enteredOldPin = value;
        break;
      case PinChangeWorkflowStep.enterNewPin:
        _enteredNewPin = value;
        break;
      case PinChangeWorkflowStep.confirmNewPin:
        _enteredConfirmPin = value;
        break;
    }
  }

  void _onKeyPress(String digit) {
    if (_isSuccessFeedback ||
        _isRejectingPin ||
        _currentEntered.length >= _targetLength) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _pinErrorActive = false;
      _setCurrentEntered('$_currentEntered$digit');
    });

    if (_currentEntered.length != _targetLength) return;

    switch (_currentStep) {
      case PinChangeWorkflowStep.verifyOldPin:
        _handleVerifyOldPin();
        break;
      case PinChangeWorkflowStep.enterNewPin:
        final completedPin = _enteredNewPin;
        Future<void>.delayed(const Duration(milliseconds: 140), () {
          if (!mounted ||
              _currentStep != PinChangeWorkflowStep.enterNewPin ||
              _enteredNewPin != completedPin ||
              _enteredNewPin.length != _selectedPinLength) {
            return;
          }
          HapticFeedback.selectionClick();
          setState(() {
            _currentStep = PinChangeWorkflowStep.confirmNewPin;
            _enteredConfirmPin = '';
            _errorMessage = null;
          });
        });
        break;
      case PinChangeWorkflowStep.confirmNewPin:
        _handleConfirmNewPin();
        break;
    }
  }

  void _onBackspace() {
    if (_isSuccessFeedback || _isRejectingPin || _currentEntered.isEmpty) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _pinErrorActive = false;
      final current = _currentEntered;
      _setCurrentEntered(current.substring(0, current.length - 1));
    });
  }

  void _onClear() {
    if (_isSuccessFeedback || _isRejectingPin || _currentEntered.isEmpty) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _pinErrorActive = false;
      _setCurrentEntered('');
    });
  }

  Future<void> _rejectCurrentEntry(String message,
      {bool restartSetup = false}) async {
    if (_isRejectingPin) return;

    HapticFeedback.heavyImpact();

    setState(() {
      _isRejectingPin = true;
      _pinErrorActive = true;
      _errorMessage = message;
    });

    try {
      await Future.wait([
        _pinRejectController.forward(from: 0.0).orCancel,
        if (restartSetup)
          Future<void>.delayed(const Duration(milliseconds: 500)),
      ]);
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;

    _pinRejectController.value = 0.0;
    setState(() {
      _setCurrentEntered('');
      if (restartSetup) {
        _enteredNewPin = '';
        _enteredConfirmPin = '';
        _currentStep = PinChangeWorkflowStep.enterNewPin;
        _errorMessage = null;
      }
      _pinErrorActive = false;
      _isRejectingPin = false;
    });
  }

  Future<void> _handleVerifyOldPin() async {
    final notifier = ref.read(vaultSecurityNotifierProvider.notifier);
    final isValid = await notifier.verifyPin(_enteredOldPin);

    if (!mounted) return;

    if (!isValid) {
      await _rejectCurrentEntry('Mã PIN chưa đúng, thử lại nhé');
      return;
    }

    if (!await _flashSuccess()) return;
    setState(() {
      _currentStep = PinChangeWorkflowStep.enterNewPin;
      _enteredOldPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _handleConfirmNewPin() async {
    if (_enteredConfirmPin != _enteredNewPin) {
      await _rejectCurrentEntry('Mã PIN không khớp, vui lòng nhập lại',
          restartSetup: true);
      return;
    }

    final notifier = ref.read(vaultSecurityNotifierProvider.notifier);
    await notifier.updatePin(
      newPin: _enteredNewPin,
      length: _selectedPinLength,
    );

    if (!mounted) return;

    if (!await _flashSuccess()) return;
    if (!mounted) return;
    AppFeedback.showSuccess(
      context,
      'Đã cập nhật mã PIN két ($_selectedPinLength số).',
      emitHaptic: false,
    );
    Navigator.of(context).pop();
  }

  Future<bool> _flashSuccess() async {
    setState(() => _isSuccessFeedback = true);
    HapticFeedback.lightImpact();
    try {
      await _successController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return false;
    }
    if (!mounted) return false;
    setState(() => _isSuccessFeedback = false);
    return true;
  }

  void _togglePinLength() {
    if (_isSuccessFeedback ||
        _currentStep != PinChangeWorkflowStep.enterNewPin ||
        _isRejectingPin) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedPinLength = _selectedPinLength == 4 ? 6 : 4;
      _enteredNewPin = '';
      _errorMessage = null;
      _pinErrorActive = false;
    });
  }

  String _stepTitle() {
    return switch (_currentStep) {
      PinChangeWorkflowStep.verifyOldPin => 'Nhập mã PIN hiện tại',
      PinChangeWorkflowStep.enterNewPin => 'Đặt mã PIN mới',
      PinChangeWorkflowStep.confirmNewPin => 'Xác nhận lại mã PIN',
    };
  }

  String _stepSubtitle() {
    return switch (_currentStep) {
      PinChangeWorkflowStep.verifyOldPin =>
        'Nhập ${ref.read(vaultPinLengthProvider)} số bảo mật để đổi mã PIN',
      PinChangeWorkflowStep.enterNewPin => 'Nhập mật khẩu mới',
      PinChangeWorkflowStep.confirmNewPin => 'Nhập lại mật khẩu',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = ref.watch(accentPresetProvider);
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B11),
        foregroundColor: Colors.white,
        title: const Text('Tạo mã PIN'),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Đóng',
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: VaultSecuritySurface(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VaultBreathingShield(accent: accentColor),
                      const SizedBox(height: 18),
                      Text(_stepTitle(), style: titleStyle),
                      const SizedBox(height: 7),
                      Text(
                        _stepSubtitle(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      if (_currentStep ==
                          PinChangeWorkflowStep.enterNewPin) ...[
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: _togglePinLength,
                          style: TextButton.styleFrom(
                            foregroundColor: accentColor,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          child: Text(
                            _selectedPinLength == 4
                                ? 'Mã 4 số · Chuyển sang 6 số'
                                : 'Mã 6 số · Chuyển sang 4 số',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      AnimatedBuilder(
                        animation: Listenable.merge(
                            [_pinRejectController, _successController]),
                        builder: (context, _) => VaultPinDots(
                          length: _targetLength,
                          enteredLength: _currentEntered.length,
                          accentColor: _isSuccessFeedback
                              ? Color.lerp(
                                  const Color(0xFF10B981),
                                  const Color(0xFFD1FAE5),
                                  1 - (2 * _successController.value - 1).abs())!
                              : accentColor,
                          isError: _pinErrorActive,
                          shakeProgress: _pinRejectController.value,
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTokens.expense,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              PrecisionNumpad(
                onDigit: _onKeyPress,
                onBackspace: _onBackspace,
                onBackspaceLongPress: _onClear,
                leadingAction: PrecisionNumpadAction(
                  label: 'C',
                  onPressed: _onClear,
                  color: const Color(0xFF94A3B8),
                  semanticLabel: 'Xóa toàn bộ',
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
