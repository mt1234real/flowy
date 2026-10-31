import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfm_app/core/animation/app_animation_policy.dart';
import 'package:pfm_app/core/animation/flowy_navigation_motion.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/features/insights/insights_data.dart';
import 'package:pfm_app/features/insights/insights_donut.dart';
import 'package:pfm_app/features/insights/spending_insights_screen.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:pfm_app/widgets/spending_trend_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Routes extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

// Static title/chart fixture: the production route, with no loading or intro
// animation, isolates page choreography from the real Insights content.
Widget _page(String name) => Scaffold(
      key: ValueKey(name),
      appBar: AppBar(
          title: Text(name,
              style: const TextStyle(fontFamily: 'N4RFixture', fontSize: 20)),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0),
      body: Stack(children: [
        const Positioned(
            left: 28,
            top: 30,
            right: 28,
            child: Text('Chi tiêu theo nhóm',
                style: TextStyle(fontSize: 18, fontFamily: 'N4RFixture'))),
        Positioned(
            left: 32,
            top: name == 'child' ? 80 : 140,
            child: CustomPaint(
                size: const Size(170, 170),
                painter: _StaticChart(
                    name == 'child' ? Colors.teal : Colors.orange))),
        const Positioned(
            left: 230,
            top: 150,
            child: Text('Wants\nNeeds\nBổ sung',
                style: TextStyle(height: 2, fontFamily: 'N4RFixture'))),
      ]),
    );

class _StaticChart extends CustomPainter {
  const _StaticChart(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24;
    canvas.drawArc(Offset.zero & size, -.8, 4.5, false, paint);
    paint.color = Colors.blue;
    canvas.drawArc(Offset.zero & size, 3.7, 1.78, false, paint);
  }

  @override
  bool shouldRepaint(_StaticChart oldDelegate) => color != oldDelegate.color;
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  const directory = String.fromEnvironment('FLOWY_CAPTURE');
  if (directory.isEmpty) return;
  final image =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(key)).toImageSync();
  await tester.runAsync(() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$name.png').writeAsBytes(data!.buffer.asUint8List());
  });
  image.dispose();
}

Finder _slides(String name) => find.ancestor(
      of: find.byKey(ValueKey(name), skipOffstage: false),
      matching: find.byType(SlideTransition, skipOffstage: false),
    );

double _pageOpacity(WidgetTester tester, String name) => tester
    .widgetList<FadeTransition>(find.ancestor(
      of: find.byKey(ValueKey(name), skipOffstage: false),
      matching: find.byType(FadeTransition, skipOffstage: false),
    ))
    .fold(1.0, (value, fade) => value * fade.opacity.value);

Future<void> _back(WidgetTester tester, String method, [int edge = 0]) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(MethodCall(
      method,
      method == 'startBackGesture' || method == 'updateBackGestureProgress'
          ? <String, dynamic>{
              'touchOffset': <double>[edge == 0 ? 5.0 : 795.0, 300.0],
              'progress': method == 'startBackGesture' ? 0.0 : .4,
              'swipeEdge': edge,
            }
          : null,
    )),
    (_) {},
  );
  await tester.pump();
}

Future<GlobalKey<NavigatorState>> _mount(WidgetTester tester) async {
  final key = GlobalKey<NavigatorState>();
  await tester.pumpWidget(MaterialApp(
    navigatorKey: key,
    theme: ThemeData(
      platform: TargetPlatform.android,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      }),
    ),
    onGenerateRoute: (settings) => flowyWorkspaceRoute<dynamic>(
        settings: settings, builder: (_) => _page('root')),
  ));
  await tester.pumpAndSettle();
  return key;
}

Future<void> _expectBackgroundPixels(
    WidgetTester tester, GlobalKey boundaryKey, Color background) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
  final image = boundary.toImageSync();
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
  for (final x in [0, 400, 799]) {
    final offset = (550 * image.width + x) * 4;
    expect(bytes!.getUint8(offset), closeTo(background.r * 255, 2));
    expect(bytes.getUint8(offset + 1), closeTo(background.g * 255, 2));
    expect(bytes.getUint8(offset + 2), closeTo(background.b * 255, 2));
    expect(bytes.getUint8(offset + 3), 255);
  }
  image.dispose();
}

class _GestureLifecycleProbe extends StatefulWidget {
  const _GestureLifecycleProbe({super.key});
  @override
  State<_GestureLifecycleProbe> createState() => _GestureLifecycleProbeState();
}

class _GestureLifecycleProbeState extends State<_GestureLifecycleProbe> {
  int deactivations = 0;
  int activations = 0;
  int builds = 0;
  @override
  void deactivate() {
    deactivations++;
    super.deactivate();
  }

  @override
  void activate() {
    activations++;
    super.activate();
  }

  @override
  Widget build(BuildContext context) {
    builds++;
    return _page('child');
  }
}

void main() {
  setUpAll(() async {
    final font = FontLoader('N4RFixture')
      ..addFont(
          rootBundle.load('assets/google_fonts/BeVietnamPro-Regular.ttf'));
    await font.load();
  });

  for (final cancel in [true, false]) {
    testWidgets('predictiveVsyncDemand_${cancel ? "cancel" : "commit"}',
        (tester) async {
      final nav = await _mount(tester);
      final route = flowyReferenceRoute<void>(builder: (_) => _page('child'));
      nav.currentState!.push(route);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await _back(tester, 'startBackGesture');
      expect(tester.binding.transientCallbackCount, 1);
      await _back(tester, 'updateBackGestureProgress');
      final progress = route.animation!.value;
      final rect = tester.getRect(find.byKey(const ValueKey('child')));
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(microseconds: 8333));
        // Requesting vsync cannot manufacture progress or another animation.
        expect(route.animation!.value, progress);
        expect(tester.getRect(find.byKey(const ValueKey('child'))), rect);
        expect(tester.binding.transientCallbackCount, 1);
        expect(tester.binding.hasScheduledFrame, true);
      }
      await _back(tester, cancel ? 'cancelBackGesture' : 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(nav.currentState!.userGestureInProgress, false);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, false);
      expect(find.text('child'), cancel ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('predictiveVsyncDemand_pauseStopsRequests', (tester) async {
    final nav = await _mount(tester);
    nav.currentState!
        .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
    await tester.pumpAndSettle();
    await _back(tester, 'startBackGesture');
    expect(tester.binding.transientCallbackCount, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _back(tester, 'updateBackGestureProgress');
    expect(tester.binding.transientCallbackCount, 1);
    await _back(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('predictiveVsyncDemand_disposeCancelsPendingRequest',
      (tester) async {
    final nav = await _mount(tester);
    nav.currentState!
        .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
    await tester.pumpAndSettle();
    await _back(tester, 'startBackGesture');
    expect(tester.binding.transientCallbackCount, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, false);
    expect(tester.takeException(), isNull);
  });

  for (final edge in [0, 1]) {
    for (final cancel in [false, true]) {
      testWidgets(
          'predictiveStableSubtree_edge${edge}_${cancel ? "cancel" : "commit"}',
          (tester) async {
        final nav = await _mount(tester);
        final probe = GlobalKey<_GestureLifecycleProbeState>();
        final route = flowyReferenceRoute<void>(
            builder: (_) => _GestureLifecycleProbe(key: probe));
        nav.currentState!.push(route);
        await tester.pumpAndSettle();
        final state = probe.currentState!;
        final builds = state.builds;
        final deactivations = state.deactivations;
        final activations = state.activations;
        final child = find.byKey(const ValueKey('child'));
        final renderObject = tester.renderObject(child);
        await _back(tester, 'startBackGesture', edge);
        // Both directions, with non-rounded progress values.
        for (final progress in [
          .0312345,
          .4123456,
          .7245678,
          .1912345,
          .4345678
        ]) {
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
              'flutter/backgesture',
              const StandardMethodCodec()
                  .encodeMethodCall(MethodCall('updateBackGestureProgress', {
                'touchOffset': [edge == 0 ? 160.0 : 640.0, 320.0],
                'progress': progress,
                'swipeEdge': edge,
              })),
              (_) {});
          await tester.pump();
          expect(route.animation!.value, closeTo(1 - progress, 1e-12));
          expect(tester.renderObject(child), same(renderObject));
          expect(state.deactivations, deactivations);
          expect(state.activations, activations);
          expect(state.builds, builds,
              reason: 'Progress must rebuild motion, not the page subtree');
          final transforms = tester
              .widgetList<Transform>(
                  find.ancestor(of: child, matching: find.byType(Transform)))
              .toList();
          expect(
              transforms.any((transform) =>
                  (transform.transform.entry(0, 0) - (1 - .1 * progress))
                      .abs() <
                  1e-10),
              isTrue);
        }
        final beforeRelease = tester.getRect(child);
        await _back(tester, cancel ? 'cancelBackGesture' : 'commitBackGesture');
        expect(tester.getRect(child), beforeRelease);
        expect(state.deactivations, deactivations);
        expect(state.activations, activations);
        await tester.pumpAndSettle();
        if (cancel) {
          expect(probe.currentState, same(state));
          expect(state.deactivations, deactivations);
          expect(state.activations, activations);
          expect(tester.getRect(child), const Rect.fromLTWH(0, 0, 800, 600));
        } else {
          expect(probe.currentState, isNull);
        }
        expect(nav.currentState!.userGestureInProgress, false);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final nested in [false, true]) {
    for (final edge in [0, 1]) {
      for (final cancel in [false, true]) {
        testWidgets(
            'coveredPredictiveSaturation_${nested ? "nested" : "root"}_edge${edge}_${cancel ? "cancel" : "commit"}',
            (tester) async {
          final nav = GlobalKey<NavigatorState>();
          final probe = GlobalKey<_GestureLifecycleProbeState>();
          await tester.pumpWidget(MaterialApp(
            navigatorKey: nav,
            theme: ThemeData(
              platform: TargetPlatform.android,
              pageTransitionsTheme: const PageTransitionsTheme(builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              }),
            ),
            onGenerateRoute: (settings) => flowyWorkspaceRoute<dynamic>(
                settings: settings,
                builder: (_) => nested
                    ? _page('workspace')
                    : _GestureLifecycleProbe(key: probe)),
          ));
          await tester.pumpAndSettle();
          if (nested) {
            nav.currentState!.push(flowyReferenceRoute<void>(
                builder: (_) => _GestureLifecycleProbe(key: probe)));
            await tester.pumpAndSettle();
          }
          final route =
              flowyReferenceRoute<void>(builder: (_) => _page('front'));
          nav.currentState!.push(route);
          await tester.pumpAndSettle();
          final state = probe.currentState!;
          final deactivations = state.deactivations;
          final activations = state.activations;
          final covered =
              find.byKey(const ValueKey('child'), skipOffstage: false);
          final render = tester.renderObject(covered);
          await _back(tester, 'startBackGesture', edge);
          final builds = state.builds;
          for (final progress in [.4, .99, 1.0, 1.0, .99, 1.0, .5, .1]) {
            await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
                'flutter/backgesture',
                const StandardMethodCodec()
                    .encodeMethodCall(MethodCall('updateBackGestureProgress', {
                  'touchOffset': [edge == 0 ? 160.0 : 640.0, 300.0],
                  'progress': progress,
                  'swipeEdge': edge,
                })),
                (_) {});
            await tester.pump();
            expect(nav.currentState!.userGestureInProgress, true);
            expect(state.deactivations, deactivations,
                reason: 'Covered page must stay mounted at progress $progress');
            expect(state.activations, activations);
            expect(state.builds, builds);
            expect(probe.currentState, same(state));
            expect(tester.renderObject(covered), same(render));
            expect(
                tester.getRect(covered), const Rect.fromLTWH(0, 0, 800, 600));
          }
          await _back(
              tester, cancel ? 'cancelBackGesture' : 'commitBackGesture');
          await tester.pumpAndSettle();
          expect(probe.currentState, same(state));
          expect(state.deactivations, deactivations);
          expect(state.activations, activations);
          expect(nav.currentState!.userGestureInProgress, false);
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
        'workspace_normalPilotAndNonPilotMatchOriginal_${platform.name}',
        (tester) async {
      Future<List<Object>> sample(bool workspace) async {
        final nav = GlobalKey<NavigatorState>();
        final theme = ThemeData(
          platform: platform,
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          }),
        );
        await tester.pumpWidget(MaterialApp(
          navigatorKey: nav,
          theme: theme,
          onGenerateRoute: (settings) => workspace
              ? flowyWorkspaceRoute<dynamic>(
                  settings: settings, builder: (_) => _page('root'))
              : PreservedMaterialPageRoute<dynamic>(
                  settings: settings, builder: (_) => _page('root')),
        ));
        await tester.pumpAndSettle();
        final poses = <Object>[];
        // Include an ordinary route AFTER the pilot has popped: adjacency must
        // switch back to the native theme, not retain pilot secondary motion.
        for (final pilot in [true, false]) {
          final route = pilot
              ? flowyReferenceRoute<int>(builder: (_) => _page('front'))
              : PreservedMaterialPageRoute<int>(builder: (_) => _page('front'));
          final result = nav.currentState!.push(route);
          await tester.pump();
          for (final ms in [45, 55, 100, 180]) {
            await tester.pump(Duration(milliseconds: ms));
            poses.addAll([
              tester.getRect(
                  find.byKey(const ValueKey('root'), skipOffstage: false)),
              tester.getRect(find.byKey(const ValueKey('front'))),
              _pageOpacity(tester, 'root'),
              _pageOpacity(tester, 'front'),
            ]);
          }
          await tester.pumpAndSettle();
          nav.currentState!.pop(42);
          await tester.pump();
          for (final ms in [45, 55, 100, 180]) {
            await tester.pump(Duration(milliseconds: ms));
            poses.addAll([
              tester.getRect(
                  find.byKey(const ValueKey('root'), skipOffstage: false)),
              _pageOpacity(tester, 'root'),
            ]);
          }
          await tester.pumpAndSettle();
          expect(await result, 42);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        return poses;
      }

      expect(await sample(true), await sample(false));
    });
  }

  for (final edge in [0, 1]) {
    testWidgets('nativeCancelAtZero_verticalDriftDoesNotSnap_edge$edge',
        (tester) async {
      final nav = await _mount(tester);
      final route = flowyReferenceRoute<void>(builder: (_) => _page('child'));
      nav.currentState!.push(route);
      await tester.pumpAndSettle();
      await _back(tester, 'startBackGesture', edge);
      final child = find.byKey(const ValueKey('child'), skipOffstage: false);
      final element = tester.element(child);
      Offset? nearZero;
      // Android may finish its cancellation spring before notifying Flutter.
      // Recorded input had 107.25px vertical drift at progress .0083301356,
      // followed by progress zero and the cancel callback. The page must
      // already meet its resting plane without a final 10.725dp reset.
      for (final progress in [.6, .3, .5, .1, .008330135606229305, 0.0]) {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/backgesture',
            const StandardMethodCodec()
                .encodeMethodCall(MethodCall('updateBackGestureProgress', {
              'touchOffset': [edge == 0 ? 160.0 : 640.0, 407.25],
              'progress': progress,
              'swipeEdge': edge,
            })),
            (_) {});
        await tester.pump();
        expect(route.animation!.value, closeTo(1 - progress, 1e-12));
        expect(tester.element(child), same(element));
        expect(
            tester.getTopLeft(
                find.byKey(const ValueKey('root'), skipOffstage: false)),
            Offset.zero);
        if (progress == .008330135606229305) {
          nearZero = tester.getTopLeft(child);
        }
      }
      final atZero = tester.getRect(child);
      expect(atZero, const Rect.fromLTWH(0, 0, 800, 600),
          reason: 'Zero progress must restore the plane even before cancel');
      expect((nearZero!.dy - atZero.top).abs(), lessThan(.5));
      await _back(tester, 'cancelBackGesture');
      expect(tester.getRect(child), atZero);
      await tester.pumpAndSettle();
      expect(tester.getRect(child), atZero);
      expect(nav.currentState!.userGestureInProgress, false);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('predictiveCommit_paintedBackingLimitsDoubleContent',
      (tester) async {
    final nav = await _mount(tester);
    final route = flowyReferenceRoute<void>(builder: (_) => _page('child'));
    nav.currentState!.push(route);
    await tester.pumpAndSettle();
    await _back(tester, 'startBackGesture');
    await _back(tester, 'updateBackGestureProgress');
    await _back(tester, 'commitBackGesture');
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(microseconds: 8333));
      if (!nav.currentState!.userGestureInProgress) break;
      final alpha = _pageOpacity(tester, 'child');
      final stack = find
          .ancestor(
              of: find.byKey(const ValueKey('child')),
              matching: find.byType(Stack))
          .first;
      final backing = tester.widget<Stack>(stack).children.first as ColoredBox;
      expect(backing.color.a, inInclusiveRange(0.0, .9));
      // Parent's effective contribution through the content AND painted backing.
      // This bounds compositing weights; it is not a perceptual/FPS assertion.
      final parentWeight = (1 - alpha) * (1 - backing.color.a);
      if (i >= 6) {
        expect(alpha > .4 && 1 - backing.color.a > .45, false,
            reason: 'Includes exposed margins, not only the overlapping area');
      }
      expect(alpha + parentWeight, greaterThanOrEqualTo(.60));
      expect(
          tester
              .widgetList<SlideTransition>(_slides('child'))
              .every((slide) => slide.position.value == Offset.zero),
          isTrue);
    }
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('root'))), Offset.zero);
  });

  for (final progress in [0.0, 1.0]) {
    for (final cancel in [false, true]) {
      testWidgets('predictiveEndpoint_${progress}_${cancel}_settlesAndReopens',
          (tester) async {
        final nav = await _mount(tester);
        nav.currentState!
            .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
        await tester.pumpAndSettle();
        await _back(tester, 'startBackGesture');
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/backgesture',
            const StandardMethodCodec()
                .encodeMethodCall(MethodCall('updateBackGestureProgress', {
              'touchOffset': const [160.0, 300.0],
              'progress': progress,
              'swipeEdge': 0,
            })),
            (_) {});
        await tester.pump();
        await _back(tester, cancel ? 'cancelBackGesture' : 'commitBackGesture');
        await tester.pumpAndSettle();
        expect(nav.currentState!.userGestureInProgress, false);
        expect(find.text('child'), cancel ? findsOneWidget : findsNothing);
        nav.currentState!
            .push(flowyReferenceRoute<void>(builder: (_) => _page('again')));
        await tester.pump(const Duration(milliseconds: 1));
        nav.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('again'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('staticHarness_pushAndButtonBack_referenceChoreography',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final nav = GlobalKey<NavigatorState>();
    final boundary = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
            navigatorKey: nav,
            theme: ThemeData(platform: TargetPlatform.android),
            home: _page('insights'))));
    await tester.pumpAndSettle();
    final route = flowyReferenceRoute<void>(builder: (_) => _page('child'));
    nav.currentState!.push(route);
    await tester.pump();
    var elapsed = 0;
    for (final ms in [1, 40, 80, 114, 134, 168, 201, 267, 380]) {
      await tester.pump(Duration(milliseconds: ms - elapsed));
      elapsed = ms;
      await _capture(tester, boundary, 'push-$ms');
      final old = _pageOpacity(tester, 'insights');
      final next = _pageOpacity(tester, 'child');
      expect(old > .25 || next > .25, true);
      expect(old > .5 && next > .5, false);
      expect(tester.getTopLeft(find.byKey(const ValueKey('child'))).dy, 0);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    elapsed = 0;
    for (final ms in [1, 80, 114, 168, 267, 380]) {
      await tester.pump(Duration(milliseconds: ms - elapsed));
      elapsed = ms;
      await _capture(tester, boundary, 'button-back-$ms');
    }
    await tester.pumpAndSettle();
    expect(find.text('insights'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final cancel in [false, true]) {
    for (final edge in [0, 1]) {
      testWidgets('staticHarness_releaseWithVerticalDrag_edge${edge}_$cancel',
          (tester) async {
        final nav = GlobalKey<NavigatorState>();
        final boundary = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
            key: boundary,
            child: MaterialApp(
                navigatorKey: nav,
                theme: ThemeData(platform: TargetPlatform.android),
                home: _page('insights'))));
        nav.currentState!
            .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
        await tester.pumpAndSettle();
        await _back(tester, 'startBackGesture', edge);
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/backgesture',
            const StandardMethodCodec()
                .encodeMethodCall(MethodCall('updateBackGestureProgress', {
              'touchOffset': [edge == 0 ? 160.0 : 640.0, 410.0],
              'progress': .4,
              'swipeEdge': edge,
            })),
            (_) {});
        await tester.pump();
        final child = find.byKey(const ValueKey('child'), skipOffstage: false);
        final before = tester.getRect(child);
        final radius = tester
            .widget<ClipRRect>(
                find.ancestor(of: child, matching: find.byType(ClipRRect)))
            .borderRadius;
        await _back(tester, cancel ? 'cancelBackGesture' : 'commitBackGesture');
        expect(tester.getRect(child), before);
        expect(
            tester
                .widget<ClipRRect>(
                    find.ancestor(of: child, matching: find.byType(ClipRRect)))
                .borderRadius,
            radius);
        expect(_pageOpacity(tester, 'child'), 1);
        for (final step in [0, 32, 32, 50, 50, 100]) {
          await tester.pump(Duration(milliseconds: step));
          await _capture(tester, boundary,
              'gesture-$edge-$cancel-${tester.binding.clock.now().microsecondsSinceEpoch}');
        }
        await tester.pumpAndSettle();
        expect(find.text('child'), cancel ? findsOneWidget : findsNothing);
        if (cancel) {
          expect(tester.getRect(child), const Rect.fromLTWH(0, 0, 800, 600));
        }
        expect(nav.currentState!.userGestureInProgress, false);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final edge in [0, 1]) {
    for (final cancel in [false, true]) {
      testWidgets(
          'releaseContinuity_edge${edge}_${cancel ? "cancel" : "commit"}',
          (tester) async {
        final nav = await _mount(tester);
        nav.currentState!
            .push(flowyReferenceRoute<void>(builder: (_) => _page('insights')));
        await tester.pumpAndSettle();
        final route = flowyReferenceRoute<void>(builder: (_) => _page('child'));
        nav.currentState!.push(route);
        await tester.pumpAndSettle();
        await _back(tester, 'startBackGesture', edge);
        await _back(tester, 'updateBackGestureProgress', edge);
        final child = find.byKey(const ValueKey('child'), skipOffstage: false);
        final parent =
            find.byKey(const ValueKey('insights'), skipOffstage: false);
        final before = tester.getRect(child);
        await _back(tester, cancel ? 'cancelBackGesture' : 'commitBackGesture');
        expect(tester.getRect(child), before,
            reason: 'Release must not switch to a different pose');
        double lastAlpha = 1;
        for (var frame = 0; frame < 55; frame++) {
          await tester.pump(const Duration(microseconds: 8333));
          if (!nav.currentState!.userGestureInProgress) break;
          expect(tester.getTopLeft(parent), Offset.zero);
          expect(_pageOpacity(tester, 'insights'), 1);
          final alpha = _pageOpacity(tester, 'child');
          if (cancel) {
            expect(alpha, 1);
          } else {
            expect(alpha, lessThanOrEqualTo(lastAlpha + .00001));
            lastAlpha = alpha;
          }
          // Normal wrappers remain mounted but neutral: only the accepting
          // page's predictive pose may affect clipping, travel or alpha.
          expect(find.ancestor(of: child, matching: find.byType(ClipRRect)),
              findsOneWidget);
          final fades = tester
              .widgetList<FadeTransition>(find.ancestor(
                  of: child, matching: find.byType(FadeTransition)))
              .toList();
          expect(fades.where((fade) => fade.opacity.value != 1),
              hasLength(cancel ? 0 : (alpha == 1 ? 0 : 1)));
          expect(
              tester
                  .widgetList<SlideTransition>(_slides('child'))
                  .every((slide) => slide.position.value == Offset.zero),
              isTrue);
        }
        await tester.pumpAndSettle();
        expect(nav.currentState!.userGestureInProgress, false);
        expect(find.text('child'), cancel ? findsOneWidget : findsNothing);
        if (cancel) {
          expect(tester.getRect(child), const Rect.fromLTWH(0, 0, 800, 600));
        }
        // Immediately open again after settlement, then reverse during entry.
        nav.currentState!
            .push(flowyReferenceRoute<void>(builder: (_) => _page('again')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        nav.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.text('again'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final dark in [false, true]) {
    testWidgets(
        'predictiveParent_cornerPixelsStayPainted_${dark ? "dark" : "light"}',
        (tester) async {
      final nav = GlobalKey<NavigatorState>();
      final boundary = GlobalKey();
      final color = dark ? const Color(0xff202830) : const Color(0xfff0f3f6);
      await tester.pumpWidget(ColoredBox(
          color: Colors.black,
          child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                navigatorKey: nav,
                theme: ThemeData(
                    platform: TargetPlatform.android,
                    scaffoldBackgroundColor: color),
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .applyDisplayCornerRadii(BorderRadius.circular(32)),
                    child: child!),
                home: _page('root'),
              ))));
      nav.currentState!
          .push(flowyReferenceRoute<void>(builder: (_) => _page('insights')));
      await tester.pumpAndSettle();
      nav.currentState!
          .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
      await tester.pumpAndSettle();
      await _back(tester, 'startBackGesture');
      await _back(tester, 'updateBackGestureProgress');
      final image = tester
          .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
          .toImageSync();
      final bytes = await tester
          .runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
      for (final point in [
        const Offset(1, 1),
        const Offset(798, 1),
        const Offset(1, 598)
      ]) {
        final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
        expect(bytes!.getUint8(offset), closeTo(color.r * 255, 2));
        expect(bytes.getUint8(offset + 1), closeTo(color.g * 255, 2));
        expect(bytes.getUint8(offset + 2), closeTo(color.b * 255, 2));
      }
      image.dispose();
      await _back(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final cancel in [false, true]) {
    testWidgets(
        'predictiveOwner_onlyTopRouteClips_${cancel ? "cancel" : "commit"}',
        (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        theme: ThemeData(platform: TargetPlatform.android),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .applyDisplayCornerRadii(BorderRadius.circular(32)),
          child: child!,
        ),
        home: _page('root'),
      ));
      nav.currentState!
          .push(flowyReferenceRoute<void>(builder: (_) => _page('insights')));
      await tester.pumpAndSettle();
      final parentRoute = ModalRoute.of(
          tester.element(find.byKey(const ValueKey('insights'))))!;
      final route = flowyReferenceRoute<void>(builder: (_) => _page('child'));
      nav.currentState!.push(route);
      await tester.pumpAndSettle();
      await _back(tester, 'startBackGesture');
      await _back(tester, 'updateBackGestureProgress');
      final parent =
          find.byKey(const ValueKey('insights'), skipOffstage: false);
      expect(parentRoute.popGestureInProgress, false,
          reason: 'Only the accepting route owns predictive presentation');
      expect(route.popGestureInProgress, true);
      expect(
          tester
              .widgetList<ClipRRect>(find.ancestor(
                  of: parent,
                  matching: find.byType(ClipRRect, skipOffstage: false)))
              .every((clip) => clip.borderRadius == BorderRadius.zero),
          isTrue);
      expect(tester.getTopLeft(parent), Offset.zero);
      expect(tester.getSize(parent), const Size(800, 600));
      final child = find.byKey(const ValueKey('child'));
      expect(find.ancestor(of: child, matching: find.byType(ClipRRect)),
          findsOneWidget);
      await _back(tester, cancel ? 'cancelBackGesture' : 'commitBackGesture');
      // Commit loses isCurrent immediately, but must keep ownership until settled.
      expect(route.popGestureInProgress, true);
      for (var frame = 0; frame < 55; frame++) {
        await tester.pump(const Duration(microseconds: 8333));
        if (nav.currentState!.userGestureInProgress) {
          expect(tester.getTopLeft(parent), Offset.zero);
        }
        expect(
            tester
                .widgetList<ClipRRect>(find.ancestor(
                    of: parent,
                    matching: find.byType(ClipRRect, skipOffstage: false)))
                .every((clip) => clip.borderRadius == BorderRadius.zero),
            isTrue);
      }
      await tester.pumpAndSettle();
      expect(nav.currentState!.userGestureInProgress, false);
      if (cancel) {
        expect(tester.getTopLeft(child), Offset.zero);
        expect(
            tester
                .widgetList<ClipRRect>(
                    find.ancestor(of: child, matching: find.byType(ClipRRect)))
                .every((clip) => clip.borderRadius == BorderRadius.zero),
            isTrue);
        // Cancelled owner must not become an owner of the next child's gesture.
        nav.currentState!
            .push(flowyReferenceRoute<void>(builder: (_) => _page('next')));
        await tester.pumpAndSettle();
        await _back(tester, 'startBackGesture');
        expect(route.popGestureInProgress, false);
        await _back(tester, 'commitBackGesture');
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final nested in [false, true]) {
    testWidgets(
        'handoff_${nested ? 'nested' : 'root'}_hasBriefOverlapWithoutBlankHandoff',
        (tester) async {
      final nav = await _mount(tester);
      final parent = nested ? 'insights' : 'root';
      if (nested) {
        nav.currentState!
            .push(flowyReferenceRoute<void>(builder: (_) => _page(parent)));
        await tester.pumpAndSettle();
      }
      nav.currentState!
          .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
      await tester.pump();
      for (var frame = 0; frame < 44; frame++) {
        await tester.pump(const Duration(microseconds: 8333));
        final parentAlpha = _pageOpacity(tester, parent);
        final childAlpha = _pageOpacity(tester, 'child');
        expect(parentAlpha > .5 && childAlpha > .5, false);
        expect(parentAlpha > .25 || childAlpha > .25, true,
            reason: 'No near-empty handoff at frame $frame');
      }
      await tester.pumpAndSettle();
    });

    testWidgets(
        'progress_${nested ? 'nested' : 'root'}_isContinuousAt120HzSteps',
        (tester) async {
      final nav = await _mount(tester);
      if (nested) {
        nav.currentState!
            .push(flowyReferenceRoute<void>(builder: (_) => _page('insights')));
        await tester.pumpAndSettle();
      }
      final childKey = GlobalKey();
      final route = flowyReferenceRoute<void>(
          builder: (_) => Scaffold(key: childKey, body: const Text('child')));
      nav.currentState!.push(route);
      await tester.pump();
      // Navigator's initial offstage size probe is not a displayed frame.
      await tester.pump(const Duration(microseconds: 8333));
      final element = childKey.currentContext;
      var previousProgress = route.animation!.value;
      final childFinder = find.byKey(childKey, skipOffstage: false);
      var previousX = tester.getTopLeft(childFinder).dx;
      for (var frame = 0; frame < 44; frame++) {
        await tester.pump(const Duration(microseconds: 8333));
        final progress = route.animation!.value;
        final x = tester.getTopLeft(childFinder).dx;
        expect(progress, greaterThan(previousProgress));
        expect(x, lessThanOrEqualTo(previousX + .001));
        expect(childKey.currentContext, same(element));
        expect(tester.getTopLeft(childFinder).dy, 0);
        previousProgress = progress;
        previousX = x;
      }
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(childKey)), Offset.zero);
      expect(tester.takeException(), isNull);
    });

    testWidgets('popHandoff_${nested ? 'nested' : 'root'}_hasControlledOverlap',
        (tester) async {
      final nav = await _mount(tester);
      final parent = nested ? 'insights' : 'root';
      if (nested) {
        nav.currentState!
            .push(flowyReferenceRoute<void>(builder: (_) => _page(parent)));
        await tester.pumpAndSettle();
      }
      nav.currentState!
          .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
      await tester.pumpAndSettle();
      nav.currentState!.pop();
      await tester.pump();
      for (var frame = 0; frame < 44; frame++) {
        await tester.pump(const Duration(microseconds: 8333));
        expect(
            _pageOpacity(tester, parent) > .5 &&
                _pageOpacity(tester, 'child') > .5,
            false);
      }
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(ValueKey(parent))), Offset.zero);
    });
  }

  testWidgets(
      'incomingTravel_fitsVisibleReferenceSamples_withRecordingTolerance',
      (tester) async {
    final nav = await _mount(tester);
    nav.currentState!
        .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
    await tester.pump();
    // 12.mp4 title-template measurements aligned to the last steady frame
    // at 1.076s. Alignment/contrast have >= one ~33ms recording-frame error.
    const milliseconds = [134, 168, 201, 233, 267, 303, 336];
    const measured = [.128, .071, .044, .017, .006, .001, 0.0];
    var elapsed = 0;
    for (var index = 0; index < milliseconds.length; index++) {
      await tester.pump(Duration(milliseconds: milliseconds[index] - elapsed));
      elapsed = milliseconds[index];
      final x = tester.getTopLeft(find.byKey(const ValueKey('child'))).dx / 800;
      expect(x, closeTo(measured[index], .02),
          reason: 'visible reference sample at $elapsed ms');
    }
    await tester.pumpAndSettle();
  });

  testWidgets('outgoingTravel_fitsCorrelatedReferenceSamples', (tester) async {
    final nav = await _mount(tester);
    nav.currentState!
        .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
    await tester.pump();
    // Source label correlation >= .95; later samples are too faint to measure.
    const ms = [34, 68, 100];
    const dx = [-.001, -.037, -.093];
    const contrast = [.95, .58, .24];
    var elapsed = 0;
    for (var i = 0; i < ms.length; i++) {
      await tester.pump(Duration(milliseconds: ms[i] - elapsed));
      elapsed = ms[i];
      expect(
          tester
                  .getTopLeft(
                      find.byKey(const ValueKey('root'), skipOffstage: false))
                  .dx /
              800,
          closeTo(dx[i], .025));
      // Contrast is a recording proxy, not an exact widget opacity measurement.
      expect(_pageOpacity(tester, 'root'), closeTo(contrast[i], .18));
    }
    await tester.pumpAndSettle();
  });

  testWidgets('rapidReverse_preservesPoseAtDirectionChange', (tester) async {
    final nav = await _mount(tester);
    nav.currentState!
        .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final position = tester.getTopLeft(find.byKey(const ValueKey('child')));
    final alpha = _pageOpacity(tester, 'child');
    nav.currentState!.pop();
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(const ValueKey('child'))), position);
    expect(_pageOpacity(tester, 'child'), closeTo(alpha, .0001));
    await tester.pumpAndSettle();
    expect(find.text('child'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('predictiveCancel_keepsActiveStateAndScroll', (tester) async {
    final nav = await _mount(tester);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final page = StatefulBuilder(
        builder: (context, setState) => Scaffold(
              body: ListView(controller: scroll, children: const [
                SizedBox(height: 2500),
                Text('retained child'),
              ]),
            ));
    nav.currentState!.push(flowyReferenceRoute<void>(builder: (_) => page));
    await tester.pumpAndSettle();
    scroll.jumpTo(350);
    await tester.pump();
    final state = tester.state(find.byWidget(page));
    for (final edge in [0, 1]) {
      await _back(tester, 'startBackGesture', edge);
      await _back(tester, 'updateBackGestureProgress', edge);
      expect(tester.state(find.byWidget(page)), same(state));
      await _back(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(tester.state(find.byWidget(page)), same(state));
      expect(scroll.offset, 350);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  test('referenceRoute_preservesTypeSettingsMaintainStateAndOpaque', () {
    const settings = RouteSettings(name: '/pilot', arguments: 17);
    final route = flowyReferenceRoute<int>(
      builder: (_) => _page('child'),
      settings: settings,
      maintainState: false,
    );
    expect(route, isA<PreservedMaterialPageRoute<int>>());
    expect(route.settings, same(settings));
    expect(route.maintainState, false);
    expect(route.opaque, true);
    expect(route.allowSnapshotting, true);
    expect(
        flowyReferenceRoute<void>(builder: (_) => _page('child')).maintainState,
        true);
    expect(route.transitionDuration, const Duration(milliseconds: 380));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 380));
    route.dispose();
  });

  testWidgets('rootParent_participatesOnce_childAdvances_withoutCardCapture',
      (tester) async {
    final nav = await _mount(tester);
    final route = flowyReferenceRoute<int>(builder: (_) => _page('child'));
    final result = nav.currentState!.push(route);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 45));
    final probe = route.createAnimationController();
    expect(probe.animationBehavior, AnimationBehavior.preserve);
    probe.dispose();
    final parentSlides = tester.widgetList<SlideTransition>(_slides('root'));
    expect(parentSlides.where((s) => s.position.value.dx < 0), hasLength(1));
    final childSlides = tester.widgetList<SlideTransition>(_slides('child'));
    expect(childSlides.where((s) => s.position.value.dx > 0), hasLength(1));
    expect(childSlides.every((s) => s.position.value.dy == 0), true);
    expect(find.byType(RawImage), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('child'))), Offset.zero);
    expect(find.byKey(const ValueKey('root')), findsNothing);
    nav.currentState!.pop(42);
    await tester.pumpAndSettle();
    expect(await result, 42);
    expect(tester.getTopLeft(find.byKey(const ValueKey('root'))), Offset.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nestedParent_noDuplicateDelegatedTransform_andRestores',
      (tester) async {
    final nav = await _mount(tester);
    final first = flowyReferenceRoute<void>(builder: (_) => _page('insights'));
    nav.currentState!.push(first);
    await tester.pumpAndSettle();
    final second = flowyReferenceRoute<void>(builder: (_) => _page('bucket'));
    nav.currentState!.push(second);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 45));
    expect(first.receivedTransition, isNull);
    expect(
        tester
            .widgetList<SlideTransition>(_slides('insights'))
            .where((s) => s.position.value.dx < 0),
        hasLength(1));
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('insights'))), Offset.zero);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('root'))), Offset.zero);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nonPilotRoute_keepsThemeTransition_noPilotDelegate',
      (tester) async {
    final nav = await _mount(tester);
    final old = ModalRoute.of(tester.element(find.text('root')))!;
    final other =
        PreservedMaterialPageRoute<void>(builder: (_) => _page('other'));
    nav.currentState!.push(other);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 45));
    expect(old.receivedTransition, isNull);
    expect(
        tester
            .widgetList<SlideTransition>(_slides('other'))
            .any((s) => s.position.value.dy > 0),
        true);
    expect(
        tester
            .widgetList<SlideTransition>(_slides('other'))
            .every((s) => s.position.value.dx == 0),
        true);
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('nonPilotAbovePilot_doesNotReceivePilotChoreography',
      (tester) async {
    final nav = await _mount(tester);
    final pilot = flowyReferenceRoute<void>(builder: (_) => _page('insights'));
    nav.currentState!.push(pilot);
    await tester.pumpAndSettle();
    final other =
        PreservedMaterialPageRoute<void>(builder: (_) => _page('editor'));
    expect(pilot.canTransitionTo(other), false);
    nav.currentState!.push(other);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 45));
    expect(pilot.secondaryAnimation!.value, 0);
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('insights'), findsOneWidget);
  });

  testWidgets('rapidReverse_beforePushCompletes_noOrphan', (tester) async {
    final nav = await _mount(tester);
    final route = flowyReferenceRoute<void>(builder: (_) => _page('child'));
    nav.currentState!.push(route);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('root'))), Offset.zero);
    expect(find.text('child'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final action in ['replace', 'remove', 'dispose']) {
    testWidgets('routeLifecycle_${action}_noTickerLeak', (tester) async {
      final nav = await _mount(tester);
      final route = flowyReferenceRoute<void>(builder: (_) => _page('child'));
      nav.currentState!.push(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      if (action == 'replace') {
        nav.currentState!.pushReplacement(
            flowyReferenceRoute<void>(builder: (_) => _page('replacement')));
      } else if (action == 'remove') {
        nav.currentState!.removeRoute(route);
      } else {
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpAndSettle();
      await route.completed;
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  for (final nested in [false, true]) {
    for (final edge in [0, 1]) {
      for (final cancel in [false, true]) {
        testWidgets(
            'predictive_${nested ? 'nested' : 'root'}_edge${edge}_${cancel ? 'cancel' : 'commit'}',
            (tester) async {
          final nav = await _mount(tester);
          if (nested) {
            nav.currentState!.push(
                flowyReferenceRoute<void>(builder: (_) => _page('insights')));
            await tester.pumpAndSettle();
          }
          final route =
              flowyReferenceRoute<void>(builder: (_) => _page('child'));
          nav.currentState!.push(route);
          await tester.pumpAndSettle();
          expect(route.popGestureEnabled, true);
          await _back(tester, 'startBackGesture', edge);
          await _back(tester, 'updateBackGestureProgress', edge);
          expect(nav.currentState!.userGestureInProgress, true);
          expect(route.animation!.value, closeTo(.6, .001));
          expect(
              tester.getTopLeft(find.byKey(
                  ValueKey(nested ? 'insights' : 'root'),
                  skipOffstage: false)),
              Offset.zero);
          expect(
              tester.getBottomRight(find.byKey(const ValueKey('child'))).dx -
                  tester.getTopLeft(find.byKey(const ValueKey('child'))).dx,
              lessThan(800));
          await _back(
              tester, cancel ? 'cancelBackGesture' : 'commitBackGesture');
          await tester.pumpAndSettle();
          expect(nav.currentState!.userGestureInProgress, false);
          expect(find.text('child'), cancel ? findsOneWidget : findsNothing);
          if (cancel) {
            expect(route.animation!.value, 1);
            expect(tester.getTopLeft(find.byKey(const ValueKey('child'))),
                Offset.zero);
            nav.currentState!.pop();
            await tester.pumpAndSettle();
          }
          expect(find.text(nested ? 'insights' : 'root'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('blockedPopScope_rejectsPredictiveGesture', (tester) async {
    final nav = await _mount(tester);
    final route = flowyReferenceRoute<void>(
        builder: (_) => PopScope(canPop: false, child: _page('child')));
    nav.currentState!.push(route);
    await tester.pumpAndSettle();
    expect(route.popGestureEnabled, false);
    await _back(tester, 'startBackGesture');
    expect(nav.currentState!.userGestureInProgress, false);
    expect(route.animation!.value, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  for (final dark in [false, true]) {
    testWidgets('background_${dark ? 'dark' : 'light'}_usesScaffoldSurface',
        (tester) async {
      final nav = GlobalKey<NavigatorState>();
      final boundaryKey = GlobalKey();
      final bg = dark ? const Color(0xff0b0f17) : const Color(0xfff8fafc);
      await tester.pumpWidget(RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            navigatorKey: nav,
            theme: ThemeData(
              brightness: dark ? Brightness.dark : Brightness.light,
              scaffoldBackgroundColor: bg,
            ),
            home: _page('root'),
          )));
      nav.currentState!
          .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
      await tester.pump();
      await _expectBackgroundPixels(tester, boundaryKey, bg);
      await tester.pump(const Duration(milliseconds: 70));
      await _expectBackgroundPixels(tester, boundaryKey, bg);
      final fills = find.ancestor(
          of: find.byKey(const ValueKey('root'), skipOffstage: false),
          matching: find.byType(ColoredBox, skipOffstage: false));
      expect(tester.widgetList<ColoredBox>(fills).any((box) => box.color == bg),
          true);
      await tester.pumpAndSettle();
      expect(find.text('child'), findsOneWidget);
      await _expectBackgroundPixels(tester, boundaryKey, bg);
      nav.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
      await _expectBackgroundPixels(tester, boundaryKey, bg);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('parentStateAndScroll_surviveNestedPushAndPop', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final root = StatefulBuilder(builder: (context, setState) {
      return Scaffold(
          body: ListView(controller: scroll, children: const [
        SizedBox(height: 2500),
        Text('retained bottom'),
      ]));
    });
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, home: root));
    await tester.pumpAndSettle();
    scroll.jumpTo(350);
    await tester.pump();
    final retainedState = tester.state(find.byWidget(root));
    nav.currentState!
        .push(flowyReferenceRoute<void>(builder: (_) => _page('first')));
    await tester.pumpAndSettle();
    nav.currentState!
        .push(flowyReferenceRoute<void>(builder: (_) => _page('second')));
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(scroll.offset, 350);
    expect(tester.state(find.byWidget(root)), same(retainedState));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('cancelThenCommit_repeatedPredictiveBack_remainsUsable',
      (tester) async {
    final nav = await _mount(tester);
    nav.currentState!
        .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
    await tester.pumpAndSettle();
    for (final edge in [0, 1]) {
      await _back(tester, 'startBackGesture', edge);
      await _back(tester, 'updateBackGestureProgress', edge);
      await _back(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('child'), findsOneWidget);
    }
    await _back(tester, 'startBackGesture');
    await _back(tester, 'updateBackGestureProgress');
    await _back(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('root'), findsOneWidget);
    expect(nav.currentState!.userGestureInProgress, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fadeHandoff_briefOverlapWithoutWhitePause', (tester) async {
    final nav = await _mount(tester);
    nav.currentState!
        .push(flowyReferenceRoute<void>(builder: (_) => _page('child')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 114));
    expect(_pageOpacity(tester, 'root'), inExclusiveRange(.1, .3));
    expect(_pageOpacity(tester, 'child'), inExclusiveRange(.2, .4));
    await tester.pumpAndSettle();
    expect(_pageOpacity(tester, 'child'), 1);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
  });

  testWidgets('maintainStateFalse_disposesCoveredPage', (tester) async {
    final nav = await _mount(tester);
    nav.currentState!.push(flowyReferenceRoute<void>(
        builder: (_) => _page('first'), maintainState: false));
    await tester.pumpAndSettle();
    nav.currentState!
        .push(flowyReferenceRoute<void>(builder: (_) => _page('second')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('first'), skipOffstage: false), findsNothing);
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('production pilot', () {
    late SharedPreferences prefs;
    final haptics = <String>[];
    final anchor = DateTime(2026, 10, 6);
    final window = InsightsWindow(DateTime(2026, 10), DateTime(2026, 11));
    final category = Category(
        id: 'food',
        name: 'N3R category sentinel',
        type: CategoryType.expense,
        icon: 'Food',
        color: '#FF6688',
        sortOrder: 0,
        isSystem: false,
        createdAt: anchor);
    final transaction = Transaction(
        id: 'tx',
        walletId: 'wallet-sentinel',
        categoryId: 'food',
        amount: 120000,
        type: CategoryType.expense,
        envelopeType: 'needs',
        date: anchor,
        isAiParsed: false,
        createdAt: anchor,
        isCycleStart: false);
    final data = InsightsData([transaction], [category], const [], const []);

    setUp(() async {
      haptics.clear();
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    Future<void> mount(WidgetTester tester, Widget home, _Routes routes) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          chartExpensesStreamProvider.overrideWith((ref) => Stream.value([])),
          insightsDataProvider.overrideWith((ref) async => data),
        ],
        child: MaterialApp(navigatorObservers: [routes], home: home),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'wantsSupplement_actualLaunchers_cancelCommitBackAndImmediateReopen',
        (tester) async {
      final wants = Category(
          id: 'wants',
          name: 'Wants',
          type: CategoryType.expense,
          icon: 'Food',
          color: '#FF6688',
          sortOrder: 0,
          isSystem: false,
          createdAt: anchor);
      final supplement = Category(
          id: 'food',
          parentId: 'wants',
          name: 'Bổ sung',
          type: CategoryType.expense,
          icon: 'Food',
          color: '#FF6688',
          sortOrder: 0,
          isSystem: false,
          createdAt: anchor);
      final scopedData =
          InsightsData([transaction], [wants, supplement], const [], const []);
      final routes = _Routes();
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            insightsDataProvider.overrideWith((ref) async => scopedData),
          ],
          child: MaterialApp(
              theme: ThemeData(platform: TargetPlatform.android),
              navigatorObservers: [routes],
              home: SpendingInsightsScreen(
                  initialPeriod: InsightsPeriod.custom,
                  anchor: anchor,
                  customWindow: window))));
      await tester.pumpAndSettle();
      Future<void> open(String label) async {
        // Transaction ListTiles share the category label but launch Quick Entry.
        // Exercise the category card, not that unrelated task-sheet domain.
        final tile = find
            .byWidgetPredicate((widget) =>
                widget is InkWell &&
                widget.onTap != null &&
                find
                    .descendant(
                        of: find.byWidget(widget), matching: find.text(label))
                    .evaluate()
                    .isNotEmpty &&
                find
                    .ancestor(
                        of: find.byWidget(widget),
                        matching: find.byType(ListTile))
                    .evaluate()
                    .isEmpty)
            .last;
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        tester.widget<InkWell>(tile).onTap!();
        await tester.pump();
        await tester.pumpAndSettle();
      }

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      for (var cycle = 0; cycle < 3; cycle++) {
        await open('Wants');
        expect(
            tester
                .widget<SpendingInsightsScreen>(
                    find.byType(SpendingInsightsScreen))
                .title,
            'Wants');
        final wantsState = tester.state(find.byType(SpendingInsightsScreen));
        await open('Bổ sung');
        expect(
            tester
                .widget<SpendingInsightsScreen>(
                    find.byType(SpendingInsightsScreen))
                .title,
            'Bổ sung');
        final childState = tester.state(find.byType(SpendingInsightsScreen));
        final donutState = tester.state(find.byType(InsightsDonut));
        await _back(tester, 'startBackGesture', cycle % 2);
        await _back(tester, 'updateBackGestureProgress', cycle % 2);
        await _back(tester, 'cancelBackGesture');
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(SpendingInsightsScreen)),
            same(childState));
        expect(tester.state(find.byType(InsightsDonut)), same(donutState));
        if (cycle == 0) {
          await tester.tap(find.byTooltip('Quay lại'));
        } else {
          await _back(tester, 'startBackGesture', cycle % 2);
          await _back(tester, 'updateBackGestureProgress', cycle % 2);
          await _back(tester, 'commitBackGesture');
        }
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(SpendingInsightsScreen)),
            same(wantsState));
        await tester.tap(find.byTooltip('Quay lại'));
        await tester.pumpAndSettle();
        expect(navigator.userGestureInProgress, false);
      }
      expect(routes.pushed, hasLength(7));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    for (final localTickersEnabled in [false, true]) {
      testWidgets(
          'loadedInsights_localTickers${localTickersEnabled}_progressAndOwnershipStable',
          (tester) async {
        final routes = _Routes();
        // Warm, already loaded data isolates route/content progress from IO.
        await mount(tester, const SpendingInsightsScreen(), routes);
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        final key = GlobalKey();
        final destination = SpendingInsightsScreen(
          key: key,
          title: 'Wants',
          detailCategoryId: 'food',
          categoryIds: const {'food'},
          leaf: true,
          anchor: anchor,
          revealAmounts: true,
        );
        final route = flowyReferenceRoute<void>(
          builder: (_) =>
              TickerMode(enabled: localTickersEnabled, child: destination),
        );
        navigator.push(route);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final state = tester.state(find.byKey(key));
        final donut = find.descendant(
          of: find.byKey(key),
          matching: find.byType(InsightsDonut),
        );
        expect(donut, findsOneWidget);
        final size = tester.getSize(donut);
        var previousProgress = route.animation!.value;
        var previousX = tester.getTopLeft(find.byKey(key)).dx;
        for (var frame = 0; frame < 38; frame++) {
          await tester.pump(const Duration(microseconds: 8333));
          expect(route.animation!.value, greaterThan(previousProgress));
          final x = tester.getTopLeft(find.byKey(key)).dx;
          expect(x, lessThanOrEqualTo(previousX + .001));
          expect(tester.state(find.byKey(key)), same(state));
          expect(tester.getSize(donut), size);
          previousProgress = route.animation!.value;
          previousX = x;
        }
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }

    testWidgets('trendTap_usesReferenceRoute_andKeepsDefaultInsightsArguments',
        (tester) async {
      final routes = _Routes();
      await mount(tester, const Scaffold(body: SpendingTrendChart()), routes);
      final launch = tester
          .widget<InkWell>(find
              .ancestor(
                  of: find.text('Phân tích nhóm ❯'),
                  matching: find.byType(InkWell))
              .first)
          .onTap!;
      launch();
      launch();
      await tester.pumpAndSettle();
      expect(
          haptics
              .where((value) => value == 'HapticFeedbackType.selectionClick'),
          hasLength(1));
      expect(routes.pushed, hasLength(2));
      final route = routes.pushed.last as PageRoute;
      expect(route.transitionDuration, FlowyNavigationMotion.hierarchy);
      expect(route.delegatedTransition, isNotNull);
      expect(
          route.runtimeType,
          flowyReferenceRoute<void>(builder: (_) => const SizedBox())
              .runtimeType);
      final screen = tester
          .widget<SpendingInsightsScreen>(find.byType(SpendingInsightsScreen));
      expect(screen.initialPeriod, InsightsPeriod.cycle);
      expect(screen.categoryIds, null);
      expect(screen.initialWallets, isEmpty);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.byType(SpendingTrendChart), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    for (final grouped in [false, true]) {
      testWidgets(
          'bucketTap_${grouped ? 'scheme' : 'category'}_preservesAllArguments',
          (tester) async {
        if (grouped) {
          await prefs.setString(ClassificationSchemes.storageKey,
              '[{"id":"sentinel-scheme","name":"Sentinel","preset":false,"groups":[{"id":"group","name":"Thiết yếu","color":4294901896}],"assignments":{"food":"group"}}]');
        }
        final routes = _Routes();
        final root = SpendingInsightsScreen(
          initialPeriod: InsightsPeriod.custom,
          anchor: anchor,
          initialWallets: const {'wallet-sentinel'},
          initialType: CategoryType.expense,
          customWindow: window,
          revealAmounts: true,
          classification: 'needs',
          schemeId: grouped ? 'sentinel-scheme' : null,
        );
        await mount(tester, root, routes);
        final tile = find
            .byWidgetPredicate((widget) =>
                widget is InkWell &&
                widget.onTap != null &&
                find
                    .descendant(
                        of: find.byWidget(widget),
                        matching:
                            find.text(grouped ? 'Thiết yếu' : category.name))
                    .evaluate()
                    .isNotEmpty)
            .last;
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        final launch = tester.widget<InkWell>(tile).onTap!;
        launch();
        launch();
        await tester.pumpAndSettle();
        expect(routes.pushed, hasLength(2));
        expect(haptics.where((h) => h == 'HapticFeedbackType.selectionClick'),
            hasLength(1));
        expect(routes.pushed.last, isA<PreservedMaterialPageRoute<void>>());
        expect((routes.pushed.last as PageRoute).transitionDuration,
            FlowyNavigationMotion.hierarchy);
        final screen = tester.widget<SpendingInsightsScreen>(
            find.byType(SpendingInsightsScreen));
        expect(screen.initialPeriod, InsightsPeriod.custom);
        expect(screen.anchor, anchor);
        expect(screen.initialWallets, {'wallet-sentinel'});
        expect(screen.initialType, CategoryType.expense);
        expect(screen.customWindow, same(window));
        expect(screen.title, grouped ? 'Thiết yếu' : category.name);
        expect(screen.detailCategoryId, grouped ? null : 'food');
        expect(screen.categoryIds, {'food'});
        expect(screen.leaf, !grouped);
        expect(screen.revealAmounts, true);
        expect(screen.classification, 'needs');
        expect(screen.detailColor,
            grouped ? const Color(0xFFFF0088) : const Color(0xFFFF6688));
        await tester.tap(find.byTooltip('Quay lại'));
        await tester.pumpAndSettle();
        expect(
            tester.widget<SpendingInsightsScreen>(
                find.byType(SpendingInsightsScreen)),
            same(root));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
