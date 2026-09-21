// ==============================================================================
// File: lib/widgets/internal_transfer_sheet.dart
// Architecture: Executive Internal Wallet-to-Wallet Transfer Sheet (Double-Entry Non-Impact Engine)
// Stack: flutter, flutter_riverpod, drift, intl
// Features:
// 1. Source & Destination Wallet Pickers with instant swap button (🔄)
// 2. Custom Numpad 4x4 with quick-increment chips (+50k, +100k, +200k, +500k, Tất cả số dư)
// 3. Optional Transfer Fee & Transaction Note
// 4. Real-time Post-Transfer Balance Impact Simulator
// 5. ACID Double-Entry Transaction Execution (CategoryType.transfer)
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

/// StreamProvider chuyên biệt lấy danh sách ví đang hoạt động (không gồm ví lưu trữ)
final activeWalletsStreamProvider = StreamProvider.autoDispose<List<Wallet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllWallets(includeArchived: false);
});

class InternalTransferSheet extends ConsumerStatefulWidget {
  final String? initialFromWalletId;
  final String? initialToWalletId;
  final double? initialAmount;
  final String? initialNote;

  const InternalTransferSheet({
    super.key,
    this.initialFromWalletId,
    this.initialToWalletId,
    this.initialAmount,
    this.initialNote,
  });

  static Future<void> show(
      BuildContext context, {
        String? initialFromWalletId,
        String? initialToWalletId,
        double? initialAmount,
        String? initialNote,
      }) {
    HapticFeedback.selectionClick();
    return AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => InternalTransferSheet(
        initialFromWalletId: initialFromWalletId,
        initialToWalletId: initialToWalletId,
        initialAmount: initialAmount,
        initialNote: initialNote,
      ),
    );
  }

  @override
  ConsumerState<InternalTransferSheet> createState() => _InternalTransferSheetState();
}

class _InternalTransferSheetState extends ConsumerState<InternalTransferSheet> {
  String? _fromWalletId;
  String? _toWalletId;
  String _amountInput = '0';
  double _transferFee = 0.0;
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _feeController = TextEditingController();
  bool _isSubmitting = false;
  bool _showExtraFields = false;

  final AppValidationFeedbackController _walletFeedback =
  AppValidationFeedbackController();
  final AppValidationFeedbackController _amountFeedback =
  AppValidationFeedbackController();

  @override
  void initState() {
    super.initState();
    _fromWalletId = widget.initialFromWalletId;
    _toWalletId = widget.initialToWalletId;
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _amountInput = widget.initialAmount!.toStringAsFixed(0);
    }
    if (widget.initialNote != null) {
      _noteController.text = widget.initialNote!;
    }
  }

  @override
  void dispose() {
    _walletFeedback.dispose();
    _amountFeedback.dispose();
    _noteController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  double get _currentAmount {
    return double.tryParse(_amountInput) ?? 0.0;
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  void _onNumpadPress(String val) {
    HapticFeedback.selectionClick();
    _amountFeedback.clear();
    setState(() {
      if (val == 'C') {
        _amountInput = '0';
      } else if (val == '⌫') {
        if (_amountInput.length > 1) {
          _amountInput = _amountInput.substring(0, _amountInput.length - 1);
        } else {
          _amountInput = '0';
        }
      } else if (val == '000') {
        if (_amountInput != '0') {
          if (_amountInput.length < 11) {
            _amountInput += '000';
          }
        }
      } else {
        if (_amountInput == '0') {
          _amountInput = val;
        } else {
          if (_amountInput.length < 13) {
            _amountInput += val;
          }
        }
      }
    });
  }

  void _addQuickAmount(double delta) {
    HapticFeedback.selectionClick();
    _amountFeedback.clear();
    setState(() {
      final current = double.tryParse(_amountInput) ?? 0.0;
      final next = current + delta;
      _amountInput = next.toStringAsFixed(0);
    });
  }

  void _swapWallets() {
    HapticFeedback.mediumImpact();
    _walletFeedback.clear();
    _amountFeedback.clear();
    setState(() {
      final temp = _fromWalletId;
      _fromWalletId = _toWalletId;
      _toWalletId = temp;
    });
  }

  Future<void> _submitTransfer(List<Wallet> wallets) async {
    final fromWallet = wallets.firstWhere((w) => w.id == _fromWalletId, orElse: () => wallets.first);
    final toWallet = wallets.firstWhere((w) => w.id == _toWalletId, orElse: () => wallets.first);

    if (_fromWalletId == null || _toWalletId == null) {
      _walletFeedback.reject();
      return;
    }

    if (_fromWalletId == _toWalletId) {
      _walletFeedback.reject();
      return;
    }

    if (_currentAmount <= 0) {
      _amountFeedback.reject();
      return;
    }

    final totalDeduct = _currentAmount + _transferFee;
    if (fromWallet.type != 'credit' && fromWallet.balance < totalDeduct) {
      _walletFeedback.reject();
      _amountFeedback.reject(emitHaptic: false);
      return;
    }

    _walletFeedback.clear();
    _amountFeedback.clear();
    setState(() => _isSubmitting = true);

    try {
      final db = ref.read(databaseProvider);
      await db.executeInternalTransfer(
        fromWalletId: _fromWalletId!,
        toWalletId: _toWalletId!,
        amount: _currentAmount,
        fee: _transferFee,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        date: DateTime.now(),
      );

      if (mounted) {
        AppFeedback.showSuccess(
          context,
          'Đã chuyển ${_formatCurrency(_currentAmount)} từ '
              '"${fromWallet.name}" sang "${toWallet.name}" thành công!',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppFeedback.showError(
          context,
          'Lỗi thực hiện chuyển tiền: $e',
        );
      }
    }
  }

  void _showWalletPicker({
    required BuildContext context,
    required bool isSource,
    required List<Wallet> wallets,
    required bool isDark,
    required AppAccentPreset accent,
  }) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (sheetContext, __) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            decoration: BoxDecoration(
              color: isDark ? AppTokens.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isSource ? 'Chọn Ví Nguồn (Trích Tiền)' : 'Chọn Ví Đích (Nhận Tiền)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(sheetContext).size.height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: wallets.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final wallet = wallets[index];
                        final isSelected = isSource
                            ? wallet.id == _fromWalletId
                            : wallet.id == _toWalletId;
                        final isOpposite = isSource
                            ? wallet.id == _toWalletId
                            : wallet.id == _fromWalletId;

                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (isSource) {
                                _fromWalletId = wallet.id;
                                if (_toWalletId == wallet.id) {
                                  _toWalletId = null;
                                }
                              } else {
                                _toWalletId = wallet.id;
                                if (_fromWalletId == wallet.id) {
                                  _fromWalletId = null;
                                }
                              }
                            });
                            _walletFeedback.clear();
                            _amountFeedback.clear();
                            Navigator.of(sheetContext).pop();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.primary.withValues(alpha: 0.12)
                                  : (isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? accent.primary
                                    : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _parseColor(wallet.color).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      _getWalletIconData(wallet.type),
                                      size: 20,
                                      color: _parseColor(wallet.color),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            wallet.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                            ),
                                          ),
                                          if (isOpposite) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isSource ? 'Đang là đích' : 'Đang là nguồn',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_getWalletTypeName(wallet.type)} • Số dư: ${_formatCurrency(wallet.balance)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded, color: accent.primary, size: 20),
                              ],
                            ),
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
      ),
    );
  }

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  IconData _getWalletIconData(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return Icons.account_balance_rounded;
      case 'ewallet':
        return Icons.account_balance_wallet_rounded;
      case 'credit':
        return Icons.credit_card_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'cash':
      default:
        return Icons.payments_rounded;
    }
  }

  String _getWalletTypeName(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return 'Tài khoản Ngân hàng';
      case 'ewallet':
        return 'Ví điện tử';
      case 'credit':
        return 'Thẻ tín dụng';
      case 'savings':
        return 'Tài khoản tiết kiệm';
      case 'cash':
      default:
        return 'Tiền mặt';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final walletsAsync = ref.watch(activeWalletsStreamProvider);

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
              child: walletsAsync.when(
                data: (wallets) {
                  if (wallets.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Chưa có ví nào để chuyển tiền.')),
                    );
                  }

                  _fromWalletId ??= wallets.first.id;
                  if (_toWalletId == null || _toWalletId == _fromWalletId) {
                    if (wallets.length > 1) {
                      _toWalletId = wallets.firstWhere((w) => w.id != _fromWalletId).id;
                    } else {
                      _toWalletId = wallets.first.id;
                    }
                  }

                  final fromWallet = wallets.firstWhere((w) => w.id == _fromWalletId, orElse: () => wallets.first);
                  final toWallet = wallets.firstWhere((w) => w.id == _toWalletId, orElse: () => wallets.first);

                  final fromAfterBalance = fromWallet.balance - (_currentAmount + _transferFee);
                  final toAfterBalance = toWallet.balance + _currentAmount;

                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thanh Handle Kéo
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

                        // Tiêu đề & Nút đóng
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: accent.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.sync_alt_rounded, color: accent.primary, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chuyển Tiền Nội Bộ',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                      ),
                                    ),
                                    Text(
                                      'Không ảnh hưởng Tổng Thu/Chi của chu kỳ',
                                      style: TextStyle(
                                        fontSize: 11,
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
                                size: 22,
                                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Khối chọn Ví Nguồn ⇄ Đảo Chiều ⇄ Ví Đích
                        AppValidationFeedback(
                          controller: _walletFeedback,
                          builder: (context, visual) {
                            final restingBorder = isDark
                                ? AppTokens.darkBorder
                                : AppTokens.lightBorder;
                            final borderColor =
                            visual.borderColor(restingBorder);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTokens.darkCard
                                    : AppTokens.lightCardSubtle,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: borderColor,
                                  width: visual.isInvalid ? 1.8 : 1.0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Ví Nguồn
                                  InkWell(
                                    onTap: () => _showWalletPicker(
                                      context: context,
                                      isSource: true,
                                      wallets: wallets,
                                      isDark: isDark,
                                      accent: accent,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTokens.darkCardSubtle : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: _parseColor(fromWallet.color).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              _getWalletIconData(fromWallet.type),
                                              size: 18,
                                              color: _parseColor(fromWallet.color),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Từ ví nguồn',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                                  ),
                                                ),
                                                Text(
                                                  fromWallet.name,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Khả dụng',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                                ),
                                              ),
                                              Text(
                                                _formatCurrency(fromWallet.balance),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  fontFamily: 'monospace',
                                                  color: fromWallet.balance < 0
                                                      ? AppTokens.expense
                                                      : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Nút Đảo Chiều
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Center(
                                      child: InkWell(
                                        onTap: _swapWallets,
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: accent.primary.withValues(alpha: 0.16),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: accent.primary.withValues(alpha: 0.3),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.swap_vert_rounded,
                                            size: 18,
                                            color: accent.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Ví Đích
                                  InkWell(
                                    onTap: () => _showWalletPicker(
                                      context: context,
                                      isSource: false,
                                      wallets: wallets,
                                      isDark: isDark,
                                      accent: accent,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTokens.darkCardSubtle : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: _parseColor(toWallet.color).withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              _getWalletIconData(toWallet.type),
                                              size: 18,
                                              color: _parseColor(toWallet.color),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Đến ví nhận',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                                  ),
                                                ),
                                                Text(
                                                  toWallet.name,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Hiện có',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                                ),
                                              ),
                                              Text(
                                                _formatCurrency(toWallet.balance),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  fontFamily: 'monospace',
                                                  color: toWallet.balance < 0
                                                      ? AppTokens.expense
                                                      : (isDark ? AppTokens.darkText : AppTokens.lightText),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),

                        // Màn hình hiển thị số tiền & Chips cộng nhanh
                        AppValidationFeedback(
                          controller: _amountFeedback,
                          builder: (context, visual) {
                            final restingBorder = isDark
                                ? AppTokens.darkBorder
                                : AppTokens.lightBorder;
                            final borderColor =
                            visual.borderColor(restingBorder);

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color:
                                isDark ? AppTokens.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: borderColor,
                                  width: visual.isInvalid ? 1.8 : 1.0,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'SỐ TIỀN CHUYỂN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _formatCurrency(_currentAmount),
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                        color: accent.primary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: [
                                        _buildQuickAddChip('+50.000', 50000, isDark, accent),
                                        const SizedBox(width: 6),
                                        _buildQuickAddChip('+100.000', 100000, isDark, accent),
                                        const SizedBox(width: 6),
                                        _buildQuickAddChip('+200.000', 200000, isDark, accent),
                                        const SizedBox(width: 6),
                                        _buildQuickAddChip('+500.000', 500000, isDark, accent),
                                        if (fromWallet.balance > 0) ...[
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              _amountFeedback.clear();
                                              setState(() {
                                                _amountInput =
                                                    fromWallet.balance.toStringAsFixed(0);
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(10),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                              ),
                                              child: const Text(
                                                'Tất cả số dư',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // Nút mở rộng Phí & Ghi chú
                        InkWell(
                          onTap: () {
                            setState(() => _showExtraFields = !_showExtraFields);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _showExtraFields
                                      ? '▾ Thu gọn thông tin phụ'
                                      : '▸ Thêm phí giao dịch & ghi chú',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                  ),
                                ),
                                if (_transferFee > 0)
                                  Text(
                                    'Phí: ${_formatCurrency(_transferFee)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTokens.expense,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        if (_showExtraFields) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  controller: _feeController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Phí chuyển (nếu có)',
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                    ),
                                    prefixIcon: const Icon(Icons.receipt_outlined, size: 16),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    _walletFeedback.clear();
                                    _amountFeedback.clear();
                                    setState(() {
                                      _transferFee = double.tryParse(
                                        val.replaceAll(RegExp(r'[^0-9]'), ''),
                                      ) ??
                                          0.0;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: TextField(
                                  controller: _noteController,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Ghi chú chuyển tiền',
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                    ),
                                    prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Banner đối soát số dư Real-time
                        if (_currentAmount > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sau chuyển: ${fromWallet.name}: ${_formatCurrency(fromAfterBalance)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: fromAfterBalance < 0
                                        ? AppTokens.expense
                                        : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                                  ),
                                ),
                                Text(
                                  '➔ ${toWallet.name}: ${_formatCurrency(toAfterBalance)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Numpad 4x4 tích hợp
                        _buildNumpad(isDark, accent),

                        const SizedBox(height: 14),

                        // Nút CTA xác nhận
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
                            onPressed: _isSubmitting ? null : () => _submitTransfer(wallets),
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
                                  'XÁC NHẬN CHUYỂN TIỀN',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Lỗi: $err')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddChip(String label, double amount, bool isDark, AppAccentPreset accent) {
    return InkWell(
      onTap: () => _addQuickAmount(amount),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: isDark ? AppTokens.darkText : AppTokens.lightText,
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
      ['', '0', '', ''],
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
              final isSpecial = ['⌫', 'C', '000'].contains(key);
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