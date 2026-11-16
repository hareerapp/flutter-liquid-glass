import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_design/liquid_design.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Future<void> sendAppearance(
  WidgetTester tester,
  String prefix,
  Object? arguments,
) async {
  const codec = StandardMethodCodec();
  for (var id = 0; id < 8; id++) {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      '${prefix}_$id',
      codec.encodeMethodCall(MethodCall('appearance', arguments)),
      (_) {},
    );
  }
  await tester.pump();
}

Color? iconColor(WidgetTester tester, IconData icon) => tester
    .widget<RichText>(
      find.descendant(of: find.byIcon(icon), matching: find.byType(RichText)),
    )
    .text
    .style
    ?.color;

void main() {
  setUp(() {
    var next = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          if (call.method == 'create') return next++;
          return null;
        });
  });
  tearDown(LiquidGlassService.instance.reset);

  Widget app(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('icons turn white when the glass turns dark', (tester) async {
    Brightness? seen;
    await tester.pumpWidget(
      app(
        LiquidGlass(
          shape: const LiquidGlassShape.circle(),
          child: SizedBox.square(
            dimension: 44,
            child: Builder(
              builder: (context) {
                seen = LiquidGlassAppearance.maybeOf(context);
                return const Icon(Icons.search);
              },
            ),
          ),
        ),
      ),
    );
    final before = iconColor(tester, Icons.search)!;
    expect(before.computeLuminance(), lessThan(0.4));
    expect(seen, isNull);

    await sendAppearance(tester, 'liquid_design/glass', 'dark');
    expect(seen, Brightness.dark);
    expect(
      iconColor(tester, Icons.search),
      const Color(0xFFFFFFFF).withValues(alpha: before.a),
    );

    await sendAppearance(tester, 'liquid_design/glass', 'light');
    expect(seen, Brightness.light);
    expect(iconColor(tester, Icons.search), before);
  }, variant: ios);

  testWidgets('adaptiveForeground: false keeps the colour', (tester) async {
    await tester.pumpWidget(
      app(
        const LiquidGlass(
          adaptiveForeground: false,
          child: SizedBox.square(dimension: 44, child: Icon(Icons.search)),
        ),
      ),
    );
    final before = iconColor(tester, Icons.search);
    await sendAppearance(tester, 'liquid_design/glass', 'dark');
    expect(iconColor(tester, Icons.search), before);
  }, variant: ios);

  testWidgets('grouped glass gets its own appearance', (tester) async {
    await tester.pumpWidget(
      app(
        LiquidGlassGroup(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              LiquidGlass(
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(Icons.search),
                ),
              ),
              LiquidGlass(
                child: SizedBox.square(dimension: 44, child: Icon(Icons.add)),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    final before = iconColor(tester, Icons.add);
    for (var id = 0; id < 64; id++) {
      await sendAppearance(tester, 'liquid_design/glass_group', {
        'id': id,
        'appearance': 'dark',
      });
    }
    expect(iconColor(tester, Icons.search), isNot(before));
    expect(iconColor(tester, Icons.add), isNot(before));
  }, variant: ios);

  test('adaptTo only changes colours that would be hard to read', () {
    const black = Color(0xFF000000), white = Color(0xFFFFFFFF);
    const purple = Color(0xFF3E205A), yellow = Color(0xFFFFEB3B);
    expect(LiquidGlassAppearance.adaptTo(null, black), black);
    expect(LiquidGlassAppearance.adaptTo(Brightness.dark, black), white);
    expect(LiquidGlassAppearance.adaptTo(Brightness.dark, purple), white);
    expect(LiquidGlassAppearance.adaptTo(Brightness.dark, yellow), yellow);
    expect(LiquidGlassAppearance.adaptTo(Brightness.light, white), black);
    expect(LiquidGlassAppearance.adaptTo(Brightness.light, purple), purple);
  });

  testWidgets('glass button text adapts, prominent does not', (tester) async {
    await tester.pumpWidget(
      app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiquidGlassButton(onPressed: () {}, child: const Text('Glass')),
            LiquidGlassButton(
              style: LiquidGlassButtonStyle.prominent,
              onPressed: () {},
              child: const Text('Buy'),
            ),
          ],
        ),
      ),
    );
    Color? textColor(String text) => tester
        .widget<RichText>(
          find.descendant(of: find.text(text), matching: find.byType(RichText)),
        )
        .text
        .style
        ?.color;
    final buy = textColor('Buy');
    await sendAppearance(tester, 'liquid_design/glass', 'dark');
    expect(textColor('Glass'), const Color(0xFFFFFFFF));
    expect(textColor('Buy'), buy);
  }, variant: ios);
}
