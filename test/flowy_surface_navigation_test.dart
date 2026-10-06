import 'dart:ui' as ui;

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

const _parentKey = ValueKey('parent');
const _childKey = ValueKey('child');
Widget _page(Key key, {Color? color}) =>
    Scaffold(key: key, backgroundColor: color, body: const SizedBox.expand());

Finder _ancestors(Key key, Type type) => find.ancestor(
    of: find.byKey(key, skipOffstage: false),
    matching: find.byType(type, skipOffstage: false));

Transform _surfaceTransform(WidgetTester tester, Key key) =>
    tester.widgetList<Transform>(_ancestors(key, Transform)).last;

Opacity _surfaceOpacity(WidgetTester tester, Key key) =>
    tester.widget<Opacity>(_ancestors(key, Opacity).last);

ColoredBox _wash(WidgetTester tester, Key key) {
  final stack = tester.widget<Stack>(_ancestors(key, Stack).first);
  final ignored = stack.children.first as IgnorePointer;
  return (ignored.child as ExcludeSemantics).child as ColoredBox;
}

void _expectColorClose(Color actual, Color expected) {
  expect(actual.r, closeTo(expected.r, 2 / 255));
  expect(actual.g, closeTo(expected.g, 2 / 255));
  expect(actual.b, closeTo(expected.b, 2 / 255));
}

void _expectStatic(WidgetTester tester, Key key) {
  expect(tester.getTopLeft(find.byKey(key)), Offset.zero);
  for (final transform
      in tester.widgetList<Transform>(_ancestors(key, Transform))) {
    expect(transform.transform.isIdentity(), true);
  }
}

class _PaintCounter extends CustomPainter {
  _PaintCounter(this.signal) : super(repaint: signal);
  final ValueNotifier<int> signal;
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(covariant _PaintCounter oldDelegate) => false;
}

Future<Color> _pixel(WidgetTester tester, Key boundaryKey, int x, int y) async {
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
  final image = boundary.toImageSync();
  final bytes = await tester
      .runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
  final offset = (y * image.width + x) * 4;
  final color = Color.fromARGB(
      bytes!.getUint8(offset + 3),
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2));
  image.dispose();
  return color;
}

void main() {
  test('surfaceRoute_preservesResultTypeSettingsMaintainStateAndDefaults', () {
    const settings = RouteSettings(name: 'detail', arguments: 17);
    final route = flowySurfaceRoute<int>(
      builder: (_) => _page(_childKey),
      settings: settings,
      maintainState: false,
    );
    expect(route, isA<PreservedPageRouteBuilder<int>>());
    expect(route.settings, same(settings));
    expect(route.maintainState, false);
    expect(
        flowySurfaceRoute<void>(builder: (_) => _page(_childKey)).maintainState,
        true);
    expect(route.opaque, true);
    expect(route.allowSnapshotting, true);
    expect(route.delegatedTransition, isNull);
    expect(route.transitionDuration, const Duration(milliseconds: 280));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 240));
  });

  testWidgets('surfaceDissolve_fixed12Pixels_oneChildFade_parentStatic',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: _page(_parentKey),
    ));
    var childBuilds = 0;
    final route = flowySurfaceRoute<void>(
      builder: (_) => Builder(builder: (_) {
        childBuilds++;
        return _page(_childKey);
      }),
    );
    navigator.currentState!.push(route);
    await tester.pump();
    await tester.pump();
    expect(_surfaceTransform(tester, _childKey).transform.entry(0, 3), 12);
    expect(_surfaceTransform(tester, _childKey).transform.entry(1, 3), 0);
    expect(_surfaceOpacity(tester, _childKey).opacity, 0);
    expect(_wash(tester, _childKey).color.a, 0);
    _expectStatic(tester, _parentKey);
    expect(_ancestors(_childKey, Opacity), findsOneWidget);
    expect(_ancestors(_parentKey, Opacity), findsNothing);
    expect(_ancestors(_childKey, FadeTransition), findsNothing);
    expect(_ancestors(_childKey, ScaleTransition), findsNothing);
    expect(_ancestors(_childKey, SlideTransition), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(find.byType(AnimatedPositioned), findsNothing);
    // The route has only its painted wash and child; no seam/painter branch.
    final surface = tester.widget<Stack>(_ancestors(_childKey, Stack).first);
    expect(surface.children.length, 2);
    expect(surface.children.first, isA<IgnorePointer>());
    expect(surface.children.last, isA<Transform>());
    expect(find.byType(Hero), findsNothing);

    await tester.pump(const Duration(milliseconds: 140));
    final progress = const Interval(.4, 1, curve: Curves.easeOutCubic)
        .transform(route.animation!.value);
    final transform = _surfaceTransform(tester, _childKey).transform;
    expect(transform.entry(0, 3), closeTo(12 * (1 - progress), 1e-6));
    expect(transform.entry(1, 3), 0);
    expect(transform.entry(0, 0), 1);
    expect(transform.entry(1, 1), 1);
    expect(_surfaceOpacity(tester, _childKey).opacity, progress);
    expect(_wash(tester, _childKey).color.a, inExclusiveRange(0, .9));
    _expectStatic(tester, _parentKey);
    await tester.pumpAndSettle();
    expect(_surfaceTransform(tester, _childKey).transform.isIdentity(), true);
    expect(_surfaceOpacity(tester, _childKey).opacity, 1);
    expect(_wash(tester, _childKey).color.a, 0);
    expect(childBuilds, 1);

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final reverse = const Interval(.4, 1, curve: Curves.easeOutCubic)
        .transform(route.animation!.value);
    expect(_surfaceTransform(tester, _childKey).transform.entry(0, 3),
        closeTo(12 * (1 - reverse), 1e-6));
    expect(_surfaceOpacity(tester, _childKey).opacity, reverse);
    expect(_surfaceTransform(tester, _childKey).transform.entry(1, 3), 0);
    _expectStatic(tester, _parentKey);
    await tester.pumpAndSettle();
    _expectStatic(tester, _parentKey);
    expect(find.byKey(_childKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('surfaceDissolve_${brightness.name}_phasesAndReverse',
        (tester) async {
      final route = flowySurfaceRoute<void>(builder: (_) => _page(_childKey));
      final clock = AppAnimationPolicy.createController(
        vsync: const TestVSync(),
        duration: route.transitionDuration,
        reverseDuration: route.reverseTransitionDuration,
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Builder(
          builder: (context) => route.buildTransitions(
              context, clock, kAlwaysCompleteAnimation, _page(_childKey)),
        ),
      ));
      final peak = brightness == Brightness.light ? .9 : .85;
      for (final t in [
        0.0,
        .2,
        .38,
        .4,
        .46,
        .65,
        .82,
        1.0,
        .82,
        .65,
        .46,
        .4,
        .38,
        .2,
        0.0
      ]) {
        clock.value = t;
        await tester.pump();
        final expectedWash = peak *
            const Interval(0, .38, curve: Curves.easeOutCubic).transform(t) *
            (1 -
                const Interval(.46, .82, curve: Curves.easeInOutCubic)
                    .transform(t));
        final incoming =
            const Interval(.4, 1, curve: Curves.easeOutCubic).transform(t);
        expect(_wash(tester, _childKey).color.a, closeTo(expectedWash, 1e-6));
        expect(_surfaceOpacity(tester, _childKey).opacity, incoming);
        expect(_surfaceTransform(tester, _childKey).transform.entry(0, 3),
            closeTo(12 * (1 - incoming), 1e-6));
        expect(tester.getSize(find.byWidget(_wash(tester, _childKey))),
            tester.getSize(find.byType(Navigator)));
        if (t >= .38 && t <= .46) {
          expect(_wash(tester, _childKey).color.a, peak);
        }
        if (t <= .4) expect(incoming, 0);
        if (t >= .82) expect(expectedWash, 0);
      }
      clock.value = 1;
      clock.reverse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      expect(_surfaceTransform(tester, _childKey).transform.entry(0, 3), 12);
      expect(_surfaceOpacity(tester, _childKey).opacity, 0);
      expect(_wash(tester, _childKey).color.a, 0);
      await tester.pumpWidget(const SizedBox());
      clock.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('surfacePush_nestedResults_keepPreviousSurfaceStationary',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: _page(_parentKey)));
    navigator.currentState!
        .push(flowySurfaceRoute<void>(builder: (_) => _page(_childKey)));
    await tester.pumpAndSettle();
    final route =
        flowySurfaceRoute<int>(builder: (_) => _page(const ValueKey('detail')));
    final result = navigator.currentState!.push(route);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    _expectStatic(tester, _childKey);
    expect(_surfaceOpacity(tester, _childKey).opacity, 1);
    expect(_wash(tester, _childKey).color.a, 0);
    expect(
        _surfaceTransform(tester, const ValueKey('detail'))
            .transform
            .entry(0, 3),
        inExclusiveRange(0, 12));
    expect(_ancestors(const ValueKey('detail'), Opacity), findsOneWidget);
    await tester.pumpAndSettle();
    navigator.currentState!.pop(42);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    _expectStatic(tester, _childKey);
    await tester.pumpAndSettle();
    expect(await result, 42);
    _expectStatic(tester, _childKey);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    _expectStatic(tester, _parentKey);
    expect(tester.takeException(), isNull);
  });

  testWidgets('surfacePush_osAnimationDisabled_preservesController_andRapidPop',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!),
      home: _page(_parentKey),
    ));
    for (final elapsed in [60, 160, 220]) {
      final route = flowySurfaceRoute<void>(builder: (_) => _page(_childKey));
      navigator.currentState!.push(route);
      await tester.pump();
      await tester.pump(Duration(milliseconds: elapsed));
      expect(route.animation!.value, inExclusiveRange(0, 1));
      final beforePop =
          _surfaceTransform(tester, _childKey).transform.entry(0, 3);
      final beforeWash = _wash(tester, _childKey).color.a;
      final beforeOpacity = _surfaceOpacity(tester, _childKey).opacity;
      _expectStatic(tester, _parentKey);
      navigator.currentState!.pop();
      await tester.pump();
      expect(_surfaceTransform(tester, _childKey).transform.entry(0, 3),
          closeTo(beforePop, 1e-6));
      expect(_wash(tester, _childKey).color.a, beforeWash);
      expect(_surfaceOpacity(tester, _childKey).opacity, beforeOpacity);
      await tester.pump(const Duration(milliseconds: 30));
      expect(_surfaceTransform(tester, _childKey).transform.entry(0, 3),
          greaterThanOrEqualTo(beforePop));
      await tester.pumpAndSettle();
      _expectStatic(tester, _parentKey);
      expect(find.byKey(_childKey), findsNothing);
      expect(find.byType(Opacity), findsNothing);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('surfaceOpaque_settledRoute_stopsCoveredParentPainting',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final signal = ValueNotifier(0);
    final counter = _PaintCounter(signal);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: Scaffold(
          key: _parentKey,
          body: CustomPaint(painter: counter, child: const SizedBox.expand())),
    ));
    navigator.currentState!
        .push(flowySurfaceRoute<void>(builder: (_) => _page(_childKey)));
    await tester.pumpAndSettle();
    final coveredPaints = counter.paints;
    for (var i = 0; i < 3; i++) {
      signal.value++;
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(counter.paints, coveredPaints);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(counter.paints, greaterThan(coveredPaints));
    _expectStatic(tester, _parentKey);
    await tester.pumpWidget(const SizedBox());
    signal.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('surfaceDissolve_${brightness.name}_parentWashChildPixels',
        (tester) async {
      const boundaryKey = ValueKey('viewport');
      final navigator = GlobalKey<NavigatorState>();
      final parentColor = brightness == Brightness.dark
          ? const Color(0xFF153020)
          : const Color(0xFF99CCAA);
      final childColor = brightness == Brightness.dark
          ? const Color(0xFF303040)
          : const Color(0xFFF2EEDD);
      final theme = ThemeData(
        brightness: brightness,
        scaffoldBackgroundColor: brightness == Brightness.dark
            ? const Color(0xFF17211D)
            : const Color(0xFFF2F6F3),
      );
      final surface = Color.alphaBlend(
          theme.colorScheme.primary.withValues(alpha: .02),
          theme.scaffoldBackgroundColor);
      await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          navigatorKey: navigator,
          theme: theme,
          home: _page(_parentKey, color: parentColor),
        ),
      ));
      navigator.currentState!.push(flowySurfaceRoute<void>(
          builder: (_) => _page(_childKey, color: childColor)));
      await tester.pump();
      await tester.pump();
      expect(await _pixel(tester, boundaryKey, 1, 100), parentColor);
      expect(await _pixel(tester, boundaryKey, 100, 100), parentColor);
      await tester.pump(const Duration(milliseconds: 56));
      final early = _wash(tester, _childKey).color;
      expect(early.a, greaterThan(0));
      expect(_surfaceOpacity(tester, _childKey).opacity, 0);
      _expectColorClose(await _pixel(tester, boundaryKey, 100, 100),
          Color.alphaBlend(early, parentColor));
      await tester.pump(const Duration(milliseconds: 56));
      final wash = _wash(tester, _childKey).color;
      final peak = brightness == Brightness.dark ? .85 : .9;
      expect(wash.a, peak);
      expect(_surfaceOpacity(tester, _childKey).opacity, 0);
      _expectColorClose(await _pixel(tester, boundaryKey, 100, 100),
          Color.alphaBlend(surface.withValues(alpha: peak), parentColor));
      expect(wash.toARGB32() & 0xffffff, surface.toARGB32() & 0xffffff);
      expect(wash.toARGB32() & 0xffffff, isNot(0xffffff));
      expect(wash.toARGB32() & 0xffffff, isNot(0));
      _expectStatic(tester, _parentKey);
      await tester.pump(const Duration(milliseconds: 70));
      expect(_surfaceOpacity(tester, _childKey).opacity, greaterThan(.75));
      expect(_surfaceTransform(tester, _childKey).transform.entry(0, 3),
          lessThan(3));
      expect(_wash(tester, _childKey).color.a, inExclusiveRange(0, peak));
      final visible = await _pixel(tester, boundaryKey, 100, 100);
      expect((visible.r - childColor.r).abs(), lessThan(.15));
      expect((visible.g - childColor.g).abs(), lessThan(.15));
      expect((visible.b - childColor.b).abs(), lessThan(.15));
      await tester.pump(const Duration(milliseconds: 48));
      expect(_wash(tester, _childKey).color.a, 0);
      await tester.pumpAndSettle();
      expect(_surfaceOpacity(tester, _childKey).opacity, 1);
      expect(_surfaceTransform(tester, _childKey).transform.isIdentity(), true);
      expect(await _pixel(tester, boundaryKey, 0, 100), childColor);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(await _pixel(tester, boundaryKey, 100, 100), parentColor);
      expect(tester.takeException(), isNull);
    });
  }

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

    testWidgets('trendTap_usesSurfaceRoute_andKeepsDefaultInsightsArguments',
        (tester) async {
      final routes = _Routes();
      await mount(tester, const Scaffold(body: SpendingTrendChart()), routes);
      await tester.tap(find.text('Phân tích nhóm ❯'));
      await tester.pumpAndSettle();
      expect(
          haptics
              .where((value) => value == 'HapticFeedbackType.selectionClick'),
          hasLength(1));
      final route = routes.pushed.last as PageRoute;
      expect(route.transitionDuration, FlowyNavigationMotion.surfaceEnter);
      expect(route.delegatedTransition, isNull);
      expect(
          route.runtimeType,
          flowySurfaceRoute<void>(builder: (_) => const SizedBox())
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
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(routes.pushed.last, isA<PreservedPageRouteBuilder<void>>());
        expect((routes.pushed.last as PageRoute).transitionDuration,
            FlowyNavigationMotion.surfaceEnter);
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
