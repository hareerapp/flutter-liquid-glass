import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class NativeTab {
  const NativeTab({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badge,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String? badge;

  bool sameLook(NativeTab other) =>
      other.label == label &&
      other.icon == icon &&
      other.selectedIcon == selectedIcon;
}

class NativeTabBar extends StatefulWidget {
  const NativeTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelected,
    required this.dark,
    required this.rtl,
    this.selectedColor,
    this.unselectedColor,
    this.badgeColor,
    this.fontAsset,
    this.fontSize = 10,
  });

  static const viewType = 'liquid_design/tab_bar';
  static const barHeight = 56.0;
  static const overflow = 24.0;
  static const iconSize = 24.0;

  final List<NativeTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final bool dark;
  final bool rtl;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? badgeColor;
  final String? fontAsset;
  final double fontSize;

  @override
  State<NativeTabBar> createState() => _NativeTabBarState();
}

class _NativeTabBarState extends State<NativeTabBar> {
  static final _icons = <String, Uint8List>{};

  static const _gestures = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
  };

  Map<String, Object?>? _params;
  MethodChannel? _channel;
  int _generation = 0;
  int? _sentIndex;
  List<String?>? _sentBadges;
  Map<String, Object?>? _sentStyle;
  double _dpr = 3;

  Map<String, Object?> get _style => {
    'dark': widget.dark,
    'selectedColor': widget.selectedColor?.toARGB32(),
    'unselectedColor': widget.unselectedColor?.toARGB32(),
    'badgeColor': widget.badgeColor?.toARGB32(),
  };

  List<String?> get _badges => [for (final tab in widget.tabs) tab.badge];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (_params == null || dpr != _dpr) {
      _dpr = dpr;
      _prepare();
    }
  }

  @override
  void didUpdateWidget(NativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameTabs(oldWidget.tabs, widget.tabs) ||
        oldWidget.rtl != widget.rtl ||
        oldWidget.fontAsset != widget.fontAsset ||
        oldWidget.fontSize != widget.fontSize) {
      _prepare();
      return;
    }
    _sync();
  }

  static bool _sameTabs(List<NativeTab> a, List<NativeTab> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!a[i].sameLook(b[i])) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _prepare() async {
    final tabs = widget.tabs;
    final dpr = _dpr;
    final images = await Future.wait([
      for (final tab in tabs) ...[
        _rasterize(tab.icon, dpr),
        _rasterize(tab.selectedIcon ?? tab.icon, dpr),
      ],
    ]);
    if (!mounted || !_sameTabs(tabs, widget.tabs) || dpr != _dpr) return;
    final style = _style;
    setState(() {
      _generation++;
      _channel?.setMethodCallHandler(null);
      _channel = null;
      _sentIndex = widget.currentIndex;
      _sentBadges = _badges;
      _sentStyle = style;
      _params = {
        ...style,
        'tabs': [
          for (var i = 0; i < tabs.length; i++)
            {
              'label': tabs[i].label,
              'icon': images[i * 2],
              'selectedIcon': images[i * 2 + 1],
              'badge': tabs[i].badge,
            },
        ],
        'iconScale': dpr,
        'selectedIndex': widget.currentIndex,
        'rtl': widget.rtl,
        'fontSize': widget.fontSize,
        'fontAsset': widget.fontAsset,
        'overflow': NativeTabBar.overflow,
      };
    });
  }

  static Future<Uint8List?> _rasterize(IconData icon, double dpr) async {
    final key = '${icon.fontFamily}|${icon.fontPackage}|${icon.codePoint}|$dpr';
    final cached = _icons[key];
    if (cached != null) return cached;
    final recorder = ui.PictureRecorder();
    final painter = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: NativeTabBar.iconSize * dpr,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          height: 1,
          color: const Color(0xFFFFFFFF),
        ),
      )
      ..layout();
    painter.paint(Canvas(recorder), Offset.zero);
    final width = painter.width.ceil(), height = painter.height.ceil();
    painter.dispose();
    if (width <= 0 || height <= 0) return null;
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return null;
    return _icons[key] = data.buffer.asUint8List();
  }

  void _onCreated(int id) {
    _channel = MethodChannel('${NativeTabBar.viewType}_$id')
      ..setMethodCallHandler(_onNativeCall);
    _sync();
  }

  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method != 'onTabSelected' || !mounted) return;
    final index = call.arguments;
    if (index is! int) return;
    _sentIndex = index;
    widget.onSelected(index);
  }

  void _sync() {
    final channel = _channel;
    if (channel == null) return;
    if (_sentIndex != widget.currentIndex) {
      _sentIndex = widget.currentIndex;
      _invoke(channel, 'select', widget.currentIndex);
    }
    final badges = _badges;
    if (!listEquals(badges, _sentBadges)) {
      _sentBadges = badges;
      _invoke(channel, 'badges', badges);
    }
    final style = _style;
    if (!mapEquals(style, _sentStyle)) {
      _sentStyle = style;
      _invoke(channel, 'style', style);
    }
  }

  static void _invoke(MethodChannel channel, String method, Object? args) {
    unawaited(channel.invokeMethod<void>(method, args).catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final height =
        NativeTabBar.barHeight + MediaQuery.viewPaddingOf(context).bottom;
    final params = _params;
    return SizedBox(
      height: height,
      child: params == null
          ? null
          : Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: -NativeTabBar.overflow,
                  bottom: 0,
                  child: UiKitView(
                    key: ValueKey(_generation),
                    viewType: NativeTabBar.viewType,
                    creationParams: params,
                    creationParamsCodec: const StandardMessageCodec(),
                    gestureRecognizers: _gestures,
                    onPlatformViewCreated: _onCreated,
                  ),
                ),
              ],
            ),
    );
  }
}
