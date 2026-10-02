import '../widgets/currency_text.dart';
import '../theme/app_icons.dart';
// ==============================================================================
// File: lib/screens/debt_dashboard_screen.dart
// Architecture: Debt Counterparty Overview & Contact Directory (Strict Drift Schema)
// Stack: flutter_riverpod, drift, intl
// Schema Fidelity: Only accesses real Drift columns:
//                  id, name, phone, avatarUrl, netBalance, createdAt, updatedAt
// Features: Composite Avatar Packing (_avatarType|_colorHex|_avatarValue) in avatarUrl,
//           Full integration with DebtContactAvatarPicker & real-time Initials sync,
//           Hero Net Balance Card (Net Worth Adjustment, Receivable & Payable),
//           4 Horizontal Status Filter Chips [Tất cả | Ai nợ tôi | Tôi nợ ai | Đã sòng phẳng],
//           Tap for history; swipe left to archive settled contacts with undo,
//           Collapsible Settled Section for zero-balance contacts,
//           Strict Safe Deletion Validation Rule (Block delete when netBalance != 0),
//           Universal Fluid Sheet Launching via QuickEntrySheet.show(...)
// ==============================================================================

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../widgets/sliding_segmented_bar.dart';
import '../widgets/preserved_sleek_dismissible.dart';
import '../widgets/archived_entities_sheet.dart';
import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/daos/debt_dao.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
import '../widgets/debt_contact_avatar_picker.dart';
import '../widgets/quick_entry_sheet.dart';
import 'contact_ledger_screen.dart';

final _availableContactsProvider =
    StreamProvider.autoDispose<List<DebtContact>>(
        (ref) => ref.watch(databaseProvider).watchAvailableDebtContacts());

// StreamProvider tra cứu hạn chót gần nhất chưa thanh toán theo từng contact
final contactDueDatesStreamProvider =
    StreamProvider.autoDispose<Map<String, DateTime?>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.debtTransactions)
        ..where((t) => t.dueDate.isNotNull() & t.isSettled.equals(false) & t.deletedAt.isNull())
        ..orderBy([(t) => drift.OrderingTerm.asc(t.dueDate)]))
      .watch()
      .map((txs) {
    final map = <String, DateTime?>{};
    for (final tx in txs) {
      if (!map.containsKey(tx.contactId)) {
        map[tx.contactId] = tx.dueDate;
      }
    }
    return map;
  });
});

enum DebtContactFilter { all, receivable, payable, settled }

// Helper bóc tách avatarUrl an toàn, tương thích ngược nhiều định dạng
class _ParsedAvatar {
  final String type; // 'INITIALS' | 'EMOJI'
  final String colorHex;
  final String emoji;

  const _ParsedAvatar({
    required this.type,
    required this.colorHex,
    required this.emoji,
  });

  static _ParsedAvatar parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const _ParsedAvatar(
        type: 'INITIALS',
        colorHex: '#10B981',
        emoji: '',
      );
    }

    if (raw.startsWith('icon:')) {
      final parts = raw.substring(5).split('|');
      return _ParsedAvatar(type: 'ICON', colorHex: parts.length > 1 ? parts[1] : '#10B981', emoji: parts.first);
    }
    final parts = raw.split('|');
    if (parts.length >= 3) {
      final type = parts[0] == 'ICON' ? 'ICON' : parts[0] == 'EMOJI' ? 'EMOJI' : 'INITIALS';
      final colorHex = parts[1].startsWith('#') ? parts[1] : '#10B981';
      final emoji = parts.sublist(2).join('|');
      return _ParsedAvatar(type: type, colorHex: colorHex, emoji: emoji);
    } else if (parts.length == 2) {
      // Định dạng cũ: colorHex|emoji
      final colorHex = parts[0].startsWith('#') ? parts[0] : '#10B981';
      final emoji = parts[1];
      final type = emoji.isNotEmpty ? 'EMOJI' : 'INITIALS';
      return _ParsedAvatar(type: type, colorHex: colorHex, emoji: emoji);
    } else {
      if (raw.startsWith('#')) {
        return _ParsedAvatar(type: 'INITIALS', colorHex: raw, emoji: '');
      } else {
        return _ParsedAvatar(type: 'EMOJI', colorHex: '#10B981', emoji: raw);
      }
    }
  }
}

class DebtDashboardScreen extends ConsumerStatefulWidget {
  const DebtDashboardScreen({super.key});

  @override
  ConsumerState<DebtDashboardScreen> createState() =>
      _DebtDashboardScreenState();
}

class _DebtDashboardScreenState extends ConsumerState<DebtDashboardScreen> {
  DebtContactFilter _activeFilter = DebtContactFilter.all;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  bool _isSettledSectionExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount, [String currency = '₫']) {
    final formatter = NumberFormat.currency(
        locale: 'vi_VN', symbol: currency, decimalDigits: 0);
    return formatter.format(amount);
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  String _extractInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  // 🌟 Mở QuickEntrySheet chuẩn qua launcher tĩnh Fluid Sheet Engine
  void _openQuickEntryForDebt(BuildContext context) {
    QuickEntrySheet.show(
      context,
      prefilledDebtType: 'LEND',
    );
  }

  void _openContactEditModal(BuildContext context, [DebtContact? contact]) {
    HapticFeedback.selectionClick();
    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => _ContactEditModal(contact: contact),
    );
  }

  Future<bool> _confirmArchiveContact(DebtContact contact) async {
    final db = ref.read(databaseProvider);
    final current = await (db.select(db.debtContacts)
          ..where((c) => c.id.equals(contact.id)))
        .getSingleOrNull();
    final openLoans = await (db.select(db.debtTransactions)
          ..where((d) =>
              d.contactId.equals(contact.id) &
              d.deletedAt.isNull() &
              d.isSettled.equals(false) &
              d.type.isIn(['LEND', 'BORROW'])))
        .get();
    if (!mounted) return false;
    if (current == null ||
        current.netBalance.abs() > .001 ||
        openLoans.isNotEmpty) {
      AppFeedback.showInfo(
          context, 'Hãy tất toán các khoản vay trước khi lưu trữ đối tác.');
      return false;
    }
    return true;
  }

  Future<void> _archiveContact(DebtContact contact) async {
    final db = ref.read(databaseProvider);
    try {
      await db.archiveEntity('contact', contact.id);
    } catch (_) {
      if (mounted) {
        AppFeedback.showInfo(
            context, 'Chưa lưu trữ được đối tác. Hãy kiểm tra các khoản vay.');
      }
      rethrow;
    }
    if (!mounted) return;
    AppFeedback.showUndo(context,
        message: 'Đã lưu trữ “${contact.name}”',
        onUndo: () => db.restoreArchivedEntity('contact', contact.id));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final summaryAsync = ref.watch(debtSummaryStreamProvider);
    final contactsAsync = ref.watch(_availableContactsProvider);
    final dueDatesAsync = ref.watch(contactDueDatesStreamProvider);

    final dueDatesMap = dueDatesAsync.valueOrNull ?? {};

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
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(
                      fontSize: 15,
                      color: isDark ? AppTokens.darkText : AppTokens.lightText),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên người nợ...',
                    hintStyle: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppTokens.darkMuted
                            : AppTokens.lightMuted),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                )
              : Text(
                  'Sổ Nợ & Đối Ứng',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                  ),
                ),
          actions: [
            IconButton(
                tooltip: 'Đã lưu trữ',
                icon: const Icon(Icons.inventory_2_outlined),
                onPressed: () => showArchivedEntities(
                    context, ref.read(databaseProvider), 'contact')),
            IconButton(
              icon: Icon(
                  _isSearching ? Icons.close_rounded : Icons.search_rounded,
                  size: 22),
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (_isSearching) {
                    _searchController.clear();
                    _isSearching = false;
                  } else {
                    _isSearching = true;
                  }
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.person_add_alt_1_rounded,
                  color: accent.primary, size: 22),
              tooltip: 'Tạo hồ sơ đối tượng mới',
              onPressed: () => _openContactEditModal(context),
            ),
          ],
        ),
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Thẻ Tổng Quan Dòng Tiền Nợ Ròng (Hero Net Balance Card)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: summaryAsync.when(
                    data: (summary) =>
                        _buildSummaryCard(summary, isDark, accent),
                    loading: () => const SizedBox(
                      height: 120,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (err, _) => Center(
                      child: Text('Lỗi: $err',
                          style: const TextStyle(color: AppTokens.expense)),
                    ),
                  ),
                ),
              ),

              // 2. Bộ Lọc Trạng Thái Nhanh (Status Filter Chips)
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 10),
                sliver: SliverToBoxAdapter(
                  child: contactsAsync.maybeWhen(
                    data: (allContacts) {
                      final countAll = allContacts.length;
                      final countReceivable =
                          allContacts.where((c) => c.netBalance > 0.001).length;
                      final countPayable = allContacts
                          .where((c) => c.netBalance < -0.001)
                          .length;
                      final countSettled = allContacts
                          .where((c) => c.netBalance.abs() <= 0.001)
                          .length;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const ClampingScrollPhysics(),
                        child: SizedBox(
                          width: 680,
                          child: SlidingSegmentedBar<DebtContactFilter>(
                            height: 38,
                            duration: const Duration(milliseconds: 185),
                            overshootPx: 1.6,
                            debugLabel: 'DebtDashboard.contactFilter',
                            selectedValue: _activeFilter,
                            trackColor: isDark
                                ? AppTokens.darkCard
                                : AppTokens.lightCardSubtle,
                            trackBorderColor: isDark
                                ? AppTokens.darkBorder
                                : AppTokens.lightBorder,
                            indicatorColor: accent.primary,
                            indicatorBorderColor: accent.primary,
                            selectedTextColor: Colors.white,
                            mutedTextColor: isDark
                                ? AppTokens.darkText
                                : AppTokens.lightText,
                            items: [
                              SlidingSegmentedItem<DebtContactFilter>(
                                value: DebtContactFilter.all,
                                label: 'Tất cả ($countAll)',
                              ),
                              SlidingSegmentedItem<DebtContactFilter>(
                                value: DebtContactFilter.receivable,
                                label: 'Ai nợ tôi ($countReceivable)',
                              ),
                              SlidingSegmentedItem<DebtContactFilter>(
                                value: DebtContactFilter.payable,
                                label: 'Tôi nợ ai ($countPayable)',
                              ),
                              SlidingSegmentedItem<DebtContactFilter>(
                                value: DebtContactFilter.settled,
                                label: 'Đã sòng phẳng ($countSettled)',
                              ),
                            ],
                            onValueChanged: (filter) {
                              setState(() => _activeFilter = filter);
                            },
                          ),
                        ),
                      );
                    },
                    orElse: () => const SizedBox(),
                  ),
                ),
              ),

              // 3. Danh Sách Đối Tượng Nợ
              contactsAsync.when(
                data: (allContacts) {
                  var filtered = List<DebtContact>.from(allContacts);

                  // Lọc tìm kiếm theo tên
                  final query = _searchController.text.trim().toLowerCase();
                  if (query.isNotEmpty) {
                    filtered = filtered
                        .where((c) => c.name.toLowerCase().contains(query))
                        .toList();
                  }

                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_alt_outlined,
                              size: 52,
                              color: isDark
                                  ? AppTokens.darkMuted
                                  : AppTokens.lightMuted,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              query.isNotEmpty
                                  ? 'Không tìm thấy đối tượng "$query"'
                                  : 'Chưa có hồ sơ vay nợ nào.\nHãy nhấn (+👤) để thêm đối tượng mới!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppTokens.darkMuted
                                    : AppTokens.lightMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Áp dụng bộ lọc trạng thái
                  if (_activeFilter == DebtContactFilter.receivable) {
                    filtered =
                        filtered.where((c) => c.netBalance > 0.001).toList();
                  } else if (_activeFilter == DebtContactFilter.payable) {
                    filtered =
                        filtered.where((c) => c.netBalance < -0.001).toList();
                  } else if (_activeFilter == DebtContactFilter.settled) {
                    filtered = filtered
                        .where((c) => c.netBalance.abs() <= 0.001)
                        .toList();
                  }

                  // Nếu chọn "Tất cả": phân nhóm đối tượng đang có nợ và nhóm đã thanh toán sòng phẳng
                  if (_activeFilter == DebtContactFilter.all) {
                    final activeDebtList = filtered
                        .where((c) => c.netBalance.abs() > 0.001)
                        .toList();
                    final settledList = filtered
                        .where((c) => c.netBalance.abs() <= 0.001)
                        .toList();

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          ...activeDebtList.map((contact) {
                            final dueDate = dueDatesMap[contact.id];
                            return _buildRichContactCard(
                                context, contact, dueDate, isDark, accent);
                          }),
                          if (settledList.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _isSettledSectionExpanded =
                                    !_isSettledSectionExpanded);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTokens.darkCard
                                      : AppTokens.lightCardSubtle,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: isDark
                                          ? AppTokens.darkBorder
                                          : AppTokens.lightBorder),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                            Icons.check_circle_outline_rounded,
                                            size: 16,
                                            color: Color(0xFF10B981)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Đã thanh toán sòng phẳng (${settledList.length} người)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppTokens.darkText
                                                : AppTokens.lightText,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      _isSettledSectionExpanded
                                          ? Icons.expand_less_rounded
                                          : Icons.expand_more_rounded,
                                      size: 18,
                                      color: isDark
                                          ? AppTokens.darkMuted
                                          : AppTokens.lightMuted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_isSettledSectionExpanded) ...[
                              const SizedBox(height: 8),
                              ...settledList.map((contact) {
                                final dueDate = dueDatesMap[contact.id];
                                return _buildRichContactCard(
                                    context, contact, dueDate, isDark, accent);
                              }),
                            ],
                          ],
                        ]),
                      ),
                    );
                  }

                  // Các bộ lọc cụ thể: hiển thị danh sách trực tiếp
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final contact = filtered[index];
                          final dueDate = dueDatesMap[contact.id];
                          return _buildRichContactCard(
                              context, contact, dueDate, isDark, accent);
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Lỗi tải danh bạ: $err',
                        style: const TextStyle(color: AppTokens.expense)),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 86)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: accent.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ghi Vay / Nợ',
              style: TextStyle(fontWeight: FontWeight.w800)),
          onPressed: () => _openQuickEntryForDebt(context),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      DebtSummary summary, bool isDark, AppAccentPreset accent) {
    final netPositive = summary.netWorthAdjustment >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
          width: 1,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cân đối nợ ròng',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (netPositive
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF43F5E))
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  netPositive ? 'Thặng dư phải thu' : 'Cần thanh toán',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: netPositive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF43F5E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: CurrencyText(
              '${netPositive ? '+' : ''}${_formatCurrency(summary.netWorthAdjustment)}',
              style: currencyTextStyle(
                  context,
                  TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: netPositive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF43F5E),
                  )),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Người ta nợ tôi',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTokens.darkMuted
                                : AppTokens.lightMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    CurrencyText(
                      _formatCurrency(summary.totalReceivable),
                      style: currencyTextStyle(
                          context,
                          const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10B981),
                          )),
                    ),
                  ],
                ),
              ),
              Container(
                  width: 1,
                  height: 30,
                  color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF43F5E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tôi đang nợ',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppTokens.darkMuted
                                : AppTokens.lightMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    CurrencyText(
                      _formatCurrency(summary.totalPayable),
                      style: currencyTextStyle(
                          context,
                          const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF43F5E),
                          )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRichContactCard(
    BuildContext context,
    DebtContact contact,
    DateTime? dueDate,
    bool isDark,
    AppAccentPreset accent,
  ) {
    final hasDebt = contact.netBalance.abs() > 0.001;
    final isReceivable = contact.netBalance > 0;
    final contactColor = hasDebt
        ? (isReceivable ? const Color(0xFF10B981) : const Color(0xFFF43F5E))
        : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted);

    // Giải mã avatar an toàn từ contact.avatarUrl
    final parsedAvatar = _ParsedAvatar.parse(contact.avatarUrl);
    final swatchColor = _parseColor(parsedAvatar.colorHex);
    final isEmoji =
        parsedAvatar.type == 'EMOJI' && parsedAvatar.emoji.isNotEmpty;
    final avatarContent =
        isEmoji ? parsedAvatar.emoji : _extractInitials(contact.name);

    // Tính toán badge hạn chót
    Widget? dueDateBadge;
    if (dueDate != null && hasDebt) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final diff = due.difference(today).inDays;

      if (diff < 0) {
        dueDateBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: AppTokens.expense.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Quá hạn ${diff.abs()} ngày',
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppTokens.expense),
          ),
        );
      } else if (diff == 0) {
        dueDateBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Hạn hôm nay',
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w800, color: Colors.amber),
          ),
        );
      } else {
        dueDateBadge = Text(
          'Hạn: ${DateFormat('dd/MM').format(dueDate)}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: PreservedSleekDismissible(
        key: ValueKey('debt_contact_${contact.id}'),
        borderRadius: 18,
        label: 'Lưu trữ',
        icon: Icons.archive_outlined,
        confirmDismiss: () => _confirmArchiveContact(contact),
        onDismissed: () => _archiveContact(contact),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                PreservedMaterialPageRoute(
                  builder: (_) => ContactLedgerScreen(contact: contact),
                ),
              );
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTokens.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  // Avatar Squircle hiển thị đồng bộ từ avatarUrl
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          swatchColor.withValues(alpha: isDark ? 0.22 : 0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: swatchColor.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: parsedAvatar.type == 'ICON'
                          ? Icon(AppIcons.resolve(parsedAvatar.emoji), color: swatchColor, size: 22)
                          : Text(
                        avatarContent,
                        style: TextStyle(
                          fontSize: isEmoji ? 20 : 17,
                          fontWeight: FontWeight.w900,
                          color: isEmoji ? null : swatchColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Contact Name & Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                contact.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppTokens.darkText
                                      : AppTokens.lightText,
                                ),
                              ),
                            ),
                            if (dueDateBadge != null) ...[
                              const SizedBox(width: 6),
                              dueDateBadge,
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (contact.phone != null &&
                                contact.phone!.isNotEmpty) ...[
                              Icon(Icons.phone_rounded,
                                  size: 11,
                                  color: isDark
                                      ? AppTokens.darkMuted
                                      : AppTokens.lightMuted),
                              const SizedBox(width: 4),
                              Text(
                                contact.phone!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppTokens.darkMuted
                                      : AppTokens.lightMuted,
                                ),
                              ),
                            ] else
                              Text(
                                'Đối tác tài chính',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppTokens.darkMuted
                                      : AppTokens.lightMuted,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Số dư ròng
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CurrencyText(
                        hasDebt
                            ? '${isReceivable ? '+' : '-'}${_formatCurrency(contact.netBalance.abs())}'
                            : '0 ₫',
                        style: currencyTextStyle(
                            context,
                            TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: contactColor,
                            )),
                      ),
                      Text(
                        hasDebt
                            ? (isReceivable ? 'Nợ bạn' : 'Bạn nợ')
                            : 'Đã sòng phẳng',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTokens.darkMuted
                              : AppTokens.lightMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),

                  PopupMenuButton<String>(
                    tooltip: 'Tùy chọn đối tác',
                    icon: Icon(Icons.more_horiz_rounded,
                        size: 20,
                        color: isDark
                            ? AppTokens.darkMuted
                            : AppTokens.lightMuted),
                    onSelected: (_) => _openContactEditModal(context, contact),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Sửa thông tin'))
                    ],
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
// 🌟 MODAL TẠO & CHỈNH SỬA HỒ SƠ ĐỐI TƯỢNG (_ContactEditModal)
// ==============================================================================

class _ContactEditModal extends ConsumerStatefulWidget {
  final DebtContact? contact;

  const _ContactEditModal({this.contact});

  @override
  ConsumerState<_ContactEditModal> createState() => _ContactEditModalState();
}

class _ContactEditModalState extends ConsumerState<_ContactEditModal> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  late String _avatarType; // 'INITIALS' | 'EMOJI'
  late String _avatarValue;
  late String _colorHex;
  bool _isSaving = false;
  final AppValidationFeedbackController _nameValidation =
      AppValidationFeedbackController();

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');

    // Giải mã cấu hình avatar từ avatarUrl
    final parsed = _ParsedAvatar.parse(c?.avatarUrl);
    _avatarType = parsed.type;
    _avatarValue = parsed.emoji;
    _colorHex = parsed.colorHex;

    // Lắng nghe thay đổi tên để Live Preview tự động cập nhật chữ cái đầu theo thời gian thực
    _nameController.addListener(() {
      if (mounted && _avatarType == 'INITIALS') {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameValidation.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _nameValidation.reject();
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final isEdit = widget.contact != null;
      final contactId = isEdit
          ? widget.contact!.id
          : 'contact_${DateTime.now().millisecondsSinceEpoch}';

      // Đóng gói avatarType, colorHex, avatarValue thành 1 chuỗi lưu vào avatarUrl
      final encodedAvatar = _avatarType == 'ICON'
          ? 'icon:$_avatarValue|$_colorHex'
          : '$_avatarType|$_colorHex|$_avatarValue';

      final phone = _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim();
      if (isEdit) {
        await db.updateDebtContactMetadata(
          id: contactId,
          name: name,
          phone: phone,
          avatarUrl: encodedAvatar,
        );
      } else {
        await db.upsertDebtContact(DebtContactsCompanion(
          id: drift.Value(contactId),
          name: drift.Value(name),
          phone: drift.Value(phone),
          avatarUrl: drift.Value(encodedAvatar),
          updatedAt: drift.Value(DateTime.now()),
        ));
      }

      if (!mounted) return;
      AppFeedback.showSuccess(
        context,
        isEdit
            ? 'Đã cập nhật hồ sơ "$name"'
            : 'Đã tạo hồ sơ "$name" thành công!',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(
        context,
        'Lỗi lưu hồ sơ: $e',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.contact != null;
    final primaryColor = _parseColor(_colorHex);

    return AppFeedbackDismissRegion(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151C28) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit
                            ? 'Chỉnh sửa hồ sơ đối tượng'
                            : 'Tạo hồ sơ đối tượng mới',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? AppTokens.darkText : AppTokens.lightText,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // =============================================================
                  // 🌟 TÍCH HỢP WIDGET CHỌN AVATAR ĐỘC LẬP (DebtContactAvatarPicker)
                  // =============================================================
                  DebtContactAvatarPicker(
                    avatarType: _avatarType,
                    avatarValue: _avatarValue,
                    colorHex: _colorHex,
                    contactName: _nameController.text,
                    onChanged: ({
                      required String avatarType,
                      required String avatarValue,
                      required String colorHex,
                    }) {
                      setState(() {
                        _avatarType = avatarType;
                        _avatarValue = avatarValue;
                        _colorHex = colorHex;
                      });
                    },
                  ),

                  const SizedBox(height: 18),

                  // Tên đối tượng (Bắt buộc)
                  AppValidationFeedback(
                    controller: _nameValidation,
                    builder: (context, visual) => _buildTextField(
                      controller: _nameController,
                      label: 'Tên đối tượng *',
                      hint: 'vd: Nam, Hải Anh, Chị Mai...',
                      icon: Icons.person_rounded,
                      isDark: isDark,
                      borderColor: visual.borderColor(
                        isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                      ),
                      onChanged: (_) => _nameValidation.clear(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Số điện thoại (Tùy chọn)
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Số điện thoại (Tùy chọn)',
                    hint: 'vd: 0987654321',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  // Nút Lưu Hồ Sơ
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 1,
                      ),
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white)),
                            )
                          : Text(
                              isEdit
                                  ? '✓ CẬP NHẬT HỒ SƠ'
                                  : '✓ TẠO HỒ SƠ ĐỐI TƯỢNG',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800),
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
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isDark = false,
    TextInputType? keyboardType,
    Color? borderColor,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(
          fontSize: 13,
          color: isDark ? AppTokens.darkText : AppTokens.lightText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            fontSize: 12,
            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
        hintText: hint,
        hintStyle: TextStyle(
            fontSize: 12,
            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
        prefixIcon: Icon(icon,
            size: 18,
            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: borderColor ??
                (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: borderColor ??
                (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
          ),
        ),
      ),
    );
  }
}
