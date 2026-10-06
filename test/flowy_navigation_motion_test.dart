import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pfm_app/core/animation/flowy_navigation_motion.dart';
import 'package:pfm_app/data/database.dart';
import 'package:pfm_app/screens/main_scaffold.dart';
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
    Future<void> mountShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MainScaffold()),
      ));
      await tester.pump();
    }

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
  });
}
