// ==============================================================================
// File: lib/widgets/category_icon_badge.dart
// Architecture: Reusable Dynamic Category Icon & Color Badge
// Stack: flutter, drift
// Features: Dynamic Icon & Color Resolution (supports iconCode/icon name and colorValue/HEX),
//           Adaptive Opacity Border, Fallback to Semantic Expense/Income Arrows
// ==============================================================================

import 'package:flutter/material.dart';
import '../data/database.dart';
import '../screens/category_manager_screen.dart' show resolveAppIcon;

class CategoryIconBadge extends StatelessWidget {
  final Category? category;
  final bool isExpense;
  final double size;
  final double iconSize;

  const CategoryIconBadge({
    super.key,
    required this.category,
    this.isExpense = true,
    this.size = 40,
    this.iconSize = 20,
  });

  Color _resolveColor() {
    if (category == null) {
      return isExpense ? const Color(0xFFF43F5E) : const Color(0xFF10B981);
    }

    // 1. Nếu có thuộc tính hex color (String)
    final hexStr = category!.color;
    if (hexStr != null && hexStr.isNotEmpty) {
      try {
        final clean = hexStr.replaceAll('#', '');
        return Color(int.parse('FF$clean', radix: 16));
      } catch (_) {}
    }

    return isExpense ? const Color(0xFFF43F5E) : const Color(0xFF10B981);
  }

  IconData _resolveIconData() {
    if (category == null) {
      return isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    }

    // 1. Phân giải qua resolveAppIcon nếu category.icon có dữ liệu
    if (category!.icon != null && category!.icon!.isNotEmpty) {
      return resolveAppIcon(category!.icon);
    }

    return isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _resolveColor();
    final iconData = _resolveIconData();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(
          color: baseColor.withValues(alpha: 0.28),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          iconData,
          color: baseColor,
          size: iconSize,
        ),
      ),
    );
  }
}