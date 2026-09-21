// ==============================================================================
// File: lib/widgets/sliding_segmented_bar.dart
// Architecture: Universal Generic Sliding Segmented Bar with Preserved Motion
// Stack: flutter/material.dart, flutter/services.dart, flutter_riverpod
// Features:
// 1. Generic Multi-Segment Support (<T>):
//    - Hỗ trợ số lượng tab linh hoạt (2, 3, 4 hoặc N tabs) theo generic type <T>.
// 2. Preserved Mechanical Motion (Miễn nhiễm 0x animator scale trên HyperOS):
//    - Sử dụng explicit AnimationController qua AppAnimationPolicy.createController
//      sở hữu sẵn cờ AnimationBehavior.preserve.
//    - Thời lượng mặc định 185ms; hỗ trợ override duration/overshootPx theo từng màn hình.
// 3. Tách Lớp Chữ & Nền & Tự Động Đổi Màu Chữ (Smart Solid Background Text Contrast):
//    - Tự động kiểm tra độ mờ/alpha của activeBackgroundColor: nếu nền là màu đặc (>0.6)
//      thì chữ active tự động chuyển sang Colors.white, triệt tiêu lỗi chìm chữ.
// 4. Phản Hồi Xúc Giác Haptic & Riverpod Accent Synchronization:
//    - HapticFeedback.selectionClick() khi chạm tab chưa chọn.
//    - Đọc màu chủ đạo chuẩn xác qua ref.watch(accentPresetProvider).
// ==============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/animation/app_animation_policy.dart';
import '../theme/app_theme.dart';

// ============================================================================
// DATA MODEL
// ============================================================================

class SlidingSegmentedItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final String? leadingText;
  final Widget? trailing;
  final Color? activeColor;
  final Color? activeBackgroundColor;

  const SlidingSegmentedItem({
    required this.value,
    required this.label,
    this.icon,
    this.leadingText,
    this.trailing,
    this.activeColor,
    this.activeBackgroundColor,
  });
}

// ============================================================================
// WIDGET
// ============================================================================

class SlidingSegmentedBar<T> extends ConsumerStatefulWidget {
  final List<SlidingSegmentedItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;
  final double height;
  final double fontSize;
  final double iconSize;
  final String debugLabel;
  final Duration duration;
  final double overshootPx;

  // Optional visual overrides. Defaults preserve previous generic appearance.
  final Color? trackColor;
  final Color? trackBorderColor;
  final Color? indicatorColor;
  final Color? indicatorBorderColor;
  final Color? selectedTextColor;
  final Color? mutedTextColor;
  final Color? indicatorShadowColor;

  const SlidingSegmentedBar({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onValueChanged,
    this.height = 40.0,
    this.fontSize = 12.0,
    this.iconSize = 14.0,
    this.debugLabel = 'SlidingSegmentedBar',
    this.duration = const Duration(milliseconds: 185),
    this.overshootPx = 1.8,
    this.trackColor,
    this.trackBorderColor,
    this.indicatorColor,
    this.indicatorBorderColor,
    this.selectedTextColor,
    this.mutedTextColor,
    this.indicatorShadowColor,
  });

  @override
  ConsumerState<SlidingSegmentedBar<T>> createState() => _SlidingSegmentedBarState<T>();
}

class _SlidingSegmentedBarState<T> extends ConsumerState<SlidingSegmentedBar<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late double _fromVisualIndex;
  late int _targetIndex;
  late int _visualTargetIndex;

  @override
  void initState() {
    super.initState();
    final initialIndex = _indexOfValue(widget.selectedValue);
    final safeIndex = initialIndex >= 0 ? initialIndex : 0;
    _fromVisualIndex = safeIndex.toDouble();
    _targetIndex = safeIndex;
    _visualTargetIndex = safeIndex;

    _controller = AppAnimationPolicy.createController(
      vsync: this,
      duration: widget.duration,
      debugLabel: widget.debugLabel,
    );

    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant SlidingSegmentedBar<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    if (oldWidget.selectedValue != widget.selectedValue) {
      final newIdx = _indexOfValue(widget.selectedValue);
      if (newIdx >= 0 && newIdx != _visualTargetIndex) {
        _startMove(newIdx, notifyParent: false, haptic: false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexOfValue(T value, {List<SlidingSegmentedItem<T>>? list}) {
    final targetList = list ?? widget.items;
    return targetList.indexWhere((item) => item.value == value);
  }

  double _lerp(double a, double b, double t) {
    return a + ((b - a) * t);
  }

  double _resolveVisualIndex(double segmentWidth) {
    final rawT = _controller.value;
    if (!_controller.isAnimating || rawT >= 1.0) {
      return _targetIndex.toDouble();
    }

    final direction = (_targetIndex - _fromVisualIndex).sign.toDouble();
    final overshootInIndex = segmentWidth > 0
        ? (widget.overshootPx / segmentWidth) * direction
        : 0.0;

    final totalMs = math.max(1, widget.duration.inMilliseconds);
    final settleMs = math.min(40, math.max(1, totalMs - 1));
    final approachFraction = ((totalMs - settleMs) / totalMs).clamp(0.0, 1.0);
    if (rawT <= approachFraction) {
      final localT = (rawT / approachFraction).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(localT);
      final overshootTarget = _targetIndex + overshootInIndex;
      return _lerp(_fromVisualIndex, overshootTarget, eased);
    }

    final localT = ((rawT - approachFraction) / (1.0 - approachFraction))
        .clamp(0.0, 1.0);
    final eased = Curves.easeOutQuad.transform(localT);
    final overshootTarget = _targetIndex + overshootInIndex;
    return _lerp(overshootTarget, _targetIndex.toDouble(), eased);
  }

  void _startMove(
      int index, {
        required bool notifyParent,
        required bool haptic,
      }) {
    if (index == _targetIndex && !_controller.isAnimating) return;

    // Retarget từ đúng vị trí visual hiện tại nếu user chạm liên tiếp.
    // Segment width thật được cập nhật trong build; dùng index interpolation hiện tại
    // ở đây để không teleport về target cũ.
    final rawT = _controller.value;
    final settledGuess = _controller.isAnimating
        ? _lerp(_fromVisualIndex, _targetIndex.toDouble(), Curves.easeOutCubic.transform(rawT))
        : _targetIndex.toDouble();
    _fromVisualIndex = settledGuess;
    _targetIndex = index;
    _visualTargetIndex = index;

    if (haptic) HapticFeedback.selectionClick();
    _controller.forward(from: 0.0);

    if (notifyParent) {
      widget.onValueChanged(widget.items[index].value);
    }
  }

  Color _resolveActiveColor(SlidingSegmentedItem<T> item, AppAccentPreset accent) {
    return item.activeColor ?? accent.primary;
  }

  Color _resolveActiveBgColor(SlidingSegmentedItem<T> item, Color activeColor) {
    return item.activeBackgroundColor ?? activeColor.withValues(alpha: 0.16);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    if (count == 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    final fromIndexForColor = _fromVisualIndex.round().clamp(0, count - 1);
    final fromItem = widget.items[fromIndexForColor];
    final targetItem = widget.items[_targetIndex.clamp(0, count - 1)];

    final fromColor = _resolveActiveColor(fromItem, accent);
    final targetColor = _resolveActiveColor(targetItem, accent);

    final fromBg = _resolveActiveBgColor(fromItem, fromColor);
    final targetBg = _resolveActiveBgColor(targetItem, targetColor);

    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: widget.trackColor ?? (isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(
          color: widget.trackBorderColor ?? (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
          width: 1.0,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final double t = _controller.value;
              final double segmentWidth = constraints.maxWidth / count;
              final double visualIndex = _resolveVisualIndex(segmentWidth);

              final double alignX = count > 1
                  ? -1.0 + (visualIndex / (count - 1)) * 2.0
                  : 0.0;

              final Color currentBorderColor = Color.lerp(
                fromColor,
                targetColor,
                Curves.easeOut.transform(t),
              ) ?? targetColor;

              final Color currentBgColor = Color.lerp(
                fromBg,
                targetBg,
                Curves.easeOut.transform(t),
              ) ?? targetBg;

              return Stack(
                children: [
                  // =========================================================
                  // 🌟 LỚP 1: KHUNG VIÊN THUỐC TRƯỢT (PRESERVED MOTION PILL)
                  // =========================================================
                  Align(
                    alignment: Alignment(alignX, 0.0),
                    child: FractionallySizedBox(
                      widthFactor: 1.0 / count,
                      heightFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.indicatorColor ?? currentBgColor,
                          borderRadius: BorderRadius.circular(11.0),
                          border: Border.all(
                            color: widget.indicatorBorderColor ?? currentBorderColor,
                            width: widget.indicatorBorderColor == Colors.transparent ? 0.0 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.indicatorShadowColor ?? currentBorderColor.withValues(alpha: 0.12),
                              blurRadius: 4.0,
                              offset: const Offset(0.0, 1.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // =========================================================
                  // 🌟 LỚP 2: HÀNG NHÃN TEXT & ICON (INTERACTION LAYER)
                  // =========================================================
                  Row(
                    children: List.generate(count, (index) {
                      final item = widget.items[index];
                      final bool isSelected = item.value == widget.selectedValue;

                      // Tính khoảng cách thị giác từ viên thuốc đến tab hiện tại
                      final double distance = (visualIndex - index).abs();
                      final double activeProgress = (1.0 - distance).clamp(0.0, 1.0);

                      final Color itemActiveColor = _resolveActiveColor(item, accent);
                      final Color mutedColor = widget.mutedTextColor ??
                          (isDark ? AppTokens.darkMuted : AppTokens.lightMuted);

                      // 🌟 TỰ ĐỘNG ĐỔI MÀU CHỮ NẾU NỀN LÀ MÀU ĐẶC (SOLID BACKGROUND DETECTION)
                      final bool isSolidBg = item.activeBackgroundColor != null &&
                          item.activeBackgroundColor!.a > 0.6;
                      final Color selectedTextColor = widget.selectedTextColor ??
                          (isSolidBg ? Colors.white : itemActiveColor);

                      final Color textColor = Color.lerp(mutedColor, selectedTextColor, activeProgress) ?? mutedColor;
                      final FontWeight fontWeight = FontWeight.lerp(FontWeight.w600, FontWeight.w800, activeProgress) ?? FontWeight.w600;

                      return Expanded(
                        child: InkWell(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          borderRadius: BorderRadius.circular(11.0),
                          onTap: () {
                            if (!isSelected) {
                              _startMove(index, notifyParent: true, haptic: true);
                            }
                          },
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (item.leadingText != null) ...[
                                  Text(
                                    item.leadingText!,
                                    style: TextStyle(fontSize: widget.iconSize),
                                  ),
                                  const SizedBox(width: 5.0),
                                ] else if (item.icon != null) ...[
                                  Icon(
                                    item.icon,
                                    size: widget.iconSize,
                                    color: textColor,
                                  ),
                                  const SizedBox(width: 5.0),
                                ],
                                Flexible(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: widget.fontSize,
                                      fontWeight: fontWeight,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                if (item.trailing != null) ...[
                                  const SizedBox(width: 4.0),
                                  item.trailing!,
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}