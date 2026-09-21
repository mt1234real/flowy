// ==============================================================================
// File: lib/features/onboarding/controllers/onboarding_controller.dart
// Architecture: 4-Step Express Onboarding State Controller (30-Second Setup)
// Stack: flutter_riverpod, drift, google_sign_in, shared_preferences
// Features:
// 1. Immutable OnboardingState model (Step 0 to 3):
//    - displayName, photoUrl, cashBalance, bankBalance, cycleStartDay, monthlyBudget
//    - isGoogleLoading, isCompleting, foundCloudBackup, cloudBackupMetadata
// 2. hasCompletedOnboardingProvider:
//    - StateProvider<bool> phản ứng thời gian thực cho router chính tại main.dart.
// 3. signInWithGoogleAndCheckBackup():
//    - Xác thực GoogleSignIn, lấy thông tin cá nhân.
//    - Quét ngầm Google Drive appDataFolder tìm bản sao lưu cũ.
// 4. restoreFromCloud():
//    - Ủy quyền khôi phục CSDL từ Cloud, đánh dấu hoàn tất onboarding.
// 5. completeOnboarding():
//    - Bọc try-catch toàn diện, tuyệt đối không ném uncaught exception làm liệt UI.
//    - Ghi SharedPreferences: has_completed_onboarding = true, user_display_name, flowy_cycle_start_day.
//    - Khởi tạo Ví Tiền Mặt & Ngân Hàng ban đầu trong SQLite an toàn.
//    - Cập nhật hasCompletedOnboardingProvider = true.
// ==============================================================================

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/database.dart';
import '../../../screens/ledger_screen.dart' show cycleStartDaysByMonthProvider;
import '../../../services/auth_profile_service.dart';
import '../../../services/cloud_backup_service.dart';

/// StateProvider thông báo trạng thái hoàn tất onboarding cho toàn app
final hasCompletedOnboardingProvider = StateProvider<bool>((ref) => false);

class OnboardingState {
  final int currentStep; // 0: Phong cách & Chào mừng, 1: Tên & Google, 2: Ví tiền, 3: Chu kỳ & Hạn mức
  final String displayName;
  final String? photoUrl;
  final double cashBalance;
  final double bankBalance;
  final int cycleStartDay;
  final double monthlyBudget;
  final bool isGoogleLoading;
  final bool isCompleting;
  final bool foundCloudBackup;
  final CloudBackupMetadata? cloudBackupMetadata;

  const OnboardingState({
    this.currentStep = 0,
    this.displayName = 'Bạn',
    this.photoUrl,
    this.cashBalance = 0.0,
    this.bankBalance = 0.0,
    this.cycleStartDay = 1,
    this.monthlyBudget = 10000000.0,
    this.isGoogleLoading = false,
    this.isCompleting = false,
    this.foundCloudBackup = false,
    this.cloudBackupMetadata,
  });

  OnboardingState copyWith({
    int? currentStep,
    String? displayName,
    String? photoUrl,
    double? cashBalance,
    double? bankBalance,
    int? cycleStartDay,
    double? monthlyBudget,
    bool? isGoogleLoading,
    bool? isCompleting,
    bool? foundCloudBackup,
    CloudBackupMetadata? cloudBackupMetadata,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      cashBalance: cashBalance ?? this.cashBalance,
      bankBalance: bankBalance ?? this.bankBalance,
      cycleStartDay: cycleStartDay ?? this.cycleStartDay,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
      isCompleting: isCompleting ?? this.isCompleting,
      foundCloudBackup: foundCloudBackup ?? this.foundCloudBackup,
      cloudBackupMetadata: cloudBackupMetadata ?? this.cloudBackupMetadata,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  final Ref _ref;
  final AppDatabase _db;
  final GoogleSignIn _googleSignIn;

  OnboardingController(this._ref, this._db)
      : _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.appdata',
    ],
  ),
        super(const OnboardingState());

  void setStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  void updateDisplayName(String name) {
    state = state.copyWith(displayName: name.trim().isEmpty ? 'Bạn' : name.trim());
  }

  void updateCashBalance(double balance) {
    state = state.copyWith(cashBalance: balance);
  }

  void updateBankBalance(double balance) {
    state = state.copyWith(bankBalance: balance);
  }

  void updateCycleStartDay(int day) {
    state = state.copyWith(cycleStartDay: day.clamp(1, 31));
  }

  void updateMonthlyBudget(double budget) {
    state = state.copyWith(monthlyBudget: budget);
  }

  void dismissCloudPrompt() {
    state = state.copyWith(foundCloudBackup: false);
  }

  /// Đăng nhập Google và quét kiểm tra bản sao lưu cũ trên Google Drive AppData
  Future<bool> signInWithGoogleAndCheckBackup() async {
    state = state.copyWith(isGoogleLoading: true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(isGoogleLoading: false);
        return false;
      }

      final profileNotifier = _ref.read(userProfileNotifierProvider.notifier);
      await profileNotifier.signInWithGoogle();

      state = state.copyWith(
        displayName: account.displayName?.isNotEmpty == true ? account.displayName! : state.displayName,
        photoUrl: account.photoUrl,
      );

      // Quét ngầm Google Drive appDataFolder
      final backupService = _ref.read(cloudBackupServiceProvider);
      final backups = await backupService.listBackups();

      if (backups.isNotEmpty) {
        final newest = backups.first;
        final meta = CloudBackupMetadata.fromDriveItem(newest);
        state = state.copyWith(
          isGoogleLoading: false,
          foundCloudBackup: true,
          cloudBackupMetadata: meta,
        );
        return true;
      }

      state = state.copyWith(isGoogleLoading: false);
      return true;
    } catch (e) {
      debugPrint('[OnboardingController] signInWithGoogleAndCheckBackup error: $e');
      state = state.copyWith(isGoogleLoading: false);
      return false;
    }
  }

  /// Khôi phục toàn bộ CSDL từ bản sao lưu Cloud được tìm thấy
  Future<bool> restoreFromCloud() async {
    if (state.cloudBackupMetadata == null) return false;
    state = state.copyWith(isCompleting: true);

    try {
      final backupService = _ref.read(cloudBackupServiceProvider);
      await backupService.performRestoreFromCloud(state.cloudBackupMetadata!.fileId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);

      _ref.read(hasCompletedOnboardingProvider.notifier).state = true;

      state = state.copyWith(isCompleting: false, foundCloudBackup: false);
      return true;
    } catch (e) {
      debugPrint('[OnboardingController] restoreFromCloud error: $e');
      state = state.copyWith(isCompleting: false);
      return false;
    }
  }

  /// 🌟 HOÀN TẤT THIẾT LẬP ONBOARDING:
  /// Tuyệt đối an toàn, bọc try-catch đa lớp, đảm bảo không bao giờ làm đơ nút bấm
  Future<bool> completeOnboarding() async {
    state = state.copyWith(isCompleting: true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Lưu cờ hoàn tất và cấu hình cá nhân vào SharedPreferences
      await prefs.setBool('has_completed_onboarding', true);
      await prefs.setString('user_display_name', state.displayName);
      if (state.photoUrl != null && state.photoUrl!.isNotEmpty) {
        await prefs.setString('user_avatar_value', state.photoUrl!);
      }
      await prefs.setInt('flowy_cycle_start_day', state.cycleStartDay);

      // Cập nhật provider mốc chu kỳ an toàn
      try {
        final now = DateTime.now();
        final monthKey = DateFormat('yyyy-MM').format(now);
        _ref.read(cycleStartDaysByMonthProvider.notifier).update((store) {
          return Map<String, int>.from(store)
            ..['default'] = state.cycleStartDay
            ..[monthKey] = state.cycleStartDay;
        });
      } catch (e) {
        debugPrint('[OnboardingController] Cập nhật mốc chu kỳ lỗi nhẹ: $e');
      }

      // 2. Khởi tạo nguồn tiền ban đầu vào Drift SQLite (bọc riêng try-catch)
      try {
        await _db.transaction(() async {
          final existingWallets = await _db.select(_db.wallets).get();
          final now = DateTime.now();

          if (existingWallets.isEmpty) {
            // Tạo Ví Tiền Mặt mặc định
            await _db.into(_db.wallets).insert(
              WalletsCompanion(
                id: const drift.Value('wallet_cash_default'),
                name: const drift.Value('Tiền mặt'),
                type: const drift.Value('cash'),
                balance: drift.Value(state.cashBalance),
                currency: const drift.Value('VND'),
                icon: const drift.Value('Wallet'),
                color: const drift.Value('#10B981'),
                isDefault: const drift.Value(true),
                isArchived: const drift.Value(false),
                sortOrder: const drift.Value(0),
                createdAt: drift.Value(now),
                updatedAt: drift.Value(now),
              ),
            );

            // Tạo Ví Ngân Hàng
            await _db.into(_db.wallets).insert(
              WalletsCompanion(
                id: const drift.Value('wallet_bank_default'),
                name: const drift.Value('Tài khoản ngân hàng'),
                type: const drift.Value('bank'),
                balance: drift.Value(state.bankBalance),
                currency: const drift.Value('VND'),
                icon: const drift.Value('Landmark'),
                color: const drift.Value('#0EA5E9'),
                isDefault: const drift.Value(false),
                isArchived: const drift.Value(false),
                sortOrder: const drift.Value(1),
                createdAt: drift.Value(now),
                updatedAt: drift.Value(now),
              ),
            );
          } else {
            // Nếu đã tồn tại ví, cập nhật số dư cho các ví đầu tiên
            final cashWallet = existingWallets.firstWhere(
                  (w) => w.type == 'cash',
              orElse: () => existingWallets.first,
            );
            await (_db.update(_db.wallets)..where((w) => w.id.equals(cashWallet.id))).write(
              WalletsCompanion(
                balance: drift.Value(state.cashBalance),
                updatedAt: drift.Value(now),
              ),
            );

            if (existingWallets.length > 1) {
              final bankWallet = existingWallets.firstWhere(
                    (w) => w.type == 'bank',
                orElse: () => existingWallets[1],
              );
              await (_db.update(_db.wallets)..where((w) => w.id.equals(bankWallet.id))).write(
                WalletsCompanion(
                  balance: drift.Value(state.bankBalance),
                  updatedAt: drift.Value(now),
                ),
              );
            }
          }

          // Khởi tạo bản ghi ngân sách ban đầu nếu có danh mục
          final categories = await _db.select(_db.categories).get();
          if (categories.isNotEmpty) {
            final defaultExpenseCat = categories.firstWhere(
                  (c) => c.type == CategoryType.expense,
              orElse: () => categories.first,
            );
            final curMonth = DateTime(now.year, now.month, 1);
            final budgetId = 'b_${DateFormat('yyyy-MM').format(curMonth)}_${defaultExpenseCat.id}';

            await _db.into(_db.budgets).insertOnConflictUpdate(
              BudgetsCompanion(
                id: drift.Value(budgetId),
                categoryId: drift.Value(defaultExpenseCat.id),
                amount: drift.Value(state.monthlyBudget),
                cycleStartDay: drift.Value(state.cycleStartDay),
                periodMonth: drift.Value(curMonth),
                createdAt: drift.Value(now),
              ),
            );
          }
        });
      } catch (dbErr) {
        debugPrint('[OnboardingController] Khởi tạo SQLite có lỗi nhẹ, bỏ qua an toàn: $dbErr');
      }

      // Đánh dấu StateProvider
      try {
        _ref.read(hasCompletedOnboardingProvider.notifier).state = true;
      } catch (_) {}

      state = state.copyWith(isCompleting: false);
      return true;
    } catch (e) {
      debugPrint('[OnboardingController] completeOnboarding fallback: $e');
      // Dự phòng cuối: Đảm bảo luôn ghi SharedPreferences để thoát onboarding
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_completed_onboarding', true);
        _ref.read(hasCompletedOnboardingProvider.notifier).state = true;
      } catch (_) {}

      state = state.copyWith(isCompleting: false);
      return true;
    }
  }
}

final onboardingControllerProvider =
StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  final db = ref.watch(databaseProvider);
  return OnboardingController(ref, db);
});