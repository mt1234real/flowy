import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/core/feedback/app_feedback.dart';

class Channel1Harness {
  late BuildContext page;
  final haptics = <String>[];
  final pill = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_TopBannerOverlay');
  Finder inside(Type type) =>
      find.descendant(of: pill, matching: find.byType(type));
  Finder get surface => find.descendant(
      of: pill,
      matching: find.byWidgetPredicate((w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          ((w.decoration as BoxDecoration).color ==
                  Colors.white.withValues(alpha: .88) ||
              (w.decoration as BoxDecoration).color ==
                  const Color(0xE01A2620))));
  double y(WidgetTester t) =>
      t.widget<Positioned>(inside(Positioned).first).top!;
  double sy(WidgetTester t) =>
      t.widget<Transform>(inside(Transform).first).transform.storage[5];
  final safe = 24.0;
  Future<void> mount(WidgetTester t,
      {double top = 24,
      double width = 800,
      double textScale = 1,
      bool reduced = false,
      Brightness brightness = Brightness.light,
      VoidCallback? onTap}) async {
    AppFeedback.dismissImmediately();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    });
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: brightness, fontFamily: 'SelectedFont'),
      builder: (_, child) => MediaQuery(
          data: MediaQueryData(
              size: Size(width, 600),
              padding: EdgeInsets.only(top: top),
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduced),
          child: child!),
      home: Builder(builder: (context) {
        page = context;
        return Scaffold(
            body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: const SizedBox.expand()));
      }),
    ));
    AppFeedback.capture(page);
    addTearDown(() async {
      AppFeedback.dismissImmediately();
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 5));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  }

  void live(String text,
          {bool running = false,
          bool terminal = false,
          bool error = false,
          bool reduced = false,
          bool backup = true,
          VoidCallback? onPresented}) =>
      AppFeedback.showLive(AppLiveFeedback(
          id: 'backup',
          message: text,
          presentation: backup
              ? AppLiveFeedbackPresentation.ambientBackup
              : AppLiveFeedbackPresentation.standard,
          icon: error
              ? Icons.error_outline_rounded
              : terminal
                  ? Icons.check_circle_rounded
                  : Icons.schedule_rounded,
          tone: error
              ? AppTopFeedbackTone.error
              : terminal
                  ? AppTopFeedbackTone.success
                  : AppTopFeedbackTone.info,
          spinning: running,
          terminal: terminal,
          reduceMotion: reduced,
          onPresented: onPresented));
  Future<void> frames(WidgetTester t) async {
    await t.pump();
    await t.pump();
    await t.pump();
  }

  Future<void> settle(WidgetTester t) async {
    await frames(t);
    await t.pump(const Duration(milliseconds: 501));
  }

  Future<void> reel(WidgetTester t) async {
    await frames(t);
    await t.pump(const Duration(milliseconds: 241));
    await t.pump();
  }

  void single(WidgetTester t) {
    expect(pill.evaluate().length, lessThanOrEqualTo(1));
    expect(inside(BackdropFilter).evaluate().length, lessThanOrEqualTo(1));
    expect(t.takeException(), isNull);
  }
}

// The previous Z1/Z1.1 visual assertions are superseded by this shared HUD
// contract. Both generic live feedback and backup feedback use the same tree.
void registerHudVisualTests({required bool backup}) {
  final prefix = backup ? 'backupHud' : 'genericHud';
  late Channel1Harness h;
  setUp(() => h = Channel1Harness());
  void live(String text,
          {bool running = false,
          bool terminal = false,
          bool error = false,
          bool reduced = false}) =>
      h.live(text,
          backup: backup,
          running: running,
          terminal: terminal,
          error: error,
          reduced: reduced);
  for (final top in [0.0, 24.0, 44.0]) {
    testWidgets('${prefix}_safeTop${top}_plus12', (t) async {
      await h.mount(t, top: top);
      live('Status');
      await h.settle(t);
      expect(t.getTopLeft(h.surface).dy, top + 12);
    });
  }
  testWidgets('${prefix}_normalHeight42_naturalWidth_andTwoRows', (t) async {
    await h.mount(t);
    live('Short');
    await h.settle(t);
    expect(t.getSize(h.surface).height, 42);
    expect(t.getSize(h.surface).width, lessThan(300));
    expect(t.getCenter(h.surface).dx, 400);
    expect(find.text(backup ? 'ĐỒNG BỘ CLOUD' : 'THÔNG BÁO'), findsOneWidget);
    expect(t.widget<Padding>(h.inside(Padding).first).padding,
        const EdgeInsets.symmetric(vertical: 4));
  });
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('${prefix}_largeTextScale${scale}_growsSafelyWithoutOverflow',
        (t) async {
      await h.mount(t, width: 320, textScale: scale);
      live(List.filled(50, 'Long status').join(' '));
      await h.settle(t);
      expect(t.getSize(h.surface).width, lessThanOrEqualTo(288));
      expect(t.getSize(h.surface).height, scale == 1 ? 42 : greaterThan(42));
      expect(t.getSize(h.surface).height, greaterThanOrEqualTo(8 + scale * 27));
      expect(
          t
              .widget<Text>(find.text(List.filled(50, 'Long status').join(' ')))
              .overflow,
          TextOverflow.ellipsis);
      h.single(t);
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('${prefix}_${brightness.name}_glassShadowAndTypography',
        (t) async {
      final dark = brightness == Brightness.dark;
      await h.mount(t, brightness: brightness);
      live('Status');
      await h.settle(t);
      final glass =
          t.widget<DecoratedBox>(h.surface).decoration as BoxDecoration;
      expect(glass.color,
          dark ? const Color(0xE01A2620) : Colors.white.withValues(alpha: .88));
      expect(glass.borderRadius, BorderRadius.circular(999));
      expect((glass.border as Border).top.width, .8);
      expect(
          (glass.border as Border).top.color,
          dark
              ? Colors.white.withValues(alpha: .12)
              : Colors.black.withValues(alpha: .06));
      final shadowBox = h.inside(DecoratedBox).first;
      final shadow =
          (t.widget<DecoratedBox>(shadowBox).decoration as BoxDecoration)
              .boxShadow!
              .single;
      expect(shadow.color, Colors.black.withValues(alpha: dark ? .35 : .08));
      expect(shadow.blurRadius, dark ? 20 : 18);
      expect(shadow.offset, Offset(0, dark ? 8 : 6));
      expect(find.ancestor(of: shadowBox, matching: find.byType(ClipRRect)),
          findsNothing);
      expect(t.widget<BackdropFilter>(h.inside(BackdropFilter)).filter,
          ImageFilter.blur(sigmaX: 18, sigmaY: 18));
      final category =
          t.widget<Text>(find.text(backup ? 'ĐỒNG BỘ CLOUD' : 'THÔNG BÁO'));
      expect(category.style!.fontSize, 10);
      expect(category.style!.fontWeight, FontWeight.w700);
      expect(category.style!.letterSpacing, .5);
      final status = t.widget<Text>(find.text('Status'));
      expect(status.style!.fontSize, 12.5);
      expect(status.style!.fontWeight, FontWeight.w800);
      expect(status.style!.fontFamily, 'SelectedFont');
      expect(status.style!.color, Theme.of(h.page).colorScheme.onSurface);
      expect(t.widget<Material>(h.inside(Material)).type,
          MaterialType.transparency);
    });
  }
  testWidgets('${prefix}_queuedSchedule14_in24GlyphSlot_persistent', (t) async {
    await h.mount(t);
    live('Queued');
    await h.settle(t);
    expect(t.widget<Icon>(find.byIcon(Icons.schedule_rounded)).size, 14);
    expect(
        t
            .widgetList<Positioned>(h.inside(Positioned))
            .where((w) => w.width == 24 && w.height == 24)
            .length,
        1);
    await t.pump(const Duration(minutes: 1));
    expect(h.pill, findsOneWidget);
  });
  testWidgets('${prefix}_running13SpinnerStroke1_8_persistent', (t) async {
    await h.mount(t);
    live('Running', running: true);
    await h.settle(t);
    final progress = t
        .widget<CircularProgressIndicator>(h.inside(CircularProgressIndicator));
    expect(t.getSize(h.inside(CircularProgressIndicator)), const Size(13, 13));
    expect(progress.strokeWidth, 1.8);
    expect(progress.value, isNull);
    expect(progress.color, Theme.of(h.page).colorScheme.onSurface);
    await t.pump(const Duration(minutes: 1));
    expect(h.pill, findsOneWidget);
  });
  testWidgets('${prefix}_successEmerald_and2000HoldAfterEntry', (t) async {
    await h.mount(t);
    live('Success', terminal: true);
    await h.settle(t);
    final icon = t.widget<Icon>(find.byIcon(Icons.check_circle_rounded));
    expect(icon.color, const Color(0xFF34D399));
    expect(icon.size, 15);
    await t.pump(const Duration(milliseconds: 1998));
    expect(h.pill, findsOneWidget);
    await t.pump(const Duration(milliseconds: 2));
    await t.pump(const Duration(milliseconds: 270));
    expect(h.pill, findsNothing);
  });
  testWidgets('${prefix}_failureSafe_noSuccessHaptic_andAutoDismiss',
      (t) async {
    await h.mount(t);
    live('Sao lưu chưa hoàn tất', terminal: true, error: true);
    await h.settle(t);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(h.haptics.where((e) => e == 'HapticFeedbackType.mediumImpact'),
        isEmpty);
    await t.pump(const Duration(milliseconds: 1800));
    await t.pump(const Duration(milliseconds: 270));
    expect(h.pill, findsNothing);
  });
  for (final grow in [true, false]) {
    testWidgets('${prefix}_widthMorph240_centerInvariant_$grow', (t) async {
      await h.mount(t);
      live(grow ? 'Short' : 'A longer status message for backup');
      await h.settle(t);
      final element = t.element(h.pill);
      final before = t.getSize(h.surface).width;
      live(grow ? 'A longer status message for backup' : 'Short');
      await h.frames(t);
      await t.pump(const Duration(milliseconds: 80));
      final middle = t.getSize(h.surface).width;
      expect(t.getCenter(h.surface).dx, closeTo(400, .5));
      await t.pump(const Duration(milliseconds: 160));
      final after = t.getSize(h.surface).width;
      expect(middle, greaterThan(grow ? before : after));
      expect(middle, lessThan(grow ? after : before));
      expect(t.getCenter(h.surface).dx, closeTo(400, .5));
      expect(t.element(h.pill), same(element));
    });
  }
  for (final mediaReduced in [true, false]) {
    testWidgets('${prefix}_reducedMotionStatic_$mediaReduced', (t) async {
      await h.mount(t, reduced: mediaReduced);
      live('Running', running: true, reduced: !mediaReduced);
      await h.frames(t);
      expect(h.y(t), 36);
      expect(h.sy(t), 1);
      expect(h.haptics, isEmpty);
      expect(h.inside(AnimatedSize), findsNothing);
      expect(h.inside(AnimatedSwitcher), findsNothing);
      live('Success', terminal: true, reduced: !mediaReduced);
      await h.frames(t);
      expect(h.haptics, ['HapticFeedbackType.mediumImpact']);
    });
  }
  testWidgets('${prefix}_touchThrough_andOneSemanticLabel', (t) async {
    var taps = 0;
    await h.mount(t, onTap: () => taps++);
    live('Running', running: true);
    await h.settle(t);
    final semantics = find.descendant(
        of: h.pill,
        matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true));
    expect(semantics, findsOneWidget);
    expect(t.widget<Semantics>(semantics).properties.label,
        '${backup ? 'ĐỒNG BỘ CLOUD' : 'THÔNG BÁO'}. Running');
    await t.tapAt(t.getCenter(h.surface));
    expect(taps, 1);
    final element = t.element(semantics);
    live('Running', running: true);
    await h.frames(t);
    expect(t.element(semantics), same(element));
  });
  for (final operation in ['current', 'live', 'immediate']) {
    testWidgets('${prefix}_preMountDismiss_${operation}_noOrphan', (t) async {
      await h.mount(t);
      if (operation == 'current') {
        AppFeedback.showInfo(h.page, 'Transient', emitHaptic: false);
        await t.idle();
        AppFeedback.dismissCurrent(h.page);
      } else {
        live('Running', running: true);
        if (operation == 'live') {
          AppFeedback.dismissLive('backup');
        } else {
          AppFeedback.dismissImmediately();
        }
      }
      await h.frames(t);
      await t.pump(const Duration(seconds: 4));
      expect(h.pill, findsNothing);
    });
  }
  for (final duringMorph in [false, true]) {
    testWidgets(
        '${prefix}_replacementDuring${duringMorph ? 'Morph' : 'Entry'}_oneOwner',
        (t) async {
      await h.mount(t);
      live('Queued');
      await h.frames(t);
      final entry = t.element(h.pill);
      if (duringMorph) {
        await t.pump(const Duration(milliseconds: 501));
        live('A longer running message', running: true);
        await h.frames(t);
      }
      await t.pump(const Duration(milliseconds: 30));
      AppFeedback.showInfo(h.page, 'Transient', emitHaptic: false);
      await h.frames(t);
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 20));
        h.single(t);
        expect(t.element(h.pill), same(entry));
        expect(t.getCenter(h.surface).dx, closeTo(400, .5));
      }
    });
  }
  testWidgets('${prefix}_preMountLiveToTransient_sameContainer', (t) async {
    await h.mount(t);
    live('Running', running: true);
    AppFeedback.showSuccess(h.page, 'Transaction', emitHaptic: false);
    await h.settle(t);
    expect(find.text('Running'), findsNothing);
    expect(find.text('Transaction'), findsOneWidget);
    final entry = t.element(h.pill);
    await t.pump(const Duration(milliseconds: 2000));
    await h.reel(t);
    expect(t.element(h.pill), same(entry));
    expect(find.text('Running'), findsOneWidget);
  });
  testWidgets('${prefix}_genericPublicApisAndCallerIconRemainValid', (t) async {
    await h.mount(t);
    AppFeedback.showInfo(h.page, 'Info',
        icon: Icons.star_rounded, emitHaptic: false);
    await h.settle(t);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.text('THÔNG BÁO'), findsOneWidget);
    AppFeedback.showError(h.page, 'Error', emitHaptic: false);
    await h.reel(t);
    expect(find.text('CẦN CHÚ Ý'), findsOneWidget);
    AppFeedback.showSuccess(h.page, 'Saved', emitHaptic: false);
    await h.reel(t);
    expect(find.text('THÀNH CÔNG'), findsOneWidget);
    expect(h.haptics, isEmpty);
  });
}
