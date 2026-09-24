// ==============================================================================
// File: lib/screens/project_budget_detail_screen.dart
// Architecture: Isolated Event/Project Financial Management & Analytics Dashboard
// Stack: flutter_riverpod, drift, intl
// Features:
// 1. Reactive Drift Watchers: watchProjectBudgetById & watchTransactionsForProject
// 2. Mini-Dashboard: Overview card (Target, Spent, Remaining) + Dynamic Progress Bar
// 3. Bento Metrics Grid: Days remaining counter & Event-Specific Safe-to-Spend per day
// 4. Category Expense Breakdown: Aggregated category share percentages with sleek horizontal bars
// 5. Isolated Transactions Timeline: Sắp xếp theo ngày giảm dần, hỗ trợ sửa & xóa hoàn tác an toàn
// 6. 1-Tap Quick Entry Launcher: Mở trực tiếp qua QuickEntrySheet.show(...) tích hợp Fluid Sheet Engine
// ==============================================================================

import 'dart:math' as math;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_text.dart';
import '../widgets/category_icon_badge.dart';
import '../widgets/quick_entry_sheet.dart';

// StreamProvider theo dõi chi tiết một sự kiện/dự án cụ thể theo ID
final projectDetailStreamProvider = StreamProvider.autoDispose.family<ProjectBudget?, String>((ref, projectId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.projectBudgets)..where((p) => p.id.equals(projectId)))
      .watchSingleOrNull();
});

// StreamProvider theo dõi các giao dịch thuộc về sự kiện này
final projectTransactionsStreamProvider = StreamProvider.autoDispose.family<List<Transaction>, String>((ref, projectId) {
  final db = ref.watch(databaseProvider);
  final projectAsync = ref.watch(projectDetailStreamProvider(projectId));
  final project = projectAsync.valueOrNull;

  if (project == null) {
    return Stream.value(<Transaction>[]);
  }

  return db.watchTransactionsForProject(project.id, project.tag);
});

// StreamProvider lấy toàn bộ danh mục để hiển thị tên & icon
final projectCategoriesStreamProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

// StreamProvider lấy toàn bộ ví tiền để hiển thị ví thanh toán
final projectWalletsStreamProvider = StreamProvider.autoDispose<List<Wallet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.wallets).watch();
});

// Model DTO gom nhóm chi phí theo danh mục trong sự kiện
class CategoryShareItem {
  final Category? category;
  final double amount;
  final double percentage;

  const CategoryShareItem({
    required this.category,
    required this.amount,
    required this.percentage,
  });
}

class ProjectBudgetDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectBudgetDetailScreen({
    super.key,
    required this.projectId,
  });

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount);
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF0EA5E9);
    }
  }

  void _openEditModal(BuildContext context, ProjectBudget project) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => _EditProjectModal(project: project),
    );
  }

  /// 🌟 Mở QuickEntrySheet chuẩn qua launcher tĩnh Fluid Sheet Engine
  void _openQuickAddTransaction(BuildContext context, ProjectBudget project) {
    QuickEntrySheet.show(
      context,
      initialContextDate: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    final projectAsync = ref.watch(projectDetailStreamProvider(projectId));
    final transactionsAsync = ref.watch(projectTransactionsStreamProvider(projectId));
    final categoriesAsync = ref.watch(projectCategoriesStreamProvider);
    final walletsAsync = ref.watch(projectWalletsStreamProvider);

    return AppFeedbackDismissRegion(
      child: projectAsync.when(
        data: (project) {
          if (project == null) {
            return Scaffold(
              backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
              appBar: AppBar(title: const Text('Chi tiết sự kiện')),
              body: const Center(child: Text('Không tìm thấy sự kiện hoặc sự kiện đã bị xóa.')),
            );
          }

          final projectColor = _parseColor(project.colorHex);
          final txs = transactionsAsync.valueOrNull ?? <Transaction>[];
          final catMap = {for (final c in categoriesAsync.valueOrNull ?? <Category>[]) c.id: c};
          final walletMap = {for (final w in walletsAsync.valueOrNull ?? <Wallet>[]) w.id: w};

          final now = DateTime.now();
          final isPast = now.isAfter(project.endDate);
          final isFuture = now.isBefore(project.startDate);
          final isArchived = project.status == 'ARCHIVED' || isPast;

          // Tính tổng tiền đã chi cho sự kiện
          final double totalSpent = txs.fold(0.0, (sum, t) => sum + t.amount);
          final double remaining = project.targetAmount - totalSpent;
          final bool isOver = remaining < 0;
          final double spendRatio = project.targetAmount > 0 ? (totalSpent / project.targetAmount).clamp(0.0, 1.0) : 0.0;

          // Màu thanh tiến độ
          Color progressColor = const Color(0xFF10B981); // Emerald
          if (isOver || spendRatio > 0.90) {
            progressColor = const Color(0xFFF43F5E); // Rose
          } else if (spendRatio >= 0.75) {
            progressColor = const Color(0xFFF59E0B); // Amber
          }

          // Tính số ngày còn lại & Safe-to-Spend mỗi ngày
          int daysRemaining = 0;
          if (!isPast) {
            daysRemaining = math.max(1, project.endDate.difference(now).inDays + 1);
          }
          final double safeToSpendDaily = isArchived || remaining <= 0
              ? 0.0
              : math.max(0.0, remaining / daysRemaining).floorToDouble();

          // Tính tỷ trọng phân bổ chi phí theo danh mục (Expense Breakdown)
          final Map<String, double> categorySpentMap = {};
          for (final t in txs) {
            categorySpentMap[t.categoryId] = (categorySpentMap[t.categoryId] ?? 0.0) + t.amount;
          }

          final List<CategoryShareItem> breakdownList = categorySpentMap.entries.map((entry) {
            final cat = catMap[entry.key];
            final amount = entry.value;
            final pct = totalSpent > 0 ? (amount / totalSpent) : 0.0;
            return CategoryShareItem(category: cat, amount: amount, percentage: pct);
          }).toList()
            ..sort((a, b) => b.amount.compareTo(a.amount));

          return Scaffold(
            backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
            appBar: AppBar(
              backgroundColor: isDark ? AppTokens.darkCard : Colors.white,
              elevation: 0.5,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              titleSpacing: 0,
              title: Row(
                children: [
                  Text(project.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                        Text(
                          project.tag,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: projectColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: isDark ? AppTokens.darkText : AppTokens.lightText),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) async {
                    HapticFeedback.selectionClick();
                    final db = ref.read(databaseProvider);
                    if (val == 'edit') {
                      _openEditModal(context, project);
                    } else if (val == 'archive') {
                      await db.archiveProjectBudget(project.id);
                      if (!context.mounted) return;
                      AppFeedback.showSuccess(
                        context,
                        'Đã đóng sự kiện "${project.title}"!',
                      );
                    } else if (val == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Xác nhận xóa sự kiện'),
                          content: Text('Xóa sự kiện "${project.title}"? Các giao dịch chi tiêu liên quan sẽ được giữ lại nguyên vẹn.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTokens.expense, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('XÓA'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await db.deleteProjectBudget(project.id);
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('✏️ Chỉnh sửa thông tin')]),
                    ),
                    if (!isArchived)
                      const PopupMenuItem(
                        value: 'archive',
                        child: Row(children: [Icon(Icons.archive_outlined, size: 18), SizedBox(width: 8), Text('📥 Đóng / Chốt sổ')]),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppTokens.expense), SizedBox(width: 8), Text('🗑️ Xóa sự kiện', style: TextStyle(color: AppTokens.expense))]),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.lightImpact();
                ref.invalidate(projectDetailStreamProvider(projectId));
                ref.invalidate(projectTransactionsStreamProvider(projectId));
              },
              child: ListView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                children: [
                  // 1. THẺ THỐNG KÊ TỔNG QUAN (EVENT MINI-DASHBOARD HERO CARD)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                            : [projectColor, projectColor.withValues(alpha: 0.85)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: projectColor.withValues(alpha: 0.25),
                          blurRadius: 14,
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
                              'TỔNG HẠN MỨC SỰ KIỆN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: isDark ? AppTokens.darkMuted : Colors.white70,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isArchived ? 'Đã chốt sổ' : (isFuture ? 'Sắp tới' : 'Đang diễn ra'),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatCurrency(project.targetAmount),
                          style: currencyTextStyle(context, const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          )),
                        ),
                        const SizedBox(height: 14),
                        Stack(
                          children: [
                            Container(
                              height: 7,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: spendRatio,
                              child: Container(
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isOver ? const Color(0xFFF87171) : const Color(0xFF34D399),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CurrencyText(
                              'Đã chi: ${_formatCurrency(totalSpent)} (${(spendRatio * 100).toStringAsFixed(0)}%)',
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                            CurrencyText(
                              isOver ? 'Vượt: ${_formatCurrency(remaining.abs())}' : 'Còn: ${_formatCurrency(remaining)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isOver ? const Color(0xFFFCA5A5) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. HÀNG THÔNG SỐ KÉP (BENTO DUAL METRIC CARDS)
                  Row(
                    children: [
                      // Bento 1: Thời gian & Ngày còn lại
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppTokens.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.event_available_rounded, size: 16, color: projectColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    'THỜI GIAN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isArchived ? 'Đã kết thúc' : (isFuture ? 'Chưa bắt đầu' : 'Còn $daysRemaining ngày'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormat('dd/MM').format(project.startDate)} → ${DateFormat('dd/MM').format(project.endDate)}',
                                style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Bento 2: Safe-to-Spend Mỗi Ngày Của Sự Kiện
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppTokens.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.shield_outlined, size: 16, color: const Color(0xFF10B981)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AN TOÀN MỖI NGÀY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${_formatCurrency(safeToSpendDaily)}/ngày',
                                  style: currencyTextStyle(context, const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF10B981),
                                  )),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Hạn mức tối đa/ngày',
                                style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 3. CƠ CẤU PHÂN BỔ CHI PHÍ (EXPENSE BREAKDOWN)
                  if (breakdownList.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.pie_chart_outline_rounded, size: 15, color: projectColor),
                        const SizedBox(width: 6),
                        Text(
                          'Cơ cấu phân bổ chi phí',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTokens.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                      ),
                      child: Column(
                        children: breakdownList.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CategoryIconBadge(category: item.category, isExpense: true, size: 28, iconSize: 14),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.category?.name ?? 'Chưa phân loại',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                        ),
                                      ),
                                    ),
                                    CurrencyText(
                                      '${_formatCurrency(item.amount)} (${(item.percentage * 100).toStringAsFixed(0)}%)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: item.percentage,
                                    minHeight: 5,
                                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                    valueColor: AlwaysStoppedAnimation<Color>(projectColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 4. NHẬT KÝ GIAO DỊCH RIÊNG BIỆT (EVENT ISOLATED TIMELINE)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history_rounded, size: 16, color: projectColor),
                          const SizedBox(width: 6),
                          Text(
                            'Nhật ký chi tiêu (${txs.length})',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Tự nhận qua ${project.tag}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: projectColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (txs.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                      decoration: BoxDecoration(
                        color: isDark ? AppTokens.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 38, color: projectColor.withValues(alpha: 0.6)),
                            const SizedBox(height: 10),
                            Text(
                              'Chưa có chi tiêu nào cho sự kiện này',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTokens.darkText : AppTokens.lightText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hãy bấm nút bên dưới để ghi chép khoản chi đầu tiên!',
                              style: TextStyle(fontSize: 12, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...txs.map((tx) {
                      final cat = catMap[tx.categoryId];
                      final wallet = walletMap[tx.walletId];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Dismissible(
                          key: Key(tx.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppTokens.expense,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            return await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Xác nhận xóa'),
                                content: const Text('Xóa giao dịch này? Số dư ví sẽ được hoàn trả tương ứng.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTokens.expense, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('XÓA'),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (_) async {
                            final db = ref.read(databaseProvider);
                            await db.deleteTransactionWithBalanceReversal(tx.id);
                          },
                          child: InkWell(
                            onTap: () {
                              QuickEntrySheet.show(
                                context,
                                initialTransaction: tx,
                                initialContextDate: tx.date,
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppTokens.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                              ),
                              child: Row(
                                children: [
                                  CategoryIconBadge(category: cat, isExpense: true, size: 36, iconSize: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cat?.name ?? 'Khoản chi',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${DateFormat('dd/MM HH:mm').format(tx.date)} • ${wallet?.name ?? "Ví tiền"}${tx.note != null && tx.note!.isNotEmpty ? " • ${tx.note}" : ""}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '-${_formatCurrency(tx.amount)}',
                                    style: currencyTextStyle(context, const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppTokens.expense,
                                    )),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),

            // 5. NÚT GHI CHÉP NHANH 1-CHẠM (BOTTOM CTA CỐ ĐỊNH)
            bottomSheet: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? AppTokens.darkCard : Colors.white,
                border: Border(top: BorderSide(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder)),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: projectColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _openQuickAddTransaction(context, project),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(
                      '+ Thêm chi tiêu cho ${project.title}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => Scaffold(
          backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
          body: Center(child: Text('Lỗi: $e')),
        ),
      ),
    );
  }
}

// ==============================================================================
// 🌟 MODAL CHỈNH SỬA SỰ KIỆN (_EditProjectModal)
// ==============================================================================

class _EditProjectModal extends ConsumerStatefulWidget {
  final ProjectBudget project;
  const _EditProjectModal({required this.project});

  @override
  ConsumerState<_EditProjectModal> createState() => _EditProjectModalState();
}

class _EditProjectModalState extends ConsumerState<_EditProjectModal> {
  late final TextEditingController _titleController;
  late final TextEditingController _tagController;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _amountBuffer;
  late String _selectedEmoji;
  late String _selectedColorHex;
  bool _isSaving = false;

  final AppValidationFeedbackController _titleFeedback =
  AppValidationFeedbackController();
  final AppValidationFeedbackController _amountFeedback =
  AppValidationFeedbackController();

  final List<String> _presetEmojis = ['🌴', '✈️', '💻', '🧧', '🏠', '💍', '🚗', '🛍️', '🎓', '🎉'];
  final List<String> _presetColors = ['#0EA5E9', '#10B981', '#F59E0B', '#F43F5E', '#8B5CF6', '#3B82F6', '#64748B'];

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _titleController = TextEditingController(text: p.title);
    _tagController = TextEditingController(text: p.tag);
    _startDate = p.startDate;
    _endDate = p.endDate;
    _amountBuffer = p.targetAmount.toInt().toString();
    _selectedEmoji = p.icon;
    _selectedColorHex = p.colorHex;

    _titleController.addListener(() {
      if (_titleController.text.trim().isNotEmpty) {
        _titleFeedback.clear();
      }
    });
  }

  @override
  void dispose() {
    _titleFeedback.dispose();
    _amountFeedback.dispose();
    _titleController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountBuffer) ?? 0.0;

    final titleInvalid = title.isEmpty;
    final amountInvalid = amount <= 0;
    if (titleInvalid || amountInvalid) {
      HapticFeedback.heavyImpact();
      if (titleInvalid) {
        _titleFeedback.reject(emitHaptic: false);
      }
      if (amountInvalid) {
        _amountFeedback.reject(emitHaptic: false);
      }
      return;
    }

    var tag = _tagController.text.trim();
    if (!tag.startsWith('#')) tag = '#$tag';

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);

    try {
      await db.updateProjectBudget(
        id: widget.project.id,
        title: title,
        tag: tag,
        icon: _selectedEmoji,
        colorHex: _selectedColorHex,
        targetAmount: amount,
        startDate: _startDate,
        endDate: _endDate,
      );

      HapticFeedback.mediumImpact();
      if (!mounted) return;

      AppFeedback.showSuccess(
        context,
        'Đã cập nhật sự kiện "$title".',
        emitHaptic: false,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(
          context,
          'Lỗi cập nhật sự kiện: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Color(int.parse('FF${_selectedColorHex.replaceAll('#', '')}', radix: 16));

    return AppFeedbackDismissRegion(
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C28) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 12),
                Text('Chỉnh Sửa Sự Kiện', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? AppTokens.darkText : AppTokens.lightText)),
                const SizedBox(height: 10),
                AppValidationFeedback(
                  controller: _titleFeedback,
                  builder: (context, visual) {
                    final restingBorder =
                    isDark ? AppTokens.darkBorder : AppTokens.lightBorder;
                    return TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Tên sự kiện *',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: visual.borderColor(restingBorder),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: visual.isInvalid
                                ? visual.borderColor(restingBorder)
                                : primaryColor,
                            width: 1.6,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: _tagController, decoration: const InputDecoration(labelText: 'Mã Tag nhận diện *')),
                const SizedBox(height: 10),
                // Emoji Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _presetEmojis.map((em) {
                      final isSel = _selectedEmoji == em;
                      return InkWell(
                        onTap: () => setState(() => _selectedEmoji = em),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSel ? primaryColor.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isSel ? Border.all(color: primaryColor, width: 1.5) : null,
                          ),
                          child: Text(em, style: const TextStyle(fontSize: 20)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                // Date Range Button
                InkWell(
                  onTap: _pickDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range_rounded, color: primaryColor, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(_startDate)} → ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppTokens.darkText : AppTokens.lightText),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AppValidationFeedback(
                  controller: _amountFeedback,
                  builder: (context, visual) {
                    final restingBorder =
                    isDark ? AppTokens.darkBorder : AppTokens.lightBorder;
                    return TextField(
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: _amountBuffer),
                      onChanged: (val) {
                        _amountBuffer = val;
                        if ((double.tryParse(val) ?? 0.0) > 0) {
                          _amountFeedback.clear();
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Hạn mức ngân sách (₫) *',
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: visual.borderColor(restingBorder),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: visual.isInvalid
                                ? visual.borderColor(restingBorder)
                                : primaryColor,
                            width: 1.6,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isSaving ? null : _save,
                    child: const Text('✓ LƯU THAY ĐỔI', style: TextStyle(fontWeight: FontWeight.w800)),
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