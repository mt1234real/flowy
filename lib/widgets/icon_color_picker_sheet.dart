// ==============================================================================
// File: lib/widgets/icon_color_picker_sheet.dart
// Architecture: Production-Grade Rich Icon & Color Picker Modal Sheet
// Stack: flutter, flutter_riverpod
// Features: Live Dynamic Preview Banner, 12 Fintech Color Swatches,
//           Bilingual Keyword Search (VI/EN), Category Topic Chips, 5x4 Icon Grid
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/animation/app_animation_policy.dart';
import '../core/feedback/app_feedback.dart';

class IconColorResult {
  final IconData iconData;
  final String iconName;
  final Color color;
  final String hexColor;

  IconColorResult({
    required this.iconData,
    required this.iconName,
    required this.color,
    required this.hexColor,
  });
}

class IconColorPickerSheet extends StatefulWidget {
  final String? initialIconName;
  final String? initialHexColor;

  const IconColorPickerSheet({
    super.key,
    this.initialIconName,
    this.initialHexColor,
  });

  static Future<IconColorResult?> show(
      BuildContext context, {
        String? initialIconName,
        String? initialHexColor,
      }) {
    return AppAnimationPolicy.showFluidSheet<IconColorResult>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      backgroundColor: Colors.transparent,
      builder: (_, __) => IconColorPickerSheet(
        initialIconName: initialIconName,
        initialHexColor: initialHexColor,
      ),
    );
  }

  @override
  State<IconColorPickerSheet> createState() => _IconColorPickerSheetState();
}

class _IconItem {
  final String key;
  final String label;
  final IconData icon;
  final String topic;
  final List<String> keywords;

  const _IconItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.topic,
    required this.keywords,
  });
}

class _IconColorPickerSheetState extends State<IconColorPickerSheet> {
  // 12 Fintech/Pastel Color Swatches
  static const List<Map<String, dynamic>> _colorSwatches = [
    {'name': 'Emerald', 'hex': '#10B981', 'color': Color(0xFF10B981)},
    {'name': 'Amber', 'hex': '#F59E0B', 'color': Color(0xFFF59E0B)},
    {'name': 'Sky Blue', 'hex': '#0EA5E9', 'color': Color(0xFF0EA5E9)},
    {'name': 'Sakura Rose', 'hex': '#EC4899', 'color': Color(0xFFEC4899)},
    {'name': 'Indigo', 'hex': '#6366F1', 'color': Color(0xFF6366F1)},
    {'name': 'Violet', 'hex': '#8B5CF6', 'color': Color(0xFF8B5CF6)},
    {'name': 'Coral', 'hex': '#F43F5E', 'color': Color(0xFFF43F5E)},
    {'name': 'Teal', 'hex': '#14B8A6', 'color': Color(0xFF14B8A6)},
    {'name': 'Crimson', 'hex': '#EF4444', 'color': Color(0xFFEF4444)},
    {'name': 'Gold', 'hex': '#EAB308', 'color': Color(0xFFEAB308)},
    {'name': 'Mint', 'hex': '#34D399', 'color': Color(0xFF34D399)},
    {'name': 'Slate', 'hex': '#64748B', 'color': Color(0xFF64748B)},
  ];

  // 40+ Curated Material Icons with Bilingual Search Tags
  static const List<_IconItem> _allIcons = [
    // Ăn uống
    _IconItem(key: 'restaurant', label: 'Cơm / Ăn uống', icon: Icons.restaurant_rounded, topic: 'Ăn uống', keywords: ['com', 'an', 'food', 'restaurant', 'rice', 'bua']),
    _IconItem(key: 'local_cafe', label: 'Cà phê / Trà', icon: Icons.local_cafe_rounded, topic: 'Ăn uống', keywords: ['cafe', 'coffee', 'tra', 'tea', 'uong', 'drink']),
    _IconItem(key: 'local_bar', label: 'Bia / Tiệc', icon: Icons.local_bar_rounded, topic: 'Ăn uống', keywords: ['bia', 'beer', 'nhau', 'ruou', 'bar', 'party']),
    _IconItem(key: 'bakery_dining', label: 'Bánh ngọt', icon: Icons.bakery_dining_rounded, topic: 'Ăn uống', keywords: ['banh', 'cake', 'bread', 'an vat']),
    _IconItem(key: 'fastfood', label: 'Đồ ăn nhanh', icon: Icons.fastfood_rounded, topic: 'Ăn uống', keywords: ['fastfood', 'burger', 'pizza', 'ga ran']),

    // Xe cộ / Di chuyển
    _IconItem(key: 'directions_car', label: 'Ô tô / Taxi', icon: Icons.directions_car_rounded, topic: 'Xe cộ', keywords: ['oto', 'car', 'taxi', 'grab', 'be', 'xe']),
    _IconItem(key: 'two_wheeler', label: 'Xe máy / Xăng', icon: Icons.two_wheeler_rounded, topic: 'Xe cộ', keywords: ['xe may', 'moto', 'bike', 'xang', 'gas']),
    _IconItem(key: 'local_gas_station', label: 'Cây xăng', icon: Icons.local_gas_station_rounded, topic: 'Xe cộ', keywords: ['xang', 'oil', 'petrol', 'nhien lieu']),
    _IconItem(key: 'flight', label: 'Máy bay / Du lịch', icon: Icons.flight_rounded, topic: 'Xe cộ', keywords: ['may bay', 'flight', 'du lich', 'travel', 've']),
    _IconItem(key: 'commute', label: 'Xe buýt / Tàu', icon: Icons.commute_rounded, topic: 'Xe cộ', keywords: ['bus', 'tau', 'metro', 'xe cong cong']),

    // Nhà cửa / Hóa đơn
    _IconItem(key: 'home', label: 'Tiền nhà / Thuê', icon: Icons.home_rounded, topic: 'Nhà cửa', keywords: ['nha', 'home', 'house', 'rent', 'phong']),
    _IconItem(key: 'bolt', label: 'Tiền điện', icon: Icons.bolt_rounded, topic: 'Nhà cửa', keywords: ['dien', 'electric', 'power', 'hoa don']),
    _IconItem(key: 'water_drop', label: 'Tiền nước', icon: Icons.water_drop_rounded, topic: 'Nhà cửa', keywords: ['nuoc', 'water', 'hoa don']),
    _IconItem(key: 'wifi', label: 'Internet / Mạng', icon: Icons.wifi_rounded, topic: 'Nhà cửa', keywords: ['wifi', 'internet', 'mang', 'cuoc']),
    _IconItem(key: 'cleaning_services', label: 'Dọn dẹp', icon: Icons.cleaning_services_rounded, topic: 'Nhà cửa', keywords: ['don dep', 'clean', 'giat']),

    // Mua sắm
    _IconItem(key: 'shopping_bag', label: 'Mua sắm chung', icon: Icons.shopping_bag_rounded, topic: 'Mua sắm', keywords: ['mua', 'shopping', 'store', 'shop']),
    _IconItem(key: 'shopping_cart', label: 'Siêu thị / Chợ', icon: Icons.shopping_cart_rounded, topic: 'Mua sắm', keywords: ['sieu thi', 'cho', 'market', 'grocery']),
    _IconItem(key: 'checkroom', label: 'Quần áo / Giày', icon: Icons.checkroom_rounded, topic: 'Mua sắm', keywords: ['quan ao', 'clothes', 'fashion', 'thoi trang']),
    _IconItem(key: 'devices', label: 'Đồ điện tử', icon: Icons.devices_rounded, topic: 'Mua sắm', keywords: ['dien tu', 'phone', 'laptop', 'tech']),

    // Sức khỏe & Học tập
    _IconItem(key: 'medical_services', label: 'Thuốc / Bác sĩ', icon: Icons.medical_services_rounded, topic: 'Sức khỏe', keywords: ['thuoc', 'kham', 'doctor', 'hospital', 'benh']),
    _IconItem(key: 'fitness_center', label: 'Tập Gym / Thể thao', icon: Icons.fitness_center_rounded, topic: 'Sức khỏe', keywords: ['gym', 'fitness', 'sport', 'the duc']),
    _IconItem(key: 'school', label: 'Học tập / Khóa học', icon: Icons.school_rounded, topic: 'Sức khỏe', keywords: ['hoc', 'school', 'course', 'sach', 'book']),

    // Giải trí
    _IconItem(key: 'sports_esports', label: 'Game / Trò chơi', icon: Icons.sports_esports_rounded, topic: 'Giải trí', keywords: ['game', 'choi', 'nap the', 'play']),
    _IconItem(key: 'movie', label: 'Xem phim / Rạp', icon: Icons.movie_rounded, topic: 'Giải trí', keywords: ['phim', 'cinema', 'movie', 'netflix']),
    _IconItem(key: 'headphones', label: 'Âm nhạc / Spotify', icon: Icons.headphones_rounded, topic: 'Giải trí', keywords: ['nhac', 'music', 'spotify', 'headphone']),
    _IconItem(key: 'card_giftcard', label: 'Quà tặng / Mừng', icon: Icons.card_giftcard_rounded, topic: 'Giải trí', keywords: ['qua', 'gift', 'mung', 'cuoi', 'le']),

    // Tài chính / Thu nhập
    _IconItem(key: 'payments', label: 'Lương / Thu nhập', icon: Icons.payments_rounded, topic: 'Tài chính', keywords: ['luong', 'salary', 'income', 'tien']),
    _IconItem(key: 'trending_up', label: 'Đầu tư / Cổ phiếu', icon: Icons.trending_up_rounded, topic: 'Tài chính', keywords: ['dau tu', 'invest', 'stock', 'lai']),
    _IconItem(key: 'savings', label: 'Tiết kiệm / Heo', icon: Icons.savings_rounded, topic: 'Tài chính', keywords: ['tiet kiem', 'saving', 'heo', 'bank']),
    _IconItem(key: 'handshake', label: 'Vay / Mượn nợ', icon: Icons.handshake_rounded, topic: 'Tài chính', keywords: ['vay', 'no', 'muon', 'debt', 'loan']),
    _IconItem(key: 'receipt_long', label: 'Hóa đơn chung', icon: Icons.receipt_long_rounded, topic: 'Tài chính', keywords: ['hoa don', 'bill', 'receipt']),
  ];

  late Color _selectedColor;
  late String _selectedHex;
  late _IconItem _selectedIcon;

  String _searchQuery = '';
  String _selectedTopic = 'Tất cả';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _topics = [
    'Tất cả',
    'Ăn uống',
    'Xe cộ',
    'Nhà cửa',
    'Mua sắm',
    'Sức khỏe',
    'Giải trí',
    'Tài chính',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialHexColor != null && widget.initialHexColor!.isNotEmpty) {
      final hex = widget.initialHexColor!.replaceAll('#', '');
      _selectedHex = '#$hex';
      _selectedColor = Color(int.parse('FF$hex', radix: 16));
    } else {
      _selectedColor = _colorSwatches.first['color'] as Color;
      _selectedHex = _colorSwatches.first['hex'] as String;
    }

    _selectedIcon = _allIcons.firstWhere(
          (item) => item.key.toLowerCase() == widget.initialIconName?.toLowerCase(),
      orElse: () => _allIcons.first,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_IconItem> get _filteredIcons {
    return _allIcons.where((item) {
      final matchesTopic = _selectedTopic == 'Tất cả' || item.topic == _selectedTopic;
      if (!matchesTopic) return false;

      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase().trim();
      final inLabel = item.label.toLowerCase().contains(query);
      final inKey = item.key.toLowerCase().contains(query);
      final inKeywords = item.keywords.any((k) => k.contains(query));

      return inLabel || inKey || inKeywords;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLightColor = _selectedColor.computeLuminance() > 0.5;
    final iconContentColor = isLightColor ? Colors.black87 : Colors.white;

    return AppFeedbackDismissRegion(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151C28) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // 1. LIVE PREVIEW STICKY BANNER
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: _selectedColor.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            _selectedIcon.icon,
                            size: 30,
                            color: iconContentColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedIcon.label,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Mã màu: $_selectedHex • Chủ đề: ${_selectedIcon.topic}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. COLOR PALETTE SWATCHES ROW
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _colorSwatches.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final item = _colorSwatches[index];
                        final Color col = item['color'] as Color;
                        final String hex = item['hex'] as String;
                        final isSelected = _selectedHex == hex;

                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedColor = col;
                              _selectedHex = hex;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: col,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                              boxShadow: isSelected
                                  ? [
                                BoxShadow(
                                  color: col.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(
                              Icons.check_rounded,
                              color: col.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                              size: 20,
                            )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 3. SEARCH INPUT
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm icon (vd: cơm, grab, cafe, netflix, gym)...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
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

                  const SizedBox(height: 8),

                  // 4. TOPIC FILTER CHIPS
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _topics.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final topic = _topics[index];
                        final isSelected = _selectedTopic == topic;

                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTopic = topic);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _selectedColor.withValues(alpha: 0.18)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? _selectedColor : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              topic,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.white : _selectedColor)
                                    : (isDark ? Colors.white60 : Colors.black54),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 5. 5-COLUMN ICON GRID
                  Expanded(
                    child: _filteredIcons.isEmpty
                        ? Center(
                      child: Text(
                        'Không tìm thấy icon phù hợp với "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    )
                        : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      physics: const ClampingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _filteredIcons.length,
                      itemBuilder: (context, index) {
                        final item = _filteredIcons[index];
                        final isSelected = _selectedIcon.key == item.key;

                        return InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIcon = item);
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _selectedColor.withValues(alpha: 0.18)
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? _selectedColor : Colors.transparent,
                                width: 1.8,
                              ),
                            ),
                            child: Icon(
                              item.icon,
                              color: isSelected ? _selectedColor : (isDark ? Colors.white70 : Colors.black54),
                              size: 24,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 6. ACTION BAR CTA
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedColor,
                          foregroundColor: iconContentColor,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(context).pop(
                            IconColorResult(
                              iconData: _selectedIcon.icon,
                              iconName: _selectedIcon.key,
                              color: _selectedColor,
                              hexColor: _selectedHex,
                            ),
                          );
                        },
                        child: const Text(
                          '✓ CHỌN BIỂU TƯỢNG NÀY',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
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
}