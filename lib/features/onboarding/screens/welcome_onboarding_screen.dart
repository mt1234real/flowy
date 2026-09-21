// ==============================================================================
// File: lib/features/onboarding/screens/welcome_onboarding_screen.dart
// Architecture: 4-Step Express Onboarding Screen (High-Fidelity Brand & Settings Parity)
// Stack: flutter, flutter_riverpod, google_fonts, intl
// Features:
// 1. Logo nhận diện thương hiệu Flowy chuẩn mực (84x84, Squircle 22dp, Soft Glow):
//    - Ưu tiên nạp từ 'assets/icons/app_icon.png' hoặc 'assets/images/logo.png'.
//    - Fallback thông minh: Logo Typography huy hiệu thương hiệu Flowy với chữ "Flowy"
//      cách điệu sắc nét và biểu tượng chiếc lá 🌿, TUYỆT ĐỐI KHÔNG dùng icon búp sen.
// 2. Khối Studio Cá Nhân Hóa (Settings Parity 100%):
//    - Bộ chọn Sáng / Tối to bản: [ ☀️ Giao diện Sáng ] và [ 🌙 Giao diện Tối ].
//    - 5 Thẻ Sticker Palette tự nhiên: Cỏ (🌿), Nắng (☀️), Biển (🌊), Hoa (🌸), Đêm (🌙).
//    - 5 Thẻ Font Cards có badge phân loại và dòng xem trước trực tiếp bằng phông đó.
// 3. Live Preview phản hồi tức thì qua các StateNotifier bền vững.
// 4. Khắc phục dứt điểm nút bấm "Khám phá Flowy" bị liệt bằng loading state và chuyển hướng an toàn.
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/animation/app_animation_policy.dart';
import '../../../core/feedback/app_feedback.dart';
import '../../../screens/main_scaffold.dart';
import '../../../theme/app_theme.dart';
import '../controllers/onboarding_controller.dart';

import '../../../widgets/sliding_segmented_bar.dart';
class _FontItemDef {
  final String name;
  final String badge;
  final String description;
  final TextStyle Function({TextStyle? textStyle, Color? color, FontWeight? fontWeight, double? fontSize}) fontBuilder;

  const _FontItemDef({
    required this.name,
    required this.badge,
    required this.description,
    required this.fontBuilder,
  });
}

class WelcomeOnboardingScreen extends ConsumerStatefulWidget {
  const WelcomeOnboardingScreen({super.key});

  @override
  ConsumerState<WelcomeOnboardingScreen> createState() => _WelcomeOnboardingScreenState();
}

class _WelcomeOnboardingScreenState extends ConsumerState<WelcomeOnboardingScreen> {
  late final PageController _pageController;

  late final TextEditingController _nameController;
  late final TextEditingController _cashController;
  late final TextEditingController _bankController;
  late final TextEditingController _budgetController;

  final NumberFormat _currencyFormatter = NumberFormat('#,###', 'vi_VN');

  static const List<_FontItemDef> _fontDefinitions = [
    _FontItemDef(
      name: 'Comfortaa',
      badge: 'Cute / Rounded',
      description: 'Bo tròn, siêu đáng yêu & nhẹ nhàng',
      fontBuilder: GoogleFonts.comfortaa,
    ),
    _FontItemDef(
      name: 'Nunito',
      badge: 'Rounded Soft',
      description: 'Bo góc mềm mại, thân thiện dễ nhìn',
      fontBuilder: GoogleFonts.nunito,
    ),
    _FontItemDef(
      name: 'Plus Jakarta Sans',
      badge: 'Modern',
      description: 'Sắc nét, thanh lịch chuẩn Fintech',
      fontBuilder: GoogleFonts.plusJakartaSans,
    ),
    _FontItemDef(
      name: 'Be Vietnam Pro',
      badge: 'Vietnamese',
      description: 'Tối ưu độ đọc & hiển thị dấu tiếng Việt',
      fontBuilder: GoogleFonts.beVietnamPro,
    ),
    _FontItemDef(
      name: 'Lora',
      badge: 'Elegant Serif',
      description: 'Cổ điển, thanh lịch & đậm chất sổ tay',
      fontBuilder: GoogleFonts.lora,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    final state = ref.read(onboardingControllerProvider);
    _nameController = TextEditingController(
      text: state.displayName == 'Bạn' ? '' : state.displayName,
    );
    _cashController = TextEditingController(
      text: state.cashBalance > 0 ? _currencyFormatter.format(state.cashBalance.round()) : '',
    );
    _bankController = TextEditingController(
      text: state.bankBalance > 0 ? _currencyFormatter.format(state.bankBalance.round()) : '',
    );
    _budgetController = TextEditingController(
      text: _currencyFormatter.format(state.monthlyBudget.round()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _cashController.dispose();
    _bankController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    HapticFeedback.selectionClick();
    ref.read(onboardingControllerProvider.notifier).setStep(step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _onAmountFieldChanged(
      String val,
      void Function(double) updateCallback,
      TextEditingController controller,
      ) {
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

    final formatted = _currencyFormatter.format(amount.round());
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _finishAndNavigateHome() async {
    HapticFeedback.heavyImpact();
    final controller = ref.read(onboardingControllerProvider.notifier);
    await controller.completeOnboarding();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScaffold()),
      );
    }
  }

  int _calculateDaysInCycle(int startDay) {
    final now = DateTime.now();
    DateTime cycleStart;
    DateTime cycleEnd;

    if (startDay == 1) {
      cycleStart = DateTime(now.year, now.month, 1);
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      cycleEnd = nextMonth.subtract(const Duration(days: 1));
    } else {
      if (now.day >= startDay) {
        cycleStart = DateTime(now.year, now.month, startDay);
        cycleEnd = DateTime(now.year, now.month + 1, startDay).subtract(const Duration(days: 1));
      } else {
        cycleStart = DateTime(now.year, now.month - 1, startDay);
        cycleEnd = DateTime(now.year, now.month, startDay).subtract(const Duration(days: 1));
      }
    }

    final totalDays = cycleEnd.difference(cycleStart).inDays + 1;
    return totalDays > 0 ? totalDays : 30;
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(amount);
  }

  /// 🌟 Widget hiển thị Logo nhận diện thương hiệu Flowy chuẩn mực
  Widget _buildBrandLogo(AppAccentPreset accent) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accent.primary.withValues(alpha: 0.25),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.asset(
          'assets/icons/app_icon.png',
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/logo.png',
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.primary,
                    accent.darkVariant,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🌿', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Flowy',
                    style: TextStyle(
                      fontFamily: 'Comfortaa',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    final accent = ref.watch(accentPresetProvider);

    // Lắng nghe sự kiện tìm thấy bản sao lưu cũ trên Google Drive
    ref.listen<OnboardingState>(onboardingControllerProvider, (prev, next) {
      if (!prev!.foundCloudBackup && next.foundCloudBackup && next.cloudBackupMetadata != null) {
        _showCloudBackupRestoreModal(context, next);
      }
    });

    return AppFeedbackDismissRegion(
      child: Scaffold(
        backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar: Back button, Segmented Progress Bar, Nút Để sau
              _buildTopNavigation(context, state, isDark, accent),

              // Main Content: 4 PageViews
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep0StyleAndWelcome(context, state, isDark, accent, themeMode),
                    _buildStep1IdentityAndGoogle(context, state, isDark, accent),
                    _buildStep2Wallets(context, state, isDark, accent),
                    _buildStep3CycleAndBudget(context, state, isDark, accent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavigation(
      BuildContext context,
      OnboardingState state,
      bool isDark,
      AppAccentPreset accent,
      ) {
    final bool showProgressBar = state.currentStep > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Nút Quay lại
          if (state.currentStep > 0)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => _goToStep(state.currentStep - 1),
            )
          else
            const SizedBox(width: 44),

          // Thanh tiến trình Segmented 3 vạch (tính từ Bước 1)
          if (showProgressBar)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: List.generate(3, (index) {
                    final isCompleted = state.currentStep > index;
                    final isCurrent = state.currentStep == index + 1;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isCompleted || isCurrent
                              ? accent.primary
                              : (isDark ? Colors.white12 : Colors.black12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            )
          else
            const Spacer(),

          // Nút Bỏ qua / Để sau
          TextButton(
            onPressed: state.isCompleting ? null : _finishAndNavigateHome,
            child: Text(
              'Để sau',
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

  // ==============================================================================
  // 🌟 BƯỚC 0: CÁ NHÂN HÓA PHONG CÁCH TỨC THÌ (SETTINGS PARITY 100%) & LOGO
  // ==============================================================================
  Widget _buildStep0StyleAndWelcome(
      BuildContext context,
      OnboardingState state,
      bool isDark,
      AppAccentPreset accent,
      ThemeMode currentThemeMode,
      ) {
    final currentFont = ref.watch(fontFamilyProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Logo nhận diện thương hiệu chuẩn mực Flowy
          _buildBrandLogo(accent),
          const SizedBox(height: 14),

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
            'Không gian chi tiêu điềm tĩnh, giữ trọn quyền riêng tư.\nCá nhân hóa phong cách ngay trước khi bắt đầu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
            ),
          ),
          const SizedBox(height: 20),

          // 2. KHỐI STUDIO CÁ NHÂN HÓA PHONG CÁCH CHUẨN SETTINGS
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppTokens.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Khối Studio
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.palette_outlined, size: 16, color: accent.primary),
                        const SizedBox(width: 6),
                        Text(
                          'THIẾT KẾ KHÔNG GIAN CỦA BẠN',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: accent.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Đổi tức thì',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // MỤC 1: BỘ CHỌN SÁNG / TỐI — shared preserved sliding engine
                SlidingSegmentedBar<ThemeMode>(
                  height: 50,
                  duration: const Duration(milliseconds: 185),
                  overshootPx: 1.8,
                  debugLabel: 'Onboarding.themeMode',
                  selectedValue: currentThemeMode == ThemeMode.dark
                      ? ThemeMode.dark
                      : ThemeMode.light,
                  trackColor: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
                  trackBorderColor: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
                  indicatorColor: isDark ? AppTokens.darkCard : Colors.white,
                  indicatorBorderColor: accent.primary,
                  selectedTextColor: accent.primary,
                  mutedTextColor: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                  indicatorShadowColor: accent.primary.withValues(alpha: 0.18),
                  items: const [
                    SlidingSegmentedItem<ThemeMode>(
                      value: ThemeMode.light,
                      label: 'Giao diện Sáng',
                      icon: Icons.wb_sunny_rounded,
                    ),
                    SlidingSegmentedItem<ThemeMode>(
                      value: ThemeMode.dark,
                      label: 'Giao diện Tối',
                      icon: Icons.nightlight_round,
                    ),
                  ],
                  onValueChanged: (mode) {
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  },
                ),
                const SizedBox(height: 18),

                // MỤC 2: 5 THẺ MÀU SẮC THIÊN NHIÊN (CỎ, NẮNG, BIỂN, HOA, ĐÊM)
                Text(
                  'MÀU SẮC THIÊN NHIÊN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                  ),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    _buildStickerPaletteCard(
                      preset: AppAccentPreset.grass,
                      stickerEmoji: '🌿',
                      title: 'Cỏ',
                      color: const Color(0xFF10B981),
                      isSelected: accent == AppAccentPreset.grass,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(accentPresetProvider.notifier).setAccent(AppAccentPreset.grass);
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildStickerPaletteCard(
                      preset: AppAccentPreset.sun,
                      stickerEmoji: '☀️',
                      title: 'Nắng',
                      color: const Color(0xFFF59E0B),
                      isSelected: accent == AppAccentPreset.sun,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(accentPresetProvider.notifier).setAccent(AppAccentPreset.sun);
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildStickerPaletteCard(
                      preset: AppAccentPreset.sea,
                      stickerEmoji: '🌊',
                      title: 'Biển',
                      color: const Color(0xFF0EA5E9),
                      isSelected: accent == AppAccentPreset.sea,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(accentPresetProvider.notifier).setAccent(AppAccentPreset.sea);
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildStickerPaletteCard(
                      preset: AppAccentPreset.flower,
                      stickerEmoji: '🌸',
                      title: 'Hoa',
                      color: const Color(0xFFF43F5E),
                      isSelected: accent == AppAccentPreset.flower,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(accentPresetProvider.notifier).setAccent(AppAccentPreset.flower);
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildStickerPaletteCard(
                      preset: AppAccentPreset.night,
                      stickerEmoji: '🌙',
                      title: 'Đêm',
                      color: const Color(0xFF6366F1),
                      isSelected: accent == AppAccentPreset.night,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(accentPresetProvider.notifier).setAccent(AppAccentPreset.night);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // MỤC 3: 5 FONT CARDS CHUYÊN NGHIỆP CÓ BADGE & DÒNG MẪU XEM TRƯỚC
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'KIỂU CHỮ TYPOGRAPHY (5)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                    Text(
                      'Xem mẫu trực quan',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                _buildFontCardsGrid(
                  fontDefs: _fontDefinitions,
                  currentFont: currentFont,
                  accent: accent,
                  isDark: isDark,
                  onSelectFont: (name) {
                    HapticFeedback.selectionClick();
                    ref.read(fontFamilyProvider.notifier).setFontFamily(name);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // NÚT BẮT ĐẦU THIẾT LẬP (30s)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: accent.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () => _goToStep(1),
              child: const Text(
                'BẮT ĐẦU THIẾT LẬP (30s) ❯',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),

          TextButton(
            onPressed: state.isCompleting ? null : _finishAndNavigateHome,
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

  // --- SUB-WIDGETS CHUẨN SETTINGS SCREEN ---

  Widget _buildStickerPaletteCard({
    required AppAccentPreset preset,
    required String stickerEmoji,
    required String title,
    required Color color,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.14)
                : (isDark ? AppTokens.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Column(
            children: [
              Text(stickerEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? color : (isDark ? AppTokens.darkText : AppTokens.lightText),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 22,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontCardsGrid({
    required List<_FontItemDef> fontDefs,
    required String currentFont,
    required AppAccentPreset accent,
    required bool isDark,
    required ValueChanged<String> onSelectFont,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildSingleFontCard(fontDefs[0], currentFont, accent, isDark, onSelectFont)),
            const SizedBox(width: 8),
            Expanded(child: _buildSingleFontCard(fontDefs[1], currentFont, accent, isDark, onSelectFont)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildSingleFontCard(fontDefs[2], currentFont, accent, isDark, onSelectFont)),
            const SizedBox(width: 8),
            Expanded(child: _buildSingleFontCard(fontDefs[3], currentFont, accent, isDark, onSelectFont)),
          ],
        ),
        const SizedBox(height: 8),
        _buildSingleFontCard(fontDefs[4], currentFont, accent, isDark, onSelectFont),
      ],
    );
  }

  Widget _buildSingleFontCard(
      _FontItemDef font,
      String currentFont,
      AppAccentPreset accent,
      bool isDark,
      ValueChanged<String> onSelect,
      ) {
    final isSelected = currentFont == font.name;

    return InkWell(
      onTap: () => onSelect(font.name),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.primary.withValues(alpha: 0.10)
              : (isDark ? AppTokens.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent.primary : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: accent.primary.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    font.badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? accent.primary : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                    ),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? accent.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? accent.primary : (isDark ? Colors.white30 : Colors.black26),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              font.name,
              style: font.fontBuilder(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTokens.darkText : AppTokens.lightText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              font.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mẫu: 1.250.000 ₫ • Cà phê',
              style: font.fontBuilder(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? accent.primary : (isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================================
  // 🌟 BƯỚC 1: DANH XƯNG & KẾT NỐI GOOGLE (TÌM BẢN SAO LƯU CŨ)
  // ==============================================================================
  Widget _buildStep1IdentityAndGoogle(
      BuildContext context,
      OnboardingState state,
      bool isDark,
      AppAccentPreset accent,
      ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BƯỚC 1 / 3',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: accent.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bạn muốn Flowy gọi bạn là gì?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nhập tên hoặc biệt danh để cá nhân hóa lời chào mỗi ngày.',
            style: TextStyle(fontSize: 12, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
          ),
          const SizedBox(height: 20),

          // TextField Nhập Tên
          TextField(
            controller: _nameController,
            onChanged: (val) => ref.read(onboardingControllerProvider.notifier).updateDisplayName(val),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
            decoration: InputDecoration(
              labelText: 'Tên của bạn',
              hintText: 'Ví dụ: mt, Alex, Minh Trí...',
              prefixIcon: Icon(Icons.person_rounded, color: accent.primary, size: 20),
              filled: true,
              fillColor: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
          const SizedBox(height: 16),

          // Nút Đăng nhập Google quét backup cũ
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: isDark ? AppTokens.darkCard.withValues(alpha: 0.6) : Colors.white,
                foregroundColor: isDark ? AppTokens.darkText : AppTokens.lightText,
                side: BorderSide(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(accent.primary)),
              )
                  : const Icon(Icons.cloud_sync_rounded, color: Color(0xFF0EA5E9), size: 18),
              label: Text(
                state.isGoogleLoading ? 'Đang kiểm tra sao lưu Google Drive...' : 'Tiếp tục với Google (Tìm sao lưu cũ)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _goToStep(2),
              child: const Text('Tiếp tục sang bước Ví ❯', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================================
  // 🌟 BƯỚC 2: KHỞI TẠO NGUỒN TIỀN (TIỀN MẶT & NGÂN HÀNG)
  // ==============================================================================
  Widget _buildStep2Wallets(
      BuildContext context,
      OnboardingState state,
      bool isDark,
      AppAccentPreset accent,
      ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BƯỚC 2 / 3',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: accent.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hiện tại bạn đang có\nbao nhiêu tiền?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              height: 1.25,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ước tính số tiền khả dụng ban đầu, có thể kiểm kê hoặc sửa lại bất cứ lúc nào.',
            style: TextStyle(fontSize: 12, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
          ),
          const SizedBox(height: 18),

          // Ô Tiền mặt
          _buildWalletCard(
            title: 'Tiền mặt trong ví',
            subtitle: 'Tiền mặt trong bóp, ngăn kéo...',
            iconEmoji: '💵',
            iconColor: const Color(0xFF10B981),
            controller: _cashController,
            isDark: isDark,
            accent: accent,
            onChanged: (val) {
              _onAmountFieldChanged(
                val,
                    (amt) => ref.read(onboardingControllerProvider.notifier).updateCashBalance(amt),
                _cashController,
              );
            },
          ),
          const SizedBox(height: 14),

          // Ô Ngân hàng
          _buildWalletCard(
            title: 'Tài khoản ngân hàng',
            subtitle: 'Tài khoản nhận lương, thanh toán...',
            iconEmoji: '💳',
            iconColor: const Color(0xFF0EA5E9),
            controller: _bankController,
            isDark: isDark,
            accent: accent,
            onChanged: (val) {
              _onAmountFieldChanged(
                val,
                    (amt) => ref.read(onboardingControllerProvider.notifier).updateBankBalance(amt),
                _bankController,
              );
            },
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _goToStep(3),
              child: const Text('Tiếp tục ❯', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),

          Center(
            child: TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.read(onboardingControllerProvider.notifier).updateCashBalance(0.0);
                ref.read(onboardingControllerProvider.notifier).updateBankBalance(0.0);
                _goToStep(3);
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(iconEmoji, style: const TextStyle(fontSize: 20))),
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
          const SizedBox(height: 12),

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
              suffixText: '₫',
              suffixStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accent.primary),
              filled: true,
              fillColor: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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

  // ==============================================================================
  // 🌟 BƯỚC 3: CHU KỲ, HẠN MỨC CHI TIÊU & THẺ "AHA MOMENT" AN TOÀN MỖI NGÀY
  // ==============================================================================
  Widget _buildStep3CycleAndBudget(
      BuildContext context,
      OnboardingState state,
      bool isDark,
      AppAccentPreset accent,
      ) {
    final int cycleDays = _calculateDaysInCycle(state.cycleStartDay);
    final double dailySafeSpend = state.monthlyBudget > 0 ? (state.monthlyBudget / cycleDays) : 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BƯỚC 3 / 3',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: accent.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Chu kỳ & Hạn mức an toàn',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thuật toán Flowy tự động tính toán số tiền an toàn mỗi ngày dựa trên mốc này.',
            style: TextStyle(fontSize: 12, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
          ),
          const SizedBox(height: 16),

          // Chọn ngày nhận lương Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ngày nhận lương: Ngày ${state.cycleStartDay}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTokens.darkText : AppTokens.lightText,
                ),
              ),
              Text(
                'Chu kỳ $cycleDays ngày',
                style: TextStyle(fontSize: 11, color: accent.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent.primary,
              thumbColor: accent.primary,
              overlayColor: accent.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: state.cycleStartDay.toDouble(),
              min: 1,
              max: 31,
              divisions: 30,
              label: 'Ngày ${state.cycleStartDay}',
              onChanged: (val) {
                ref.read(onboardingControllerProvider.notifier).updateCycleStartDay(val.round());
              },
            ),
          ),
          const SizedBox(height: 12),

          // Dự trù ngân sách tháng
          Text(
            'Hạn mức chi tiêu mong muốn tháng này',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (val) {
              _onAmountFieldChanged(
                val,
                    (amt) => ref.read(onboardingControllerProvider.notifier).updateMonthlyBudget(amt),
                _budgetController,
              );
            },
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? AppTokens.darkText : AppTokens.lightText,
            ),
            decoration: InputDecoration(
              hintText: '10.000.000',
              suffixText: '₫',
              prefixIcon: Icon(Icons.savings_outlined, color: accent.primary, size: 20),
              filled: true,
              fillColor: isDark ? AppTokens.darkCard : AppTokens.lightCardSubtle,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: accent.primary, width: 2.0),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quick Chips chọn hạn mức
          Wrap(
            spacing: 8,
            children: [5000000.0, 10000000.0, 15000000.0, 20000000.0].map((preset) {
              final isSelected = state.monthlyBudget == preset;
              return ChoiceChip(
                label: Text('${(preset / 1000000).toStringAsFixed(0)} Triệu'),
                selected: isSelected,
                selectedColor: accent.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? accent.primary : (isDark ? AppTokens.darkText : AppTokens.lightText),
                ),
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  _budgetController.text = _currencyFormatter.format(preset.round());
                  ref.read(onboardingControllerProvider.notifier).updateMonthlyBudget(preset);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // THẺ "AHA MOMENT" AN TOÀN MỖI NGÀY (FROSTED GLASS CARD)
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                      const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: accent.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accent.primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('💡', style: TextStyle(fontSize: 15)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Thuật toán Flowy tính toán:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTokens.darkText : AppTokens.lightText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Text(
                      'Mỗi ngày bạn có khoảng:',
                      style: TextStyle(fontSize: 12, color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted),
                    ),
                    const SizedBox(height: 4),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        _formatCurrency(dailySafeSpend),
                        key: ValueKey<double>(dailySafeSpend),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    Text(
                      'để chi tiêu thảnh thơi mà không bị cạn túi vào cuối tháng! 🎉',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // 🌟 NÚT BẤM HOÀN TẤT: KHÁM PHÁ FLOWY (KÈM LOADING STATE CHỐNG LIỆT)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: accent.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: state.isCompleting ? null : _finishAndNavigateHome,
              child: state.isCompleting
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                'HOÀN TẤT & KHÁM PHÁ FLOWY 🚀',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================================
  // MODAL PHỤC HỒI KHI TÌM THẤY BẢN SAO LƯU TRÊN GOOGLE DRIVE
  // ==============================================================================
  void _showCloudBackupRestoreModal(BuildContext context, OnboardingState state) {
    final meta = state.cloudBackupMetadata!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    AppAnimationPolicy.showFluidSheet<void>(
      context: context,
      mode: FluidSheetMode.nestedScrollable,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_, __) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151C28).withValues(alpha: 0.98) : Colors.white.withValues(alpha: 0.98),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_done_rounded, color: Color(0xFF0EA5E9), size: 32),
                ),
                const SizedBox(height: 12),

                Text(
                  'Mừng bạn quay lại!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppTokens.darkText : AppTokens.lightText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Flowy đã tìm thấy bản sao lưu cũ trên Google Drive của bạn:\n'
                      '• Thời điểm: ${DateFormat('dd/MM/yyyy HH:mm').format(meta.updatedAt.toLocal())}\n'
                      '• Quy mô: ${meta.transactionCount} giao dịch, ${meta.walletCount} nguồn ví.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: isDark ? AppTokens.darkMuted : AppTokens.lightMuted,
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      final success = await ref.read(onboardingControllerProvider.notifier).restoreFromCloud();
                      if (success && context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const MainScaffold()),
                        );
                      }
                    },
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: const Text(
                      'Khôi phục dữ liệu ngay',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(onboardingControllerProvider.notifier).dismissCloudPrompt();
                      _goToStep(1);
                    },
                    child: Text(
                      'Tạo sổ chi tiêu mới hoàn toàn',
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
          ),
        ),
      ),
    );
  }
}