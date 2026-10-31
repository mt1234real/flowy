// ==============================================================================
// File: lib/screens/wallet_manager_screen.dart
// Architecture: Executive Wealth Source Management & Audit Engine (Phase 1 & 2)
// Stack: flutter, flutter_riverpod, drift, intl
// Features:
// 1. Executive Asset Overview (Net Real Assets, Available Liquidity, Excluded/Frozen)
// 2. 4 Grouped Categories: Cash/Payment, Savings/Private, Credit Cards & Debts, Archived
// 3. Quick Repay Shortcut for Credit Cards (Instant Internal Transfer Prefill)
// 4. Slidable Actions: [⭐ Set Default], [✏️ Edit], [⚖️ Balance Audit], [🗑️ Archive/Delete]
// 5. Safe Deletion Guardrail Dialog (Blocks deletion if transactions exist)
// 6. Balance Audit Sheet with Auto-Balancing Accounting Transaction (ACID Audit Trail)
// 7. Responsive Top Header: Flexible title with overflow ellipsis, compact Transfer button & 36x36 circular (+) CTA
// ==============================================================================

import 'dart:math' as math;
import 'dart:ui';
import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
import '../theme/app_icons.dart';
import '../widgets/currency_text.dart';
import '../widgets/internal_transfer_sheet.dart';

// StreamProvider lấy toàn bộ danh sách ví bao gồm cả ví lưu trữ
final allWalletsWithArchivedStreamProvider = StreamProvider.autoDispose<List<Wallet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllWallets(includeArchived: true);
});

class WalletManagerScreen extends ConsumerStatefulWidget {
  const WalletManagerScreen({super.key});

  @override
  ConsumerState<WalletManagerScreen> createState() => _WalletManagerScreenState();
}

class _WalletManagerScreenState extends ConsumerState<WalletManagerScreen> {
  bool _isBalanceVisible = true;

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(amount);
  }

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
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

  // ============================================================================
  // HỘP THOẠI KIỂM KÊ SỐ DƯ VÍ (BALANCE AUDIT DIALOG)
  // ============================================================================
  void _showBalanceAuditDialog(BuildContext context, Wallet wallet, bool isDark, AppAccentPreset accent) {
    HapticFeedback.selectionClick();
    final TextEditingController realBalanceController = TextEditingController(
      text: wallet.balance.toStringAsFixed(0),
    );
    final TextEditingController reasonController = TextEditingController(
      text: 'Kiểm kê định kỳ',
    );
    double calculatedDelta = 0.0;

    AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (sheetContext, __) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final enteredAmount = double.tryParse(
              realBalanceController.text.replaceAll(RegExp(r'[^0-9.-]'), ''),
            ) ??
                wallet.balance;
            calculatedDelta = enteredAmount - wallet.balance;

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
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
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.black26,
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
                                color: Colors.amber.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.scale_rounded, color: Colors.amber, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kiểm Kê Số Dư Ví',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                    ),
                                  ),
                                  Text(
                                    wallet.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Khối so sánh Sổ sách vs Thực tế
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                            borderRadius: BorderRadius.circular(16),
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
                                    'Số dư trên sổ sách:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(wallet.balance),
                                    style: currencyTextStyle(context, TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                    )),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Chênh lệch đối soát (Δ):',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                    ),
                                  ),
                                  Text(
                                    '${calculatedDelta >= 0 ? '+' : ''}${_formatCurrency(calculatedDelta)}',
                                    style: currencyTextStyle(context, TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: calculatedDelta == 0
                                          ? (isDark ? AppTokens.darkMuted : AppTokens.lightMuted)
                                          : (calculatedDelta > 0 ? AppTokens.income : AppTokens.expense),
                                    )),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Nhập số dư thực tế
                        TextField(
                          controller: realBalanceController,
                          keyboardType: const TextInputType.numberWithOptions(signed: true),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: accent.primary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Số dư thực tế đếm được (₫)',
                            labelStyle: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                            prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onChanged: (val) {
                            setModalState(() {});
                          },
                        ),
                        const SizedBox(height: 12),

                        // Lý do kiểm kê
                        TextField(
                          controller: reasonController,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Lý do điều chỉnh',
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                            prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          '💡 Chênh lệch được lưu là Điều chỉnh số dư, không tính vào thu nhập hoặc chi tiêu.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                          ),
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                              final targetBalance = double.tryParse(
                                realBalanceController.text.replaceAll(RegExp(r'[^0-9.-]'), ''),
                              );
                              if (targetBalance == null || !targetBalance.isFinite) {
                                AppFeedback.showError(context, 'Hãy nhập số dư thực tế hợp lệ.');
                                return;
                              }
                              final reason = reasonController.text.trim().isEmpty
                                  ? 'Kiểm kê định kỳ'
                                  : reasonController.text.trim();

                              final db = ref.read(databaseProvider);
                              try {
                                await db.adjustWalletBalance(
                                  walletId: wallet.id,
                                  realBalance: targetBalance,
                                  reason: reason,
                                );

                                if (context.mounted) {
                                  AppFeedback.showSuccess(
                                    context,
                                    'Đã cập nhật số dư ví "${wallet.name}" thành công!',
                                  );
                                  Navigator.of(context).pop();
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  AppFeedback.showError(context, 'Không thể điều chỉnh số dư. Chưa có thay đổi nào được lưu.');
                                }
                              }
                            },
                            child: const Text(
                              '✓ XÁC NHẬN ĐIỀU CHỈNH SỐ DƯ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
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
  }

  // ============================================================================
  // SAFE DELETION & ARCHIVE GUARDRAIL DIALOG
  // ============================================================================
  void _showDeleteOrArchiveDialog(BuildContext context, Wallet wallet, bool isDark) {
    HapticFeedback.heavyImpact();
    final db = ref.read(databaseProvider);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<List<Transaction>>(
          future: (db.select(db.transactions)
            ..where((t) => t.walletId.equals(wallet.id) | t.toWalletId.equals(wallet.id)))
              .get(),
          builder: (context, snapshot) {
            final txCount = snapshot.data?.length ?? 0;
            final bool hasTransactions = txCount > 0;
            final bool hasNonZeroBalance = wallet.balance.abs() > 0.001;

            return AlertDialog(
              backgroundColor: isDark ? AppTokens.darkCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(
                    hasTransactions ? Icons.shield_rounded : Icons.delete_outline_rounded,
                    color: hasTransactions ? Colors.amber : AppTokens.expense,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasTransactions ? 'Bảo Vệ Sổ Cái (Guardrail)' : 'Xóa Ví',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTransactions) ...[
                    Text(
                      'Ví "${wallet.name}" đã phát sinh $txCount giao dịch trong quá khứ.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Để đảm bảo tính toàn vẹn của sổ sách và các báo cáo chi tiêu cũ, hệ thống KHÔNG CHO PHÉP XÓA CỨNG ví này.\n\nThay vào đó, bạn hãy đưa số dư về 0 ₫ rồi chọn "Ẩn / Lưu trữ ví".',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (hasNonZeroBalance)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTokens.expense.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppTokens.expense, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CurrencyText(
                                'Số dư ví hiện tại là ${_formatCurrency(wallet.balance)}. Hãy chuyển hết tiền hoặc kiểm kê về 0 ₫ trước khi lưu trữ.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTokens.expense,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else ...[
                    Text(
                      'Ví "${wallet.name}" chưa có giao dịch phát sinh nào. Bạn có chắc chắn muốn xóa vĩnh viễn ví này?',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Đóng', style: TextStyle(color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted)),
                ),
                if (hasTransactions) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: hasNonZeroBalance
                        ? null
                        : () async {
                      HapticFeedback.mediumImpact();
                      await db.archiveWallet(wallet.id);
                      if (context.mounted) {
                        Navigator.of(dialogContext).pop();
                        AppFeedback.showSuccess(
                          context,
                          'Đã lưu trữ ví "${wallet.name}" thành công.',
                        );
                      }
                    },
                    child: const Text('Ẩn / Lưu Trữ Ví', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ] else ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTokens.expense,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      HapticFeedback.heavyImpact();
                      await db.deleteWalletSafely(wallet.id);
                      if (context.mounted) {
                        Navigator.of(dialogContext).pop();
                        AppFeedback.showSuccess(
                          context,
                          'Đã xóa ví "${wallet.name}".',
                        );
                      }
                    },
                    child: const Text('Xóa Vĩnh Viễn', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // MODAL TẠO MỚI HOẶC CHỈNH SỬA VÍ (CREATE / EDIT WALLET MODAL)
  // ============================================================================
  void _showCreateOrEditWalletModal(
      BuildContext context, {
        Wallet? existingWallet,
        required bool isDark,
        required AppAccentPreset accent,
      }) {
    HapticFeedback.selectionClick();
    final isEditing = existingWallet != null;

    final nameController = TextEditingController(text: existingWallet?.name ?? '');
    final balanceController = TextEditingController(
      text: existingWallet != null ? existingWallet.balance.toStringAsFixed(0) : '0',
    );
    final creditLimitController = TextEditingController(
      text: existingWallet?.creditLimit != null ? existingWallet!.creditLimit!.toStringAsFixed(0) : '',
    );
    final statementDayController = TextEditingController(
      text: existingWallet?.statementDay != null ? existingWallet!.statementDay.toString() : '',
    );
    final paymentDueDayController = TextEditingController(
      text: existingWallet?.paymentDueDay != null ? existingWallet!.paymentDueDay.toString() : '',
    );

    String selectedType = existingWallet?.type ?? 'bank';
    String selectedColor = existingWallet?.color ?? '#10B981';
    bool isExcluded = existingWallet?.isExcludedFromTotal ?? false;
    bool isDefault = existingWallet?.isDefault ?? false;
    final nameValidation = AppValidationFeedbackController();

    AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (sheetContext, __) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    MediaQuery.of(sheetContext).viewInsets.bottom + 24,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
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
                          Center(
                            child: Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white24 : Colors.black26,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Text(
                            isEditing ? 'Chỉnh Sửa Nguồn Tiền' : 'Thêm Nguồn Tiền Mới',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Tên ví
                          AppValidationFeedback(
                            controller: nameValidation,
                            builder: (context, visual) => TextField(
                              controller: nameController,
                              onChanged: (_) => nameValidation.clear(),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Tên ví / Tài khoản (vd: VCB Lương, Momo, Visa)',
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                ),
                                prefixIcon: const Icon(Icons.wallet_rounded, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: visual.borderColor(
                                      isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                                    ),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: visual.borderColor(
                                      isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: visual.isInvalid ? AppTokens.expense : accent.primary,
                                    width: visual.isInvalid ? 1.8 : 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Loại ví Chips
                          Text(
                            'Phân loại nguồn tiền:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildTypeChip('cash', 'Tiền mặt', Icons.payments_rounded, selectedType, (t) {
                                  setModalState(() => selectedType = t);
                                }, isDark, accent),
                                const SizedBox(width: 8),
                                _buildTypeChip('bank', 'Ngân hàng', Icons.account_balance_rounded, selectedType, (t) {
                                  setModalState(() => selectedType = t);
                                }, isDark, accent),
                                const SizedBox(width: 8),
                                _buildTypeChip('ewallet', 'Ví điện tử', Icons.account_balance_wallet_rounded, selectedType, (t) {
                                  setModalState(() => selectedType = t);
                                }, isDark, accent),
                                const SizedBox(width: 8),
                                _buildTypeChip('credit', 'Thẻ tín dụng', Icons.credit_card_rounded, selectedType, (t) {
                                  setModalState(() => selectedType = t);
                                }, isDark, accent),
                                const SizedBox(width: 8),
                                _buildTypeChip('savings', 'Tiết kiệm', Icons.savings_rounded, selectedType, (t) {
                                  setModalState(() => selectedType = t);
                                }, isDark, accent),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Số dư ban đầu (chỉ khi tạo mới)
                          if (!isEditing) ...[
                            TextField(
                              controller: balanceController,
                              keyboardType: const TextInputType.numberWithOptions(signed: true),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: accent.primary,
                              ),
                              decoration: InputDecoration(
                                labelText: selectedType == 'credit' ? 'Dư nợ ban đầu (số âm vd: -5000000)' : 'Số dư ban đầu (₫)',
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                ),
                                prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // NẾU LÀ THẺ TÍN DỤNG: CÁC TRƯỜNG ĐẶC THÙ
                          if (selectedType == 'credit') ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                                borderRadius: BorderRadius.circular(16),
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
                                      const SizedBox(width: 6),
                                      Text(
                                        'Cấu hình Thẻ Tín Dụng',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: creditLimitController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                    ),
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
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: statementDayController,
                                          keyboardType: TextInputType.number,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Ngày sao kê (1-31)',
                                            labelStyle: TextStyle(
                                              fontSize: 10,
                                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                            ),
                                            isDense: true,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: paymentDueDayController,
                                          keyboardType: TextInputType.number,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: 'Hạn thanh toán (1-31)',
                                            labelStyle: TextStyle(
                                              fontSize: 10,
                                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                            ),
                                            isDense: true,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Tùy chọn Loại trừ khỏi Tổng Khả Chi
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Loại trừ khỏi Tổng Số Dư & Hạn mức khả chi',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                              ),
                            ),
                            subtitle: Text(
                              'Thích hợp cho sổ tiết kiệm, tài sản riêng tư không dùng tiêu vặt hàng ngày.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                              ),
                            ),
                            value: isExcluded,
                            activeThumbColor: accent.primary,
                            onChanged: (val) {
                              setModalState(() => isExcluded = val);
                            },
                          ),

                          // Tùy chọn Ví mặc định
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Đặt làm ví mặc định khi ghi chép',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                              ),
                            ),
                            value: isDefault,
                            activeThumbColor: accent.primary,
                            onChanged: (val) {
                              setModalState(() => isDefault = val);
                            },
                          ),
                          const SizedBox(height: 10),

                          // Palette chọn màu
                          Text(
                            'Màu sắc đại diện:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              '#10B981',
                              '#0EA5E9',
                              '#6366F1',
                              '#F59E0B',
                              '#EC4899',
                              '#8B5CF6',
                              '#64748B',
                            ].map((hex) {
                              final isSelected = selectedColor.toLowerCase() == hex.toLowerCase();
                              final color = _parseColor(hex);
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setModalState(() => selectedColor = hex);
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(color: Colors.white, width: 3)
                                          : null,
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
                                    child: isSelected
                                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),

                          // CTA Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) {
                                  nameValidation.reject();
                                  return;
                                }

                                final db = ref.read(databaseProvider);
                                final creditLimit = double.tryParse(creditLimitController.text.replaceAll(RegExp(r'[^0-9.]'), ''));
                                final statementDay = int.tryParse(statementDayController.text.trim());
                                final paymentDueDay = int.tryParse(paymentDueDayController.text.trim());

                                if (isEditing) {
                                  await db.updateWallet(
                                    id: existingWallet.id,
                                    name: name,
                                    type: selectedType,
                                    color: selectedColor,
                                    isExcludedFromTotal: isExcluded,
                                    creditLimit: creditLimit,
                                    statementDay: statementDay,
                                    paymentDueDay: paymentDueDay,
                                    isDefault: isDefault,
                                  );
                                  if (isDefault) {
                                    await db.setWalletAsDefault(existingWallet.id);
                                  }
                                } else {
                                  final rawBalance = double.tryParse(
                                    balanceController.text.replaceAll(RegExp(r'[^0-9.-]'), ''),
                                  ) ??
                                      0.0;
                                  final newId = 'w_${DateTime.now().millisecondsSinceEpoch}';

                                  await db.insertWallet(
                                    WalletsCompanion.insert(
                                      id: newId,
                                      name: name,
                                      type: selectedType,
                                      balance: Value(rawBalance),
                                      color: Value(selectedColor),
                                      isExcludedFromTotal: Value(isExcluded),
                                      creditLimit: Value(creditLimit),
                                      statementDay: Value(statementDay),
                                      paymentDueDay: Value(paymentDueDay),
                                      isDefault: Value(isDefault),
                                      createdAt: Value(DateTime.now()),
                                      updatedAt: Value(DateTime.now()),
                                    ),
                                  );
                                  if (isDefault) {
                                    await db.setWalletAsDefault(newId);
                                  }
                                }

                                if (context.mounted) {
                                  AppFeedback.showSuccess(
                                    context,
                                    isEditing ? 'Đã cập nhật ví "$name"' : 'Đã tạo nguồn tiền mới "$name"',
                                  );
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                              child: Text(
                                isEditing ? 'LƯU THAY ĐỔI' : 'TẠO NGUỒN TIỀN MỚI',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameValidation.dispose();
      nameController.dispose();
      balanceController.dispose();
      creditLimitController.dispose();
      statementDayController.dispose();
      paymentDueDayController.dispose();
    });
  }

  Widget _buildTypeChip(
      String typeKey,
      String label,
      IconData icon,
      String currentType,
      ValueChanged<String> onSelected,
      bool isDark,
      AppAccentPreset accent,
      ) {
    final isSelected = currentType == typeKey;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelected(typeKey);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? accent.primary : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? accent.primary : (isDark ? AppTokens.darkText : AppTokens.lightText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // CARD RENDERER DÀNH CHO TỪNG VÍ (VỚI CỬ CHỈ VUỐT SLIDABLE 2 HƯỚNG)
  // ============================================================================
  Widget _buildWalletCard(Wallet wallet, bool isDark, AppAccentPreset accent) {
    final isCredit = wallet.type.toLowerCase() == 'credit';
    final isNegative = wallet.balance < 0;
    final absBalance = wallet.balance.abs();
    final creditLimit = wallet.creditLimit ?? 0.0;
    final availableCredit = creditLimit > 0 ? math.max(0.0, creditLimit - absBalance) : 0.0;

    return Dismissible(
      key: ValueKey('wallet_${wallet.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Vuốt sang phải: Sửa ví
          HapticFeedback.selectionClick();
          _showCreateOrEditWalletModal(context, existingWallet: wallet, isDark: isDark, accent: accent);
          return false;
        } else {
          // Vuốt sang trái: Kiểm kê số dư
          HapticFeedback.selectionClick();
          _showBalanceAuditDialog(context, wallet, isDark, accent);
          return false;
        }
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: accent.primary.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.edit_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('Chỉnh sửa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Kiểm kê số dư', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.scale_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTokens.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: wallet.isDefault
                ? accent.primary.withValues(alpha: 0.6)
                : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
            width: wallet.isDefault ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _parseColor(wallet.color).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      AppIcons.resolve(wallet.icon),
                      size: 22,
                      color: _parseColor(wallet.color),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              wallet.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (wallet.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: accent.primary.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Mặc định',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: accent.primary,
                                ),
                              ),
                            ),
                          ],
                          if (wallet.isExcludedFromTotal) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Ẩn khỏi tổng',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getWalletTypeName(wallet.type),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    CurrencyText(
                      _formatCurrency(wallet.balance),
                      isVisible: _isBalanceVisible,
                      style: currencyTextStyle(context, TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isNegative
                            ? AppTokens.expense
                            : (isDark ? AppTokens.darkText : AppTokens.lightText),
                      )),
                    ),
                    if (isCredit && creditLimit > 0)
                      CurrencyText(
                        'Hạn mức: ${_formatCurrency(creditLimit)}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                        ),
                      ),
                  ],
                ),

                // Quick Menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                  ),
                  onSelected: (action) async {
                    final db = ref.read(databaseProvider);
                    if (action == 'default') {
                      await db.setWalletAsDefault(wallet.id);
                    } else if (action == 'audit') {
                      _showBalanceAuditDialog(context, wallet, isDark, accent);
                    } else if (action == 'edit') {
                      _showCreateOrEditWalletModal(context, existingWallet: wallet, isDark: isDark, accent: accent);
                    } else if (action == 'delete') {
                      _showDeleteOrArchiveDialog(context, wallet, isDark);
                    } else if (action == 'unarchive') {
                      await db.unarchiveWallet(wallet.id);
                    }
                  },
                  itemBuilder: (context) => [
                    if (!wallet.isDefault && !wallet.isArchived)
                      const PopupMenuItem(
                        value: 'default',
                        child: Row(
                          children: [
                            Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                            SizedBox(width: 8),
                            Text('Đặt làm mặc định'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'audit',
                      child: Row(
                        children: [
                          Icon(Icons.scale_rounded, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text('Kiểm kê số dư'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('Chỉnh sửa'),
                        ],
                      ),
                    ),
                    if (wallet.isArchived)
                      const PopupMenuItem(
                        value: 'unarchive',
                        child: Row(
                          children: [
                            Icon(Icons.unarchive_rounded, color: Colors.purple, size: 18),
                            SizedBox(width: 8),
                            Text('Khôi phục ví'),
                          ],
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: AppTokens.expense, size: 18),
                            SizedBox(width: 8),
                            Text('Lưu trữ / Xóa'),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // NẾU LÀ THẺ TÍN DỤNG: DÒNG THÔNG SỐ VÀ NÚT THANH TOÁN NHANH DƯ NỢ
            if (isCredit) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CurrencyText(
                          'Khả dụng: ${_formatCurrency(availableCredit)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                        Text(
                          'Sao kê ngày ${wallet.statementDay ?? '--'} • Hạn trả ngày ${wallet.paymentDueDay ?? '--'}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                          ),
                        ),
                      ],
                    ),
                    if (wallet.balance < 0)
                      InkWell(
                        onTap: () {
                          InternalTransferSheet.show(
                            context,
                            initialToWalletId: wallet.id,
                            initialAmount: wallet.balance.abs(),
                            initialNote: 'Thanh toán dư nợ thẻ ${wallet.name}',
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTokens.expense.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTokens.expense.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Text(
                                'Thanh toán nợ ❯',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTokens.expense,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final walletsAsync = ref.watch(allWalletsWithArchivedStreamProvider);

    return AppFeedbackDismissRegion(
      child: Scaffold(
        backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
        body: SafeArea(
          child: walletsAsync.when(
            data: (wallets) {
              final activeWallets = wallets.where((w) => !w.isArchived).toList();
              final archivedWallets = wallets.where((w) => w.isArchived).toList();

              // Tính tổng tài sản thực tế: Tổng số dư dương - Tổng dư nợ âm
              double positiveAssets = 0.0;
              double creditDebt = 0.0;
              double availableSpending = 0.0;
              double excludedOrFrozen = 0.0;
              int availableCount = 0;
              int excludedCount = 0;

              for (final w in activeWallets) {
                if (w.type == 'credit' && w.balance < 0) {
                  creditDebt += w.balance.abs();
                } else if (w.balance > 0) {
                  positiveAssets += w.balance;
                }

                if (w.isExcludedFromTotal || w.type == 'savings') {
                  excludedOrFrozen += w.balance;
                  excludedCount++;
                } else {
                  availableSpending += w.balance;
                  availableCount++;
                }
              }

              final netRealAssets = positiveAssets - creditDebt;

              // Phân nhóm
              final cashAndPayWallets = activeWallets
                  .where((w) => ['cash', 'bank', 'ewallet'].contains(w.type.toLowerCase()) && !w.isExcludedFromTotal)
                  .toList();

              final savingsAndPrivateWallets = activeWallets
                  .where((w) => w.type.toLowerCase() == 'savings' || w.isExcludedFromTotal)
                  .toList();

              final creditWallets = activeWallets
                  .where((w) => w.type.toLowerCase() == 'credit')
                  .toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ==============================================================
                  // TOP HEADER: CO GIÃN THEO MÀN HÌNH, NÚT [+] KHÔNG TRÀN MÉP
                  // ==============================================================
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          // Nút Back
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                          const SizedBox(width: 4),

                          // Tiêu đề co giãn tự động theo kích thước màn hình
                          Expanded(
                            child: Text(
                              'Quản Lý Nguồn Tiền',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Cụm hành động bên phải
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Nút Chuyển Tiền CTA gọn gàng
                              InkWell(
                                onTap: () => InternalTransferSheet.show(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: accent.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: accent.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.sync_alt_rounded, size: 15, color: accent.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Chuyển tiền',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: accent.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Nút Tròn (+) Tạo Ví Mới chuẩn 36x36 cố định
                              InkWell(
                                onTap: () => _showCreateOrEditWalletModal(
                                  context,
                                  isDark: isDark,
                                  accent: accent,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: accent.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.primary.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ==============================================================
                  // THẺ TỔNG QUAN TÀI SẢN THỰC TẾ (NET WEALTH CARD)
                  // ==============================================================
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                : [accent.primary, accent.primary.withValues(alpha: 0.85)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: accent.primary.withValues(alpha: isDark ? 0.16 : 0.28),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'TỔNG TÀI SẢN THỰC TẾ (NET ASSETS)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: isDark ? AppTokens.darkMuted : Colors.white70,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _isBalanceVisible = !_isBalanceVisible);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      _isBalanceVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            CurrencyText(
                              _formatCurrency(netRealAssets),
                      isVisible: _isBalanceVisible,
                              style: currencyTextStyle(context, const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              )),
                            ),
                            const SizedBox(height: 14),

                            // 2 Dòng bóc tách: Khả dụng vs Đang ẩn/khóa
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Khả dụng tiêu xài ($availableCount ví):',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppTokens.darkMuted : Colors.white70,
                                        ),
                                      ),
                                      CurrencyText(
                                        _formatCurrency(availableSpending),
                      isVisible: _isBalanceVisible,
                                        style: currencyTextStyle(context, const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF34D399),
                                        )),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Đang ẩn / Khóa / Tiết kiệm ($excludedCount ví):',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppTokens.darkMuted : Colors.white70,
                                        ),
                                      ),
                                      CurrencyText(
                                        _formatCurrency(excludedOrFrozen),
                      isVisible: _isBalanceVisible,
                                        style: currencyTextStyle(context, const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        )),
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
                  ),

                  // ==============================================================
                  // NHÓM 1: TIỀN MẶT & TÀI KHOẢN THANH TOÁN
                  // ==============================================================
                  if (cashAndPayWallets.isNotEmpty) ...[
                    _buildSectionHeader(
                      'TIỀN MẶT & THANH TOÁN',
                      '${cashAndPayWallets.length} ví',
                      isDark,
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, i) => _buildWalletCard(cashAndPayWallets[i], isDark, accent),
                          childCount: cashAndPayWallets.length,
                        ),
                      ),
                    ),
                  ],

                  // ==============================================================
                  // NHÓM 2: TÀI KHOẢN TIẾT KIỆM & TÀI SẢN RIÊNG
                  // ==============================================================
                  if (savingsAndPrivateWallets.isNotEmpty) ...[
                    _buildSectionHeader(
                      'TIẾT KIỆM & TÀI SẢN RIÊNG',
                      '${savingsAndPrivateWallets.length} nguồn',
                      isDark,
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, i) => _buildWalletCard(savingsAndPrivateWallets[i], isDark, accent),
                          childCount: savingsAndPrivateWallets.length,
                        ),
                      ),
                    ),
                  ],

                  // ==============================================================
                  // NHÓM 3: THẺ TÍN DỤNG & DƯ NỢ
                  // ==============================================================
                  if (creditWallets.isNotEmpty) ...[
                    _buildSectionHeader(
                      'THẺ TÍN DỤNG & DƯ NỢ',
                      '${creditWallets.length} thẻ',
                      isDark,
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, i) => _buildWalletCard(creditWallets[i], isDark, accent),
                          childCount: creditWallets.length,
                        ),
                      ),
                    ),
                  ],

                  // ==============================================================
                  // NHÓM 4: VÍ ĐÃ LƯU TRỮ (NẾU CÓ)
                  // ==============================================================
                  if (archivedWallets.isNotEmpty) ...[
                    _buildSectionHeader(
                      'VÍ ĐÃ LƯU TRỮ (ẨN)',
                      '${archivedWallets.length} ví',
                      isDark,
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, i) => _buildWalletCard(archivedWallets[i], isDark, accent),
                          childCount: archivedWallets.length,
                        ),
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(child: Text('Lỗi tải danh sách ví: $e')),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String countText, bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      sliver: SliverToBoxAdapter(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
              ),
            ),
            Text(
              countText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
