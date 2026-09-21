// ==============================================================================
// File: lib/screens/recycle_bin_screen.dart
// Architecture: Unified Recycle Bin (Standard Transactions + Debt Transactions)
// Stack: flutter, flutter_riverpod, intl, math, drift
// Features:
// 1. Wireframe chuẩn Dark OLED & Emerald Theme.
// 2. StreamProvider hợp nhất phản ứng thời gian thực:
//    - Lắng nghe cả transactions (soft-deleted) và debt_transactions (soft-deleted).
//    - Sắp xếp thứ tự xóa giảm dần theo deletedAt.
// 3. Phân biệt giao diện rõ ràng giữa 2 loại bản ghi:
//    - Giao dịch thường: Hiển thị CategoryIconBadge danh mục chi tiêu/thu nhập.
//    - Giao dịch vay nợ: Hiển thị DebtBadge màu sắc theo loại (LEND, COLLECT, BORROW, REPAY),
//      badge nhãn "Vay / Nợ" và tên đối tác nợ rõ ràng.
// 4. Thao tác xử lý đa hình (Polymorphic Actions):
//    - [ ↺ Khôi phục ]: Gọi restoreTransaction hoặc restoreDebtTransaction tương ứng.
//    - [ 🗑️ Xóa hẳn ]: Gọi permanentDeleteTransaction hoặc permanentDeleteDebtTransaction.
//    - [ Dọn sạch tất cả ]: Gọi emptyRecycleBin xóa sạch vĩnh viễn cả 2 bảng.
// 5. Header đếm ngược 30 ngày tự động xóa vĩnh viễn & Smart Empty State.
// ==============================================================================

import 'dart:math' as math;
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
import '../widgets/category_icon_badge.dart';

// --- DATA STRUCTURES ĐA HÌNH CHO THÙNG RÁC ---

enum RecycleBinItemType { standard, debt }

class UnifiedRecycleBinItem {
  final String id;
  final RecycleBinItemType itemType;
  final String title;
  final String subtitle;
  final double amount;
  final bool isMoneyIn;
  final DateTime date;
  final DateTime deletedAt;
  final int daysRemaining;

  // Dữ liệu gốc
  final Transaction? standardTx;
  final Category? category;
  final Wallet? wallet;

  final DebtTransaction? debtTx;
  final DebtContact? contact;
  final String? debtType;

  const UnifiedRecycleBinItem({
    required this.id,
    required this.itemType,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isMoneyIn,
    required this.date,
    required this.deletedAt,
    required this.daysRemaining,
    this.standardTx,
    this.category,
    this.wallet,
    this.debtTx,
    this.contact,
    this.debtType,
  });

  bool get isDebt => itemType == RecycleBinItemType.debt;
}

/// 🌟 STREAM PROVIDER HỢP NHẤT TOÀN BỘ MỤC ĐÃ XÓA MỀM (TRANSACTIONS + DEBTS)
final unifiedDeletedItemsStreamProvider =
StreamProvider.autoDispose<List<UnifiedRecycleBinItem>>((ref) {
  final db = ref.watch(databaseProvider);

  // 1. Luồng transactions đã xóa mềm
  final txQuery = db.select(db.transactions).join([
    leftOuterJoin(db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
    leftOuterJoin(db.wallets, db.wallets.id.equalsExp(db.transactions.walletId)),
  ])..where(db.transactions.deletedAt.isNotNull());

  // 2. Luồng debt_transactions đã xóa mềm
  final debtQuery = db.select(db.debtTransactions).join([
    leftOuterJoin(db.debtContacts, db.debtContacts.id.equalsExp(db.debtTransactions.contactId)),
    leftOuterJoin(db.wallets, db.wallets.id.equalsExp(db.debtTransactions.walletId)),
  ])..where(db.debtTransactions.deletedAt.isNotNull());

  return txQuery.watch().asyncMap((txRows) async {
    final debtRows = await debtQuery.get();
    final now = DateTime.now();
    final List<UnifiedRecycleBinItem> items = [];

    // Phân giải giao dịch thường
    for (final row in txRows) {
      final tx = row.readTable(db.transactions);
      final cat = row.readTableOrNull(db.categories);
      final w = row.readTableOrNull(db.wallets);

      final deletedTime = tx.deletedAt ?? now;
      final elapsedDays = now.difference(deletedTime).inDays;
      final daysLeft = math.max(0, 30 - elapsedDays);
      final isIncome = tx.type == CategoryType.income;

      final title = tx.note ?? tx.merchant ?? cat?.name ?? 'Giao dịch';
      final subtitle =
          '${DateFormat('dd/MM HH:mm').format(tx.date)} • ${w?.name ?? 'Ví'} • ${cat?.name ?? 'Chung'}';

      items.add(
        UnifiedRecycleBinItem(
          id: tx.id,
          itemType: RecycleBinItemType.standard,
          title: title,
          subtitle: subtitle,
          amount: tx.amount,
          isMoneyIn: isIncome,
          date: tx.date,
          deletedAt: deletedTime,
          daysRemaining: daysLeft,
          standardTx: tx,
          category: cat,
          wallet: w,
        ),
      );
    }

    // Phân giải giao dịch nợ
    for (final row in debtRows) {
      final d = row.readTable(db.debtTransactions);
      final contact = row.readTableOrNull(db.debtContacts);
      final w = row.readTableOrNull(db.wallets);

      final deletedTime = d.deletedAt ?? now;
      final elapsedDays = now.difference(deletedTime).inDays;
      final daysLeft = math.max(0, 30 - elapsedDays);

      final contactName = contact?.name ?? 'Đối tác';
      String title = '';
      bool isMoneyIn = false;

      switch (d.type) {
        case 'LEND':
          title = 'Cho $contactName vay';
          isMoneyIn = false;
          break;
        case 'COLLECT':
          title = '$contactName trả nợ';
          isMoneyIn = true;
          break;
        case 'BORROW':
          title = 'Vay từ $contactName';
          isMoneyIn = true;
          break;
        case 'REPAY':
          title = 'Trả nợ cho $contactName';
          isMoneyIn = false;
          break;
        default:
          title = 'Giao dịch nợ với $contactName';
          isMoneyIn = false;
      }

      final subtitle =
          '${DateFormat('dd/MM HH:mm').format(d.date)} • ${w?.name ?? 'Ví'}';

      items.add(
        UnifiedRecycleBinItem(
          id: d.id,
          itemType: RecycleBinItemType.debt,
          title: title,
          subtitle: subtitle,
          amount: d.amount,
          isMoneyIn: isMoneyIn,
          date: d.date,
          deletedAt: deletedTime,
          daysRemaining: daysLeft,
          debtTx: d,
          contact: contact,
          wallet: w,
          debtType: d.type,
        ),
      );
    }

    // Sắp xếp theo ngày đưa vào thùng rác mới nhất lên đầu
    items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return items;
  });
});

class RecycleBinScreen extends ConsumerWidget {
  const RecycleBinScreen({super.key});

  String _formatCurrency(double amount, [String currency = '₫']) {
    final formatter =
    NumberFormat.currency(locale: 'vi_VN', symbol: currency, decimalDigits: 0);
    return formatter.format(amount);
  }

  String _formatRelativeDeletedGroup(DateTime deletedAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(deletedAt.year, deletedAt.month, deletedAt.day);
    final diffDays = today.difference(itemDate).inDays;

    if (diffDays == 0) return 'HÔM NAY';
    if (diffDays == 1) return 'HÔM QUA';
    return '$diffDays NGÀY TRƯỚC';
  }

  Map<String, List<UnifiedRecycleBinItem>> _groupItemsByRelativeDays(
      List<UnifiedRecycleBinItem> items) {
    final Map<String, List<UnifiedRecycleBinItem>> map = {};
    for (final it in items) {
      final key = _formatRelativeDeletedGroup(it.deletedAt);
      map.putIfAbsent(key, () => []).add(it);
    }
    return map;
  }

  Future<void> _confirmEmptyBin(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTokens.darkCard : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTokens.expense, size: 24),
            SizedBox(width: 8),
            Text('Dọn sạch thùng rác?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'Tất cả các giao dịch thu chi và vay nợ trong thùng rác sẽ bị xóa vĩnh viễn khỏi bộ nhớ và KHÔNG THỂ khôi phục lại được nữa. Bạn có chắc chắn không?',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('HỦY', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.expense,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('XÓA TẤT CẢ', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.heavyImpact();
      final db = ref.read(databaseProvider);
      final count = await db.emptyRecycleBin();
      if (context.mounted) {
        AppFeedback.showSuccess(
          context,
          '✓ Đã dọn sạch $count mục khỏi Thùng rác vĩnh viễn.',
          emitHaptic: false,
        );
      }
    }
  }

  Future<void> _confirmPermanentDeleteSingle(
      BuildContext context, WidgetRef ref, UnifiedRecycleBinItem item) async {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTokens.darkCard : Colors.white,
        title: const Text('Xóa vĩnh viễn mục này?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
          'Mục "${item.title}" (${item.isDebt ? 'Vay/Nợ' : 'Giao dịch'}) sẽ bị xóa vĩnh viễn khỏi thiết bị.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('HỦY'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.expense,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('XÓA HẲN'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      HapticFeedback.mediumImpact();
      final db = ref.read(databaseProvider);

      if (item.isDebt) {
        await db.permanentDeleteDebtTransaction(item.id);
      } else {
        await db.permanentDeleteTransaction(item.id);
      }

      if (context.mounted) {
        AppFeedback.showSuccess(
          context,
          '✓ Đã xóa vĩnh viễn mục khỏi bộ nhớ.',
          emitHaptic: false,
        );
      }
    }
  }

  Future<void> _restoreSingle(
      BuildContext context, WidgetRef ref, UnifiedRecycleBinItem item) async {
    HapticFeedback.selectionClick();
    final db = ref.read(databaseProvider);

    if (item.isDebt) {
      await db.restoreDebtTransaction(item.id);
    } else {
      await db.restoreTransaction(item.id);
    }

    if (context.mounted) {
      AppFeedback.showSuccess(
        context,
        '✓ Đã khôi phục "${item.title}" về Sổ Giao Dịch và tái cân đối số dư ví.',
        emitHaptic: false,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final deletedListAsync = ref.watch(unifiedDeletedItemsStreamProvider);

    return AppFeedbackDismissRegion(
      child: Scaffold(
        backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop();
            },
          ),
          title: deletedListAsync.maybeWhen(
            data: (items) => Text(
              'Thùng Rác (${items.length})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTokens.darkText : AppTokens.lightText,
              ),
            ),
            orElse: () => Text(
              'Thùng Rác',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTokens.darkText : AppTokens.lightText,
              ),
            ),
          ),
          actions: [
            deletedListAsync.maybeWhen(
              data: (items) {
                if (items.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: AppTokens.expense),
                    label: const Text(
                      'Dọn sạch',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTokens.expense,
                      ),
                    ),
                    onPressed: () => _confirmEmptyBin(context, ref),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        body: SafeArea(
          child: deletedListAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return _buildEmptyState(isDark);
              }

              final grouped = _groupItemsByRelativeDays(items);
              final groupKeys = grouped.keys.toList();

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                children: [
                  // Header thông minh đếm ngược 30 ngày
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.28),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF0EA5E9), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Các mục trong thùng rác (cả thu chi và vay nợ) sẽ tự động bị xóa vĩnh viễn sau 30 ngày kể từ ngày xóa.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0EA5E9),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phân nhóm theo mốc thời gian
                  ...groupKeys.map((groupKey) {
                    final groupItems = grouped[groupKey]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                groupKey,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                ),
                              ),
                              Text(
                                '${groupItems.length} mục',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...groupItems.map((item) {
                          return _buildDeletedItemCard(context, ref, item, isDark, accent);
                        }),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Lỗi tải thùng rác: $err',
                  style: const TextStyle(color: AppTokens.expense),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 40,
              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Thùng rác trống',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Không có giao dịch hoặc khoản nợ nào bị xóa gần đây.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedItemCard(
      BuildContext context,
      WidgetRef ref,
      UnifiedRecycleBinItem item,
      bool isDark,
      AppAccentPreset accent,
      ) {
    final amountColor = item.isMoneyIn ? AppTokens.income : AppTokens.expense;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (item.isDebt)
                _buildDebtBadge(item.debtType ?? 'LEND')
              else
                CategoryIconBadge(
                  category: item.category,
                  isExpense: item.standardTx?.type == CategoryType.expense,
                  size: 38,
                  iconSize: 18,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                            ),
                          ),
                        ),
                        if (item.isDebt) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: _resolveDebtColor(item.debtType).withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              'Vay/Nợ',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _resolveDebtColor(item.debtType),
                              ),
                            ),
                          ),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.daysRemaining <= 5
                                ? AppTokens.expense.withValues(alpha: 0.16)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Còn ${item.daysRemaining} ngày',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: item.daysRemaining <= 5
                                  ? AppTokens.expense
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                          ),
                        ),
                        Text(
                          '${item.isMoneyIn ? '+' : '-'}${_formatCurrency(item.amount)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Nút xóa vĩnh viễn
              InkWell(
                onTap: () => _confirmPermanentDeleteSingle(context, ref, item),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever_rounded,
                          size: 15, color: AppTokens.expense.withValues(alpha: 0.9)),
                      const SizedBox(width: 4),
                      const Text(
                        'Xóa hẳn',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.expense,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Nút khôi phục
              InkWell(
                onTap: () => _restoreSingle(context, ref, item),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accent.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.restore_rounded, size: 15, color: accent.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Khôi phục',
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebtBadge(String debtType) {
    IconData iconData;
    Color color;

    switch (debtType) {
      case 'LEND':
        iconData = Icons.call_made_rounded;
        color = const Color(0xFF10B981);
        break;
      case 'COLLECT':
        iconData = Icons.call_received_rounded;
        color = const Color(0xFF0EA5E9);
        break;
      case 'BORROW':
        iconData = Icons.south_west_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case 'REPAY':
        iconData = Icons.north_east_rounded;
        color = const Color(0xFFF43F5E);
        break;
      default:
        iconData = Icons.swap_horiz_rounded;
        color = const Color(0xFF10B981);
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: color, size: 18),
    );
  }

  Color _resolveDebtColor(String? debtType) {
    switch (debtType) {
      case 'LEND':
        return const Color(0xFF10B981);
      case 'COLLECT':
        return const Color(0xFF0EA5E9);
      case 'BORROW':
        return const Color(0xFFF59E0B);
      case 'REPAY':
        return const Color(0xFFF43F5E);
      default:
        return const Color(0xFF6366F1);
    }
  }
}