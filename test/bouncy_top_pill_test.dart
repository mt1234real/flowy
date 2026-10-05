import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/core/feedback/app_feedback.dart';
import 'support/channel1_harness.dart';

void main() {
  late Channel1Harness h;
  setUp(() => h = Channel1Harness());
  for (final step in [
    (0, -30.0, 1.0),
    (130, 48.0, 1.05),
    (190, 33.0, .96),
    (240, 36.0, 1.0)
  ]) {
    testWidgets('z2_entry_${step.$1}ms_exactPhase', (t) async {
      await h.mount(t);
      h.live('Queued');
      await h.frames(t);
      await t.pump(Duration(milliseconds: step.$1));
      expect(h.y(t), closeTo(step.$2, .01));
      expect(h.sy(t), closeTo(step.$3, .001));
      expect(t.getSize(h.surface).height, 42);
    });
  }
  testWidgets('z2_entry_total240ms_fallAccelerates', (t) async {
    await h.mount(t);
    h.live('Queued');
    await h.frames(t);
    await t.pump(const Duration(milliseconds: 35));
    final a = h.y(t) + 30;
    await t.pump(const Duration(milliseconds: 35));
    final b = h.y(t) + 30 - a;
    expect(b, greaterThan(a));
    await t.pump(const Duration(milliseconds: 170));
    expect(h.y(t), 36);
    expect(h.sy(t), 1);
  });
  testWidgets('z2_entry_lightImpactOnlyAtImpactOnce', (t) async {
    await h.mount(t);
    h.live('Queued');
    await h.frames(t);
    await t.pump(const Duration(milliseconds: 129));
    expect(h.haptics, isEmpty);
    await t.pump(const Duration(milliseconds: 1));
    expect(h.haptics, ['HapticFeedbackType.lightImpact']);
    await t.pump(const Duration(milliseconds: 370));
    h.live('Running', running: true);
    await h.reel(t);
    for (var i = 0; i < 5; i++) {
      h.live('Running', running: true);
      await h.frames(t);
    }
    expect(h.haptics, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.selectionClick'
    ]);
  });
  testWidgets('z2_success_mediumImpactAfterReelOnce', (t) async {
    await h.mount(t);
    h.live('Running', running: true);
    await h.settle(t);
    h.live('Success', terminal: true);
    await h.frames(t);
    await t.pump(const Duration(milliseconds: 239));
    expect(h.haptics, ['HapticFeedbackType.lightImpact']);
    await t.pump(const Duration(milliseconds: 1));
    expect(h.haptics,
        ['HapticFeedbackType.lightImpact', 'HapticFeedbackType.mediumImpact']);
    for (var i = 0; i < 5; i++) {
      h.live('Success', terminal: true);
      await h.frames(t);
    }
    expect(h.haptics.length, 2);
  });
  testWidgets('z2_transientSuccessMessageChange_noSecondSuccessHaptic',
      (t) async {
    await h.mount(t);
    AppFeedback.showSuccess(h.page, 'A');
    await h.settle(t);
    expect(h.haptics.length, 2);
    AppFeedback.showSuccess(h.page, 'B');
    await h.reel(t);
    expect(h.haptics.length, 2);
  });
  testWidgets('z2_failure_doesNotEmitSuccessHaptic', (t) async {
    await h.mount(t);
    h.live('Running', running: true);
    await h.settle(t);
    h.live('Safe failure', terminal: true, error: true);
    await h.reel(t);
    expect(h.haptics, ['HapticFeedbackType.lightImpact']);
  });
  testWidgets('channel1_queueToRunning_sameOverlayEntry', (t) async {
    await h.mount(t);
    h.live('Queued');
    await h.settle(t);
    final entry = t.element(h.pill);
    h.live('Running', running: true);
    await h.reel(t);
    expect(t.element(h.pill), same(entry));
    expect(h.y(t), 36);
    expect(h.sy(t), 1);
  });
  testWidgets('channel1_runningToSuccess_sameOverlayEntry', (t) async {
    await h.mount(t);
    h.live('Running', running: true);
    await h.settle(t);
    final entry = t.element(h.pill);
    h.live('Success', terminal: true);
    await h.reel(t);
    expect(t.element(h.pill), same(entry));
    expect(h.y(t), 36);
  });
  for (final terminalWhileCovered in [false, true]) {
    testWidgets(
        'channel1_transientBackToLatestLive_noExit_$terminalWhileCovered',
        (t) async {
      await h.mount(t);
      h.live('Running', running: true);
      await h.settle(t);
      final entry = t.element(h.pill);
      AppFeedback.showSuccess(h.page, 'Transaction', emitHaptic: false);
      await h.reel(t);
      expect(t.element(h.pill), same(entry));
      expect(find.text('Transaction'), findsOneWidget);
      if (terminalWhileCovered) h.live('Success', terminal: true);
      await t.pump(const Duration(milliseconds: 1980));
      await h.reel(t);
      expect(t.element(h.pill), same(entry));
      expect(h.y(t), 36);
      expect(h.sy(t), 1);
      expect(find.text(terminalWhileCovered ? 'Success' : 'Running'),
          findsOneWidget);
      h.single(t);
    });
  }
  testWidgets('channel1_newEventDuringExit_reusesOwnedContainer', (t) async {
    await h.mount(t);
    AppFeedback.showInfo(h.page, 'Old', emitHaptic: false);
    await h.settle(t);
    final entry = t.element(h.pill);
    AppFeedback.dismissCurrent(h.page);
    await t.pump();
    await t.pump(const Duration(milliseconds: 70));
    AppFeedback.showInfo(h.page, 'Latest', emitHaptic: false);
    await h.reel(t);
    expect(t.element(h.pill), same(entry));
    expect(h.y(t), 36);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Latest'), findsOneWidget);
    h.single(t);
  });
  testWidgets('channel1_liveUpdateDuringEntry_doesNotRestartEntry', (t) async {
    await h.mount(t);
    h.live('Queued');
    await h.frames(t);
    await t.pump(const Duration(milliseconds: 70));
    h.live('Running', running: true);
    await h.frames(t);
    await t.pump(const Duration(milliseconds: 70));
    expect(h.y(t), lessThan(48));
    await t.pump(const Duration(milliseconds: 130));
    expect(h.y(t), 36);
    expect(h.haptics, ['HapticFeedbackType.lightImpact']);
  });
  testWidgets('z2_reel_fixedCategoryDoesNotReanimate', (t) async {
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
  testWidgets('z2_reel_oldUp_newBelow_andGlyphMovesTogether', (t) async {
    await h.mount(t);
    h.live('Old');
    await h.settle(t);
    h.live('New', running: true);
    await h.frames(t);
    final newSlide = find.ancestor(
        of: find.text('New'), matching: find.byType(SlideTransition));
    expect(t.widget<SlideTransition>(newSlide).position.value.dy, .8);
    expect(
        t.element(find.ancestor(
            of: h.inside(CircularProgressIndicator),
            matching: find.byType(SlideTransition))),
        same(t.element(newSlide)));
    await t.pump(const Duration(milliseconds: 45));
    final oldSlide = find.ancestor(
        of: find.text('Old'), matching: find.byType(SlideTransition));
    expect(t.widget<SlideTransition>(oldSlide).position.value.dy, lessThan(0));
    final oldOpacity = t
        .widget<FadeTransition>(find.ancestor(
            of: find.text('Old'), matching: find.byType(FadeTransition)))
        .opacity
        .value;
    final newOpacity = t
        .widget<FadeTransition>(find.ancestor(
            of: find.text('New'), matching: find.byType(FadeTransition)))
        .opacity
        .value;
    expect(oldOpacity == 0 || newOpacity == 0, isTrue);
    await t.pump(const Duration(milliseconds: 45));
    await t.pump();
    // Flutter may retain the dismissed switcher child until its next frame;
    // it must already be visually absent at the 90ms boundary.
    expect(oldOpacity, greaterThanOrEqualTo(0));
    final oldFadeAt90 = t.widget<FadeTransition>(find.ancestor(
        of: find.text('Old'), matching: find.byType(FadeTransition)));
    expect(oldFadeAt90.opacity.value, closeTo(0, .001));
    await t.pump(const Duration(milliseconds: 1));
    await t.pump();
    expect(find.text('Old'), findsNothing);
    await t.pump(const Duration(milliseconds: 39));
    expect(t.widget<SlideTransition>(newSlide).position.value.dy, 0);
  });
  testWidgets('z2_reel_explicit90Out130In', (t) async {
    await h.mount(t);
    h.live('Queued');
    await h.settle(t);
    final reel = t.widget<AnimatedSwitcher>(h.inside(AnimatedSwitcher));
    expect(reel.duration, const Duration(milliseconds: 130));
    expect(reel.reverseDuration, const Duration(milliseconds: 90));
  });
  testWidgets('z2_successGlyph_scale85_110_100', (t) async {
    await h.mount(t);
    h.live('Running', running: true);
    await h.settle(t);
    h.live('Success', terminal: true);
    await h.frames(t);
    final transform = find
        .ancestor(
            of: find.byIcon(Icons.check_circle_rounded),
            matching: find.byType(Transform))
        .first;
    expect(t.widget<Transform>(transform).transform.storage[0],
        closeTo(.85, .001));
    await t.pump(const Duration(milliseconds: 70));
    expect(t.widget<Transform>(transform).transform.storage[0],
        closeTo(1.1, .001));
    await t.pump(const Duration(milliseconds: 70));
    expect(t.widget<Transform>(transform).transform.storage[0], 1);
  });
  testWidgets('z2_successHold2000AfterReelThenExit', (t) async {
    await h.mount(t);
    h.live('Running', running: true);
    await h.settle(t);
    h.live('Success', terminal: true);
    await h.frames(t);
    await t.pump(const Duration(milliseconds: 240));
    await t.pump(const Duration(milliseconds: 1999));
    expect(h.y(t), 36);
    await t.pump(const Duration(milliseconds: 1));
    await t.pump(const Duration(milliseconds: 110));
    expect(h.y(t), 36);
    await t.pump(const Duration(milliseconds: 160));
    expect(h.pill, findsNothing);
  });
  testWidgets('z2_exit_total270ms_collapseThenLaunch', (t) async {
    await h.mount(t);
    AppFeedback.showInfo(h.page, 'Old', emitHaptic: false);
    await h.settle(t);
    AppFeedback.dismissCurrent(h.page);
    await t.pump();
    await t.pump(const Duration(milliseconds: 110));
    expect(h.y(t), 36);
    expect(h.sy(t), closeTo(1, .001));
    await t.pump(const Duration(milliseconds: 159));
    expect(h.y(t), closeTo(-60, 3));
    expect(t.widget<Opacity>(h.inside(Opacity).first).opacity, lessThan(.01));
    await t.pump(const Duration(milliseconds: 1));
    expect(h.pill, findsNothing);
  });
  testWidgets('z2_reducedMotion_noImpact_staticReel_mediumSuccessOnce',
      (t) async {
    await h.mount(t, reduced: true);
    h.live('Running', running: true);
    await h.frames(t);
    expect(h.y(t), 36);
    expect(h.sy(t), 1);
    expect(h.haptics, isEmpty);
    expect(h.inside(AnimatedSize), findsNothing);
    expect(h.inside(AnimatedSwitcher), findsNothing);
    expect(
        t
            .widget<CircularProgressIndicator>(
                h.inside(CircularProgressIndicator))
            .value,
        .75);
    h.live('Success', terminal: true);
    await h.frames(t);
    expect(h.haptics, ['HapticFeedbackType.mediumImpact']);
    expect(
        find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_TopSuccessGlyph'),
        findsNothing);
  });
  testWidgets('z2_reducedMotionDuringEntry_staysSettledWhenReenabled',
      (t) async {
    await h.mount(t);
    h.live('Running', running: true);
    await h.frames(t);
    await t.pump(const Duration(milliseconds: 60));
    h.live('Running', running: true, reduced: true);
    await h.frames(t);
    expect(h.y(t), 36);
    expect(h.haptics, isEmpty);
    h.live('Running', running: true);
    await h.frames(t);
    expect(h.y(t), 36);
  });
  for (final pair in [
    ('Short', 'A much longer status message'),
    ('A much longer status message', 'Short')
  ]) {
    testWidgets('z2_width240ms_centerFixed_${pair.$1}', (t) async {
      await h.mount(t);
      h.live(pair.$1);
      await h.settle(t);
      final before = t.getSize(h.surface).width;
      h.live(pair.$2);
      await h.frames(t);
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 20));
        expect(t.getCenter(h.surface).dx, closeTo(400, .5));
        h.single(t);
      }
      expect(t.getSize(h.surface).width, isNot(before));
      expect(h.inside(AnimatedSize), findsNothing);
    });
  }
  testWidgets('z2_rapidQueueRunningTransientSuccess_latestWinsOneSession',
      (t) async {
    await h.mount(t);
    h.live('Queued');
    await h.frames(t);
    final entry = t.element(h.pill);
    await t.pump(const Duration(milliseconds: 60));
    h.live('Running', running: true);
    AppFeedback.showSuccess(h.page, 'Transaction', emitHaptic: false);
    h.live('Success', terminal: true);
    await h.frames(t);
    var sawSuccess = false;
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 100));
      h.single(t);
      if (h.pill.evaluate().isNotEmpty) {
        expect(t.element(h.pill), same(entry));
        expect(t.getCenter(h.surface).dx, closeTo(400, .5));
      }
      sawSuccess |= find.text('Success').evaluate().isNotEmpty;
    }
    expect(sawSuccess, isTrue);
    expect(h.pill, findsNothing);
    expect(
        h.haptics.where((e) => e == 'HapticFeedbackType.mediumImpact').length,
        1);
  });
}
