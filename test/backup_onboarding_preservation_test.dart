import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/features/onboarding/controllers/onboarding_controller.dart';
import 'package:pfm_app/features/onboarding/onboarding_completion.dart';
import 'package:pfm_app/main.dart'
    show appSessionKeyProvider, resetAppRootSession;
import 'package:pfm_app/screens/ledger_screen.dart'
    show cycleStartDaysByMonthProvider;
import 'package:pfm_app/services/auth_profile_service.dart';
import 'package:pfm_app/services/cloud_backup_service.dart';
import 'package:pfm_app/services/vault_security_service.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _WalletFixture = ({
  String id,
  String type,
  double balance,
  int sortOrder,
  bool isDefault,
});

const _threeWallets = <_WalletFixture>[
  (
    id: 'Momo',
    type: 'ewallet',
    balance: 107974,
    sortOrder: 0,
    isDefault: false
  ),
  (id: 'VCB', type: 'bank', balance: 1659, sortOrder: 2, isDefault: false),
  (id: 'BIDV', type: 'bank', balance: 613, sortOrder: 1, isDefault: true),
];

const _sevenWallets = <_WalletFixture>[
  (
    id: 'Ví Tiền Mặt',
    type: 'cash',
    balance: 1770000,
    sortOrder: 0,
    isDefault: false
  ),
  (
    id: 'Techcombank',
    type: 'bank',
    balance: 12100000,
    sortOrder: 0,
    isDefault: false
  ),
  (
    id: 'Ví MoMo',
    type: 'ewallet',
    balance: 2650000,
    sortOrder: 0,
    isDefault: false
  ),
  (
    id: 'Techcomb default',
    type: 'bank',
    balance: 87689000,
    sortOrder: 100,
    isDefault: true
  ),
  (
    id: 'Tiền mặt · Mẫu',
    type: 'cash',
    balance: 27969000,
    sortOrder: 101,
    isDefault: false
  ),
  (
    id: 'MoMo · Mẫu',
    type: 'ewallet',
    balance: 9415000,
    sortOrder: 102,
    isDefault: false
  ),
  (
    id: 'Savings/private',
    type: 'savings',
    balance: 20000000,
    sortOrder: 104,
    isDefault: false
  ),
];

Map<String, double> _expected(List<_WalletFixture> fixture) => {
      for (final wallet in fixture) wallet.id: wallet.balance,
    };

Future<Map<String, double>> _balances(AppDatabase db) async => {
      for (final wallet in await db.select(db.wallets).get())
        wallet.id: wallet.balance,
    };

Future<void> _seedWallets(AppDatabase db, List<_WalletFixture> fixture) async {
  for (final wallet in fixture) {
    await db.into(db.wallets).insert(WalletsCompanion.insert(
          id: wallet.id,
          name: wallet.id,
          type: wallet.type,
          balance: Value(wallet.balance),
          sortOrder: Value(wallet.sortOrder),
          isDefault: Value(wallet.isDefault),
          isExcludedFromTotal: Value(wallet.type == 'savings'),
        ));
  }
}

String _budgetId() =>
    'b_${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}_food';

Future<void> _seedBudget(AppDatabase db, {String? id}) async {
  await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: 'food',
        name: 'Food',
        type: CategoryType.expense,
      ));
  final now = DateTime.now();
  await db.into(db.budgets).insert(BudgetsCompanion.insert(
        id: id ?? _budgetId(),
        categoryId: 'food',
        amount: 2000000,
        cycleStartDay: const Value(5),
        periodMonth: DateTime(now.year, now.month),
      ));
}

ProviderContainer _container(AppDatabase db, SharedPreferences prefs) =>
    ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final fixture in [_threeWallets, _sevenWallets]) {
    test(
        '${fixture.length}-wallet restored dataset survives every tested order and repeated completion',
        () async {
      final orders = [
        fixture,
        fixture.reversed.toList(),
        [...fixture.skip(1), fixture.first]
      ];
      for (final order in orders) {
        // No completion/restore flag: existing financial rows alone must guard re-entry.
        SharedPreferences.setMockInitialValues({
          'user_display_name': 'Restored sentinel',
          'flowy_cycle_start_day': 5,
        });
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final container = _container(db, prefs);
        try {
          await _seedWallets(db, order);
          await _seedBudget(db);
          final before = await db.select(db.wallets).get();
          final budgetBefore = await db.select(db.budgets).getSingle();
          final controller =
              container.read(onboardingControllerProvider.notifier);
          expect(await controller.completeOnboarding(), true);
          expect(await controller.completeOnboarding(), true);
          // Compare every balance and the full rows, including default/order/timestamps.
          expect(await _balances(db), _expected(fixture));
          expect(await db.select(db.wallets).get(), before);
          expect(await db.select(db.budgets).getSingle(), budgetBefore);
          expect(prefs.getString('user_display_name'), 'Restored sentinel');
          expect(prefs.getInt('flowy_cycle_start_day'), 5);
          expect(container.read(cycleStartDaysByMonthProvider)['default'], 5);
          expect(prefs.getBool('has_completed_onboarding'), true);
          expect(container.read(hasCompletedOnboardingProvider), true);
          final total = (await _balances(db))
              .values
              .fold(0.0, (sum, value) => sum + value);
          // The seven supplied balances total 161.593M. The screenshot's extra
          // 29.043M is unspecified; do not invent a wallet to force 190.636M.
          expect(total, fixture.length == 3 ? 110246 : 161593000);
        } finally {
          container.dispose();
          await db.close();
        }
      }
    });
  }

  test(
      'Fresh setup saves entered balances/profile/cycle and creates its initial budget once',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = _container(db, prefs);
    try {
      await db.into(db.categories).insert(CategoriesCompanion.insert(
            id: 'food',
            name: 'Food',
            type: CategoryType.expense,
          ));
      final controller = container.read(onboardingControllerProvider.notifier)
        ..updateDisplayName('Fresh name')
        ..updateCashBalance(123000)
        ..updateBankBalance(456000)
        ..updateCycleStartDay(10)
        ..updateMonthlyBudget(3000000);
      expect(container.read(hasCompletedOnboardingProvider), false);
      expect(await controller.completeOnboarding(), true);
      expect(await _balances(db),
          {'wallet_cash_default': 123000.0, 'wallet_bank_default': 456000.0});
      expect(prefs.getString('user_display_name'), 'Fresh name');
      expect(prefs.getInt('flowy_cycle_start_day'), 10);
      expect(container.read(cycleStartDaysByMonthProvider)['default'], 10);
      final budget = await db.select(db.budgets).getSingle();
      expect(budget.amount, 3000000);
      expect(budget.cycleStartDay, 10);
      expect(prefs.getBool('has_completed_onboarding'), true);
      expect(container.read(hasCompletedOnboardingProvider), true);
      controller.updateCashBalance(0);
      expect(await controller.completeOnboarding(), true);
      expect(await _balances(db),
          {'wallet_cash_default': 123000.0, 'wallet_bank_default': 456000.0});
      expect(await db.select(db.budgets).getSingle(), budget);
    } finally {
      container.dispose();
      await db.close();
    }
  });

  test(
      'Initial budget creation preserves an equivalent existing budget with a legacy ID',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = _container(db, prefs);
    try {
      await _seedBudget(db, id: 'legacy-budget-id');
      final before = await db.select(db.budgets).getSingle();
      expect(
          await container
              .read(onboardingControllerProvider.notifier)
              .completeOnboarding(),
          true);
      expect(await db.select(db.budgets).getSingle(), before);
      expect((await db.select(db.wallets).get()).length, 2);
    } finally {
      container.dispose();
      await db.close();
    }
  });

  for (final flag in ['has_completed_onboarding', 'flowy_restored_private']) {
    test('$flag guards an initialized profile even if no wallets remain',
        () async {
      SharedPreferences.setMockInitialValues({
        flag: true,
        'user_display_name': 'Empty restored profile',
        'flowy_cycle_start_day': 5,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = _container(db, prefs);
      try {
        await _seedBudget(db);
        final before = await db.select(db.budgets).getSingle();
        expect(
            await container
                .read(onboardingControllerProvider.notifier)
                .completeOnboarding(),
            true);
        expect(await db.select(db.wallets).get(), isEmpty);
        expect(await db.select(db.budgets).getSingle(), before);
        expect(prefs.getString('user_display_name'), 'Empty restored profile');
        expect(prefs.getInt('flowy_cycle_start_day'), 5);
        expect(container.read(hasCompletedOnboardingProvider), true);
      } finally {
        container.dispose();
        await db.close();
      }
    });
  }

  test('Failed initialization does not falsely persist completion', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory(
      setup: (_) =>
          throw StateError('Injected database initialization failure'),
    ));
    final container = _container(db, prefs);
    final controller = container.read(onboardingControllerProvider.notifier);
    try {
      expect(await controller.completeOnboarding(), false);
      expect(prefs.getBool('has_completed_onboarding'), isNot(true));
      expect(container.read(hasCompletedOnboardingProvider), false);
    } finally {
      container.dispose();
      await db.close();
    }
  });

  test(
      'Restore completion reconciles a cached false state and survives a new container',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    try {
      expect(container.read(hasCompletedOnboardingProvider), false);
      await prefs.setBool('has_completed_onboarding', true);
      await container
          .read(hasCompletedOnboardingProvider.notifier)
          .completeRestore(finishOnboarding: false);
      expect(container.read(hasCompletedOnboardingProvider), true);
    } finally {
      container.dispose();
    }
    final restarted = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    try {
      expect(restarted.read(hasCompletedOnboardingProvider), true);
    } finally {
      restarted.dispose();
    }
  });

  for (final fixture in [_threeWallets, _sevenWallets]) {
    for (final fromWelcome in [true, false]) {
      testWidgets(
          '${fixture.length}-wallet ${fromWelcome ? 'Welcome' : 'Skip → Settings'} restore preserves initialized state through root reset',
          (tester) async {
        late Directory root;
        late ProviderContainer container;
        late SharedPreferences prefs;
        late WidgetRef rootRef;
        final opened = <AppDatabase>[];
        const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
        try {
          await tester.runAsync(() async {
            root = await Directory.systemTemp.createTemp('flowy-backup-fix0-');
            await Directory('${root.path}/docs').create();
            await Directory('${root.path}/cache').create();
            await Directory('${root.path}/cloud').create();
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(pathChannel, (call) async {
              return switch (call.method) {
                'getApplicationDocumentsDirectory' => '${root.path}/docs',
                'getTemporaryDirectory' => '${root.path}/cache',
                _ => throw UnsupportedError(call.method),
              };
            });
            // Fail before any restore/security IO if paths are not sandboxed.
            expect((await getApplicationDocumentsDirectory()).path,
                '${root.path}/docs');
            SharedPreferences.setMockInitialValues({});
            FlutterSecureStorage.setMockInitialValues({
              VaultSecurityService.storageKey: jsonEncode({
                'algorithm': 'pbkdf2-sha256',
                'salt': base64Encode(List.filled(16, 0)),
                'hash': base64Encode(List.filled(32, 0)),
                'iterations': 120000,
                'length': 4,
                'isCustom': false,
              }),
            });
            prefs = await SharedPreferences.getInstance();
            final live = File('${root.path}/docs/pfm_local_vault.sqlite');
            container = ProviderContainer(overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              databaseProvider.overrideWith((ref) {
                final db = AppDatabase.forTesting(NativeDatabase(live));
                opened.add(db);
                ref.onDispose(() => db.close());
                return db;
              }),
            ]);
            expect(container.read(hasCompletedOnboardingProvider), false);
            if (!fromWelcome) {
              expect(
                  await container
                      .read(onboardingControllerProvider.notifier)
                      .completeOnboarding(),
                  true);
              expect(prefs.getBool('has_completed_onboarding'), true);
              expect(container.read(hasCompletedOnboardingProvider), true);
            }
            final snapshot = File('${root.path}/cloud/pfm_local_vault.sqlite');
            final cloud = AppDatabase.forTesting(NativeDatabase(snapshot));
            try {
              await _seedWallets(cloud, fixture);
              await _seedBudget(cloud);
              await cloud
                  .into(cloud.transactions)
                  .insert(TransactionsCompanion.insert(
                    id: 'history-probe',
                    walletId: fixture.first.id,
                    categoryId: 'food',
                    amount: 123,
                    type: CategoryType.expense,
                    date: DateTime(2026, 9, 1),
                  ));
              expect(await _balances(cloud), _expected(fixture));
            } finally {
              await cloud.close();
            }
            await File('${root.path}/cloud/preferences_manifest.json')
                .writeAsString(jsonEncode({
              'user_display_name': 'Restored sentinel',
              'flowy_cycle_start_day': 5,
              'notification_cycle_snapshot': jsonEncode({'default': 5}),
            }));
            // App profile is normally initialized before opening a restore sheet.
            container.read(userProfileNotifierProvider);
            while (container.read(userProfileNotifierProvider).isLoading) {
              await Future<void>.delayed(const Duration(milliseconds: 1));
            }
            final oldController =
                container.read(onboardingControllerProvider.notifier);
            await container
                .read(cloudBackupServiceProvider)
                .restorePreparedBackup(snapshot);
            expect(await _balances(container.read(databaseProvider)),
                _expected(fixture));
            expect(
                identical(oldController,
                    container.read(onboardingControllerProvider.notifier)),
                false);
            // This is the same completion API called by RestoreDiffModal.
            await container
                .read(hasCompletedOnboardingProvider.notifier)
                .completeRestore(finishOnboarding: fromWelcome);
            expect(prefs.getBool('has_completed_onboarding'), true);
            expect(container.read(hasCompletedOnboardingProvider), true);
          });
          // Probe the exact routing state consumed by FlowyApp without booting
          // unrelated Dashboard notification/biometric plugins.
          await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: Consumer(builder: (context, ref, child) {
              rootRef = ref;
              final completed = ref.watch(hasCompletedOnboardingProvider);
              return Directionality(
                textDirection: TextDirection.ltr,
                child: KeyedSubtree(
                  key: ref.watch(appSessionKeyProvider),
                  child: Text(completed ? 'MainScaffold' : 'Welcome'),
                ),
              );
            }),
          ));
          final oldKey = container.read(appSessionKeyProvider);
          resetAppRootSession(rootRef);
          await tester.pump();
          expect(container.read(appSessionKeyProvider), isNot(oldKey));
          expect(find.text('MainScaffold'), findsOneWidget);
          expect(find.text('Welcome'), findsNothing);
          await tester.runAsync(() async {
            final db = container.read(databaseProvider);
            final walletsBefore = await db.select(db.wallets).get();
            final budgetBefore = await db.select(db.budgets).getSingle();
            final historyBefore = await db.select(db.transactions).get();
            // A rebuilt controller has 0/0 inputs; accidental completion is harmless.
            expect(container.read(onboardingControllerProvider).cashBalance, 0);
            expect(container.read(onboardingControllerProvider).bankBalance, 0);
            expect(
                await container
                    .read(onboardingControllerProvider.notifier)
                    .completeOnboarding(),
                true);
            expect(await _balances(db), _expected(fixture));
            expect(await db.select(db.wallets).get(), walletsBefore);
            expect(await db.select(db.budgets).getSingle(), budgetBefore);
            expect(budgetBefore.amount, 2000000);
            expect(budgetBefore.cycleStartDay, 5);
            expect(await db.select(db.transactions).get(), historyBefore);
            expect(historyBefore.single.id, 'history-probe');
            expect(prefs.getString('user_display_name'), 'Restored sentinel');
            expect(prefs.getInt('flowy_cycle_start_day'), 5);
            expect(container.read(cycleStartDaysByMonthProvider)['default'], 5);
          });
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          container.dispose();
          await tester.runAsync(() async {
            for (final db in opened) {
              await db.close();
            }
            // Only the directory created by this test is removed.
            expect(
                root.absolute.path
                    .startsWith(Directory.systemTemp.absolute.path),
                true);
            expect(root.path.contains('flowy-backup-fix0-'), true);
            await root.delete(recursive: true);
          });
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(pathChannel, null);
        }
      });
    }
  }
}
