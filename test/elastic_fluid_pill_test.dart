import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/core/feedback/app_feedback.dart';
import 'support/channel1_harness.dart';

void main() {
  late Channel1Harness h;
  setUp(() => h = Channel1Harness());
  const light = 'HapticFeedbackType.lightImpact';
  const medium = 'HapticFeedbackType.mediumImpact';
  const selection = 'HapticFeedbackType.selectionClick';
  double width(WidgetTester t) => t.getSize(h.surface).width;
  double targetWidth(WidgetTester t) {
    double textWidth(String text) {
      final widget = t.widget<Text>(find.text(text));
      final painter = TextPainter(
          text: TextSpan(text: text, style: widget.style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(h.page))
        ..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    final label =
        t.widget<Text>(find.byKey(const ValueKey('top.category'))).data!;
    final texts = t
        .widgetList<Text>(h.inside(Text))
        .where((x) => x.data != label)
        .toList();
    final raw = 60 +
        [textWidth(label), textWidth(texts.last.data!)]
            .reduce((a, b) => a > b ? a : b);
    final max = MediaQuery.sizeOf(h.page).width - 32;
    return raw.clamp(84, max < 520 ? max : 520).toDouble();
  }

  double sx(WidgetTester t) =>
      t.widget<Transform>(h.inside(Transform).first).transform.storage[0];
  double opacity(WidgetTester t) =>
      t.widget<Opacity>(h.inside(Opacity).first).opacity;
  double textOpacity(WidgetTester t, String text) => t
      .widget<Opacity>(find
          .ancestor(of: find.text(text), matching: find.byType(Opacity))
          .first)
      .opacity;
  Future<void> exit(WidgetTester t, {bool haptic = true}) async {
    await h.mount(t);
    AppFeedback.showInfo(h.page, 'Status for exit', emitHaptic: haptic);
    await h.settle(t);
    h.haptics.clear();
    AppFeedback.dismissCurrent(h.page);
    await t.pump();
  }

  for (final step in [
    (0, -30.0, 1.0),
    (130, 48.0, 1.05),
    (190, 33.0, .96),
    (240, 36.0, 1.0)
  ]) {
    testWidgets('z3_drop_${step.$1}ms_exactMilestone', (t) async {
      await h.mount(t);
      h.live('Queued');
      await h.frames(t);
      await t.pump(Duration(milliseconds: step.$1));
      expect(h.y(t), closeTo(step.$2, .01));
      expect(h.sy(t), closeTo(step.$3, .001));
      expect(width(t), 42);
      expect(t.getSize(h.surface).height, 42);
      h.single(t);
    });
  }
  testWidgets('z3_dropImpactHaptic_once', (t) async {
    await h.mount(t);
    h.live('Queued');
    await h.frames(t);
    await t.pump(const Duration(milliseconds: 129));
    expect(h.haptics, isEmpty);
    await t.pump(const Duration(milliseconds: 1));
    expect(h.haptics, [light]);
    await t.pump(const Duration(milliseconds: 370));
    expect(h.haptics, [light]);
  });
  for (final step in [(240, 0.0), (390, 18.0), (460, -4.0), (500, 0.0)]) {
    testWidgets('z3_expand_${step.$1}ms_controlledWidth', (t) async {
      await h.mount(t);
      h.live('A comfortably long backup status');
      await h.frames(t);
      final target = targetWidth(t);
      await t.pump(Duration(milliseconds: step.$1));
      expect(width(t), closeTo(step.$1 == 240 ? 42 : target + step.$2, .01));
      expect(t.getCenter(h.surface).dx, closeTo(400, .5));
      expect(h.y(t), 36);
    });
  }
  testWidgets('z3_expand_centerInvariantEveryFrame', (t) async {
    await h.mount(t);
    h.live('Long status for expansion');
    await h.frames(t);
    for (var i = 0; i < 25; i++) {
      await t.pump(const Duration(milliseconds: 20));
      expect(t.getCenter(h.surface).dx, closeTo(400, .5));
      h.single(t);
    }
  });
  testWidgets('z3_textHiddenUntilShellHasRoom_thenVisible', (t) async {
    await h.mount(t);
    h.live('Status');
    await h.frames(t);
    expect(textOpacity(t, 'Status'), 0);
    await t.pump(const Duration(milliseconds: 240));
    expect(textOpacity(t, 'Status'), 0);
    await t.pump(const Duration(milliseconds: 120));
    expect(textOpacity(t, 'Status'), 0);
    await t.pump(const Duration(milliseconds: 140));
    expect(textOpacity(t, 'Status'), 1);
  });
  testWidgets('z3_glyphCircleCentered_movesSmoothlyToLeadingRegion', (t) async {
    await h.mount(t);
    h.live('Queued');
    await h.frames(t);
    final icon = find.byIcon(Icons.schedule_rounded);
    expect(t.getCenter(icon).dx, 400);
    await t.pump(const Duration(milliseconds: 270));
    final a = t.getCenter(icon).dx;
    await t.pump(const Duration(milliseconds: 1));
    final b = t.getCenter(icon).dx;
    expect((b - a).abs(), lessThan(5));
    await t.pump(const Duration(milliseconds: 229));
    expect(t.getCenter(icon).dx - t.getTopLeft(h.surface).dx, 26);
  });
  for (final grow in [true, false]) {
    for (final ms in [0, 140, 240]) {
      testWidgets('z3_morph_${grow ? 'grow' : 'shrink'}_${ms}ms_keyframe',
          (t) async {
        await h.mount(t);
        h.live(grow ? 'Short' : 'A very long backup status message');
        await h.settle(t);
        final old = width(t);
        final owner = t.element(h.pill);
        h.live(grow ? 'A very long backup status message' : 'Short');
        await h.frames(t);
        final target = targetWidth(t);
        await t.pump(Duration(milliseconds: ms));
        expect(
            width(t),
            closeTo(
                ms == 0
                    ? old
                    : ms == 140
                        ? target + (grow ? 10 : -8)
                        : target,
                .01));
        expect(t.element(h.pill), same(owner));
        expect(t.getCenter(h.surface).dx, closeTo(400, .5));
        expect(h.inside(AnimatedSize), findsNothing);
        h.single(t);
      });
    }
  }
  for (final scale in [1.0, 3.0]) {
    testWidgets('z3_maxWidthClamp_scale$scale', (t) async {
      await h.mount(t, width: 320, textScale: scale);
      h.live('Short');
      await h.settle(t);
      h.live(List.filled(80, 'Long').join(' '));
      await h.frames(t);
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 20));
        expect(width(t), lessThanOrEqualTo(288));
        h.single(t);
      }
      expect(width(t), 288);
    });
  }
  testWidgets('z3_minWidthClamp_tinyScreen', (t) async {
    await h.mount(t, width: 112);
    h.live('Long long status');
    await h.settle(t);
    h.live('X');
    await h.frames(t);
    await t.pump(const Duration(milliseconds: 140));
    expect(width(t), 80);
    h.single(t);
  });
  testWidgets('z3_reel_newBelow_oldUp_glyphAndStatusTogether', (t) async {
    await h.mount(t);
    h.live('Old');
    await h.settle(t);
    h.live('New', running: true);
    await h.frames(t);
    final slide = find.ancestor(
        of: find.text('New'), matching: find.byType(SlideTransition));
    expect(t.widget<SlideTransition>(slide).position.value.dy, .8);
    expect(
        t.element(find.ancestor(
            of: h.inside(CircularProgressIndicator),
            matching: find.byType(SlideTransition))),
        same(t.element(slide)));
    await t.pump(const Duration(milliseconds: 45));
    final oldSlide = find.ancestor(
        of: find.text('Old'), matching: find.byType(SlideTransition));
    expect(t.widget<SlideTransition>(oldSlide).position.value.dy, lessThan(0));
    final newFade = t
        .widget<FadeTransition>(find.ancestor(
            of: find.text('New'), matching: find.byType(FadeTransition)))
        .opacity
        .value;
    final oldFade = t
        .widget<FadeTransition>(find.ancestor(
            of: find.text('Old'), matching: find.byType(FadeTransition)))
        .opacity
        .value;
    expect(newFade == 0 || oldFade == 0, isTrue);
    await t.pump(const Duration(milliseconds: 45));
    await t.pump();
    expect(
        t
            .widget<FadeTransition>(find.ancestor(
                of: find.text('Old'), matching: find.byType(FadeTransition)))
            .opacity
            .value,
        0);
    await t.pump(const Duration(milliseconds: 40));
    expect(t.widget<SlideTransition>(slide).position.value.dy, 0);
  });
  testWidgets('z3_reel_categoryStable', (t) async {
    await h.mount(t);
    h.live('Queued');
    await h.settle(t);
    final category = find.text('ĐỒNG BỘ CLOUD');
    final element = t.element(category);
    h.live('Running', running: true);
    await h.frames(t);
    expect(t.element(category), same(element));
    expect(find.ancestor(of: category, matching: find.byType(SlideTransition)),
        findsNothing);
  });
  for (final terminal in [false, true]) {
    testWidgets('z3_morph_hapticPriority_success$terminal', (t) async {
      await h.mount(t);
      h.live('Queued');
      await h.settle(t);
      h.haptics.clear();
      h.live(terminal ? 'Success' : 'Running',
          running: !terminal, terminal: terminal);
      await h.frames(t);
      await t.pump(const Duration(milliseconds: 239));
      expect(h.haptics, isEmpty);
      await t.pump(const Duration(milliseconds: 1));
      expect(h.haptics, [terminal ? medium : selection]);
      for (var i = 0; i < 5; i++) {
        h.live(terminal ? 'Success' : 'Running',
            running: !terminal, terminal: terminal);
        await h.frames(t);
      }
      expect(h.haptics.length, 1);
    });
  }
  testWidgets('z3_staleMorphCallback_noHaptic', (t) async {
    await h.mount(t);
    h.live('A');
    await h.settle(t);
    h.haptics.clear();
    h.live('B');
    await h.frames(t);
    await t.pump(const Duration(milliseconds: 100));
    h.live('C', terminal: true, error: true);
    await h.frames(t);
    await t.pump(const Duration(milliseconds: 500));
    expect(h.haptics, isEmpty);
  });
  for (final ms in [60, 110, 160, 269]) {
    testWidgets('z3_exit_${ms}ms_physicalMilestone', (t) async {
      await exit(t);
      await t.pump(Duration(milliseconds: ms));
      if (ms >= 110) {
        expect(width(t), 42);
        expect(t.getSize(h.surface).height, 42);
      }
      if (ms == 60) {
        expect(textOpacity(t, 'Status for exit'), 0);
        expect(h.y(t), 36);
      }
      if (ms == 110) {
        expect(h.y(t), 36);
        expect(sx(t), 1);
        expect(h.sy(t), 1);
      }
      if (ms == 160) {
        expect(h.y(t), 39);
        expect(width(t) * sx(t), closeTo(46, .01));
        expect(42 * h.sy(t), closeTo(36, .01));
      }
      if (ms == 269) {
        expect(h.y(t), closeTo(-60, .1));
        expect(42 * sx(t), closeTo(38, .01));
        expect(42 * h.sy(t), closeTo(46, .01));
        expect(opacity(t), lessThan(.001));
      }
      h.single(t);
    });
  }
  testWidgets('z3_exit_total270ms_removesOnlyAtEnd', (t) async {
    await exit(t);
    await t.pump(const Duration(milliseconds: 269));
    expect(h.pill, findsOneWidget);
    await t.pump(const Duration(milliseconds: 1));
    expect(h.pill, findsNothing);
  });
  testWidgets('z3_exitLaunch_lightImpactOnlyAt160Once', (t) async {
    await exit(t);
    await t.pump(const Duration(milliseconds: 159));
    expect(h.haptics, isEmpty);
    await t.pump(const Duration(milliseconds: 1));
    expect(h.haptics, [light]);
    await t.pump(const Duration(milliseconds: 110));
    expect(h.haptics, [light]);
  });
  for (final ms in [50, 140, 200]) {
    testWidgets('z3_cancelExitAt${ms}_sameOwner_safeRecovery', (t) async {
      await exit(t);
      final owner = t.element(h.pill);
      await t.pump(Duration(milliseconds: ms));
      final currentWidth = width(t);
      final y = h.y(t);
      AppFeedback.showInfo(h.page, 'Latest with new volume');
      await h.frames(t);
      expect(width(t), closeTo(currentWidth, .01));
      expect(h.y(t), closeTo(y, .01));
      await h.reel(t);
      expect(t.element(h.pill), same(owner));
      expect(find.text('Latest with new volume'), findsOneWidget);
      expect(h.y(t), 36);
      expect(h.sy(t), 1);
      expect(sx(t), 1);
      h.single(t);
      expect(h.haptics.where((e) => e == light).length, ms < 160 ? 0 : 1);
      await t.pump(const Duration(milliseconds: 300));
      expect(h.pill, findsOneWidget);
    });
  }
  for (final ms in [60, 330, 550]) {
    testWidgets('z3_interruptDropExpandMorphAt${ms}_latestWins', (t) async {
      await h.mount(t);
      h.live('Queued');
      await h.frames(t);
      final owner = t.element(h.pill);
      if (ms == 550) {
        await t.pump(const Duration(milliseconds: 500));
        h.live('Intermediate volume');
        await h.frames(t);
        await t.pump(const Duration(milliseconds: 50));
      } else {
        await t.pump(Duration(milliseconds: ms));
      }
      final before = width(t);
      h.live('Latest', running: true);
      await h.frames(t);
      expect(width(t), closeTo(before, .01));
      for (var i = 0; i < 30; i++) {
        await t.pump(const Duration(milliseconds: 20));
        h.single(t);
        expect(t.element(h.pill), same(owner));
      }
      expect(find.text('Latest'), findsOneWidget);
      expect(h.y(t), 36);
      expect(h.haptics.where((e) => e == light).length, 1);
      expect(h.haptics.where((e) => e == selection).length, 1);
    });
  }
  testWidgets('z3_liveTransientLatestSuccess_noCollapse_sameSession',
      (t) async {
    await h.mount(t);
    h.live('Queued');
    await h.settle(t);
    final owner = t.element(h.pill);
    h.live('Running', running: true);
    await h.reel(t);
    AppFeedback.showSuccess(h.page, 'Transaction', emitHaptic: false);
    await h.reel(t);
    h.live('Success', terminal: true);
    await h.frames(t);
    await t.pump(const Duration(milliseconds: 2000));
    await h.reel(t);
    expect(t.element(h.pill), same(owner));
    expect(h.y(t), 36);
    expect(find.text('Running'), findsNothing);
    expect(find.text('Success'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 2000));
    await t.pump(const Duration(milliseconds: 270));
    expect(h.pill, findsNothing);
  });
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('z3_accessibility${scale}_circleThenGrowingHudThenCircle',
        (t) async {
      await h.mount(t, textScale: scale, width: 320);
      AppFeedback.showInfo(h.page, 'Status');
      await h.frames(t);
      expect(t.getSize(h.surface), const Size(42, 42));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.getSize(h.surface).height, scale == 1 ? 42 : greaterThan(42));
      AppFeedback.dismissCurrent(h.page);
      await t.pump();
      await t.pump(const Duration(milliseconds: 110));
      expect(t.getSize(h.surface), const Size(42, 42));
      expect(textOpacity(t, 'Status'), 0);
      h.single(t);
    });
  }
  testWidgets('z3_reducedMotion_skipsAllMotionHaptics', (t) async {
    await h.mount(t, reduced: true);
    h.live('Queued');
    await h.frames(t);
    expect(h.y(t), 36);
    expect(width(t), greaterThan(42));
    expect(h.haptics, isEmpty);
    h.live('Running', running: true);
    await h.frames(t);
    expect(h.haptics, isEmpty);
    h.live('Success', terminal: true);
    await h.frames(t);
    expect(h.haptics, [medium]);
    await t.pump(const Duration(milliseconds: 2000));
    await t.pump();
    expect(h.pill, findsNothing);
    expect(h.haptics, [medium]);
  });
  testWidgets('z3_entryWidthMaxClampedNoTextOverflow', (t) async {
    await h.mount(t, width: 320);
    h.live(List.filled(100, 'Long').join(' '));
    await h.frames(t);
    for (var i = 0; i < 25; i++) {
      await t.pump(const Duration(milliseconds: 20));
      expect(width(t), lessThanOrEqualTo(288));
      h.single(t);
    }
  });
}
