import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pfm_app/screens/vault_auth_screen.dart';
import 'package:pfm_app/screens/vault_pin_change_screen.dart';
import 'package:pfm_app/services/vault_security_service.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/precision_numpad.dart';
import 'package:pfm_app/widgets/preserved_balance_tumbler.dart';
import 'package:pfm_app/screens/savings_vault_screen.dart';
import 'package:pfm_app/data/database.dart';

class UnusedDatabase extends Fake implements AppDatabase {}

class MemorySecurity extends VaultSecurityService {
  VaultSecurityConfig config;
  int saves = 0;
  MemorySecurity(this.config);
  @override
  Future<void> init() async {}
  @override
  VaultSecurityConfig get currentConfig => config;
  @override
  Future<bool> verifyPin(String enteredPin) async => config.pin == enteredPin;
  @override
  Future<void> updatePin({required String newPin, required int length}) async {
    saves++;
    config = VaultSecurityConfig(pin: newPin, length: length, isCustom: true);
  }
}

Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
}

Future<void> mountFlow(WidgetTester tester, MemorySecurity service,
    {bool setup = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      vaultSecurityServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => setup
                                    ? const VaultPinChangeScreen()
                                    : const VaultAuthScreen(
                                        unlockOnly: true,
                                        autoStartBiometrics: false)),
                          ),
                      child: const Text('Open')),
                ))),
  ));
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final length in [4, 6]) {
    testWidgets('$length-digit lockout blocks input and survives reopening',
        (tester) async {
      final pin = length == 4 ? '1234' : '123456';
      await mountFlow(
          tester,
          MemorySecurity(VaultSecurityConfig(
            pin: pin,
            length: length,
            isCustom: true,
          )));
      for (var attempt = 0; attempt < 3; attempt++) {
        await enterPin(tester, '9' * length);
        expect(find.text('Mã PIN không chính xác'),
            attempt < 2 ? findsOneWidget : findsNothing);
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.textContaining('Đã nhập sai 3 lần.'), findsOneWidget);
      // Callback invocation also stays guarded, including accessibility actions.
      tester.widget<PrecisionNumpad>(find.byType(PrecisionNumpad)).onDigit('1');
      await tester.pump();
      expect(
          tester.widget<VaultPinDots>(find.byType(VaultPinDots)).enteredLength,
          0);
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Đã nhập sai 3 lần.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
      expect(find.textContaining('Đã nhập sai 3 lần.'), findsNothing);
      await enterPin(tester, pin);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(VaultAuthScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Goal progress fits on a narrow vault and remains masked',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(UnusedDatabase()),
      savingsGoalsStreamProvider.overrideWith((ref) => Stream.value([
            SavingsGoal(
                id: 'goal',
                title: 'Du lịch',
                icon: 'travel',
                colorHex: '#10B981',
                targetAmount: 1000000,
                currentAmount: 1000000,
                createdAt: DateTime(2026)),
          ])),
    ], child: const MaterialApp(home: SavingsVaultScreen())));
    await tester.pump();
    expect(find.text('Riêng tư'), findsOneWidget);
    final progress = find.text('100% mục tiêu');
    expect(progress, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(progress);
    expect(paragraph.didExceedMaxLines, false);
    final width = tester.getSize(progress).width;
    expect(width, greaterThan(44));
    await tester.tap(find.byTooltip('Ẩn số dư'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
        tester
            .widgetList<PreservedBalanceTumbler>(
                find.byType(PreservedBalanceTumbler))
            .every((widget) => !widget.isVisible),
        true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('PIN mismatch resets to step one at 500ms without saving',
      (tester) async {
    final service = MemorySecurity(VaultSecurityConfig.defaultConfig);
    await mountFlow(tester, service, setup: true);
    expect(find.text('Tạo mã PIN'), findsOneWidget);
    await enterPin(tester, '1111');
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Xác nhận lại mã PIN'), findsOneWidget);
    await enterPin(tester, '2222');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Mã PIN không khớp, vui lòng nhập lại'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 299));
    expect(find.text('Xác nhận lại mã PIN'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Đặt mã PIN mới'), findsOneWidget);
    expect(tester.widget<VaultPinDots>(find.byType(VaultPinDots)).enteredLength,
        0);
    expect(service.saves, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
