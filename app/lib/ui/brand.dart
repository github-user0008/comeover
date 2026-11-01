import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'expressive.dart';

/// ComeOver's mark: two orbits drifting into each other.
class BrandMark extends StatefulWidget {
  const BrandMark({super.key, this.size = 72, this.animated = true});

  final double size;
  final bool animated;

  @override
  State<BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<BrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animated) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _MarkPainter(
          t: widget.animated ? _controller.value : 0.3,
          brand: scheme.primary,
          accent: style.accent,
          live: style.live,
          ink: style.ink,
          warm: style.warm,
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({
    required this.t,
    required this.brand,
    required this.accent,
    required this.live,
    required this.ink,
    required this.warm,
  });

  final double t;
  final Color brand;
  final Color accent;
  final Color live;
  final Color ink;
  final Color warm;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.3;
    final separation = math.sin(t * math.pi * 2) * size.shortestSide * 0.10;

    final left = center.translate(-radius * 0.62 - separation, -radius * 0.12);
    final right = center.translate(radius * 0.62 + separation, radius * 0.12);

    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..shader = RadialGradient(
        colors: [brand.withValues(alpha: 0.7), Colors.transparent],
      ).createShader(Rect.fromCircle(center: left, radius: radius * 1.4));
    canvas.drawCircle(left, radius * 1.2, glow);

    final leftFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, brand],
      ).createShader(Rect.fromCircle(center: left, radius: radius));
    canvas.drawCircle(left, radius, leftFill);

    final rightStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.035
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [live, Color.lerp(live, brand, 0.35)!],
      ).createShader(Rect.fromCircle(center: right, radius: radius));
    canvas.drawCircle(right, radius, rightStroke);

    final inner = Paint()..color = ink.withValues(alpha: 0.55);
    canvas.drawCircle(left, radius * 0.46, inner);
    canvas.drawCircle(
      right,
      radius * 0.46,
      Paint()..color = live.withValues(alpha: 0.9),
    );

    // A small comet that travels along the connection.
    final angle = t * math.pi * 2;
    final pathCenter = Offset.lerp(left, right, (math.sin(angle) + 1) / 2)!;
    final dot = Paint()
      ..color = warm
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(
      pathCenter.translate(0, math.cos(angle) * radius * 0.55),
      size.shortestSide * 0.03,
      dot,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.t != t ||
      old.brand != brand ||
      old.accent != accent ||
      old.live != live;
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.compact = false, this.tagline = false});

  final bool compact;
  final bool tagline;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      fontSize: compact ? 18 : 26,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: compact ? 30 : 40, animated: !compact),
        SizedBox(width: compact ? 8 : 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientText('ComeOver', style: style),
            if (tagline)
              Text(
                'See them coming.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Staggered "wave" dots used while waiting for a join.
class WaitingDots extends StatefulWidget {
  const WaitingDots({super.key, this.color});

  final Color? color;

  @override
  State<WaitingDots> createState() => _WaitingDotsState();
}

class _WaitingDotsState extends State<WaitingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppStyle.of(context).live;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              _dot(i, color),
              if (i < 2) const SizedBox(width: 7),
            ],
          ],
        );
      },
    );
  }

  Widget _dot(int index, Color color) {
    final phase = (_controller.value - index * 0.18) % 1;
    final lift = math.sin(phase * math.pi).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, -5 * lift),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.35 + lift * 0.65),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5 * lift),
              blurRadius: 10,
            ),
          ],
        ),
      ),
    );
  }
}

/// Radar sweep used in the lobby.
class RadarSweep extends StatefulWidget {
  const RadarSweep({super.key, this.size = 260, this.child});

  final double size;
  final Widget? child;

  @override
  State<RadarSweep> createState() => _RadarSweepState();
}

class _RadarSweepState extends State<RadarSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppStyle.of(context).live;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarPainter(t: _controller.value, color: color),
            child: Center(child: child),
          );
        },
        child: widget.child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: 0.16);
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * i / 4, ring);
    }
    final sweep = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        stops: const [0, 0.22],
        transform: GradientRotation(t * math.pi * 2 - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, sweep);
    final beam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.5);
    final angle = t * math.pi * 2 - math.pi / 2;
    canvas.drawLine(
      center,
      center + Offset(math.cos(angle), math.sin(angle)) * maxRadius,
      beam,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.color != color;
}

/// Faint moving sheen for the hero card.
class Sheen extends StatefulWidget {
  const Sheen({super.key, required this.child, this.radius = 32});

  final Widget child;
  final double radius;

  @override
  State<Sheen> createState() => _SheenState();
}

class _SheenState extends State<Sheen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Stack(
        children: [
          widget.child,
          if (!reduce)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final x = _controller.value * 2.4 - 1.2;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(x - 0.5, -1),
                          end: Alignment(x + 0.5, 1),
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.055),
                            Colors.white.withValues(alpha: 0),
                          ],
                          stops: const [0.35, 0.5, 0.65],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
