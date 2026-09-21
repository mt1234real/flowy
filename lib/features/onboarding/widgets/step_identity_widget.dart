// ==============================================================================
// File: lib/features/onboarding/widgets/step_identity_widget.dart
// Architecture: Onboarding Step 0 - Identity, Google Link & Instant Style Studio
// Stack: flutter, flutter_riverpod, google_fonts
// Features:
// 1. Nhập tên / biệt danh với TextField bo tròn 18dp thân thiện.
// 2. Nút "Tiếp tục với Google" kết nối OnboardingController quét backup Drive tự động.
// 3. Instant Style Studio (Đổi màu & phông chữ thời gian thực ngay tại màn hình):
//    - Chế độ Giao diện: 2 Pill Toggle [ ☀️ Sáng ] / [ 🌙 Tối ] kết nối themeModeProvider.
//    - 5 Màu Thiên Nhiên (Cỏ, Nắng, Biển, Hoa, Đêm) với dải Squircle phản ứng tức thì.
//    - 3 Họ phông chữ bo tròn đáng yêu (Comfortaa, Nunito, Plus Jakarta Sans) kết nối fontFamilyProvider.
// 4. Các nút điều hướng: [ BẮT ĐẦU THIẾT LẬP (30s) ❯ ] và [ Bỏ qua, vào app ngay ].
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../controllers/onboarding_controller.dart';

import '../../../widgets/sliding_segmented_bar.dart';
class StepIdentityWidget extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const StepIdentityWidget({
    super.key,
    required this.onNext,
    required this.onSkip,
  });

  @override
  ConsumerState<StepIdentityWidget> createState() => _StepIdentityWidgetState();
}

class _StepIdentityWidgetState extends ConsumerState<StepIdentityWidget> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final currentName = ref.read(onboardingControllerProvider).displayName;
    _nameController = TextEditingController(
      text: (currentName == 'Bạn' || currentName.isEmpty) ? '' : currentName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    final currentAccent = ref.watch(accentPresetProvider);
    final currentFont = ref.watch(fontFamilyProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mascot Logo Squircle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [currentAccent.primary, currentAccent.primary.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: currentAccent.primary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '🌿',
                style: TextStyle(fontSize: 34),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Chào mừng đến với Flowy',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            'Không gian chi tiêu điềm tĩnh, bảo mật tuyệt đối.\nCá nhân hóa trải nghiệm theo phong cách của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
            ),
          ),
          const SizedBox(height: 24),

          // Khối 1: Nhập Tên hoặc Biệt Danh
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'BẠN TÊN LÀ GÌ?',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: currentAccent.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _nameController,
            onChanged: (val) => ref.read(onboardingControllerProvider.notifier).updateDisplayName(val),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
            decoration: InputDecoration(
              hintText: 'Nhập tên hoặc biệt danh... (vd: mt)',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? AppTokens.darkMuted.withValues(alpha: 0.6) : AppTokens.lightMuted.withValues(alpha: 0.6),
              ),
              prefixIcon: Icon(Icons.badge_rounded, color: currentAccent.primary, size: 20),
              filled: true,
              fillColor: isDark ? AppTokens.darkCard : AppTokens.lightCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: currentAccent.primary, width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Nút Đăng nhập / Đồng bộ Google
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? AppTokens.darkCard.withValues(alpha: 0.6) : Colors.white,
                foregroundColor: isDark ? AppTokens.darkText : AppTokens.lightText,
                side: BorderSide(
                  color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: state.isGoogleLoading
                  ? null
                  : () async {
                HapticFeedback.mediumImpact();
                final success = await ref
                    .read(onboardingControllerProvider.notifier)
                    .signInWithGoogleAndCheckBackup();
                if (success && mounted) {
                  final updatedName = ref.read(onboardingControllerProvider).displayName;
                  _nameController.text = updatedName == 'Bạn' ? '' : updatedName;
                }
              },
              icon: state.isGoogleLoading
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(currentAccent.primary),
                ),
              )
                  : const Icon(Icons.cloud_sync_rounded, color: Color(0xFF0EA5E9), size: 18),
              label: Text(
                state.isGoogleLoading ? 'Đang quét bản sao lưu Cloud...' : 'Tiếp tục với Google (Tìm sao lưu cũ)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Khối 2: CÁ NHÂN HÓA PHONG CÁCH TỨC THÌ (Instant Style Studio)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTokens.darkCard : AppTokens.lightCard,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined, size: 16, color: currentAccent.primary),
                    const SizedBox(width: 6),
                    Text(
                      'PHÒNG THIẾT KẾ PHONG CÁCH (ĐỔI TỨC THÌ)',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 1. Chuyển đổi Giao diện: [ Sáng ] / [ Tối ]
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Giao diện:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTokens.darkText : AppTokens.lightText,
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: SlidingSegmentedBar<ThemeMode>(
                        height: 38,
                        duration: const Duration(milliseconds: 185),
                        overshootPx: 1.6,
                        debugLabel: 'OnboardingIdentity.themeMode',
                        selectedValue: isDark ? ThemeMode.dark : ThemeMode.light,
                        trackColor: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
                        trackBorderColor: Colors.transparent,
                        indicatorColor: isDark ? AppTokens.darkCard : Colors.white,
                        indicatorBorderColor: Colors.transparent,
                        selectedTextColor: isDark ? AppTokens.darkText : AppTokens.lightText,
                        mutedTextColor: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                        items: const [
                          SlidingSegmentedItem<ThemeMode>(
                            value: ThemeMode.light,
                            label: 'Sáng',
                            leadingText: '☀️',
                          ),
                          SlidingSegmentedItem<ThemeMode>(
                            value: ThemeMode.dark,
                            label: 'Tối',
                            leadingText: '🌙',
                          ),
                        ],
                        onValueChanged: (mode) {
                          ref.read(themeModeProvider.notifier).setThemeMode(mode);
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // 2. 5 Màu Thiên Nhiên (Cỏ, Nắng, Biển, Hoa, Đêm)
                Text(
                  'Màu sắc chủ đạo:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: AppAccentPreset.values.map((preset) {
                    final isSelected = currentAccent == preset;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(accentPresetProvider.notifier).setAccent(preset);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? preset.primary.withValues(alpha: isDark ? 0.25 : 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? preset.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: preset.primary,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: isSelected
                                    ? [
                                  BoxShadow(
                                    color: preset.primary.withValues(alpha: 0.45),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              preset.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected
                                    ? preset.primary
                                    : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 24),

                // 3. Phông chữ yêu thích (Comfortaa, Nunito, Plus Jakarta Sans)
                Text(
                  'Phông chữ hiển thị:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    _buildFontChip('Comfortaa', 'Bo tròn', currentFont, currentAccent, isDark),
                    const SizedBox(width: 8),
                    _buildFontChip('Nunito', 'Mềm mại', currentFont, currentAccent, isDark),
                    const SizedBox(width: 8),
                    _buildFontChip('Plus Jakarta Sans', 'Hiện đại', currentFont, currentAccent, isDark),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Nút Hành động Chính: BẮT ĐẦU THIẾT LẬP (30s)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: currentAccent.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: currentAccent.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onNext();
              },
              child: const Text(
                'BẮT ĐẦU THIẾT LẬP (30s) ❯',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Nút Phụ: Bỏ qua, vào app ngay
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              widget.onSkip();
            },
            child: Text(
              'Bỏ qua, vào app ngay',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontChip(
      String fontKey,
      String label,
      String currentFont,
      AppAccentPreset accent,
      bool isDark,
      ) {
    final isSelected = currentFont == fontKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(fontFamilyProvider.notifier).setFontFamily(fontKey);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.primary.withValues(alpha: isDark ? 0.25 : 0.15)
                : (isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? accent.primary : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  fontFamily: fontKey,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? accent.primary : (isDark ? AppTokens.darkText : AppTokens.lightText),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? accent.primary : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}