import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfm_app/core/animation/flowy_navigation_motion.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/screens/budget_screen.dart';
import 'package:pfm_app/screens/dashboard_screen.dart';
import 'package:pfm_app/screens/ledger_screen.dart';
import 'package:pfm_app/screens/main_scaffold.dart';
import 'package:pfm_app/screens/settings_screen.dart';
import 'package:pfm_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Tab extends StatefulWidget {
  const _Tab(this.index, {super.key});
  final int index;
  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  final scroll = ScrollController();
  int count = 0;
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        controller: scroll,
        children: [
          TextButton(
            onPressed: () => setState(() => count++),
            child: Text('tab ${widget.index}: $count'),
          ),
          const SizedBox(height: 2000),
        ],
      );
}

void main() {
  final tabs = List.generate(4, (i) => _Tab(i, key: ValueKey(i)));
  Future<void> mount(WidgetTester tester, int index,
          {bool disableAnimations = false}) =>
      tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: FlowyTabTransitionStack(index: index, children: tabs),
        ),
      ));

  Finder tab(int i) => find.byKey(ValueKey(i), skipOffstage: false);
  Finder ancestor(int i, Type type) => find.ancestor(
      of: tab(i), matching: find.byType(type, skipOffstage: false));
  double opacity(WidgetTester tester, int i) =>
      tester.widget<Opacity>(ancestor(i, Opacity).first).opacity;
  bool offstage(WidgetTester tester, int i) =>
      tester.widget<Offstage>(ancestor(i, Offstage).first).offstage;
  void expectOneInteractive(WidgetTester tester, int selected) {
    for (var i = 0; i < 4; i++) {
      expect(
          tester
              .widget<IgnorePointer>(ancestor(i, IgnorePointer).first)
              .ignoring,
          i != selected);
      expect(tester.widget<TickerMode>(ancestor(i, TickerMode).first).enabled,
          i == selected);
    }
  }

  testWidgets('tabSwitch_preservesStateAndScrollWithoutRecreatingScreens',
      (tester) async {
    await mount(tester, 0);
    final states = List.generate(4, (i) => tester.state<_TabState>(tab(i)));
    await tester.tap(find.text('tab 0: 0'));
    await tester.pump();
    states[0].scroll.jumpTo(320);
    await mount(tester, 2);
    await tester.pumpAndSettle();
    await mount(tester, 0);
    await tester.pumpAndSettle();
    expect(states[0].count, 1);
    expect(states[0].scroll.offset, 320);
    for (var i = 0; i < 4; i++) {
      expect(identical(tester.state(tab(i)), states[i]), true);
    }
  });

  testWidgets('sameIndex_doesNotStartAnotherTransition', (tester) async {
    await mount(tester, 0);
    await mount(tester, 0);
    expect(opacity(tester, 0), 1);
    expect(List.generate(4, (i) => offstage(tester, i)),
        [false, true, true, true]);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('fadeThrough_onlyPairPaintsAndOnlyCurrentIsInteractive',
      (tester) async {
    await mount(tester, 0);
    await mount(tester, 1);
    expect(opacity(tester, 0), 1);
    expect(opacity(tester, 1), 0);
    expectOneInteractive(tester, 1);
    expect(offstage(tester, 2), true);
    expect(offstage(tester, 3), true);
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacity(tester, 0), inExclusiveRange(0, 1));
    expect(opacity(tester, 1), 0);
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacity(tester, 0), 0);
    expect(opacity(tester, 1), inExclusiveRange(0, 1));
    await tester.pump(const Duration(milliseconds: 120));
    expect(opacity(tester, 1), 1);
    await tester.pumpAndSettle();
    expect(offstage(tester, 0), true);
  });

  testWidgets('rapidChanges_latestDestinationWinsWithoutExtraInteractivePage',
      (tester) async {
    await mount(tester, 0);
    for (final i in [1, 2, 3, 0, 2]) {
      await mount(tester, i);
      await tester.pump(const Duration(milliseconds: 35));
      expectOneInteractive(tester, i);
      expect(
          List.generate(4, (j) => offstage(tester, j)).where((v) => !v).length,
          lessThanOrEqualTo(2));
    }
    await tester.pumpAndSettle();
    expect(opacity(tester, 2), 1);
    expect(List.generate(4, (i) => offstage(tester, i)),
        [true, true, false, true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preservedPolicy_osDisabledAnimationsDoesNotSkipTabMotion',
      (tester) async {
    await mount(tester, 0, disableAnimations: true);
    await mount(tester, 1, disableAnimations: true);
    await tester.pump(const Duration(milliseconds: 120));
    expect(opacity(tester, 1), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(opacity(tester, 1), 1);
  });

  testWidgets('disposeDuringTransition_hasNoTickerLeak', (tester) async {
    await mount(tester, 0);
    await mount(tester, 1);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  group('production shell', () {
    late AppDatabase db;
    late ProviderContainer container;
    final haptics = <String>[];

    setUp(() async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ]);
      haptics.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String);
        }
        return null;
      });
    });
    tearDown(() async {
      container.dispose();
      await db.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    Future<void> mountShell(WidgetTester tester,
        {double safeBottom = 0,
        Brightness brightness = Brightness.light}) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(top: 24, bottom: safeBottom),
              viewPadding: EdgeInsets.only(top: 24, bottom: safeBottom),
            ),
            child: child!,
          ),
          home: const MainScaffold(),
        ),
      ));
      await tester.pump();
    }

    Scaffold shell(WidgetTester tester) => tester.widget<Scaffold>(find
        .descendant(
            of: find.byType(MainScaffold), matching: find.byType(Scaffold))
        .first);
    Finder dock(WidgetTester tester) => find.descendant(
        of: find.byWidget(shell(tester).bottomNavigationBar!),
        matching: find.byType(BackdropFilter));

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pumpAndSettle();
      await tester.runAsync(() => db.close());
      await tester.pump();
    }

    testWidgets('providerDrivenDestinationChange_animatesExistingShell',
        (tester) async {
      await mountShell(tester);
      final engine = tester.state(find.byType(FlowyTabTransitionStack));
      container.read(bottomNavIndexProvider.notifier).state = 1;
      await tester.pump();
      expect(
          tester
              .widget<FlowyTabTransitionStack>(
                  find.byType(FlowyTabTransitionStack))
              .index,
          1);
      await tester.pump(const Duration(milliseconds: 120));
      final layers = find.descendant(
          of: find.byType(FlowyTabTransitionStack),
          matching: find.byType(Offstage));
      expect(
          tester
              .widgetList<Offstage>(layers)
              .where((layer) => !layer.offstage)
              .length,
          2);
      await tester.pump(const Duration(milliseconds: 120));
      expect(
          identical(tester.state(find.byType(FlowyTabTransitionStack)), engine),
          true);
      expect(haptics, isEmpty);
      await unmount(tester);
    });

    testWidgets(
        'selectedNav_liftsIconAndHalo_deselectRestoresWithoutLabelMovement',
        (tester) async {
      await mountShell(tester);
      final label = find.text('Sổ GD').last;
      final labelPosition = tester.getCenter(label);
      final navItem =
          find.ancestor(of: label, matching: find.byType(InkWell)).first;
      List<Transform> transforms() => tester
          .widgetList<Transform>(
              find.descendant(of: navItem, matching: find.byType(Transform)))
          .toList();
      expect(transforms().first.transform.storage[13], 0);
      await tester.tap(label);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      expect(transforms().first.transform.storage[13], -3);
      expect(transforms()[1].transform.storage[0], closeTo(1.045, 0.0001));
      expect(tester.getCenter(label), labelPosition);
      final halo = tester
          .widgetList<DecoratedBox>(
              find.descendant(of: navItem, matching: find.byType(DecoratedBox)))
          .where((box) =>
              box.decoration is BoxDecoration &&
              (box.decoration as BoxDecoration).gradient is RadialGradient)
          .single;
      expect(
          ((halo.decoration as BoxDecoration).gradient as RadialGradient)
              .colors
              .first
              .a,
          closeTo(0.12, 0.0001));
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      await tester.tap(label);
      await tester.pump();
      expect(haptics.length, 1);
      container.read(bottomNavIndexProvider.notifier).state = 0;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      expect(transforms().first.transform.storage[13], 0);
      expect(transforms()[1].transform.storage[0], 1);
      expect(tester.getCenter(label), labelPosition);
      await unmount(tester);
    });

    for (final safeBottom in [0.0, 24.0, 48.0]) {
      testWidgets(
          'floatingDock_safeBottom${safeBottom}_canvasAndScrollClearance',
          (tester) async {
        await mountShell(tester, safeBottom: safeBottom);
        final engine = find.byType(FlowyTabTransitionStack);
        final dockRect = tester.getRect(dock(tester));
        expect(dockRect.height, 72);
        expect(dockRect.left, 16);
        expect(dockRect.right, 1080 - 16);
        expect(dockRect.bottom, 1920 - safeBottom - 16);
        expect(tester.getRect(engine).bottom, 1920);
        // Consumers see only the device inset, never the dock's occupied height.
        expect(MediaQuery.paddingOf(tester.element(engine)).bottom, safeBottom);

        for (final entry in {
          0: DashboardScreen,
          1: LedgerScreen,
          2: BudgetScreen,
          3: SettingsScreen,
        }.entries) {
          container.read(bottomNavIndexProvider.notifier).state = entry.key;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 260));
          final scroll = find
              .descendant(
                of: find.byType(entry.value),
                matching: find.byType(Scrollable),
              )
              .first;
          expect(
              tester.getRect(scroll).bottom, closeTo(1920 - safeBottom, 0.1));
          expect(tester.getRect(scroll).bottom, greaterThan(dockRect.top));
          expect(tester.getRect(dock(tester)), dockRect);
        }

        final settingsScroll = find.descendant(
            of: find.byType(SettingsScreen), matching: find.byType(Scrollable));
        final position = tester.state<ScrollableState>(settingsScroll).position;
        final lastLabel = find.byWidgetPredicate((widget) =>
            widget is Text &&
            (widget.data?.startsWith('Flowy • Phiên bản') ?? false));
        // Build the end of the lazy ListView before using its exact extent.
        await tester.scrollUntilVisible(lastLabel, 500,
            scrollable: settingsScroll, maxScrolls: 30);
        await tester.pump();
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        expect(tester.getRect(lastLabel).bottom,
            lessThanOrEqualTo(dockRect.top - 8));
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }

    testWidgets('floatingDock_tabStateAndSpatialAnchorsSurviveRapidSwitching',
        (tester) async {
      await mountShell(tester, safeBottom: 24);
      final screenTypes = [
        DashboardScreen,
        LedgerScreen,
        BudgetScreen,
        SettingsScreen
      ];
      final states = screenTypes
          .map((type) => tester.state(find.byType(type, skipOffstage: false)))
          .toList();
      final engineState = tester.state(find.byType(FlowyTabTransitionStack));
      final dockRect = tester.getRect(dock(tester));
      final fabRect =
          tester.getRect(find.byWidget(shell(tester).floatingActionButton!));
      for (final index in [1, 2, 3, 0, 2]) {
        container.read(bottomNavIndexProvider.notifier).state = index;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 35));
        expect(tester.getRect(dock(tester)), dockRect);
        expect(
            tester.getRect(find.byWidget(shell(tester).floatingActionButton!)),
            fabRect);
        for (var i = 0; i < 4; i++) {
          expect(
              identical(
                  tester
                      .state(find.byType(screenTypes[i], skipOffstage: false)),
                  states[i]),
              true);
        }
      }
      await tester.pump(const Duration(milliseconds: 260));
      expect(
          identical(
              tester.state(find.byType(FlowyTabTransitionStack)), engineState),
          true);
      expect(container.read(bottomNavIndexProvider), 2);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets(
        'floatingDock_blocksPageHitOnlyInsideDock_andFabStaysAboveGlass',
        (tester) async {
      await mountShell(tester, safeBottom: 24);
      final rect = tester.getRect(dock(tester));
      final pageRenderObject =
          tester.renderObject(find.byType(FlowyTabTransitionStack));
      final inside = tester.hitTestOnBinding(rect.center);
      expect(
          inside.path.any((entry) => identical(entry.target, pageRenderObject)),
          false);
      final outside = tester.hitTestOnBinding(Offset(8, rect.center.dy));
      expect(
          outside.path
              .any((entry) => identical(entry.target, pageRenderObject)),
          true);
      final fab = find.byWidget(shell(tester).floatingActionButton!);
      final fabHit = tester.hitTestOnBinding(tester.getCenter(fab));
      expect(
          fabHit.path.any((entry) =>
              identical(entry.target, tester.renderObject(dock(tester)))),
          false);
      // Exercise the real FAB gesture without submitting/opening Quick Entry.
      final press = await tester.startGesture(tester.getCenter(fab));
      await tester.pump(const Duration(milliseconds: 110));
      expect(haptics, contains('HapticFeedbackType.lightImpact'));
      await press.cancel();
      await tester.pump(const Duration(milliseconds: 160));
      await tester.tap(find.text('Sổ GD').last);
      await tester.pump();
      expect(container.read(bottomNavIndexProvider), 1);
      await unmount(tester);
    });

    for (final brightness in Brightness.values) {
      testWidgets(
          'floatingDock_${brightness.name}_singleClippedBlurAndUnclippedShadow',
          (tester) async {
        await mountShell(tester, brightness: brightness);
        final nav = find.byWidget(shell(tester).bottomNavigationBar!);
        final glass = dock(tester);
        expect(glass, findsOneWidget);
        final clip = tester.widget<ClipRRect>(
            find.ancestor(of: glass, matching: find.byType(ClipRRect)).first);
        expect(clip.borderRadius, BorderRadius.circular(26));
        final surface = tester
            .widgetList<Container>(
                find.descendant(of: glass, matching: find.byType(Container)))
            .where((widget) =>
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).border != null)
            .single;
        final decoration = surface.decoration! as BoxDecoration;
        final dark = brightness == Brightness.dark;
        expect(
            decoration.color,
            (dark ? AppTokens.darkCard : AppTokens.lightCard)
                .withValues(alpha: dark ? 0.68 : 0.66));
        final border = decoration.border! as Border;
        expect(border.top.width, 0.8);
        expect(border.top.color,
            Colors.white.withValues(alpha: dark ? 0.10 : 0.18));
        final shadowContainer = tester
            .widgetList<Container>(
                find.descendant(of: nav, matching: find.byType(Container)))
            .where((widget) =>
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).boxShadow != null)
            .single;
        final shadow =
            (shadowContainer.decoration! as BoxDecoration).boxShadow!.single;
        expect(
            shadow.color, Colors.black.withValues(alpha: dark ? 0.16 : 0.08));
        expect(shadow.blurRadius, 24);
        expect(shadow.offset, const Offset(0, 6));
        expect(shadowContainer.child, isA<ClipRRect>());
        expect(shell(tester).extendBody, true);
        await unmount(tester);
      });
    }
  });
}
