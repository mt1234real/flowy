// ==============================================================================
// File: lib/widgets/category_tree_modal.dart
// Architecture: Dynamic 2-Tier Category Tree Modal with Drift SQLite Sync & Fluid Sheet Engine
// Stack: flutter_riverpod, drift, flutter/material.dart
// Features: Real-time SQLite sync, Dual-purpose mode (Transaction vs Budget Setup),
//           Parent group selection support (allowSelectParent), Fast Search Input,
//           40+ Icon Resolver, Selected Category Highlight Badge,
//           1:1 Fluid Drag Tracking via AppAnimationPolicy.showFluidSheet, ClampingScrollPhysics Navigation
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sliding_segmented_bar.dart';
import '../core/animation/app_animation_policy.dart';
import '../data/database.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

// StreamProvider tự động cập nhật danh mục từ Drift SQLite
final categoriesTreeStreamProvider = StreamProvider.autoDispose<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAvailableCategories();
});

class CategoryTreeModal extends ConsumerStatefulWidget {
  final CategoryType initialType;
  final String? selectedCategoryId;
  final bool allowSelectParent; // true cho Thiết lập Ngân Sách, false cho Ghi Chép Giao Dịch
  final String? title;
  final ScrollController? scrollController;

  const CategoryTreeModal({
    super.key,
    required this.initialType,
    this.selectedCategoryId,
    this.allowSelectParent = false,
    this.title,
    this.scrollController,
  });

  /// 🌟 MỞ MODAL QUA FLUID SHEET ENGINE TOÀN CỤC
  static Future<Category?> show(
      BuildContext context, {
        required CategoryType initialType,
        String? selectedCategoryId,
        bool allowSelectParent = false,
        String? title,
      }) {
    HapticFeedback.selectionClick();
    return AppAnimationPolicy.showFluidSheet<Category>(
      context: context,
      mode: FluidSheetMode.scrollable,
      useRootNavigator: true,
      isDismissible: true,
      builder: (sheetContext, scrollController) => CategoryTreeModal(
        initialType: initialType,
        selectedCategoryId: selectedCategoryId,
        allowSelectParent: allowSelectParent,
        title: title,
        scrollController: scrollController,
      ),
    );
  }

  @override
  ConsumerState<CategoryTreeModal> createState() => _CategoryTreeModalState();
}

class _CategoryTreeModalState extends ConsumerState<CategoryTreeModal> {
  late CategoryType _activeType;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedParentIds = {};

  @override
  void initState() {
    super.initState();
    _activeType = widget.initialType;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return const Color(0xFF10B981);
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  void _toggleExpand(String parentId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expandedParentIds.contains(parentId)) {
        _expandedParentIds.remove(parentId);
      } else {
        _expandedParentIds.add(parentId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final categoriesAsync = ref.watch(categoriesTreeStreamProvider);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151C28) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
            width: 1,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // ===============================================================
              // 1. DRAG HANDLE & HEADER
              // ===============================================================
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
              ),

              // Hàng Tiêu đề và nút đóng '✕'
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title ??
                              (widget.allowSelectParent
                                  ? 'Chọn Ngân Sách / Danh Mục'
                                  : 'Chọn Danh Mục Giao Dịch'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                        Text(
                          widget.allowSelectParent
                              ? 'Có thể chọn cả Nhóm Cha hoặc Danh Mục Con'
                              : 'Chọn danh mục phù hợp với khoản tiền',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                      onPressed: () {
                        if (mounted && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
              ),

              // 2. Segmented Tab Switcher: Khoản chi | Khoản thu | Vay nợ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: SlidingSegmentedBar<CategoryType>(
                  height: 40,
                  duration: const Duration(milliseconds: 185),
                  overshootPx: 1.8,
                  debugLabel: 'CategoryTree.typeTabs',
                  selectedValue: _activeType,
                  trackColor: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                  trackBorderColor: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                  indicatorColor: isDark ? AppTokens.darkCardSubtle : Colors.white,
                  indicatorBorderColor: Colors.transparent,
                  mutedTextColor: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                  indicatorShadowColor: Colors.black.withValues(alpha: 0.05),
                  items: const [
                    SlidingSegmentedItem<CategoryType>(
                      value: CategoryType.expense,
                      label: 'Khoản chi',
                      activeColor: AppTokens.expense,
                    ),
                    SlidingSegmentedItem<CategoryType>(
                      value: CategoryType.income,
                      label: 'Khoản thu',
                      activeColor: AppTokens.income,
                    ),
                    SlidingSegmentedItem<CategoryType>(
                      value: CategoryType.debt,
                      label: 'Vay / Nợ',
                      activeColor: AppTokens.debt,
                    ),
                  ],
                  onValueChanged: (type) {
                    setState(() => _activeType = type);
                  },
                ),
              ),

              // 3. Search Filter Field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Tìm nhanh danh mục (ăn uống, mua sắm, xăng)...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const Divider(height: 1),

              // ===============================================================
              // 4. DYNAMIC CATEGORY TREE (KẾT NỐI CONTROLLER VỚI FLUID ENGINE)
              // ===============================================================
              Expanded(
                child: categoriesAsync.when(
                  data: (allCategories) {
                    final typedCategories =
                    allCategories.where((c) => c.type == _activeType).toList();

                    final parentGroups = typedCategories
                        .where((c) => c.parentId == null || c.parentId!.isEmpty)
                        .toList();

                    final Map<String, List<Category>> childrenMap = {};
                    for (final c in typedCategories) {
                      if (c.parentId != null && c.parentId!.isNotEmpty) {
                        childrenMap.putIfAbsent(c.parentId!, () => []).add(c);
                      }
                    }

                    List<Category> displayedParents = parentGroups;
                    if (_searchQuery.isNotEmpty) {
                      displayedParents = parentGroups.where((p) {
                        final parentMatches = p.name.toLowerCase().contains(_searchQuery);
                        final children = childrenMap[p.id] ?? [];
                        final childrenMatch =
                        children.any((ch) => ch.name.toLowerCase().contains(_searchQuery));
                        return parentMatches || childrenMatch;
                      }).toList();
                    }

                    if (displayedParents.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 44,
                              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Không tìm thấy danh mục phù hợp',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: widget.scrollController,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: displayedParents.length,
                      itemBuilder: (context, index) {
                        final parent = displayedParents[index];
                        final allChildren = childrenMap[parent.id] ?? [];

                        final visibleChildren = _searchQuery.isEmpty
                            ? allChildren
                            : allChildren
                            .where((ch) =>
                        ch.name.toLowerCase().contains(_searchQuery) ||
                            parent.name.toLowerCase().contains(_searchQuery))
                            .toList();

                        final isExpanded =
                            _searchQuery.isNotEmpty || _expandedParentIds.contains(parent.id);
                        final isParentSelected = widget.selectedCategoryId == parent.id;
                        final parentColor = _parseColor(parent.color);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isDark ? AppTokens.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isParentSelected
                                  ? accent.primary
                                  : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                              width: isParentSelected ? 1.6 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // PARENT GROUP TILE
                              InkWell(
                                onTap: () {
                                  if (widget.allowSelectParent) {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(context).pop(parent);
                                  } else {
                                    _toggleExpand(parent.id);
                                  }
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: Padding(
                                  padding:
                                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: parentColor.withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          AppIcons.resolve(parent.icon),
                                          color: parentColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              parent.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? AppTokens.darkText
                                                    : AppTokens.lightText,
                                              ),
                                            ),
                                            Text(
                                              '${allChildren.length} danh mục con',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? AppTokens.darkMuted
                                                    : AppTokens.lightMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (widget.allowSelectParent)
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                          ),
                                          onPressed: () => _toggleExpand(parent.id),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                isExpanded ? 'Gập lại' : 'Chi tiết',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: accent.primary,
                                                ),
                                              ),
                                              Icon(
                                                isExpanded
                                                    ? Icons.keyboard_arrow_up_rounded
                                                    : Icons.keyboard_arrow_down_rounded,
                                                size: 16,
                                                color: accent.primary,
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          size: 20,
                                          color:
                                          isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              // CHILDREN LIST (Accordion Body)
                              if (isExpanded && visibleChildren.isNotEmpty) ...[
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF101622)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: const BorderRadius.vertical(
                                        bottom: Radius.circular(18)),
                                  ),
                                  child: Column(
                                    children: visibleChildren.map((child) {
                                      final isChildSelected =
                                          widget.selectedCategoryId == child.id;
                                      final childColor = _parseColor(child.color);

                                      return InkWell(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          Navigator.of(context).pop(child);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 10),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(
                                                color: isDark
                                                    ? AppTokens.darkBorder
                                                    : AppTokens.lightBorder,
                                                width: 0.6,
                                              ),
                                            ),
                                            color: isChildSelected
                                                ? accent.primary.withValues(alpha: 0.12)
                                                : Colors.transparent,
                                          ),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: childColor.withValues(alpha: 0.16),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  AppIcons.resolve(child.icon),
                                                  size: 16,
                                                  color: childColor,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  child.name,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: isChildSelected
                                                        ? FontWeight.w800
                                                        : FontWeight.w600,
                                                    color: isChildSelected
                                                        ? accent.primary
                                                        : (isDark
                                                        ? AppTokens.darkText
                                                        : AppTokens.lightText),
                                                  ),
                                                ),
                                              ),
                                              if (isChildSelected)
                                                Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: accent.primary,
                                                  ),
                                                  child: const Icon(
                                                    Icons.check_rounded,
                                                    size: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (err, _) => Center(
                    child: Text('Lỗi tải danh mục: $err',
                        style: const TextStyle(color: AppTokens.expense)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}