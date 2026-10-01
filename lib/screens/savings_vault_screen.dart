// ==============================================================================
// File: lib/screens/savings_vault_screen.dart
// Architecture: Digital Swiss Vault Savings Screen & Dual-Level Vault Audit Ledger
// Stack: flutter, flutter_riverpod, drift, intl, local_auth, dart:ui, dart:math
// Version: Flowy v1.0.0-beta
// Features: Frosted Glass Assets, Modern Goal Iconography, Multi-Wallet ACID,
//           Auto-Lock Privacy Shield with Root-Navigator Unlock Flow,
//           SavingsGoalDetailSheet with Progress Gauge, Quick Actions,
//           VaultMasterAuditLedgerSheet (All Vault History with Goal Badges & Filter Pills),
//           Individual Goal Audit Ledger with Two-Way Reversal Deletion,
//           Intelligent Goal Deletion with Balance Resolution (Refund or Transfer),
//           Segmented Temporal Capsule, Multi-line Note Box, Chromatic 4x4 Numpad
// ==============================================================================

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../services/vault_security_service.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_text.dart';
import '../widgets/flowy_selection_picker.dart';
import '../widgets/icon_color_picker_sheet.dart';
import '../widgets/preserved_balance_tumbler.dart';
import '../widgets/preserved_sleek_dismissible.dart';
import 'vault_auth_screen.dart';
import 'vault_pin_change_screen.dart';

class SavingsVaultScreen extends ConsumerStatefulWidget {
  const SavingsVaultScreen({super.key});

  @override
  ConsumerState<SavingsVaultScreen> createState() => _SavingsVaultScreenState();
}

class _SavingsVaultScreenState extends ConsumerState<SavingsVaultScreen>
    with WidgetsBindingObserver {
  late bool _isBalanceHidden =
      ref.read(sharedPreferencesProvider).getBool('flowy_restored_private') ??
          false;
  bool _isPrivacyShieldActive = false;
  bool _isUnlockFlowActive = false;

  static const Duration _privacyShieldFadeDuration =
  Duration(milliseconds: 150);

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_isUnlockFlowActive) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (!_isPrivacyShieldActive && mounted) {
        setState(() => _isPrivacyShieldActive = true);
      }
    }
  }

  Future<void> _openPrivacyUnlock() async {
    if (_isUnlockFlowActive) return;

    HapticFeedback.selectionClick();

    setState(() {
      _isUnlockFlowActive = true;
      _isPrivacyShieldActive = false;
    });

    await Future<void>.delayed(_privacyShieldFadeDuration);
    if (!mounted) return;

    final unlocked = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(
      PreservedPageRouteBuilder<bool>(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (context, animation, secondaryAnimation) =>
        const VaultAuthScreen(
          unlockOnly: true,
          autoStartBiometrics: true,
        ),
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

    if (!mounted) return;

    setState(() {
      _isUnlockFlowActive = false;
      _isPrivacyShieldActive = unlocked != true;
    });
  }

  String _normalizeGoalIconKey(String raw) => AppIcons.canonicalKey(raw);

  IconData _resolveGoalIcon(String raw) => AppIcons.resolve(raw);

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
        locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(amount);
  }

  Color _parseColor(String hex) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  void _openGoalDetail(BuildContext context, SavingsGoal goal) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.scrollable,
      backgroundColor: Colors.transparent,
      builder: (_, scrollController) => SavingsGoalDetailSheet(
        goalId: goal.id,
        scrollController: scrollController!,
      ),
    );
  }

  void _openMasterVaultLedger(BuildContext context) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.scrollable,
      backgroundColor: Colors.transparent,
      builder: (_, scrollController) => VaultMasterAuditLedgerSheet(
        scrollController: scrollController!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final goalsStream = ref.watch(savingsGoalsStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    final screenBackground =
    isDark ? const Color(0xFF0B0F17) : AppTokens.lightBg;
    final primaryText = isDark ? const Color(0xFFF8FAFC) : AppTokens.lightText;
    final mutedText = isDark ? const Color(0xFF94A3B8) : AppTokens.lightMuted;

    return BalancePrivacyScope(
      visible: !_isBalanceHidden,
      child: AppFeedbackDismissRegion(
        child: PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              HapticFeedback.selectionClick();
            }
          },
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: screenBackground,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                  leading: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: primaryText,
                      size: 23,
                    ),
                    tooltip: 'Đóng két',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                    },
                  ),
                  title: Text(
                    'Quỹ Tiết Kiệm',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primaryText,
                      letterSpacing: -0.2,
                    ),
                  ),
                  actions: [
                    // 🌟 Nút Lịch sử dòng tiền toàn két
                    IconButton(
                      icon: Icon(Icons.history_rounded, color: primaryText, size: 24),
                      tooltip: 'Nhật ký toàn bộ két',
                      onPressed: () => _openMasterVaultLedger(context),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Bảo mật két',
                      icon: Icon(Icons.more_horiz_rounded, color: mutedText),
                      onSelected: (value) async {
                        if (_isPrivacyShieldActive || _isUnlockFlowActive) {
                          return;
                        }
                        if (value == 'pin') {
                          await Navigator.of(context).push(
                              PreservedMaterialPageRoute(
                                  builder: (_) =>
                                  const VaultPinChangeScreen()));
                        } else if (value == 'lock') {
                          setState(() => _isPrivacyShieldActive = true);
                        } else {
                          final enabled = ref.read(vaultBiometricsProvider);
                          setState(() => _isUnlockFlowActive = true);
                          try {
                            if (!enabled) {
                              final auth = LocalAuthentication();
                              if ((await auth.getAvailableBiometrics())
                                  .isEmpty) {
                                if (mounted) {
                                  AppFeedback.showInfo(this.context,
                                      'Hãy thiết lập vân tay hoặc Face ID trong cài đặt thiết bị.');
                                }
                                return;
                              }
                              if (!await auth.authenticate(
                                  biometricOnly: true,
                                  localizedReason:
                                  'Xác nhận bật sinh trắc học cho két')) {
                                return;
                              }
                            }
                            if (!mounted) return;
                            await ref
                                .read(vaultBiometricsProvider.notifier)
                                .setEnabled(!enabled);
                          } catch (_) {
                            if (mounted) {
                              AppFeedback.showInfo(this.context,
                                  'Chưa thay đổi được sinh trắc học. Vui lòng thử lại.');
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isUnlockFlowActive = false);
                            }
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'pin', child: Text('Đổi mã PIN')),
                        CheckedPopupMenuItem(
                            value: 'biometric',
                            checked: ref.watch(vaultBiometricsProvider),
                            child: const Text('Dùng sinh trắc học')),
                        const PopupMenuItem(
                            value: 'lock', child: Text('Khóa két')),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_rounded,
                        color: accent.primary,
                        size: 25,
                      ),
                      tooltip: 'Tạo mục tiêu mới',
                      onPressed: () => _showCreateOrEditGoalModal(context),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                body: SafeArea(
                  top: false,
                  child: goalsStream.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: accent.primary,
                        strokeWidth: 2,
                      ),
                    ),
                    error: (err, stack) => Center(
                      child: Text(
                        'Không thể tải dữ liệu két.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTokens.expense,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    data: (goals) {
                      final totalProtected = goals.fold<double>(
                        0.0,
                            (sum, g) => sum + g.currentAmount,
                      );

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeroVaultCard(
                              totalProtected,
                              goals.length,
                              isDark: isDark,
                              accent: accent,
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Mục tiêu tích lũy',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: primaryText,
                                  ),
                                ),
                                Text(
                                  '(${goals.length} hũ)',
                                  style:
                                  theme.textTheme.labelMedium?.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: mutedText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (goals.isEmpty)
                              _buildEmptyGoalsState(
                                context,
                                isDark: isDark,
                                accent: accent,
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: goals.length,
                                separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                                itemBuilder: (ctx, index) {
                                  return InkWell(
                                    onTap: () =>
                                        _openGoalDetail(context, goals[index]),
                                    borderRadius: BorderRadius.circular(20),
                                    child: _buildLiquidGoalCard(
                                      goals[index],
                                      db,
                                      isDark: isDark,
                                      accent: accent,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_isPrivacyShieldActive || _isUnlockFlowActive)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _isUnlockFlowActive,
                    child: AnimatedOpacity(
                      duration: _privacyShieldFadeDuration,
                      curve: Curves.easeOutCubic,
                      opacity: _isPrivacyShieldActive ? 1.0 : 0.0,
                      child: _buildPrivacyShield(
                        context,
                        accent: accent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyShield(
      BuildContext context, {
        required AppAccentPreset accent,
      }) {
    final theme = Theme.of(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
      child: Container(
        color: const Color(0xFF070B12).withValues(alpha: 0.92),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.primary.withValues(alpha: 0.08),
                  border: Border.all(
                    color: accent.primary.withValues(alpha: 0.30),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.primary.withValues(alpha: 0.16),
                      blurRadius: 22,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 27,
                  color: accent.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Két đang tạm khóa',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Tạm ẩn thông tin để bảo vệ số dư riêng tư của bạn.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.45,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent.primary,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _openPrivacyUnlock,
                  icon: const Icon(Icons.fingerprint_rounded, size: 20),
                  label: const Text(
                    'Mở khóa ngay',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroVaultCard(
      double totalBalance,
      int totalGoals, {
        required bool isDark,
        required AppAccentPreset accent,
      }) {
    final theme = Theme.of(context);
    final surface =
    isDark ? const Color(0xEB1E2430) : Colors.white.withValues(alpha: 0.90);
    final border = isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0);
    final primaryText =
    isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedText =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -52,
                right: -32,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        accent.primary.withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: accent.primary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TỔNG TÍCH LŨY HIỆN CÓ',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                  color: mutedText,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Riêng tư',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: accent.primary,
                                    )),
                              ),
                            ],
                          ),
                        ),
                        Tooltip(
                          message: _isBalanceHidden ? 'Hiện số dư' : 'Ẩn số dư',
                          child: Semantics(
                            button: true,
                            label: _isBalanceHidden ? 'Hiện số dư' : 'Ẩn số dư',
                            child: Listener(
                              onPointerDown: (_) =>
                                  HapticFeedback.selectionClick(),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(
                                        () => _isBalanceHidden = !_isBalanceHidden),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration:
                                      const Duration(milliseconds: 180),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      child: Icon(
                                        _isBalanceHidden
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        key: ValueKey(_isBalanceHidden),
                                        size: 18,
                                        color: mutedText,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: PreservedBalanceTumbler(
                        isVisible: !_isBalanceHidden,
                        realValue: _formatCurrency(totalBalance),
                        maskedValue: '● ● ● ● ● ●',
                        height: 38,
                        debugLabel: 'SavingsVault.totalBalance',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: primaryText,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: accent.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.primary.withValues(alpha: 0.35),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            totalGoals > 0
                                ? 'Tách biệt hoàn toàn với tiền chi tiêu hàng ngày'
                                : 'Tách biệt hoàn toàn với tiền chi tiêu hàng ngày',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              color: mutedText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiquidGoalCard(
      SavingsGoal goal,
      AppDatabase db, {
        required bool isDark,
        required AppAccentPreset accent,
      }) {
    final theme = Theme.of(context);
    final progress = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = (progress * 100).round();
    final goalColor = _parseColor(goal.colorHex);

    final surface =
    isDark ? const Color(0xE61E2430) : Colors.white.withValues(alpha: 0.92);
    final border = isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0);
    final primaryText =
    isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedText =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    String? paceText;
    bool isUrgent = false;
    if (goal.targetDate != null) {
      final now = DateTime.now();
      final diffDays = goal.targetDate!
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;

      if (progress >= 1.0) {
        paceText = 'Đã hoàn thành mục tiêu';
      } else if (diffDays <= 0) {
        paceText =
        'Đã đến hạn • còn ${_formatCurrency(goal.targetAmount - goal.currentAmount)}';
        isUrgent = true;
      } else {
        final remaining = goal.targetAmount - goal.currentAmount;
        final dailyNeeded = (remaining / diffDays).ceilToDouble();
        paceText = '~${_formatCurrency(dailyNeeded)}/ngày • còn $diffDays ngày';
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: goalColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: goalColor.withValues(alpha: 0.24),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      _resolveGoalIcon(goal.icon),
                      size: 21,
                      color: goalColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text('Mục tiêu: ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11.5,
                                  color: mutedText,
                                )),
                            Expanded(
                              child: PreservedBalanceTumbler(
                                isVisible: !_isBalanceHidden,
                                realValue: _formatCurrency(goal.targetAmount),
                                maskedValue: '● ● ● ● ● ●',
                                height: 18,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: mutedText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: mutedText,
                      size: 20,
                    ),
                    color: isDark ? const Color(0xFF1E2430) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: (val) {
                      if (val == 'edit') {
                        _showCreateOrEditGoalModal(
                          context,
                          existingGoal: goal,
                        );
                      } else if (val == 'delete') {
                        _showIntelligentDeleteGoalWorkflow(context, goal, db);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: primaryText,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Chỉnh sửa mục tiêu',
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: AppTokens.expense,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Xóa hũ tích lũy',
                              style: TextStyle(
                                color: AppTokens.expense,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Text('Hiện có: ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      )),
                  Expanded(
                    child: PreservedBalanceTumbler(
                      isVisible: !_isBalanceHidden,
                      realValue: _formatCurrency(goal.currentAmount),
                      maskedValue: '● ● ● ● ● ●',
                      height: 18,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: IntrinsicWidth(
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: PreservedBalanceTumbler(
                      isVisible: !_isBalanceHidden,
                      realValue: '$progressPercent% mục tiêu',
                      isCurrency: false,
                      maskedValue: '••% mục tiêu',
                      height: 18,
                      alignment: Alignment.centerRight,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: accent.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : const Color(0xFFE2E8F0),
                    ),
                    FractionallySizedBox(
                      widthFactor: _isBalanceHidden ? 0 : progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.primary,
                              const Color(0xFF34D399),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (paceText != null) ...[
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(
                      isUrgent
                          ? Icons.schedule_rounded
                          : Icons.trending_up_rounded,
                      size: 14,
                      color: isUrgent ? AppTokens.expense : mutedText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: PreservedBalanceTumbler(
                        isVisible: !_isBalanceHidden,
                        realValue: paceText,
                        maskedValue: '● ● ● ● ● ●',
                        height: 18,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isUrgent ? AppTokens.expense : mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor: accent.primary,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _showDepositSheet(context, goal, db),
                        icon: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'Nạp thêm',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          foregroundColor: primaryText,
                          side: BorderSide(color: border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: goal.currentAmount > 0
                            ? () => _showWithdrawSheet(context, goal, db)
                            : null,
                        icon: const Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'Rút tiền',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyGoalsState(
      BuildContext context, {
        required bool isDark,
        required AppAccentPreset accent,
      }) {
    final theme = Theme.of(context);
    final primaryText =
    isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final mutedText =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xE61E2430)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accent.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.savings_outlined,
              size: 27,
              color: accent.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có mục tiêu nào',
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tạo khoản tiết kiệm cho bạn',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11.5,
              height: 1.4,
              color: mutedText,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: accent.primary,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _showCreateOrEditGoalModal(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text(
              '+ Thêm mục tiêu đầu tiên',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showDepositSheet(
      BuildContext context,
      SavingsGoal goal,
      AppDatabase db,
      ) {
    AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.scrollable,
      backgroundColor: Colors.transparent,
      builder: (_, scrollController) => _VaultDepositSheet(
        goal: goal,
        db: db,
        scrollController: scrollController!,
      ),
    );
  }

  void _showWithdrawSheet(
      BuildContext context,
      SavingsGoal goal,
      AppDatabase db,
      ) {
    AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.scrollable,
      backgroundColor: Colors.transparent,
      builder: (_, scrollController) => _VaultWithdrawSheet(
        goal: goal,
        db: db,
        scrollController: scrollController!,
      ),
    );
  }

  void _showCreateOrEditGoalModal(BuildContext context,
      {SavingsGoal? existingGoal}) {
    final titleController =
    TextEditingController(text: existingGoal?.title ?? '');
    final targetController = TextEditingController(
      text: existingGoal != null
          ? existingGoal.targetAmount.toInt().toString()
          : '',
    );
    String selectedIcon =
    _normalizeGoalIconKey(existingGoal?.icon ?? 'general');
    String selectedColor = existingGoal?.colorHex ??
        '#${ref.read(accentPresetProvider).primary.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    DateTime? selectedTargetDate = existingGoal?.targetDate;
    final titleValidation = AppValidationFeedbackController();
    final targetValidation = AppValidationFeedbackController();
    final accent = ref.read(accentPresetProvider);
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFill = isDark ? const Color(0xFF1A212D) : Colors.white;

    final icons = AppIcons.search('', topic: 'Tài chính')
        .take(11)
        .map((item) => item.key)
        .toList(growable: false);
    final colors = [
      for (final preset in AppAccentPreset.values)
        '#${preset.primary.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      '#8B5CF6',
    ];

    AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.scrollable,
      enableBlur: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx, scrollController) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Material(
              color: scheme.surface,
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                    left: 20,
                    right: 20,
                    top: 16,
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSheetHeader(
                            ctx,
                            existingGoal == null
                                ? 'Tạo mục tiêu tích lũy'
                                : 'Chỉnh sửa mục tiêu'),
                        const SizedBox(height: 18),
                        Text('TÊN MỤC TIÊU',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        AppValidationFeedback(
                          controller: titleValidation,
                          builder: (context, visual) => _VaultInputFocus(
                            color: visual.isInvalid
                                ? AppTokens.expense
                                : accent.primary,
                            child: TextField(
                              controller: titleController,
                              onChanged: (_) => titleValidation.clear(),
                              style: TextStyle(
                                  color: scheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                hintText:
                                'Ví dụ: Đàn Guitar, Mua MacBook, Quỹ khẩn cấp',
                                hintStyle: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400),
                                filled: true,
                                fillColor: inputFill,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: visual.borderColor(
                                        accent.primary.withValues(
                                            alpha: isDark ? .25 : .20)),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: visual.borderColor(
                                        accent.primary.withValues(
                                            alpha: isDark ? .25 : .20)),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: visual.isInvalid
                                        ? AppTokens.expense
                                        : accent.primary,
                                    width: visual.isInvalid ? 1.8 : 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(AppIcons.resolve(selectedIcon),
                              color: _parseColor(selectedColor)),
                          title: const Text('Biểu tượng và màu sắc'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () async {
                            final result = await IconColorPickerSheet.show(ctx,
                                initialIconName: selectedIcon,
                                initialHexColor: selectedColor,
                                title: 'Biểu tượng hũ tích lũy',
                                confirmLabel: 'Áp dụng cho hũ');
                            if (!ctx.mounted || result == null) return;
                            setModalState(() {
                              selectedIcon = result.iconName;
                              selectedColor = result.hexColor;
                            });
                          },
                        ),
                        Text('CHỌN BIỂU TƯỢNG',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: icons.length,
                            separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final icon = icons[i];
                              final isSelected = icon == selectedIcon;
                              return InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setModalState(() => selectedIcon = icon);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accent.primary
                                        : (isDark
                                        ? Colors.white
                                        .withValues(alpha: .05)
                                        : Colors.white),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: isSelected
                                        ? [
                                      BoxShadow(
                                          color: accent.primary
                                              .withValues(alpha: .35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3))
                                    ]
                                        : null,
                                    border: Border.all(
                                        width: .8,
                                        color: isSelected
                                            ? accent.primary
                                            : (isDark
                                            ? AppTokens.darkBorder
                                            : AppTokens.lightBorder)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    _resolveGoalIcon(icon),
                                    size: isSelected ? 20 : 18,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                        ? AppTokens.darkMuted
                                        : AppTokens.lightMuted),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('CHỌN MÀU CHỦ ĐẠO',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 8),
                        Row(
                          children: colors.map((hex) {
                            final isSelected = hex == selectedColor;
                            final color = _parseColor(hex);
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => selectedColor = hex);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: isSelected
                                          ? scheme.onSurface
                                          : Colors.transparent,
                                      width: 2),
                                ),
                                child: isSelected
                                    ? Icon(Icons.check,
                                    size: 16,
                                    color: _parseColor(hex)
                                        .computeLuminance() >
                                        .45
                                        ? Colors.black
                                        : Colors.white)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        Text('SỐ TIỀN MỤC TIÊU (₫)',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        AppValidationFeedback(
                          controller: targetValidation,
                          builder: (context, visual) => _VaultInputFocus(
                            color: visual.isInvalid
                                ? AppTokens.expense
                                : accent.primary,
                            child: TextField(
                              controller: targetController,
                              onChanged: (_) => targetValidation.clear(),
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: visual.isInvalid
                                    ? AppTokens.expense
                                    : scheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Ví dụ: 25000000',
                                hintStyle: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400),
                                filled: true,
                                fillColor: inputFill,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: visual.borderColor(
                                        accent.primary.withValues(
                                            alpha: isDark ? .25 : .20)),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: visual.borderColor(
                                        accent.primary.withValues(
                                            alpha: isDark ? .25 : .20)),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: visual.isInvalid
                                        ? AppTokens.expense
                                        : accent.primary,
                                    width: visual.isInvalid ? 1.8 : 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('HẠN CHÓT ĐẠT MỤC TIÊU (TÙY CHỌN)',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: inputFill,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: accent.primary.withValues(
                                          alpha: isDark ? .25 : .20)),
                                ),
                                child: Text(
                                  selectedTargetDate != null
                                      ? DateFormat('dd/MM/yyyy')
                                      .format(selectedTargetDate!)
                                      : 'Chưa đặt hạn chót',
                                  style: TextStyle(
                                    color: selectedTargetDate != null
                                        ? scheme.onSurface
                                        : scheme.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              style: IconButton.styleFrom(
                                  backgroundColor: accent.primary
                                      .withValues(alpha: .12)),
                              icon: Icon(Icons.calendar_month_rounded,
                                  color: accent.primary),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedTargetDate ??
                                      DateTime.now()
                                          .add(const Duration(days: 90)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 3650)),
                                  builder: (ctx, child) {
                                    return Theme(
                                      data: Theme.of(ctx).copyWith(
                                        colorScheme: scheme.copyWith(
                                          primary: accent.primary,
                                          surface: inputFill,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setModalState(
                                          () => selectedTargetDate = picked);
                                }
                              },
                            ),
                            if (selectedTargetDate != null)
                              IconButton(
                                icon: Icon(Icons.clear_rounded,
                                    color: scheme.onSurfaceVariant, size: 18),
                                onPressed: () => setModalState(
                                        () => selectedTargetDate = null),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent.primary,
                              foregroundColor: scheme.onPrimary,
                              elevation: 2,
                              shadowColor:
                              accent.primary.withValues(alpha: .2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: () async {
                              final title = titleController.text.trim();
                              final targetAmount = double.tryParse(
                                  targetController.text.trim()) ??
                                  0.0;

                              final titleInvalid = title.isEmpty;
                              final targetInvalid = targetAmount <= 0;
                              if (titleInvalid || targetInvalid) {
                                if (titleInvalid) {
                                  titleValidation.reject(
                                    emitHaptic: !targetInvalid,
                                  );
                                }
                                if (targetInvalid) {
                                  targetValidation.reject();
                                }
                                return;
                              }

                              final db = ref.read(databaseProvider);
                              if (existingGoal == null) {
                                await db.createSavingsGoal(
                                  id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
                                  title: title,
                                  icon: selectedIcon,
                                  colorHex: selectedColor,
                                  targetAmount: targetAmount,
                                  targetDate: selectedTargetDate,
                                );
                              } else {
                                await db.updateSavingsGoal(
                                  id: existingGoal.id,
                                  title: title,
                                  icon: selectedIcon,
                                  colorHex: selectedColor,
                                  targetAmount: targetAmount,
                                  targetDate: selectedTargetDate,
                                );
                              }

                              if (context.mounted) {
                                AppFeedback.showSuccess(
                                  context,
                                  existingGoal == null
                                      ? '✓ Đã tạo hũ tiết kiệm "$title"'
                                      : '✓ Đã cập nhật hũ tiết kiệm "$title"',
                                );
                              }
                              if (modalCtx.mounted) {
                                Navigator.of(modalCtx).pop();
                              }
                            },
                            child: Text(
                              existingGoal == null
                                  ? 'Tạo Hũ Tiết Kiệm'
                                  : 'Lưu Thay Đổi',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      titleValidation.dispose();
      targetValidation.dispose();
      titleController.dispose();
      targetController.dispose();
    });
  }

  void _showIntelligentDeleteGoalWorkflow(
      BuildContext context, SavingsGoal goal, AppDatabase db) {
    if (goal.currentAmount <= 0) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Xác nhận xóa hũ'),
          content: Text('Bạn có chắc chắn muốn xóa hũ "${goal.title}" không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () async {
                await db.deleteGoalWithBalanceResolution(goalId: goal.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  AppFeedback.showSuccess(context, 'Đã xóa hũ "${goal.title}"');
                }
              },
              child: const Text('Xóa',
                  style: TextStyle(
                      color: AppTokens.expense, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.fixed,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx, _) => _GoalBalanceResolutionSheet(
        goal: goal,
        db: db,
        onSuccess: () {
          Navigator.of(sheetCtx).pop();
          AppFeedback.showSuccess(
              context, 'Đã giải phóng số dư và xóa hũ thành công');
        },
      ),
    );
  }
}

// ==============================================================================
// 🌟 PHÂN HỆ UI: MÀN HÌNH NHẬT KÝ TOÀN BỘ KÉT (VaultMasterAuditLedgerSheet)
// ==============================================================================
class VaultMasterAuditLedgerSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const VaultMasterAuditLedgerSheet({
    super.key,
    required this.scrollController,
  });

  @override
  ConsumerState<VaultMasterAuditLedgerSheet> createState() =>
      _VaultMasterAuditLedgerSheetState();
}

class _VaultMasterAuditLedgerSheetState
    extends ConsumerState<VaultMasterAuditLedgerSheet> {
  String _activeFilter = 'all'; // 'all', 'deposit', 'withdrawal'

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
        locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(amount);
  }

  Color _parseColor(String hex) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  Map<String, List<VaultTransactionItem>> _groupByDay(
      List<VaultTransactionItem> items) {
    final Map<String, List<VaultTransactionItem>> grouped = {};
    for (final item in items) {
      final dateKey = DateFormat('dd/MM/yyyy').format(item.transaction.date);
      grouped.putIfAbsent(dateKey, () => []).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final db = ref.watch(databaseProvider);

    final goalsAsync = ref.watch(savingsGoalsStreamProvider);
    final ledgerAsync =
    ref.watch(allVaultTransactionsStreamProvider(_activeFilter));

    final totalVaultBalance = (goalsAsync.valueOrNull ?? <SavingsGoal>[])
        .fold<double>(0.0, (sum, g) => sum + g.currentAmount);

    final primaryText = isDark ? Colors.white : AppTokens.lightText;
    final mutedText = isDark ? AppTokens.darkMuted : AppTokens.lightMuted;
    final sheetSurface =
    isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final cardSurface = isDark ? const Color(0xFF1E2430) : Colors.white;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        color: sheetSurface,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            controller: widget.scrollController,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.paddingOf(context).bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: mutedText.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nhật ký dòng tiền Két Tiết Kiệm',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        CurrencyText(
                          'Tổng tích lũy hiện tại: ${_formatCurrency(totalVaultBalance)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accent.primary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Thanh lọc nhanh (Filter Pills)
                Row(
                  children: [
                    _buildFilterPill('Tất cả', 'all', accent, isDark),
                    const SizedBox(width: 8),
                    _buildFilterPill('Nạp tiền', 'deposit', accent, isDark),
                    const SizedBox(width: 8),
                    _buildFilterPill('Rút tiền', 'withdrawal', accent, isDark),
                  ],
                ),
                const SizedBox(height: 18),

                // Danh sách Gom Nhóm Theo Ngày
                ledgerAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (e, _) => Text('Lỗi tải nhật ký két: $e',
                      style: const TextStyle(color: AppTokens.expense)),
                  data: (items) {
                    if (items.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        decoration: BoxDecoration(
                          color: cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? AppTokens.darkBorder
                                : AppTokens.lightBorder,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.history_toggle_off_rounded,
                                size: 40, color: mutedText),
                            const SizedBox(height: 10),
                            Text(
                              'Chưa có giao dịch tích lũy nào thỏa mãn bộ lọc.',
                              style: TextStyle(fontSize: 12.5, color: mutedText),
                            ),
                          ],
                        ),
                      );
                    }

                    final grouped = _groupByDay(items);
                    final dateKeys = grouped.keys.toList();
                    final now = DateTime.now();
                    final todayStr = DateFormat('dd/MM/yyyy').format(now);
                    final yesterdayStr = DateFormat('dd/MM/yyyy')
                        .format(now.subtract(const Duration(days: 1)));

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dateKeys.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (ctx, dIndex) {
                        final dateStr = dateKeys[dIndex];
                        final dayItems = grouped[dateStr]!;
                        final dayHeader = dateStr == todayStr
                            ? 'HÔM NAY ($dateStr)'
                            : (dateStr == yesterdayStr
                            ? 'HÔM QUA ($dateStr)'
                            : dateStr);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                dayHeader,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: mutedText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            ...dayItems.map((item) {
                              final tx = item.transaction;
                              final goal = item.goal;
                              final isDeposit = item.isDeposit;
                              final goalColor = goal != null
                                  ? _parseColor(goal.colorHex)
                                  : accent.primary;
                              final actionColor = isDeposit
                                  ? goalColor
                                  : const Color(0xFFF59E0B);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: PreservedSleekDismissible(
                                  key: ValueKey('master_vault_tx_${tx.id}'),
                                  backgroundColor: AppTokens.expense,
                                  borderRadius: 16,
                                  onDismissed: () async {
                                    final confirmed =
                                    await AppAnimationPolicy.showPreservedDialog<bool>(
                                      context: context,
                                      barrierDismissible: true,
                                      builder: (dCtx) => AlertDialog(
                                        title: const Text('Xác nhận hoàn tác'),
                                        content: Text(
                                          isDeposit
                                              ? 'Xóa lệnh nạp này sẽ giảm ${_formatCurrency(tx.amount)} trong hũ và hoàn trả tiền về ví?'
                                              : 'Xóa lệnh rút này sẽ tăng lại ${_formatCurrency(tx.amount)} vào hũ và trừ tiền ví?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dCtx).pop(false),
                                            child: const Text('Hủy'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTokens.expense),
                                            onPressed: () =>
                                                Navigator.of(dCtx).pop(true),
                                            child: const Text('Xác nhận xóa',
                                                style: TextStyle(color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true) {
                                      await db.deleteVaultTransactionAtomically(tx.id);
                                      if (context.mounted) {
                                        AppFeedback.showSuccess(context,
                                            'Đã hoàn tác giao dịch và cân bằng số dư');
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: cardSurface,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark
                                            ? AppTokens.darkBorder
                                            : AppTokens.lightBorder,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: actionColor.withValues(alpha: 0.15),
                                            borderRadius:
                                            BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            isDeposit
                                                ? Icons.south_west_rounded
                                                : Icons.north_east_rounded,
                                            size: 16,
                                            color: actionColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  if (goal != null) ...[
                                                    Container(
                                                      padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: goalColor.withValues(alpha: 0.14),
                                                        borderRadius:
                                                        BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        goal.title,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w800,
                                                          color: goalColor,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                  ],
                                                  Expanded(
                                                    child: Text(
                                                      isDeposit
                                                          ? 'Từ ví: ${item.wallet?.name ?? 'Ví'}'
                                                          : 'Về ví: ${item.wallet?.name ?? 'Ví'}',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: primaryText,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '${DateFormat('HH:mm').format(tx.date)}${tx.note != null && tx.note!.isNotEmpty ? ' • ${tx.note}' : ''}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontSize: 11, color: mutedText),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${isDeposit ? '+' : '-'}${_formatCurrency(tx.amount)}',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: actionColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill(
      String label, String filterKey, AppAccentPreset accent, bool isDark) {
    final isSelected = _activeFilter == filterKey;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeFilter = filterKey);
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.primary.withValues(alpha: 0.16)
              : (isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? accent.primary
                : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? accent.primary
                : (isDark ? AppTokens.darkText : AppTokens.lightText),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 🌟 PHÂN HỆ UI: MÀN HÌNH CHI TIẾT HŨ TÍCH LŨY & NHẬT KÝ (SavingsGoalDetailSheet)
// ==============================================================================
class SavingsGoalDetailSheet extends ConsumerWidget {
  final String goalId;
  final ScrollController scrollController;

  const SavingsGoalDetailSheet({
    super.key,
    required this.goalId,
    required this.scrollController,
  });

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
        locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(amount);
  }

  Color _parseColor(String hex) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final db = ref.watch(databaseProvider);

    final goalsAsync = ref.watch(savingsGoalsStreamProvider);
    final transactionsAsync =
    ref.watch(vaultTransactionsByGoalStreamProvider(goalId));

    final goal = goalsAsync.valueOrNull
        ?.where((g) => g.id == goalId)
        .firstOrNull;

    if (goal == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(child: Text('Không tìm thấy mục tiêu tích lũy.')),
      );
    }

    final goalColor = _parseColor(goal.colorHex);
    final progress = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = (progress * 100).round();
    final remainingAmount =
    math.max(0.0, goal.targetAmount - goal.currentAmount);

    String deadlineText = 'Chưa đặt hạn chót';
    if (goal.targetDate != null) {
      final diff = goal.targetDate!
          .difference(DateTime.now())
          .inDays;
      deadlineText = diff >= 0
          ? 'Hạn: ${DateFormat('dd/MM/yyyy').format(goal.targetDate!)} (còn $diff ngày)'
          : 'Đã quá hạn (${DateFormat('dd/MM/yyyy').format(goal.targetDate!)})';
    }

    final primaryText = isDark ? Colors.white : AppTokens.lightText;
    final mutedText = isDark ? AppTokens.darkMuted : AppTokens.lightMuted;
    final sheetSurface =
    isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final cardSurface = isDark ? const Color(0xFF1E2430) : Colors.white;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        color: sheetSurface,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.paddingOf(context).bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: mutedText.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: goalColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            AppIcons.resolve(goal.icon),
                            color: goalColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: primaryText,
                              ),
                            ),
                            Text(
                              'Chi tiết mục tiêu tích lũy',
                              style: TextStyle(fontSize: 11, color: mutedText),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TIẾN ĐỘ HIỆN TẠI',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: mutedText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$progressPercent%',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: goalColor,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_formatCurrency(goal.currentAmount)} / ${_formatCurrency(goal.targetAmount)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                remainingAmount > 0
                                    ? 'Còn thiếu ${_formatCurrency(remainingAmount)}'
                                    : '✓ Đã đạt chỉ tiêu',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: remainingAmount > 0
                                      ? AppTokens.expense
                                      : AppTokens.income,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Stack(
                          children: [
                            Container(
                              height: 10,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFE2E8F0),
                            ),
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: goalColor,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 13, color: mutedText),
                          const SizedBox(width: 6),
                          Text(
                            deadlineText,
                            style: TextStyle(fontSize: 11, color: mutedText),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: goalColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            AppAnimationPolicy.showFluidSheet<void>(
                              context: context,
                              mode: FluidSheetMode.scrollable,
                              backgroundColor: Colors.transparent,
                              builder: (_, scroll) => _VaultDepositSheet(
                                goal: goal,
                                db: db,
                                scrollController: scroll!,
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                          label: const Text(
                            '+ Nạp thêm',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryText,
                            side: BorderSide(
                              color: isDark
                                  ? AppTokens.darkBorder
                                  : AppTokens.lightBorder,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: goal.currentAmount > 0
                              ? () {
                            AppAnimationPolicy.showFluidSheet<void>(
                              context: context,
                              mode: FluidSheetMode.scrollable,
                              backgroundColor: Colors.transparent,
                              builder: (_, scroll) => _VaultWithdrawSheet(
                                goal: goal,
                                db: db,
                                scrollController: scroll!,
                              ),
                            );
                          }
                              : null,
                          icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                          label: const Text(
                            '⤓ Rút tiền',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'NHẬT KÝ TÍCH LŨY HŨ NÀY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: mutedText,
                      ),
                    ),
                    transactionsAsync.maybeWhen(
                      data: (txs) => Text(
                        '${txs.length} biến động',
                        style: TextStyle(fontSize: 11, color: mutedText),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                transactionsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (e, _) => Text('Lỗi tải nhật ký: $e',
                      style: const TextStyle(color: AppTokens.expense)),
                  data: (items) {
                    if (items.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          color: cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? AppTokens.darkBorder
                                : AppTokens.lightBorder,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.history_toggle_off_rounded,
                                size: 36, color: mutedText),
                            const SizedBox(height: 8),
                            Text(
                              'Chưa có lịch sử nạp rút nào cho hũ này.',
                              style: TextStyle(fontSize: 12, color: mutedText),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final item = items[index];
                        final tx = item.transaction;
                        final isDeposit = item.isDeposit;
                        final actionColor = isDeposit
                            ? goalColor
                            : const Color(0xFFF59E0B);

                        return PreservedSleekDismissible(
                          key: ValueKey('vault_tx_${tx.id}'),
                          backgroundColor: AppTokens.expense,
                          borderRadius: 16,
                          onDismissed: () async {
                            final confirmed =
                            await AppAnimationPolicy.showPreservedDialog<bool>(
                              context: context,
                              barrierDismissible: true,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Xác nhận hoàn tác'),
                                content: Text(
                                  isDeposit
                                      ? 'Xóa lệnh nạp này sẽ giảm ${_formatCurrency(tx.amount)} trong hũ và hoàn trả tiền về ví?'
                                      : 'Xóa lệnh rút này sẽ tăng lại ${_formatCurrency(tx.amount)} vào hũ và trừ tiền ví?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dCtx).pop(false),
                                    child: const Text('Hủy'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTokens.expense),
                                    onPressed: () =>
                                        Navigator.of(dCtx).pop(true),
                                    child: const Text('Xác nhận xóa',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              await db.deleteVaultTransactionAtomically(tx.id);
                              if (context.mounted) {
                                AppFeedback.showSuccess(
                                    context, 'Đã hoàn tác giao dịch và cân bằng số dư');
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: cardSurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? AppTokens.darkBorder
                                    : AppTokens.lightBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: actionColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isDeposit
                                        ? Icons.south_west_rounded
                                        : Icons.north_east_rounded,
                                    size: 16,
                                    color: actionColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isDeposit
                                            ? 'Nạp từ: ${item.wallet?.name ?? 'Ví'}'
                                            : 'Rút về: ${item.wallet?.name ?? 'Ví'}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${DateFormat('HH:mm • dd/MM/yyyy').format(tx.date)}${tx.note != null && tx.note!.isNotEmpty ? ' • ${tx.note}' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11, color: mutedText),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${isDeposit ? '+' : '-'}${_formatCurrency(tx.amount)}',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: actionColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 🌟 BOTTOM SHEET: GIẢI PHÓNG DÒNG TIỀN KHI XÓA HŨ CÒN SỐ DƯ
// ==============================================================================
class _GoalBalanceResolutionSheet extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  final AppDatabase db;
  final VoidCallback onSuccess;

  const _GoalBalanceResolutionSheet({
    required this.goal,
    required this.db,
    required this.onSuccess,
  });

  @override
  ConsumerState<_GoalBalanceResolutionSheet> createState() =>
      _GoalBalanceResolutionSheetState();
}

class _GoalBalanceResolutionSheetState
    extends ConsumerState<_GoalBalanceResolutionSheet> {
  int _resolutionMode = 0; // 0: Hoàn tiền về ví, 1: Chuyển sang hũ khác
  String? _selectedWalletId;
  String? _selectedDestinationGoalId;
  bool _isSubmitting = false;

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
        locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
        .format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final goalsAsync = ref.watch(savingsGoalsStreamProvider);

    return StreamBuilder<List<Wallet>>(
      stream: widget.db.watchAllWallets(),
      builder: (context, snapshot) {
        final wallets = snapshot.data ?? <Wallet>[];
        final otherGoals = (goalsAsync.valueOrNull ?? <SavingsGoal>[])
            .where((g) => g.id != widget.goal.id)
            .toList();

        if (_selectedWalletId == null && wallets.isNotEmpty) {
          _selectedWalletId = wallets.first.id;
        }
        if (_selectedDestinationGoalId == null && otherGoals.isNotEmpty) {
          _selectedDestinationGoalId = otherGoals.first.id;
        }

        final primaryText = isDark ? Colors.white : AppTokens.lightText;
        final mutedText = isDark ? AppTokens.darkMuted : AppTokens.lightMuted;
        final cardSurface = isDark ? const Color(0xFF1E2430) : Colors.white;

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151C28) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: mutedText.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'HŨ VẪN CÒN SỐ DƯ TÍCH LŨY',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTokens.expense,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Mục tiêu "${widget.goal.title}" đang lưu trữ ${_formatCurrency(widget.goal.currentAmount)}. Vui lòng chọn cách xử lý dòng tiền trước khi xóa hũ:',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: mutedText),
                ),
                const SizedBox(height: 16),

                // Lựa chọn 1: Hoàn tiền về ví
                RadioListTile<int>(
                  value: 0,
                  groupValue: _resolutionMode,
                  contentPadding: EdgeInsets.zero,
                  activeColor: accent.primary,
                  title: Text(
                    'Hoàn trả toàn bộ về Ví:',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryText),
                  ),
                  subtitle: _resolutionMode == 0
                      ? Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: FlowyDropdown<String>(
                      value: _selectedWalletId,
                      dropdownColor: cardSurface,
                      isExpanded: true,
                      items: walletPickerItems(wallets),
                      title: 'Chọn ví nhận tiền',
                      onChanged: (val) =>
                          setState(() => _selectedWalletId = val),
                    ),
                  )
                      : null,
                  onChanged: (val) => setState(() => _resolutionMode = val ?? 0),
                ),

                // Lựa chọn 2: Chuyển sang hũ khác
                RadioListTile<int>(
                  value: 1,
                  groupValue: _resolutionMode,
                  contentPadding: EdgeInsets.zero,
                  activeColor: accent.primary,
                  title: Text(
                    'Chuyển toàn bộ sang Hũ tích lũy khác:',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryText),
                  ),
                  subtitle: _resolutionMode == 1
                      ? Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: otherGoals.isEmpty
                        ? const Text('Chưa có hũ nào khác để chuyển.',
                        style: TextStyle(
                            fontSize: 11, color: AppTokens.expense))
                        : FlowyDropdown<String>(
                      value: _selectedDestinationGoalId,
                      dropdownColor: cardSurface,
                      isExpanded: true,
                      items: otherGoals.map((g) {
                        return DropdownMenuItem<String>(
                          value: g.id,
                          child: Row(
                            children: [
                              Icon(AppIcons.resolve(g.icon), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  g.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      title: 'Chọn hũ nhận tiền',
                      onChanged: (val) => setState(
                              () => _selectedDestinationGoalId = val),
                    ),
                  )
                      : null,
                  onChanged: otherGoals.isEmpty
                      ? null
                      : (val) => setState(() => _resolutionMode = val ?? 1),
                ),
                const SizedBox(height: 20),

                // Nút Thao tác
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('HỦY'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTokens.expense,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                          setState(() => _isSubmitting = true);
                          try {
                            if (_resolutionMode == 0) {
                              await widget.db.deleteGoalWithBalanceResolution(
                                goalId: widget.goal.id,
                                refundWalletId: _selectedWalletId,
                              );
                            } else {
                              await widget.db.deleteGoalWithBalanceResolution(
                                goalId: widget.goal.id,
                                transferToGoalId: _selectedDestinationGoalId,
                              );
                            }
                            widget.onSuccess();
                          } catch (e) {
                            setState(() => _isSubmitting = false);
                            if (context.mounted) {
                              AppFeedback.showError(
                                  context, 'Lỗi giải phóng số dư: $e');
                            }
                          }
                        },
                        child: _isSubmitting
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                            : const Text('XÁC NHẬN & XÓA'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==============================================================================
// 🌟 HEADER CHUNG CHO CÁC SHEET KÉT TIẾT KIỆM
// ==============================================================================
Widget _buildSheetHeader(BuildContext context, String title,
    {bool enabled = true}) {
  final scheme = Theme.of(context).colorScheme;
  return Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
      ),
      const SizedBox(width: 12),
      IconButton(
        tooltip: 'Đóng',
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: scheme.onSurface.withValues(alpha: .06),
          foregroundColor: scheme.onSurfaceVariant,
          shape: const CircleBorder(),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: !enabled
            ? null
            : () {
          if (ModalRoute.of(context)?.isCurrent == true) {
            Navigator.of(context).pop();
          }
        },
        icon: const Icon(Icons.close_rounded, size: 20),
      ),
    ],
  );
}

// ==============================================================================
// 🌟 PHÍM SỐ NUMPAD ĐÀN HỒI (0.93X PRESS FEEDBACK)
// ==============================================================================
class _VaultNumpadKey extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color textColor;
  final Color bgColor;

  const _VaultNumpadKey({
    required this.label,
    required this.onTap,
    required this.textColor,
    required this.bgColor,
  });

  @override
  State<_VaultNumpadKey> createState() => _VaultNumpadKeyState();
}

class _VaultNumpadKeyState extends State<_VaultNumpadKey>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
      reverseDuration: const Duration(milliseconds: 80),
      debugLabel: 'VaultNumpadKey.${widget.label}',
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: widget.bgColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          child: Container(
            height: 42,
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: widget.label.startsWith('+') ? 12.5 : 16,
                fontWeight: FontWeight.bold,
                color: widget.textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 🌟 BÀN PHÍM NUMPAD 4X4 ĐÀN HỒI THEO ACCENT THEME
// ==============================================================================
Widget _buildVaultChromaticNumpad({
  required bool isDark,
  required Color actionColor,
  required String expression,
  required ValueChanged<String> onKeyPress,
}) {
  final rows = [
    ['7', '8', '9', '+50k'],
    ['4', '5', '6', '+100k'],
    ['1', '2', '3', '+200k'],
    ['C', '0', '000', '⌫'],
  ];

  final Color normalKeyBg =
  isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle;
  final Color shortcutKeyBg =
  isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9);
  final Color normalKeyText =
  isDark ? AppTokens.darkText : AppTokens.lightText;

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: rows.map((row) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          children: row.map((key) {
            Color keyBg = normalKeyBg;
            Color keyText = normalKeyText;
            if (key.startsWith('+')) {
              keyBg = shortcutKeyBg;
              keyText = actionColor;
            } else if (key == 'C') {
              final bool hasInput = expression != '0' && expression.isNotEmpty;
              keyBg = hasInput
                  ? AppTokens.expense.withValues(alpha: 0.12)
                  : normalKeyBg;
              keyText = hasInput
                  ? AppTokens.expense
                  : (isDark ? Colors.white30 : Colors.black26);
            } else if (key == '⌫') {
              keyBg = normalKeyBg;
              keyText = isDark ? Colors.white70 : Colors.black87;
            }

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3.0),
                child: _VaultNumpadKey(
                  label: key,
                  bgColor: keyBg,
                  textColor: keyText,
                  onTap: () => onKeyPress(key),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }).toList(),
  );
}

// ==============================================================================
// 🌟 BOTTOM SHEET NẠP TIỀN VÀO HŨ TIẾT KIỆM (DEPOSIT)
// ==============================================================================
class _VaultDepositSheet extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  final AppDatabase db;
  final ScrollController scrollController;

  const _VaultDepositSheet({
    required this.goal,
    required this.db,
    required this.scrollController,
  });

  @override
  ConsumerState<_VaultDepositSheet> createState() => _VaultDepositSheetState();
}

class _VaultDepositSheetState extends ConsumerState<_VaultDepositSheet>
    with TickerProviderStateMixin {
  final amountValidation = AppValidationFeedbackController();
  late final Stream<List<Wallet>> _walletsStream;
  String _expression = '0';
  String? _selectedWalletId;
  late DateTime _selectedDate;
  late final TextEditingController _noteController;
  bool _isSubmitting = false;

  late final AnimationController _morphButtonController;
  late final AnimationController _checkIconController;
  late final Animation<double> _morphWidthAnimation;
  late final Animation<double> _checkScaleAnimation;
  bool _isSuccessMorphed = false;

  @override
  void initState() {
    super.initState();
    _walletsStream = widget.db.watchAllWallets();
    _selectedDate = DateTime.now();
    _noteController = TextEditingController();

    _morphButtonController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      debugLabel: 'VaultDeposit.MorphButton',
    );
    _morphWidthAnimation = CurvedAnimation(
      parent: _morphButtonController,
      curve: Curves.easeInOutCubic,
    );

    _checkIconController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      debugLabel: 'VaultDeposit.CheckIcon',
    );
    _checkScaleAnimation = CurvedAnimation(
      parent: _checkIconController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    amountValidation.dispose();
    _noteController.dispose();
    _morphButtonController.dispose();
    _checkIconController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
          .format(amount);

  Color _parseGoalColor(String hex) {
    try {
      final cleanHex = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  double _evaluateExpression() {
    try {
      final sanitized = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      final List<String> tokens = [];
      String currentNumber = '';

      for (int i = 0; i < sanitized.length; i++) {
        final char = sanitized[i];
        if ('+-*/'.contains(char)) {
          if (currentNumber.isNotEmpty) {
            tokens.add(currentNumber);
            currentNumber = '';
          }
          tokens.add(char);
        } else {
          currentNumber += char;
        }
      }
      if (currentNumber.isNotEmpty) tokens.add(currentNumber);
      if (tokens.isEmpty) return 0.0;

      final List<String> pass1 = [];
      int idx = 0;
      while (idx < tokens.length) {
        if (tokens[idx] == '*' || tokens[idx] == '/') {
          final op = tokens[idx];
          final prevNum = double.parse(pass1.removeLast());
          final nextNum = double.parse(tokens[idx + 1]);
          final res = op == '*'
              ? prevNum * nextNum
              : (nextNum != 0 ? prevNum / nextNum : 0.0);
          pass1.add(res.toString());
          idx += 2;
        } else {
          pass1.add(tokens[idx]);
          idx++;
        }
      }

      double total = double.parse(pass1[0]);
      idx = 1;
      while (idx < pass1.length) {
        final op = pass1[idx];
        final nextNum = double.parse(pass1[idx + 1]);
        if (op == '+') total += nextNum;
        if (op == '-') total -= nextNum;
        idx += 2;
      }
      return total < 0 ? 0.0 : total;
    } catch (_) {
      return 0.0;
    }
  }

  void _onNumpadPress(String key) {
    setState(() {
      if (key == 'C') {
        _expression = '0';
      } else if (key == '⌫') {
        if (_expression.length > 1) {
          _expression = _expression.substring(0, _expression.length - 1);
        } else {
          _expression = '0';
        }
      } else if (key == '000') {
        if (_expression != '0' && _expression.length <= 10) {
          _expression += '000';
        }
      } else if (key == '+50k') {
        final current = _evaluateExpression();
        _expression = (current + 50000).toStringAsFixed(0);
      } else if (key == '+100k') {
        final current = _evaluateExpression();
        _expression = (current + 100000).toStringAsFixed(0);
      } else if (key == '+200k') {
        final current = _evaluateExpression();
        _expression = (current + 200000).toStringAsFixed(0);
      } else {
        if (_expression == '0') {
          _expression = key;
        } else if (_expression.length <= 11) {
          _expression += key;
        }
      }
    });
    amountValidation.clear();
  }

  String _formatDateChipLabel(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) return 'Hôm nay, ${DateFormat('dd/MM').format(date)}';
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    if (isYesterday) return 'Hôm qua, ${DateFormat('dd/MM').format(date)}';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  void _openCalendar(bool isDark, AppAccentPreset accent) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      useRootNavigator: true,
      builder: (_, __) => _VaultMiniCalendarSheet(
        initialDate: _selectedDate,
        isDark: isDark,
        accent: accent,
        onDateSelected: (newDate) {
          setState(() {
            _selectedDate = DateTime(
              newDate.year,
              newDate.month,
              newDate.day,
              _selectedDate.hour,
              _selectedDate.minute,
              _selectedDate.second,
            );
          });
        },
      ),
    );
  }

  void _openTimePicker(bool isDark, AppAccentPreset accent) async {
    HapticFeedback.selectionClick();
    final initialTime = TimeOfDay(
      hour: _selectedDate.hour,
      minute: _selectedDate.minute,
    );

    final pickedTime = await AppAnimationPolicy.showFluidSheet<TimeOfDay>(
      context: context,
      mode: FluidSheetMode.fixed,
      isDismissible: true,
      canDismiss: () => false,
      useRootNavigator: true,
      builder: (ctx, _) => _VaultTimePickerSheet(
        initialTime: initialTime,
        isDark: isDark,
        accent: accent,
      ),
    );

    if (pickedTime != null && mounted) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goalActionColor = _parseGoalColor(widget.goal.colorHex);

    final sheetSurface =
    isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final cardSurface = isDark ? const Color(0xFF1E2430) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedText =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textMuted =
    isDark ? const Color(0xFF85A497) : const Color(0xFF536D62);

    final double calculatedAmount = _evaluateExpression();
    final bool canSubmit = calculatedAmount > 0 && !_isSubmitting;

    return StreamBuilder<List<Wallet>>(
      stream: _walletsStream,
      builder: (context, snapshot) {
        final wallets = snapshot.data ?? const <Wallet>[];

        if (_selectedWalletId == null && wallets.isNotEmpty) {
          _selectedWalletId = wallets.first.id;
        }

        final selectedWallet = wallets.cast<Wallet?>().firstWhere(
              (wallet) => wallet?.id == _selectedWalletId,
          orElse: () => null,
        );

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            color: sheetSurface,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                controller: widget.scrollController,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.paddingOf(context).bottom + 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: mutedText.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nạp tiền vào quỹ',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Dành cho mục tiêu: ${widget.goal.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            tooltip: 'Đóng',
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).pop();
                            },
                            icon: Icon(
                              Icons.close_rounded,
                              size: 21,
                              color: mutedText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Nguồn tiền trích',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FlowyDropdown<String>(
                      value: _selectedWalletId,
                      dropdownColor: cardSurface,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: mutedText,
                      ),
                      hint: Text(
                        'Chọn nguồn tiền',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      items: walletPickerItems(wallets),
                      itemsStream: widget.db
                          .watchAllWallets()
                          .map(walletPickerItems),
                      title: 'Chọn nguồn tiền',
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedWalletId = value;
                          amountValidation.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    AppValidationFeedback(
                      controller: amountValidation,
                      builder: (context, visual) => Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardSurface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: goalActionColor.withValues(alpha: .04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: visual.borderColor(
                                goalActionColor.withValues(alpha: .35)),
                            width: visual.isInvalid ? 1.8 : 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'Số tiền tích lũy',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: mutedText,
                                  ),
                                ),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _formatCurrency(calculatedAmount),
                                      style: currencyTextStyle(
                                        context,
                                        TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                          color: visual.isInvalid
                                              ? AppTokens.expense
                                              : goalActionColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: CurrencyText(
                                    selectedWallet != null
                                        ? 'Khả dụng: ${_formatCurrency(selectedWallet.balance)}'
                                        : 'Chưa chọn ví',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: mutedText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: selectedWallet == null
                                      ? null
                                      : () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _expression = selectedWallet
                                          .balance
                                          .clamp(0.0, double.infinity)
                                          .toInt()
                                          .toString();
                                      amountValidation.clear();
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: goalActionColor
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: goalActionColor
                                            .withValues(alpha: 0.3),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Text(
                                      'Toàn bộ ví',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: goalActionColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppTokens.darkBorder
                              : AppTokens.lightBorder,
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openCalendar(isDark, ref.read(accentPresetProvider)),
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(16),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 16,
                                        color: textMuted,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _formatDateChipLabel(_selectedDate),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: primaryText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: isDark
                                ? AppTokens.darkBorder
                                : AppTokens.lightBorder,
                          ),
                          Expanded(
                            flex: 4,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openTimePicker(isDark, ref.read(accentPresetProvider)),
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(16),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 16,
                                        color: textMuted,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('HH:mm')
                                            .format(_selectedDate),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: primaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTokens.darkCardSubtle
                            : AppTokens.lightCardSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? AppTokens.darkBorder
                              : AppTokens.lightBorder,
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 10, right: 8),
                            child: Icon(
                              Icons.edit_note_rounded,
                              size: 20,
                              color: textMuted,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _noteController,
                              minLines: 1,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: primaryText,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Thêm ghi chú nạp két...',
                                hintStyle: TextStyle(
                                  fontSize: 12.5,
                                  color: mutedText,
                                ),
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _buildVaultChromaticNumpad(
                      isDark: isDark,
                      actionColor: goalActionColor,
                      expression: _expression,
                      onKeyPress: _onNumpadPress,
                    ),
                    const SizedBox(height: 14),

                    Center(
                      child: AnimatedBuilder(
                        animation: _morphWidthAnimation,
                        builder: (context, child) {
                          final double fullWidth =
                              MediaQuery.of(context).size.width - 40;
                          final double currentWidth = _isSuccessMorphed
                              ? fullWidth -
                              (fullWidth - 50.0) *
                                  _morphWidthAnimation.value
                              : fullWidth;

                          return SizedBox(
                            width: currentWidth,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: goalActionColor,
                                foregroundColor: Colors.white,
                                elevation: canSubmit ? 2 : 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    _isSuccessMorphed
                                        ? 16.0 +
                                        (9.0 * _morphWidthAnimation.value)
                                        : 16.0,
                                  ),
                                ),
                              ),
                              onPressed: !canSubmit
                                  ? null
                                  : () async {
                                if (selectedWallet == null) {
                                  AppFeedback.showInfo(
                                    context,
                                    'Chưa có nguồn tiền khả dụng.',
                                  );
                                  return;
                                }

                                if (calculatedAmount <= 0 ||
                                    calculatedAmount >
                                        selectedWallet.balance) {
                                  amountValidation.reject();
                                  return;
                                }

                                setState(() => _isSubmitting = true);

                                try {
                                  await widget.db.depositToGoal(
                                    goalId: widget.goal.id,
                                    walletId: selectedWallet.id,
                                    amount: calculatedAmount,
                                    date: _selectedDate,
                                    note: _noteController.text.trim().isEmpty
                                        ? null
                                        : _noteController.text.trim(),
                                  );

                                  setState(
                                          () => _isSuccessMorphed = true);
                                  await _morphButtonController.forward(
                                      from: 0.0);
                                  HapticFeedback.mediumImpact();
                                  await _checkIconController.forward(
                                      from: 0.0);
                                  await Future.delayed(
                                      const Duration(milliseconds: 250));

                                  if (context.mounted) {
                                    AppFeedback.showSuccess(
                                      context,
                                      'Đã nạp ${_formatCurrency(calculatedAmount)} vào "${widget.goal.title}".',
                                    );
                                  }

                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                } catch (e) {
                                  debugPrint(
                                      'SavingsVault deposit failed: $e');
                                  if (mounted) {
                                    setState(
                                            () => _isSubmitting = false);
                                    AppFeedback.showError(
                                      context,
                                      'Không thể nạp tiền vào hũ. Vui lòng thử lại.',
                                    );
                                  }
                                }
                              },
                              child: _isSuccessMorphed
                                  ? ScaleTransition(
                                scale: _checkScaleAnimation,
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 26),
                              )
                                  : (_isSubmitting
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation(
                                      Colors.white),
                                ),
                              )
                                  : const Text(
                                '✓  XÁC NHẬN NẠP TIỀN',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              )),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==============================================================================
// 🌟 BOTTOM SHEET RÚT TIỀN TỪ HŨ VỀ VÍ (WITHDRAW)
// ==============================================================================
class _VaultWithdrawSheet extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  final AppDatabase db;
  final ScrollController scrollController;

  const _VaultWithdrawSheet({
    required this.goal,
    required this.db,
    required this.scrollController,
  });

  @override
  ConsumerState<_VaultWithdrawSheet> createState() =>
      _VaultWithdrawSheetState();
}

class _VaultWithdrawSheetState extends ConsumerState<_VaultWithdrawSheet>
    with TickerProviderStateMixin {
  final amountValidation = AppValidationFeedbackController();
  late final Stream<List<Wallet>> _walletsStream;
  String _expression = '';
  String? _selectedWalletId;
  late DateTime _selectedDate;
  late final TextEditingController _noteController;
  bool _isSubmitting = false;

  late final AnimationController _morphButtonController;
  late final AnimationController _checkIconController;
  late final Animation<double> _morphWidthAnimation;
  late final Animation<double> _checkScaleAnimation;
  bool _isSuccessMorphed = false;

  static const Color _withdrawAccent = Color(0xFF0284C7);

  @override
  void initState() {
    super.initState();
    _walletsStream = widget.db.watchAllWallets();
    _selectedDate = DateTime.now();
    _noteController = TextEditingController();

    _morphButtonController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      debugLabel: 'VaultWithdraw.MorphButton',
    );
    _morphWidthAnimation = CurvedAnimation(
      parent: _morphButtonController,
      curve: Curves.easeInOutCubic,
    );

    _checkIconController = AppAnimationPolicy.createController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      debugLabel: 'VaultWithdraw.CheckIcon',
    );
    _checkScaleAnimation = CurvedAnimation(
      parent: _checkIconController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    amountValidation.dispose();
    _noteController.dispose();
    _morphButtonController.dispose();
    _checkIconController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) =>
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
          .format(amount);

  double _evaluateExpression() {
    try {
      final sanitized = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      final List<String> tokens = [];
      String currentNumber = '';

      for (int i = 0; i < sanitized.length; i++) {
        final char = sanitized[i];
        if ('+-*/'.contains(char)) {
          if (currentNumber.isNotEmpty) {
            tokens.add(currentNumber);
            currentNumber = '';
          }
          tokens.add(char);
        } else {
          currentNumber += char;
        }
      }
      if (currentNumber.isNotEmpty) tokens.add(currentNumber);
      if (tokens.isEmpty) return 0.0;

      final List<String> pass1 = [];
      int idx = 0;
      while (idx < tokens.length) {
        if (tokens[idx] == '*' || tokens[idx] == '/') {
          final op = tokens[idx];
          final prevNum = double.parse(pass1.removeLast());
          final nextNum = double.parse(tokens[idx + 1]);
          final res = op == '*'
              ? prevNum * nextNum
              : (nextNum != 0 ? prevNum / nextNum : 0.0);
          pass1.add(res.toString());
          idx += 2;
        } else {
          pass1.add(tokens[idx]);
          idx++;
        }
      }

      double total = double.parse(pass1[0]);
      idx = 1;
      while (idx < pass1.length) {
        final op = pass1[idx];
        final nextNum = double.parse(pass1[idx + 1]);
        if (op == '+') total += nextNum;
        if (op == '-') total -= nextNum;
        idx += 2;
      }
      return total < 0 ? 0.0 : total;
    } catch (_) {
      return 0.0;
    }
  }

  void _onNumpadPress(String key) {
    setState(() {
      if (key == 'C') {
        _expression = '0';
      } else if (key == '⌫') {
        if (_expression.length > 1) {
          _expression = _expression.substring(0, _expression.length - 1);
        } else {
          _expression = '0';
        }
      } else if (key == '000') {
        if (_expression != '0' && _expression.length <= 10) {
          _expression += '000';
        }
      } else if (key == '+50k') {
        final current = _evaluateExpression();
        _expression = (current + 50000).toStringAsFixed(0);
      } else if (key == '+100k') {
        final current = _evaluateExpression();
        _expression = (current + 100000).toStringAsFixed(0);
      } else if (key == '+200k') {
        final current = _evaluateExpression();
        _expression = (current + 200000).toStringAsFixed(0);
      } else {
        if (_expression == '0' || _expression.isEmpty) {
          _expression = key;
        } else if (_expression.length <= 11) {
          _expression += key;
        }
      }
    });
    amountValidation.clear();
  }

  String _formatDateChipLabel(DateTime date) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) return 'Hôm nay, ${DateFormat('dd/MM').format(date)}';
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
    if (isYesterday) return 'Hôm qua, ${DateFormat('dd/MM').format(date)}';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  void _openCalendar(bool isDark, AppAccentPreset accent) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      useRootNavigator: true,
      builder: (_, __) => _VaultMiniCalendarSheet(
        initialDate: _selectedDate,
        isDark: isDark,
        accent: accent,
        onDateSelected: (newDate) {
          setState(() {
            _selectedDate = DateTime(
              newDate.year,
              newDate.month,
              newDate.day,
              _selectedDate.hour,
              _selectedDate.minute,
              _selectedDate.second,
            );
          });
        },
      ),
    );
  }

  void _openTimePicker(bool isDark, AppAccentPreset accent) async {
    HapticFeedback.selectionClick();
    final initialTime = TimeOfDay(
      hour: _selectedDate.hour,
      minute: _selectedDate.minute,
    );

    final pickedTime = await AppAnimationPolicy.showFluidSheet<TimeOfDay>(
      context: context,
      mode: FluidSheetMode.fixed,
      isDismissible: true,
      canDismiss: () => false,
      useRootNavigator: true,
      builder: (ctx, _) => _VaultTimePickerSheet(
        initialTime: initialTime,
        isDark: isDark,
        accent: accent,
      ),
    );

    if (pickedTime != null && mounted) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sheetSurface =
    isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final cardSurface = isDark ? const Color(0xFF1E2430) : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedText =
    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final textMuted =
    isDark ? const Color(0xFF85A497) : const Color(0xFF536D62);

    final double calculatedAmount = _evaluateExpression();
    final bool canSubmit = calculatedAmount > 0 && !_isSubmitting;

    return StreamBuilder<List<Wallet>>(
      stream: _walletsStream,
      builder: (context, snapshot) {
        final wallets = snapshot.data ?? const <Wallet>[];

        if (_selectedWalletId == null && wallets.isNotEmpty) {
          _selectedWalletId = wallets.first.id;
        }

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            color: sheetSurface,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                controller: widget.scrollController,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.paddingOf(context).bottom + 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: mutedText.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rút tiền về ví',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: primaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Nguồn: ${widget.goal.title} (Có: ${_formatCurrency(widget.goal.currentAmount)})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            tooltip: 'Đóng',
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              Navigator.of(context).pop();
                            },
                            icon: Icon(
                              Icons.close_rounded,
                              size: 21,
                              color: mutedText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Chuyển tiền vào ví',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FlowyDropdown<String>(
                      value: _selectedWalletId,
                      dropdownColor: cardSurface,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(16),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: mutedText,
                      ),
                      hint: Text(
                        'Chuyển vào ví',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      items: walletPickerItems(wallets),
                      itemsStream: widget.db
                          .watchAllWallets()
                          .map(walletPickerItems),
                      title: 'Chuyển vào ví',
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedWalletId = value;
                          amountValidation.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    AppValidationFeedback(
                      controller: amountValidation,
                      builder: (context, visual) => Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardSurface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _withdrawAccent.withValues(alpha: .04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: visual.borderColor(
                                _withdrawAccent.withValues(alpha: .35)),
                            width: visual.isInvalid ? 1.8 : 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'Số tiền rút',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: mutedText,
                                  ),
                                ),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _formatCurrency(calculatedAmount),
                                      style: currencyTextStyle(
                                        context,
                                        TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                          color: visual.isInvalid
                                              ? AppTokens.expense
                                              : _withdrawAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: CurrencyText(
                                    'Số dư tối đa: ${_formatCurrency(widget.goal.currentAmount)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: mutedText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _expression = widget.goal.currentAmount
                                          .toInt()
                                          .toString();
                                      amountValidation.clear();
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: _withdrawAccent
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: _withdrawAccent
                                            .withValues(alpha: 0.3),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                            Icons.all_inclusive_rounded,
                                            size: 13,
                                            color: _withdrawAccent),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Rút hết số dư',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: _withdrawAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppTokens.darkBorder
                              : AppTokens.lightBorder,
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 6,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openCalendar(isDark, ref.read(accentPresetProvider)),
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(16),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 16,
                                        color: textMuted,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _formatDateChipLabel(_selectedDate),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: primaryText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            color: isDark
                                ? AppTokens.darkBorder
                                : AppTokens.lightBorder,
                          ),
                          Expanded(
                            flex: 4,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openTimePicker(isDark, ref.read(accentPresetProvider)),
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(16),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 16,
                                        color: textMuted,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('HH:mm')
                                            .format(_selectedDate),
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: primaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTokens.darkCardSubtle
                            : AppTokens.lightCardSubtle,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? AppTokens.darkBorder
                              : AppTokens.lightBorder,
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 10, right: 8),
                            child: Icon(
                              Icons.edit_note_rounded,
                              size: 20,
                              color: textMuted,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _noteController,
                              minLines: 1,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: primaryText,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Lý do rút tiền...',
                                hintStyle: TextStyle(
                                  fontSize: 12.5,
                                  color: mutedText,
                                ),
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _buildVaultChromaticNumpad(
                      isDark: isDark,
                      actionColor: _withdrawAccent,
                      expression: _expression,
                      onKeyPress: _onNumpadPress,
                    ),
                    const SizedBox(height: 14),

                    Center(
                      child: AnimatedBuilder(
                        animation: _morphWidthAnimation,
                        builder: (context, child) {
                          final double fullWidth =
                              MediaQuery.of(context).size.width - 40;
                          final double currentWidth = _isSuccessMorphed
                              ? fullWidth -
                              (fullWidth - 50.0) *
                                  _morphWidthAnimation.value
                              : fullWidth;

                          return SizedBox(
                            width: currentWidth,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _withdrawAccent,
                                foregroundColor: Colors.white,
                                elevation: canSubmit ? 2 : 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    _isSuccessMorphed
                                        ? 16.0 +
                                        (9.0 * _morphWidthAnimation.value)
                                        : 16.0,
                                  ),
                                ),
                              ),
                              onPressed: !canSubmit
                                  ? null
                                  : () async {
                                if (_selectedWalletId == null) {
                                  AppFeedback.showInfo(
                                    context,
                                    'Chưa chọn ví nhận tiền.',
                                  );
                                  return;
                                }

                                if (calculatedAmount <= 0 ||
                                    calculatedAmount >
                                        widget.goal.currentAmount) {
                                  amountValidation.reject();
                                  return;
                                }

                                setState(() => _isSubmitting = true);

                                try {
                                  await widget.db.withdrawFromGoal(
                                    goalId: widget.goal.id,
                                    walletId: _selectedWalletId!,
                                    amount: calculatedAmount,
                                    date: _selectedDate,
                                    note: _noteController.text.trim().isEmpty
                                        ? null
                                        : _noteController.text.trim(),
                                  );

                                  setState(
                                          () => _isSuccessMorphed = true);
                                  await _morphButtonController.forward(
                                      from: 0.0);
                                  HapticFeedback.mediumImpact();
                                  await _checkIconController.forward(
                                      from: 0.0);
                                  await Future.delayed(
                                      const Duration(milliseconds: 250));

                                  if (context.mounted) {
                                    AppFeedback.showSuccess(
                                      context,
                                      'Đã rút ${_formatCurrency(calculatedAmount)} từ "${widget.goal.title}".',
                                    );
                                  }

                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                } catch (e) {
                                  debugPrint(
                                      'SavingsVault withdraw failed: $e');
                                  if (mounted) {
                                    setState(
                                            () => _isSubmitting = false);
                                    AppFeedback.showError(
                                      context,
                                      'Không thể rút tiền khỏi hũ. Vui lòng thử lại.',
                                    );
                                  }
                                }
                              },
                              child: _isSuccessMorphed
                                  ? ScaleTransition(
                                scale: _checkScaleAnimation,
                                child: const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 26),
                              )
                                  : (_isSubmitting
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation(
                                      Colors.white),
                                ),
                              )
                                  : const Text(
                                '✓  XÁC NHẬN RÚT TIỀN',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              )),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==============================================================================
// 🌟 MODAL CHỈNH GIỜ KẾT HỢP DÙNG CHUNG TRONG KÉT TIẾT KIỆM
// ==============================================================================
class _VaultTimePickerSheet extends ConsumerStatefulWidget {
  final TimeOfDay initialTime;
  final bool isDark;
  final AppAccentPreset accent;

  const _VaultTimePickerSheet({
    required this.initialTime,
    required this.isDark,
    required this.accent,
  });

  @override
  ConsumerState<_VaultTimePickerSheet> createState() =>
      _VaultTimePickerSheetState();
}

class _VaultTimePickerSheetState extends ConsumerState<_VaultTimePickerSheet> {
  late int _selectedHour;
  late int _selectedMinute;

  late final FixedExtentScrollController _hourWheelController;
  late final FixedExtentScrollController _minuteWheelController;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;

    _hourWheelController = FixedExtentScrollController(
      initialItem: _selectedHour,
    );
    _minuteWheelController = FixedExtentScrollController(
      initialItem: _selectedMinute,
    );
  }

  @override
  void dispose() {
    _hourWheelController.dispose();
    _minuteWheelController.dispose();
    super.dispose();
  }

  void _applyTime(int hour, int minute) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedHour = hour.clamp(0, 23);
      _selectedMinute = minute.clamp(0, 59);
    });

    if (_hourWheelController.hasClients) {
      _hourWheelController.animateToItem(
        _selectedHour,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
    if (_minuteWheelController.hasClients) {
      _minuteWheelController.animateToItem(
        _selectedMinute,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _adjustCurrentTime({int deltaHours = 0, int deltaMinutes = 0}) {
    final base = DateTime(2026, 1, 1, _selectedHour, _selectedMinute);
    final adjusted =
    base.add(Duration(hours: deltaHours, minutes: deltaMinutes));
    _applyTime(adjusted.hour, adjusted.minute);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryBrand = widget.accent.primary;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final systemFont = Theme.of(context).textTheme.bodyMedium?.fontFamily ??
        ref.watch(fontFamilyProvider);

    final containerBg = isDark
        ? const Color(0xFF151C28).withValues(alpha: 0.98)
        : Colors.white.withValues(alpha: 0.98);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
          decoration: BoxDecoration(
            color: containerBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
              width: 1,
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thời gian giao dịch',
                          style: TextStyle(
                            fontFamily: systemFont,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppTokens.darkText
                                : AppTokens.lightText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cuộn vòng xoay để chọn giờ và phút',
                          style: TextStyle(
                            fontFamily: systemFont,
                            fontSize: 11,
                            color: isDark
                                ? AppTokens.darkMuted
                                : AppTokens.lightMuted,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: isDark
                              ? AppTokens.darkMuted
                              : AppTokens.lightMuted,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildVaultPresetChip('Vừa xong', () {
                        final now = DateTime.now();
                        _applyTime(now.hour, now.minute);
                      }, isDark, primaryBrand, systemFont),
                      const SizedBox(width: 8),
                      _buildVaultPresetChip('-15 phút', () {
                        _adjustCurrentTime(deltaMinutes: -15);
                      }, isDark, primaryBrand, systemFont),
                      const SizedBox(width: 8),
                      _buildVaultPresetChip('-1 giờ', () {
                        _adjustCurrentTime(deltaHours: -1);
                      }, isDark, primaryBrand, systemFont),
                      const SizedBox(width: 8),
                      _buildVaultPresetChip('12:00', () {
                        _applyTime(12, 0);
                      }, isDark, primaryBrand, systemFont),
                      const SizedBox(width: 8),
                      _buildVaultPresetChip('19:00', () {
                        _applyTime(19, 0);
                      }, isDark, primaryBrand, systemFont),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Listener(
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: primaryBrand.withValues(
                                alpha: isDark ? 0.16 : 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: primaryBrand.withValues(
                                  alpha: isDark ? 0.40 : 0.25),
                              width: 1.4,
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  (isDark
                                      ? const Color(0xFF151C28)
                                      : Colors.white)
                                      .withValues(alpha: 0.95),
                                  (isDark
                                      ? const Color(0xFF151C28)
                                      : Colors.white)
                                      .withValues(alpha: 0.0),
                                  (isDark
                                      ? const Color(0xFF151C28)
                                      : Colors.white)
                                      .withValues(alpha: 0.0),
                                  (isDark
                                      ? const Color(0xFF151C28)
                                      : Colors.white)
                                      .withValues(alpha: 0.95),
                                ],
                                stops: const [0.0, 0.28, 0.72, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: _hourWheelController,
                                itemExtent: 50,
                                diameterRatio: 1.5,
                                perspective: 0.003,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedHour = index);
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 24,
                                  builder: (context, index) {
                                    final isSelected = index == _selectedHour;
                                    final distance =
                                    (index - _selectedHour).abs();
                                    final opacity = isSelected
                                        ? 1.0
                                        : (distance == 1 ? 0.45 : 0.20);

                                    return Center(
                                      child: AnimatedDefaultTextStyle(
                                        duration:
                                        const Duration(milliseconds: 140),
                                        style: TextStyle(
                                          fontFamily: systemFont,
                                          fontSize: isSelected ? 32 : 18,
                                          fontWeight: isSelected
                                              ? FontWeight.w900
                                              : FontWeight.w600,
                                          color: isSelected
                                              ? primaryBrand
                                              : (isDark
                                              ? AppTokens.darkText
                                              : AppTokens.lightText)
                                              .withValues(alpha: opacity),
                                          letterSpacing: isSelected ? -0.5 : 0,
                                        ),
                                        child: Text(
                                            index.toString().padLeft(2, '0')),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                ':',
                                style: TextStyle(
                                  fontFamily: systemFont,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? AppTokens.darkText
                                      : AppTokens.lightText,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: _minuteWheelController,
                                itemExtent: 50,
                                diameterRatio: 1.5,
                                perspective: 0.003,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedMinute = index);
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 60,
                                  builder: (context, index) {
                                    final isSelected = index == _selectedMinute;
                                    final distance =
                                    (index - _selectedMinute).abs();
                                    final opacity = isSelected
                                        ? 1.0
                                        : (distance == 1 ? 0.45 : 0.20);

                                    return Center(
                                      child: AnimatedDefaultTextStyle(
                                        duration:
                                        const Duration(milliseconds: 140),
                                        style: TextStyle(
                                          fontFamily: systemFont,
                                          fontSize: isSelected ? 32 : 18,
                                          fontWeight: isSelected
                                              ? FontWeight.w900
                                              : FontWeight.w600,
                                          color: isSelected
                                              ? primaryBrand
                                              : (isDark
                                              ? AppTokens.darkText
                                              : AppTokens.lightText)
                                              .withValues(alpha: opacity),
                                          letterSpacing: isSelected ? -0.5 : 0,
                                        ),
                                        child: Text(
                                            index.toString().padLeft(2, '0')),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBrand,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      FocusScope.of(context).unfocus();
                      Navigator.of(context).pop(
                        TimeOfDay(
                            hour: _selectedHour, minute: _selectedMinute),
                      );
                    },
                    child: Text(
                      '✓  Xác nhận thời gian',
                      style: TextStyle(
                        fontFamily: systemFont,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildVaultPresetChip(
    String label,
    VoidCallback onTap,
    bool isDark,
    Color primaryColor,
    String? fontFamily,
    ) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B3329) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF223F33) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: isDark ? AppTokens.darkText : AppTokens.lightText,
        ),
      ),
    ),
  );
}

// ==============================================================================
// 🌟 MODAL LỊCH MINI DÙNG CHUNG TRONG KÉT TIẾT KIỆM
// ==============================================================================
class _VaultMiniCalendarSheet extends StatefulWidget {
  final DateTime initialDate;
  final bool isDark;
  final AppAccentPreset accent;
  final ValueChanged<DateTime> onDateSelected;

  const _VaultMiniCalendarSheet({
    required this.initialDate,
    required this.isDark,
    required this.accent,
    required this.onDateSelected,
  });

  @override
  State<_VaultMiniCalendarSheet> createState() =>
      _VaultMiniCalendarSheetState();
}

class _VaultMiniCalendarSheetState extends State<_VaultMiniCalendarSheet> {
  late DateTime _displayedMonth;
  late DateTime _currentPickedDate;

  @override
  void initState() {
    super.initState();
    _currentPickedDate = widget.initialDate;
    _displayedMonth =
        DateTime(widget.initialDate.year, widget.initialDate.month, 1);
  }

  void _shiftMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + delta, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    final leadingEmptyCount = (firstWeekday - 1) % 7;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF151C28) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: widget.isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 28),
                    onPressed: () => _shiftMonth(-1),
                  ),
                  Text(
                    'Tháng ${DateFormat('MM / yyyy').format(_displayedMonth)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: widget.isDark
                          ? AppTokens.darkText
                          : AppTokens.lightText,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 28),
                    onPressed: () => _shiftMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((w) {
                  final isWeekend = w == 'T7' || w == 'CN';
                  return Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isWeekend
                              ? (widget.isDark
                              ? Colors.amber.shade300
                              : Colors.amber.shade800)
                              : (widget.isDark
                              ? AppTokens.darkMuted
                              : AppTokens.lightMuted),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.0,
                ),
                itemCount: leadingEmptyCount + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < leadingEmptyCount) {
                    return const SizedBox();
                  }

                  final dayNumber = index - leadingEmptyCount + 1;
                  final cellDate = DateTime(
                      _displayedMonth.year, _displayedMonth.month, dayNumber);

                  final isFutureDate = cellDate.isAfter(today);
                  final isSelected = cellDate.year ==
                      _currentPickedDate.year &&
                      cellDate.month == _currentPickedDate.month &&
                      cellDate.day == _currentPickedDate.day;

                  final isToday = cellDate.year == today.year &&
                      cellDate.month == today.month &&
                      cellDate.day == today.day;

                  return InkWell(
                    onTap: isFutureDate
                        ? null
                        : () {
                      HapticFeedback.selectionClick();
                      setState(() => _currentPickedDate = cellDate);
                      widget.onDateSelected(cellDate);
                      Navigator.of(context).pop();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? widget.accent.primary
                            : (isToday
                            ? widget.accent.primary.withValues(alpha: 0.15)
                            : Colors.transparent),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isToday && !isSelected
                              ? widget.accent.primary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isFutureDate
                                ? (widget.isDark
                                ? Colors.white24
                                : Colors.black26)
                                : (isSelected
                                ? Colors.white
                                : (widget.isDark
                                ? AppTokens.darkText
                                : AppTokens.lightText)),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    widget.onDateSelected(today);
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.today_rounded, size: 16),
                  label: const Text(
                    'Hôm nay',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.accent.primary,
                    side: BorderSide(
                        color: widget.accent.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VaultInputFocus extends StatefulWidget {
  const _VaultInputFocus({required this.color, required this.child});
  final Color color;
  final Widget child;
  @override
  State<_VaultInputFocus> createState() => _VaultInputFocusState();
}

class _VaultInputFocusState extends State<_VaultInputFocus> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onFocusChange: (value) => setState(() => _focused = value),
    child: DecoratedBox(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _focused
              ? [
            BoxShadow(
                color: widget.color.withValues(alpha: .14),
                blurRadius: 4)
          ]
              : null),
      child: widget.child,
    ),
  );
}