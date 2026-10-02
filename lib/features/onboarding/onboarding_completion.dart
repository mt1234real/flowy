import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart' show sharedPreferencesProvider;

/// Shared by routing, initial setup and restore; DB invalidation does not reset it.
final hasCompletedOnboardingProvider =
    StateNotifierProvider<OnboardingCompletionNotifier, bool>((ref) {
  return OnboardingCompletionNotifier(ref.watch(sharedPreferencesProvider));
});

class OnboardingCompletionNotifier extends StateNotifier<bool> {
  OnboardingCompletionNotifier(this._prefs)
      : super(_prefs.getBool('has_completed_onboarding') ?? false);

  final SharedPreferences _prefs;

  Future<void> markCompleted() async {
    if (!await _prefs.setBool('has_completed_onboarding', true)) {
      throw StateError('Không lưu được trạng thái hoàn tất thiết lập');
    }
    if (mounted) state = true;
  }

  Future<void> completeRestore({required bool finishOnboarding}) async {
    if (finishOnboarding ||
        state ||
        (_prefs.getBool('has_completed_onboarding') ?? false)) {
      await markCompleted();
    }
  }
}
