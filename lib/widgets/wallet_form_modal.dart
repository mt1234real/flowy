// ==============================================================================
// File: lib/widgets/wallet_form_modal.dart
// Architecture: Executive Wealth Source Creation & Update Sheet (Schema V6)
// Stack: flutter, flutter_riverpod, drift, intl
// Features:
// 1. Dual Mode: Create New Wallet & Edit Existing Source
// 2. 5 Segmented Type Chips: Cash, Bank, E-Wallet, Credit Card, Savings
// 3. Specialized Credit Card Configuration (creditLimit, statementDay, paymentDueDay)
// 4. Color Swatches & Dedicated Financial Icon Picker
// 5. Executive Switches: Exclude from safe spending & Set as Default Wallet
// ==============================================================================

import 'dart:ui';
import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sliding_segmented_bar.dart';
import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';

class WalletFormModal extends ConsumerStatefulWidget {
  final Wallet? existingWallet;

  const WalletFormModal({
    super.key,
    this.existingWallet,
  });

  static Future<void> show(
      BuildContext context, {
        Wallet? existingWallet,
      }) {
    HapticFeedback.selectionClick();
    return AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => WalletFormModal(existingWallet: existingWallet),
    );
  }

  @override
  ConsumerState<WalletFormModal> createState() => _WalletFormModalState();
}

class _WalletFormModalState extends ConsumerState<WalletFormModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final TextEditingController _creditLimitController;

  late String _selectedType;
  late String _selectedColor;
  late String _selectedIcon;
  late bool _isExcludedFromTotal;
  late bool _isDefault;
  int? _statementDay;
  int? _paymentDueDay;
  bool _isSubmitting = false;
  final AppValidationFeedbackController _nameFeedback =
  AppValidationFeedbackController();

  final List<String> _colorSwatches = [
    '#10B981', // Emerald
    '#0EA5E9', // Sky Blue
    '#6366F1', // Indigo
    '#F59E0B', // Amber
    '#EC4899', // Pink
    '#8B5CF6', // Purple
    '#64748B', // Slate
  ];

  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'Wallet', 'icon': Icons.account_balance_wallet_rounded},
    {'name': 'Bank', 'icon': Icons.account_balance_rounded},
    {'name': 'Card', 'icon': Icons.credit_card_rounded},
    {'name': 'Cash', 'icon': Icons.payments_rounded},
    {'name': 'Savings', 'icon': Icons.savings_rounded},
    {'name': 'Vault', 'icon': Icons.lock_outline_rounded},
    {'name': 'Piggy', 'icon': Icons.paid_rounded},
  ];

  bool get _isEditing => widget.existingWallet != null;

  @override
  void initState() {
    super.initState();
    final w = widget.existingWallet;
    _nameController = TextEditingController(text: w?.name ?? '');
    _balanceController = TextEditingController(
      text: w != null ? w.balance.toStringAsFixed(0) : '0',
    );
    _creditLimitController = TextEditingController(
      text: w?.creditLimit != null ? w!.creditLimit!.toStringAsFixed(0) : '',
    );
    _selectedType = w?.type ?? 'bank';
    _selectedColor = w?.color ?? '#10B981';
    _selectedIcon = w?.icon ?? 'Wallet';
    _isExcludedFromTotal = w?.isExcludedFromTotal ?? false;
    _isDefault = w?.isDefault ?? false;
    _statementDay = w?.statementDay;
    _paymentDueDay = w?.paymentDueDay;
  }

  @override
  void dispose() {
    _nameFeedback.dispose();
    _nameController.dispose();
    _balanceController.dispose();
    _creditLimitController.dispose();
    super.dispose();
  }

  Color _parseColor(String hexColor) {
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  Future<void> _saveWallet() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _nameFeedback.reject();
      return;
    }

    _nameFeedback.clear();
    setState(() => _isSubmitting = true);

    try {
      final db = ref.read(databaseProvider);
      final double? creditLimit = _selectedType == 'credit'
          ? double.tryParse(_creditLimitController.text.replaceAll(RegExp(r'[^0-9.]'), ''))
          : null;

      if (_isEditing) {
        await db.updateWallet(
          id: widget.existingWallet!.id,
          name: name,
          type: _selectedType,
          color: _selectedColor,
          isExcludedFromTotal: _isExcludedFromTotal,
          creditLimit: creditLimit,
          statementDay: _statementDay,
          paymentDueDay: _paymentDueDay,
          isDefault: _isDefault,
        );
        if (_isDefault) {
          await db.setWalletAsDefault(widget.existingWallet!.id);
        }
      } else {
        final double rawBalance = double.tryParse(
          _balanceController.text.replaceAll(RegExp(r'[^0-9.-]'), ''),
        ) ??
            0.0;
        final newId = 'w_${DateTime.now().millisecondsSinceEpoch}';

        await db.insertWallet(
          WalletsCompanion.insert(
            id: newId,
            name: name,
            type: _selectedType,
            balance: Value(rawBalance),
            icon: Value(_selectedIcon),
            color: Value(_selectedColor),
            isExcludedFromTotal: Value(_isExcludedFromTotal),
            creditLimit: Value(creditLimit),
            statementDay: Value(_statementDay),
            paymentDueDay: Value(_paymentDueDay),
            isDefault: Value(_isDefault),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        if (_isDefault) {
          await db.setWalletAsDefault(newId);
        }
      }

      if (mounted) {
        AppFeedback.showSuccess(
          context,
          _isEditing
              ? 'Đã lưu thay đổi ví "$name"'
              : 'Đã tạo nguồn tiền mới "$name"',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppFeedback.showError(context, 'Lỗi lưu ví: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    return AppFeedbackDismissRegion(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).viewInsets.bottom + 24),
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
                        Text(
                          _isEditing ? 'Chỉnh Sửa Nguồn Tiền' : 'Tạo Nguồn Tiền Mới',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
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
                    const SizedBox(height: 14),

                    // Tên ví — validation cục bộ, không phát overlay khi thiếu dữ liệu.
                    AppValidationFeedback(
                      controller: _nameFeedback,
                      builder: (context, visual) {
                        final restingBorder = isDark
                            ? AppTokens.darkBorder
                            : AppTokens.lightBorder;
                        final borderColor =
                        visual.borderColor(restingBorder);

                        return TextField(
                          controller: _nameController,
                          onChanged: (value) {
                            if (value.trim().isNotEmpty) {
                              _nameFeedback.clear();
                            }
                          },
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppTokens.darkText
                                : AppTokens.lightText,
                          ),
                          decoration: InputDecoration(
                            labelText:
                            'Tên ví / Tài khoản (vd: VCB Tiền lương, Momo, Visa)',
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTokens.darkMuted
                                  : AppTokens.lightMuted,
                            ),
                            prefixIcon:
                            const Icon(Icons.wallet_rounded, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: borderColor,
                                width: visual.isInvalid ? 1.8 : 1.0,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: visual.isInvalid
                                    ? AppTokens.expense
                                    : accent.primary,
                                width: 1.8,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Loại ví (Segmented Chips) — shared preserved sliding engine
                    Text(
                      'Phân loại nguồn tiền:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      child: SizedBox(
                        width: 620,
                        child: SlidingSegmentedBar<String>(
                          height: 38,
                          duration: const Duration(milliseconds: 185),
                          overshootPx: 1.6,
                          debugLabel: 'WalletForm.type',
                          selectedValue: _selectedType,
                          trackColor: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                          trackBorderColor: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                          mutedTextColor: isDark ? AppTokens.darkMuted : AppTokens.lightText,
                          items: const [
                            SlidingSegmentedItem<String>(
                              value: 'cash',
                              label: 'Tiền mặt',
                              icon: Icons.payments_rounded,
                            ),
                            SlidingSegmentedItem<String>(
                              value: 'bank',
                              label: 'Ngân hàng',
                              icon: Icons.account_balance_rounded,
                            ),
                            SlidingSegmentedItem<String>(
                              value: 'ewallet',
                              label: 'Ví điện tử',
                              icon: Icons.account_balance_wallet_rounded,
                            ),
                            SlidingSegmentedItem<String>(
                              value: 'credit',
                              label: 'Thẻ tín dụng',
                              icon: Icons.credit_card_rounded,
                            ),
                            SlidingSegmentedItem<String>(
                              value: 'savings',
                              label: 'Tiết kiệm',
                              icon: Icons.savings_rounded,
                            ),
                          ],
                          onValueChanged: (type) {
                            setState(() => _selectedType = type);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Số dư ban đầu (chỉ khi tạo mới)
                    if (!_isEditing) ...[
                      TextField(
                        controller: _balanceController,
                        keyboardType: const TextInputType.numberWithOptions(signed: true),
                        style: currencyTextStyle(context, TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: accent.primary,
                        )),
                        decoration: InputDecoration(
                          labelText: _selectedType == 'credit'
                              ? 'Dư nợ ban đầu (số âm vd: -5000000)'
                              : 'Số dư ban đầu (₫)',
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                          ),
                          prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // CẤU HÌNH ĐẶC THÙ THẺ TÍN DỤNG
                    if (_selectedType == 'credit') ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.credit_score_rounded, color: Colors.amber, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Cấu hình Thẻ Tín Dụng & Dư Nợ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _creditLimitController,
                              keyboardType: TextInputType.number,
                              style: currencyTextStyle(context, TextStyle(
                                fontSize: 14,
                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                              )),
                              decoration: InputDecoration(
                                labelText: 'Hạn mức tín dụng tối đa (vd: 50.000.000 ₫)',
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                ),
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Dropdown ngày sao kê
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _statementDay,
                                    decoration: InputDecoration(
                                      labelText: 'Ngày sao kê',
                                      labelStyle: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                      ),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    dropdownColor: isDark ? AppTokens.darkCard : Colors.white,
                                    items: List.generate(31, (i) => i + 1)
                                        .map((d) => DropdownMenuItem(
                                      value: d,
                                      child: Text('Ngày $d', style: const TextStyle(fontSize: 12)),
                                    ))
                                        .toList(),
                                    onChanged: (val) => setState(() => _statementDay = val),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Dropdown ngày đến hạn thanh toán
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _paymentDueDay,
                                    decoration: InputDecoration(
                                      labelText: 'Hạn thanh toán',
                                      labelStyle: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                      ),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    dropdownColor: isDark ? AppTokens.darkCard : Colors.white,
                                    items: List.generate(31, (i) => i + 1)
                                        .map((d) => DropdownMenuItem(
                                      value: d,
                                      child: Text('Ngày $d', style: const TextStyle(fontSize: 12)),
                                    ))
                                        .toList(),
                                    onChanged: (val) => setState(() => _paymentDueDay = val),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Bảng Chọn Icon
                    Text(
                      'Biểu tượng nhận diện:',
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
                        children: _iconOptions.map((opt) {
                          final isSelected = _selectedIcon == opt['name'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedIcon = opt['name'] as String);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accent.primary.withValues(alpha: 0.16)
                                      : (isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? accent.primary : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                                  ),
                                ),
                                child: Icon(
                                  opt['icon'] as IconData,
                                  size: 18,
                                  color: isSelected ? accent.primary : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Bảng Chọn Màu Sắc
                    Text(
                      'Màu sắc chủ đạo:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _colorSwatches.map((hex) {
                        final isSelected = _selectedColor.toLowerCase() == hex.toLowerCase();
                        final color = _parseColor(hex);
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedColor = hex);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                                boxShadow: isSelected
                                    ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                                    : null,
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Switches Cấu Hình
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Loại trừ khỏi Tổng số dư khả dụng',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      subtitle: Text(
                        'Thích hợp cho sổ tiết kiệm hoặc tài khoản đóng băng.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                        ),
                      ),
                      value: _isExcludedFromTotal,
                      activeThumbColor: accent.primary,
                      onChanged: (val) => setState(() => _isExcludedFromTotal = val),
                    ),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Đặt làm ví thanh toán mặc định',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      value: _isDefault,
                      activeThumbColor: accent.primary,
                      onChanged: (val) => setState(() => _isDefault = val),
                    ),
                    const SizedBox(height: 18),

                    // CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        onPressed: _isSubmitting ? null : _saveWallet,
                        child: _isSubmitting
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : Text(
                          _isEditing ? 'LƯU THAY ĐỔI' : 'TẠO NGUỒN TIỀN',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
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


}