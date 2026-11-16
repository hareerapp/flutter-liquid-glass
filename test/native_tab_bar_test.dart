import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_design/liquid_design.dart';
import 'package:liquid_design/src/glass_selection_bar.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

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

  Widget bar({
    required int index,
    required ValueChanged<int> onTap,
    ValueChanged<int>? onReselect,
    Widget firstIcon = const Icon(Icons.home),
  }) => MaterialApp(
    home: Scaffold(
      extendBody: true,
      bottomNavigationBar: LiquidGlassNavigationBar(
        native: true,
        currentIndex: index,
        onTap: onTap,
        onReselect: onReselect,
        items: [
          LiquidGlassNavItem(icon: firstIcon, label: 'Home'),
          const LiquidGlassNavItem(
            icon: Icon(Icons.search),
            activeIcon: Icon(Icons.search_off),
            label: 'Search',
            badge: '3',
          ),
        ],
      ),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  Future<void> fromNative(WidgetTester tester, Object? index) async {
    const codec = StandardMethodCodec();
    for (var id = 0; id < 4; id++) {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'liquid_design/tab_bar_$id',
        codec.encodeMethodCall(MethodCall('onTabSelected', index)),
        (_) {},
      );
    }
  }

  testWidgets('iOS uses the system tab bar with every tab', (tester) async {
    await tester.pumpWidget(bar(index: 0, onTap: (_) {}));
    await settle(tester);
    final view = tester.widget<UiKitView>(find.byType(UiKitView));
    expect(view.viewType, 'liquid_design/tab_bar');
    final params = view.creationParams! as Map<String, Object?>;
    final tabs = params['tabs']! as List;
    expect(tabs, hasLength(2));
    expect((tabs[1] as Map)['label'], 'Search');
    expect((tabs[1] as Map)['badge'], '3');
    expect((tabs[1] as Map)['icon'], isA<Uint8List>());
    expect(find.byType(GlassSelectionBar), findsNothing);
  }, variant: ios);

  testWidgets('native taps call onTap and onReselect', (tester) async {
    final taps = <int>[], reselects = <int>[];
    await tester.pumpWidget(
      bar(index: 0, onTap: taps.add, onReselect: reselects.add),
    );
    await settle(tester);
    await fromNative(tester, 1);
    await fromNative(tester, 0);
    expect(taps, contains(1));
    expect(reselects, contains(0));
  }, variant: ios);

  testWidgets('a non-Icon icon falls back to the Flutter bar', (tester) async {
    await tester.pumpWidget(
      bar(index: 0, onTap: (_) {}, firstIcon: const Text('H')),
    );
    await settle(tester);
    expect(find.byType(GlassSelectionBar), findsOneWidget);
  }, variant: ios);

  testWidgets('other platforms keep the Flutter bar and draw badges', (
    tester,
  ) async {
    await tester.pumpWidget(bar(index: 0, onTap: (_) {}));
    await settle(tester);
    expect(find.byType(UiKitView), findsNothing);
    expect(find.byType(GlassSelectionBar), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
