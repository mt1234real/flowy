// ==============================================================================
// File: lib/main.dart
// Architecture: Application Entry Point & Root Purge Session Engine with Animation Hardening
// Stack: flutter_riverpod, drift, shared_preferences, flutter/material.dart
// Features:
// 1. Root Purge Session Engine (appSessionKeyProvider):
//    - Cung cấp StateProvider<UniqueKey> làm Session Key toàn cục cho cây Widget.
//    - Bọc MaterialApp trong KeyedSubtree(key: sessionKey).
//    - Khi chuyển tài khoản hoặc khôi phục sao lưu: resetSessionKey() ép dựng lại
//      100% Widget tree và dọn sạch state cũ trong RAM mà không cần khởi động lại tiến trình OS.
// 2. Pre-Initialization SharedPreferences & Drift SQLite Engine (Zero Theme Flash).
// 3. Dynamic Flow Routing:
//    - Nếu tài khoản trắng hoặc chưa hoàn thành: WelcomeOnboardingScreen.
//    - Nếu tài khoản đã hoàn tất cấu hình: MainScaffold.
// 4. Global Animation Hardening & HyperOS Optimization:
//    - Ghi đè MediaQueryData.disableAnimations = false trong MaterialApp.builder.
//    - Đảm bảo toàn bộ animation sản phẩm (Fade, Slide, Shimmer, Ripple, Aura) luôn chạy
//      mượt mà trên mọi máy Android/HyperOS kể cả khi bật Tiết kiệm pin hoặc tắt Animator duration.
// ==============================================================================

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:path_provider/path_provider.dart';
import 'services/backup_capsule.dart';
import 'data/database.dart';
import 'data/database_seeder.dart';
import 'features/onboarding/onboarding_completion.dart';
import 'features/onboarding/screens/welcome_onboarding_screen.dart';
import 'screens/main_scaffold.dart';
import 'theme/app_theme.dart';
import 'widgets/backup_progress_curtain.dart';

/// 🌟 ROOT SESSION KEY PROVIDER (ROOT PURGE ARCHITECTURE)
/// Gán UniqueKey mới để dọn sạch toàn bộ state trong bộ nhớ và ép dựng lại cây Widget.
final appSessionKeyProvider = StateProvider<UniqueKey>((ref) => UniqueKey());

/// Helper reset toàn bộ ứng dụng từ bất kỳ đâu
void resetAppRootSession(WidgetRef ref) {
  backupNavigatorKey = GlobalKey<NavigatorState>();
  ref.read(appSessionKeyProvider.notifier).state = UniqueKey();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khóa hướng màn hình dọc (Portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Cấu hình giao diện thanh điều hướng và trạng thái hệ thống trong suốt
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Khởi tạo SharedPreferences trước khi render frame đầu tiên (Chống chớp giật giao diện)
  final prefs = await SharedPreferences.getInstance();

  final documents = await getApplicationDocumentsDirectory();
  if (await File(p.join(documents.path, 'restore_recovery', 'pending'))
      .exists()) {
    final recoveryGuard =
        await File(p.join(documents.path, 'restore_access.lock'))
            .open(mode: FileMode.append);
    await recoveryGuard.lock(FileLock.blockingExclusive);
    try {
      await recoverInterruptedRestore(documents.path, prefs);
    } finally {
      await recoveryGuard.unlock();
      await recoveryGuard.close();
    }
  }

  // Khởi tạo Drift SQLite Database cục bộ
  final appDb = AppDatabase();

  // Chỉ gieo dữ liệu mẫu nếu người dùng cũ đã xong onboarding
  final hasCompletedOnboarding =
      prefs.getBool('has_completed_onboarding') ?? false;
  if (hasCompletedOnboarding) {
    try {
      await DatabaseSeeder.seedInitialData(appDb);
    } catch (e) {
      debugPrint('Database seeding error (non-fatal): $e');
    }
  }

  await appDb.close();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const FlowyApp(),
    ),
  );
}

class FlowyApp extends ConsumerWidget {
  const FlowyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Session Key toàn cục ép dọn sạch bộ nhớ và dựng lại toàn bộ cây khi đăng xuất/đổi tài khoản
    final sessionKey = ref.watch(appSessionKeyProvider);

    // Theo dõi trạng thái giao diện đã được lưu trữ bền vững từ Riverpod
    final themeMode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentPresetProvider);
    final fontName = ref.watch(fontFamilyProvider);
    final currencyFont = ref.watch(currencyFontProvider);
    final hasCompletedOnboarding = ref.watch(hasCompletedOnboardingProvider);

    return KeyedSubtree(
      key: sessionKey,
      child: MaterialApp(
        title: 'Flowy',
        navigatorKey: backupNavigatorKey,
        debugShowCheckedModeBanner: false,

        // 🌟 GHI ĐÈ THIẾT LẬP TRỢ NĂNG TOÀN CỤC: BẢO VỆ MỌI ANIMATION TRÊN HYPEROS / ANDROID
        builder: (context, child) {
          final mediaQueryData = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQueryData.copyWith(
              disableAnimations: false,
            ),
            child: BackupProgressHost(child: child!),
          );
        },

        // Cấu hình Theme đồng bộ với AppTheme
        theme: AppTheme.buildTheme(
          isDark: false,
          accent: accent,
          fontName: fontName,
          currencyFont: currencyFont,
        ),
        darkTheme: AppTheme.buildTheme(
          isDark: true,
          accent: accent,
          fontName: fontName,
          currencyFont: currencyFont,
        ),
        themeMode: themeMode,

        // Điều hướng thông minh: Chưa hoàn thành -> WelcomeOnboardingScreen, đã hoàn thành -> MainScaffold
        home: hasCompletedOnboarding
            ? const MainScaffold()
            : const WelcomeOnboardingScreen(),
      ),
    );
  }
}
