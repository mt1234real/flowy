// ==============================================================================
// File: lib/features/onboarding/widgets/step_wallet_widget.dart
// Architecture: Onboarding Step 1 - Initial Wealth Source Setup
// Stack: flutter, flutter_riverpod, intl
// Features:
// 1. Thanh tiến trình mini "1/3" phong cách viên thuốc (Pill Progress Badge).
// 2. Tiêu đề hướng dẫn thân thiện: "Hiện tại bạn đang có bao nhiêu tiền?".
// 3. Hai thẻ nhập số dư tài chính thông minh (Auto-Formatting dấu chấm phân tách hàng nghìn):
//    - 💵 Ví Tiền Mặt
//    - 💳 Tài Khoản Ngân Hàng chính
// 4. Nút "+ Thêm ví khác" mở rộng trường nhập ví Tiết Kiệm hoặc Ví Điện Tử.
// 5. Nút điều hướng: [ Tiếp tục ❯ ] và [ Để sau ] (mặc định số dư là 0 ₫).
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../controllers/onboarding_controller.dart';

import '../../../widgets/sliding_segmented_bar.dart';
class StepWalletWidget extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const StepWalletWidget({
    super.key,
    required this.onNext,
    required this.onSkip,
  });

  @override
  ConsumerState<StepWalletWidget> createState() => _StepWalletWidgetState();
}

class _StepWalletWidgetState extends ConsumerState<StepWalletWidget> {
  late final TextEditingController _cashController;
  late final TextEditingController _bankController;
  late final TextEditingController _extraWalletController;

  bool _showExtraWallet = false;
  String _extraWalletType = 'savings'; // 'savings' hoặc 'ewallet'

  final NumberFormat _formatter = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingControllerProvider);
    _cashController = TextEditingController(
      text: state.cashBalance > 0 ? _formatter.format(state.cashBalance.round()) : '',
    );
    _bankController = TextEditingController(
      text: state.bankBalance > 0 ? _formatter.format(state.bankBalance.round()) : '',
    );
    _extraWalletController = TextEditingController();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _bankController.dispose();
    _extraWalletController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val, void Function(double) updateCallback, TextEditingController controller) {
    final cleanDigits = val.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      updateCallback(0.0);
      controller.value = const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      return;
    }

    final double amount = double.tryParse(cleanDigits) ?? 0.0;
    updateCallback(amount);

    final formatted = _formatter.format(amount.round());
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = ref.watch(accentPresetProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Vùng định danh bước & Thanh tiến trình mini 1/3
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.primary.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'TIẾN TRÌNH 1/3',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: accent.primary,
                  ),
                ),
              ),
              Text(
                'Thiết lập ví',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            'Hiện tại bạn đang có\nbao nhiêu tiền?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.25,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            'Ước lượng nhanh số dư khả dụng, bạn có thể kiểm kê hoặc sửa lại bất cứ lúc nào.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
            ),
          ),
          const SizedBox(height: 24),

          // THẺ 1: VÍ TIỀN MẶT
          _buildWalletCard(
            title: 'Tiền mặt',
            subtitle: 'Tiền mặt trong bóp, ngăn kéo...',
            iconEmoji: '💵',
            iconColor: const Color(0xFF10B981),
            controller: _cashController,
            isDark: isDark,
            accent: accent,
            onChanged: (val) {
              _onAmountChanged(
                val,
                    (amt) => ref.read(onboardingControllerProvider.notifier).updateCashBalance(amt),
                _cashController,
              );
            },
          ),
          const SizedBox(height: 14),

          // THẺ 2: TÀI KHOẢN NGÂN HÀNG
          _buildWalletCard(
            title: 'Ngân hàng chính',
            subtitle: 'Tài khoản nhận lương, thanh toán...',
            iconEmoji: '💳',
            iconColor: const Color(0xFF0EA5E9),
            controller: _bankController,
            isDark: isDark,
            accent: accent,
            onChanged: (val) {
              _onAmountChanged(
                val,
                    (amt) => ref.read(onboardingControllerProvider.notifier).updateBankBalance(amt),
                _bankController,
              );
            },
          ),
          const SizedBox(height: 14),

          // THẺ MỞ RỘNG (NẾU BẤM + THÊM VÍ)
          if (_showExtraWallet) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTokens.darkCard : AppTokens.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accent.primary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(_extraWalletType == 'savings' ? '🐖' : '📱', style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text(
                            _extraWalletType == 'savings' ? 'Két Tiết kiệm' : 'Ví điện tử (Momo/ZaloPay)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppTokens.darkText : AppTokens.lightText,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          setState(() {
                            _showExtraWallet = false;
                            _extraWalletController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Toggle chọn loại ví mở rộng — shared preserved sliding engine
                  SlidingSegmentedBar<String>(
                    height: 40,
                    duration: const Duration(milliseconds: 185),
                    overshootPx: 1.6,
                    debugLabel: 'Onboarding.extraWalletType',
                    selectedValue: _extraWalletType,
                    trackColor: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
                    trackBorderColor: Colors.transparent,
                    indicatorColor: accent.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                    indicatorBorderColor: accent.primary,
                    selectedTextColor: accent.primary,
                    mutedTextColor: isDark ? AppTokens.darkText : AppTokens.lightText,
                    items: const [
                      SlidingSegmentedItem<String>(
                        value: 'savings',
                        label: 'Tiết kiệm',
                        leadingText: '🐖',
                      ),
                      SlidingSegmentedItem<String>(
                        value: 'ewallet',
                        label: 'Ví điện tử',
                        leadingText: '📱',
                      ),
                    ],
                    onValueChanged: (type) {
                      setState(() => _extraWalletType = type);
                    },
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _extraWalletController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (val) {
                      _onAmountChanged(
                        val,
                            (amt) {
                          final curBank = ref.read(onboardingControllerProvider).bankBalance;
                          ref.read(onboardingControllerProvider.notifier).updateBankBalance(curBank + amt);
                        },
                        _extraWalletController,
                      );
                    },
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTokens.darkText : AppTokens.lightText,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: '₫',
                      filled: true,
                      fillColor: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ] else ...[
            // Nút + Thêm ví khác
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: accent.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showExtraWallet = true);
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text(
                  '+ Thêm ví khác (Tiết kiệm, Ví điện tử)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),

          // Cụm Nút Hành Động
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.primary,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onNext();
              },
              child: const Text(
                'Tiếp tục ❯',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Center(
            child: TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                // Mặc định số dư là 0 ₫ và chuyển bước kế tiếp
                ref.read(onboardingControllerProvider.notifier).updateCashBalance(0.0);
                ref.read(onboardingControllerProvider.notifier).updateBankBalance(0.0);
                widget.onNext();
              },
              child: Text(
                'Để sau (Mặc định là 0 ₫)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard({
    required String title,
    required String subtitle,
    required String iconEmoji,
    required Color iconColor,
    required TextEditingController controller,
    required bool isDark,
    required AppAccentPreset accent,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTokens.darkCard : AppTokens.lightCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(iconEmoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? AppTokens.darkMuted.withValues(alpha: 0.5) : AppTokens.lightMuted.withValues(alpha: 0.5),
              ),
              suffixText: '₫',
              suffixStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: accent.primary,
              ),
              filled: true,
              fillColor: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: accent.primary, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }


}