import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pfm_app/core/feedback/app_feedback.dart';
import 'package:pfm_app/main.dart';
import 'package:pfm_app/services/backup_state.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/backup_progress_curtain.dart';
import 'package:pfm_app/widgets/backup_status_details.dart';
import 'package:pfm_app/widgets/manual_backup_action.dart';
import 'support/channel1_harness.dart';

void main() {
  late StreamController<BackupStatus> statuses;
  late SharedPreferences prefs;
  late Channel1Harness h;
  const queued = 'Đang chờ sao lưu…';
  const running = 'Đang sao lưu dữ liệu…';
  const success = 'Đã sao lưu lên Google Drive';
  const medium = 'HapticFeedbackType.mediumImpact';

  ManualBackupRequest request(ManualBackupPhase phase) => ManualBackupRequest(
        id: 'parity',
        phase: phase,
        queuedAt: DateTime.now(),
        finishedAt: phase == ManualBackupPhase.success ? DateTime.now() : null,
      );

  setUp(() async {
    AppFeedback.dismissImmediately();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    statuses = StreamController<BackupStatus>.broadcast();
    h = Channel1Harness();
    backupNavigatorKey = GlobalKey<NavigatorState>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        h.haptics.add(call.arguments as String);
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

  Future<void> mount(WidgetTester t,
      {bool systemDisabled = true,
      bool accessible = true,
      bool effectiveReduced = false,
      Future<ManualBackupRequest> Function()? enqueue}) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backupStatusProvider.overrideWith((ref) => statuses.stream),
        manualBackupEnqueueProvider.overrideWithValue(
            enqueue ?? () async => request(ManualBackupPhase.queued)),
      ],
      child: MaterialApp(
        navigatorKey: backupNavigatorKey,
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(
            size: const Size(800, 600),
            padding: const EdgeInsets.only(top: 24),
            disableAnimations: systemDisabled,
            accessibleNavigation: accessible,
          ),
          child: Builder(builder: (platformContext) {
            // Exercise the actual production root builder. A genuine local
            // opt-out below the product override remains valid for both pills.
            return buildFlowyFeedbackRoot(
                platformContext,
                effectiveReduced
                    ? MediaQuery(
                        data: MediaQuery.of(platformContext)
                            .copyWith(disableAnimations: true),
                        child: child!)
                    : child);
          }),
        ),
        home: Builder(builder: (context) {
          h.page = context;
          return Scaffold(
            body: ManualBackupAction(
                enabled: true,
                builder: (pending, action) => ElevatedButton(
                    onPressed: action, child: const Text('Manual'))),
          );
        }),
      ),
    ));
    statuses.add(const BackupStatus());
    await h.frames(t);
    AppFeedback.capture(h.page);
    addTearDown(() async {
      AppFeedback.dismissImmediately();
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 3));
    });
  }

  Future<void> emit(WidgetTester t, ManualBackupPhase phase) async {
    statuses.add(BackupStatus(manualRequest: request(phase)));
    await h.frames(t);
  }

  double width(WidgetTester t) => t.getSize(h.surface).width;
  double scaleX(WidgetTester t) =>
      t.widget<Transform>(h.inside(Transform).first).transform.storage[0];
  double slide(WidgetTester t, String message) => t
      .widget<SlideTransition>(find.ancestor(
          of: find.text(message), matching: find.byType(SlideTransition)))
      .position
      .value
      .dy;

  for (final systemDisabled in [false, true]) {
    for (final accessible in [false, true]) {
      testWidgets(
          'backup_genericPolicyParity_system${systemDisabled}_accessible$accessible',
          (t) async {
        await mount(t, systemDisabled: systemDisabled, accessible: accessible);
        expect(MediaQuery.disableAnimationsOf(h.page), isFalse);
        expect(MediaQuery.of(h.page).accessibleNavigation, accessible);
        AppFeedback.showSuccess(h.page, 'Transaction', emitHaptic: false);
        await h.frames(t);
        expect(width(t), 42);
        expect(h.y(t), -30);
        await t.pump(const Duration(milliseconds: 130));
        expect(h.y(t), 48);
        AppFeedback.dismissImmediately();
        await emit(t, ManualBackupPhase.queued);
        expect(width(t), 42);
        expect(h.y(t), -30);
        await t.pump(const Duration(milliseconds: 130));
        expect(h.y(t), 48);
        h.single(t);
      });
    }
  }

  testWidgets('backup_queueToRunning_usesAnimatedMorph', (t) async {
    await mount(t);
    await emit(t, ManualBackupPhase.queued);
    await t.pump(const Duration(milliseconds: 500));
    final owner = t.element(h.pill);
    final category = t.element(find.text('ĐỒNG BỘ CLOUD'));
    final before = width(t);
    await emit(t, ManualBackupPhase.running);
    expect(width(t), closeTo(before, .01));
    expect(slide(t, running), .8);
    await t.pump(const Duration(milliseconds: 45));
    expect(slide(t, queued), lessThan(0));
    expect(slide(t, running), greaterThan(0));
    await t.pump(const Duration(milliseconds: 95));
    final peak = width(t);
    await t.pump(const Duration(milliseconds: 100));
    expect(peak, closeTo(width(t) + 10, .01));
    expect(slide(t, running), 0);
    expect(h.y(t), 36);
    expect(t.element(h.pill), same(owner));
    expect(t.element(find.text('ĐỒNG BỘ CLOUD')), same(category));
    h.single(t);
  });

  testWidgets('backup_runningToSuccess_usesAnimatedMorph', (t) async {
    await mount(t);
    await emit(t, ManualBackupPhase.running);
    await t.pump(const Duration(milliseconds: 500));
    final owner = t.element(h.pill);
    final before = width(t);
    h.haptics.clear();
    await emit(t, ManualBackupPhase.success);
    expect(width(t), closeTo(before, .01));
    expect(slide(t, success), .8);
    await t.pump(const Duration(milliseconds: 45));
    expect(slide(t, running), lessThan(0));
    await t.pump(const Duration(milliseconds: 95));
    final peak = width(t);
    expect(h.haptics, isEmpty);
    await t.pump(const Duration(milliseconds: 100));
    expect(peak, closeTo(width(t) + 10, .01));
    expect(slide(t, success), 0);
    expect(h.haptics, [medium]);
    expect(t.element(h.pill), same(owner));
    await emit(t, ManualBackupPhase.success);
    await t.pump(const Duration(milliseconds: 300));
    expect(h.haptics, [medium]);
    h.single(t);
  });

  testWidgets('backup_success_terminal_usesFullZ3Exit', (t) async {
    await mount(t);
    await emit(t, ManualBackupPhase.running);
    await t.pump(const Duration(milliseconds: 500));
    final owner = t.element(h.pill);
    await emit(t, ManualBackupPhase.success);
    await t.pump(const Duration(milliseconds: 240));
    await t.pump(const Duration(milliseconds: 2000));
    expect(t.element(h.pill), same(owner));
    expect(width(t), greaterThan(42));
    await t.pump(const Duration(milliseconds: 110));
    expect(t.getSize(h.surface), const Size(42, 42));
    expect(h.y(t), 36);
    await t.pump(const Duration(milliseconds: 50));
    expect(width(t) * scaleX(t), closeTo(46, .01));
    expect(42 * h.sy(t), closeTo(36, .01));
    expect(h.y(t), 39);
    await t.pump(const Duration(milliseconds: 109));
    expect(h.y(t), closeTo(-60, .1));
    expect(t.element(h.pill), same(owner));
    await t.pump(const Duration(milliseconds: 1));
    expect(h.pill, findsNothing);
  });

  testWidgets('backup_genuineEffectiveReducedPolicy_matchesGeneric', (t) async {
    await mount(t, effectiveReduced: true);
    expect(MediaQuery.disableAnimationsOf(h.page), isTrue);
    AppFeedback.showInfo(h.page, 'Generic reduced', emitHaptic: false);
    await h.frames(t);
    expect(h.y(t), 36);
    expect(width(t), greaterThan(42));
    expect(h.inside(AnimatedSwitcher), findsNothing);
    AppFeedback.dismissImmediately();
    await emit(t, ManualBackupPhase.queued);
    expect(h.y(t), 36);
    expect(width(t), greaterThan(42));
    await emit(t, ManualBackupPhase.running);
    expect(h.inside(AnimatedSwitcher), findsNothing);
    expect(
        t
            .widget<CircularProgressIndicator>(
                h.inside(CircularProgressIndicator))
            .value,
        .75);
    await emit(t, ManualBackupPhase.success);
    expect(h.haptics, [medium]);
    final semantics = h.inside(Semantics).first;
    expect(t.widget<Semantics>(semantics).properties.label,
        'ĐỒNG BỘ CLOUD. $success');
    await t.pump(const Duration(milliseconds: 2000));
    await t.pump();
    expect(h.pill, findsNothing);
  });

  testWidgets('backup_enqueueSuccess_onlyLiveQueued_noGenericToast', (t) async {
    await mount(t, enqueue: () async {
      final value = request(ManualBackupPhase.queued);
      statuses.add(BackupStatus(manualRequest: value));
      return value;
    });
    await t.tap(find.text('Manual'));
    await h.frames(t);
    expect(find.text('Đã đưa yêu cầu sao lưu vào hàng đợi.'), findsNothing);
    expect(find.text('THÔNG BÁO'), findsNothing);
    expect(find.text('ĐỒNG BỘ CLOUD'), findsOneWidget);
    expect(find.text(queued), findsOneWidget);
    expect(h.y(t), -30);
    h.single(t);
  });

  testWidgets('backup_enqueueFailure_keepsSafeErrorFeedback', (t) async {
    await mount(t, enqueue: () async => throw StateError('secret raw detail'));
    await t.tap(find.text('Manual'));
    await h.frames(t);
    expect(find.textContaining('Chưa đưa được yêu cầu'), findsOneWidget);
    expect(find.textContaining('secret raw detail'), findsNothing);
    expect(find.text('CẦN CHÚ Ý'), findsOneWidget);
    expect(t.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);
    h.single(t);
  });
}
