import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pfm_app/widgets/precision_numpad.dart';
import 'package:pfm_app/widgets/vault_security_surface.dart';

Widget surface(Widget child) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  testWidgets('Key preserves compression and dark ink with animations disabled',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(surface(PrecisionNumpadKey.number(
      number: '1',
      color: const Color(0xFF0F172A),
      fontWeight: FontWeight.w700,
      onPressed: () => taps++,
    )));
    final gesture = await tester.startGesture(tester.getCenter(find.text('1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final transform = tester.widget<Transform>(find
        .ancestor(
          of: find.text('1'),
          matching: find.byType(Transform),
        )
        .first);
    expect(transform.transform.storage[0], closeTo(0.92, 0.001));
    final text = tester.widget<Text>(find.text('1'));
    expect(text.style!.color, const Color(0xFF0F172A));
    expect(text.style!.fontWeight, FontWeight.w700);
    expect(taps, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Long press clears once without firing backspace tap',
      (tester) async {
    var taps = 0;
    var clears = 0;
    await tester.pumpWidget(surface(PrecisionNumpadKey.action(
      PrecisionNumpadAction(
        icon: Icons.backspace_outlined,
        onPressed: () => taps++,
        onLongPress: () => clears++,
      ),
    )));
    final gesture = await tester
        .startGesture(tester.getCenter(find.byIcon(Icons.backspace_outlined)));
    await tester.pump(const Duration(milliseconds: 349));
    expect(clears, 0);
    await tester.pump(const Duration(milliseconds: 2));
    expect(clears, 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(clears, 1);
    expect(taps, 0);
  });

  testWidgets(
      'Security canvas scrolls without overflow on a narrow short screen',
      (tester) async {
    tester.view.physicalSize = const Size(280, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VaultSecuritySurface(
      child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const SizedBox(height: 44),
            const Expanded(
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
              VaultBreathingShield(accent: Colors.teal),
              SizedBox(height: 100),
              VaultPinDots(
                  length: 6, enteredLength: 0, accentColor: Colors.teal),
            ]))),
            PrecisionNumpad(onDigit: (_) {}, onBackspace: () {}),
          ])),
    ))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final length in [4, 6]) {
    testWidgets('$length digit PIN only pops the newly filled dot',
        (tester) async {
      Widget dots(int entered) => surface(VaultPinDots(
            length: length,
            enteredLength: entered,
            accentColor: Colors.teal,
          ));
      List<double> scales() => tester
          .widgetList<Transform>(find.descendant(
            of: find.byType(VaultPinDots),
            matching: find.byType(Transform),
          ))
          .where((w) => w.child is Container)
          .map((w) => w.transform.storage[0])
          .toList();
      await tester.pumpWidget(dots(0));
      await tester.pumpWidget(dots(1));
      await tester.pump(const Duration(milliseconds: 60));
      expect(scales().first, closeTo(20 / 16, 0.001));
      await tester.pumpAndSettle();
      await tester.pumpWidget(dots(2));
      await tester.pump(const Duration(milliseconds: 60));
      expect(scales().first, 1);
      expect(scales()[1], closeTo(20 / 16, 0.001));
      await tester.pumpAndSettle();
      await tester.pumpWidget(dots(1));
      await tester.pump(const Duration(milliseconds: 60));
      expect(scales()[1], lessThan(1));
      // Removing the route mid-animation must dispose all tickers safely.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  }
}
