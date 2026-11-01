import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

/// Material 3 Expressive motion, plus a couple of springy flourishes.
abstract final class Motion {
  static const emphasized = Cubic(0.18, 0.0, 0.0, 1.0);
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const overshoot = Cubic(0.34, 1.4, 0.64, 1.0);

  /// Expressive spring: ~14% overshoot before settling. Reserved for the
  /// material visual language so entrances and button releases visibly bounce.
  static const springy = Cubic(0.30, 1.56, 0.42, 1.0);

  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 560);
  static const glacial = Duration(milliseconds: 900);

  /// Release motion for presses on the material language. Long enough for the
  /// spring to be visible, unlike [fast] which swallows the overshoot.
  static const release = Duration(milliseconds: 420);
}

/// A tiny spring for press/hover scale. No animation package required.
class SpringScale extends StatefulWidget {
  const SpringScale({
    super.key,
    required this.child,
    this.pressedScale = 0.96,
    this.enabled = true,
  });

  final Widget child;
  final double pressedScale;
  final bool enabled;

  @override
  State<SpringScale> createState() => _SpringScaleState();
}

class _SpringScaleState extends State<SpringScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _controller.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 0.9, stiffness: 320, damping: 22),
        _controller.value,
        target,
        0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled
          ? (_) => _animateTo(widget.pressedScale)
          : null,
      onPointerUp: widget.enabled ? (_) => _animateTo(1) : null,
      onPointerCancel: widget.enabled ? (_) => _animateTo(1) : null,
      child: ScaleTransition(scale: _controller, child: widget.child),
    );
  }
}

/// Fade + rise entrance with a stagger delay. Motion is skipped when the
/// platform asks for reduced motion.
class RiseIn extends StatefulWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.slow,
    this.offset = 24,
    this.enabled = true,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;
  final bool enabled;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.enabled ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final springy = AppStyle.of(context).isMaterial;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: springy ? Motion.springy : Motion.emphasizedDecelerate,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final value = curved.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Soft, endlessly drifting value in 0..1 — used for ambient glows.
class AmbientDrift extends StatefulWidget {
  const AmbientDrift({
    super.key,
    required this.builder,
    this.period = const Duration(seconds: 18),
    this.enabled = true,
  });

  final Widget Function(BuildContext context, double t) builder;
  final Duration period;
  final bool enabled;

  @override
  State<AmbientDrift> createState() => _AmbientDriftState();
}

class _AmbientDriftState extends State<AmbientDrift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.builder(context, 0);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return widget.builder(context, (math.sin(t * math.pi * 2) + 1) / 2);
      },
    );
  }
}
