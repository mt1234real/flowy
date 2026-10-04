import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/core/feedback/app_feedback.dart';

void main() {
  late BuildContext page;
  final pill = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_TopBannerOverlay');
  Finder inside(Type type) =>
      find.descendant(of: pill, matching: find.byType(type));
  Finder surface() => find.descendant(
      of: pill,
      matching: find.byWidgetPredicate((w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == const Color(0xDD111827)));

  Future<void> mount(WidgetTester tester,
      {double safeTop = 0,
      Brightness brightness = Brightness.light,
      bool reduced = false,
      double textScale = 1,
      double screenWidth = 800,
      VoidCallback? onTap}) async {
    AppFeedback.dismissImmediately();
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness, fontFamily: 'SelectedFont'),
        builder: (_, child) => MediaQuery(
            data: MediaQueryData(
                size: Size(screenWidth, 600),
                padding: EdgeInsets.only(top: safeTop),
                disableAnimations: reduced,
                textScaler: TextScaler.linear(textScale)),
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

  void live(String message,
      {bool running = false,
      bool terminal = false,
      AppTopFeedbackTone tone = AppTopFeedbackTone.info,
      bool reduced = false}) {
    AppFeedback.showLive(AppLiveFeedback(
        id: 'test',
        message: message,
        icon: terminal ? Icons.check_circle_rounded : Icons.schedule_rounded,
        spinning: running,
        terminal: terminal,
        tone: tone,
        reduceMotion: reduced));
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
  }

  Future<void> entered(WidgetTester tester) async {
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump(const Duration(milliseconds: 1));
  }

  for (final safe in [0.0, 24.0, 44.0]) {
    testWidgets('zenPill_visibleTop_safe$safe', (tester) async {
      await mount(tester, safeTop: safe);
      live('Status');
      await entered(tester);
      expect(tester.getTopLeft(surface()).dy, closeTo(safe + 14, 0.01));
    });
  }
  testWidgets('zenPill_heightIs36_andUsesNaturalWidth', (tester) async {
    await mount(tester);
    live('Đã lưu');
    await entered(tester);
    final size = tester.getSize(surface());
    expect(size.height, 36);
    expect(size.width, lessThan(200));
    final padding = tester.widget<Padding>(inside(Padding).first);
    expect(padding.padding, const EdgeInsets.symmetric(horizontal: 14));
  });
  testWidgets('zenPill_respectsScreenMaxWidthAndTextScale', (tester) async {
    await mount(tester, textScale: 2);
    live('A very long message ${List.filled(50, '200.000 ₫').join(' ')}');
    await entered(tester);
    expect(tester.getSize(surface()).width, lessThanOrEqualTo(520));
    expect(tester.getSize(surface()).height, 36);
    expect(tester.takeException(), isNull);
  });
  testWidgets('zenPill_narrowScreen_retainsSafeMargins', (tester) async {
    await mount(tester, screenWidth: 320);
    live(List.filled(20, 'Long text').join(' '));
    await entered(tester);
    expect(tester.getSize(surface()).width, lessThanOrEqualTo(288));
    expect(tester.takeException(), isNull);
  });
  for (final longer in [true, false]) {
    testWidgets(
        'zenPill_${longer ? 'shortToLong' : 'longToShort'}_animatesWidthCentered',
        (tester) async {
      await mount(tester);
      const short = 'Đã lưu', long = 'Đã sao lưu lên Google Drive';
      live(longer ? short : long);
      await entered(tester);
      final before = tester.getSize(surface()).width;
      final center = tester.getCenter(surface()).dx;
      live(longer ? long : short);
      await frames(tester);
      await tester.pump(const Duration(milliseconds: 100));
      final middle = tester.getSize(surface()).width;
      expect(tester.getCenter(surface()).dx, closeTo(center, 0.01));
      await tester.pump(const Duration(milliseconds: 160));
      final after = tester.getSize(surface()).width;
      expect(middle, greaterThan(longer ? before : after));
      expect(middle, lessThan(longer ? after : before));
      expect(tester.getCenter(surface()).dx, closeTo(center, 0.01));
      expect(tester.element(pill), isNotNull);
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('zenPill_${brightness.name}_glassAndTypography',
        (tester) async {
      await mount(tester, brightness: brightness);
      live('Status');
      await entered(tester);
      final decoration =
          tester.widget<DecoratedBox>(surface()).decoration as BoxDecoration;
      expect(decoration.color, const Color(0xDD111827));
      expect(decoration.borderRadius, BorderRadius.circular(999));
      final border = decoration.border as Border;
      expect(border.top.width, 0.8);
      expect(border.top.color, Colors.white.withValues(alpha: 0.12));
      final shadow = (tester
              .widget<DecoratedBox>(inside(DecoratedBox).first)
              .decoration as BoxDecoration)
          .boxShadow!
          .single;
      expect(shadow.color, Colors.black.withValues(alpha: 0.18));
      expect(shadow.blurRadius, 16);
      expect(shadow.offset, const Offset(0, 6));
      expect(tester.widget<BackdropFilter>(inside(BackdropFilter)).filter,
          ImageFilter.blur(sigmaX: 16, sigmaY: 16));
      final text = tester.widget<Text>(find.text('Status'));
      expect(text.style!.fontFamily, 'SelectedFont');
      expect(text.style!.fontSize, 12.5);
      expect(text.style!.fontWeight, FontWeight.w600);
      expect(text.style!.color, Colors.white);
      expect(text.style!.letterSpacing, 0.2);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.widget<Material>(inside(Material).first).type,
          MaterialType.transparency);
    });
  }
  testWidgets('zenPill_entry_uses320msMotionFromHiddenTop', (tester) async {
    await mount(tester, safeTop: 24);
    live('Status');
    await tester.pump(); // First layout: hidden.
    expect(tester.getTopLeft(surface()).dy, -60);
    await frames(tester);
    final positioned =
        tester.widget<AnimatedPositioned>(inside(AnimatedPositioned));
    expect(positioned.duration, const Duration(milliseconds: 320));
    expect(positioned.curve, Curves.easeOutBack);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(surface()).dy, greaterThan(-60));
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.getTopLeft(surface()).dy, closeTo(38, 0.01));
  });
  testWidgets('zenPill_exit_uses220msMotion', (tester) async {
    await mount(tester);
    AppFeedback.showInfo(page, 'Status', emitHaptic: false);
    await entered(tester);
    AppFeedback.dismissCurrent(page);
    await tester.pump();
    final positioned =
        tester.widget<AnimatedPositioned>(inside(AnimatedPositioned));
    expect(positioned.top, -60);
    expect(positioned.duration, const Duration(milliseconds: 220));
    expect(positioned.curve, Curves.easeInCubic);
    await tester.pump(const Duration(milliseconds: 100));
    expect(pill, findsOneWidget);
    expect(tester.getTopLeft(surface()).dy, lessThan(14));
    await tester.pump(const Duration(milliseconds: 120));
    expect(pill, findsNothing);
  });
  testWidgets('zenPill_contentSwitch_uses180msSlideUpWithFade', (tester) async {
    await mount(tester);
    live('Queued');
    await entered(tester);
    final element = tester.element(pill);
    live('Running', running: true);
    await frames(tester);
    final switcher = tester.widget<AnimatedSwitcher>(inside(AnimatedSwitcher));
    expect(switcher.duration, const Duration(milliseconds: 180));
    final fade = tester.widget<FadeTransition>(find.ancestor(
        of: find.text('Running'), matching: find.byType(FadeTransition)));
    final slide = tester.widget<SlideTransition>(find.ancestor(
        of: find.text('Running'), matching: find.byType(SlideTransition)));
    expect(fade.opacity.value, 0);
    expect(slide.position.value.dy, 0.25);
    await tester.pump(const Duration(milliseconds: 120));
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    expect(slide.position.value.dy, inExclusiveRange(0, 0.25));
    final outgoingFade = tester.widget<FadeTransition>(find.ancestor(
        of: find.text('Queued'), matching: find.byType(FadeTransition)));
    expect(outgoingFade.opacity.value, 0); // Never two readable labels.
    await tester.pump(const Duration(milliseconds: 60));
    expect(fade.opacity.value, 1);
    expect(slide.position.value.dy, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester
        .pump(); // AnimatedSwitcher removes the dismissed child next frame.
    expect(find.text('Queued'), findsNothing);
    expect(tester.element(pill), same(element));
    final size = tester.widget<AnimatedSize>(inside(AnimatedSize));
    expect(size.duration, const Duration(milliseconds: 260));
  });
  testWidgets('zenPill_successHolds2200msAfterEntry', (tester) async {
    await mount(tester);
    AppFeedback.showSuccess(page, 'Saved', emitHaptic: false);
    await entered(tester);
    await tester.pump(const Duration(milliseconds: 2199));
    expect(
        tester.widget<AnimatedPositioned>(inside(AnimatedPositioned)).top, 14);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
        tester.widget<AnimatedPositioned>(inside(AnimatedPositioned)).top, -60);
    await tester.pump(const Duration(milliseconds: 220));
    expect(pill, findsNothing);
  });
  testWidgets('backupPill_queuedUsesCloudQueueAndPersists', (tester) async {
    await mount(tester);
    live('Đang chờ sao lưu…');
    await entered(tester);
    expect(find.byIcon(Icons.cloud_queue_rounded), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
    expect(pill, findsOneWidget);
  });
  testWidgets('backupPill_terminalSuccessHolds2200msAfterContentTransition',
      (tester) async {
    await mount(tester);
    // Begin with an already-presented outcome to isolate the content/hold clock
    // from the separately covered 800ms minimum pending-status visibility.
    live('Previous failure', terminal: true, tone: AppTopFeedbackTone.error);
    await entered(tester);
    live('Success', terminal: true, tone: AppTopFeedbackTone.success);
    await frames(tester);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('Success'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2199));
    expect(
        tester.widget<AnimatedPositioned>(inside(AnimatedPositioned)).top, 14);
    await tester.pump(const Duration(milliseconds: 1));
    expect(
        tester.widget<AnimatedPositioned>(inside(AnimatedPositioned)).top, -60);
    await tester.pump(const Duration(milliseconds: 220));
    expect(pill, findsNothing);
  });
  testWidgets('backupPill_runningUses13pxProgressStroke1_8WithoutRotation',
      (tester) async {
    await mount(tester);
    live('Đang sao lưu dữ liệu…', running: true);
    await entered(tester);
    final progress = tester
        .widget<CircularProgressIndicator>(inside(CircularProgressIndicator));
    expect(
        tester.getSize(inside(CircularProgressIndicator)), const Size(13, 13));
    expect(progress.strokeWidth, 1.8);
    expect(progress.color, Colors.white);
    expect(progress.value, isNull);
    expect(inside(RotationTransition), findsNothing);
    expect(find.byIcon(Icons.sync_rounded), findsNothing);
    await tester.pump(const Duration(minutes: 1));
    expect(pill, findsOneWidget);
  });
  testWidgets('backupPill_successUsesEmeraldCheckAndFailureSafeContent',
      (tester) async {
    await mount(tester);
    live('Đã sao lưu lên Google Drive',
        terminal: true, tone: AppTopFeedbackTone.success);
    await entered(tester);
    final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
    expect(icon.color, const Color(0xFF34D399));
    expect(icon.size, 15);
    AppFeedback.showError(page, 'Chưa thể sao lưu', emitHaptic: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    await entered(tester);
    expect(find.text('Chưa thể sao lưu'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });
  for (final mediaReduced in [true, false]) {
    testWidgets(
        'zenPill_reducedMotion_${mediaReduced ? 'media' : 'live'}_staticProgress',
        (tester) async {
      await mount(tester, reduced: mediaReduced);
      live('Running', running: true, reduced: !mediaReduced);
      await frames(tester);
      expect(tester.getTopLeft(surface()).dy, 14);
      expect(
          tester
              .widget<AnimatedPositioned>(inside(AnimatedPositioned))
              .duration,
          Duration.zero);
      expect(inside(AnimatedSize), findsNothing);
      expect(inside(AnimatedSwitcher), findsNothing);
      expect(
          tester
              .widget<CircularProgressIndicator>(
                  inside(CircularProgressIndicator))
              .value,
          0.75);
      await tester.pump(const Duration(seconds: 5));
      expect(pill, findsOneWidget);
    });
  }
  testWidgets('zenPill_touchPassesThroughAndCallerIconPreserved',
      (tester) async {
    var taps = 0;
    await mount(tester, onTap: () => taps++);
    AppFeedback.showInfo(page, 'Custom',
        icon: Icons.star_rounded, emitHaptic: false);
    await entered(tester);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(
        tester.widget<IgnorePointer>(inside(IgnorePointer)).ignoring, isTrue);
    final semantics = tester.widget<Semantics>(find.descendant(
        of: pill,
        matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true)));
    expect(semantics.properties.label, 'Custom');
    expect(semantics.properties.liveRegion, isTrue);
    await tester.tapAt(tester.getCenter(surface()));
    expect(taps, 1);
  });
  for (final duringMorph in [false, true]) {
    testWidgets(
        'zenPill_replacementDuring${duringMorph ? 'WidthMorph' : 'Entry'}_neverDuplicates',
        (tester) async {
      await mount(tester);
      live('Queued');
      await frames(tester);
      if (duringMorph) {
        await tester.pump(const Duration(milliseconds: 320));
        live('A longer running backup message', running: true);
        await frames(tester);
      }
      await tester.pump(const Duration(milliseconds: 50));
      AppFeedback.showSuccess(page, 'Transaction', emitHaptic: false);
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(pill.evaluate().length, lessThanOrEqualTo(1));
        expect(inside(BackdropFilter).evaluate().length, lessThanOrEqualTo(1));
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('zenPill_rapidStateStress_latestTerminalResumesThenDismisses',
      (tester) async {
    await mount(tester);
    live('Queued');
    live('Running', running: true);
    AppFeedback.showSuccess(page, 'Transaction', emitHaptic: false);
    live('Đã sao lưu lên Google Drive',
        terminal: true, tone: AppTopFeedbackTone.success);
    await frames(tester);
    var sawTerminal = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      sawTerminal |=
          find.text('Đã sao lưu lên Google Drive').evaluate().isNotEmpty;
      expect(pill.evaluate().length, lessThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    }
    expect(sawTerminal, isTrue);
    expect(pill, findsNothing);
  });
}
