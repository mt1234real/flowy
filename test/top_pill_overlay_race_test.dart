import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/core/feedback/app_feedback.dart';

void main() {
  late BuildContext context;
  final pills = find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_TopBannerOverlay',
  );

  Future<void> mount(WidgetTester tester) async {
    AppFeedback.dismissImmediately();
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const Scaffold(body: Text('Page'));
    })));
    AppFeedback.capture(context);
    addTearDown(() async {
      AppFeedback.dismissImmediately();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
    });
  }

  void live(String message, {bool terminal = false}) {
    AppFeedback.showLive(AppLiveFeedback(
      id: 'request',
      message: message,
      icon: message == 'Failure'
          ? Icons.error_rounded
          : terminal
              ? Icons.check_circle_rounded
              : Icons.sync_rounded,
      tone: message == 'Failure'
          ? AppTopFeedbackTone.error
          : terminal
              ? AppTopFeedbackTone.success
              : AppTopFeedbackTone.info,
      terminal: terminal,
      spinning: !terminal,
    ));
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      expect(pills.evaluate().length, lessThanOrEqualTo(1));
    }
    await tester.pump(const Duration(milliseconds: 200));
    expect(pills.evaluate().length, lessThanOrEqualTo(1));
  }

  Future<void> expire(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1900));
    expect(pills.evaluate().length, lessThanOrEqualTo(1));
    await tester.pump(const Duration(milliseconds: 150));
    await frames(tester);
  }

  testWidgets('topPill_liveThenTransientBeforeMount_neverDuplicates',
      (tester) async {
    await mount(tester);
    live('Running');
    // Deliberately no frame between insertion and replacement.
    AppFeedback.showSuccess(context, 'Transaction', emitHaptic: false);
    await frames(tester);
    expect(pills, findsOneWidget);
    expect(find.text('Transaction'), findsOneWidget);
    expect(find.text('Running'), findsNothing);
    await expire(tester);
    expect(pills, findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
  });

  for (final pair in ['success-success', 'info-error', 'error-success']) {
    testWidgets('topPill_transientThenTransientBeforeMount_$pair',
        (tester) async {
      await mount(tester);
      switch (pair.split('-').first) {
        case 'success':
          AppFeedback.showSuccess(context, 'Old', emitHaptic: false);
        case 'info':
          AppFeedback.showInfo(context, 'Old', emitHaptic: false);
        case 'error':
          AppFeedback.showError(context, 'Old', emitHaptic: false);
      }
      // Finish asynchronous scheduling, but do not mount A's entry.
      await tester.idle();
      if (pair.endsWith('error')) {
        AppFeedback.showError(context, 'Latest', emitHaptic: false);
      } else {
        AppFeedback.showSuccess(context, 'Latest', emitHaptic: false);
      }
      await frames(tester);
      expect(pills, findsOneWidget);
      expect(find.text('Old'), findsNothing);
      expect(find.text('Latest'), findsOneWidget);
      await expire(tester);
      expect(pills, findsNothing);
    });
  }

  testWidgets('topPill_queuedThenRunningBeforeMount_neverDuplicates',
      (tester) async {
    await mount(tester);
    live('Queued');
    live('Running');
    await frames(tester);
    expect(pills, findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Queued'), findsNothing);
  });

  for (final terminal in ['Success', 'Failure']) {
    testWidgets('topPill_runningThen${terminal}BeforeMount_neverDuplicates',
        (tester) async {
      await mount(tester);
      live('Running');
      live(terminal, terminal: true);
      await frames(tester);
      expect(pills, findsOneWidget);
      expect(find.text(terminal), findsOneWidget);
      expect(find.text('Running'), findsNothing);
      await expire(tester);
      expect(pills, findsNothing);
    });
  }

  for (final operation in ['live', 'current', 'immediate']) {
    testWidgets('topPill_dismissBeforeMount_$operation', (tester) async {
      await mount(tester);
      if (operation == 'current') {
        AppFeedback.showInfo(context, 'Transient', emitHaptic: false);
        await tester.idle();
        AppFeedback.dismissCurrent(context);
      } else {
        live('Running');
        if (operation == 'live') {
          AppFeedback.dismissLive('request');
        } else {
          AppFeedback.dismissImmediately();
        }
      }
      await frames(tester);
      expect(pills, findsNothing);
      await tester.pump(const Duration(seconds: 4));
      expect(pills, findsNothing);
    });
  }

  testWidgets('topPill_staleTimerCannotClearReplacement', (tester) async {
    await mount(tester);
    live('Running');
    AppFeedback.showInfo(context, 'Old', emitHaptic: false);
    await frames(tester);
    // Cancel A's mounted timers while retaining the live state.
    AppFeedback.dismissCurrent(context);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await frames(tester);
    expect(find.text('Running'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(pills, findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
  });

  testWidgets('topPill_staleExitCannotRemoveReplacement', (tester) async {
    await mount(tester);
    live('Old');
    await frames(tester);
    final dynamic oldWidget = tester.widget(pills);
    final VoidCallback oldCompletion = oldWidget.onClosed as VoidCallback;
    AppFeedback.dismissLive('request');
    live('Latest');
    await frames(tester);
    // Simulate an already dispatched completion from the revoked owner.
    oldCompletion();
    await frames(tester);
    expect(pills, findsOneWidget);
    expect(find.text('Latest'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(pills, findsOneWidget);
  });

  testWidgets('topPill_revokedTerminalTimerCannotPresentOrResumeOldState',
      (tester) async {
    await mount(tester);
    live('Running');
    await frames(tester);
    var presented = 0;
    AppFeedback.showLive(AppLiveFeedback(
      id: 'request',
      message: 'Old success',
      icon: Icons.check_circle_rounded,
      terminal: true,
      onPresented: () => presented++,
    ));
    AppFeedback.dismissLive('request');
    live('Latest running');
    await frames(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(presented, 0);
    expect(pills, findsOneWidget);
    expect(find.text('Latest running'), findsOneWidget);
    expect(find.text('Old success'), findsNothing);
  });

  testWidgets('topPill_exitInterruptedByImmediateReplacement_isSafe',
      (tester) async {
    await mount(tester);
    AppFeedback.showInfo(context, 'Old', emitHaptic: false);
    await frames(tester);
    AppFeedback.showSuccess(context, 'Pending', emitHaptic: false);
    await tester.pump(const Duration(milliseconds: 50));
    AppFeedback.dismissImmediately();
    live('Latest');
    await frames(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(pills, findsOneWidget);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
  });

  for (final latest in ['Latest running', 'Success', 'Failure']) {
    testWidgets('topPill_liveResumesLatestStateAfterPreMountOverride_$latest',
        (tester) async {
      await mount(tester);
      live('Old running');
      AppFeedback.showSuccess(context, 'Transaction', emitHaptic: false);
      await frames(tester);
      live(latest, terminal: latest != 'Latest running');
      await frames(tester);
      expect(find.text('Transaction'), findsOneWidget);
      await expire(tester);
      expect(pills, findsOneWidget);
      expect(find.text(latest), findsOneWidget);
      expect(find.text('Old running'), findsNothing);
      if (latest != 'Latest running') {
        await expire(tester);
        expect(pills, findsNothing);
      }
    });
  }

  testWidgets('topPill_unavailableRootDoesNotOwnUninsertedEntry',
      (tester) async {
    AppFeedback.dismissImmediately();
    await tester.pumpWidget(const SizedBox.shrink());
    live('Running');
    AppFeedback.dismissLive('request');
    await tester.pump();
    expect(pills, findsNothing);
    expect(tester.takeException(), isNull);
    await mount(tester);
    live('Available');
    await frames(tester);
    expect(pills, findsOneWidget);
  });

  testWidgets('topPill_rootReplacementResumesSameLatestLiveState',
      (tester) async {
    await mount(tester);
    live('Running');
    await frames(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (value) {
      context = value;
      return const Scaffold(body: Text('New root'));
    })));
    AppFeedback.capture(context);
    live('Running');
    await frames(tester);
    expect(pills, findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
  });
}
