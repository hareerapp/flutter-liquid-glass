import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Detects presses on glass the way iOS 26 bar buttons do.
///
/// The detector claims the finger as soon as it touches, so an enclosing
/// scroll view never takes the drag away. The glass can then follow and
/// stretch with the finger for as long as it is held. Pair it with
/// `dragExitDistance: double.infinity` on the glass:
///
/// ```dart
/// LiquidGlassPressDetector(
///   onPressed: openSearch,
///   child: const SizedBox.square(dimension: 44, child: Icon(Icons.search)),
/// ).liquidGlass(
///   shape: const LiquidGlassShape.circle(),
///   dragExitDistance: double.infinity,
/// )
/// ```
///
/// [onPressed] runs when the finger is lifted inside the widget, inflated by
/// [releaseDistance]. Use it for buttons outside scrolling lists; inside a
/// list a plain tap detector lets the list scroll.
class LiquidGlassPressDetector extends StatelessWidget {
  /// Creates a press detector around [child].
  const LiquidGlassPressDetector({
    super.key,
    required this.onPressed,
    required this.child,
    this.onLongPress,
    this.releaseDistance = 0,
    this.semanticLabel,
  });

  /// Called when the finger is lifted inside the widget. Null disables it.
  final VoidCallback? onPressed;

  /// Called when the finger is held still for a moment.
  final VoidCallback? onLongPress;

  /// How far outside the widget the finger may be lifted and still press.
  final double releaseDistance;

  /// Screen reader label.
  final String? semanticLabel;

  /// The pressable content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      onTap: onPressed,
      onLongPress: onLongPress,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        gestures: onPressed == null && onLongPress == null
            ? const <Type, GestureRecognizerFactory>{}
            : <Type, GestureRecognizerFactory>{
                _GlassPressRecognizer:
                    GestureRecognizerFactoryWithHandlers<_GlassPressRecognizer>(
                      () => _GlassPressRecognizer(debugOwner: this),
                      (recognizer) => recognizer
                        ..onPressed = onPressed
                        ..onLongPress = onLongPress
                        ..releaseDistance = releaseDistance
                        ..sizeOf = () => context.size,
                    ),
              },
        child: child,
      ),
    );
  }
}

class _GlassPressRecognizer extends OneSequenceGestureRecognizer {
  _GlassPressRecognizer({super.debugOwner});

  static const _longPressDelay = Duration(milliseconds: 500);

  VoidCallback? onPressed;
  VoidCallback? onLongPress;
  double releaseDistance = 0;
  Size? Function()? sizeOf;

  int? _pointer;
  Offset _down = Offset.zero;
  Timer? _longPress;
  bool _longPressed = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _down = event.localPosition;
    _longPressed = false;
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    if (onLongPress != null) {
      _longPress = Timer(_longPressDelay, () {
        if (_pointer == null) return;
        _longPressed = true;
        invokeCallback<void>('onLongPress', onLongPress!);
      });
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent &&
        (event.localPosition - _down).distance > kTouchSlop) {
      _longPress?.cancel();
    } else if (event is PointerUpEvent) {
      final inside = _inside(event.localPosition);
      _finish(event.pointer);
      final callback = onPressed;
      if (!_longPressed && inside && callback != null) {
        invokeCallback<void>('onPressed', callback);
      }
    } else if (event is PointerCancelEvent) {
      _finish(event.pointer);
    }
  }

  bool _inside(Offset position) {
    final size = sizeOf?.call();
    if (size == null) return false;
    return (Offset.zero & size).inflate(releaseDistance).contains(position);
  }

  void _finish(int pointer) {
    _longPress?.cancel();
    _longPress = null;
    stopTrackingPointer(pointer);
    _pointer = null;
  }

  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    if (pointer == _pointer) _finish(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  void dispose() {
    _longPress?.cancel();
    super.dispose();
  }

  @override
  String get debugDescription => 'glass press';
}
