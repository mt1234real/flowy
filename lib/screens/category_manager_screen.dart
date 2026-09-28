// ==============================================================================
// File: lib/screens/category_manager_screen.dart
// Architecture: 2-Tier Category Manager with Tap-to-Edit & Reversible Archive
// Stack: flutter_riverpod, drift, flutter_slidable
// Features: Unified 40+ Icon Resolver, Full Drift CRUD, Integrated Icon & Color Picker,
//           Parent-Child Dropdown Picker, Transaction Constraint Validation on Delete
// ==============================================================================

import 'dart:ui';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/preserved_sleek_dismissible.dart';
import '../widgets/archived_entities_sheet.dart';

import '../widgets/sliding_segmented_bar.dart';
import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';
import '../data/database.dart';
import '../theme/app_theme.dart';
import '../widgets/icon_color_picker_sheet.dart';

// StreamProvider lấy toàn bộ danh mục từ database Drift SQLite
final allCategoriesStreamProvider =
    StreamProvider.autoDispose<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAvailableCategories();
});

// ==============================================================================
// 🌟 UNIFIED TOP-LEVEL ICON RESOLVER (Supports 40+ Curated Icons)
// ==============================================================================
IconData resolveAppIcon(String? iconName) {
  if (iconName == null || iconName.isEmpty) return Icons.folder_open_rounded;

  switch (iconName.toLowerCase()) {
    // Ăn uống
    case 'restaurant':
    case 'food':
      return Icons.restaurant_rounded;
    case 'local_cafe':
    case 'cafe':
    case 'coffee':
      return Icons.local_cafe_rounded;
    case 'local_bar':
    case 'bar':
    case 'beer':
      return Icons.local_bar_rounded;
    case 'bakery_dining':
    case 'bakery':
    case 'cake':
      return Icons.bakery_dining_rounded;
    case 'fastfood':
      return Icons.fastfood_rounded;

    // Xe cộ / Di chuyển
    case 'directions_car':
    case 'car':
    case 'transport':
    case 'taxi':
      return Icons.directions_car_rounded;
    case 'two_wheeler':
    case 'bike':
    case 'motorcycle':
      return Icons.two_wheeler_rounded;
    case 'local_gas_station':
    case 'gas':
    case 'fuel':
      return Icons.local_gas_station_rounded;
    case 'flight':
    case 'travel':
      return Icons.flight_rounded;
    case 'commute':
    case 'bus':
    case 'train':
      return Icons.commute_rounded;

    // Nhà cửa / Hóa đơn
    case 'home':
    case 'house':
    case 'rent':
      return Icons.home_rounded;
    case 'bolt':
    case 'electric':
    case 'power':
      return Icons.bolt_rounded;
    case 'water_drop':
    case 'water':
      return Icons.water_drop_rounded;
    case 'wifi':
    case 'internet':
      return Icons.wifi_rounded;
    case 'cleaning_services':
    case 'clean':
      return Icons.cleaning_services_rounded;

    // Mua sắm
    case 'shopping_bag':
    case 'shopping':
    case 'shop':
      return Icons.shopping_bag_rounded;
    case 'shopping_cart':
    case 'market':
    case 'grocery':
      return Icons.shopping_cart_rounded;
    case 'checkroom':
    case 'clothes':
    case 'fashion':
      return Icons.checkroom_rounded;
    case 'devices':
    case 'phone':
    case 'laptop':
      return Icons.devices_rounded;

    // Sức khỏe & Học tập
    case 'medical_services':
    case 'health':
    case 'medicine':
    case 'doctor':
      return Icons.medical_services_rounded;
    case 'fitness_center':
    case 'gym':
    case 'fitness':
    case 'sport':
      return Icons.fitness_center_rounded;
    case 'school':
    case 'education':
    case 'course':
    case 'book':
      return Icons.school_rounded;

    // Giải trí
    case 'sports_esports':
    case 'game':
    case 'entertainment':
      return Icons.sports_esports_rounded;
    case 'movie':
    case 'cinema':
    case 'film':
      return Icons.movie_rounded;
    case 'headphones':
    case 'music':
    case 'audio':
      return Icons.headphones_rounded;
    case 'card_giftcard':
    case 'gift':
      return Icons.card_giftcard_rounded;

    // Tài chính / Thu nhập
    case 'payments':
    case 'salary':
    case 'income':
      return Icons.payments_rounded;
    case 'trending_up':
    case 'investment':
    case 'stock':
      return Icons.trending_up_rounded;
    case 'savings':
    case 'saving':
    case 'bank':
      return Icons.savings_rounded;
    case 'handshake':
    case 'debt':
    case 'loan':
      return Icons.handshake_rounded;
    case 'receipt_long':
    case 'bill':
    case 'receipt':
      return Icons.receipt_long_rounded;

    default:
      return Icons.folder_open_rounded;
  }
}

class CategoryManagerScreen extends ConsumerStatefulWidget {
  const CategoryManagerScreen({super.key});

  @override
  ConsumerState<CategoryManagerScreen> createState() =>
      _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends ConsumerState<CategoryManagerScreen> {
  CategoryType _activeType = CategoryType.expense;

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return const Color(0xFF10B981);
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  // Mở Modal Thêm hoặc Chỉnh sửa danh mục
  Future<void> _openAddOrEditCategoryModal([Category? editingCategory]) async {
    HapticFeedback.selectionClick();
    final isEditing = editingCategory != null;

    final db = ref.read(databaseProvider);
    final allCats =
        await (db.select(db.categories)..where(db.categoryAvailable)).get();
    final parentOptions = allCats
        .where((c) =>
            c.type == _activeType &&
            (c.parentId == null || c.parentId!.isEmpty))
        .toList();

    if (!mounted) return;

    AppAnimationPolicy.showFluidSheet(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => _CategoryFormModal(
        isEditing: isEditing,
        initialCategory: editingCategory,
        activeType: _activeType,
        parentOptions: parentOptions,
      ),
    );
  }

  Future<bool> _confirmArchiveCategory(Category category) async {
    final db = ref.read(databaseProvider);
    if (category.isSystem) {
      AppFeedback.showInfo(context, 'Danh mục hệ thống cần được giữ lại.');
      return false;
    }
    final children = await (db.select(db.categories)
          ..where((c) => c.parentId.equals(category.id)))
        .get();
    final ids = [category.id, ...children.map((c) => c.id)];
    final txs = await (db.select(db.transactions)
          ..where((t) => t.categoryId.isIn(ids)))
        .get();
    if (!mounted) return false;
    if (children.any((c) => c.isSystem)) {
      AppFeedback.showInfo(
          context, 'Nhóm này chứa danh mục hệ thống cần được giữ lại.');
      return false;
    }
    if (txs.isEmpty && children.isEmpty) return true;
    return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('Lưu trữ danh mục?'),
                  content: Text(
                      'Ẩn “${category.name}”${children.isEmpty ? '' : ' và các mục con'} khỏi danh sách chọn. Lịch sử giao dịch và ngân sách vẫn được giữ nguyên.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Để lại')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Lưu trữ')),
                  ],
                )) ??
        false;
  }

  Future<void> _archiveCategory(Category category) async {
    final db = ref.read(databaseProvider);
    try {
      await db.archiveEntity('category', category.id);
    } catch (_) {
      if (mounted) {
        AppFeedback.showInfo(
            context, 'Chưa lưu trữ được danh mục. Vui lòng thử lại.');
      }
      rethrow;
    }
    if (!mounted) return;
    AppFeedback.showUndo(context,
        message: 'Đã lưu trữ “${category.name}”',
        onUndo: () => db.restoreArchivedEntity('category', category.id));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final categoriesAsync = ref.watch(allCategoriesStreamProvider);

    return AppFeedbackDismissRegion(
      child: Scaffold(
        backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
        appBar: AppBar(
          backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
                tooltip: 'Đã lưu trữ',
                icon: const Icon(Icons.inventory_2_outlined),
                onPressed: () => showArchivedEntities(
                    context, ref.read(databaseProvider), 'category'))
          ],
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Quản lý danh mục',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Sticky Segmented Tab Bar — shared preserved sliding engine
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: SlidingSegmentedBar<CategoryType>(
                  height: 40,
                  duration: const Duration(milliseconds: 185),
                  overshootPx: 1.8,
                  debugLabel: 'CategoryManager.typeTabs',
                  selectedValue: _activeType,
                  trackColor:
                      isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
                  trackBorderColor:
                      isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                  indicatorColor:
                      isDark ? AppTokens.darkCardSubtle : Colors.white,
                  indicatorBorderColor: Colors.transparent,
                  mutedTextColor:
                      isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
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

              // 2. 2-Tier Accordion Categories List
              Expanded(
                child: categoriesAsync.when(
                  data: (allCategories) {
                    final filtered = allCategories
                        .where((c) => c.type == _activeType)
                        .toList();
                    final parentCategories = filtered
                        .where((c) => c.parentId == null || c.parentId!.isEmpty)
                        .toList();

                    final Map<String, List<Category>> childrenMap = {};
                    for (final c in filtered) {
                      if (c.parentId != null && c.parentId!.isNotEmpty) {
                        childrenMap.putIfAbsent(c.parentId!, () => []).add(c);
                      }
                    }

                    if (parentCategories.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 48,
                              color: isDark
                                  ? AppTokens.darkMuted
                                  : AppTokens.lightMuted,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Chưa có danh mục nào trong nhóm này',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppTokens.darkMuted
                                    : AppTokens.lightMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                      itemCount: parentCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final parent = parentCategories[index];
                        final children = childrenMap[parent.id] ?? [];
                        final parentColor = _parseColor(parent.color);

                        return _buildParentAccordionCard(
                          parent: parent,
                          children: children,
                          parentColor: parentColor,
                          isDark: isDark,
                          accent: accent,
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (err, _) => Center(
                    child: Text('Lỗi tải danh mục: $err',
                        style: const TextStyle(color: AppTokens.expense)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Floating Action Button: + Thêm danh mục
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: accent.primary,
          foregroundColor: Colors.white,
          elevation: 3,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            'Thêm danh mục',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
          ),
          onPressed: () => _openAddOrEditCategoryModal(),
        ),
      ),
    );
  }

  final Set<String> _expandedCategories = {};

  Widget _buildParentAccordionCard({
    required Category parent,
    required List<Category> children,
    required Color parentColor,
    required bool isDark,
    required AppAccentPreset accent,
  }) {
    return PreservedSleekDismissible(
      key: ValueKey(parent.id),
      borderRadius: 18,
      label: 'Lưu trữ',
      icon: Icons.archive_outlined,
      confirmDismiss: () => _confirmArchiveCategory(parent),
      onDismissed: () => _archiveCategory(parent),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTokens.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Column(children: [
            ListTile(
              onTap: () => _openAddOrEditCategoryModal(parent),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: parentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  resolveAppIcon(parent.icon),
                  color: parentColor,
                  size: 22,
                ),
              ),
              title: Text(
                parent.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                ),
              ),
              subtitle: Text(
                '${children.length} mục con',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                ),
              ),
              trailing: IconButton(
                tooltip: _expandedCategories.contains(parent.id)
                    ? 'Thu gọn'
                    : 'Xem mục con',
                icon: Icon(_expandedCategories.contains(parent.id)
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded),
                onPressed: () => setState(() {
                  if (!_expandedCategories.add(parent.id)) {
                    _expandedCategories.remove(parent.id);
                  }
                }),
              ),
            ),
            if (_expandedCategories.contains(parent.id)) ...[
              if (children.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
                  child: Text(
                    'Chưa có mục con. Chọn Thêm danh mục để tạo mới.',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color:
                          isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                    ),
                  ),
                )
              else
                ...children
                    .map((child) => _buildChildCategoryItem(child, isDark)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildChildCategoryItem(Category child, bool isDark) {
    final childColor = _parseColor(child.color);

    return PreservedSleekDismissible(
      key: ValueKey(child.id),
      borderRadius: 0,
      label: 'Lưu trữ',
      icon: Icons.archive_outlined,
      confirmDismiss: () => _confirmArchiveCategory(child),
      onDismissed: () => _archiveCategory(child),
      child: InkWell(
          onTap: () => _openAddOrEditCategoryModal(child),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111722) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                  width: 0.6,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: childColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    resolveAppIcon(child.icon),
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
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                    ),
                  ),
                ),
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 18,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ],
            ),
          )),
    );
  }
}

// ==============================================================================
// 🌟 MODAL BOTTOM SHEET: TẠO MỚI / CHỈNH SỬA DANH MỤC
// ==============================================================================

class _CategoryFormModal extends ConsumerStatefulWidget {
  final bool isEditing;
  final Category? initialCategory;
  final CategoryType activeType;
  final List<Category> parentOptions;

  const _CategoryFormModal({
    required this.isEditing,
    this.initialCategory,
    required this.activeType,
    required this.parentOptions,
  });

  @override
  ConsumerState<_CategoryFormModal> createState() => _CategoryFormModalState();
}

class _CategoryFormModalState extends ConsumerState<_CategoryFormModal> {
  late final TextEditingController _nameController;
  late bool _isChildCategory;
  String? _selectedParentId;
  String _selectedIconName = 'restaurant';
  String _selectedHexColor = '#10B981';

  bool _isSaving = false;
  final AppValidationFeedbackController _nameFeedback =
      AppValidationFeedbackController();

  @override
  void initState() {
    super.initState();
    final cat = widget.initialCategory;

    if (cat != null) {
      _nameController = TextEditingController(text: cat.name);
      _isChildCategory = cat.parentId != null && cat.parentId!.isNotEmpty;
      _selectedParentId = cat.parentId;
      _selectedIconName = cat.icon ?? 'restaurant';
      _selectedHexColor = cat.color ?? '#10B981';
    } else {
      _nameController = TextEditingController();
      _isChildCategory = false;
      _selectedParentId = widget.parentOptions.isNotEmpty
          ? widget.parentOptions.first.id
          : null;
    }
  }

  @override
  void dispose() {
    _nameFeedback.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Color _resolveColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }

  Future<void> _pickIconAndColor() async {
    final result = await IconColorPickerSheet.show(
      context,
      initialIconName: _selectedIconName,
      initialHexColor: _selectedHexColor,
    );

    if (result != null && mounted) {
      setState(() {
        _selectedIconName = result.iconName;
        _selectedHexColor = result.hexColor;
      });
    }
  }

  Future<void> _saveCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _nameFeedback.reject();
      return;
    }

    _nameFeedback.clear();

    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);

    try {
      final parentId = _isChildCategory ? _selectedParentId : null;

      if (widget.isEditing) {
        // Cập nhật danh mục
        await (db.update(db.categories)
              ..where((c) => c.id.equals(widget.initialCategory!.id)))
            .write(
          CategoriesCompanion(
            name: drift.Value(name),
            icon: drift.Value(_selectedIconName),
            color: drift.Value(_selectedHexColor),
            parentId: drift.Value(parentId),
          ),
        );
      } else {
        // Tạo mới danh mục
        final newId = 'cat_${DateTime.now().millisecondsSinceEpoch}';
        await db.into(db.categories).insert(
              CategoriesCompanion.insert(
                id: newId,
                name: name,
                type: widget.activeType,
                parentId: drift.Value(parentId),
                icon: drift.Value(_selectedIconName),
                color: drift.Value(_selectedHexColor),
              ),
            );
      }

      if (!mounted) return;

      AppFeedback.showSuccess(
        context,
        widget.isEditing ? 'Đã cập nhật danh mục' : 'Đã tạo danh mục mới',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, 'Lỗi: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);
    final activeColor = _resolveColor(_selectedHexColor);

    return AppFeedbackDismissRegion(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: EdgeInsets.fromLTRB(
                20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151C28) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
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
                          color: isDark ? Colors.white24 : Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Header
                    Text(
                      widget.isEditing
                          ? 'Chỉnh sửa danh mục'
                          : 'Thêm danh mục mới',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? AppTokens.darkText : AppTokens.lightText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. Phân loại 2 cấp: Nhóm Cha vs Danh Mục Con
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTokens.darkCardSubtle
                            : AppTokens.lightCardSubtle,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _isChildCategory = false),
                              borderRadius: BorderRadius.circular(11),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !_isChildCategory
                                      ? (isDark
                                          ? AppTokens.darkCard
                                          : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Center(
                                  child: Text(
                                    'Nhóm Cha',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: !_isChildCategory
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: !_isChildCategory
                                          ? (isDark
                                              ? AppTokens.darkText
                                              : AppTokens.lightText)
                                          : (isDark
                                              ? AppTokens.darkMuted
                                              : AppTokens.lightMuted),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _isChildCategory = true),
                              borderRadius: BorderRadius.circular(11),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _isChildCategory
                                      ? (isDark
                                          ? AppTokens.darkCard
                                          : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Center(
                                  child: Text(
                                    'Danh Mục Con',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _isChildCategory
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: _isChildCategory
                                          ? (isDark
                                              ? AppTokens.darkText
                                              : AppTokens.lightText)
                                          : (isDark
                                              ? AppTokens.darkMuted
                                              : AppTokens.lightMuted),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Nếu là danh mục con -> Hiển thị Dropdown chọn nhóm cha
                    if (_isChildCategory) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Trực thuộc nhóm cha:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppTokens.darkMuted
                              : AppTokens.lightMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTokens.darkCard
                              : AppTokens.lightCardSubtle,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? AppTokens.darkBorder
                                : AppTokens.lightBorder,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedParentId,
                            dropdownColor:
                                isDark ? AppTokens.darkCard : Colors.white,
                            items: widget.parentOptions.map((p) {
                              return DropdownMenuItem<String>(
                                value: p.id,
                                child: Text(
                                  p.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppTokens.darkText
                                        : AppTokens.lightText,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedParentId = val),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // 3. Avatar Squircle + Tên danh mục Input
                    Row(
                      children: [
                        InkWell(
                          onTap: _pickIconAndColor,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: activeColor,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  resolveAppIcon(_selectedIconName),
                                  color: activeColor.computeLuminance() > 0.5
                                      ? Colors.black87
                                      : Colors.white,
                                  size: 28,
                                ),
                                Positioned(
                                  right: 3,
                                  bottom: 3,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit,
                                        size: 10, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AppValidationFeedback(
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
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppTokens.darkText
                                      : AppTokens.lightText,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Tên danh mục (vd: Ăn uống, Cafe)...',
                                  hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppTokens.darkMuted
                                        : AppTokens.lightMuted,
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? AppTokens.darkCard
                                      : AppTokens.lightCardSubtle,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(
                                      color: borderColor,
                                      width: visual.isInvalid ? 1.8 : 1.0,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
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
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 4. Nút Lưu
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        onPressed: _isSaving ? null : _saveCategory,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                widget.isEditing
                                    ? 'LƯU THAY ĐỔI'
                                    : 'TẠO DANH MỤC',
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
      ),
    );
  }
}
