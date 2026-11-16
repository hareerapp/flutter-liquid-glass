import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_design/liquid_design.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Future<void> frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Matrix4 glassTransform(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byType(LiquidGlass),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform;

Widget inList(Widget child, ScrollController controller) => MaterialApp(
  home: Scaffold(
    body: ListView(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Center(child: child),
        const SizedBox(height: 2000),
      ],
    ),
  ),
);

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        );
  });
  tearDown(LiquidGlassService.instance.reset);

  Widget headerButton(VoidCallback onPressed, {VoidCallback? onLongPress}) =>
      LiquidGlassPressDetector(
        onPressed: onPressed,
        onLongPress: onLongPress,
        child: const SizedBox.square(dimension: 44, child: Icon(Icons.search)),
      ).liquidGlass(
        shape: const LiquidGlassShape.circle(),
        dragExitDistance: double.infinity,
      );

  testWidgets('holds the finger: the list does not scroll, glass stretches', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var presses = 0;
    await tester.pumpWidget(inList(headerButton(() => presses++), scroll));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.search)),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await frames(tester, 40);
    expect(scroll.offset, 0);
    final m = glassTransform(tester);
    expect(m.storage[5], greaterThan(m.storage[0] * 1.15));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(presses, 0);
  }, variant: ios);

  testWidgets('presses when lifted inside after a drag', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var presses = 0;
    await tester.pumpWidget(inList(headerButton(() => presses++), scroll));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.search)),
    );
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -55));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(presses, 1);
    expect(scroll.offset, 0);
  }, variant: ios);

  testWidgets('long press fires once and skips the press', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var presses = 0, longPresses = 0;
    await tester.pumpWidget(
      inList(
        headerButton(() => presses++, onLongPress: () => longPresses++),
        scroll,
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.search)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(longPresses, 1);
    expect(presses, 0);
  }, variant: ios);

  testWidgets('LiquidGlassButton captureDrag holds the finger', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    var presses = 0;
    await tester.pumpWidget(
      inList(
        LiquidGlassButton.icon(
          captureDrag: true,
          onPressed: () => presses++,
          icon: const Icon(Icons.add),
        ),
        scroll,
      ),
    );
    final start = tester.getCenter(find.byIcon(Icons.add));
    final gesture = await tester.startGesture(start);
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(scroll.offset, 0);
    await gesture.moveTo(start);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(presses, 1);
  }, variant: ios);

  testWidgets('without captureDrag a button in a list still scrolls', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      inList(
        LiquidGlassButton.icon(onPressed: () {}, icon: const Icon(Icons.add)),
        scroll,
      ),
    );
    await tester.drag(find.byIcon(Icons.add), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
  }, variant: ios);
}
