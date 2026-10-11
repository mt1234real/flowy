// ==============================================================================
// File: lib/screens/contact_ledger_screen.dart
// Architecture: Individual Counterparty Ledger with Preserved Sleek Dismissible & Soft-Delete Undo
// Stack: flutter_riverpod, drift, intl
// Features:
// 1. Chuyển Đổi Sang ConsumerStatefulWidget:
//    - Quản lý tập hợp _restoringDebtTxIds theo dõi các giao dịch nợ vừa nhấn HOÀN TÁC.
//    - Cung cấp getter tiện ích `DebtContact get contact => widget.contact;`.
// 2. Tích Hợp PreservedSleekDismissible (Thay thế hoàn toàn Flutter Dismissible cũ):
//    - Cử chỉ kéo 1:1 từ phải sang trái.
//    - Vượt 40% tự động kích hoạt rung mediumImpact và nảy icon thùng rác.
//    - Thả tay >=40%: Dòng trượt kịch mép (100ms) đồng thời fade đỏ và co chiều cao (200ms).
//    - Hoàn tất hoạt ảnh co chiều cao mới gọi _softDeleteDebtFromTimeline và hiển thị Dynamic Bottom Undo Dock.
// 3. Cơ Chế Hoàn Tác Mượt Mà (Smooth Undo Animation):
//    - Khi người dùng nhấn "HOÀN TÁC" trên Undo Dock, thêm tx.id vào _restoringDebtTxIds.
//    - PreservedSleekDismissible nhận animateIn == true, bung mượt mà từ height 0 -> full trong 180ms.
// 4. Bảo Toàn Toàn Vẹn 100% Tính Năng Sổ Nợ:
//    - Thẻ tổng quan nợ ròng thời gian thực (DebtContact live state).
//    - Hai nút thao tác nhanh: "Phát sinh" và "Tất toán" (mở QuickEntrySheet qua launcher tĩnh).
//    - Tấm thiệp nhắc nợ tinh tế (_DebtReminderModal) kèm sao chép vào Clipboard.
//    - Chạm vào dòng lịch sử để chỉnh sửa nợ trong QuickEntrySheet.
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
import '../theme/app_theme.dart';
import '../widgets/currency_text.dart';
import '../widgets/preserved_sleek_dismissible.dart';
import '../widgets/quick_entry_sheet.dart';

class ContactLedgerScreen extends ConsumerStatefulWidget {
  final DebtContact contact;

  const ContactLedgerScreen({
    super.key,
    required this.contact,
  });

  @override
  ConsumerState<ContactLedgerScreen> createState() => _ContactLedgerScreenState();
}

class _ContactLedgerScreenState extends ConsumerState<ContactLedgerScreen> {
  // Tập hợp theo dõi các giao dịch nợ đang được khôi phục khi nhấn Hoàn tác
  final Set<String> _restoringDebtTxIds = {};

  DebtContact get contact => widget.contact;

  String _formatCurrency(double amount, [String currency = '₫']) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: currency, decimalDigits: 0);
    return formatter.format(amount);
  }

  // Mở QuickEntrySheet với chế độ Thêm phát sinh cho người này qua static launcher
  void _openAddTransactionSheet(BuildContext context, DebtContact targetContact) {
    QuickEntrySheet.show(
      context,
      prefilledDebtContact: targetContact,
      prefilledDebtType: 'LEND',
    );
  }

  // Mở QuickEntrySheet với chế độ Tất toán toàn bộ số dư đối ứng qua static launcher
  void _openSettleAllSheet(BuildContext context, double currentNetBalance) {
    HapticFeedback.selectionClick();
    if (currentNetBalance.abs() <= 0.001) return;

    // Nếu họ nợ mình (netBalance > 0) -> Hành động tất toán là 'COLLECT' (Thu nợ)
    // Nếu mình nợ họ (netBalance < 0) -> Hành động tất toán là 'REPAY' (Trả nợ)
    final settleType = currentNetBalance > 0 ? 'COLLECT' : 'REPAY';
    final settleAmount = currentNetBalance.abs();

    QuickEntrySheet.show(
      context,
      prefilledDebtContact: contact,
      prefilledDebtType: settleType,
      prefilledAmount: settleAmount,
    );
  }

  // Mở Tấm Thiệp Nhắc Nợ Tinh Tế (Debt Reminder Modal)
  void _showDebtReminderDialog(
      BuildContext context,
      double currentNetBalance,
      List<DebtTransaction> txs,
      bool isDark,
      ) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => _DebtReminderModal(
        contact: contact,
        netBalance: currentNetBalance,
        transactions: txs.take(4).toList(),
        isDark: isDark,
      ),
    );
  }

  // Chỉnh sửa khoản nợ qua launcher dùng chung.
  void _openTransactionDetail(BuildContext context, DebtTransaction tx) {
    QuickEntrySheet.show(context, initialDebtTransaction: tx);
  }

  // 🌟 HÀM XÓA MỀM & HOÀN TÁC NGUYÊN TỬ CHO SỔ NỢ (GỌI SAU KHI DÒNG ĐÃ CO VỀ 0)
  Future<void> _softDeleteDebtFromTimeline(DebtTransaction tx) async {
    final db = ref.read(databaseProvider);

    // Callback này được gọi SAU KHI PreservedSleekDismissible đã co chiều cao về 0
    await db.softDeleteDebtTransaction(tx.id);

    ref.invalidate(debtTransactionsByContactStreamProvider(contact.id));
    ref.invalidate(debtContactsStreamProvider);
    ref.invalidate(debtSummaryStreamProvider);

    if (!mounted) return;

    AppFeedback.showUndo(
      context,
      message: 'Đã chuyển giao dịch nợ vào Thùng rác',
      actionColor: ref.read(accentPresetProvider).primary,
      onUndo: () async {
        // Đánh dấu để row mới xuất hiện chạy animation bung từ 0 -> full (180ms)
        if (mounted) {
          setState(() {
            _restoringDebtTxIds.add(tx.id);
          });
        }

        await db.restoreDebtTransaction(tx.id);

        ref.invalidate(debtTransactionsByContactStreamProvider(contact.id));
        ref.invalidate(debtContactsStreamProvider);
        ref.invalidate(debtSummaryStreamProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    // Watch live contact state để cập nhật số dư tức thì khi có thay đổi
    final contactsList = ref.watch(debtContactsStreamProvider).valueOrNull ?? [];
    final liveContact = contactsList.firstWhere(
          (c) => c.id == contact.id,
      orElse: () => contact,
    );

    final txsAsync = ref.watch(debtTransactionsByContactStreamProvider(contact.id));
    final walletsAsync = ref.watch(databaseProvider).watchAllWallets();

    return AppFeedbackDismissRegion(
      child: Scaffold(
        backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            liveContact.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 20),
              tooltip: 'Gửi thiệp nhắc nợ',
              onPressed: () {
                final txs = txsAsync.valueOrNull ?? [];
                _showDebtReminderDialog(context, liveContact.netBalance, txs, isDark);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: StreamBuilder<List<Wallet>>(
            stream: walletsAsync,
            builder: (context, walletSnap) {
              final walletsMap = {for (final w in walletSnap.data ?? []) w.id: w};

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // 1. Overview Net Card
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    sliver: SliverToBoxAdapter(
                      child: _buildContactOverviewCard(
                        context,
                        liveContact,
                        isDark,
                        accent,
                      ),
                    ),
                  ),

                  // 2. Timeline Section Title
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Lịch sử đối soát',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // 3. Timeline Transactions Stream
                  txsAsync.when(
                    data: (txs) {
                      if (txs.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 48,
                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Chưa có giao dịch vay nợ nào với ${liveContact.name}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final tx = txs[index];
                              final wallet = walletsMap[tx.walletId];
                              return _buildTimelineItem(context, tx, wallet, isDark);
                            },
                            childCount: txs.length,
                          ),
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                    error: (err, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Lỗi: $err', style: const TextStyle(color: AppTokens.expense)),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContactOverviewCard(
      BuildContext context,
      DebtContact contact,
      bool isDark,
      AppAccentPreset accent,
      ) {
    final hasDebt = contact.netBalance.abs() > 0.001;
    final isReceivable = contact.netBalance > 0;
    final statusColor = hasDebt
        ? (isReceivable ? const Color(0xFF10B981) : const Color(0xFFF43F5E))
        : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
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
          Text(
            hasDebt
                ? (isReceivable ? 'Người này đang nợ bạn' : 'Bạn đang nợ người này')
                : 'Trạng thái tài chính',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              hasDebt ? _formatCurrency(contact.netBalance.abs()) : '0 ₫ (Đã xong)',
              style: currencyTextStyle(context, TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: statusColor,
              )),
            ),
          ),
          const SizedBox(height: 16),

          // 2 Nút Thao Tác Nhanh
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _openAddTransactionSheet(context, contact),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Phát sinh',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent.primary,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: hasDebt ? () => _openSettleAllSheet(context, contact.netBalance) : null,
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text(
                      'Tất toán',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: hasDebt ? statusColor : Colors.grey,
                      side: BorderSide(
                        color: hasDebt
                            ? statusColor.withValues(alpha: 0.5)
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🌟 BỌC BẰNG PRESERVED SLEEK DISMISSIBLE THAY THẾ FLUTTER DISMISSIBLE CŨ
  Widget _buildTimelineItem(
      BuildContext context,
      DebtTransaction tx,
      Wallet? wallet,
      bool isDark,
      ) {
    String typeLabel = '';
    Color typeColor = Colors.grey;
    IconData typeIcon = Icons.swap_horiz_rounded;
    String sign = '';

    switch (tx.type) {
      case 'LEND':
        typeLabel = 'Cho vay';
        typeColor = const Color(0xFF10B981);
        typeIcon = Icons.arrow_outward_rounded;
        sign = '+';
        break;
      case 'COLLECT':
        typeLabel = 'Thu nợ';
        typeColor = const Color(0xFF0EA5E9);
        typeIcon = Icons.arrow_downward_rounded;
        sign = '-';
        break;
      case 'BORROW':
        typeLabel = 'Đi vay';
        typeColor = const Color(0xFFF59E0B);
        typeIcon = Icons.arrow_downward_rounded;
        sign = '-';
        break;
      case 'REPAY':
        typeLabel = 'Trả nợ';
        typeColor = const Color(0xFFF43F5E);
        typeIcon = Icons.arrow_upward_rounded;
        sign = '+';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: PreservedSleekDismissible(
        key: ValueKey('contact_debt_${tx.id}'),
        backgroundColor: AppTokens.expense,
        borderRadius: 16,
        animateIn: _restoringDebtTxIds.contains(tx.id),
        onInsertAnimationCompleted: () {
          if (!mounted) return;
          setState(() {
            _restoringDebtTxIds.remove(tx.id);
          });
        },
        onDismissed: () async {
          await _softDeleteDebtFromTimeline(tx);
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openTransactionDetail(context, tx),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTokens.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                              ),
                            ),
                            CurrencyText(
                              '$sign${_formatCurrency(tx.amount)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: typeColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${DateFormat('dd/MM/yyyy').format(tx.date)} •${wallet?.name ?? "Ví"}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                              ),
                            ),
                            if (tx.dueDate != null)
                              Text(
                                'Hạn: ${DateFormat('dd/MM').format(tx.dueDate!)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                                ),
                              ),
                          ],
                        ),
                        if (tx.note != null && tx.note!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            tx.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 🌟 MODAL TẤM THIỆP NHẮC NỢ TINH TẾ (_DebtReminderModal)
// ==============================================================================

class _DebtReminderModal extends StatelessWidget {
  final DebtContact contact;
  final double netBalance;
  final List<DebtTransaction> transactions;
  final bool isDark;

  const _DebtReminderModal({
    required this.contact,
    required this.netBalance,
    required this.transactions,
    required this.isDark,
  });

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount);
  }

  void _copyToClipboard(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('Chào ${contact.name}, mình gửi bạn đối soát khoản nợ nhỏ giữa chúng mình nhé:');
    if (netBalance > 0) {
      buffer.writeln('- Số tiền còn lại: ${_formatCurrency(netBalance)}');
    } else {
      buffer.writeln('- Mình đang nợ bạn: ${_formatCurrency(netBalance.abs())}');
    }
    if (transactions.isNotEmpty) {
      buffer.writeln('Các phát sinh gần nhất:');
      for (final t in transactions) {
        buffer.writeln(
          '  • ${DateFormat('dd/MM').format(t.date)}: ${_formatCurrency(t.amount)} (${t.note ?? t.type})',
        );
      }
    }
    buffer.writeln('Cảm ơn bạn nhiều nha!');

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    AppFeedback.showSuccess(
      context,
      'Đã sao chép nội dung tin nhắn nhắc nợ vào Clipboard!',
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151C28).withValues(alpha: 0.98) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Thiệp Biên Nhận Nhắc Nợ
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 32, color: Color(0xFF10B981)),
                      const SizedBox(height: 6),
                      Text(
                        'Biên Nhận Đối Soát',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      Text(
                        'Gửi tới: ${contact.name}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        netBalance > 0 ? _formatCurrency(netBalance) : _formatCurrency(netBalance.abs()),
                        style: currencyTextStyle(context, TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: netBalance > 0 ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                        )),
                      ),
                      Text(
                        netBalance > 0 ? 'Khoản nợ chưa thanh toán' : 'Khoản bạn sẽ nhận lại',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      Text(
                        '"Gửi bạn đối soát khoản nợ nhỏ giữa chúng mình nhé! Lúc nào tiện bạn gửi lại mình nha."',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Nút Sao chép
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _copyToClipboard(context),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text(
                      'Sao chép tin nhắn gửi Zalo / Messenger',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
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
