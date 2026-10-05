// ==============================================================================
// File: lib/features/onboarding/controllers/onboarding_controller.dart
// Architecture: 4-Step Express Onboarding State Controller (30-Second Setup)
// Stack: flutter_riverpod, drift, google_sign_in, shared_preferences
// Features:
// 1. Immutable OnboardingState model (Step 0 to 3):
//    - displayName, photoUrl, cashBalance, bankBalance, cycleStartDay, monthlyBudget
//    - isGoogleLoading, isCompleting, foundCloudBackup, cloudBackupMetadata
// 2. Shared completion state for routing, setup and restore.
// 3. signInWithGoogleAndCheckBackup():
//    - Xác thực GoogleSignIn, lấy thông tin cá nhân.
//    - Quét ngầm Google Drive appDataFolder tìm bản sao lưu cũ.
// 4. restoreFromCloud():
//    - Ủy quyền khôi phục CSDL từ Cloud, đánh dấu hoàn tất onboarding.
// 5. completeOnboarding():
//    - Create initial wallets/budget and profile only for a fresh financial setup.
//    - Preserve existing/restored data on re-entry and mark shared completion.
// ==============================================================================

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/database.dart';
import '../../../screens/ledger_screen.dart' show cycleStartDaysByMonthProvider;
import '../../../services/auth_profile_service.dart';
import '../../../services/cloud_backup_service.dart';
import '../../../theme/app_theme.dart' show sharedPreferencesProvider;
import '../onboarding_completion.dart';

class OnboardingState {
  final int
      currentStep; // 0: Phong cách & Chào mừng, 1: Tên & Google, 2: Ví tiền, 3: Chu kỳ & Hạn mức
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

  OnboardingController(this._ref, this._db)
      : super(const OnboardingState());

  void setStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  void updateDisplayName(String name) {
    state =
        state.copyWith(displayName: name.trim().isEmpty ? 'Bạn' : name.trim());
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
      final profileNotifier = _ref.read(userProfileNotifierProvider.notifier);
      await profileNotifier.signInWithGoogle();
      final profile = _ref.read(currentUserProfileProvider);

      state = state.copyWith(
        displayName: profile.displayName,
        photoUrl: profile.avatarType == UserAvatarType.google
            ? profile.avatarValue
            : null,
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
      debugPrint(
          '[OnboardingController] signInWithGoogleAndCheckBackup error: $e');
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
      final completion = _ref.read(hasCompletedOnboardingProvider.notifier);
      await backupService
          .performRestoreFromCloud(state.cloudBackupMetadata!.fileId);
      await completion.markCompleted();
      if (mounted) {
        state = state.copyWith(isCompleting: false, foundCloudBackup: false);
      }
      return true;
    } catch (e) {
      debugPrint('[OnboardingController] restoreFromCloud error: $e');
      if (mounted) state = state.copyWith(isCompleting: false);
      return false;
    }
  }

  /// Initialize only a new financial profile. Re-entry only marks completion.
  Future<bool> completeOnboarding() async {
    if (state.isCompleting) return false;
    final setup = state;
    state = state.copyWith(isCompleting: true);

    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final initialized =
          (prefs.getBool('has_completed_onboarding') ?? false) ||
              (prefs.getBool('flowy_restored_private') ?? false);
      final created = await _db.transaction(() async {
        final existingWallets = await _db.select(_db.wallets).get();
        // Any existing wallet, including archived wallets, belongs to the user.
        if (initialized || existingWallets.isNotEmpty) return false;

        final now = DateTime.now();
        await _db.into(_db.wallets).insert(
              WalletsCompanion(
                id: const drift.Value('wallet_cash_default'),
                name: const drift.Value('Tiền mặt'),
                type: const drift.Value('cash'),
                balance: drift.Value(setup.cashBalance),
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
        await _db.into(_db.wallets).insert(
              WalletsCompanion(
                id: const drift.Value('wallet_bank_default'),
                name: const drift.Value('Tài khoản ngân hàng'),
                type: const drift.Value('bank'),
                balance: drift.Value(setup.bankBalance),
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

        final categories = await _db.select(_db.categories).get();
        if (categories.isNotEmpty) {
          final defaultExpenseCat = categories.firstWhere(
            (c) => c.type == CategoryType.expense,
            orElse: () => categories.first,
          );
          final curMonth = DateTime(now.year, now.month, 1);
          final budgetId =
              'b_${DateFormat('yyyy-MM').format(curMonth)}_${defaultExpenseCat.id}';
          final existingBudget = await (_db.select(_db.budgets)
                ..where((b) =>
                    b.categoryId.equals(defaultExpenseCat.id) &
                    b.periodMonth.equals(curMonth)))
              .get();
          if (existingBudget.isEmpty) {
            await _db.into(_db.budgets).insert(
                  BudgetsCompanion(
                    id: drift.Value(budgetId),
                    categoryId: drift.Value(defaultExpenseCat.id),
                    amount: drift.Value(setup.monthlyBudget),
                    cycleStartDay: drift.Value(setup.cycleStartDay),
                    periodMonth: drift.Value(curMonth),
                    createdAt: drift.Value(now),
                  ),
                  mode: drift.InsertMode.insertOrIgnore,
                );
          }
        }
        return true;
      });

      if (created) {
        await prefs.setString('user_display_name', setup.displayName);
        if (setup.photoUrl != null && setup.photoUrl!.isNotEmpty) {
          await prefs.setString('user_avatar_value', setup.photoUrl!);
        }
        await prefs.setInt('flowy_cycle_start_day', setup.cycleStartDay);
        final monthKey = DateFormat('yyyy-MM').format(DateTime.now());
        _ref.read(cycleStartDaysByMonthProvider.notifier).update((store) {
          return Map<String, int>.from(store)
            ..['default'] = setup.cycleStartDay
            ..[monthKey] = setup.cycleStartDay;
        });
      }

      await _ref.read(hasCompletedOnboardingProvider.notifier).markCompleted();
      return true;
    } catch (e) {
      debugPrint('[OnboardingController] completeOnboarding error: $e');
      return false;
    } finally {
      if (mounted) state = state.copyWith(isCompleting: false);
    }
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  final db = ref.watch(databaseProvider);
  return OnboardingController(ref, db);
});
