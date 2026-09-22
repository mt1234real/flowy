// ==============================================================================
// File: lib/widgets/pre_purchase_advisor_sheet.dart
// Architecture: Pre-Purchase Decision Advisor & Dilemma Simulator (Behavioral UX Phase 2)
// Stack: flutter_riverpod, intl
// Features:
// 1. Dual-Tab Structure: [ 1 Món Đồ ] (Single Item) vs [ So Kèo A vs B ] (Dilemma Comparison)
// 2. Exact Behavioral Mathematical Engine (No Division by Zero Guard):
//    - %premium = ((pMax - pMin) / pMin) * 100% & kDiff = pMax / pMin
//    - %saved = ((pMax - pMin) / pMax) * 100%
//    - wA = (pA / bFree) * 100% & wB = (pB / bFree) * 100%
//    - deltaSA = pA / d -> %dropA = (deltaSA / sDaily) * 100% -> sNewA = sDaily - deltaSA
//    - deltaSB = pB / d -> %dropB = (deltaSB / sDaily) * 100% -> sNewB = sDaily - deltaSB
//    - dA = pA / sDaily & dB = pB / sDaily
//    - deltaP = abs(pA - pB)
// 3. UI Matrix:
//    - 2 Parallel Amount Input Boxes with Dynamic Focus & Correlation Badges
//    - 3-Row Comparison Grid (Tải trọng tháng, Tác động hàng ngày, Quy đổi ngày tiêu)
//    - Leverage Insight Box
//    - Triple Action Buttons: [ Chọn Món A ], [ Chọn Món B ], [ 🙅 Không mua món nào cả ]
// 4. Action Routing: Opens QuickEntrySheet with isAmortized = true and note prefilled
// ==============================================================================

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'sliding_segmented_bar.dart';
import '../core/feedback/app_feedback.dart';
import '../theme/app_theme.dart';
import 'quick_entry_sheet.dart';

enum AdvisorTab { single, dilemma }

class PrePurchaseAdvisorSheet extends ConsumerStatefulWidget {
  final double dailySafe; // S_daily: Mức chi an toàn hôm nay
  final int daysRemaining; // d: Số ngày còn lại trong chu kỳ
  final double freeBudgetRemaining; // B_free: Ngân sách tự do còn lại
  final ScrollController? scrollController;

  const PrePurchaseAdvisorSheet({
    super.key,
    required this.dailySafe,
    required this.daysRemaining,
    required this.freeBudgetRemaining,
    this.scrollController,
  });

  @override
  ConsumerState<PrePurchaseAdvisorSheet> createState() => _PrePurchaseAdvisorSheetState();
}

class _PrePurchaseAdvisorSheetState extends ConsumerState<PrePurchaseAdvisorSheet> {
  AdvisorTab _currentTab = AdvisorTab.single;

  // Single item controllers
  late final TextEditingController _singleNameController;
  String _singleAmountBuffer = '150000';

  // Dilemma item controllers
  late final TextEditingController _itemANameController;
  late final TextEditingController _itemBNameController;
  String _itemAAmountBuffer = '350000';
  String _itemBAmountBuffer = '180000';
  int _activeDilemmaInput = 0; // 0: Item A, 1: Item B

  @override
  void initState() {
    super.initState();
    _singleNameController = TextEditingController();
    _itemANameController = TextEditingController(text: 'Món A');
    _itemBNameController = TextEditingController(text: 'Món B');
  }

  @override
  void dispose() {
    _singleNameController.dispose();
    _itemANameController.dispose();
    _itemBNameController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount);
  }

  void _onNumpadPressSingle(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      if (key == 'C') {
        _singleAmountBuffer = '0';
      } else if (key == '⌫') {
        if (_singleAmountBuffer.length > 1) {
          _singleAmountBuffer = _singleAmountBuffer.substring(0, _singleAmountBuffer.length - 1);
        } else {
          _singleAmountBuffer = '0';
        }
      } else if (key == '000') {
        if (_singleAmountBuffer != '0' && _singleAmountBuffer.length <= 9) {
          _singleAmountBuffer += '000';
        }
      } else {
        if (_singleAmountBuffer == '0') {
          _singleAmountBuffer = key;
        } else if (_singleAmountBuffer.length <= 11) {
          _singleAmountBuffer += key;
        }
      }
    });
  }

  void _onNumpadPressDilemma(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      String target = _activeDilemmaInput == 0 ? _itemAAmountBuffer : _itemBAmountBuffer;

      if (key == 'C') {
        target = '0';
      } else if (key == '⌫') {
        if (target.length > 1) {
          target = target.substring(0, target.length - 1);
        } else {
          target = '0';
        }
      } else if (key == '000') {
        if (target != '0' && target.length <= 9) {
          target += '000';
        }
      } else {
        if (target == '0') {
          target = key;
        } else if (target.length <= 11) {
          target += key;
        }
      }

      if (_activeDilemmaInput == 0) {
        _itemAAmountBuffer = target;
      } else {
        _itemBAmountBuffer = target;
      }
    });
  }

  void _proceedToBuySingle(String itemName, double amount) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    QuickEntrySheet.show(
      context,
      initialContextDate: DateTime.now(),
      prefilledAmount: amount,
      prefilledDailySafe: widget.dailySafe,
    );
  }

  void _proceedToBuyDilemma(String chosenItemName, double amount) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    QuickEntrySheet.show(
      context,
      initialContextDate: DateTime.now(),
      prefilledAmount: amount,
      prefilledDailySafe: widget.dailySafe,
    );
  }

  void _cancelPurchase(double amount) {
    HapticFeedback.selectionClick();
    AppFeedback.showSuccess(
      context,
      '🎉 Bạn vừa giữ lại ${_formatCurrency(amount)} cho chu kỳ này.',
      emitHaptic: false,
      icon: Icons.celebration_rounded,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    return AppFeedbackDismissRegion(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151C28).withValues(alpha: 0.98) : Colors.white.withValues(alpha: 0.98),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                controller: widget.scrollController,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: accent.primary.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('⚖️', style: TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cân nhắc trước khi mua',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                                  ),
                                ),
                                Text(
                                  'Xem khoản này ảnh hưởng thế nào đến ngân sách',
                                  style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 2 Top Tabs: [ 1 món đồ ] vs [ So sánh 2 món ]
                    SlidingSegmentedBar<AdvisorTab>(
                      height: 42,
                      duration: const Duration(milliseconds: 190),
                      overshootPx: 1.8,
                      debugLabel: 'PrePurchaseAdvisor.topTabs',
                      selectedValue: _currentTab,
                      items: [
                        SlidingSegmentedItem<AdvisorTab>(
                          value: AdvisorTab.single,
                          label: '1 món đồ',
                          activeColor: Colors.white,
                          activeBackgroundColor: accent.primary,
                        ),
                        SlidingSegmentedItem<AdvisorTab>(
                          value: AdvisorTab.dilemma,
                          label: 'So sánh 2 món',
                          activeColor: Colors.white,
                          activeBackgroundColor: accent.primary,
                        ),
                      ],
                      onValueChanged: (tab) {
                        if (tab == _currentTab) return;
                        setState(() => _currentTab = tab);
                      },
                    ),
                    const SizedBox(height: 14),

                    if (_currentTab == AdvisorTab.single)
                      _buildSingleItemView(isDark, accent)
                    else
                      _buildDilemmaView(isDark, accent),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 🌟 TAB 1: THẨM ĐỊNH 1 MÓN ĐỒ (SINGLE ITEM VIEW)
  // ===========================================================================
  Widget _buildSingleItemView(bool isDark, AppAccentPreset accent) {
    final double p = double.tryParse(_singleAmountBuffer) ?? 0.0;
    final double sDaily = widget.dailySafe.isFinite
        ? math.max(0.0, widget.dailySafe)
        : 0.0;
    final int d = math.max(1, widget.daysRemaining);
    final double bFree = widget.freeBudgetRemaining.isFinite
        ? widget.freeBudgetRemaining
        : 0.0;

    final double deltaS = (p / d).floorToDouble();
    final double sNew = math.max(0.0, sDaily - deltaS);

    final bool isGreen = bFree > 0 && sDaily > 0 && p <= sDaily && p <= bFree;
    final bool isYellow = bFree > 0 && p > sDaily && p <= bFree;
    final bool isRed = bFree <= 0 || p > bFree;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _singleNameController,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? AppTokens.darkText : AppTokens.lightText),
          decoration: const InputDecoration(
            labelText: 'Tên món đồ (không bắt buộc)',
            hintText: 'Ví dụ: Tai nghe',
            prefixIcon: Icon(Icons.shopping_bag_outlined, size: 18),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppTokens.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isGreen
                  ? const Color(0xFF10B981)
                  : (isYellow ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E)),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Số tiền dự tính chi',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _buildStatusBadge(isGreen: isGreen, isYellow: isYellow, isRed: isRed),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatCurrency(p),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: isGreen
                      ? const Color(0xFF10B981)
                      : (isYellow ? const Color(0xFFF59E0B) : const Color(0xFFF43F5E)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isGreen) ...[
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Khoản chi nằm trọn trong hạn mức hôm nay (${_formatCurrency(sDaily)}).',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppTokens.darkText : AppTokens.lightText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Sau khi mua, hôm nay bạn vẫn còn lại ${_formatCurrency(sDaily - p)} khả chi. Các ngày tiếp theo hoàn toàn không bị ảnh hưởng!',
                  style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                ),
              ] else if (isYellow) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🏷️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chiếm ${((p / bFree) * 100).clamp(0, 999).toStringAsFixed(0)}% quỹ còn lại',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? AppTokens.darkText : AppTokens.lightText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📉', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sDaily <= 0
                            ? 'Không còn tiền an toàn để chi'
                            : 'Nếu dàn đều: Hạn mức mỗi ngày từ mai sẽ giảm từ ${_formatCurrency(sDaily)} ➔ ${_formatCurrency(sNew)}/ngày (mỗi ngày bớt ${_formatCurrency(deltaS)}).',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🛡️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ngân sách tự do chu kỳ vẫn an toàn còn ${_formatCurrency(bFree - p)} cho $d ngày tới.',
                        style: TextStyle(fontSize: 11, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    const Icon(Icons.dangerous_outlined, color: Color(0xFFF43F5E), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bFree <= 0
                            ? 'Đang hết ngân sách tự do\nKhông còn tiền an toàn để chi'
                            : 'Khoản này lớn hơn số tiền bạn còn lại trong chu kỳ. Nếu mua, bạn sẽ phải bù từ tiền sinh hoạt cố định.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppTokens.darkText : AppTokens.lightText),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        _buildNumpadGrid(isDark, _onNumpadPressSingle),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppTokens.darkText : AppTokens.lightText,
                    side: BorderSide(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _cancelPurchase(p),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Để sau', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRed ? const Color(0xFFF43F5E) : accent.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: p <= 0
                      ? null
                      : () => _proceedToBuySingle(_singleNameController.text.trim().isEmpty ? 'Món đồ mới' : _singleNameController.text.trim(), p),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isGreen ? 'Ghi chép giao dịch ngay' : 'Vẫn mua (Dàn đều các ngày)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge({required bool isGreen, required bool isYellow, required bool isRed}) {
    String text = 'Mua được!';
    Color color = const Color(0xFF10B981);
    if (isYellow) {
      text = 'Cân nhắc thêm: Sẽ giảm hạn mức các ngày tới';
      color = const Color(0xFFF59E0B);
    } else if (isRed) {
      text = 'Vượt ngân sách chu kỳ';
      color = const Color(0xFFF43F5E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  // ===========================================================================
  // 🌟 TAB 2: SO SÁNH 2 MÓN (TOÀN BỘ TOÁN HỌC & BỐ CỤC HOÀN CHỈNH)
  // ===========================================================================
  Widget _buildDilemmaView(bool isDark, AppAccentPreset accent) {
    final double pA = math.max(0.0, double.tryParse(_itemAAmountBuffer) ?? 0.0);
    final double pB = math.max(0.0, double.tryParse(_itemBAmountBuffer) ?? 0.0);
    final double sDaily = widget.dailySafe.isFinite
        ? math.max(0.0, widget.dailySafe)
        : 0.0;
    final int d = math.max(1, widget.daysRemaining);
    final double bFree = widget.freeBudgetRemaining.isFinite
        ? widget.freeBudgetRemaining
        : 0.0;

    // Xác định món đắt hơn và rẻ hơn
    final bool isAExp = pA > pB;
    final bool isBExp = pB > pA;
    final bool isEqual = (pA - pB).abs() < 1.0;

    final double pMax = math.max(pA, pB);
    final double pMin = math.min(pA, pB);

    // 1. Mức đắt hơn tương đối & hệ số gấp (kDiff)
    final double premiumPct = pMin > 0 ? ((pMax - pMin) / pMin) * 100.0 : 0.0;
    final double kDiff = pMin > 0 ? pMax / pMin : 1.0;

    // 2. Tỷ lệ tiết kiệm nếu chọn món rẻ hơn (%saved)
    final double savedPct = pMax > 0 ? ((pMax - pMin) / pMax) * 100.0 : 0.0;

    // 3. Tải trọng ngân sách (wA, wB) với clamp safe
    final double wA = bFree > 0 ? ((pA / bFree) * 100.0).clamp(0.0, 999.0) : 0.0;
    final double wB = bFree > 0 ? ((pB / bFree) * 100.0).clamp(0.0, 999.0) : 0.0;

    // 4. Mức giảm chi tiêu mỗi ngày nếu dàn đều
    final double deltaSA = (pA / d).floorToDouble();
    final double deltaSB = (pB / d).floorToDouble();
    final double sNewA = math.max(0.0, sDaily - deltaSA);
    final double sNewB = math.max(0.0, sDaily - deltaSB);

    // 5. Thặng dư tiền mặt bảo toàn
    final double deltaP = (pA - pB).abs();

    final String nameA = _itemANameController.text.trim().isEmpty ? 'Món A' : _itemANameController.text.trim();
    final String nameB = _itemBNameController.text.trim().isEmpty ? 'Món B' : _itemBNameController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // HÀNG NHẬP TÊN SONG SONG
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _itemANameController,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppTokens.darkText : AppTokens.lightText),
                decoration: const InputDecoration(
                  labelText: 'Tên Lựa Chọn A',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _itemBNameController,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? AppTokens.darkText : AppTokens.lightText),
                decoration: const InputDecoration(
                  labelText: 'Tên Lựa Chọn B',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // A. HEADER NHẬP SỐ TIỀN SONG SONG KÈM BADGE TƯƠNG QUAN
        Row(
          children: [
            // BOX NHẬP SỐ TIỀN MÓN A
            Expanded(
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeDilemmaInput = 0);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTokens.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _activeDilemmaInput == 0
                          ? accent.primary
                          : (isAExp ? const Color(0xFFF59E0B).withValues(alpha: 0.5) : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder)),
                      width: _activeDilemmaInput == 0 ? 2.0 : 1.0,
                    ),
                    boxShadow: _activeDilemmaInput == 0
                        ? [BoxShadow(color: accent.primary.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              nameA,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _activeDilemmaInput == 0 ? accent.primary : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                              ),
                            ),
                          ),
                          if (_activeDilemmaInput == 0)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: accent.primary, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatCurrency(pA),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // BADGE TƯƠNG QUAN MÓN A
                      if (!isEqual)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAExp
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isAExp
                                ? 'Đắt hơn ${_formatCurrency(deltaP)} (+${premiumPct.toStringAsFixed(0)}%)'
                                : 'Tiết kiệm ${_formatCurrency(deltaP)} (${savedPct.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isAExp ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            ),
                          ),
                        )
                      else
                        Text('Cùng mức giá', style: TextStyle(fontSize: 10, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // BOX NHẬP SỐ TIỀN MÓN B
            Expanded(
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeDilemmaInput = 1);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTokens.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _activeDilemmaInput == 1
                          ? const Color(0xFF10B981)
                          : (isBExp ? const Color(0xFFF59E0B).withValues(alpha: 0.5) : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder)),
                      width: _activeDilemmaInput == 1 ? 2.0 : 1.0,
                    ),
                    boxShadow: _activeDilemmaInput == 1
                        ? [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              nameB,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _activeDilemmaInput == 1 ? const Color(0xFF10B981) : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                              ),
                            ),
                          ),
                          if (_activeDilemmaInput == 1)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatCurrency(pB),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // BADGE TƯƠNG QUAN MÓN B
                      if (!isEqual)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isBExp
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isBExp
                                ? 'Đắt hơn ${_formatCurrency(deltaP)} (+${premiumPct.toStringAsFixed(0)}%)'
                                : 'Tiết kiệm ${_formatCurrency(deltaP)} (${savedPct.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isBExp ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            ),
                          ),
                        )
                      else
                        Text('Cùng mức giá', style: TextStyle(fontSize: 10, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // B. BẢNG LƯỚI SO SÁNH 2 TẦNG (CẮT BỎ HOÀN TOÀN MỤC QUY ĐỔI NGÀY SỐNG)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
          ),
          child: Column(
            children: [
              // HÀNG 1: ẢNH HƯỞNG CHU KỲ
              _buildMatrixRow(
                title: 'Ảnh hưởng chu kỳ',
                colA: bFree <= 0 ? 'Đang hết ngân sách tự do' : 'Chiếm ${wA.toStringAsFixed(0)}% quỹ còn lại',
                colB: bFree <= 0 ? 'Đang hết ngân sách tự do' : 'Chiếm ${wB.toStringAsFixed(0)}% quỹ còn lại',
                isDark: isDark,
                highlightA: isAExp,
                highlightB: isBExp,
              ),
              const Divider(height: 14),

              // HÀNG 2: HẠN MỨC MỖI NGÀY TỚI
              _buildMatrixRow(
                title: 'Hạn mức mỗi ngày tới',
                colA: bFree <= 0 || sDaily <= 0 ? 'Không còn tiền an toàn để chi' : 'Mỗi ngày tới giảm -${_formatCurrency(deltaSA)}\n(còn ${_formatCurrency(sNewA)}/ngày)',
                colB: bFree <= 0 || sDaily <= 0 ? 'Không còn tiền an toàn để chi' : 'Mỗi ngày tới giảm -${_formatCurrency(deltaSB)}\n(còn ${_formatCurrency(sNewB)}/ngày)',
                isDark: isDark,
                highlightA: isAExp,
                highlightB: isBExp,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // C. HỘP KẾT LUẬN ĐÒN BẨY (INSIGHT BOX)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      !isEqual
                          ? (isBExp
                          ? 'Chọn $nameA giúp bạn giữ lại ${savedPct.toStringAsFixed(0)}% số tiền (${_formatCurrency(deltaP)}).'
                          : 'Chọn $nameB giúp bạn giữ lại ${savedPct.toStringAsFixed(0)}% số tiền (${_formatCurrency(deltaP)}).')
                          : 'Hai món có chi phí ngang nhau, hãy cân nhắc theo giá trị sử dụng lâu dài.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? AppTokens.darkText : AppTokens.lightText),
                    ),
                  ),
                ],
              ),
              if (!isEqual && kDiff > 1.05) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    isAExp
                        ? '$nameA phải chi gấp ${kDiff.toStringAsFixed(1)} lần so với $nameB.'
                        : '$nameB phải chi gấp ${kDiff.toStringAsFixed(1)} lần so với $nameA.',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        _buildNumpadGrid(isDark, _onNumpadPressDilemma),
        const SizedBox(height: 12),

        // D. BỘ BA NÚT HÀNH ĐỘNG Ở ĐÁY (ACTION ROW)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF43F5E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: pA <= 0 ? null : () => _proceedToBuyDilemma(nameA, pA),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Mua $nameA (${_formatCurrency(pA)})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: pB <= 0 ? null : () => _proceedToBuyDilemma(nameB, pB),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Mua $nameB (${_formatCurrency(pB)})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // HÀNG DƯỚI: NÚT VIỀN TOÀN CHIỀU NGANG
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? AppTokens.darkText : AppTokens.lightText,
              side: BorderSide(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _cancelPurchase(math.max(pA, pB)),
            child: const Text('Không mua món nào', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildMatrixRow({
    required String title,
    required String colA,
    required String colB,
    required bool isDark,
    required bool highlightA,
    required bool highlightB,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                colA,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: highlightA ? FontWeight.w800 : FontWeight.w600,
                  color: highlightA ? const Color(0xFFF59E0B) : (isDark ? AppTokens.darkText : AppTokens.lightText),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                colB,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: highlightB ? FontWeight.w800 : FontWeight.w600,
                  color: highlightB ? const Color(0xFFF59E0B) : (isDark ? AppTokens.darkText : AppTokens.lightText),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNumpadGrid(bool isDark, Function(String) onKey) {
    final keys = [
      ['1', '2', '3', '⌫'],
      ['4', '5', '6', 'C'],
      ['7', '8', '9', '000'],
      ['', '0', '', ''],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: row.map((k) {
              if (k.isEmpty) return const Expanded(child: SizedBox());
              final isAction = k == '⌫' || k == 'C';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: InkWell(
                    onTap: () => onKey(k),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? AppTokens.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                      ),
                      child: Center(
                        child: isAction
                            ? (k == '⌫'
                            ? const Icon(Icons.backspace_outlined, size: 16)
                            : const Text('C', style: TextStyle(fontWeight: FontWeight.bold)))
                            : Text(k, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}