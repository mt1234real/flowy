import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/core/feedback/app_feedback.dart';

void main() {
  late BuildContext page;
  final pill = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_TopBannerOverlay');
  Finder inside(Type type) =>
      find.descendant(of: pill, matching: find.byType(type));
  Finder surface() => find.descendant(
      of: pill,
      matching: find.byWidgetPredicate((widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color ==
              const Color(0xCC1F2937)));

  Future<void> mount(WidgetTester tester,
      {double safeTop = 0,
      double width = 800,
      double textScale = 1,
      Brightness brightness = Brightness.light,
      bool reduced = false,
      VoidCallback? onTap}) async {
    AppFeedback.dismissImmediately();
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness, fontFamily: 'SelectedFont'),
        builder: (_, child) => MediaQuery(
            data: MediaQueryData(
                size: Size(width, 600),
                padding: EdgeInsets.only(top: safeTop),
                textScaler: TextScaler.linear(textScale),
                disableAnimations: reduced),
            child: child!),
        home: Builder(builder: (context) {
          page = context;
          return Scaffold(
              body: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: const SizedBox.expand(child: Text('Page'))));
        })));
    AppFeedback.capture(page);
    addTearDown(() async {
      AppFeedback.dismissImmediately();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
    });
  }

  void live(String state, {String? text, bool reduced = false}) {
    AppFeedback.showLive(AppLiveFeedback(
        id: 'backup',
        presentation: AppLiveFeedbackPresentation.ambientBackup,
        message: text ??
            switch (state) {
              'queued' => 'Đang chờ sao lưu',
              'running' => 'Đang sao lưu',
              'success' => 'Đã sao lưu',
              _ => 'Sao lưu chưa hoàn tất',
            },
        icon: switch (state) {
          'queued' => Icons.cloud_queue_rounded,
          'running' => Icons.sync_rounded,
          'success' => Icons.check_rounded,
          _ => Icons.error_outline_rounded,
        },
        tone: state == 'success'
            ? AppTopFeedbackTone.success
            : state == 'failure'
                ? AppTopFeedbackTone.error
                : AppTopFeedbackTone.info,
        terminal: state == 'success' || state == 'failure',
        spinning: state == 'running',
        reduceMotion: reduced));
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      expect(pill.evaluate().length, lessThanOrEqualTo(1));
    }
  }

  Future<void> entered(WidgetTester tester) async {
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 1));
  }

  for (final safe in [0.0, 24.0, 44.0]) {
    testWidgets('backupLive_topIsSafeTopPlus8_$safe', (tester) async {
      await mount(tester, safeTop: safe);
      live('queued');
      await entered(tester);
      expect(tester.getTopLeft(surface()).dy, closeTo(safe + 8, 0.01));
    });
  }
  testWidgets('backupLive_heightIs34_naturalCenteredWidthAndPadding',
      (tester) async {
    await mount(tester);
    live('queued');
    await entered(tester);
    expect(tester.getSize(surface()).height, 34);
    expect(tester.getSize(surface()).width, inExclusiveRange(80, 250));
    expect(tester.getCenter(surface()).dx, 400);
    expect(tester.widget<Padding>(inside(Padding).first).padding,
        const EdgeInsets.symmetric(horizontal: 12));
  });
  testWidgets('backupLive_narrowScreenLongTextAndScalingStayBounded',
      (tester) async {
    await mount(tester, width: 320, textScale: 2);
    live('failure', text: List.filled(20, 'Long message').join(' '));
    await entered(tester);
    expect(tester.getSize(surface()).width, lessThanOrEqualTo(288));
    expect(tester.getSize(surface()).height, 34);
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    testWidgets('backupLive_${brightness.name}_lighterGlassAndInheritedFont',
        (tester) async {
      await mount(tester, brightness: brightness);
      live('queued');
      await entered(tester);
      final decoration =
          tester.widget<DecoratedBox>(surface()).decoration as BoxDecoration;
      expect(decoration.color, const Color(0xCC1F2937));
      expect(decoration.borderRadius, BorderRadius.circular(999));
      final border = decoration.border as Border;
      expect(border.top.width, 0.8);
      expect(border.top.color, Colors.white.withValues(alpha: 0.08));
      final shadow = (tester
              .widget<DecoratedBox>(inside(DecoratedBox).first)
              .decoration as BoxDecoration)
          .boxShadow!
          .single;
      expect(shadow.color, Colors.black.withValues(alpha: 0.11));
      expect(shadow.blurRadius, 11);
      expect(shadow.offset, const Offset(0, 3));
      expect(tester.widget<BackdropFilter>(inside(BackdropFilter)).filter,
          ImageFilter.blur(sigmaX: 12, sigmaY: 12));
      final text = tester.widget<Text>(find.text('Đang chờ sao lưu'));
      expect(text.style!.fontFamily, 'SelectedFont');
      expect(text.style!.fontSize, 12.25);
      expect(text.style!.fontWeight, FontWeight.w600);
      expect(text.style!.letterSpacing, 0.12);
      expect(text.style!.color, Colors.white.withValues(alpha: 0.96));
      expect(tester.widget<Material>(inside(Material)).type,
          MaterialType.transparency);
    });
  }
  testWidgets('backupLive_queuedCompactCopy14pxCloudAndPersistent',
      (tester) async {
    await mount(tester);
    live('queued');
    await entered(tester);
    final cloud = tester.widget<Icon>(find.byIcon(Icons.cloud_queue_rounded));
    expect(cloud.size, 14);
    expect(cloud.color, Colors.white.withValues(alpha: 0.72));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Đang chờ sao lưu'), findsOneWidget);
    expect(pill, findsOneWidget);
  });
  testWidgets('backupLive_runningCompactCopy12pxSpinnerStroke1_5AndPersistent',
      (tester) async {
    await mount(tester);
    live('running');
    await entered(tester);
    final progress = tester
        .widget<CircularProgressIndicator>(inside(CircularProgressIndicator));
    expect(
        tester.getSize(inside(CircularProgressIndicator)), const Size(12, 12));
    expect(progress.strokeWidth, 1.5);
    expect(progress.color, Colors.white.withValues(alpha: 0.92));
    expect(progress.value, isNull);
    expect(find.byIcon(Icons.sync_rounded), findsNothing);
    expect(inside(RotationTransition), findsNothing);
    await tester.pump(const Duration(minutes: 1));
    expect(find.text('Đang sao lưu'), findsOneWidget);
    expect(pill, findsOneWidget);
  });
  testWidgets('backupLive_successCompactCopyPlainEmeraldCheck', (tester) async {
    await mount(tester);
    live('success');
    await entered(tester);
    final check = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    expect(check.size, 14);
    expect(check.color, const Color(0xFF34D399));
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.text('Đã sao lưu'), findsOneWidget);
  });
  testWidgets('backupLive_failureSafeCopySoftErrorAndAutoDismiss',
      (tester) async {
    await mount(tester);
    live('failure');
    await entered(tester);
    final error = tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
    expect(error.size, 14);
    expect(error.color, const Color(0xFFFCA5A5));
    expect(find.text('Sao lưu chưa hoàn tất'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 170));
    expect(pill, findsNothing);
  });
  testWidgets('backupLive_entry200msHasNoBounceAndOnly7pxTravel',
      (tester) async {
    await mount(tester, safeTop: 24);
    live('queued');
    await tester.pump();
    expect(tester.getTopLeft(surface()).dy, 25);
    expect(tester.widget<Opacity>(inside(Opacity)).opacity, 0);
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(surface()).dy, inExclusiveRange(25, 32));
    expect(tester.widget<Opacity>(inside(Opacity)).opacity,
        inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(surface()).dy, 32);
    expect(tester.widget<Opacity>(inside(Opacity)).opacity, 1);
    expect(inside(AnimatedPositioned), findsNothing);
  });
  testWidgets('backupLive_content150msUses3pxFadeAndUpdatesSameEntry',
      (tester) async {
    await mount(tester);
    live('queued');
    await entered(tester);
    final element = tester.element(pill);
    live('running');
    await frames(tester);
    expect(tester.widget<AnimatedSwitcher>(inside(AnimatedSwitcher)).duration,
        const Duration(milliseconds: 150));
    final fade = tester.widget<FadeTransition>(find.ancestor(
        of: find.text('Đang sao lưu'), matching: find.byType(FadeTransition)));
    final transform = tester.widget<Transform>(find
        .ancestor(
            of: find.text('Đang sao lưu'), matching: find.byType(Transform))
        .first);
    expect(transform.transform.storage[13], 3);
    expect(fade.opacity.value, 0);
    await tester.pump(const Duration(milliseconds: 75));
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    final oldTransform = tester.widget<Transform>(find
        .ancestor(
            of: find.text('Đang chờ sao lưu'), matching: find.byType(Transform))
        .first);
    expect(oldTransform.transform.storage[13], inExclusiveRange(-3, 0));
    await tester.pump(const Duration(milliseconds: 75));
    expect(fade.opacity.value, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('Đang chờ sao lưu'), findsNothing);
    expect(tester.element(pill), same(element));
  });
  for (final growing in [true, false]) {
    testWidgets(
        'backupLive_widthMorph200msCentered_${growing ? 'grow' : 'shrink'}',
        (tester) async {
      await mount(tester);
      live('queued', text: growing ? 'Đã lưu' : 'Sao lưu chưa hoàn tất');
      await entered(tester);
      final before = tester.getSize(surface()).width;
      live('running', text: growing ? 'Sao lưu chưa hoàn tất' : 'Đã lưu');
      await frames(tester);
      expect(tester.widget<AnimatedSize>(inside(AnimatedSize)).duration,
          const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 100));
      final middle = tester.getSize(surface()).width;
      expect(tester.getCenter(surface()).dx, 400);
      await tester.pump(const Duration(milliseconds: 100));
      final after = tester.getSize(surface()).width;
      expect(middle, greaterThan(growing ? before : after));
      expect(middle, lessThan(growing ? after : before));
      expect(tester.getCenter(surface()).dx, 400);
    });
  }
  testWidgets('backupLive_successHold1600msThenExit170msOnly6px',
      (tester) async {
    await mount(tester);
    live('success');
    await entered(tester);
    await tester.pump(const Duration(milliseconds: 1599));
    expect(tester.getTopLeft(surface()).dy, 8);
    expect(tester.widget<Opacity>(inside(Opacity)).opacity, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 85));
    expect(tester.getTopLeft(surface()).dy, inExclusiveRange(2, 8));
    expect(tester.widget<Opacity>(inside(Opacity)).opacity,
        inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 85));
    expect(pill, findsNothing);
  });
  for (final mediaReduced in [true, false]) {
    testWidgets('backupLive_reducedMotion_${mediaReduced ? 'media' : 'live'}',
        (tester) async {
      await mount(tester, reduced: mediaReduced);
      live('running', reduced: !mediaReduced);
      await frames(tester);
      expect(tester.getTopLeft(surface()).dy, 8);
      expect(inside(TweenAnimationBuilder<double>), findsNothing);
      expect(inside(AnimatedSize), findsNothing);
      expect(inside(AnimatedSwitcher), findsNothing);
      expect(
          tester
              .widget<CircularProgressIndicator>(
                  inside(CircularProgressIndicator))
              .value,
          0.75);
      live('success', reduced: !mediaReduced);
      await tester.pump(const Duration(milliseconds: 850));
      await frames(tester);
      expect(find.text('Đã sao lưu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('backupLive_successHoldStartsAfter150msContentTransition',
      (tester) async {
    await mount(tester);
    live('failure');
    await entered(tester);
    live('success');
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 1599));
    expect(tester.widget<Opacity>(inside(Opacity)).opacity, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 85));
    expect(tester.widget<Opacity>(inside(Opacity)).opacity,
        inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 85));
    expect(pill, findsNothing);
  });
  testWidgets('backupLive_reducedMotionEnabledDuringEntry_stillCompletes',
      (tester) async {
    await mount(tester);
    live('success');
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 50));
    live('success', reduced: true);
    await frames(tester);
    expect(find.text('Đã sao lưu'), findsOneWidget);
    expect(inside(TweenAnimationBuilder<double>), findsNothing);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();
    expect(pill, findsNothing);
  });
  for (final next in ['running', 'success', 'failure']) {
    testWidgets('backupLive_preMountStateUpdate_${next}_keepsOneLatestPill',
        (tester) async {
      await mount(tester);
      live('queued');
      live(next);
      await entered(tester);
      expect(pill, findsOneWidget);
      expect(find.text('Đang chờ sao lưu'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('backupLive_replacementDuringWidthMorph_neverDuplicates',
      (tester) async {
    await mount(tester);
    live('queued');
    await entered(tester);
    live('running');
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 50));
    AppFeedback.showSuccess(page, 'Transaction', emitHaptic: false);
    live('success');
    await frames(tester);
    var sawTerminal = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      sawTerminal |= find.text('Đã sao lưu').evaluate().isNotEmpty;
      expect(pill.evaluate().length, lessThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    }
    expect(sawTerminal, isTrue);
    expect(pill, findsNothing);
  });
  testWidgets('backupLive_touchPassesThroughAndSemanticsOnlyMessage',
      (tester) async {
    var taps = 0;
    await mount(tester, onTap: () => taps++);
    live('running');
    await entered(tester);
    final semantics = tester.widget<Semantics>(find.descendant(
        of: pill,
        matching: find.byWidgetPredicate((widget) =>
            widget is Semantics && widget.properties.liveRegion == true)));
    expect(semantics.properties.label, 'Đang sao lưu');
    expect(
        tester.widget<IgnorePointer>(inside(IgnorePointer)).ignoring, isTrue);
    await tester.tapAt(tester.getCenter(surface()));
    expect(taps, 1);
    final element = tester.element(pill);
    live('running');
    await frames(tester);
    expect(tester.element(pill), same(element));
  });
  for (final state in ['queued', 'running', 'success', 'failure']) {
    testWidgets('backupLive_${state}ThenTransientBeforeMount_neverDuplicates',
        (tester) async {
      await mount(tester);
      live(state);
      AppFeedback.showSuccess(page, 'Transaction', emitHaptic: false);
      await frames(tester);
      expect(pill, findsOneWidget);
      expect(find.text('Transaction'), findsOneWidget);
      expect(surface(), findsNothing);
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pump(const Duration(milliseconds: 220));
      await entered(tester);
      expect(surface(), findsOneWidget);
      expect(pill, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('backupLive_preMountDismiss_hasNoOrphan', (tester) async {
    await mount(tester);
    live('running');
    AppFeedback.dismissLive('backup');
    await frames(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(pill, findsNothing);
  });
  testWidgets('backupLive_rapidStatesAndReplacementDuringEntry_latestWins',
      (tester) async {
    await mount(tester);
    live('queued');
    live('running');
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 50));
    AppFeedback.showSuccess(page, 'Transaction', emitHaptic: false);
    live('success');
    await frames(tester);
    var sawSuccess = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      sawSuccess |= find.text('Đã sao lưu').evaluate().isNotEmpty;
      expect(pill.evaluate().length, lessThanOrEqualTo(1));
      expect(inside(BackdropFilter).evaluate().length, lessThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    }
    expect(sawSuccess, isTrue);
    expect(find.text('Đang sao lưu'), findsNothing);
    expect(pill, findsNothing);
  });
}
