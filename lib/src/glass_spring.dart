import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';

final Expando<Duration> _lastStart = Expando<Duration>();

void animateGlassSpring(
  AnimationController controller,
  double target,
  SpringDescription spring,
) {
  final now = SchedulerBinding.instance.currentSystemFrameTimeStamp;
  final last = _lastStart[controller];
  final carried = controller.isAnimating && last != null
      ? math.min((now - last).inMicroseconds / 1e6, _maxStep)
      : 0.0;
  _lastStart[controller] = now;
  controller.animateWith(
    _CappedSimulation(
      SpringSimulation(spring, controller.value, target, controller.velocity),
      startTime: carried,
    ),
  );
}

const double _maxStep = 1 / 30;

class _CappedSimulation extends Simulation {
  _CappedSimulation(this._inner, {double startTime = 0})
    : _virtualTime = startTime;

  final Simulation _inner;
  double _lastTime = 0;
  double _virtualTime;

  double _advance(double time) {
    if (time > _lastTime) {
      _virtualTime += math.min(time - _lastTime, _maxStep);
      _lastTime = time;
    }
    return _virtualTime;
  }

  @override
  double x(double time) => _inner.x(_advance(time));

  @override
  double dx(double time) => _inner.dx(_advance(time));

  @override
  bool isDone(double time) => _inner.isDone(_advance(time));
}
