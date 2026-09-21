// ==============================================================================
// File: lib/theme/app_theme.dart
// Architecture: Persistent Design Tokens, Glassmorphism, 5 Nature Accents & Dynamic GoogleFonts
// Stack: flutter_riverpod, google_fonts, shared_preferences, flutter/material.dart
// Features:
// 1. SharedPreferences Theme & Accent Persistence (No Flash Reset on App Launch)[cite: 3]
// 2. StateNotifier Architecture for ThemeMode and AppAccentPreset[cite: 3]
// 3. 5 Cute Nature Accent Palettes: Cỏ (Grass), Nắng (Sun), Biển (Sea), Hoa (Flower), Đêm (Night)[cite: 3]
// 4. 5 Offline-Ready Google Fonts Typography Families[cite: 3]
// 5. Glassmorphism Design Helpers & Contrast Ratios Compliant[cite: 3]
// 6. Native PageTransitionsTheme tích hợp FadeUpwards / Cupertino mượt mà trên mọi nền tảng
// ==============================================================================
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- STORAGE KEYS ---
const String kPrefKeyThemeMode = 'flowy_theme_mode';
const String kPrefKeyAccentPreset = 'flowy_accent_preset';
const String kPrefKeyFontFamily = 'flowy_font_family';

// --- DESIGN TOKENS ---

class AppTokens {
  // Deep Slate Core Colors
  static const Color darkBg = Color(0xFF0B0F17);
  static const Color darkCard = Color(0xFF151C28);
  static const Color darkCardSubtle = Color(0xFF1E2638);
  static const Color darkBorder = Color(0xFF232D42);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkMuted = Color(0xFF94A3B8);

  // Crisp Light Mode Colors
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardSubtle = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightMuted = Color(0xFF64748B);

  // Financial Semantic Colors
  static const Color expense = Color(0xFFF43F5E); // Rose 500
  static const Color income = Color(0xFF10B981);  // Emerald 500
  static const Color debt = Color(0xFFF59E0B);    // Amber 500
  static const Color savings = Color(0xFF6366F1); // Indigo 500
  static const Color warning = Color(0xFFF59E0B); // Amber
}

// --- 5 CUTE NATURE ACCENT PALETTES ---

enum AppAccentPreset {
  grass('Cỏ', Color(0xFF10B981), Color(0xFF059669)),   // Fresh Mint / Emerald
  sun('Nắng', Color(0xFFF59E0B), Color(0xFFD97706)),    // Warm Amber / Orange
  sea('Biển', Color(0xFF0EA5E9), Color(0xFF0284C7)),    // Ocean Sky / Blue
  flower('Hoa', Color(0xFFF43F5E), Color(0xFFE11D48)),  // Sakura Blossom / Rose
  night('Đêm', Color(0xFF6366F1), Color(0xFF4F46E5));   // Night Owl / Indigo

  final String label;
  final Color primary;
  final Color darkVariant;

  const AppAccentPreset(this.label, this.primary, this.darkVariant);

  Color get secondary => darkVariant;
}

// Danh sách 5 họ phông chữ được hỗ trợ
const List<String> kSupportedFontFamilies = [
  'Plus Jakarta Sans',
  'Be Vietnam Pro',
  'Nunito',
  'Comfortaa',
  'Lora',
];

// --- DYNAMIC TEXT THEME RESOLVER (TREE-SHAKING SAFE) ---

TextTheme getDynamicTextTheme(String fontName, TextTheme baseTextTheme) {
  switch (fontName) {
    case 'Comfortaa':
      return GoogleFonts.comfortaaTextTheme(baseTextTheme);
    case 'Nunito':
      return GoogleFonts.nunitoTextTheme(baseTextTheme);
    case 'Be Vietnam Pro':
      return GoogleFonts.beVietnamProTextTheme(baseTextTheme);
    case 'Lora':
      return GoogleFonts.loraTextTheme(baseTextTheme);
    case 'Plus Jakarta Sans':
    default:
      return GoogleFonts.plusJakartaSansTextTheme(baseTextTheme);
  }
}

/// Alias hàm build cho tính tương thích ngược
TextTheme buildDynamicTextTheme(String fontFamily, TextTheme baseTextTheme) {
  return getDynamicTextTheme(fontFamily, baseTextTheme);
}

// --- PERSISTENT SHARED PREFERENCES PROVIDER ---

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

// --- PERSISTENT THEME MODE NOTIFIER ---

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs) : super(_loadInitialMode(_prefs));

  static ThemeMode _loadInitialMode(SharedPreferences prefs) {
    final modeStr = prefs.getString(kPrefKeyThemeMode);
    switch (modeStr) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark; // Mặc định Deep Slate nếu chưa từng lưu
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    String modeStr = 'dark';
    if (mode == ThemeMode.light) {
      modeStr = 'light';
    } else if (mode == ThemeMode.system) {
      modeStr = 'system';
    }
    await _prefs.setString(kPrefKeyThemeMode, modeStr);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});

// --- PERSISTENT ACCENT PRESET NOTIFIER ---

class AccentPresetNotifier extends StateNotifier<AppAccentPreset> {
  final SharedPreferences _prefs;

  AccentPresetNotifier(this._prefs) : super(_loadInitialAccent(_prefs));

  static AppAccentPreset _loadInitialAccent(SharedPreferences prefs) {
    final presetName = prefs.getString(kPrefKeyAccentPreset);
    return AppAccentPreset.values.firstWhere(
          (p) => p.name == presetName,
      orElse: () => AppAccentPreset.grass, // Mặc định Cỏ (Emerald/Mint)
    );
  }

  Future<void> setAccent(AppAccentPreset preset) async {
    state = preset;
    await _prefs.setString(kPrefKeyAccentPreset, preset.name);
  }
}

final accentPresetProvider = StateNotifierProvider<AccentPresetNotifier, AppAccentPreset>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AccentPresetNotifier(prefs);
});

// --- PERSISTENT FONT FAMILY NOTIFIER ---

class FontFamilyNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;

  FontFamilyNotifier(this._prefs)
      : super(_prefs.getString(kPrefKeyFontFamily) ?? 'Plus Jakarta Sans');

  Future<void> setFontFamily(String fontName) async {
    state = fontName;
    await _prefs.setString(kPrefKeyFontFamily, fontName);
  }
}

final fontFamilyProvider = StateNotifierProvider<FontFamilyNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FontFamilyNotifier(prefs);
});

// --- THEME DATA BUILDERS ---

ThemeData buildLightTheme(AppAccentPreset accent, String fontFamily) {
  return AppTheme.buildTheme(
    isDark: false,
    accent: accent,
    fontName: fontFamily,
  );
}

ThemeData buildDarkTheme(AppAccentPreset accent, String fontFamily) {
  return AppTheme.buildTheme(
    isDark: true,
    accent: accent,
    fontName: fontFamily,
  );
}

class AppTheme {
  /// Builds a complete [ThemeData] with full backward-compatibility.
  static ThemeData buildTheme({
    required bool isDark,
    required AppAccentPreset accent,
    String fontName = 'Plus Jakarta Sans',
  }) {
    final baseTheme = isDark ? ThemeData.dark() : ThemeData.light();
    final textColor = isDark ? AppTokens.darkText : AppTokens.lightText;
    final mutedColor = isDark ? AppTokens.darkMuted : AppTokens.lightMuted;

    final resolvedTextTheme = getDynamicTextTheme(
      fontName,
      baseTheme.textTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
      cardColor: isDark ? AppTokens.darkCard : AppTokens.lightCard,
      textTheme: resolvedTextTheme,
      // 🌟 CẤU HÌNH TRANSITION CHUẨN FRAMEWORK AN TOÀN VÀ TƯƠNG THÍCH ĐA NỀN TẢNG
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent.primary,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: accent.primary,
        surface: isDark ? AppTokens.darkCard : AppTokens.lightCard,
        error: AppTokens.expense,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppTokens.darkBg : AppTokens.lightBg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: TextStyle(
          fontFamily: fontName,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppTokens.darkCardSubtle : AppTokens.lightCardSubtle,
        hintStyle: TextStyle(color: mutedColor, fontSize: 13),
        labelStyle: TextStyle(color: mutedColor, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppTokens.darkBorder : AppTokens.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: accent.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// --- GLASSMORPHISM UI HELPERS ---

class AppGlassmorphism {
  /// Standard reusable frosted glass card container
  static Widget glassCard({
    required BuildContext context,
    required Widget child,
    required bool isDark,
    Color? customAccent,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double borderRadius = 24,
    double blur = 16,
  }) {
    final borderColor = customAccent != null
        ? customAccent.withValues(alpha: 0.28)
        : (isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08));

    final surfaceColor = isDark
        ? AppTokens.darkCard.withValues(alpha: 0.85)
        : AppTokens.lightCard.withValues(alpha: 0.90);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
              if (customAccent != null)
                BoxShadow(
                  color: customAccent.withValues(alpha: 0.12),
                  blurRadius: 24,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  /// Reusable BoxDecoration for non-blur card surfaces
  static BoxDecoration cardDecoration({
    required bool isDark,
    Color? customAccent,
    bool isGlowing = false,
    double borderRadius = 20,
  }) {
    return BoxDecoration(
      color: isDark ? AppTokens.darkCard : AppTokens.lightCard,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: customAccent != null
            ? customAccent.withValues(alpha: 0.3)
            : (isDark ? AppTokens.darkBorder : AppTokens.lightBorder),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
        if (isGlowing && customAccent != null)
          BoxShadow(
            color: customAccent.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 2),
          ),
      ],
    );
  }
}