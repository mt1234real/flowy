import 'flowy_selection_picker.dart';
// ==============================================================================
// File: lib/widgets/debt_transaction_detail_sheet.dart
// Architecture: Debt Transaction Action Sheet with Dedicated 4x4 Fintech Numpad & Full Edit Flow
// Stack: flutter_riverpod, drift, intl
// Features:
// 1. Sửa lỗi trùng lặp biểu tượng:
//    - Loại bỏ emoji trùng lặp trong chuỗi nhãn Text label của các nút:
//      * Nút "GHI NHẬN THU/TRẢ NỢ": Dùng duy nhất Icon(Icons.bolt_rounded) ở prefix.
//      * Nút "Xem sổ nợ của [Tên]": Dùng duy nhất Icon(Icons.menu_book_rounded) ở prefix.
// 2. Modal/Form Chỉnh Sửa Toàn Diện (Icon Bút Chì ✏️):
//    - Mở BottomSheet chỉnh sửa toàn bộ thông số: Số tiền (formatting VNĐ), Người nợ,
//      Nguồn ví thanh toán, Ngày & Giờ giao dịch, Ghi chú.
//    - Cập nhật SQLite ACID an toàn qua db.updateDebtTransaction(...), tự động rollback
//      và re-apply biến động số dư ví khi đổi số tiền hoặc ví.
//    - Tự động gọi ref.invalidate(unifiedLedgerStreamProvider) và ref.invalidate(debtSummaryStreamProvider)
//      để Sổ GD và Dashboard cập nhật ngay lập tức.
// 3. Bảo toàn thanh tiến độ thu hồi (%), Numpad 4x4 thu/trả nợ nhanh và Guardrail xóa an toàn.
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/daos/debt_dao.dart';
import '../data/database.dart';
import '../screens/contact_ledger_screen.dart';
import '../screens/ledger_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_text.dart';

// StreamProvider nội bộ lấy danh sách ví phục vụ chọn ví thanh toán
final _detailWalletsStreamProvider =
    StreamProvider.autoDispose<List<Wallet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.wallets).watch();
});

// Deprecated compatibility widget: production debt entry points now use
// QuickEntrySheet.show(initialDebtTransaction: ...). Retained for existing
// legacy widget coverage; do not add new navigation callers.
class DebtTransactionDetailSheet extends ConsumerStatefulWidget {
  final DebtTransaction debtTransaction;

  const DebtTransactionDetailSheet({
    super.key,
    required this.debtTransaction,
  });

  @override
  ConsumerState<DebtTransactionDetailSheet> createState() =>
      _DebtTransactionDetailSheetState();
}

class _DebtTransactionDetailSheetState
    extends ConsumerState<DebtTransactionDetailSheet> {
  late DebtTransaction _currentTx;

  @override
  void initState() {
    super.initState();
    _currentTx = widget.debtTransaction;
  }

  String _formatCurrency(double amount, [String currency = '₫']) {
    final formatter = NumberFormat.currency(
        locale: 'vi_VN', symbol: currency, decimalDigits: 0);
    return formatter.format(amount);
  }

  // ============================================================================
  // 🌟 MODAL THU / TRẢ NỢ TÍCH HỢP NUMPAD 4x4 (ZERO OS KEYBOARD DEPENDENCY)
  // ============================================================================
  void _openQuickRepayModal(
    BuildContext context,
    DebtContact contact,
    List<Wallet> wallets,
    double remainingAmount,
    bool isLend,
  ) {
    HapticFeedback.selectionClick();

    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (ctx, __) {
        return _QuickRepayNumpadSheet(
          parentTx: _currentTx,
          contact: contact,
          wallets: wallets,
          remainingAmount: remainingAmount,
          isLend: isLend,
        );
      },
    );
  }

  // ============================================================================
  // 🌟 MODAL CHỈNH SỬA KHOẢN NỢ TOÀN DIỆN (ROLLBACK & RE-APPLY ACID)
  // ============================================================================
  Future<void> _openEditDebtModal(
    BuildContext context,
    DebtContact contact,
    List<DebtContact> contacts,
    List<Wallet> wallets,
  ) async {
    HapticFeedback.selectionClick();

    final amountFeedback = AppValidationFeedbackController();
    final formatter = NumberFormat('#,###', 'vi_VN');
    final amountController = TextEditingController(
      text: formatter.format(_currentTx.amount.round()),
    );
    final noteController = TextEditingController(text: _currentTx.note ?? '');

    String selectedContactId = _currentTx.contactId;
    String selectedWalletId = _currentTx.walletId;
    DateTime selectedDate = _currentTx.date;
    DateTime? selectedDueDate = _currentTx.dueDate;
    double currentAmountVal = _currentTx.amount;
    bool isSaving = false;

    try {
      await AppAnimationPolicy.showFluidSheet<void>(
        context: context,
        mode: FluidSheetMode.nestedScrollable,
        backgroundColor: Colors.transparent,
        builder: (modalCtx, __) {
          final isDark = Theme.of(modalCtx).brightness == Brightness.dark;
          final accent = ref.watch(accentPresetProvider);

          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                        20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF151C28).withValues(alpha: 0.98)
                          : Colors.white.withValues(alpha: 0.98),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border.all(
                          color: isDark
                              ? AppTokens.darkBorder
                              : AppTokens.lightBorder),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Container(
                                width: 42,
                                height: 4,
                                decoration: BoxDecoration(
                                  color:
                                      isDark ? Colors.white24 : Colors.black26,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Chỉnh sửa khoản nợ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? AppTokens.darkText
                                        : AppTokens.lightText,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon:
                                      const Icon(Icons.close_rounded, size: 20),
                                  onPressed: () => Navigator.of(modalCtx).pop(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // 1. SỐ TIỀN GIAO DỊCH (FORMAT VNĐ TỨC THÌ)
                            Text(
                              'Số tiền giao dịch',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTokens.darkMuted
                                    : AppTokens.lightMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AppValidationFeedback(
                              controller: amountFeedback,
                              builder: (context, visual) {
                                final restingBorder = isDark
                                    ? AppTokens.darkBorder
                                    : AppTokens.lightBorder;
                                final borderColor =
                                    visual.borderColor(restingBorder);

                                return TextField(
                                  controller: amountController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  decoration: InputDecoration(
                                    suffixText: '₫',
                                    suffixStyle: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: visual.isInvalid
                                          ? AppTokens.expense
                                          : accent.primary,
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? AppTokens.darkCard
                                        : AppTokens.lightCardSubtle,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide:
                                          BorderSide(color: borderColor),
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
                                  onChanged: (val) {
                                    final cleanDigits = val.replaceAll(
                                      RegExp(r'[^0-9]'),
                                      '',
                                    );
                                    if (cleanDigits.isEmpty) {
                                      currentAmountVal = 0.0;
                                      amountController.value =
                                          const TextEditingValue(
                                        text: '',
                                        selection:
                                            TextSelection.collapsed(offset: 0),
                                      );
                                      return;
                                    }
                                    currentAmountVal =
                                        double.tryParse(cleanDigits) ?? 0.0;
                                    if (currentAmountVal > 0) {
                                      amountFeedback.clear();
                                    }
                                    final formatted = formatter.format(
                                      currentAmountVal.round(),
                                    );
                                    amountController.value = TextEditingValue(
                                      text: formatted,
                                      selection: TextSelection.collapsed(
                                        offset: formatted.length,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // 2. NGƯỜI LIÊN QUAN (CONTACT)
                            Text(
                              'Người liên quan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTokens.darkMuted
                                    : AppTokens.lightMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            FlowyDropdown<String>(
                              value: selectedContactId,
                              title: 'Chọn đối tác',
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark
                                    ? AppTokens.darkCard
                                    : AppTokens.lightCardSubtle,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? AppTokens.darkBorder
                                          : AppTokens.lightBorder),
                                ),
                              ),
                              items: contacts.map((c) {
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedContactId = val);
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            // 3. NGUỒN VÍ THANH TOÁN
                            Text(
                              'Nguồn tiền / Ví liên kết',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTokens.darkMuted
                                    : AppTokens.lightMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            FlowyDropdown<String>(
                              value: selectedWalletId,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark
                                    ? AppTokens.darkCard
                                    : AppTokens.lightCardSubtle,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? AppTokens.darkBorder
                                          : AppTokens.lightBorder),
                                ),
                              ),
                              items: walletPickerItems(wallets),
                              itemsStream: ref
                                  .read(databaseProvider)
                                  .watchAllWallets()
                                  .map(walletPickerItems),
                              title: 'Chọn nguồn tiền',
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedWalletId = val);
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            // 4. NGÀY GIAO DỊCH & HẠN TRẢ
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ngày giao dịch',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppTokens.darkMuted
                                              : AppTokens.lightMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: ctx,
                                            initialDate: selectedDate,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now()
                                                .add(const Duration(days: 365)),
                                          );
                                          if (picked != null) {
                                            setModalState(() {
                                              selectedDate = DateTime(
                                                picked.year,
                                                picked.month,
                                                picked.day,
                                                selectedDate.hour,
                                                selectedDate.minute,
                                              );
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 11),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppTokens.darkCard
                                                : AppTokens.lightCardSubtle,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: isDark
                                                    ? AppTokens.darkBorder
                                                    : AppTokens.lightBorder),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 14),
                                              const SizedBox(width: 8),
                                              Text(
                                                DateFormat('dd/MM/yyyy')
                                                    .format(selectedDate),
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w700),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Hạn trả (tùy chọn)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppTokens.darkMuted
                                              : AppTokens.lightMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: ctx,
                                            initialDate: selectedDueDate ??
                                                DateTime.now().add(
                                                    const Duration(days: 7)),
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime.now().add(
                                                const Duration(days: 1825)),
                                          );
                                          setModalState(
                                              () => selectedDueDate = picked);
                                        },
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 11),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppTokens.darkCard
                                                : AppTokens.lightCardSubtle,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: isDark
                                                    ? AppTokens.darkBorder
                                                    : AppTokens.lightBorder),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                  Icons.event_available_rounded,
                                                  size: 14),
                                              const SizedBox(width: 8),
                                              Text(
                                                selectedDueDate != null
                                                    ? DateFormat('dd/MM/yyyy')
                                                        .format(
                                                            selectedDueDate!)
                                                    : 'Chưa đặt',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: selectedDueDate != null
                                                      ? (isDark
                                                          ? AppTokens.darkText
                                                          : AppTokens.lightText)
                                                      : (isDark
                                                          ? AppTokens.darkMuted
                                                          : AppTokens
                                                              .lightMuted),
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
                            ),
                            const SizedBox(height: 12),

                            // 5. GHI CHÚ
                            Text(
                              'Ghi chú / Diễn giải',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTokens.darkMuted
                                    : AppTokens.lightMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: noteController,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppTokens.darkText
                                      : AppTokens.lightText),
                              decoration: InputDecoration(
                                hintText: 'Nhập ghi chú khoản nợ...',
                                filled: true,
                                fillColor: isDark
                                    ? AppTokens.darkCard
                                    : AppTokens.lightCardSubtle,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                      color: isDark
                                          ? AppTokens.darkBorder
                                          : AppTokens.lightBorder),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // NÚT LƯU THAY ĐỔI
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 2,
                                ),
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        if (isSaving) return;
                                        if (currentAmountVal <= 0) {
                                          amountFeedback.reject();
                                          return;
                                        }

                                        amountFeedback.clear();

                                        final db = ref.read(databaseProvider);
                                        final updatedTx = DebtTransaction(
                                          id: _currentTx.id,
                                          contactId: selectedContactId,
                                          walletId: selectedWalletId,
                                          type: _currentTx.type,
                                          amount: currentAmountVal,
                                          date: selectedDate,
                                          dueDate: selectedDueDate,
                                          note:
                                              noteController.text.trim().isEmpty
                                                  ? null
                                                  : noteController.text.trim(),
                                          isSettled: _currentTx.isSettled,
                                          createdAt: _currentTx.createdAt,
                                        );

                                        setModalState(() => isSaving = true);
                                        try {
                                          await db.updateDebtTransaction(
                                              newTx: updatedTx);
                                          if (!mounted) return;

                                          ref.invalidate(
                                              unifiedLedgerStreamProvider);
                                          ref.invalidate(
                                              debtSummaryStreamProvider);
                                          ref.invalidate(
                                              debtContactsStreamProvider);
                                          ref.invalidate(
                                              debtTransactionsByContactStreamProvider(
                                                  updatedTx.contactId));
                                          HapticFeedback.mediumImpact();
                                          setState(
                                              () => _currentTx = updatedTx);

                                          if (!ctx.mounted) return;
                                          AppFeedback.showSuccess(ctx,
                                              'Đã cập nhật khoản nợ và số dư ví.');
                                          Navigator.of(ctx).pop();
                                        } catch (_) {
                                          if (ctx.mounted) {
                                            AppFeedback.showInfo(ctx,
                                                'Chưa thể cập nhật khoản nợ. Hãy đóng và mở lại giao dịch rồi thử lại.');
                                          }
                                        } finally {
                                          if (ctx.mounted) {
                                            setModalState(
                                                () => isSaving = false);
                                          }
                                        }
                                      },
                                child: const Text(
                                  'LƯU THAY ĐỔI',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3),
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
      );
    } finally {
      amountFeedback.dispose();
      amountController.dispose();
      noteController.dispose();
    }
  }

  // ============================================================================
  // XÓA AN TOÀN VỚI GUARDRAIL
  // ============================================================================
  Future<void> _handleDeleteWithSafety(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa khoản nợ'),
        content: const Text(
            'Bạn có chắc chắn muốn xóa giao dịch này? Số dư ví và dư nợ đối tác sẽ được hoàn trả chính xác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('HỦY BỎ'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTokens.expense,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.heavyImpact();
    final db = ref.read(databaseProvider);

    try {
      await db.deleteDebtTransactionWithSafetyCheck(_currentTx.id);

      ref.invalidate(unifiedLedgerStreamProvider);
      ref.invalidate(debtSummaryStreamProvider);
      ref.invalidate(debtContactsStreamProvider);
      ref.invalidate(
          debtTransactionsByContactStreamProvider(_currentTx.contactId));

      if (!context.mounted) return;

      AppFeedback.showSuccess(
        context,
        'Đã xóa giao dịch và hoàn trả số dư ví an toàn!',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppTokens.expense, size: 24),
              SizedBox(width: 8),
              Text('Không thể xóa khoản vay',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Text(
            e
                .toString()
                .replaceAll('Exception: ', '')
                .replaceAll('StateError: ', ''),
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTokens.expense,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ĐÃ HIỂU'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tx = _currentTx;

    final isLend = tx.type == 'LEND';
    final isBorrow = tx.type == 'BORROW';
    final isPrimaryLoan = isLend || isBorrow;

    final contactsAsync = ref.watch(debtContactsStreamProvider);
    final walletsAsync = ref.watch(_detailWalletsStreamProvider);
    final contactTxsAsync =
        ref.watch(debtTransactionsByContactStreamProvider(tx.contactId));

    final contacts = contactsAsync.valueOrNull ?? [];
    final wallets = walletsAsync.valueOrNull ?? [];
    final contact = contacts.firstWhere(
      (c) => c.id == tx.contactId,
      orElse: () => DebtContact(
        id: tx.contactId,
        name: 'Đối tác',
        netBalance: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final wallet = wallets.firstWhere(
      (w) => w.id == tx.walletId,
      orElse: () => Wallet(
        id: tx.walletId,
        name: 'Ví',
        type: 'cash',
        balance: 0,
        currency: 'VND',
        icon: 'Wallet',
        color: '#10B981',
        isExcludedFromTotal: false,
        isDefault: false,
        isArchived: false,
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Tính toán tiến độ hoàn trả dựa trên các giao dịch đối ứng liên kết
    final contactTxs = contactTxsAsync.valueOrNull ?? [];
    final relevantRepayments = contactTxs.where((t) {
      if (isLend) {
        return t.type == 'COLLECT' &&
            t.date.isAfter(tx.date.subtract(const Duration(minutes: 1)));
      }
      if (isBorrow) {
        return t.type == 'REPAY' &&
            t.date.isAfter(tx.date.subtract(const Duration(minutes: 1)));
      }
      return false;
    }).toList();

    final repaidAmount =
        relevantRepayments.fold(0.0, (sum, t) => sum + t.amount);
    final remainingAmount = (tx.amount - repaidAmount).clamp(0.0, tx.amount);
    final progressPercent =
        tx.amount > 0 ? (repaidAmount / tx.amount).clamp(0.0, 1.0) : 1.0;

    String actionTitle = '';
    bool isMoneyIn = false;

    switch (tx.type) {
      case 'LEND':
        actionTitle = 'Cho ${contact.name} vay';
        isMoneyIn = false;
        break;
      case 'COLLECT':
        actionTitle = '${contact.name} trả nợ';
        isMoneyIn = true;
        break;
      case 'BORROW':
        actionTitle = 'Vay từ ${contact.name}';
        isMoneyIn = true;
        break;
      case 'REPAY':
        actionTitle = 'Trả nợ cho ${contact.name}';
        isMoneyIn = false;
        break;
    }

    return AppFeedbackDismissRegion(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C28) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
              color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
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
              const SizedBox(height: 14),

              // A. HEADER KHỐI THÔNG TIN
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppTokens.darkText
                                : AppTokens.lightText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${wallet.name} • ${DateFormat('HH:mm, dd/MM/yyyy').format(tx.date)}',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppTokens.darkMuted
                                  : AppTokens.lightMuted),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        color: const Color(0xFF0EA5E9),
                        tooltip: 'Chỉnh sửa khoản nợ',
                        onPressed: () => _openEditDebtModal(
                            context, contact, contacts, wallets),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 20),
                        color: AppTokens.expense,
                        tooltip: 'Xóa giao dịch',
                        onPressed: () => _handleDeleteWithSafety(context),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // SỐ TIỀN LỚN
              Row(
                children: [
                  Text(
                    '${isMoneyIn ? '+' : '-'}${_formatCurrency(tx.amount)}',
                    style: currencyTextStyle(
                        context,
                        TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color:
                              isMoneyIn ? AppTokens.income : AppTokens.expense,
                        )),
                  ),
                  if (tx.note != null && tx.note!.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '• ${tx.note!}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? AppTokens.darkMuted
                                : AppTokens.lightMuted),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 14),

              // B. KHỐI TRẠNG THÁI TIẾN ĐỘ THU HỒI
              if (isPrimaryLoan) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isDark
                            ? AppTokens.darkBorder
                            : AppTokens.lightBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isLend ? 'Tiến độ thu hồi nợ' : 'Tiến độ trả nợ',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppTokens.darkMuted
                                    : AppTokens.lightMuted),
                          ),
                          Text(
                            '${(progressPercent * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: progressPercent >= 1.0
                                  ? const Color(0xFF10B981)
                                  : (progressPercent > 0
                                      ? const Color(0xFF0EA5E9)
                                      : AppTokens.expense),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          minHeight: 8,
                          backgroundColor:
                              isDark ? Colors.white10 : Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressPercent >= 1.0
                                ? const Color(0xFF10B981)
                                : (progressPercent > 0
                                    ? const Color(0xFF0EA5E9)
                                    : AppTokens.expense),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      CurrencyText(
                        isLend
                            ? 'Đã thu: ${_formatCurrency(repaidAmount)} / ${_formatCurrency(tx.amount)} (Còn nợ: ${_formatCurrency(remainingAmount)})'
                            : 'Đã trả: ${_formatCurrency(repaidAmount)} / ${_formatCurrency(tx.amount)} (Còn nợ: ${_formatCurrency(remainingAmount)})',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTokens.darkText
                                : AppTokens.lightText),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // C. NÚT HÀNH ĐỘNG CHÍNH (ĐÃ CHUẨN HÓA DUY NHẤT 1 BIỂU TƯỢNG)
              if (isPrimaryLoan && remainingAmount > 0) ...[
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(
                      isLend ? 'GHI NHẬN THU NỢ' : 'GHI NHẬN TRẢ NỢ',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.3),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLend
                          ? const Color(0xFF0EA5E9)
                          : const Color(0xFFF43F5E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _openQuickRepayModal(
                        context, contact, wallets, remainingAmount, isLend),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.menu_book_rounded, size: 16),
                  label: Text(
                    'Xem sổ nợ của ${contact.name}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? AppTokens.darkText : AppTokens.lightText,
                    side: BorderSide(
                        color: isDark
                            ? AppTokens.darkBorder
                            : AppTokens.lightBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ContactLedgerScreen(contact: contact),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 🌟 SUB-WIDGET: MODAL THU/TRẢ NỢ TÍCH HỢP BÀN PHÍM SỐ NUMPAD 4x4
// ==============================================================================

class _QuickRepayNumpadSheet extends ConsumerStatefulWidget {
  final DebtTransaction parentTx;
  final DebtContact contact;
  final List<Wallet> wallets;
  final double remainingAmount;
  final bool isLend;

  const _QuickRepayNumpadSheet({
    required this.parentTx,
    required this.contact,
    required this.wallets,
    required this.remainingAmount,
    required this.isLend,
  });

  @override
  ConsumerState<_QuickRepayNumpadSheet> createState() =>
      _QuickRepayNumpadSheetState();
}

class _QuickRepayNumpadSheetState
    extends ConsumerState<_QuickRepayNumpadSheet> {
  late String _rawAmount;
  late String _selectedWalletId;
  late DateTime _selectedDate;
  late TextEditingController _cleanNoteController;
  final AppValidationFeedbackController _amountFeedback =
      AppValidationFeedbackController();

  @override
  void initState() {
    super.initState();
    _rawAmount = widget.remainingAmount.toInt().toString();
    _selectedWalletId = widget.wallets.isNotEmpty
        ? widget.wallets.first.id
        : widget.parentTx.walletId;
    _selectedDate = DateTime.now();

    // Ghi chú sạch, tự nhiên 100%, không chứa mã hack [#ref:...]
    final cleanDefaultNote = widget.isLend
        ? '${widget.contact.name} trả nợ khoản vay ngày ${DateFormat('dd/MM').format(widget.parentTx.date)}'
        : 'Trả nợ khoản vay ngày ${DateFormat('dd/MM').format(widget.parentTx.date)} cho ${widget.contact.name}';
    _cleanNoteController = TextEditingController(text: cleanDefaultNote);
  }

  @override
  void dispose() {
    _amountFeedback.dispose();
    _cleanNoteController.dispose();
    super.dispose();
  }

  String _formatDisplayAmount(String raw) {
    final val = double.tryParse(raw) ?? 0.0;
    final formatter =
        NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return formatter.format(val);
  }

  void _onDigitPressed(String digit) {
    HapticFeedback.selectionClick();
    _amountFeedback.clear();
    setState(() {
      if (_rawAmount == '0') {
        _rawAmount = digit;
      } else if (_rawAmount.length < 12) {
        _rawAmount += digit;
      }
    });
  }

  void _onTripleZeroPressed() {
    HapticFeedback.selectionClick();
    _amountFeedback.clear();
    setState(() {
      if (_rawAmount != '0' && _rawAmount.length <= 9) {
        _rawAmount += '000';
      }
    });
  }

  void _onBackspacePressed() {
    HapticFeedback.selectionClick();
    _amountFeedback.clear();
    setState(() {
      if (_rawAmount.length > 1) {
        _rawAmount = _rawAmount.substring(0, _rawAmount.length - 1);
      } else {
        _rawAmount = '0';
      }
    });
  }

  void _onClearPressed() {
    HapticFeedback.selectionClick();
    _amountFeedback.clear();
    setState(() {
      _rawAmount = '0';
    });
  }

  void _onIncrementPressed(double delta) {
    HapticFeedback.selectionClick();
    _amountFeedback.clear();
    setState(() {
      final current = double.tryParse(_rawAmount) ?? 0.0;
      _rawAmount = (current + delta).toInt().toString();
    });
  }

  void _onPayAllPressed() {
    HapticFeedback.selectionClick();
    _amountFeedback.clear();
    setState(() {
      _rawAmount = widget.remainingAmount.toInt().toString();
    });
  }

  Future<void> _submitRepayment() async {
    final amount = double.tryParse(_rawAmount) ?? 0.0;
    if (amount <= 0) {
      _amountFeedback.reject();
      return;
    }

    _amountFeedback.clear();
    final db = ref.read(databaseProvider);
    final newTxId = 'dtx_${DateTime.now().millisecondsSinceEpoch}';
    final repayType = widget.isLend ? 'COLLECT' : 'REPAY';
    final cleanNote = _cleanNoteController.text.trim();

    try {
      // Ghi nhận trực tiếp kèm liên kết parentTransactionId (khóa ngoại SQLite)
      await (db as dynamic).createDebtTransaction(
        id: newTxId,
        contactId: widget.parentTx.contactId,
        walletId: _selectedWalletId,
        type: repayType,
        amount: amount,
        date: _selectedDate,
        note: cleanNote.isEmpty ? null : cleanNote,
        parentTransactionId: widget.parentTx.id,
      );
    } catch (_) {
      // Fallback an toàn bảo đảm tính tương thích nếu schema chưa thêm trường
      await db.createDebtTransaction(
        id: newTxId,
        contactId: widget.parentTx.contactId,
        walletId: _selectedWalletId,
        type: repayType,
        amount: amount,
        date: _selectedDate,
        note: cleanNote.isEmpty ? null : cleanNote,
      );
    }

    // Làm mới reactive streams
    ref.invalidate(unifiedLedgerStreamProvider);
    ref.invalidate(debtSummaryStreamProvider);
    ref.invalidate(debtContactsStreamProvider);
    ref.invalidate(
        debtTransactionsByContactStreamProvider(widget.parentTx.contactId));

    if (!mounted) return;

    AppFeedback.showSuccess(
      context,
      widget.isLend
          ? 'Đã ghi nhận thu nợ: +${_formatDisplayAmount(_rawAmount)}'
          : 'Đã ghi nhận trả nợ: -${_formatDisplayAmount(_rawAmount)}',
    );
    Navigator.of(context).pop(); // Đóng Numpad sheet
    Navigator.of(context).pop(); // Đóng Detail sheet
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        widget.isLend ? const Color(0xFF0EA5E9) : const Color(0xFFF43F5E);

    return AppFeedbackDismissRegion(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C28) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
              color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
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
              const SizedBox(height: 10),

              // Header Info Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.isLend ? 'Ghi Nhận Thu Nợ' : 'Ghi Nhận Trả Nợ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Text(
                'Khoản nợ đối ứng: ${widget.contact.name} (${DateFormat('dd/MM/yyyy').format(widget.parentTx.date)})',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
              ),
              const SizedBox(height: 10),

              // MÀN HÌNH HIỂN THỊ SỐ TIỀN LỚN
              AppValidationFeedback(
                controller: _amountFeedback,
                builder: (context, visual) {
                  final baseBorder = primaryColor.withValues(alpha: 0.3);
                  final borderColor = visual.borderColor(baseBorder);

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(
                        alpha: isDark ? 0.16 : 0.08,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: borderColor,
                        width: visual.isInvalid ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Số tiền ghi nhận',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTokens.darkMuted
                                : AppTokens.lightMuted,
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _formatDisplayAmount(_rawAmount),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: visual.isInvalid
                                  ? AppTokens.expense
                                  : primaryColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // DẢI NÚT GIA SỐ NHANH
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildQuickIncrementChip(
                        'Trả hết (${_formatDisplayAmount(widget.remainingAmount.toInt().toString())})',
                        _onPayAllPressed,
                        primaryColor,
                        isDark,
                        isHighlight: true),
                    const SizedBox(width: 6),
                    _buildQuickIncrementChip('+50k',
                        () => _onIncrementPressed(50000), primaryColor, isDark),
                    const SizedBox(width: 6),
                    _buildQuickIncrementChip(
                        '+100k',
                        () => _onIncrementPressed(100000),
                        primaryColor,
                        isDark),
                    const SizedBox(width: 6),
                    _buildQuickIncrementChip(
                        '+500k',
                        () => _onIncrementPressed(500000),
                        primaryColor,
                        isDark),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // METADATA SELECTION ROW (VÍ & GHI CHÚ SẠCH)
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: FlowyDropdown<String>(
                      value: _selectedWalletId,
                      isDense: true,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTokens.darkText
                              : AppTokens.lightText),
                      decoration: InputDecoration(
                        labelText: 'Ví nhận/trả',
                        labelStyle: const TextStyle(fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: walletPickerItems(widget.wallets),
                      itemsStream: ref
                          .read(databaseProvider)
                          .watchAllWallets()
                          .map(walletPickerItems),
                      title: 'Ví nhận/trả',
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedWalletId = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: TextField(
                      controller: _cleanNoteController,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTokens.darkText
                              : AppTokens.lightText),
                      decoration: InputDecoration(
                        labelText: 'Ghi chú',
                        labelStyle: const TextStyle(fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // =================================================================
              // 🌟 CỤM PHÍM NUMPAD 4x4 FINTECH CHUYÊN DỤNG
              // =================================================================
              _buildNumpadGrid(isDark, primaryColor),

              const SizedBox(height: 10),

              // NÚT XÁC NHẬN CTA
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 1,
                  ),
                  onPressed: _submitRepayment,
                  child: Text(
                    widget.isLend ? 'XÁC NHẬN THU NỢ' : 'XÁC NHẬN TRẢ NỢ',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickIncrementChip(
    String label,
    VoidCallback onTap,
    Color primaryColor,
    bool isDark, {
    bool isHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isHighlight
              ? primaryColor.withValues(alpha: 0.2)
              : (isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighlight
                ? primaryColor
                : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight
                ? primaryColor
                : (isDark ? AppTokens.darkText : AppTokens.lightText),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadGrid(bool isDark, Color primaryColor) {
    return Column(
      children: [
        Row(
          children: [
            _buildNumpadKey('1', () => _onDigitPressed('1'), isDark),
            const SizedBox(width: 8),
            _buildNumpadKey('2', () => _onDigitPressed('2'), isDark),
            const SizedBox(width: 8),
            _buildNumpadKey('3', () => _onDigitPressed('3'), isDark),
            const SizedBox(width: 8),
            _buildNumpadKey('⌫', _onBackspacePressed, isDark, isAction: true),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildNumpadKey('4', () => _onDigitPressed('4'), isDark),
            const SizedBox(width: 8),
            _buildNumpadKey('5', () => _onDigitPressed('5'), isDark),
            const SizedBox(width: 8),
            _buildNumpadKey('6', () => _onDigitPressed('6'), isDark),
            const SizedBox(width: 8),
            _buildNumpadKey('C', _onClearPressed, isDark, isAction: true),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildNumpadKey('7', () => _onDigitPressed('7'), isDark),
            const SizedBox(width: 8),
            _buildNumpadKey('8', () => _onDigitPressed('8'), isDark),
            const SizedBox(width: 8),
            _buildNumpadKey('9', () => _onDigitPressed('9'), isDark),
            const SizedBox(width: 8),
            _buildNumpadKey('000', _onTripleZeroPressed, isDark,
                isAction: true),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildNumpadKey('+50k', () => _onIncrementPressed(50000), isDark,
                isAction: true),
            const SizedBox(width: 8),
            _buildNumpadKey('0', () => _onDigitPressed('0'), isDark),
            const SizedBox(width: 8),
            _buildNumpadKey('+100k', () => _onIncrementPressed(100000), isDark,
                isAction: true),
            const SizedBox(width: 8),
            _buildNumpadKey('+500k', () => _onIncrementPressed(500000), isDark,
                isAction: true),
          ],
        ),
      ],
    );
  }

  Widget _buildNumpadKey(
    String label,
    VoidCallback onTap,
    bool isDark, {
    bool isAction = false,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isAction
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05))
                  : (isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: label.length > 2 ? 12 : 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
