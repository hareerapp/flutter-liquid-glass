import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'glass_selection_bar.dart';
import 'liquid_glass_service.dart';
import 'liquid_glass_settings.dart';
import 'liquid_glass_theme.dart';
import 'native_tab_bar.dart';

/// One tab of a [LiquidGlassNavigationBar].
class LiquidGlassNavItem {
  /// Creates a tab.
  const LiquidGlassNavItem({
    required this.icon,
    this.activeIcon,
    this.label,
    this.badge,
  });

  /// Icon of the tab.
  final Widget icon;

  /// Icon shown while the tab is selected.
  final Widget? activeIcon;

  /// Text under the icon.
  final String? label;

  /// Short text in a badge on the icon, such as a count. Null hides it.
  final String? badge;
}

/// An iOS 26 glass tab bar with a sliding, stretching selection.
class LiquidGlassNavigationBar extends StatelessWidget {
  /// Creates a navigation bar with at least two [items].
  const LiquidGlassNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.activeColor,
    this.inactiveColor,
    this.height,
    this.padding = 4,
    this.settings,
    this.collapsed = false,
    this.onExpand,
    this.onReselect,
    this.native = false,
    this.badgeColor,
    this.nativeFontAsset,
  }) : assert(items.length >= 2),
       assert(currentIndex >= 0 && currentIndex < items.length);

  /// The tabs.
  final List<LiquidGlassNavItem> items;

  /// Index of the selected tab.
  final int currentIndex;

  /// Called when a tab is chosen.
  final ValueChanged<int> onTap;

  /// Colour of the selected tab.
  final Color? activeColor;

  /// Colour of the other tabs.
  final Color? inactiveColor;

  /// Height of the bar. 64 with labels, 56 without.
  final double? height;

  /// Space between the bar edge and the selection.
  final double padding;

  /// Glass settings for this widget. Falls back to the nearest [LiquidGlassTheme], then [LiquidGlassService].
  final LiquidGlassSettings? settings;

  /// Shrinks the bar to the selected tab.
  final bool collapsed;

  /// Called when a collapsed bar is tapped.
  final VoidCallback? onExpand;

  /// Called when the selected tab is tapped again.
  final ValueChanged<int>? onReselect;

  /// Uses the system iOS 26 tab bar (`UITabBar`) on iOS with Liquid Glass.
  ///
  /// The whole bar, its icons and its lens are drawn natively, so Flutter
  /// draws nothing on top of the native glass. That is the fastest option
  /// for a bar pinned to the bottom of the screen, and it looks and behaves
  /// exactly like the system tab bar. Place it at the bottom edge at full
  /// width, for example as `Scaffold.bottomNavigationBar` with
  /// `extendBody: true`.
  ///
  /// Icons must be [Icon] widgets. Elsewhere, and when an icon is not an
  /// [Icon], the Flutter-drawn bar is used. [collapsed] is ignored by the
  /// native bar.
  final bool native;

  /// Background colour of [LiquidGlassNavItem.badge].
  final Color? badgeColor;

  /// Font asset for labels of the native bar, such as `assets/font/x.otf`.
  final String? nativeFontAsset;

  List<NativeTab>? _nativeTabs() {
    final tabs = <NativeTab>[];
    for (final item in items) {
      final icon = item.icon, active = item.activeIcon;
      if (icon is! Icon || icon.icon == null) return null;
      if (active != null && (active is! Icon || active.icon == null)) {
        return null;
      }
      tabs.add(
        NativeTab(
          label: item.label ?? '',
          icon: icon.icon!,
          selectedIcon: (active as Icon?)?.icon,
          badge: item.badge,
        ),
      );
    }
    return tabs;
  }

  Widget _withBadge(BuildContext context, Widget icon, String? badge) {
    if (badge == null) return icon;
    return Badge(
      label: Text(badge),
      backgroundColor: badgeColor,
      offset: const Offset(10, -6),
      child: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? theme.colorScheme.primary;
    final inactive = inactiveColor ?? theme.colorScheme.onSurface;
    final hasLabels = items.any((item) => item.label != null);

    return LiquidGlassSettingsBuilder(
      settings: settings,
      builder: (context, glass) {
        final tabs =
            native &&
                defaultTargetPlatform == TargetPlatform.iOS &&
                LiquidGlassService.usesNativeLens(glass)
            ? _nativeTabs()
            : null;
        if (tabs != null) {
          return NativeTabBar(
            tabs: tabs,
            currentIndex: currentIndex,
            onSelected: (index) =>
                index == currentIndex ? onReselect?.call(index) : onTap(index),
            dark: theme.brightness == Brightness.dark,
            rtl: Directionality.of(context) == TextDirection.rtl,
            selectedColor: active,
            unselectedColor: inactiveColor,
            badgeColor: badgeColor,
            fontAsset: nativeFontAsset,
          );
        }
        return _flutterBar(context, glass, active, inactive, hasLabels);
      },
    );
  }

  Widget _flutterBar(
    BuildContext context,
    LiquidGlassSettings glass,
    Color active,
    Color inactive,
    bool hasLabels,
  ) {
    return GlassSelectionBar(
      count: items.length,
      currentIndex: currentIndex,
      onSelected: onTap,
      height: height ?? (hasLabels ? 64.0 : 56.0),
      padding: padding,
      pillColor: inactive.withValues(alpha: 0.1),
      semanticLabels: [for (final item in items) item.label],
      settings: settings,
      collapsed: collapsed && glass.collapseOnScroll,
      onExpand: onExpand,
      onReselected: onReselect,
      itemBuilder: (context, i, selection, lift, collapse) {
        final item = items[i];
        final color = Color.lerp(inactive, active, selection)!;
        final scale = 1 + 0.18 * lift.clamp(0.0, 1.0) * selection;
        final labelOpacity = (1 - collapse * 2).clamp(0.0, 1.0);

        return Transform.scale(
          scale: scale,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme.merge(
                data: IconThemeData(color: color, size: 24),
                child: _withBadge(
                  context,
                  selection > 0.5 ? (item.activeIcon ?? item.icon) : item.icon,
                  item.badge,
                ),
              ),
              if (item.label != null && labelOpacity > 0) ...[
                const SizedBox(height: 2),
                Opacity(
                  opacity: labelOpacity,
                  child: ExcludeSemantics(
                    child: Text(
                      item.label!,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Reports when scrolling [child] should collapse a navigation bar.
class LiquidGlassScrollCollapse extends StatefulWidget {
  /// Creates a scroll listener for [child].
  const LiquidGlassScrollCollapse({
    super.key,
    required this.onChanged,
    required this.child,
    this.threshold = 24,
    this.collapsed,
    this.settings,
  });

  /// Called with true to collapse and false to expand.
  final ValueChanged<bool> onChanged;

  /// The scrolling content.
  final Widget child;

  /// The current collapsed state, when known.
  final bool? collapsed;

  /// Glass settings for this widget. Falls back to the nearest [LiquidGlassTheme], then [LiquidGlassService].
  final LiquidGlassSettings? settings;

  /// Distance to scroll before the state changes.
  final double threshold;

  @override
  State<LiquidGlassScrollCollapse> createState() =>
      _LiquidGlassScrollCollapseState();
}

class _LiquidGlassScrollCollapseState extends State<LiquidGlassScrollCollapse> {
  bool _collapsed = false;
  double _accumulated = 0;

  void _set(bool collapsed) {
    _accumulated = 0;
    if (collapsed == _collapsed) return;
    _collapsed = collapsed;
    widget.onChanged(collapsed);
  }

  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.collapsed ?? false;
  }

  @override
  void didUpdateWidget(LiquidGlassScrollCollapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    final collapsed = widget.collapsed;
    if (collapsed != null && collapsed != _collapsed) {
      _collapsed = collapsed;
      _accumulated = 0;
    }
  }

  bool _onScroll(ScrollUpdateNotification n) {
    if (!_enabled) return false;
    if (n.metrics.axis != Axis.vertical) return false;
    final delta = n.scrollDelta ?? 0;
    if (delta == 0) return false;
    if (n.metrics.pixels <= n.metrics.minScrollExtent + 8) {
      _set(false);
      return false;
    }
    if (n.metrics.pixels > n.metrics.maxScrollExtent) return false;
    if (delta.sign != _accumulated.sign) _accumulated = 0;
    _accumulated += delta;
    if (_accumulated > widget.threshold) _set(true);
    if (_accumulated < -widget.threshold) _set(false);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LiquidGlassSettingsBuilder(
      settings: widget.settings,
      builder: (context, glass) {
        _enabled = glass.collapseOnScroll;
        if (!_enabled && _collapsed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_enabled) _set(false);
          });
        }
        return NotificationListener<ScrollUpdateNotification>(
          onNotification: _onScroll,
          child: widget.child,
        );
      },
    );
  }
}
