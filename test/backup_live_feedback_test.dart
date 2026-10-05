import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pfm_app/core/feedback/app_feedback.dart';
import 'package:pfm_app/services/backup_capsule.dart';
import 'package:pfm_app/services/backup_state.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/backup_live_feedback_host.dart';
import 'package:pfm_app/widgets/backup_status_details.dart';

void main() {
  late StreamController<BackupStatus> statuses;
  late SharedPreferences prefs;
  late GlobalKey<NavigatorState> navigator;
  late List<String> haptics;
  late BuildContext pageContext;
  final now = DateTime.now();

  ManualBackupRequest request(ManualBackupPhase phase,
          {String id = 'manual', DateTime? finishedAt}) =>
      ManualBackupRequest(
        id: id,
        phase: phase,
        queuedAt: now,
        startedAt: phase == ManualBackupPhase.queued ? null : now,
        finishedAt: phase == ManualBackupPhase.success ||
                phase == ManualBackupPhase.failure
            ? finishedAt ?? DateTime.now()
            : null,
        message: phase == ManualBackupPhase.failure
            ? 'RAW exception token secret'
            : null,
      );

  setUp(() async {
    AppFeedback.dismissImmediately();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    statuses = StreamController<BackupStatus>.broadcast();
    navigator = GlobalKey<NavigatorState>();
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
  });
  tearDown(() async {
    AppFeedback.dismissImmediately();
    await statuses.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> frames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  Future<void> mount(WidgetTester tester,
      {bool reduced = false, bool realStream = false}) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (!realStream)
            backupStatusProvider.overrideWith((ref) => statuses.stream),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: ThemeData(fontFamily: 'Roboto'),
          builder: (_, child) => BackupLiveFeedbackHost(
              navigatorKey: navigator, reduceMotion: reduced, child: child!),
          home: Scaffold(
              body: AppFeedbackDismissRegion(child: Builder(builder: (context) {
            pageContext = context;
            return TextButton(onPressed: () {}, child: const Text('Settings'));
          }))),
        )));
    await frames(tester);
  }

  Future<void> emit(WidgetTester tester, ManualBackupPhase phase) async {
    statuses.add(BackupStatus(manualRequest: request(phase)));
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 461));
  }

  Future<void> finish(WidgetTester tester) async {
    AppFeedback.dismissImmediately();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  Finder pill() => find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_TopBannerOverlay');
  Future<void> transient(WidgetTester tester, String message) async {
    AppFeedback.showSuccess(pageContext, message, emitHaptic: false);
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 230));
    await frames(tester); // Mount/start the replacement capsule's entry.
    await tester.pump(const Duration(milliseconds: 461));
  }

  Future<void> expire(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 230));
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 461));
  }

  testWidgets('backupLive_queuedShowsQueuedPill', (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.queued);
    expect(find.text('Đang chờ sao lưu…'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(pill(), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    await finish(tester);
  });
  testWidgets('backupLive_runningDoesNotAutoTimeout', (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.running);
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Đang sao lưu dữ liệu…'), findsOneWidget);
    expect(pill(), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    await finish(tester);
  });
  testWidgets('backupLive_queuedToRunningUpdatesInPlace', (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.queued);
    final element = tester.element(pill());
    await emit(tester, ManualBackupPhase.running);
    expect(tester.element(pill()), same(element));
    expect(find.text('Đang chờ sao lưu…'), findsNothing);
    expect(find.text('Đang sao lưu dữ liệu…'), findsOneWidget);
    await finish(tester);
  });
  for (final phase in [ManualBackupPhase.success, ManualBackupPhase.failure]) {
    testWidgets('backupLive_runningTo${phase.name}_morphsAndThenDismisses',
        (tester) async {
      await mount(tester);
      await emit(tester, ManualBackupPhase.running);
      final element = tester.element(pill());
      await emit(tester, phase);
      await tester.pump(const Duration(milliseconds: 850));
      await tester.pump(const Duration(milliseconds: 461));
      expect(tester.element(pill()), same(element));
      expect(
          find.text(phase == ManualBackupPhase.success
              ? 'Đã sao lưu lên Google Drive'
              : 'Sao lưu chưa hoàn tất'),
          findsOneWidget);
      expect(find.textContaining('RAW exception'), findsNothing);
      expect(haptics.length, phase == ManualBackupPhase.success ? 2 : 1);
      await expire(tester);
      expect(pill(), findsNothing);
      await finish(tester);
    });
  }
  testWidgets('backupLive_fastSuccessUsesReelWithoutReplayingEntry',
      (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.running);
    await emit(tester, ManualBackupPhase.success);
    expect(find.text('Đang sao lưu dữ liệu…'), findsNothing);
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pump(const Duration(milliseconds: 461));
    expect(find.text('Đã sao lưu lên Google Drive'), findsOneWidget);
    await finish(tester);
  });
  testWidgets('backupLive_runningMiniSpinnerWithoutLayoutJitter',
      (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.running);
    final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator));
    expect(progress.value, isNull);
    expect(progress.strokeWidth, 1.8);
    expect(find.byIcon(Icons.sync_rounded), findsNothing);
    await tester
        .pump(const Duration(milliseconds: 461)); // Finish capsule entry.
    final position = tester.getTopLeft(find.text('Đang sao lưu dữ liệu…'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getTopLeft(find.text('Đang sao lưu dữ liệu…')), position);
    await finish(tester);
  });
  testWidgets('backupLive_reducedMotionUsesStaticProgress', (tester) async {
    await mount(tester, reduced: true);
    await emit(tester, ManualBackupPhase.running);
    final progress = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator));
    await tester.pump(const Duration(milliseconds: 350));
    expect(progress.value, 0.75);
    await finish(tester);
  });
  testWidgets('backupLive_pollingSameStateDoesNotRetriggerHapticOrSemantics',
      (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.running);
    final element = tester.element(pill());
    for (var i = 0; i < 5; i++) {
      await emit(tester, ManualBackupPhase.running);
    }
    expect(tester.element(pill()), same(element));
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    final semantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((w) => w.properties.liveRegion == true)
        .toList();
    expect(semantics.length, 1);
    expect(semantics.single.properties.label,
        'ĐỒNG BỘ CLOUD. Đang sao lưu dữ liệu…');
    await finish(tester);
  });
  testWidgets('backupLive_transientSuccessTemporarilyOverridesAndResumes',
      (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.running);
    await transient(tester, 'Đã ghi chép: 200.000 ₫');
    expect(find.text('Đã ghi chép: 200.000 ₫'), findsOneWidget);
    expect(find.text('Đang sao lưu dữ liệu…'), findsNothing);
    expect(pill(), findsOneWidget);
    await expire(tester);
    expect(find.text('Đang sao lưu dữ liệu…'), findsOneWidget);
    expect(pill(), findsOneWidget);
    await finish(tester);
  });
  testWidgets('backupLive_completionDuringTransientResumesTerminalState',
      (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.running);
    await transient(tester, 'Entry');
    await emit(tester, ManualBackupPhase.success);
    expect(find.text('Entry'), findsOneWidget);
    expect(pill(), findsOneWidget);
    await expire(tester);
    expect(find.text('Đã sao lưu lên Google Drive'), findsOneWidget);
    expect(find.text('Đang sao lưu dữ liệu…'), findsNothing);
    await expire(tester);
    expect(pill(), findsNothing);
    await finish(tester);
  });
  testWidgets('backupLive_multipleTransientsNoQueueOrTwoPills', (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.running);
    for (var i = 0; i < 8; i++) {
      AppFeedback.showInfo(pageContext, 'Entry $i', emitHaptic: false);
    }
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 230));
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 461));
    expect(find.text('Entry 7'), findsOneWidget);
    expect(find.text('Entry 0'), findsNothing);
    expect(pill(), findsOneWidget);
    await expire(tester);
    expect(find.text('Đang sao lưu dữ liệu…'), findsOneWidget);
    await finish(tester);
  });
  testWidgets('backupLive_survivesRouteChangeAndSettingsDisposal',
      (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.running);
    navigator.currentState!.pushReplacement(PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) =>
            const Scaffold(body: Text('Another tab'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await frames(tester);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('Đang sao lưu dữ liệu…'), findsOneWidget);
    expect(find.byType(BackupLiveFeedbackHost), findsOneWidget);
    expect(pill(), findsOneWidget);
    await finish(tester);
  });
  testWidgets('backupLive_dismissRegionDoesNotDismissLive', (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.running);
    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 461));
    expect(find.text('Đang sao lưu dữ liệu…'), findsOneWidget);
    await finish(tester);
  });
  testWidgets('backupLive_oldSuccessDoesNotReplayEveryStartup', (tester) async {
    await mount(tester);
    final terminal = request(ManualBackupPhase.success,
        finishedAt: DateTime.now().subtract(const Duration(days: 1)));
    statuses.add(BackupStatus(manualRequest: terminal));
    await frames(tester);
    expect(pill(), findsNothing);
    await finish(tester);
  });
  testWidgets('backupLive_terminalReceiptSurvivesProviderRecreation',
      (tester) async {
    final terminal = request(ManualBackupPhase.success);
    await mount(tester);
    statuses.add(BackupStatus(manualRequest: terminal));
    await frames(tester);
    await expire(tester);
    expect(prefs.containsKey(backupLivePresentedKey), isTrue);
    await finish(tester);
    await mount(tester);
    statuses.add(BackupStatus(manualRequest: terminal));
    await frames(tester);
    expect(pill(), findsNothing);
    await finish(tester);
  });
  testWidgets('backupLive_crossIsolatePersistedUpdateEventuallyAppears',
      (tester) async {
    await mount(tester, realStream: true);
    // Direct persisted write deliberately emits no foreground store event.
    await prefs.setString(backupManualRequestKey,
        jsonEncode(request(ManualBackupPhase.running).toJson()));
    await tester.pump(const Duration(seconds: 15));
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 461));
    expect(find.text('Đang sao lưu dữ liệu…'), findsOneWidget);
    await finish(tester);
  });
  testWidgets('backupLive_foregroundResumeRefreshesPersistedRunning',
      (tester) async {
    await mount(tester, realStream: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await prefs.setString(backupManualRequestKey,
        jsonEncode(request(ManualBackupPhase.running).toJson()));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 461));
    expect(find.text('Đang sao lưu dữ liệu…'), findsOneWidget);
    await finish(tester);
  });
  testWidgets('backupLive_presentationReceiptNeverExportedOrDirtiesBackup',
      (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.success);
    expect(prefs.containsKey(backupLivePresentedKey), isTrue);
    expect(prefs.containsKey(backupDirtyRevisionKey), isFalse);
    final exported = await exportBackupPreferences(prefs);
    expect(exported.containsKey(backupLivePresentedKey), isFalse);
    await finish(tester);
  });

  testWidgets('backupLive_queuedIsPersistentAndMissingRequestDismisses',
      (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.queued);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Đang chờ sao lưu…'), findsOneWidget);
    statuses.add(const BackupStatus());
    await frames(tester);
    expect(pill(), findsNothing);
    await finish(tester);
  });
  testWidgets('backupLive_updateBeforeOverlayMountUsesLatestState',
      (tester) async {
    await mount(tester);
    AppFeedback.capture(pageContext);
    AppFeedback.showLive(const AppLiveFeedback(
        id: 'early', message: 'Queued', icon: Icons.schedule_rounded));
    AppFeedback.showLive(const AppLiveFeedback(
        id: 'early',
        message: 'Running',
        icon: Icons.sync_rounded,
        spinning: true));
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 461));
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Queued'), findsNothing);
    expect(pill(), findsOneWidget);
    await finish(tester);
  });
  testWidgets('backupLive_failureDuringTransientResumesSafeTerminal',
      (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.running);
    await transient(tester, 'Entry');
    await emit(tester, ManualBackupPhase.failure);
    expect(find.text('Entry'), findsOneWidget);
    await expire(tester);
    expect(find.text('Sao lưu chưa hoàn tất'), findsOneWidget);
    expect(find.textContaining('RAW exception'), findsNothing);
    await expire(tester);
    expect(pill(), findsNothing);
    await finish(tester);
  });
  testWidgets('backupLive_occludedTerminalIsNotConsumedUntilVisible',
      (tester) async {
    await mount(tester, realStream: true);
    final store = BackupStateStore(prefs);
    await store.writeManualRequest(request(ManualBackupPhase.running));
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 461));
    await transient(tester, 'Entry');
    await store.writeManualRequest(request(ManualBackupPhase.success));
    await frames(tester);
    expect(prefs.containsKey(backupLivePresentedKey), isFalse);
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester);
    await expire(tester);
    expect(find.text('Đã sao lưu lên Google Drive'), findsOneWidget);
    expect(prefs.containsKey(backupLivePresentedKey), isTrue);
    expect(haptics.length, 2);
    await finish(tester);
  });
  testWidgets('backupLive_terminalPollingDoesNotRepeatHapticOrHold',
      (tester) async {
    await mount(tester);
    final terminal = request(ManualBackupPhase.failure);
    statuses.add(BackupStatus(manualRequest: terminal));
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 461));
    for (var i = 0; i < 5; i++) {
      statuses.add(BackupStatus(manualRequest: terminal));
      await frames(tester);
    }
    expect(haptics.length, 1);
    await expire(tester);
    expect(pill(), findsNothing);
    await finish(tester);
  });
  testWidgets('backupLive_visibleTerminalYieldAndResumeHasOnlyOneHaptic',
      (tester) async {
    await mount(tester);
    await emit(tester, ManualBackupPhase.success);
    expect(haptics.length, 2);
    await transient(tester, 'Entry');
    await expire(tester);
    expect(find.text('Đã sao lưu lên Google Drive'), findsOneWidget);
    expect(haptics.length, 2);
    await finish(tester);
  });
  testWidgets('backupLive_rootListenerIsSingleAcrossNavigation',
      (tester) async {
    var subscriptions = 0;
    statuses.onListen = () => subscriptions++;
    await mount(tester);
    await emit(tester, ManualBackupPhase.running);
    for (var i = 0; i < 3; i++) {
      navigator.currentState!.push(PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, __, ___) => const Scaffold(body: Text('Tab'))));
      await frames(tester);
      navigator.currentState!.pop();
      await frames(tester);
    }
    expect(subscriptions, 1);
    expect(find.byType(BackupLiveFeedbackHost), findsOneWidget);
    expect(pill(), findsOneWidget);
    await finish(tester);
  });
  testWidgets('backupLive_backgroundCompletionSurfacesOnceOnResume',
      (tester) async {
    await mount(tester, realStream: true);
    await BackupStateStore(prefs)
        .writeManualRequest(request(ManualBackupPhase.running));
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 461));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await prefs.setString(backupManualRequestKey,
        jsonEncode(request(ManualBackupPhase.success).toJson()));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 461));
    expect(find.text('Đã sao lưu lên Google Drive'), findsOneWidget);
    await expire(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester);
    expect(pill(), findsNothing);
    await finish(tester);
  });
  testWidgets('backupLive_hidesWhenBackgroundedAndDoesNotBlockTouches',
      (tester) async {
    await mount(tester, realStream: true);
    await BackupStateStore(prefs)
        .writeManualRequest(request(ManualBackupPhase.running));
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 461));
    final ignoring = tester.widget<IgnorePointer>(
        find.descendant(of: pill(), matching: find.byType(IgnorePointer)));
    expect(ignoring.ignoring, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await frames(tester);
    expect(pill(), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    statuses
        .add(BackupStatus(manualRequest: request(ManualBackupPhase.running)));
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 461));
    expect(find.text('Đang sao lưu dữ liệu…'), findsOneWidget);
    await finish(tester);
  });
}
