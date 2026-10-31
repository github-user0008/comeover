import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Animated night-sky backdrop. Two liquid blobs drift behind a soft vignette;
/// glass surfaces above it pick up the colour and blur.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.intensity = 1,
    this.dark = true,
  });

  final Widget child;
  final double intensity;
  final bool dark;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final painter = _AuroraPainter(
      t: reduceMotion ? 0.35 : _controller.value,
      dark: widget.dark,
      intensity: widget.intensity,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(painter: painter, isComplex: true),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.t, required this.dark, required this.intensity});

  final double t;
  final bool dark;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = dark ? Palette.ink : const Color(0xFFFDF9FF);
    canvas.drawRect(rect, Paint()..color = base);

    final angle = t * math.pi * 2;
    final minDim = size.shortestSide;

    if (dark) {
      _blob(
        canvas,
        size,
        center: Offset(
          size.width * (0.78 + math.sin(angle) * 0.08),
          size.height * (0.08 + math.cos(angle * 0.8) * 0.05),
        ),
        radius: minDim * 0.95,
        color: Palette.violet.withValues(alpha: 0.55 * intensity),
      );
      _blob(
        canvas,
        size,
        center: Offset(
          size.width * (0.12 + math.cos(angle * 0.7) * 0.10),
          size.height * (0.86 + math.sin(angle * 0.9) * 0.06),
        ),
        radius: minDim * 0.85,
        color: const Color(0xFF16C7DA).withValues(alpha: 0.30 * intensity),
      );
      _blob(
        canvas,
        size,
        center: Offset(
          size.width * (0.45 + math.sin(angle * 0.5 + 2) * 0.22),
          size.height * (0.42 + math.cos(angle * 0.6) * 0.18),
        ),
        radius: minDim * 0.55,
        color: const Color(0xFFFF7E5F).withValues(alpha: 0.16 * intensity),
      );
      _blob(
        canvas,
        size,
        center: Offset(size.width * 0.6, size.height * 1.1),
        radius: minDim * 0.7,
        color: const Color(0xFF4E2A84).withValues(alpha: 0.55),
      );
      // Vignette so the glass edges stay legible.
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 1.05,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
            stops: const [0.45, 1],
          ).createShader(rect),
      );
    } else {
      _blob(
        canvas,
        size,
        center: Offset(size.width * 0.85, size.height * 0.1),
        radius: minDim,
        color: const Color(0xFFD9CCFF).withValues(alpha: 0.9),
      );
      _blob(
        canvas,
        size,
        center: Offset(size.width * 0.08, size.height * 0.92),
        radius: minDim,
        color: const Color(0xFFBDF3F8).withValues(alpha: 0.8),
      );
      _blob(
        canvas,
        size,
        center: Offset(size.width * 0.45, size.height * 0.5),
        radius: minDim * 0.7,
        color: const Color(0xFFFFE3D9).withValues(alpha: 0.55),
      );
    }
  }

  void _blob(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.dark != dark || old.intensity != intensity;
}

/// Page wrapper: overscan-safe padding and a max content width for big TVs.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.child,
    this.maxWidth = 1480,
    this.padding = const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final tv = media.navigationMode == NavigationMode.directional;
    final overscan = tv ? 28.0 : 0.0;
    return SafeArea(
      minimum: EdgeInsets.all(overscan),
      child: Padding(
        padding: padding,
        child: Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}
