import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/core/feedback/app_feedback.dart';

void main() {
  late BuildContext context;
  Future<void> mount(WidgetTester tester) async {
    AppFeedback.dismissImmediately();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (value) {
        context = value;
        return const Text('Page');
      },
    ))));
  }

  Future<void> show(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 461));
  }

  Future<void> finish(WidgetTester tester) async {
    AppFeedback.dismissImmediately();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  }

  testWidgets('transientSuccess_preservesTokensAndAutoDismiss', (tester) async {
    await mount(tester);
    AppFeedback.showSuccess(context, 'Success', emitHaptic: false);
    await show(tester);
    expect(find.text('Success'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    final box = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((w) => w.height == AppFeedbackTokens.topBannerHeight);
    expect(box.length, 1);
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 230));
    expect(find.text('Success'), findsNothing);
    await finish(tester);
  });
  testWidgets('newTransient_replacesRatherThanQueues', (tester) async {
    await mount(tester);
    AppFeedback.showInfo(context, 'Old', emitHaptic: false);
    await show(tester);
    AppFeedback.showError(context, 'Latest', emitHaptic: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    await show(tester);
    expect(find.text('Old'), findsNothing);
    expect(find.text('Latest'), findsOneWidget);
    await finish(tester);
  });
  testWidgets('dismissRegion_preservesTransientDismissBehavior',
      (tester) async {
    await mount(tester);
    AppFeedback.showInfo(context, 'Transient', emitHaptic: false);
    await show(tester);
    AppFeedback.dismissCurrent(context);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    expect(find.text('Transient'), findsNothing);
    await finish(tester);
  });
  testWidgets('undo_withLive_preservesThreeSecondLifetimeAndResumesLive',
      (tester) async {
    await mount(tester);
    AppFeedback.capture(context);
    AppFeedback.showLive(const AppLiveFeedback(
        id: 'live',
        message: 'Running',
        icon: Icons.sync_rounded,
        spinning: true));
    await show(tester);
    var undone = 0;
    AppFeedback.showUndo(context, message: 'Deleted', onUndo: () => undone++);
    await show(tester);
    expect(find.text('Deleted'), findsOneWidget);
    expect(find.text('Running'), findsNothing);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('Deleted'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 160));
    await show(tester);
    expect(find.text('Deleted'), findsNothing);
    expect(find.text('Running'), findsOneWidget);
    expect(undone, 0);
    await finish(tester);
  });
  testWidgets('undo_actionRemainsExactlyOnce', (tester) async {
    await mount(tester);
    var undone = 0;
    AppFeedback.showUndo(context, message: 'Deleted', onUndo: () => undone++);
    await show(tester);
    await tester.tap(find.text('HOÀN TÁC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(undone, 1);
    expect(find.text('Deleted'), findsNothing);
    await finish(tester);
  });
  testWidgets('inSituValidation_stillPulsesAndClearsWithoutOverlay',
      (tester) async {
    final controller = AppValidationFeedbackController();
    await tester.pumpWidget(MaterialApp(
        home: AppValidationFeedback(
      controller: controller,
      builder: (_, visual) => Text(visual.isInvalid ? 'Invalid' : 'Valid'),
    )));
    controller.reject(emitHaptic: false);
    await tester.pump();
    expect(find.text('Invalid'), findsOneWidget);
    expect(controller.pulseSerial, 1);
    controller.clear();
    await tester.pump();
    expect(find.text('Valid'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
    controller.dispose();
  });

  testWidgets('inSituValidation_shakeAndBorderPulseRemainActive',
      (tester) async {
    final controller = AppValidationFeedbackController();
    late AppValidationVisualState visual;
    await tester.pumpWidget(MaterialApp(
        home: AppValidationFeedback(
      controller: controller,
      builder: (_, value) {
        visual = value;
        return const Text('Field');
      },
    )));
    controller.reject(emitHaptic: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 15));
    expect(visual.shakeX.abs(), greaterThan(0));
    expect(visual.borderStrength, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(visual.shakeX, closeTo(0, 0.001));
    expect(visual.isInvalid, isTrue);
    controller.clear();
    await tester.pump();
    expect(visual.borderStrength, 0);
    await finish(tester);
    controller.dispose();
  });

  testWidgets('undo_preservesNavigationAnchorAndRouteLifetime', (tester) async {
    AppFeedback.dismissImmediately();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      bottomNavigationBar: const SizedBox(height: 80),
      body: Builder(builder: (value) {
        context = value;
        return const Text('Root');
      }),
    )));
    AppFeedback.showUndo(context, message: 'Deleted', onUndo: () {});
    await show(tester);
    final dock = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_UndoDockOverlay');
    final positioned = tester.widget<Positioned>(find
        .descendant(
          of: dock,
          matching: find.byType(Positioned),
        )
        .first);
    expect(positioned.bottom,
        greaterThanOrEqualTo(80 + AppFeedbackTokens.undoNavigationGap));
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Detail'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Deleted'), findsOneWidget);
    expect(find.text('Detail'), findsOneWidget);
    final lowered = tester.widget<Positioned>(find
        .descendant(
          of: dock,
          matching: find.byType(Positioned),
        )
        .first);
    expect(lowered.bottom, lessThan(positioned.bottom!));
    Navigator.of(context).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Deleted'), findsOneWidget);
    await finish(tester);
  });

  for (final direction in [const Offset(120, 0), const Offset(0, 80)]) {
    testWidgets('undo_swipeDismissPreservesAction_$direction', (tester) async {
      await mount(tester);
      var undone = 0;
      AppFeedback.showUndo(context, message: 'Deleted', onUndo: () => undone++);
      await show(tester);
      await tester.drag(find.text('Deleted'), direction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Deleted'), findsNothing);
      expect(undone, 0);
      await finish(tester);
    });
  }
}
