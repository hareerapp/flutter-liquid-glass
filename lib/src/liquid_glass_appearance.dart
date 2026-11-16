import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The live light or dark appearance of the glass around a widget.
///
/// On iOS 26 glass adapts to the content behind it: over dark content it
/// turns dark, over light content it turns light, whatever the app theme.
/// [LiquidGlass] reports that appearance to its child through this widget.
/// It is null when the system does not report one, such as with
/// Flutter-drawn glass or on other platforms.
///
/// Icons and text without their own colour switch automatically. Widgets
/// with a fixed colour can follow it with [adapt]:
///
/// ```dart
/// Icon(
///   Icons.arrow_back,
///   color: LiquidGlassAppearance.adapt(context, brandColor),
/// )
/// ```
class LiquidGlassAppearance extends InheritedWidget {
  /// Provides [brightness] to [child].
  const LiquidGlassAppearance({
    super.key,
    required this.brightness,
    required super.child,
  });

  /// The appearance of the glass, or null when unknown.
  final Brightness? brightness;

  /// The appearance of the nearest glass around [context], or null.
  static Brightness? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LiquidGlassAppearance>()
      ?.brightness;

  /// Returns [color], or [onDark] / [onLight] when [color] would be hard to
  /// read on the current glass appearance.
  static Color adapt(
    BuildContext context,
    Color color, {
    Color onDark = const Color(0xFFFFFFFF),
    Color onLight = const Color(0xFF000000),
  }) => adaptTo(maybeOf(context), color, onDark: onDark, onLight: onLight);

  /// Like [adapt], for a known [appearance].
  static Color adaptTo(
    Brightness? appearance,
    Color color, {
    Color onDark = const Color(0xFFFFFFFF),
    Color onLight = const Color(0xFF000000),
  }) {
    if (appearance == null) return color;
    final dark = color.computeLuminance() < 0.4;
    if (appearance == Brightness.dark && dark) {
      return onDark.withValues(alpha: color.a);
    }
    if (appearance == Brightness.light && !dark) {
      return onLight.withValues(alpha: color.a);
    }
    return color;
  }

  @override
  bool updateShouldNotify(LiquidGlassAppearance oldWidget) =>
      oldWidget.brightness != brightness;
}

class GlassAppearanceScope extends StatelessWidget {
  const GlassAppearanceScope({
    super.key,
    required this.appearance,
    required this.adaptive,
    required this.child,
  });

  final ValueListenable<Brightness?>? appearance;
  final bool adaptive;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final appearance = this.appearance;
    if (appearance == null) return _scoped(context, null, child);
    return ValueListenableBuilder<Brightness?>(
      valueListenable: appearance,
      builder: (context, value, child) => _scoped(context, value, child!),
      child: child,
    );
  }

  Widget _scoped(BuildContext context, Brightness? value, Widget child) {
    Color? iconColor;
    Color? textColor;
    if (adaptive && value != null) {
      final icon = IconTheme.of(context).color;
      final text = DefaultTextStyle.of(context).style.color;
      if (icon != null) iconColor = LiquidGlassAppearance.adaptTo(value, icon);
      if (text != null) textColor = LiquidGlassAppearance.adaptTo(value, text);
    }
    return LiquidGlassAppearance(
      brightness: value,
      child: IconTheme.merge(
        data: IconThemeData(color: iconColor),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: textColor),
          child: child,
        ),
      ),
    );
  }
}
