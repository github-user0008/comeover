import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Two people, one dotted route, a light travelling between them.
class RouteIllustration extends StatefulWidget {
  const RouteIllustration({
    super.key,
    this.height = 132,
    this.leftEmoji = '🦊',
    this.rightEmoji = '🐼',
  });

  final double height;
  final String leftEmoji;
  final String rightEmoji;

  @override
  State<RouteIllustration> createState() => _RouteIllustrationState();
}

class _RouteIllustrationState extends State<RouteIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _RoutePainter(
              t: _controller.value,
              lineColor: scheme.outlineVariant,
              accent: scheme.secondary,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Avatar(emoji: widget.leftEmoji, glow: scheme.primary, size: widget.height * 0.44),
                  _Avatar(emoji: widget.rightEmoji, glow: scheme.secondary, size: widget.height * 0.44),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.emoji, required this.glow, required this.size});

  final String emoji;
  final Color glow;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(color: glow.withValues(alpha: 0.5), blurRadius: 26, spreadRadius: 2),
        ],
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5, height: 1)),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.t, required this.lineColor, required this.accent});

  final double t;
  final Color lineColor;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final start = Offset(size.width * 0.2, y);
    final end = Offset(size.width * 0.8, y);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(size.width * 0.38, y - size.height * 0.24, size.width * 0.62, y + size.height * 0.24, end.dx, end.dy);

    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.28);
    _drawDashed(canvas, path, dashPaint, dash: 7, gap: 7);

    final metric = path.computeMetrics().first;
    final distance = metric.length * t;
    final point = metric.getTangentForOffset(distance)?.position ?? start;
    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..color = accent.withValues(alpha: 0.9);
    canvas.drawCircle(point, 7, glow);
    canvas.drawCircle(point, 3.2, Paint()..color = Colors.white);

    // Arrival pulse at the destination.
    final pulse = (t * 2) % 1;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Palette.mint.withValues(alpha: (1 - pulse) * 0.5);
    canvas.drawCircle(end, 10 + pulse * 22, ring);

    // A couple of sparkles.
    final sparkle = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (var i = 0; i < 5; i++) {
      final angle = i * 1.7 + t * math.pi * 2;
      final center = Offset(
        size.width * (0.32 + 0.36 * ((i + 1) / 6)),
        y + math.sin(angle) * size.height * 0.22,
      );
      canvas.drawCircle(center, 1.3, sparkle);
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint, {required double dash, required double gap}) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.t != t;
}
