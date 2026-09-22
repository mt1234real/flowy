// ==============================================================================
// File: lib/widgets/audit_balance_modal.dart
// Architecture: Executive Balance Audit & Reconciliation Sheet (ACID Audit Trail)
// Stack: flutter, flutter_riverpod, drift, intl
// Features:
// 1. Interactive Balance Scales Header with current app balance ($B_{app}$)
// 2. Integrated 4x4 Numpad for entering real-world counted cash/balance ($B_{real}$)
// 3. Real-time Arithmetic Delta Calculation ($\Delta B = B_{real} - B_{app}$):
//    - Surplus: Emerald Green (+X ₫)
//    - Deficit: Crimson Red (-X ₫)
//    - Perfect Match: Slate Blue (0 ₫)
// 4. Quick preset chips for audit discrepancies & custom explanation textfield
// 5. ACID Transaction Execution via db.adjustWalletBalance(...)
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

class AuditBalanceModal extends ConsumerStatefulWidget {
  final Wallet wallet;

  const AuditBalanceModal({
    super.key,
    required this.wallet,
  });

  static Future<void> show(
      BuildContext context, {
        required Wallet wallet,
      }) {
    HapticFeedback.selectionClick();
    return AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => AuditBalanceModal(wallet: wallet),
    );
  }

  @override
  ConsumerState<AuditBalanceModal> createState() => _AuditBalanceModalState();
}

class _AuditBalanceModalState extends ConsumerState<AuditBalanceModal> {
  late String _inputExpression;
  bool _isNegative = false;
  String _selectedReason = 'Quên ghi chép';
  final TextEditingController _customReasonController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _reasonPresets = [
    'Quên ghi chép',
    'Sai số kiểm kê',
    'Lãi tiền gửi lẻ',
    'Khác',
  ];

  @override
  void initState() {
    super.initState();
    final currentBal = widget.wallet.balance;
    _isNegative = currentBal < 0;
    _inputExpression = currentBal.abs().toStringAsFixed(0);
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  double get _realBalance {
    final parsed = double.tryParse(_inputExpression) ?? 0.0;
    return _isNegative ? -parsed : parsed;
  }

  double get _delta {
    return _realBalance - widget.wallet.balance;
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  void _onNumpadPress(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == 'C') {
        _inputExpression = '0';
      } else if (key == '⌫') {
        if (_inputExpression.length > 1) {
          _inputExpression = _inputExpression.substring(0, _inputExpression.length - 1);
        } else {
          _inputExpression = '0';
        }
      } else if (key == '000') {
        if (_inputExpression != '0' && _inputExpression.length <= 11) {
          _inputExpression += '000';
        }
      } else if (key == '+/-') {
        _isNegative = !_isNegative;
      } else {
        if (_inputExpression == '0') {
          _inputExpression = key;
        } else if (_inputExpression.length <= 13) {
          _inputExpression += key;
        }
      }
    });
  }

  Future<void> _submitAudit() async {
    if (_isSubmitting) return;

    final deltaAmount = _delta;
    final reasonText = _selectedReason == 'Khác'
        ? (_customReasonController.text.trim().isEmpty
        ? 'Khác'
        : _customReasonController.text.trim())
        : _selectedReason;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final db = ref.read(databaseProvider);
      await db.adjustWalletBalance(
        walletId: widget.wallet.id,
        realBalance: _realBalance,
        reason: reasonText,
      );

      if (mounted) {
        AppFeedback.showSuccess(
          context,
          deltaAmount == 0
              ? 'Số dư ví "${widget.wallet.name}" đã khớp chuẩn 100%!'
              : 'Đã lưu vết kiểm kê ví "${widget.wallet.name}": ${deltaAmount > 0 ? '+' : ''}${_formatCurrency(deltaAmount)}',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppFeedback.showError(
          context,
          'Lỗi kiểm kê: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final deltaAmount = _delta;

    Color deltaColor;
    String deltaLabel;
    IconData deltaIcon;

    if (deltaAmount.abs() < 0.001) {
      deltaColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1);
      deltaLabel = 'Khớp chuẩn 100%';
      deltaIcon = Icons.done_all_rounded;
    } else if (deltaAmount > 0) {
      deltaColor = const Color(0xFF10B981);
      deltaLabel = 'Thặng dư (+${_formatCurrency(deltaAmount)})';
      deltaIcon = Icons.trending_up_rounded;
    } else {
      deltaColor = AppTokens.expense;
      deltaLabel = 'Thâm hụt (${_formatCurrency(deltaAmount)})';
      deltaIcon = Icons.trending_down_rounded;
    }

    return AppFeedbackDismissRegion(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.98) : Colors.white.withValues(alpha: 0.98),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.scale_rounded, color: Colors.amber, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kiểm kê số dư ví',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                ),
                                Text(
                                  widget.wallet.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Thẻ So Sánh: Sổ Sách ($B_{app}$) vs Đếm Được ($B_{real}$)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Số dư trên app:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                ),
                              ),
                              Text(
                                _formatCurrency(widget.wallet.balance),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Số tiền thực tế:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                ),
                              ),
                              Text(
                                _formatCurrency(_realBalance),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  color: accent.primary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(deltaIcon, color: deltaColor, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Chênh lệch (Δ):',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: deltaColor,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                deltaLabel,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                  color: deltaColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bộ chọn Lý do chênh lệch
                    Text(
                      'Lý do điều chỉnh (Tùy chọn):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _reasonPresets.map((reason) {
                          final isSelected = _selectedReason == reason;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedReason = reason);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accent.primary.withValues(alpha: 0.16)
                                      : (isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? accent.primary
                                        : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                                  ),
                                ),
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? accent.primary : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Nhập lý do khác nếu chọn "Khác"
                    if (_selectedReason == 'Khác') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _customReasonController,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nhập chi tiết nguyên nhân chênh lệch...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Numpad 4x4 tích hợp
                    _buildNumpad(isDark, accent),

                    const SizedBox(height: 14),

                    // Nút CTA Xác nhận
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: deltaColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        onPressed: _isSubmitting ? null : _submitAudit,
                        child: _isSubmitting
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Cập nhật số dư thực tế',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ],
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
    );
  }

  Widget _buildNumpad(bool isDark, AppAccentPreset accent) {
    final keys = [
      ['1', '2', '3', '⌫'],
      ['4', '5', '6', 'C'],
      ['7', '8', '9', '000'],
      ['+/-', '0', '', ''],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: row.map((key) {
              if (key.isEmpty) {
                return const Expanded(child: SizedBox());
              }
              final isSpecial = ['⌫', 'C', '000', '+/-'].contains(key);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => _onNumpadPress(key),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSpecial
                            ? (isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle)
                            : (isDark ? AppTokens.darkCardSubtle : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          key,
                          style: TextStyle(
                            fontSize: isSpecial ? 15 : 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: isSpecial ? null : 'monospace',
                            color: isSpecial
                                ? (key == 'C' ? AppTokens.expense : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted))
                                : (isDark ? AppTokens.darkText : AppTokens.lightText),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
