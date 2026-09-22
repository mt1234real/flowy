// ==============================================================================
// File: lib/screens/savings_vault_screen.dart
// Architecture: Digital Swiss Vault Savings Screen & Root-Safe Auto-Lock
// Stack: flutter, flutter_riverpod, drift, intl, local_auth, dart:ui
// Features: Frosted Glass Assets, Modern Goal Iconography, Multi-Wallet ACID,
//           Auto-Lock Privacy Shield with Root-Navigator Unlock Flow,
//           Savings Pace Estimator, Goal CRUD, Dynamic 4/6 PIN Compatibility
// ==============================================================================

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
import '../widgets/precision_numpad.dart';
import '../widgets/preserved_balance_tumbler.dart';
import 'vault_auth_screen.dart';
import 'vault_pin_change_screen.dart';

class SavingsVaultScreen extends ConsumerStatefulWidget {
  const SavingsVaultScreen({super.key});

  @override
  ConsumerState<SavingsVaultScreen> createState() => _SavingsVaultScreenState();
}

class _SavingsVaultScreenState extends ConsumerState<SavingsVaultScreen>
    with WidgetsBindingObserver {
  bool _isBalanceHidden = false;
  bool _isPrivacyShieldActive = false;
  bool _isUnlockFlowActive = false;

  static const Duration _privacyShieldFadeDuration =
  Duration(milliseconds: 150);

  static const Map<String, IconData> _vaultGoalIcons = {
    'general': Icons.savings_outlined,
    'laptop': Icons.laptop_mac_rounded,
    'travel': Icons.flight_takeoff_rounded,
    'motorbike': Icons.two_wheeler_rounded,
    'emergency': Icons.health_and_safety_outlined,
    'home': Icons.home_work_outlined,
    'education': Icons.school_outlined,
    'gift': Icons.redeem_outlined,
    'car': Icons.directions_car_rounded,
    'music': Icons.music_note_rounded,
    'diamond': Icons.diamond_outlined,
  };

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

  // ============================================================================
  // AUTO-LOCK + CLEAN ROOT UNLOCK FLOW
  // ============================================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (_isUnlockFlowActive) {
      // local_auth can itself drive the app through inactive/paused while the
      // system biometric surface is visible. Never re-lock underneath it.
      return;
    }

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

    // Immediately release hit-testing from the blocker, then let it fade out.
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

  String _normalizeGoalIconKey(String raw) {
    if (_vaultGoalIcons.containsKey(raw)) return raw;

    switch (raw) {
      case '💻':
        return 'laptop';
      case '✈️':
        return 'travel';
      case '🚗':
        return 'car';
      case '🏠':
        return 'home';
      case '🎓':
        return 'education';
      case '🎁':
        return 'gift';
      case '🎸':
        return 'music';
      case '💍':
        return 'diamond';
      case '🛡️':
      case '⚡':
        return 'emergency';
      case '🐖':
      default:
        return 'general';
    }
  }

  IconData _resolveGoalIcon(String raw) {
    final key = _normalizeGoalIconKey(raw);
    return _vaultGoalIcons[key] ?? Icons.savings_outlined;
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount);
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
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final goalsStream = ref.watch(savingsGoalsStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    final screenBackground =
    isDark ? const Color(0xFF0B0F17) : AppTokens.lightBg;
    final primaryText =
    isDark ? const Color(0xFFF8FAFC) : AppTokens.lightText;
    final mutedText =
    isDark ? const Color(0xFF94A3B8) : AppTokens.lightMuted;

    return AppFeedbackDismissRegion(
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
                  IconButton(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: mutedText,
                      size: 21,
                    ),
                    tooltip: 'Tạo mã PIN két',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const VaultPinChangeScreen(),
                        ),
                      );
                    },
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
                                style: theme.textTheme.labelMedium?.copyWith(
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
                                return _buildLiquidGoalCard(
                                  goals[index],
                                  db,
                                  isDark: isDark,
                                  accent: accent,
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

            // The blocker stays mounted only while it is visible or fading.
            if (_isPrivacyShieldActive || _isUnlockFlowActive)
              Positioned.fill(
                child: IgnorePointer(
                  // On unlock tap hit-testing is released immediately (0 ms).
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

  // ============================================================================
  // A. THẺ HERO TỔNG TÀI SẢN ĐANG ĐÓNG BĂNG (LUXURY VAULT THEME)
  // ============================================================================
  Widget _buildHeroVaultCard(
      double totalBalance,
      int totalGoals, {
        required bool isDark,
        required AppAccentPreset accent,
      }) {
    final theme = Theme.of(context);
    final surface = isDark
        ? const Color(0xEB1E2430)
        : Colors.white.withValues(alpha: 0.90);
    final border =
    isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0);
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Riêng tư', style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600, color: accent.primary,
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
                              onPointerDown: (_) => HapticFeedback.selectionClick(),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => setState(() => _isBalanceHidden = !_isBalanceHidden),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 180),
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
                          fontFamily: 'monospace',
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
                                color:
                                accent.primary.withValues(alpha: 0.35),
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

  // ============================================================================
  // B. THẺ BÌNH CHẤT LỎNG CHO MỖI HŨ MỤC TIÊU (LIQUID FILL CARD)
  // ============================================================================
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

    final surface = isDark
        ? const Color(0xE61E2430)
        : Colors.white.withValues(alpha: 0.92);
    final border =
    isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0);
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
        paceText =
        '~${_formatCurrency(dailyNeeded)}/ngày • còn $diffDays ngày';
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
                            Text('Mục tiêu: ', style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5, color: mutedText,
                            )),
                            Expanded(
                              child: PreservedBalanceTumbler(
                                isVisible: !_isBalanceHidden,
                                realValue: _formatCurrency(goal.targetAmount),
                                maskedValue: '● ● ● ● ● ●',
                                height: 18,
                                style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace', letterSpacing: -0.5,
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
                    color: isDark
                        ? const Color(0xFF1E2430)
                        : Colors.white,
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
                        _showDeleteGoalDialog(context, goal, db);
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
                  Text('Hiện có: ', style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: primaryText,
                  )),
                  Expanded(
                    child: PreservedBalanceTumbler(
                      isVisible: !_isBalanceHidden,
                      realValue: _formatCurrency(goal.currentAmount),
                      maskedValue: '● ● ● ● ● ●',
                      height: 18,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        fontFamily: 'monospace', letterSpacing: -0.5, color: primaryText,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    child: PreservedBalanceTumbler(
                      isVisible: !_isBalanceHidden,
                      realValue: '$progressPercent% mục tiêu',
                      maskedValue: '••% mục tiêu',
                      height: 18,
                      alignment: Alignment.centerRight,
                      style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800,
                        fontFamily: 'monospace', color: accent.primary,
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
                          fontFamily: 'monospace',
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
                        onPressed: () =>
                            _showDepositSheet(context, goal, db),
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
          color: isDark
              ? const Color(0xFF2E384D)
              : const Color(0xFFE2E8F0),
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
    final amountValidation = AppValidationFeedbackController();

    AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.scrollable,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx, scrollController) {
        String enteredAmountStr = '';
        String? selectedWalletId;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(ctx);
            final isDark = theme.brightness == Brightness.dark;
            final accent = ref.read(accentPresetProvider);

            final sheetSurface = isDark
                ? const Color(0xFF111827)
                : const Color(0xFFF8FAFC);
            final cardSurface = isDark
                ? const Color(0xFF1E2430)
                : Colors.white;
            final borderColor = isDark
                ? const Color(0xFF2E384D)
                : const Color(0xFFE2E8F0);
            final primaryText =
            isDark ? Colors.white : const Color(0xFF0F172A);
            final mutedText = isDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B);

            return StreamBuilder<List<Wallet>>(
              stream: db.watchAllWallets(),
              builder: (context, snapshot) {
                final wallets = snapshot.data ?? const <Wallet>[];

                if (selectedWalletId == null && wallets.isNotEmpty) {
                  selectedWalletId = wallets.first.id;
                }

                final selectedWallet = wallets.cast<Wallet?>().firstWhere(
                      (wallet) => wallet?.id == selectedWalletId,
                  orElse: () => null,
                );

                final amount = double.tryParse(enteredAmountStr) ?? 0.0;

                void setAmount(double value) {
                  setSheetState(() {
                    enteredAmountStr = value <= 0
                        ? ''
                        : value.floorToDouble().toStringAsFixed(0);
                    amountValidation.clear();
                  });
                }

                void addQuickAmount(double increment) {
                  setAmount(amount + increment);
                }

                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
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
                          MediaQuery.paddingOf(ctx).bottom + 18,
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
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Nạp tiền vào quỹ',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Dành cho mục tiêu: ${goal.title}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                        theme.textTheme.bodySmall?.copyWith(
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
                                      Navigator.of(sheetCtx).pop();
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

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                12,
                                10,
                              ),
                              decoration: BoxDecoration(
                                color: cardSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: borderColor,
                                  width: 0.8,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nguồn tiền trích',
                                    style:
                                    theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                      color: mutedText,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedWalletId,
                                      dropdownColor: isDark
                                          ? const Color(0xFF1E2430)
                                          : Colors.white,
                                      isExpanded: true,
                                      borderRadius: BorderRadius.circular(16),
                                      icon: Icon(
                                        Icons.chevron_right_rounded,
                                        color: mutedText,
                                      ),
                                      hint: Text(
                                        'Chọn nguồn tiền',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: mutedText,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      items: wallets.map((wallet) {
                                        return DropdownMenuItem<String>(
                                          value: wallet.id,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  color: accent.primary
                                                      .withValues(alpha: 0.10),
                                                  borderRadius:
                                                  BorderRadius.circular(9),
                                                ),
                                                child: Icon(
                                                  Icons
                                                      .account_balance_wallet_outlined,
                                                  size: 16,
                                                  color: accent.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 9),
                                              Expanded(
                                                child: Text(
                                                  wallet.name,
                                                  maxLines: 1,
                                                  overflow:
                                                  TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme.bodyMedium
                                                      ?.copyWith(
                                                    fontSize: 12.5,
                                                    fontWeight:
                                                    FontWeight.w700,
                                                    color: primaryText,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                'Khả dụng: ${_formatCurrency(wallet.balance)}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  fontSize: 10.5,
                                                  fontWeight:
                                                  FontWeight.w700,
                                                  color: accent.primary,
                                                ),
                                              ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value == null) return;
                                        setSheetState(() {
                                          selectedWalletId = value;
                                          enteredAmountStr = '';
                                          amountValidation.clear();
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            AppValidationFeedback(
                              controller: amountValidation,
                              builder: (context, visual) => Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: cardSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: visual.borderColor(borderColor),
                                    width: visual.isInvalid ? 1.8 : 0.8,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Số tiền muốn tích lũy',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.7,
                                          color: mutedText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      flex: 2,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          _formatCurrency(amount),
                                          style: theme
                                              .textTheme.headlineSmall
                                              ?.copyWith(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            color: visual.isInvalid
                                                ? AppTokens.expense
                                                : primaryText,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                _buildVaultQuickFillChip(
                                  context: ctx,
                                  label: '+50k',
                                  onTap: () => addQuickAmount(50000),
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 8),
                                _buildVaultQuickFillChip(
                                  context: ctx,
                                  label: '+100k',
                                  onTap: () => addQuickAmount(100000),
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 8),
                                _buildVaultQuickFillChip(
                                  context: ctx,
                                  label: '+200k',
                                  onTap: () => addQuickAmount(200000),
                                  isDark: isDark,
                                ),
                                const SizedBox(width: 8),
                                _buildVaultQuickFillChip(
                                  context: ctx,
                                  label: 'Tất cả ví',
                                  onTap: selectedWallet == null
                                      ? null
                                      : () => setAmount(
                                    selectedWallet.balance
                                        .clamp(0.0, double.infinity)
                                        .toDouble(),
                                  ),
                                  isDark: isDark,
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            _buildInlineNumpad(
                              onPress: (digit) {
                                setSheetState(() {
                                  if (enteredAmountStr.length >= 11) return;
                                  enteredAmountStr = enteredAmountStr.isEmpty ||
                                      enteredAmountStr == '0'
                                      ? digit
                                      : '$enteredAmountStr$digit';
                                  amountValidation.clear();
                                });
                              },
                              onBackspace: () {
                                setSheetState(() {
                                  if (enteredAmountStr.isEmpty) return;
                                  enteredAmountStr = enteredAmountStr.substring(
                                    0,
                                    enteredAmountStr.length - 1,
                                  );
                                  amountValidation.clear();
                                });
                              },
                              onClear: () {
                                setSheetState(() {
                                  enteredAmountStr = '';
                                  amountValidation.clear();
                                });
                              },
                            ),

                            const SizedBox(height: 14),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent.primary,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: accent.primary,
                                  disabledForegroundColor:
                                  Colors.white,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                  if (selectedWallet == null) {
                                    AppFeedback.showInfo(
                                      context,
                                      'Chưa có nguồn tiền khả dụng.',
                                    );
                                    return;
                                  }

                                  if (amount <= 0 ||
                                      amount >
                                          selectedWallet.balance) {
                                    amountValidation.reject();
                                    return;
                                  }

                                  setSheetState(
                                        () => isSubmitting = true,
                                  );

                                  try {
                                    await db.depositToGoal(
                                      goalId: goal.id,
                                      walletId: selectedWallet.id,
                                      amount: amount,
                                    );

                                    if (context.mounted) {
                                      AppFeedback.showSuccess(
                                        context,
                                        'Đã nạp ${_formatCurrency(amount)} vào "${goal.title}".',
                                      );
                                    }

                                    if (sheetCtx.mounted) {
                                      Navigator.of(sheetCtx).pop();
                                    }
                                  } catch (e) {
                                    debugPrint(
                                      'SavingsVault deposit failed: $e',
                                    );

                                    if (sheetCtx.mounted) {
                                      setSheetState(
                                            () => isSubmitting = false,
                                      );
                                    }

                                    if (context.mounted) {
                                      AppFeedback.showError(
                                        context,
                                        'Không thể nạp tiền vào hũ. Vui lòng thử lại.',
                                      );
                                    }
                                  }
                                },
                                child: isSubmitting
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Text(
                                  'Xác nhận nạp tiền',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
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
              },
            );
          },
        );
      },
    ).whenComplete(amountValidation.dispose);
  }

  Widget _buildVaultQuickFillChip({
    required BuildContext context,
    required String label,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: SizedBox(
        height: 32,
        child: Material(
          color: isDark
              ? const Color(0xFF1E2430)
              : const Color(0xFFEFF3F8),
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
              HapticFeedback.selectionClick();
              onTap();
            },
            borderRadius: BorderRadius.circular(11),
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 10.8,
                  fontWeight: FontWeight.w700,
                  color: onTap == null
                      ? (isDark ? Colors.white24 : Colors.black26)
                      : (isDark
                      ? Colors.white
                      : const Color(0xFF0F172A)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // E. BOTTOM SHEET RÚT TIỀN TỪ HŨ VỀ VÍ (WITHDRAW - ACID TRANSACTION)
  // ============================================================================
  void _showWithdrawSheet(BuildContext context, SavingsGoal goal, AppDatabase db) {
    final amountValidation = AppValidationFeedbackController();
    AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx, __) {
        String enteredAmountStr = '';
        String? selectedWalletId;
        String? errorMessage;
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return StreamBuilder<List<Wallet>>(
              stream: db.watchAllWallets(),
              builder: (context, snapshot) {
                final wallets = snapshot.data ?? [];
                if (selectedWalletId == null && wallets.isNotEmpty) {
                  selectedWalletId = wallets.first.id;
                }

                final double amount = double.tryParse(enteredAmountStr) ?? 0.0;

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                    left: 20,
                    right: 20,
                    top: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF38BDF8), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rút tiền về ví',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                                Text(
                                  'Nguồn: ${goal.icon} ${goal.title} (Có: ${_formatCurrency(goal.currentAmount)})',
                                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // CHỌN VÍ NHẬN TIỀN
                      const Text(
                        'Chuyển tiền vào ví',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white54),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedWalletId,
                            dropdownColor: const Color(0xFF1F2937),
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                            items: wallets.map((w) {
                              return DropdownMenuItem<String>(
                                value: w.id,
                                child: Text(w.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setSheetState(() {
                                  selectedWalletId = val;
                                  errorMessage = null;
                                  amountValidation.clear();
                                });
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Ô HIỂN THỊ SỐ TIỀN RÚT
                      AppValidationFeedback(
                        controller: amountValidation,
                        builder: (context, visual) => Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: visual.borderColor(
                                const Color(0xFF38BDF8).withValues(alpha: 0.3),
                              ),
                              width: visual.isInvalid ? 1.8 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                enteredAmountStr.isEmpty ? '0 ₫' : _formatCurrency(amount),
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: visual.isInvalid
                                      ? AppTokens.expense
                                      : const Color(0xFF38BDF8),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Số dư tối đa trong hũ: ${_formatCurrency(goal.currentAmount)}',
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorMessage!,
                          style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // NÚT CHỌN RÚT TOÀN BỘ (RÚT HẾT)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setSheetState(() {
                                enteredAmountStr = goal.currentAmount.toInt().toString();
                                errorMessage = null;
                                amountValidation.clear();
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.all_inclusive_rounded, size: 14, color: Color(0xFF38BDF8)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Rút hết số dư',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // BÀN PHÍM NUMPAD TÍCH HỢP
                      _buildInlineNumpad(
                        onPress: (digit) {
                          setSheetState(() {
                            if (enteredAmountStr.length < 11) {
                              enteredAmountStr += digit;
                              errorMessage = null;
                              amountValidation.clear();
                            }
                          });
                        },
                        onBackspace: () {
                          setSheetState(() {
                            if (enteredAmountStr.isNotEmpty) {
                              enteredAmountStr = enteredAmountStr.substring(0, enteredAmountStr.length - 1);
                              errorMessage = null;
                              amountValidation.clear();
                            }
                          });
                        },
                        onClear: () {
                          setSheetState(() {
                            enteredAmountStr = '';
                            errorMessage = null;
                            amountValidation.clear();
                          });
                        },
                      ),

                      const SizedBox(height: 18),

                      // NÚT XÁC NHẬN RÚT TIỀN
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: (isSubmitting || amount <= 0 || selectedWalletId == null)
                              ? null
                              : () async {
                            if (amount > goal.currentAmount) {
                              amountValidation.reject();
                              setSheetState(() {
                                errorMessage = 'Số tiền rút vượt quá số dư trong hũ (${_formatCurrency(goal.currentAmount)})!';
                              });
                              return;
                            }

                            setSheetState(() => isSubmitting = true);
                            try {
                              await db.withdrawFromGoal(
                                goalId: goal.id,
                                walletId: selectedWalletId!,
                                amount: amount,
                              );
                              if (context.mounted) {
                                AppFeedback.showSuccess(
                                  context,
                                  'Đã rút thành công ${_formatCurrency(amount)} về ví',
                                );
                              }
                              if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                            } catch (e) {
                              setSheetState(() {
                                isSubmitting = false;
                                errorMessage = 'Lỗi rút tiền: $e';
                              });
                            }
                          },
                          child: isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('Xác nhận rút tiền', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(amountValidation.dispose);
  }

  // ============================================================================
  // F. MODAL TẠO / SỬA HŨ TIẾT KIỆM (CREATE / EDIT GOAL)
  // ============================================================================
  void _showCreateOrEditGoalModal(BuildContext context, {SavingsGoal? existingGoal}) {
    final titleController = TextEditingController(text: existingGoal?.title ?? '');
    final targetController = TextEditingController(
      text: existingGoal != null ? existingGoal.targetAmount.toInt().toString() : '',
    );
    String selectedIcon = _normalizeGoalIconKey(existingGoal?.icon ?? 'general');
    String selectedColor = existingGoal?.colorHex ?? '#10B981';
    DateTime? selectedTargetDate = existingGoal?.targetDate;
    final titleValidation = AppValidationFeedbackController();
    final targetValidation = AppValidationFeedbackController();
    final accent = ref.read(accentPresetProvider);

    final icons = _vaultGoalIcons.keys.toList(growable: false);
    final colors = ['#10B981', '#0EA5E9', '#F59E0B', '#F43F5E', '#8B5CF6', '#14B8A6'];

    AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx, __) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      existingGoal == null ? 'Tạo Mục Tiêu Tích Lũy' : 'Chỉnh Sửa Mục Tiêu',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 18),

                    // TÊN MỤC TIÊU
                    const Text('TÊN MỤC TIÊU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white54)),
                    const SizedBox(height: 6),
                    AppValidationFeedback(
                      controller: titleValidation,
                      builder: (context, visual) => TextField(
                        controller: titleController,
                        onChanged: (_) => titleValidation.clear(),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Ví dụ: Đàn Guitar, Mua MacBook, Quỹ khẩn cấp',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFF1F2937),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: visual.borderColor(Colors.white12),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: visual.borderColor(Colors.white12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: visual.isInvalid
                                  ? AppTokens.expense
                                  : const Color(0xFF10B981),
                              width: visual.isInvalid ? 1.8 : 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // CHỌN BIỂU TƯỢNG EMOJI
                    const Text('CHỌN BIỂU TƯỢNG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white54)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: icons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                                color: isSelected ? accent.primary.withValues(alpha: 0.16) : const Color(0xFF1F2937),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isSelected ? accent.primary : Colors.transparent),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                _resolveGoalIcon(icon),
                                size: 20,
                                color: isSelected
                                    ? const Color(0xFF34D399)
                                    : Colors.white70,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    // CHỌN MÀU SẮC
                    const Text('CHỌN MÀU CHỦ ĐẠO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white54)),
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
                              border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.black) : null,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 14),

                    // SỐ TIỀN MỤC TIÊU
                    const Text('SỐ TIỀN MỤC TIÊU (₫)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white54)),
                    const SizedBox(height: 6),
                    AppValidationFeedback(
                      controller: targetValidation,
                      builder: (context, visual) => TextField(
                        controller: targetController,
                        onChanged: (_) => targetValidation.clear(),
                        keyboardType: TextInputType.number,
                        style: TextStyle(
                          color: visual.isInvalid ? AppTokens.expense : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ví dụ: 25000000',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFF1F2937),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: visual.borderColor(Colors.white12),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: visual.borderColor(Colors.white12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: visual.isInvalid
                                  ? AppTokens.expense
                                  : const Color(0xFF10B981),
                              width: visual.isInvalid ? 1.8 : 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // CHỌN HẠN CHÓT (TARGET DATE)
                    const Text('HẠN CHÓT ĐẠT MỤC TIÊU (TÙY CHỌN)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white54)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2937),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              selectedTargetDate != null
                                  ? DateFormat('dd/MM/yyyy').format(selectedTargetDate!)
                                  : 'Chưa đặt hạn chót',
                              style: TextStyle(
                                color: selectedTargetDate != null ? Colors.white : Colors.white38,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: const Color(0xFF1F2937)),
                          icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF10B981)),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedTargetDate ?? DateTime.now().add(const Duration(days: 90)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                              builder: (ctx, child) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Color(0xFF10B981),
                                      surface: Color(0xFF1F2937),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setModalState(() => selectedTargetDate = picked);
                            }
                          },
                        ),
                        if (selectedTargetDate != null)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                            onPressed: () => setModalState(() => selectedTargetDate = null),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // NÚT LƯU
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent.primary,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () async {
                          final title = titleController.text.trim();
                          final targetAmount = double.tryParse(targetController.text.trim()) ?? 0.0;

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
                          if (modalCtx.mounted) Navigator.of(modalCtx).pop();
                        },
                        child: Text(
                          existingGoal == null ? 'Tạo Hũ Tiết Kiệm' : 'Lưu Thay Đổi',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
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

  // ============================================================================
  // G. DIALOG XÓA HŨ AN TOÀN (CÓ HOÀN TRẢ TIỀN NẾU CÒN SỐ DƯ)
  // ============================================================================
  void _showDeleteGoalDialog(BuildContext context, SavingsGoal goal, AppDatabase db) {
    if (goal.currentAmount <= 0) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: const Text('Xác nhận xóa hũ', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Text('Bạn có chắc muốn xóa hũ "${goal.title}" không?', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                await db.deleteSavingsGoal(goal.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Xóa', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    // Nếu hũ còn tiền, bắt buộc chọn ví để hoàn trả số tiền
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        String? refundWalletId;
        return StreamBuilder<List<Wallet>>(
          stream: db.watchAllWallets(),
          builder: (context, snapshot) {
            final wallets = snapshot.data ?? [];
            if (refundWalletId == null && wallets.isNotEmpty) {
              refundWalletId = wallets.first.id;
            }

            return StatefulBuilder(
              builder: (ctx, setDialogState) {
                return AlertDialog(
                  backgroundColor: const Color(0xFF1F2937),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text(
                    'Hoàn trả số dư trước khi xóa',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hũ này đang có số dư ${_formatCurrency(goal.currentAmount)}. Vui lòng chọn ví để hoàn trả toàn bộ số tiền này trước khi xóa hũ:',
                        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: refundWalletId,
                            dropdownColor: const Color(0xFF111827),
                            isExpanded: true,
                            items: wallets.map((w) {
                              return DropdownMenuItem<String>(
                                value: w.id,
                                child: Text(w.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => refundWalletId = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: refundWalletId == null
                          ? null
                          : () async {
                        await db.deleteSavingsGoal(goal.id, refundWalletId: refundWalletId);
                        if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                        if (context.mounted) {
                          AppFeedback.showSuccess(
                            context,
                            'Đã xóa hũ và hoàn ${_formatCurrency(goal.currentAmount)} về ví',
                          );
                        }
                      },
                      child: const Text('Hoàn tiền & Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // H. NUMPAD TIỆN LỢI CHO BOTTOM SHEET
  // ============================================================================
  Widget _buildInlineNumpad({
    required ValueChanged<String> onPress,
    required VoidCallback onBackspace,
    required VoidCallback onClear,
  }) {
    return PrecisionNumpad(
      onDigit: onPress,
      onBackspace: onBackspace,
      onBackspaceLongPress: onClear,
      leadingAction: PrecisionNumpadAction(
        label: 'C',
        onPressed: onClear,
        color: AppTokens.expense,
        semanticLabel: 'Xóa toàn bộ',
      ),
      digitColor: Theme.of(context).brightness == Brightness.light
          ? const Color(0xFF0F172A) : Colors.white,
      digitFontWeight: FontWeight.w700,
      actionColor: Theme.of(context).brightness == Brightness.light
          ? const Color(0xFF0F172A) : Colors.white70,
      horizontalPadding: 18,
      rowSpacing: 6,
    );
  }

}
